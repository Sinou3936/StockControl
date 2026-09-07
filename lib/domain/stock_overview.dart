bool isNearExpiry(
  DateTime? expiryDate, {
  required DateTime now,
  int thresholdDays = 3,
}) {
  if (expiryDate == null) return false;
  return !expiryDate.isAfter(now.add(Duration(days: thresholdDays)));
}
