enum MovementType { inbound, usage, disposal, adjustment, countCorrection }

extension MovementTypeDb on MovementType {
  String toDbString() => name;
}

MovementType movementTypeFromDbString(String value) =>
    MovementType.values.firstWhere((type) => type.name == value);
