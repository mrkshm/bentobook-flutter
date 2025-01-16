import 'dart:async';
import 'dart:convert';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:drift/drift.dart';
import 'package:bentobook/core/network/connectivity_service.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/extensions.dart';
import 'package:bentobook/core/database/operations/profile_operations.dart';
import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/api_endpoints.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'operation_types.dart';
import 'dart:developer' as dev;
import 'package:bentobook/core/image/image_manager.dart';

class QueueManager {
  static const _maxRetries = 3;
  static const _retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];
  final AppDatabase db;
  final ApiClient api;
  String? userId;
  final ConnectivityService connectivity;
  StreamSubscription? _connectivitySubscription;
  bool _isProcessing = false;
  final ImageManager _imageManager;

  int? get userIdInt {
    dev.log('QueueManager: Getting userIdInt from userId: $userId');
    if (userId == null) return null;
    try {
      final parsed = int.parse(userId!);
      dev.log('QueueManager: Parsed userIdInt: $parsed');
      return parsed;
    } catch (e) {
      dev.log('QueueManager: Failed to parse userId: $userId', error: e);
      return null;
    }
  }

  void updateUserId(String? newUserId) {
    dev.log('QueueManager: Updating userId from ${userId} to ${newUserId}');

    // Store the previous value for comparison
    final previousUserId = userId;
    userId = newUserId;

    if (userId != null) {
      dev.log(
          'QueueManager: New userId set to ${userId}, userIdInt: ${userIdInt}');
      if (previousUserId != userId) {
        dev.log('QueueManager: UserId changed, triggering queue processing');
        Future.microtask(() => processQueue());
      }
    } else {
      dev.log('QueueManager: UserId cleared');
    }
  }

  QueueManager({
    required this.db,
    required this.api,
    required this.connectivity,
    required this.userId,
    ImageManager? imageManager,
  }) : _imageManager = imageManager ?? ImageManager(dio: api.dio) {
    dev.log('QueueManager: Created with userId: $userId');
    _initConnectivity();
    if (userId != null) {
      dev.log('QueueManager: Initial userId present, processing queue');
      processQueue();
    }
  }

  static final provider =
      Provider.autoDispose.family<QueueManager, String?>((ref, initialUserId) {
    dev.log(
        'QueueManager: Creating provider with initialUserId: $initialUserId');

    // Create the queue manager with the initial userId
    final queueManager = QueueManager(
      api: ref.watch(apiClientProvider),
      db: ref.watch(databaseProvider),
      connectivity: ref.watch(connectivityProvider),
      userId: initialUserId,
    );

    // Keep alive if we have a userId
    if (initialUserId != null) {
      ref.keepAlive();
    }

    // Listen for auth state changes
    ref.listen(authServiceProvider, (previous, next) {
      dev.log('QueueManager: Auth state changed from $previous to $next');
      final newUserId = next.maybeMap(
        authenticated: (state) => state.userId,
        orElse: () => null,
      );

      if (newUserId != initialUserId) {
        queueManager.updateUserId(newUserId);
      }
    });

    // Ensure cleanup on dispose
    ref.onDispose(() {
      dev.log('QueueManager: Disposing provider');
      queueManager.dispose();
    });

    return queueManager;
  });

  // Convenience provider that uses the current auth state
  static final currentProvider = StateProvider<QueueManager>((ref) {
    final authState = ref.watch(authServiceProvider);
    final userId = authState.maybeMap(
      authenticated: (state) {
        dev.log('QueueManager: Got userId from auth state: ${state.userId}');
        return state.userId;
      },
      orElse: () {
        dev.log('QueueManager: No userId from auth state');
        return null;
      },
    );

    dev.log(
        'QueueManager: Creating currentProvider with userId from auth state: $userId');

    // Create and maintain the QueueManager instance
    final manager = ref.watch(provider(userId));

    // Keep the provider alive if we have a userId
    if (userId != null) {
      ref.keepAlive();
    }

    return manager;
  });

  void _initConnectivity() {
    dev.log('QueueManager: Initializing connectivity listener');
    _connectivitySubscription =
        connectivity.onConnectivityChanged.listen((isOnline) {
      dev.log(
          'QueueManager: Connectivity changed - online: $isOnline, userId: $userId');
      if (isOnline && userId != null) {
        // Capture userId in closure to ensure we use the current value
        final currentUserId = userId;
        Future.delayed(Duration(seconds: 2), () {
          // Check if userId is still the same and not null
          if (userId == currentUserId && userId != null) {
            dev.log(
                'QueueManager: Starting queue processing after connectivity change, userId: $userId');
            processQueue();
          } else {
            dev.log(
                'QueueManager: UserId changed or cleared during delay, skipping queue processing');
          }
        });
      }
    });
  }

  Future<bool> _isOnline() async {
    return await connectivity.hasConnection();
  }

  Future<void> enqueueOperation({
    required OperationType type,
    required Map<String, dynamic> payload,
  }) async {
    dev.log('QueueManager: Enqueueing operation: $type with userId: $userId');

    // Get current userId if not set
    if (userId == null || userIdInt == null) {
      dev.log('QueueManager: Cannot enqueue operation - no userId available');
      throw QueueException('No authenticated user');
    }

    // Ensure we have a valid userIdInt
    final currentUserIdInt = userIdInt;
    if (currentUserIdInt == null) {
      dev.log('QueueManager: Cannot enqueue operation - invalid userId format');
      throw QueueException('Invalid user ID format');
    }

    // Check for existing pending operation of same type
    final existing = await db.getPendingOperationsByType(type);
    if (existing.isNotEmpty) {
      dev.log('QueueManager: Operation already queued');
      return;
    }

    await _retryWithBackoff(() async {
      await db.into(db.operationQueue).insert(
            OperationQueueCompanion.insert(
              operationType: type,
              payload: json.encode(payload),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              localTimestamp: DateTime.now(),
              status: OperationStatus.pending,
              retryCount: const Value(0),
            ),
          );
    });

    dev.log(
        'QueueManager: Operation enqueued successfully, triggering queue processing');
    final isOnline = await _isOnline();
    if (isOnline) {
      processQueue();
    }
  }

  Future<void> processQueue() async {
    if (_isProcessing) {
      dev.log('QueueManager: Queue already processing');
      return;
    }

    if (userId == null || userIdInt == null) {
      dev.log('QueueManager: No userId available, skipping queue processing');
      return;
    }

    final isOnline = await connectivity.hasConnection();
    if (!isOnline) {
      dev.log('QueueManager: No connection, skipping queue processing');
      return;
    }

    try {
      _isProcessing = true;
      dev.log('QueueManager: Starting queue processing with userId: $userId');
      final pending = await db.getPendingOperations();
      dev.log('QueueManager: Found ${pending.length} pending operations');

      for (final operation in pending) {
        dev.log(
            'QueueManager: Processing operation ${operation.id} of type ${operation.operationType}');
        // Check connection before each operation
        if (!await connectivity.hasConnection()) {
          dev.log('QueueManager: Lost connection, pausing queue processing');
          break;
        }

        if (operation.retryCount >= _maxRetries) {
          dev.log(
              'QueueManager: Operation ${operation.id} exceeded max retries');
          await db.markOperationStatus(
            operation.id,
            OperationStatus.failed,
            error: 'Max retries exceeded',
          );
          continue;
        }

        try {
          await db.markOperationStatus(
              operation.id, OperationStatus.processing);
          await _processOperation(operation);
          await db.markOperationStatus(operation.id, OperationStatus.completed);
        } catch (e, stackTrace) {
          dev.log('QueueManager: Error processing operation ${operation.id}',
              error: e, stackTrace: stackTrace);
          final newRetryCount = operation.retryCount + 1;
          await db.updateOperation(
            operation.id,
            status: OperationStatus.failed,
            retryCount: newRetryCount,
            error: e.toString(),
          );

          if (newRetryCount < _maxRetries) {
            // Schedule retry with exponential backoff
            final delay = _retryDelays[operation.retryCount];
            dev.log(
                'QueueManager: Scheduling retry in ${delay.inSeconds} seconds');
            Future.delayed(delay, () => processQueue());
          }
        }
      }
    } finally {
      _isProcessing = false;
      dev.log('QueueManager: Queue processing complete');
    }
  }

  Future<void> _processOperation(OperationQueueData op) async {
    if (userId == null || userIdInt == null) {
      dev.log('QueueManager: No authenticated user');
      throw Exception("No authenticated user");
    }

    if (!await connectivity.hasConnection()) {
      dev.log('QueueManager: No network connection');
      throw Exception('No network connection');
    }

    dev.log('QueueManager: Processing operation of type ${op.operationType}');
    try {
      switch (op.operationType) {
        case OperationType.profileUpdate:
          await _processProfileUpdate(op);
          break;
        case OperationType.themeUpdate:
          await _processThemeUpdate(op);
          break;
        case OperationType.localeUpdate:
          await _processLocaleUpdate(op);
          break;
        case OperationType.profileImageSync:
          await _processProfileImageSync(op);
          break;
      }
    } catch (e, stackTrace) {
      dev.log('QueueManager: Error in _processOperation',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _processProfileUpdate(OperationQueueData op) async {
    if (userId == null || userIdInt == null) {
      throw QueueException('No authenticated user');
    }

    try {
      dev.log('QueueManager: Processing profile update operation');
      await db.markOperationStatus(op.id, OperationStatus.processing);

      final payload = json.decode(op.payload);
      dev.log('QueueManager: Profile update payload: $payload');
      if (payload == null) {
        throw QueueException('No payload for profile update operation');
      }

      dev.log('QueueManager: Sending profile update to server');
      try {
        await api.profileApi.updateProfile(
          firstName: payload['firstName'],
          lastName: payload['lastName'],
          about: payload['about'],
          displayName: payload['displayName'],
          preferredTheme: payload['preferredTheme'],
          preferredLanguage: payload['preferredLanguage'],
          username: payload['username'],
        );
        dev.log('QueueManager: Server update successful');
      } catch (e) {
        dev.log('QueueManager: Server update failed', error: e);
        rethrow;
      }

      dev.log('QueueManager: Profile update successful');
      await db.markOperationStatus(op.id, OperationStatus.completed);

      // Update sync status in profile table
      await db.updateProfileSyncStatus(userIdInt!, 'synced');
    } catch (e) {
      dev.log('QueueManager: Failed to process profile update: $e');
      await db.markOperationStatus(op.id, OperationStatus.failed,
          error: e.toString());
      rethrow;
    }
  }

  Future<void> _processThemeUpdate(OperationQueueData op) async {
    if (userId == null || userIdInt == null) {
      throw QueueException('No authenticated user');
    }

    try {
      // Get current server state
      final response = await api.profileApi.getProfile(userId!);
      if (response.data == null) {
        throw Exception('Server returned no data');
      }

      final serverTimestamp = response.data!.attributes.updatedAt;

      // Compare timestamps
      if (serverTimestamp != null &&
          serverTimestamp.isAfter(op.localTimestamp)) {
        dev.log('QueueManager: Server has newer theme, skipping update');
        await db.markOperationStatus(op.id, OperationStatus.skipped);
        return;
      }

      // Process local change
      final payload = json.decode(op.payload);
      await api.profileApi.updateProfile(
        preferredTheme: payload['theme'],
      );

      // Update server timestamp
      await db.updateOperationServerTimestamp(op.id, DateTime.now());
      dev.log('QueueManager: Theme updated on server');
    } catch (e) {
      dev.log('QueueManager: Error processing theme update: $e');
      rethrow;
    }
  }

  Future<void> _processLocaleUpdate(OperationQueueData op) async {
    if (userId == null || userIdInt == null) {
      throw QueueException('No authenticated user');
    }

    try {
      // Get current server state
      final response = await api.profileApi.getProfile(userId!);
      if (response.data == null) {
        throw Exception('Server returned no data');
      }

      final serverTimestamp = response.data!.attributes.updatedAt;

      // Compare timestamps
      if (serverTimestamp != null &&
          serverTimestamp.isAfter(op.localTimestamp)) {
        dev.log('QueueManager: Server has newer locale, skipping update');
        await db.markOperationStatus(op.id, OperationStatus.skipped);
        return;
      }

      // Process local change
      final payload = json.decode(op.payload);
      await api.dio.patch(
        ApiEndpoints.updateLanguage,
        data: {'locale': payload['locale']},
      );

      // Update server timestamp
      await db.updateOperationServerTimestamp(op.id, DateTime.now());
      dev.log('QueueManager: Locale updated on server');
    } catch (e) {
      dev.log('QueueManager: Error processing locale update: $e');
      rethrow;
    }
  }

  Future<void> _processProfileImageSync(OperationQueueData op) async {
    try {
      final payload = json.decode(op.payload);
      final avatarUrls = payload['avatar_urls'] as Map<String, dynamic>;
      final thumbnailUrl = avatarUrls['thumbnail'] as String;
      final mediumUrl = avatarUrls['medium'] as String;

      if (userId != null && userIdInt != null) {
        await _imageManager.downloadAndSaveProfileImages(
          userId: userIdInt!,
          thumbnailUrl: thumbnailUrl,
          mediumUrl: mediumUrl,
        );
        dev.log('QueueManager: Profile images synced successfully');
      }
    } catch (e) {
      dev.log('QueueManager: Failed to sync profile images', error: e);
      rethrow;
    }
  }

  Future<T> _retryWithBackoff<T>(Future<T> Function() operation) async {
    for (var i = 0; i < _maxRetries; i++) {
      try {
        return await operation();
      } catch (e) {
        if (i == _maxRetries - 1) rethrow;
        await Future.delayed(_retryDelays[i]);
      }
    }
    throw Exception('Max retries exceeded');
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

class QueueException implements Exception {
  final String message;
  QueueException(this.message);

  @override
  String toString() => 'QueueException: $message';
}

class UnsupportedOperationException implements Exception {
  final String operationType;
  UnsupportedOperationException(this.operationType);

  @override
  String toString() => 'Unsupported operation type: $operationType';
}

class ProfileUpdateRequest {
  final int userId;
  final String? firstName;
  final String? lastName;
  final String? about;
  final String? displayName;
  final String? preferredTheme;
  final String? preferredLanguage;
  final String? username;

  ProfileUpdateRequest({
    required this.userId,
    this.firstName,
    this.lastName,
    this.about,
    this.displayName,
    this.preferredTheme,
    this.preferredLanguage,
    this.username,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'firstName': firstName,
        'lastName': lastName,
        'about': about,
        'displayName': displayName,
        'preferredTheme': preferredTheme,
        'preferredLanguage': preferredLanguage,
        'username': username,
      };
}
