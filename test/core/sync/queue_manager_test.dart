import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:bentobook/core/sync/queue_manager.dart';
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/api/api_client.dart';
import 'package:bentobook/core/network/connectivity_service.dart';
import 'package:bentobook/core/sync/operation_types.dart';

// Mock classes
class MockDatabase extends Mock implements AppDatabase {
  @override
  $OperationQueueTable get operationQueue => MockOperationQueue();

  Future<List<OperationQueueData>> getPendingOperationsByType(OperationType type) async {
    return [];
  }

  @override
  SimpleSelectStatement<T, R> select<T extends HasResultSet, R>(
    ResultSetImplementation<T, R> table, {
    bool distinct = false,
  }) {
    final statement = MockSimpleSelectStatement<T, R>();
    when(() => statement.get()).thenAnswer((_) async => <R>[]);
    return statement;
  }
}
class MockApiClient extends Mock implements ApiClient {}
class MockConnectivity extends Mock implements ConnectivityService {}
class MockInsertStatement extends Mock 
    implements InsertStatement<$OperationQueueTable, OperationQueueData> {}
class MockSimpleSelectStatement<T extends HasResultSet, R> extends Mock 
    implements SimpleSelectStatement<T, R> {}
class MockOperationQueue extends Mock implements $OperationQueueTable {}

void main() {
  setUpAll(() {
    final now = DateTime.now();
    registerFallbackValue(OperationType.themeUpdate);
    registerFallbackValue(MockOperationQueue());
    registerFallbackValue(
      OperationQueueCompanion(
        operationType: const Value(OperationType.themeUpdate),
        payload: const Value(''),
        createdAt: Value(now),
        updatedAt: Value(now),
        localTimestamp: Value(now),
        status: const Value(OperationStatus.pending),
        retryCount: const Value(0),
      ),
    );
  });

  late QueueManager queueManager;
  late MockDatabase db;
  late MockApiClient api;
  late MockConnectivity connectivity;
  late MockInsertStatement insertStatement;
  late StreamController<bool> connectivityController;

  setUp(() {
    db = MockDatabase();
    api = MockApiClient();
    connectivity = MockConnectivity();
    insertStatement = MockInsertStatement();
    connectivityController = StreamController<bool>.broadcast();

    when(() => db.into(any<$OperationQueueTable>())).thenReturn(insertStatement);
    when(() => insertStatement.insert(any<OperationQueueCompanion>())).thenAnswer((_) async => 1);
    when(() => connectivity.hasConnection()).thenAnswer((_) async => false);
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => connectivityController.stream);

    queueManager = QueueManager(db: db, api: api, connectivity: connectivity);
  });

  tearDown(() {
    connectivityController.close();
  });

  test('enqueues operation when offline', () async {
    await queueManager.enqueueOperation(
      type: OperationType.themeUpdate,
      payload: {'theme': 'dark'},
    );

    verify(() => insertStatement.insert(any<OperationQueueCompanion>())).called(1);
  });
}