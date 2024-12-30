import 'models/syncable.dart';

/// Generic conflict resolver for syncable objects
class ConflictResolver {
  final Map<String, ConflictResolver> resolvers;

  ConflictResolver({required this.resolvers});

  /// Resolve conflicts between local and remote data
  ConflictResolution<Syncable> resolveConflict({
    required Syncable localData,
    required Syncable remoteData,
    ConflictStrategy strategy = ConflictStrategy.remoteWins,
  }) {
    final resolver = resolvers[remoteData.type];
    if (resolver == null) {
      return ConflictResolution(shouldUpdate: true, resolvedData: remoteData);
    }
    return resolver.resolveConflict(
      localData: localData,
      remoteData: remoteData,
      strategy: strategy,
    );
  }

  /// Merge local and remote data
  /// Override this method to implement custom merge logic
  ConflictResolution<Syncable> mergeData(Syncable local, Syncable remote) {
    final resolver = resolvers[remote.type];
    if (resolver == null) {
      return ConflictResolution(shouldUpdate: true, resolvedData: remote);
    }
    return resolver.mergeData(local, remote);
  }
}
