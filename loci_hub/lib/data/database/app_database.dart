import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  Database? _db;

  Database get db {
    if (_db == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _db!;
  }

  Future<void> initialize({bool isInMemory = false}) async {
    if (_db != null) return;

    // Use FFI for desktop (Linux/Windows/macOS) and unit tests
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    if (isInMemory) {
      _db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      );
    } else {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'loci_hub.db');
      _db = await openDatabase(
        path,
        version: 1,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      );
    }
  }

  static Future<void> _onConfigure(Database db) async {
    // 1. Enable Foreign Key Constraints
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    // 1. DailyJournal Table
    await db.execute('''
      CREATE TABLE DailyJournal (
        journal_date TEXT PRIMARY KEY,
        ai_title TEXT,
        ai_summary TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // 2. LocationLogs Table
    await db.execute('''
      CREATE TABLE LocationLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        journal_date TEXT,
        timestamp INTEGER,
        latitude REAL,
        longitude REAL,
        accuracy REAL,
        altitude REAL,
        speed REAL,
        heading REAL,
        provider TEXT,
        activity_type TEXT,
        created_at INTEGER,
        FOREIGN KEY(journal_date) REFERENCES DailyJournal(journal_date) ON DELETE CASCADE
      )
    ''');

    // 3. PhotoMetadata Table
    await db.execute('''
      CREATE TABLE PhotoMetadata (
        asset_id TEXT PRIMARY KEY,
        journal_date TEXT,
        asset_title TEXT,
        relative_path TEXT,
        photo_path TEXT,
        taken_at INTEGER,
        taken_time_source TEXT,
        matched_lat REAL,
        matched_lng REAL,
        matched_confidence REAL,
        match_time_diff_seconds INTEGER,
        match_status TEXT DEFAULT 'pending',
        FOREIGN KEY(journal_date) REFERENCES DailyJournal(journal_date) ON DELETE CASCADE
      )
    ''');

    // Indexes for optimization
    await db.execute('CREATE INDEX idx_location_timestamp ON LocationLogs(timestamp)');
    await db.execute('CREATE INDEX idx_location_date ON LocationLogs(journal_date)');
    await db.execute('CREATE INDEX idx_location_date_timestamp ON LocationLogs(journal_date, timestamp)');
    await db.execute('CREATE INDEX idx_photo_taken ON PhotoMetadata(taken_at)');
    await db.execute('CREATE INDEX idx_photo_date ON PhotoMetadata(journal_date)');
    await db.execute('CREATE INDEX idx_photo_date_taken ON PhotoMetadata(journal_date, taken_at)');
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
