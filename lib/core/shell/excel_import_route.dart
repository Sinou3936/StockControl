import 'package:flutter/material.dart';

import '../../features/excel_import/excel_import_screen.dart';

void pushExcelImportScreen(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ExcelImportScreen()));
}
