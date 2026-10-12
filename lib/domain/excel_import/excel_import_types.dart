import 'dart:math' as math;

/// 시트 하나. 첫 줄이 머리글이고 나머지가 데이터다.
/// 셀 값은 String, num, DateTime, bool, null 중 하나다.
typedef RawSheet = List<List<Object?>>;

const kGuideSheet = '안내';
const kSuppliersSheet = '거래처';
const kIngredientsSheet = '품목';
const kInboundSheet = '입고';

const kSupplierHeaders = ['이름', '연락처'];
const kIngredientHeaders = ['품목명', '기본 단위', '구매 단위', '환산계수', '안전재고', '유통기한 관리'];
const kInboundHeaders = ['날짜', '거래처', '품목명', '수량', '단가', '유통기한'];

/// 한 번에 올릴 수 있는 입고 줄 수.
const kMaxInboundRows = 3000;

/// 화면에 보여 주는 오류 수 (넘으면 "외 N개").
const kMaxShownErrors = 50;

class RawWorkbook {
  const RawWorkbook({
    required this.suppliers,
    required this.ingredients,
    required this.inbound,
  });

  final RawSheet suppliers;
  final RawSheet ingredients;
  final RawSheet inbound;
}

/// 파일의 한 줄에서 찾은 문제. [row]는 엑셀에서 보이는 줄 번호(머리글이 1).
class ImportError {
  const ImportError(this.sheet, this.row, this.message);

  final String sheet;
  final int row;
  final String message;

  String get text => '$sheet 시트 $row번째 줄: $message';

  @override
  String toString() => text;
}

/// 앱에 이미 등록된 품목 중 검증에 필요한 값.
class ExistingIngredient {
  const ExistingIngredient({
    required this.baseUnit,
    required this.purchaseUnit,
    required this.conversionFactor,
    required this.isExpiryTracked,
  });

  final String baseUnit;
  final String purchaseUnit;
  final double conversionFactor;
  final bool isExpiryTracked;
}

class NewSupplier {
  const NewSupplier({required this.name, this.contact});

  final String name;
  final String? contact;
}

class NewIngredient {
  const NewIngredient({
    required this.name,
    required this.baseUnit,
    required this.purchaseUnit,
    required this.conversionFactor,
    required this.safetyStockQty,
    required this.isExpiryTracked,
  });

  final String name;
  final String baseUnit;
  final String purchaseUnit;
  final double conversionFactor;
  final double? safetyStockQty;
  final bool isExpiryTracked;
}

class InboundLine {
  const InboundLine({
    required this.rowNumber,
    required this.receivedAt,
    required this.supplierName,
    required this.ingredientName,
    required this.purchaseQty,
    required this.purchaseUnit,
    required this.baseUnit,
    required this.conversionFactor,
    required this.baseQty,
    required this.unitCost,
    required this.expiryDate,
  });

  final int rowNumber;

  /// 입고 날짜의 09:00 (로컬).
  final DateTime receivedAt;
  final String supplierName;
  final String ingredientName;

  /// 파일에 적은 수량 (구매 단위).
  final double purchaseQty;
  final String purchaseUnit;
  final String baseUnit;
  final double conversionFactor;

  /// 저장될 수량 = [purchaseQty] × [conversionFactor] (기본 단위).
  final double baseQty;
  final double unitCost;
  final DateTime? expiryDate;
}

/// 검증을 통과한, 저장할 내용.
class ImportPlan {
  const ImportPlan({
    required this.newSuppliers,
    required this.newIngredients,
    required this.inboundLines,
    required this.noPriceCount,
    required this.ignoredExpiryCount,
    this.restoredPhoneCount = 0,
  });

  final List<NewSupplier> newSuppliers;
  final List<NewIngredient> newIngredients;
  final List<InboundLine> inboundLines;

  /// 단가 칸이 비어 0으로 저장되는 입고 줄 수.
  final int noPriceCount;

  /// 유통기한 관리가 아닌 품목인데 유통기한이 적혀 있어 무시한 줄 수.
  final int ignoredExpiryCount;

  /// 엑셀이 숫자로 저장해 앞의 0이 사라진 연락처에 0을 되살린 새 거래처 수.
  final int restoredPhoneCount;

  /// 입고 날짜 범위 (자정). 입고가 없으면 null.
  DateTime? get firstDate => _dates(inboundLines).firstOrNull;
  DateTime? get lastDate => _dates(inboundLines).lastOrNull;

  static List<DateTime> _dates(List<InboundLine> lines) {
    final days = {
      for (final l in lines)
        DateTime(l.receivedAt.year, l.receivedAt.month, l.receivedAt.day),
    }.toList()..sort();
    return days;
  }
}

class ImportValidation {
  const ImportValidation({required this.plan, required this.errors});

  /// 오류가 없을 때만 있다.
  final ImportPlan? plan;
  final List<ImportError> errors;

  bool get isValid => errors.isEmpty;

  List<ImportError> get shownErrors => errors.take(kMaxShownErrors).toList();

  int get hiddenErrorCount => math.max(0, errors.length - kMaxShownErrors);
}
