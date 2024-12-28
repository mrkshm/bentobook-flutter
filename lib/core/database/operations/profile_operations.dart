import 'package:drift/drift.dart';
import '../database.dart';
import 'dart:developer' as dev;

extension ProfileOperations on AppDatabase {
  Future<Profile?> getProfile(String userId) async {
    dev.log('Database: Getting profile for user: $userId');
    return (select(profiles)..where((p) => p.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<void> upsertProfile({
    required String userId,
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

    // First try to get existing profile
    final existingProfile = await (select(profiles)
      ..where((p) => p.userId.equals(userId)))
      .getSingleOrNull();

    final profileData = ProfilesCompanion(
      id: existingProfile?.id != null 
        ? Value(existingProfile!.id) 
        : Value.absent(),
      userId: Value(userId),
      firstName: Value(firstName),
      lastName: Value(lastName),
      about: Value(about),
      displayName: Value(displayName),
      preferredTheme: preferredTheme != null ? Value(preferredTheme) : const Value.absent(),
      preferredLanguage: preferredLanguage != null ? Value(preferredLanguage) : const Value.absent(),
      syncStatus: Value(syncStatus ?? 'pending'),
      updatedAt: Value(now),
      createdAt: Value(existingProfile?.createdAt ?? now),
    );

    await into(profiles).insertOnConflictUpdate(profileData);
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
