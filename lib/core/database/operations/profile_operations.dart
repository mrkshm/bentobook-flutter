import 'package:drift/drift.dart';
import '../database.dart';
import 'dart:developer' as dev;

extension ProfileOperations on AppDatabase {
  Future<Profile?> getProfile(int userId) async {
    dev.log('Database: Getting profile for user: $userId');
    return (select(profiles)..where((p) => p.userId.equals(userId)))
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
    String? username,
    String? syncStatus,
  }) async {
    dev.log('Database: Upserting profile for user: $userId');
    final now = DateTime.now().toUtc();

    final profileData = ProfilesCompanion(
      userId: Value(userId),
      firstName: Value(firstName),
      lastName: Value(lastName),
      about: Value(about),
      displayName: Value(displayName),
      preferredTheme:
          preferredTheme != null ? Value(preferredTheme) : const Value.absent(),
      preferredLanguage: preferredLanguage != null
          ? Value(preferredLanguage)
          : const Value.absent(),
      username: username != null ? Value(username) : const Value.absent(),
      syncStatus: Value(syncStatus ?? 'pending'),
      updatedAt: Value(now),
      createdAt: Value(now),
    );

    await into(profiles).insertOnConflictUpdate(profileData);
  }

  Stream<Profile?> watchProfile(int userId) {
    dev.log('Database: Watching profile for user: $userId');
    return (select(profiles)..where((p) => p.userId.equals(userId)))
        .watchSingleOrNull();
  }

  Future<void> deleteProfile(int userId) async {
    await (delete(profiles)..where((p) => p.userId.equals(userId))).go();
  }

  Future<void> updateProfileSyncStatus(int userId, String status) async {
    await (update(profiles)..where((p) => p.userId.equals(userId)))
        .write(ProfilesCompanion(syncStatus: Value(status)));
  }

  Future<List<Profile>> getUnsyncedProfiles() async {
    return (select(profiles)..where((p) => p.syncStatus.equals('pending')))
        .get();
  }

  Future<void> updateProfileImages({
    required int userId,
    String? thumbnailPath,
    String? mediumPath,
    String? thumbnailUrl,
    String? mediumUrl,
    DateTime? imageUpdatedAt,
  }) async {
    await (update(profiles)..where((p) => p.userId.equals(userId))).write(
      ProfilesCompanion(
        thumbnailPath: Value(thumbnailPath),
        mediumPath: Value(mediumPath),
        thumbnailUrl: Value(thumbnailUrl),
        mediumUrl: Value(mediumUrl),
        imageUpdatedAt: Value(imageUpdatedAt),
      ),
    );
  }

  Future<void> updateProfileImage({
    required int userId,
    String? mediumPath,
    String? thumbnailPath,
  }) async {
    await (update(profiles)..where((t) => t.userId.equals(userId))).write(
      ProfilesCompanion(
        mediumPath:
            mediumPath == null ? const Value.absent() : Value(mediumPath),
        thumbnailPath:
            thumbnailPath == null ? const Value.absent() : Value(thumbnailPath),
        imageUpdatedAt: Value(DateTime.now()),
      ),
    );
  }
}
