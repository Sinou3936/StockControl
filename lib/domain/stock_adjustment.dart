class InsufficientStockException implements Exception {
  InsufficientStockException({
    required this.remainingQty,
    required this.requestedQty,
  });

  final double remainingQty;
  final double requestedQty;
}

double applyQuantityChange(double remainingQty, double change) {
  final newQty = remainingQty + change;
  if (newQty < 0) {
    throw InsufficientStockException(
      remainingQty: remainingQty,
      requestedQty: -change,
    );
  }
  return newQty;
}
