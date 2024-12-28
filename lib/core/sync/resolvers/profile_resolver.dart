import 'package:bentobook/core/api/models/profile.dart';
import 'package:bentobook/core/sync/conflict_resolver.dart';
import 'package:bentobook/core/sync/models/syncable.dart';

/// Extension to make Profile implement Syncable
extension ProfileSyncable on Profile {
  SyncableProfile toSyncable() => SyncableProfile(this);
}

/// Wrapper to make Profile implement Syncable
class SyncableProfile implements Syncable {
  final Profile profile;

  SyncableProfile(this.profile);

  @override
  String get id => profile.id;

  @override
  DateTime get updatedAt => profile.attributes.updatedAt ?? DateTime(0);

  @override
  String? get syncStatus => null; // Implement if needed
}

/// Profile-specific conflict resolver
class ProfileResolver extends ConflictResolver<SyncableProfile> {
  @override
  ConflictResolution<SyncableProfile> mergeData(
    SyncableProfile localData,
    SyncableProfile remoteData,
  ) {
    // Custom merge logic for profiles
    final localProfile = localData.profile;
    final remoteProfile = remoteData.profile;

    // If remote has null values for some fields, keep local values
    final mergedAttributes = ProfileAttributes(
      username: remoteProfile.attributes.username,
      firstName: remoteProfile.attributes.firstName ?? localProfile.attributes.firstName,
      lastName: remoteProfile.attributes.lastName ?? localProfile.attributes.lastName,
      about: remoteProfile.attributes.about ?? localProfile.attributes.about,
      fullName: remoteProfile.attributes.fullName ?? localProfile.attributes.fullName,
      displayName: remoteProfile.attributes.displayName ?? localProfile.attributes.displayName,
      preferredTheme: remoteProfile.attributes.preferredTheme ?? localProfile.attributes.preferredTheme,
      preferredLanguage: remoteProfile.attributes.preferredLanguage ?? localProfile.attributes.preferredLanguage,
      createdAt: remoteProfile.attributes.createdAt,
      updatedAt: remoteProfile.attributes.updatedAt,
      email: remoteProfile.attributes.email,
      avatarUrls: remoteProfile.attributes.avatarUrls,
    );

    final mergedProfile = Profile(
      id: remoteProfile.id,
      type: remoteProfile.type,
      attributes: mergedAttributes,
    );

    return ConflictResolution(
      resolvedData: SyncableProfile(mergedProfile),
      shouldUpdate: true,
      message: 'Merged local and remote profile data',
    );
  }
}
