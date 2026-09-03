enum BaseUnit { g, ml, ea }

extension BaseUnitDb on BaseUnit {
  String toDbString() => name;
}

BaseUnit baseUnitFromDbString(String value) =>
    BaseUnit.values.firstWhere((unit) => unit.name == value);
