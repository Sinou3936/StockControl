import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../domain/excel_import/excel_import_types.dart';
import '../../domain/excel_import/import_validator.dart';
import '../../domain/stock_by_date.dart';
import '../local/database.dart';
import '../repositories/lot_repository.dart';
import 'import_workbook_reader.dart';

class DuplicateCandidate {
  const DuplicateCandidate({
    required this.rowNumber,
    required this.ingredientName,
    required this.supplierName,
    required this.receivedAt,
    required this.baseQty,
    required this.unitCost,
  });

  final int rowNumber;
  final String ingredientName;
  final String supplierName;
  final DateTime receivedAt;
  final double baseQty;
  final double unitCost;
}

class ImportPreview {
  const ImportPreview({required this.validation, required this.duplicates});

  final ImportValidation validation;

  /// 저장하려는 입고와 모든 값이 같은 입고가 이미 있는 줄.
  final List<DuplicateCandidate> duplicates;
}

class ImportCommitResult {
  const ImportCommitResult({
    required this.newSuppliers,
    required this.newIngredients,
    required this.inboundCount,
    required this.firstDate,
    required this.lastDate,
  });

  final int newSuppliers;
  final int newIngredients;
  final int inboundCount;
  final DateTime? firstDate;
  final DateTime? lastDate;
}

class ExcelImportService {
  ExcelImportService(this._db);

  final AppDatabase _db;

  /// 파일을 읽어 검증하고, 오류가 없으면 기존 입고와 겹치는 줄을 찾는다.
  /// 엑셀 파일이 아니거나 시트가 없으면 [ImportFileException]. DB는 바꾸지 않는다.
  ///
  /// 파일의 이름은 앞뒤 공백을 지우고 읽으므로, 비교하는 DB 쪽 이름도 같은
  /// 규칙으로 지운다 (DB에 `" 쌀 "`이 있어도 파일의 `쌀`과 같은 품목이다).
  Future<ImportPreview> prepare({
    required Uint8List bytes,
    required String storeId,
    DateTime? now,
  }) async {
    final book = readImportWorkbook(bytes);
    final suppliers = await _db.select(_db.suppliers).get();
    final ingredients = await _db.select(_db.ingredients).get();

    final existingIngredients = <String, ExistingIngredient>{};
    for (final i in ingredients) {
      existingIngredients.putIfAbsent(
        i.name.trim(),
        () => ExistingIngredient(
          baseUnit: i.baseUnit,
          purchaseUnit: i.purchaseUnit,
          conversionFactor: i.conversionFactor,
          isExpiryTracked: i.isExpiryTracked,
        ),
      );
    }

    final validation = validateImport(
      book,
      existingSupplierNames: {for (final s in suppliers) s.name.trim()},
      existingIngredients: existingIngredients,
      now: now ?? DateTime.now(),
    );
    final plan = validation.plan;
    if (plan == null) {
      return ImportPreview(validation: validation, duplicates: const []);
    }
    final duplicates = await _findDuplicates(
      plan,
      storeId,
      suppliers,
      ingredients,
    );
    return ImportPreview(validation: validation, duplicates: duplicates);
  }

  Future<List<DuplicateCandidate>> _findDuplicates(
    ImportPlan plan,
    String storeId,
    List<Supplier> suppliers,
    List<Ingredient> ingredients,
  ) async {
    final first = plan.firstDate;
    final last = plan.lastDate;
    if (first == null || last == null) return const [];

    final supplierIds = <String, int>{};
    for (final s in suppliers) {
      supplierIds.putIfAbsent(s.name.trim(), () => s.id);
    }
    final ingredientIds = <String, int>{};
    for (final i in ingredients) {
      ingredientIds.putIfAbsent(i.name.trim(), () => i.id);
    }

    final lots =
        await (_db.select(_db.lots)..where(
              (l) =>
                  l.storeId.equals(storeId) &
                  l.receivedDate.isBetweenValues(first, dayEnd(last)),
            ))
            .get();
    if (lots.isEmpty) return const [];

    final movements =
        await (_db.select(_db.stockMovements)..where(
              (m) =>
                  m.lotId.isIn([for (final l in lots) l.id]) &
                  m.type.equals('inbound'),
            ))
            .get();
    final inboundQty = <int, double>{};
    for (final m in movements) {
      inboundQty.putIfAbsent(m.lotId, () => m.quantity);
    }

    final duplicates = <DuplicateCandidate>[];
    for (final line in plan.inboundLines) {
      final supplierId = supplierIds[line.supplierName];
      final ingredientId = ingredientIds[line.ingredientName];
      // 새 거래처나 새 품목이 걸린 줄은 기존 입고가 있을 수 없다.
      if (supplierId == null || ingredientId == null) continue;
      final found = lots.any(
        (l) =>
            l.supplierId == supplierId &&
            l.ingredientId == ingredientId &&
            isSameDay(l.receivedDate, line.receivedAt) &&
            (l.unitCost - line.unitCost).abs() < 1e-9 &&
            ((inboundQty[l.id] ?? double.nan) - line.baseQty).abs() < 1e-6,
      );
      if (found) {
        duplicates.add(
          DuplicateCandidate(
            rowNumber: line.rowNumber,
            ingredientName: line.ingredientName,
            supplierName: line.supplierName,
            receivedAt: line.receivedAt,
            baseQty: line.baseQty,
            unitCost: line.unitCost,
          ),
        );
      }
    }
    return duplicates;
  }

  /// 계획을 한 트랜잭션으로 저장한다. 하나라도 실패하면 아무것도 남지 않는다.
  Future<ImportCommitResult> commit({
    required ImportPlan plan,
    required String storeId,
  }) {
    return _db.transaction(() async {
      final supplierIds = <String, int>{};
      for (final s in await _db.select(_db.suppliers).get()) {
        supplierIds.putIfAbsent(s.name.trim(), () => s.id);
      }
      final ingredientIds = <String, int>{};
      for (final i in await _db.select(_db.ingredients).get()) {
        ingredientIds.putIfAbsent(i.name.trim(), () => i.id);
      }

      for (final s in plan.newSuppliers) {
        supplierIds[s.name] = await _db.supplierDao.insertSupplier(
          SuppliersCompanion.insert(name: s.name, contact: Value(s.contact)),
        );
      }
      for (final i in plan.newIngredients) {
        ingredientIds[i.name] = await _db.ingredientDao.insertIngredient(
          IngredientsCompanion.insert(
            name: i.name,
            baseUnit: i.baseUnit,
            purchaseUnit: i.purchaseUnit,
            conversionFactor: i.conversionFactor,
            isExpiryTracked: i.isExpiryTracked,
            safetyStockQty: Value(i.safetyStockQty),
          ),
        );
      }

      final lots = LotRepository(_db);
      for (final line in plan.inboundLines) {
        final supplierId = supplierIds[line.supplierName];
        final ingredientId = ingredientIds[line.ingredientName];
        if (supplierId == null || ingredientId == null) {
          throw StateError('업로드 계획이 현재 데이터와 맞지 않습니다 (${line.rowNumber}번째 줄)');
        }
        await lots.receiveLot(
          ingredientId: ingredientId,
          supplierId: supplierId,
          storeId: storeId,
          receivedDate: line.receivedAt,
          expiryDate: line.expiryDate,
          unitCost: line.unitCost,
          baseQty: line.baseQty,
        );
      }

      return ImportCommitResult(
        newSuppliers: plan.newSuppliers.length,
        newIngredients: plan.newIngredients.length,
        inboundCount: plan.inboundLines.length,
        firstDate: plan.firstDate,
        lastDate: plan.lastDate,
      );
    });
  }
}

final excelImportServiceProvider = Provider<ExcelImportService>(
  (ref) => ExcelImportService(ref.watch(appDatabaseProvider)),
);
