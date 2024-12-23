import 'package:bentobook/core/api/models/user.dart' as api;
import 'package:bentobook/core/database/database.dart';
import 'package:bentobook/core/theme/theme_persistence.dart';
import 'package:bentobook/core/sync/operation_types.dart';
import 'package:drift/drift.dart';
import 'dart:developer' as dev;

extension UserToApi on User {
  api.User toApiUser() {
    final urls = avatarUrls;
    final themeString = ThemePersistence.themeToString(preferredTheme);
    dev.log('Database: Converting ThemeMode "$preferredTheme" to API string: "$themeString"');
    
    return api.User(
      id: id.toString(),
      type: 'users',
      attributes: api.UserAttributes(
        email: email,
        profile: api.UserProfile(
          username: username,
          displayName: displayName,
          firstName: firstName,
          lastName: lastName,
          about: about,
          preferredTheme: themeString,
          preferredLanguage: preferredLanguage,
          avatarUrls: urls != null 
            ? api.AvatarUrls(
                small: urls['small'],
                medium: urls['medium'],
                large: urls['large'],
              )
            : null,
        ),
      ),
    );
  }
}

extension QueueOperations on AppDatabase {
  Future<List<OperationQueueData>> getPendingOperations() {
    return (select(operationQueue)
      ..where((op) => op.status.equals(OperationStatus.pending.name)))
      .get();
  }

  Future<void> markOperationStatus(
    int id, 
    OperationStatus status, {  // Changed from String to OperationStatus
    String? error,
  }) async {
    dev.log('Database: Marking operation $id as $status');
    await (update(operationQueue)..where((op) => op.id.equals(id)))
      .write(OperationQueueCompanion(
        status: Value(status),  // Drift handles enum conversion
        error: Value(error),
        updatedAt: Value(DateTime.now()),
      ));
  }

  Future<void> updateOperation(
    int id, {
    required OperationStatus status,  // Changed from String to OperationStatus
    required int retryCount,
    String? error,
  }) async {
    dev.log('Database: Updating operation $id: status=$status, retries=$retryCount');
    await (update(operationQueue)..where((op) => op.id.equals(id)))
      .write(OperationQueueCompanion(
        status: Value(status),  // Drift handles enum conversion
        retryCount: Value(retryCount),
        error: Value(error),
        updatedAt: Value(DateTime.now()),
      ));
  }

  Future<List<OperationQueueData>> getPendingOperationsByType(OperationType type) {
    return (select(operationQueue)
      ..where((op) => op.operationType.equals(type.name) & 
                      op.status.equals(OperationStatus.pending.name)))
      .get();
  }

  Future<DateTime?> getLatestServerTimestamp(OperationType type) async {
    final operation = await (select(operationQueue)
      ..where((op) => op.operationType.equals(type.name))
      ..orderBy([(op) => OrderingTerm.desc(op.serverTimestamp)]))
      .getSingleOrNull();
    return operation?.serverTimestamp;
  }

  Future<void> updateOperationServerTimestamp(
    int id, 
    DateTime serverTimestamp,
  ) async {
    await (update(operationQueue)..where((op) => op.id.equals(id)))
      .write(OperationQueueCompanion(
        serverTimestamp: Value(serverTimestamp),
      ));
  }
}
