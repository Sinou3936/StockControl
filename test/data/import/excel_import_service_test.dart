import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/data/import/excel_import_service.dart';
import 'package:stockcontrol/data/import/import_workbook_reader.dart';
import 'package:stockcontrol/data/local/database.dart';
import 'package:stockcontrol/domain/excel_import/excel_import_types.dart';

import '../../support/import_test_files.dart';

final now = DateTime(2026, 10, 12, 10);

void main() {
  late AppDatabase db;
  late ExcelImportService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = ExcelImportService(db);
    await db.storeDao.upsertStore(StoresCompanion.insert(id: 'a', name: '울산점'));
    await db.storeDao.upsertStore(StoresCompanion.insert(id: 'b', name: '부산점'));
  });

  tearDown(() => db.close());

  const riceRow = ['쌀', 'g', '포', 20000, null, '아니오'];

  Uint8List riceFile({
    Object? date = '2026-09-29',
    Object? qty = 2,
    Object? cost = 45000,
    Object? supplier = '가나다상사',
    Object? item = '쌀',
  }) => xlsx(
    suppliers: [
      ['가나다상사', null],
      ['마바사상회', '010-1234-5678'],
    ],
    ingredients: [riceRow],
    inbound: [
      [date, supplier, item, qty, cost, null],
    ],
  );

  Future<ImportCommitResult> upload(
    Uint8List bytes, {
    String store = 'a',
  }) async {
    final preview = await service.prepare(
      bytes: bytes,
      storeId: store,
      now: now,
    );
    expect(preview.validation.errors, isEmpty);
    return service.commit(plan: preview.validation.plan!, storeId: store);
  }

  test('정상 파일을 저장하면 거래처·품목·로트·입고 기록이 만들어진다', () async {
    final preview = await service.prepare(
      bytes: riceFile(),
      storeId: 'a',
      now: now,
    );
    expect(preview.validation.isValid, isTrue);
    expect(preview.duplicates, isEmpty);

    final result = await service.commit(
      plan: preview.validation.plan!,
      storeId: 'a',
    );

    expect(result.newSuppliers, 2);
    expect(result.newIngredients, 1);
    expect(result.inboundCount, 1);
    expect(result.firstDate, DateTime(2026, 9, 29));
    expect(result.lastDate, DateTime(2026, 9, 29));

    final suppliers = await db.select(db.suppliers).get();
    expect(suppliers.map((s) => s.name), containsAll(['가나다상사', '마바사상회']));
    expect(
      suppliers.firstWhere((s) => s.name == '마바사상회').contact,
      '010-1234-5678',
    );

    final ingredients = await db.select(db.ingredients).get();
    expect(ingredients.single.name, '쌀');
    expect(ingredients.single.conversionFactor, 20000);
    expect(ingredients.single.isExpiryTracked, isFalse);

    final lot = (await db.select(db.lots).get()).single;
    expect(lot.storeId, 'a');
    expect(lot.unitCost, 45000);
    expect(lot.receivedDate, DateTime(2026, 9, 29, 9));
    expect(lot.remainingQty, 40000);

    final movement = (await db.select(db.stockMovements).get()).single;
    expect(movement.type, 'inbound');
    expect(movement.quantity, 40000);
    expect(movement.occurredAt, DateTime(2026, 9, 29, 9));
  });

  test('올린 입고가 지난 날짜 재고 조회에 그날 끝 수량으로 나온다', () async {
    await upload(riceFile());

    final rows = await db.stockMovementDao
        .watchStockAsOf(DateTime(2026, 9, 30), storeId: 'a')
        .first;
    expect(rows, hasLength(1));
    expect(rows.single.lot.remainingQty, 40000);
    // 올린 날 이전 날짜에는 없다.
    final before = await db.stockMovementDao
        .watchStockAsOf(DateTime(2026, 9, 29), storeId: 'a')
        .first;
    expect(before, isEmpty);
  });

  test('DB 이름에 NBSP·겹친 공백이 있어도 같은 이름이면 새로 만들지 않는다', () async {
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '가나다 상사'),
    );
    await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '청양  고추',
        baseUnit: 'g',
        purchaseUnit: '봉',
        conversionFactor: 500,
        isExpiryTracked: false,
      ),
    );

    final bytes = xlsx(
      ingredients: [
        ['청양 고추', 'g', '봉', 500, null, '아니오'],
      ],
      inbound: [
        ['2026-09-29', '가나다 상사', '청양 고추', 1, 1000, null],
      ],
    );
    final preview = await service.prepare(bytes: bytes, storeId: 'a', now: now);

    expect(preview.validation.errors, isEmpty);
    expect(preview.validation.plan!.newSuppliers, isEmpty);
    expect(preview.validation.plan!.newIngredients, isEmpty);

    await service.commit(plan: preview.validation.plan!, storeId: 'a');
    expect(await db.select(db.suppliers).get(), hasLength(1));
    expect(await db.select(db.ingredients).get(), hasLength(1));
    expect(await db.select(db.lots).get(), hasLength(1));
  });

  test('이미 있는 거래처·품목은 새로 만들지 않고 시트를 비워도 이름으로 연결된다', () async {
    final supplierId = await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: '가나다상사'),
    );
    final ingredientId = await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '쌀',
        baseUnit: 'g',
        purchaseUnit: '포',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );

    final bytes = xlsx(
      inbound: [
        ['2026-09-29', '가나다상사', '쌀', 2, 45000, null],
      ],
    );
    final result = await upload(bytes);

    expect(result.newSuppliers, 0);
    expect(result.newIngredients, 0);
    expect(await db.select(db.suppliers).get(), hasLength(1));
    expect(await db.select(db.ingredients).get(), hasLength(1));
    final lot = (await db.select(db.lots).get()).single;
    expect(lot.supplierId, supplierId);
    expect(lot.ingredientId, ingredientId);
  });

  test('DB 이름에 앞뒤 공백이 있어도 파일의 같은 이름과 연결된다', () async {
    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(name: ' 가나다상사 '),
    );
    await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: ' 쌀 ',
        baseUnit: 'g',
        purchaseUnit: '포',
        conversionFactor: 20000,
        isExpiryTracked: false,
      ),
    );

    final preview = await service.prepare(
      bytes: xlsx(
        inbound: [
          ['2026-09-29', '가나다상사', '쌀', 2, 45000, null],
        ],
      ),
      storeId: 'a',
      now: now,
    );

    expect(preview.validation.errors, isEmpty);
    final result = await service.commit(
      plan: preview.validation.plan!,
      storeId: 'a',
    );
    expect(result.newSuppliers, 0);
    expect(result.newIngredients, 0);
    expect(await db.select(db.lots).get(), hasLength(1));
  });

  test('기존 품목과 환산계수가 다르면 오류이고 DB는 그대로다', () async {
    await db.ingredientDao.insertIngredient(
      IngredientsCompanion.insert(
        name: '쌀',
        baseUnit: 'g',
        purchaseUnit: '포',
        conversionFactor: 10000,
        isExpiryTracked: false,
      ),
    );

    final preview = await service.prepare(
      bytes: riceFile(),
      storeId: 'a',
      now: now,
    );

    expect(preview.validation.isValid, isFalse);
    expect(preview.validation.errors.single.text, contains('환산계수'));
    expect(preview.duplicates, isEmpty);
    expect(await db.select(db.lots).get(), isEmpty);
    expect(await db.select(db.suppliers).get(), isEmpty);
  });

  group('중복 의심', () {
    test('같은 파일을 두 번째 올리면 중복 의심이 나온다', () async {
      await upload(riceFile());

      final preview = await service.prepare(
        bytes: riceFile(),
        storeId: 'a',
        now: now,
      );

      expect(preview.validation.isValid, isTrue);
      final duplicate = preview.duplicates.single;
      expect(duplicate.ingredientName, '쌀');
      expect(duplicate.supplierName, '가나다상사');
      expect(duplicate.rowNumber, 2);
    });

    Future<List<DuplicateCandidate>> second(
      Uint8List bytes, {
      String store = 'a',
    }) async {
      await upload(riceFile());
      return (await service.prepare(
        bytes: bytes,
        storeId: store,
        now: now,
      )).duplicates;
    }

    test('매장이 다르면 중복이 아니다', () async {
      expect(await second(riceFile(), store: 'b'), isEmpty);
    });

    test('날짜가 다르면 중복이 아니다', () async {
      expect(await second(riceFile(date: '2026-09-28')), isEmpty);
    });

    test('여러 날짜가 든 파일에서는 같은 날 입고만 중복이다', () async {
      await upload(riceFile()); // 9월 29일에 2포
      final bytes = xlsx(
        suppliers: [
          ['가나다상사', null],
        ],
        ingredients: [riceRow],
        inbound: [
          ['2026-09-28', '가나다상사', '쌀', 2, 45000, null],
          ['2026-09-29', '가나다상사', '쌀', 2, 45000, null],
        ],
      );

      final preview = await service.prepare(
        bytes: bytes,
        storeId: 'a',
        now: now,
      );

      // 28일 줄은 값이 같아도 날짜가 달라서 중복이 아니다.
      expect(preview.duplicates.map((d) => d.rowNumber), [3]);
    });

    test('수량이 다르면 중복이 아니다', () async {
      expect(await second(riceFile(qty: 3)), isEmpty);
    });

    test('단가가 다르면 중복이 아니다', () async {
      expect(await second(riceFile(cost: 46000)), isEmpty);
    });

    test('거래처가 다르면 중복이 아니다', () async {
      expect(await second(riceFile(supplier: '마바사상회')), isEmpty);
    });

    test('품목이 다르면 중복이 아니다', () async {
      final bytes = xlsx(
        suppliers: [
          ['가나다상사', null],
        ],
        ingredients: [
          ['쌀', 'g', '포', 20000, null, '아니오'],
          ['보리', 'g', '포', 20000, null, '아니오'],
        ],
        inbound: [
          ['2026-09-29', '가나다상사', '보리', 2, 45000, null],
        ],
      );
      expect(await second(bytes), isEmpty);
    });

    test('파일 안의 같은 줄끼리는 중복으로 세지 않는다', () async {
      final bytes = xlsx(
        suppliers: [
          ['가나다상사', null],
        ],
        ingredients: [riceRow],
        inbound: [
          ['2026-09-29', '가나다상사', '쌀', 2, 45000, null],
          ['2026-09-29', '가나다상사', '쌀', 2, 45000, null],
        ],
      );

      final preview = await service.prepare(
        bytes: bytes,
        storeId: 'a',
        now: now,
      );

      expect(preview.validation.isValid, isTrue);
      expect(preview.validation.plan!.inboundLines, hasLength(2));
      expect(preview.duplicates, isEmpty);
    });
  });

  test('저장 도중 실패하면 만든 거래처·품목까지 전부 되돌려진다', () async {
    final line = InboundLine(
      rowNumber: 2,
      receivedAt: DateTime(2026, 9, 29, 9),
      supplierName: '새거래처',
      ingredientName: '새품목',
      purchaseQty: 1,
      purchaseUnit: '포',
      baseUnit: 'g',
      conversionFactor: 1000,
      baseQty: 1000,
      unitCost: 0,
      expiryDate: null,
    );
    // 둘째 줄은 계획에도 DB에도 없는 품목이라 저장 도중 예외가 난다.
    final broken = InboundLine(
      rowNumber: 3,
      receivedAt: DateTime(2026, 9, 29, 9),
      supplierName: '새거래처',
      ingredientName: '없는품목',
      purchaseQty: 1,
      purchaseUnit: '포',
      baseUnit: 'g',
      conversionFactor: 1000,
      baseQty: 1000,
      unitCost: 0,
      expiryDate: null,
    );
    final plan = ImportPlan(
      newSuppliers: const [NewSupplier(name: '새거래처')],
      newIngredients: const [
        NewIngredient(
          name: '새품목',
          baseUnit: 'g',
          purchaseUnit: '포',
          conversionFactor: 1000,
          safetyStockQty: null,
          isExpiryTracked: false,
        ),
      ],
      inboundLines: [line, broken],
      noPriceCount: 2,
      ignoredExpiryCount: 0,
    );

    await expectLater(
      service.commit(plan: plan, storeId: 'a'),
      throwsA(isA<StateError>()),
    );

    expect(await db.select(db.suppliers).get(), isEmpty);
    expect(await db.select(db.ingredients).get(), isEmpty);
    expect(await db.select(db.lots).get(), isEmpty);
    expect(await db.select(db.stockMovements).get(), isEmpty);
  });

  test('저장하면 동기화 큐에 거래처·품목·로트·입고 기록이 쌓인다', () async {
    await upload(riceFile());

    final queued = (await db.select(db.syncQueue).get())
        .map((q) => q.targetTable)
        .toSet();
    expect(
      queued,
      containsAll(['suppliers', 'ingredients', 'lots', 'stock_movements']),
    );
  });

  test('큰 파일(300줄)도 한 번에 올라간다', () async {
    final inbound = [
      for (var i = 0; i < 300; i++)
        [
          DateTime(2026, 9, 1 + i % 10),
          '가나다상사',
          '품목${i % 5}',
          1 + i,
          1000,
          null,
        ],
    ];
    final bytes = xlsx(
      suppliers: [
        ['가나다상사', null],
      ],
      ingredients: [
        for (var k = 0; k < 5; k++) ['품목$k', 'g', '박스', 1000, null, '아니오'],
      ],
      inbound: inbound,
    );

    final preview = await service.prepare(bytes: bytes, storeId: 'a', now: now);
    expect(preview.validation.errors, isEmpty);
    final result = await service.commit(
      plan: preview.validation.plan!,
      storeId: 'a',
    );

    expect(result.inboundCount, 300);
    expect(await db.select(db.lots).get(), hasLength(300));
    expect(await db.select(db.stockMovements).get(), hasLength(300));
  });

  test('오류가 있는 파일을 준비만 해서는 DB가 바뀌지 않는다', () async {
    final preview = await service.prepare(
      bytes: riceFile(supplier: '모르는거래처'),
      storeId: 'a',
      now: now,
    );

    expect(preview.validation.isValid, isFalse);
    expect(await db.select(db.suppliers).get(), isEmpty);
    expect(await db.select(db.ingredients).get(), isEmpty);
    expect(await db.select(db.lots).get(), isEmpty);
  });

  test('엑셀이 아닌 바이트는 ImportFileException이다', () async {
    await expectLater(
      service.prepare(
        bytes: Uint8List.fromList([1, 2, 3]),
        storeId: 'a',
        now: now,
      ),
      throwsA(isA<ImportFileException>()),
    );
  });

  test('유통기한 관리 품목은 유통기한이 로트에 들어가고 아닌 품목은 무시된다', () async {
    final bytes = xlsx(
      suppliers: [
        ['가나다상사', null],
      ],
      ingredients: [
        ['우유', 'ml', '팩', 1000, null, '예'],
        riceRow,
      ],
      inbound: [
        ['2026-09-29', '가나다상사', '우유', 2, 3000, '2026-10-05'],
        ['2026-09-29', '가나다상사', '쌀', 2, 45000, '2026-10-05'],
      ],
    );

    await upload(bytes);

    final lots = await db.select(db.lots).get();
    final ingredients = {
      for (final i in await db.select(db.ingredients).get()) i.id: i.name,
    };
    final milk = lots.firstWhere((l) => ingredients[l.ingredientId] == '우유');
    final rice = lots.firstWhere((l) => ingredients[l.ingredientId] == '쌀');
    expect(milk.expiryDate, DateTime(2026, 10, 5));
    expect(rice.expiryDate, isNull);
  });
}
