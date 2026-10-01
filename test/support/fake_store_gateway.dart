import 'package:stockcontrol/data/services/store_gateway.dart';

class FakeStoreGateway implements StoreGateway {
  final List<Map<String, dynamic>> stores = [];

  @override
  Future<List<Map<String, dynamic>>> fetchAllStores() async =>
      List.of(stores);

  @override
  Future<Map<String, dynamic>> createStore(String name) async {
    final store = {'id': 'fake-store-${stores.length + 1}', 'name': name};
    stores.add(store);
    return store;
  }
}
