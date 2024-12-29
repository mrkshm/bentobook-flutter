/// Base interface for objects that can be synced between local and remote storage
abstract class Syncable {
  /// Unique identifier for the object
  String get id;

  /// Last time the object was updated
  DateTime get updatedAt;

  /// Current sync status of the object
  String? get syncStatus;
}

/// Strategy to use when resolving conflicts between local and remote data
enum ConflictStrategy {
  /// Use the version with the most recent updatedAt timestamp
  newerWins,

  /// Always use the remote version
  remoteWins,

  /// Always keep the local version
  localWins,

  /// Attempt to merge the two versions
  merge,
}

/// Result of a conflict resolution
class ConflictResolution<T> {
  final T resolvedData;
  final bool shouldUpdate;
  final String message;

  const ConflictResolution({
    required this.resolvedData,
    required this.shouldUpdate,
    this.message = '',
  });
}
