import 'backup_helper.dart';

class BackupProxyWeb implements BackupProxy {
  @override
  Future<void> autoSyncToCloud() async {
    // Cloud sync not supported on web
    return;
  }

  @override
  Future<void> restoreFromCloud() async {
    throw Exception('Restore from cloud is not supported on Web.');
  }
}

BackupProxy getBackupProxy() => BackupProxyWeb();
