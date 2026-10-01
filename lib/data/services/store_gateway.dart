import 'package:supabase_flutter/supabase_flutter.dart';

abstract class StoreGateway {
  Future<List<Map<String, dynamic>>> fetchAllStores();
  Future<Map<String, dynamic>> createStore(String name);
}

class SupabaseStoreGateway implements StoreGateway {
  SupabaseStoreGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchAllStores() {
    return _client.from('stores').select();
  }

  @override
  Future<Map<String, dynamic>> createStore(String name) {
    return _client.from('stores').insert({'name': name}).select().single();
  }
}
