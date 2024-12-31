import 'dart:async';
import 'dart:convert';
import 'package:bentobook/core/auth/auth_service.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:drift/drift.dart';
import 'package:bentobook/core/network/connectivity_service.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/extensions.dart';
import 'package:bentobook/core/api/api_client.dart';
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
  final String? userId;
  final ConnectivityService connectivity;
  StreamSubscription? _connectivitySubscription;
  bool _isProcessing = false;
  final ImageManager _imageManager;

  QueueManager({
    required this.db,
    required this.api,
    required this.connectivity,
    required this.userId,
    ImageManager? imageManager,
  }) : _imageManager = imageManager ?? ImageManager(dio: api.dio) {
    _initConnectivity();
  }

  static final provider = Provider<QueueManager>((ref) {
    final authState = ref.watch(authServiceProvider);
    final userId = authState.maybeMap(
      authenticated: (state) => state.userId,
      orElse: () => null,
    );

    return QueueManager(
      api: ref.watch(apiClientProvider),
      db: ref.watch(databaseProvider),
      connectivity: ref.watch(connectivityProvider),
      userId: userId,
    );
  });

  void _initConnectivity() {
    connectivity.onConnectivityChanged.listen((isOnline) {
      dev.log('QueueManager: Connectivity changed - online: $isOnline');
      if (isOnline) {
        Future.delayed(Duration(seconds: 2), () => processQueue());
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
    dev.log('QueueManager: Enqueueing operation: $type');

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

    final isOnline = await connectivity.hasConnection();
    if (!isOnline) {
      dev.log('QueueManager: No connection, skipping queue processing');
      return;
    }

    try {
      _isProcessing = true;
      dev.log('QueueManager: Starting queue processing');
      final pending = await db.getPendingOperations();

      for (final operation in pending) {
        // Check connection before each operation
        if (!await connectivity.hasConnection()) {
          dev.log('QueueManager: Lost connection, pausing queue processing');
          break;
        }

        if (operation.retryCount >= _maxRetries) {
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
        } catch (e) {
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
    if (userId == null || userId!.isEmpty) {
      throw Exception("No authenticated user");
    }

    if (!await connectivity.hasConnection()) {
      throw Exception('No network connection');
    }

    switch (op.operationType) {
      case OperationType.profileUpdate:
        await _processProfileUpdate(op);
        break;
      case OperationType.themeUpdate:
        try {
          // Get current server state
          final response = await api.getProfile(userId!);
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
          await api.updateProfile(
            userId: userId!,
            preferredTheme: payload['theme'],
          );

          // Update server timestamp
          await db.updateOperationServerTimestamp(op.id, DateTime.now());
          dev.log('QueueManager: Theme updated on server');
        } catch (e) {
          dev.log('QueueManager: Error processing theme update: $e');
          rethrow;
        }
        break;
      case OperationType.profileImageSync:
        await _processProfileImageSync(op);
        break;
    }
  }

  Future<void> _processProfileUpdate(OperationQueueData op) async {
    try {
      dev.log('Processing profile update operation');
      await db.markOperationStatus(op.id, OperationStatus.processing);

      final payload = json.decode(op.payload);
      if (payload == null) {
        throw QueueException('No payload for profile update operation');
      }

      await api.updateProfile(
        userId: userId!,
        firstName: payload['firstName'],
        lastName: payload['lastName'],
        about: payload['about'],
        displayName: payload['displayName'],
        preferredTheme: payload['preferredTheme'],
        preferredLanguage: payload['preferredLanguage'],
        username: payload['username'],
      );

      await db.markOperationStatus(op.id, OperationStatus.completed);
    } catch (e) {
      dev.log('Failed to process profile update: $e');
      await db.markOperationStatus(op.id, OperationStatus.failed,
          error: e.toString());
      rethrow;
    }
  }

  Future<void> _processProfileImageSync(OperationQueueData op) async {
    try {
      final payload = json.decode(op.payload);
      final avatarUrls = payload['avatar_urls'] as Map<String, dynamic>;
      final thumbnailUrl = avatarUrls['thumbnail'] as String;
      final mediumUrl = avatarUrls['medium'] as String;

      if (userId != null) {
        await _imageManager.downloadAndSaveProfileImages(
          userId: userId!,
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
