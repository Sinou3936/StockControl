import 'package:stockcontrol/data/local/database.dart';

class LotQuantityAdjustment {
  LotQuantityAdjustment({required this.lotId, required this.change});

  final int lotId;
  final double change;
}

List<LotQuantityAdjustment> distributeCountDifference(
  List<Lot> lots,
  double difference,
) {
  if (difference == 0) return [];

  if (difference > 0) {
    final mostRecent = lots.reduce(
      (a, b) => a.receivedDate.isAfter(b.receivedDate) ? a : b,
    );
    return [LotQuantityAdjustment(lotId: mostRecent.id, change: difference)];
  }

  final sorted = [...lots]
    ..sort((a, b) => a.receivedDate.compareTo(b.receivedDate));
  var remaining = -difference;
  final adjustments = <LotQuantityAdjustment>[];
  for (final lot in sorted) {
    if (remaining <= 0) break;
    final take = remaining < lot.remainingQty ? remaining : lot.remainingQty;
    if (take > 0) {
      adjustments.add(LotQuantityAdjustment(lotId: lot.id, change: -take));
      remaining -= take;
    }
  }
  return adjustments;
}

class CountDifference {
  CountDifference({
    required this.ingredient,
    required this.theoreticalQty,
    required this.actualQty,
  });

  final Ingredient ingredient;
  final double theoreticalQty;
  final double actualQty;

  double get difference => actualQty - theoreticalQty;
}
