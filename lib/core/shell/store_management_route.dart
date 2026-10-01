import 'package:flutter/material.dart';

import '../../features/store_management/store_management_screen.dart';

void pushStoreManagementScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const StoreManagementScreen()),
  );
}
