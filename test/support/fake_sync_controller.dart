import 'package:stockcontrol/core/providers/sync_providers.dart';

class FakeSyncController extends SyncController {
  FakeSyncController(super.ref, {SyncStatus initial = const SyncStatus()}) {
    state = initial;
  }

  int syncCalls = 0;

  @override
  Future<void> sync() async {
    syncCalls++;
  }
}
