import 'package:drift/drift.dart';
import '../database.dart';
import 'dart:developer' as dev;

extension ProfileOperations on AppDatabase {
  Future<Profile?> getProfile(String userId) async {
    dev.log('Database: Getting profile for user: $userId');
    return (select(profiles)..where((p) => p.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<Profile> upsertProfile({
    required String userId,
    String? displayName,
    String? about,
    String? firstName,
    String? lastName,
    String? preferredLanguage,
    String syncStatus = 'pending',
  }) async {
    dev.log('Database: Upserting profile for user: $userId');

    final existingProfile = await getProfile(userId);
    final now = DateTime.now();

    final profile = ProfilesCompanion.insert(
      userId: userId,
      displayName: Value(displayName),
      about: Value(about),
      firstName: Value(firstName),
      lastName: Value(lastName),
      preferredLanguage: Value(preferredLanguage ?? 'en'),
      syncStatus: Value(syncStatus),
      updatedAt: now,
      createdAt: existingProfile?.createdAt ?? now,
    );

    await into(profiles).insertOnConflictUpdate(profile);
    return (select(profiles)..where((p) => p.userId.equals(userId)))
        .getSingle();
  }

  Stream<Profile?> watchProfile(String userId) {
    dev.log('Database: Watching profile for user: $userId');
    return (select(profiles)..where((p) => p.userId.equals(userId)))
        .watchSingleOrNull();
  }

  Future<void> deleteProfile(String userId) async {
    dev.log('Database: Deleting profile for user: $userId');
    await (delete(profiles)..where((p) => p.userId.equals(userId))).go();
  }

  Future<void> updateProfileSyncStatus(String userId, String status) async {
    dev.log('Database: Updating profile sync status: $userId -> $status');
    await (update(profiles)..where((p) => p.userId.equals(userId)))
        .write(ProfilesCompanion(syncStatus: Value(status)));
  }

  Future<List<Profile>> getUnsyncedProfiles() async {
    return (select(profiles)..where((p) => p.syncStatus.equals('pending')))
        .get();
  }
}
