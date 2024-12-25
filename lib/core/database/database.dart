import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:developer' as dev;
import 'package:flutter/material.dart' hide Table;
import 'tables/users_table.dart';
import 'tables/profiles_table.dart';
import 'tables/sync_status.dart';
import 'tables/operation_queue.dart';
import 'package:bentobook/core/sync/operation_types.dart';

part 'database.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'bentobook.sqlite'));
      dev.log('Database: Opening connection at ${file.path}');

      if (!file.existsSync()) {
        dev.log('Database: Creating new database file');
        file.createSync(recursive: true);
      }

      final database = NativeDatabase.createInBackground(file);
      dev.log('Database: Connection created successfully');
      return database;
    } catch (e, stackTrace) {
      dev.log('Database: Error opening connection',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  });
}

@DriftDatabase(tables: [Users, Profiles, SyncStatusTable, OperationQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection()) {
    _initDatabase();
  }

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 5) {
            await m.createTable(profiles);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _initDatabase() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'bentobook.sqlite'));
      dev.log('Database: Initializing at ${file.path}');
      dev.log('Database: File exists: ${file.existsSync()}');
      if (file.existsSync()) {
        dev.log('Database: File size: ${await file.length()} bytes');
        dev.log('Database: File permissions: ${file.statSync().modeString()}');
      }

      // Verify database connection
      try {
        await customStatement('SELECT 1');
        dev.log('Database: Connection test successful');
      } catch (e) {
        dev.log('Database: Connection test failed', error: e);
        rethrow;
      }

      // List all users in database
      try {
        final allUsers = await select(users).get();
        dev.log('Database: Current users in database: ${allUsers.length}');
        for (final user in allUsers) {
          dev.log('Database: User - ID: ${user.id}, Email: ${user.email}');
        }
      } catch (e) {
        dev.log('Database: Error listing users', error: e);
        rethrow;
      }
    } catch (e, stackTrace) {
      dev.log('Database: Error initializing database',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
