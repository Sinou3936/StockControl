import '../local/daos/store_dao.dart';
import '../local/database.dart';
import '../services/store_gateway.dart';

class StoreRepository {
  StoreRepository(this._gateway, this._storeDao);

  final StoreGateway _gateway;
  final StoreDao _storeDao;

  Future<void> refreshFromServer() async {
    final rows = await _gateway.fetchAllStores();
    for (final row in rows) {
      await _storeDao.upsertStore(
        StoresCompanion.insert(
          id: row['id'] as String,
          name: row['name'] as String,
        ),
      );
    }
  }

  Future<void> addStore(String name) async {
    final row = await _gateway.createStore(name);
    await _storeDao.upsertStore(
      StoresCompanion.insert(
        id: row['id'] as String,
        name: row['name'] as String,
      ),
    );
  }

  Stream<List<Store>> watchAll() => _storeDao.watchAll();
}
