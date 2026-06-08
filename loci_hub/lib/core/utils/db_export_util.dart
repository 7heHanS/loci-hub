import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database/app_database.dart';

class DbExportUtil {
  final AppDatabase _appDatabase;

  DbExportUtil(this._appDatabase);

  Database get _db => _appDatabase.db;

  /// Copies the SQLite DB file to a temporary directory with a clean filename and returns it.
  Future<File> exportDbFile() async {
    final dbPath = _db.path;
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final backupPath = join(tempDir.path, 'loci_hub_export_$timestamp.db');
    
    final dbFile = File(dbPath);
    return dbFile.copy(backupPath);
  }

  /// Exports LocationLogs (optionally filtered by journalDate) to a JSON file.
  Future<File> exportLocationLogsJson({String? journalDate}) async {
    List<Map<String, dynamic>> maps;
    if (journalDate != null) {
      maps = await _db.query(
        'LocationLogs', 
        where: 'journal_date = ?', 
        whereArgs: [journalDate],
        orderBy: 'timestamp ASC',
      );
    } else {
      maps = await _db.query(
        'LocationLogs',
        orderBy: 'timestamp ASC',
      );
    }

    final jsonStr = jsonEncode(maps);
    final tempDir = await getTemporaryDirectory();
    final suffix = journalDate ?? 'all';
    final filePath = join(tempDir.path, 'location_logs_export_$suffix.json');
    
    final file = File(filePath);
    return file.writeAsString(jsonStr, flush: true);
  }

  /// Exports PhotoMetadata (optionally filtered by journalDate) to a JSON file.
  Future<File> exportPhotoMetadataJson({String? journalDate}) async {
    List<Map<String, dynamic>> maps;
    if (journalDate != null) {
      maps = await _db.query(
        'PhotoMetadata', 
        where: 'journal_date = ?', 
        whereArgs: [journalDate],
        orderBy: 'taken_at ASC',
      );
    } else {
      maps = await _db.query(
        'PhotoMetadata',
        orderBy: 'taken_at ASC',
      );
    }

    final jsonStr = jsonEncode(maps);
    final tempDir = await getTemporaryDirectory();
    final suffix = journalDate ?? 'all';
    final filePath = join(tempDir.path, 'photo_metadata_export_$suffix.json');
    
    final file = File(filePath);
    return file.writeAsString(jsonStr, flush: true);
  }
}
