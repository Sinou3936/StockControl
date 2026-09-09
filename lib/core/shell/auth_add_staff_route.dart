import 'package:flutter/material.dart';

import '../../features/auth/add_staff_screen.dart';

void pushAddStaffScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AddStaffScreen()),
  );
}
