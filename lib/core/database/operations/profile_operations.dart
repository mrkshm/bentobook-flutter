import 'package:drift/drift.dart';
import '../database.dart';
import 'dart:developer' as dev;

extension ProfileOperations on AppDatabase {
  Future<Profile?> getProfile(int userId) async {
    dev.log('Database: Getting profile for user: $userId');
    return (select(profiles)..where((p) => p.id.equals(userId)))
        .getSingleOrNull();
  }

  Future<void> upsertProfile({
    required int userId,
    String? firstName,
    String? lastName,
    String? about,
    String? displayName,
    String? preferredTheme,
    String? preferredLanguage,
    String? syncStatus,
  }) async {
    dev.log('Database: Upserting profile for user: $userId');
    final now = DateTime.now().toUtc();

    final profileData = ProfilesCompanion(
      id: Value(userId),
      firstName: Value(firstName),
      lastName: Value(lastName),
      about: Value(about),
      displayName: Value(displayName),
      preferredTheme: preferredTheme != null ? Value(preferredTheme) : const Value.absent(),
      preferredLanguage: preferredLanguage != null ? Value(preferredLanguage) : const Value.absent(),
      syncStatus: Value(syncStatus ?? 'pending'),
      updatedAt: Value(now),
      createdAt: Value(now),
    );

    await into(profiles).insertOnConflictUpdate(profileData);
  }

  Stream<Profile?> watchProfile(int userId) {
    dev.log('Database: Watching profile for user: $userId');
    return (select(profiles)..where((p) => p.id.equals(userId)))
        .watchSingleOrNull();
  }

  Future<void> deleteProfile(int userId) async {
    await (delete(profiles)..where((p) => p.id.equals(userId))).go();
  }

  Future<void> updateProfileSyncStatus(int userId, String status) async {
    await (update(profiles)..where((p) => p.id.equals(userId)))
        .write(ProfilesCompanion(syncStatus: Value(status)));
  }

  Future<List<Profile>> getUnsyncedProfiles() async {
    return (select(profiles)..where((p) => p.syncStatus.equals('pending')))
        .get();
  }
}
