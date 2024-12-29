import 'dart:developer' as dev;
import 'models/syncable.dart';

/// Generic conflict resolver for syncable objects
abstract class ConflictResolver<T extends Syncable> {
  /// Resolve conflicts between local and remote data
  ConflictResolution<T> resolveConflict({
    required T localData,
    required T remoteData,
    ConflictStrategy strategy = ConflictStrategy.newerWins,
  }) {
    switch (strategy) {
      case ConflictStrategy.newerWins:
        final shouldUpdate = remoteData.updatedAt.isAfter(localData.updatedAt);
        return ConflictResolution(
          resolvedData: shouldUpdate ? remoteData : localData,
          shouldUpdate: shouldUpdate,
          message: shouldUpdate
              ? 'Remote data is newer'
              : 'Local data is newer or same age',
        );

      case ConflictStrategy.remoteWins:
        return ConflictResolution(
          resolvedData: remoteData,
          shouldUpdate: true,
          message: 'Using remote data (remoteWins strategy)',
        );

      case ConflictStrategy.localWins:
        return ConflictResolution(
          resolvedData: localData,
          shouldUpdate: false,
          message: 'Keeping local data (localWins strategy)',
        );

      case ConflictStrategy.merge:
        return mergeData(localData, remoteData);
    }
  }

  /// Merge local and remote data
  /// Override this method to implement custom merge logic
  ConflictResolution<T> mergeData(T localData, T remoteData) {
    // Default implementation uses newer wins
    dev.log('No custom merge logic implemented, using newerWins strategy');
    return resolveConflict(
      localData: localData,
      remoteData: remoteData,
      strategy: ConflictStrategy.newerWins,
    );
  }
}
