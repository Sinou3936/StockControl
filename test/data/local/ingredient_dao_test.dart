import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('inserts an ingredient and reads it back via watchAll', () async {
    await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '양파',
        baseUnit: 'g',
        purchaseUnit: '박스',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );

    final ingredients = await db.ingredientDao.watchAll().first;

    expect(ingredients, hasLength(1));
    expect(ingredients.first.name, '양파');
    expect(ingredients.first.conversionFactor, 20000);
  });
}
