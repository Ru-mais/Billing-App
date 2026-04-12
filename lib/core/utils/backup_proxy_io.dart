import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:archive/archive.dart';
import 'backup_helper.dart';

class BackupProxyIO implements BackupProxy {
  final _supabase = Supabase.instance.client;

  @override
  Future<void> autoSyncToCloud() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final dbDir = await getApplicationDocumentsDirectory();
      final backupBytes = await _createDatabaseZipBytes(dbDir);
      
      final fileName = 'backup_${user.id}.zip';
      
      await _supabase.storage.from('backups').uploadBinary(
        fileName,
        backupBytes,
        fileOptions: const FileOptions(upsert: true),
      );

      // Update backup metadata in profiles table
      await _supabase.from('profiles').update({
        'last_sync': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      print('Cloud Sync Successful: $fileName');
    } catch (e) {
      print('Cloud Sync Failed: $e');
    }
  }

  @override
  Future<void> restoreFromCloud() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final fileName = 'backup_${user.id}.zip';
      final response = await _supabase.storage.from('backups').download(fileName);
      
      final dbDir = await getApplicationDocumentsDirectory();
      _extractZipBytes(response, dbDir);
      
      print('Restore Successful');
    } catch (e) {
      print('Restore Failed: $e');
      rethrow;
    }
  }

  Future<Uint8List> _createDatabaseZipBytes(Directory dbDir) async {
    final archive = Archive();

    final files = dbDir.listSync();
    for (final file in files) {
      if (file is File && file.path.endsWith('.hive')) {
        final bytes = await file.readAsBytes();
        final archiveFile = ArchiveFile(p.basename(file.path), bytes.length, bytes);
        archive.addFile(archiveFile);
      }
    }
    
    final zipBytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBytes!);
  }

  void _extractZipBytes(Uint8List zipBytes, Directory destination) {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    for (final file in archive) {
      if (file.isFile) {
        final data = file.content as List<int>;
        File(p.join(destination.path, file.name))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      }
    }
  }
}

BackupProxy getBackupProxy() => BackupProxyIO();
