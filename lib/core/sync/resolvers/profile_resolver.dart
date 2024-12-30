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

  @override
  String get type => 'profile';
}

/// Profile-specific conflict resolver
class ProfileResolver implements ConflictResolver {
  @override
  Map<String, ConflictResolver> get resolvers => {'profile': this};

  @override
  ConflictResolution<Syncable> resolveConflict({
    required Syncable localData,
    required Syncable remoteData,
    ConflictStrategy strategy = ConflictStrategy.remoteWins,
  }) {
    return ConflictResolution(
      shouldUpdate: true,
      resolvedData: remoteData,
    );
  }

  @override
  ConflictResolution<Syncable> mergeData(Syncable local, Syncable remote) {
    return ConflictResolution(
      shouldUpdate: true,
      resolvedData: remote,
    );
  }
}
