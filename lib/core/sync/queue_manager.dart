import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';  // Add this import for Value class
import 'package:bentobook/core/network/connectivity_service.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/database/extensions.dart';
import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/api/models/profile.dart';
import 'operation_types.dart';
import 'dart:developer' as dev;

class QueueManager {
  static const _maxRetries = 3;
  static const _retryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];
  final AppDatabase db;
  final ApiClient api;
  final ConnectivityService connectivity;
  StreamSubscription? _connectivitySubscription;
  bool _isProcessing = false;

  QueueManager({
    required this.db,
    required this.api,
    required this.connectivity,
  }) {
    _initConnectivity();
  }

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
          await db.markOperationStatus(operation.id, OperationStatus.processing);
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
    if (!await connectivity.hasConnection()) {
      throw Exception('No network connection');
    }

    switch (OperationType.values.byName(op.operationType.name)) {
      case OperationType.themeUpdate:
        try {
          // Get current server state
          final response = await api.getMe();
          if (response.data == null) {
            throw Exception('Server returned no data');
          }

          final serverTimestamp = response.data!.attributes.updatedAt;
          
          // Compare timestamps
          if (serverTimestamp != null && serverTimestamp.isAfter(op.localTimestamp)) {
            dev.log('QueueManager: Server has newer theme, skipping update');
            await db.markOperationStatus(op.id, OperationStatus.skipped);
            return;
          }

          // Process local change
          final payload = json.decode(op.payload);
          await api.updateProfile(
            request: ProfileUpdateRequest(
              preferredTheme: payload['theme'],
            ),
          );
          
          // Update server timestamp
          await db.updateOperationServerTimestamp(op.id, DateTime.now());
          dev.log('QueueManager: Theme updated on server');
        } catch (e) {
          dev.log('QueueManager: Error processing theme update: $e');
          rethrow;
        }
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

class UnsupportedOperationException implements Exception {
  final String operationType;
  UnsupportedOperationException(this.operationType);
  
  @override
  String toString() => 'Unsupported operation type: $operationType';
}