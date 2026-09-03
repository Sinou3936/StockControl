import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

final supplierDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).supplierDao);
final ingredientDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).ingredientDao);
final lotDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).lotDao);
final stockMovementDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).stockMovementDao);
