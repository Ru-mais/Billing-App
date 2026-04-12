import 'dart:typed_data';
import 'backup_proxy_io.dart'
    if (dart.library.html) 'backup_proxy_web.dart';

abstract class BackupProxy {
  Future<void> autoSyncToCloud();
  Future<void> restoreFromCloud();
}

class BackupHelper {
  static final BackupProxy _proxy = getBackupProxy();

  static Future<void> autoSyncToCloud() => _proxy.autoSyncToCloud();
  static Future<void> restoreFromCloud() => _proxy.restoreFromCloud();
}
