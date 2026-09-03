// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SuppliersTable extends Suppliers
    with TableInfo<$SuppliersTable, Supplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactMeta = const VerificationMeta(
    'contact',
  );
  @override
  late final GeneratedColumn<String> contact = GeneratedColumn<String>(
    'contact',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, contact, memo, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suppliers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Supplier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('contact')) {
      context.handle(
        _contactMeta,
        contact.isAcceptableOrUnknown(data['contact']!, _contactMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Supplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Supplier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      contact: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact'],
      ),
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SuppliersTable createAlias(String alias) {
    return $SuppliersTable(attachedDatabase, alias);
  }
}

class Supplier extends DataClass implements Insertable<Supplier> {
  final int id;
  final String name;
  final String? contact;
  final String? memo;
  final DateTime createdAt;
  const Supplier({
    required this.id,
    required this.name,
    this.contact,
    this.memo,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || contact != null) {
      map['contact'] = Variable<String>(contact);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SuppliersCompanion toCompanion(bool nullToAbsent) {
    return SuppliersCompanion(
      id: Value(id),
      name: Value(name),
      contact: contact == null && nullToAbsent
          ? const Value.absent()
          : Value(contact),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      createdAt: Value(createdAt),
    );
  }

  factory Supplier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Supplier(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      contact: serializer.fromJson<String?>(json['contact']),
      memo: serializer.fromJson<String?>(json['memo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'contact': serializer.toJson<String?>(contact),
      'memo': serializer.toJson<String?>(memo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Supplier copyWith({
    int? id,
    String? name,
    Value<String?> contact = const Value.absent(),
    Value<String?> memo = const Value.absent(),
    DateTime? createdAt,
  }) => Supplier(
    id: id ?? this.id,
    name: name ?? this.name,
    contact: contact.present ? contact.value : this.contact,
    memo: memo.present ? memo.value : this.memo,
    createdAt: createdAt ?? this.createdAt,
  );
  Supplier copyWithCompanion(SuppliersCompanion data) {
    return Supplier(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      contact: data.contact.present ? data.contact.value : this.contact,
      memo: data.memo.present ? data.memo.value : this.memo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Supplier(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('contact: $contact, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, contact, memo, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Supplier &&
          other.id == this.id &&
          other.name == this.name &&
          other.contact == this.contact &&
          other.memo == this.memo &&
          other.createdAt == this.createdAt);
}

class SuppliersCompanion extends UpdateCompanion<Supplier> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> contact;
  final Value<String?> memo;
  final Value<DateTime> createdAt;
  const SuppliersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.contact = const Value.absent(),
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SuppliersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.contact = const Value.absent(),
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Supplier> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? contact,
    Expression<String>? memo,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (contact != null) 'contact': contact,
      if (memo != null) 'memo': memo,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SuppliersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? contact,
    Value<String?>? memo,
    Value<DateTime>? createdAt,
  }) {
    return SuppliersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (contact.present) {
      map['contact'] = Variable<String>(contact.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuppliersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('contact: $contact, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $IngredientsTable extends Ingredients
    with TableInfo<$IngredientsTable, Ingredient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseUnitMeta = const VerificationMeta(
    'baseUnit',
  );
  @override
  late final GeneratedColumn<String> baseUnit = GeneratedColumn<String>(
    'base_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purchaseUnitMeta = const VerificationMeta(
    'purchaseUnit',
  );
  @override
  late final GeneratedColumn<String> purchaseUnit = GeneratedColumn<String>(
    'purchase_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversionFactorMeta = const VerificationMeta(
    'conversionFactor',
  );
  @override
  late final GeneratedColumn<double> conversionFactor = GeneratedColumn<double>(
    'conversion_factor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isExpiryTrackedMeta = const VerificationMeta(
    'isExpiryTracked',
  );
  @override
  late final GeneratedColumn<bool> isExpiryTracked = GeneratedColumn<bool>(
    'is_expiry_tracked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_expiry_tracked" IN (0, 1))',
    ),
  );
  static const VerificationMeta _safetyStockQtyMeta = const VerificationMeta(
    'safetyStockQty',
  );
  @override
  late final GeneratedColumn<double> safetyStockQty = GeneratedColumn<double>(
    'safety_stock_qty',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    category,
    baseUnit,
    purchaseUnit,
    conversionFactor,
    isExpiryTracked,
    safetyStockQty,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ingredients';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ingredient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('base_unit')) {
      context.handle(
        _baseUnitMeta,
        baseUnit.isAcceptableOrUnknown(data['base_unit']!, _baseUnitMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUnitMeta);
    }
    if (data.containsKey('purchase_unit')) {
      context.handle(
        _purchaseUnitMeta,
        purchaseUnit.isAcceptableOrUnknown(
          data['purchase_unit']!,
          _purchaseUnitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_purchaseUnitMeta);
    }
    if (data.containsKey('conversion_factor')) {
      context.handle(
        _conversionFactorMeta,
        conversionFactor.isAcceptableOrUnknown(
          data['conversion_factor']!,
          _conversionFactorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversionFactorMeta);
    }
    if (data.containsKey('is_expiry_tracked')) {
      context.handle(
        _isExpiryTrackedMeta,
        isExpiryTracked.isAcceptableOrUnknown(
          data['is_expiry_tracked']!,
          _isExpiryTrackedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isExpiryTrackedMeta);
    }
    if (data.containsKey('safety_stock_qty')) {
      context.handle(
        _safetyStockQtyMeta,
        safetyStockQty.isAcceptableOrUnknown(
          data['safety_stock_qty']!,
          _safetyStockQtyMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ingredient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ingredient(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      baseUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_unit'],
      )!,
      purchaseUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purchase_unit'],
      )!,
      conversionFactor: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}conversion_factor'],
      )!,
      isExpiryTracked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_expiry_tracked'],
      )!,
      safetyStockQty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}safety_stock_qty'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $IngredientsTable createAlias(String alias) {
    return $IngredientsTable(attachedDatabase, alias);
  }
}

class Ingredient extends DataClass implements Insertable<Ingredient> {
  final int id;
  final String name;
  final String? category;
  final String baseUnit;
  final String purchaseUnit;
  final double conversionFactor;
  final bool isExpiryTracked;
  final double? safetyStockQty;
  final DateTime createdAt;
  const Ingredient({
    required this.id,
    required this.name,
    this.category,
    required this.baseUnit,
    required this.purchaseUnit,
    required this.conversionFactor,
    required this.isExpiryTracked,
    this.safetyStockQty,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['base_unit'] = Variable<String>(baseUnit);
    map['purchase_unit'] = Variable<String>(purchaseUnit);
    map['conversion_factor'] = Variable<double>(conversionFactor);
    map['is_expiry_tracked'] = Variable<bool>(isExpiryTracked);
    if (!nullToAbsent || safetyStockQty != null) {
      map['safety_stock_qty'] = Variable<double>(safetyStockQty);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  IngredientsCompanion toCompanion(bool nullToAbsent) {
    return IngredientsCompanion(
      id: Value(id),
      name: Value(name),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      baseUnit: Value(baseUnit),
      purchaseUnit: Value(purchaseUnit),
      conversionFactor: Value(conversionFactor),
      isExpiryTracked: Value(isExpiryTracked),
      safetyStockQty: safetyStockQty == null && nullToAbsent
          ? const Value.absent()
          : Value(safetyStockQty),
      createdAt: Value(createdAt),
    );
  }

  factory Ingredient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ingredient(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String?>(json['category']),
      baseUnit: serializer.fromJson<String>(json['baseUnit']),
      purchaseUnit: serializer.fromJson<String>(json['purchaseUnit']),
      conversionFactor: serializer.fromJson<double>(json['conversionFactor']),
      isExpiryTracked: serializer.fromJson<bool>(json['isExpiryTracked']),
      safetyStockQty: serializer.fromJson<double?>(json['safetyStockQty']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String?>(category),
      'baseUnit': serializer.toJson<String>(baseUnit),
      'purchaseUnit': serializer.toJson<String>(purchaseUnit),
      'conversionFactor': serializer.toJson<double>(conversionFactor),
      'isExpiryTracked': serializer.toJson<bool>(isExpiryTracked),
      'safetyStockQty': serializer.toJson<double?>(safetyStockQty),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Ingredient copyWith({
    int? id,
    String? name,
    Value<String?> category = const Value.absent(),
    String? baseUnit,
    String? purchaseUnit,
    double? conversionFactor,
    bool? isExpiryTracked,
    Value<double?> safetyStockQty = const Value.absent(),
    DateTime? createdAt,
  }) => Ingredient(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category.present ? category.value : this.category,
    baseUnit: baseUnit ?? this.baseUnit,
    purchaseUnit: purchaseUnit ?? this.purchaseUnit,
    conversionFactor: conversionFactor ?? this.conversionFactor,
    isExpiryTracked: isExpiryTracked ?? this.isExpiryTracked,
    safetyStockQty: safetyStockQty.present
        ? safetyStockQty.value
        : this.safetyStockQty,
    createdAt: createdAt ?? this.createdAt,
  );
  Ingredient copyWithCompanion(IngredientsCompanion data) {
    return Ingredient(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      baseUnit: data.baseUnit.present ? data.baseUnit.value : this.baseUnit,
      purchaseUnit: data.purchaseUnit.present
          ? data.purchaseUnit.value
          : this.purchaseUnit,
      conversionFactor: data.conversionFactor.present
          ? data.conversionFactor.value
          : this.conversionFactor,
      isExpiryTracked: data.isExpiryTracked.present
          ? data.isExpiryTracked.value
          : this.isExpiryTracked,
      safetyStockQty: data.safetyStockQty.present
          ? data.safetyStockQty.value
          : this.safetyStockQty,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ingredient(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('baseUnit: $baseUnit, ')
          ..write('purchaseUnit: $purchaseUnit, ')
          ..write('conversionFactor: $conversionFactor, ')
          ..write('isExpiryTracked: $isExpiryTracked, ')
          ..write('safetyStockQty: $safetyStockQty, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    baseUnit,
    purchaseUnit,
    conversionFactor,
    isExpiryTracked,
    safetyStockQty,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ingredient &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.baseUnit == this.baseUnit &&
          other.purchaseUnit == this.purchaseUnit &&
          other.conversionFactor == this.conversionFactor &&
          other.isExpiryTracked == this.isExpiryTracked &&
          other.safetyStockQty == this.safetyStockQty &&
          other.createdAt == this.createdAt);
}

class IngredientsCompanion extends UpdateCompanion<Ingredient> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> category;
  final Value<String> baseUnit;
  final Value<String> purchaseUnit;
  final Value<double> conversionFactor;
  final Value<bool> isExpiryTracked;
  final Value<double?> safetyStockQty;
  final Value<DateTime> createdAt;
  const IngredientsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.baseUnit = const Value.absent(),
    this.purchaseUnit = const Value.absent(),
    this.conversionFactor = const Value.absent(),
    this.isExpiryTracked = const Value.absent(),
    this.safetyStockQty = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  IngredientsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.category = const Value.absent(),
    required String baseUnit,
    required String purchaseUnit,
    required double conversionFactor,
    required bool isExpiryTracked,
    this.safetyStockQty = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       baseUnit = Value(baseUnit),
       purchaseUnit = Value(purchaseUnit),
       conversionFactor = Value(conversionFactor),
       isExpiryTracked = Value(isExpiryTracked);
  static Insertable<Ingredient> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? baseUnit,
    Expression<String>? purchaseUnit,
    Expression<double>? conversionFactor,
    Expression<bool>? isExpiryTracked,
    Expression<double>? safetyStockQty,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (baseUnit != null) 'base_unit': baseUnit,
      if (purchaseUnit != null) 'purchase_unit': purchaseUnit,
      if (conversionFactor != null) 'conversion_factor': conversionFactor,
      if (isExpiryTracked != null) 'is_expiry_tracked': isExpiryTracked,
      if (safetyStockQty != null) 'safety_stock_qty': safetyStockQty,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  IngredientsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? category,
    Value<String>? baseUnit,
    Value<String>? purchaseUnit,
    Value<double>? conversionFactor,
    Value<bool>? isExpiryTracked,
    Value<double?>? safetyStockQty,
    Value<DateTime>? createdAt,
  }) {
    return IngredientsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      baseUnit: baseUnit ?? this.baseUnit,
      purchaseUnit: purchaseUnit ?? this.purchaseUnit,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      isExpiryTracked: isExpiryTracked ?? this.isExpiryTracked,
      safetyStockQty: safetyStockQty ?? this.safetyStockQty,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (baseUnit.present) {
      map['base_unit'] = Variable<String>(baseUnit.value);
    }
    if (purchaseUnit.present) {
      map['purchase_unit'] = Variable<String>(purchaseUnit.value);
    }
    if (conversionFactor.present) {
      map['conversion_factor'] = Variable<double>(conversionFactor.value);
    }
    if (isExpiryTracked.present) {
      map['is_expiry_tracked'] = Variable<bool>(isExpiryTracked.value);
    }
    if (safetyStockQty.present) {
      map['safety_stock_qty'] = Variable<double>(safetyStockQty.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngredientsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('baseUnit: $baseUnit, ')
          ..write('purchaseUnit: $purchaseUnit, ')
          ..write('conversionFactor: $conversionFactor, ')
          ..write('isExpiryTracked: $isExpiryTracked, ')
          ..write('safetyStockQty: $safetyStockQty, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LotsTable extends Lots with TableInfo<$LotsTable, Lot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ingredientIdMeta = const VerificationMeta(
    'ingredientId',
  );
  @override
  late final GeneratedColumn<int> ingredientId = GeneratedColumn<int>(
    'ingredient_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ingredients (id)',
    ),
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<int> supplierId = GeneratedColumn<int>(
    'supplier_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES suppliers (id)',
    ),
  );
  static const VerificationMeta _receivedDateMeta = const VerificationMeta(
    'receivedDate',
  );
  @override
  late final GeneratedColumn<DateTime> receivedDate = GeneratedColumn<DateTime>(
    'received_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiryDateMeta = const VerificationMeta(
    'expiryDate',
  );
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
    'expiry_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitCostMeta = const VerificationMeta(
    'unitCost',
  );
  @override
  late final GeneratedColumn<double> unitCost = GeneratedColumn<double>(
    'unit_cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingQtyMeta = const VerificationMeta(
    'remainingQty',
  );
  @override
  late final GeneratedColumn<double> remainingQty = GeneratedColumn<double>(
    'remaining_qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ingredientId,
    supplierId,
    receivedDate,
    expiryDate,
    unitCost,
    remainingQty,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lots';
  @override
  VerificationContext validateIntegrity(
    Insertable<Lot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ingredient_id')) {
      context.handle(
        _ingredientIdMeta,
        ingredientId.isAcceptableOrUnknown(
          data['ingredient_id']!,
          _ingredientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ingredientIdMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    }
    if (data.containsKey('received_date')) {
      context.handle(
        _receivedDateMeta,
        receivedDate.isAcceptableOrUnknown(
          data['received_date']!,
          _receivedDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_receivedDateMeta);
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
        _expiryDateMeta,
        expiryDate.isAcceptableOrUnknown(data['expiry_date']!, _expiryDateMeta),
      );
    }
    if (data.containsKey('unit_cost')) {
      context.handle(
        _unitCostMeta,
        unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta),
      );
    } else if (isInserting) {
      context.missing(_unitCostMeta);
    }
    if (data.containsKey('remaining_qty')) {
      context.handle(
        _remainingQtyMeta,
        remainingQty.isAcceptableOrUnknown(
          data['remaining_qty']!,
          _remainingQtyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingQtyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ingredientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ingredient_id'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}supplier_id'],
      ),
      receivedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_date'],
      )!,
      expiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expiry_date'],
      ),
      unitCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_cost'],
      )!,
      remainingQty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}remaining_qty'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LotsTable createAlias(String alias) {
    return $LotsTable(attachedDatabase, alias);
  }
}

class Lot extends DataClass implements Insertable<Lot> {
  final int id;
  final int ingredientId;
  final int? supplierId;
  final DateTime receivedDate;
  final DateTime? expiryDate;
  final double unitCost;
  final double remainingQty;
  final DateTime createdAt;
  const Lot({
    required this.id,
    required this.ingredientId,
    this.supplierId,
    required this.receivedDate,
    this.expiryDate,
    required this.unitCost,
    required this.remainingQty,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ingredient_id'] = Variable<int>(ingredientId);
    if (!nullToAbsent || supplierId != null) {
      map['supplier_id'] = Variable<int>(supplierId);
    }
    map['received_date'] = Variable<DateTime>(receivedDate);
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<DateTime>(expiryDate);
    }
    map['unit_cost'] = Variable<double>(unitCost);
    map['remaining_qty'] = Variable<double>(remainingQty);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LotsCompanion toCompanion(bool nullToAbsent) {
    return LotsCompanion(
      id: Value(id),
      ingredientId: Value(ingredientId),
      supplierId: supplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierId),
      receivedDate: Value(receivedDate),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      unitCost: Value(unitCost),
      remainingQty: Value(remainingQty),
      createdAt: Value(createdAt),
    );
  }

  factory Lot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lot(
      id: serializer.fromJson<int>(json['id']),
      ingredientId: serializer.fromJson<int>(json['ingredientId']),
      supplierId: serializer.fromJson<int?>(json['supplierId']),
      receivedDate: serializer.fromJson<DateTime>(json['receivedDate']),
      expiryDate: serializer.fromJson<DateTime?>(json['expiryDate']),
      unitCost: serializer.fromJson<double>(json['unitCost']),
      remainingQty: serializer.fromJson<double>(json['remainingQty']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ingredientId': serializer.toJson<int>(ingredientId),
      'supplierId': serializer.toJson<int?>(supplierId),
      'receivedDate': serializer.toJson<DateTime>(receivedDate),
      'expiryDate': serializer.toJson<DateTime?>(expiryDate),
      'unitCost': serializer.toJson<double>(unitCost),
      'remainingQty': serializer.toJson<double>(remainingQty),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Lot copyWith({
    int? id,
    int? ingredientId,
    Value<int?> supplierId = const Value.absent(),
    DateTime? receivedDate,
    Value<DateTime?> expiryDate = const Value.absent(),
    double? unitCost,
    double? remainingQty,
    DateTime? createdAt,
  }) => Lot(
    id: id ?? this.id,
    ingredientId: ingredientId ?? this.ingredientId,
    supplierId: supplierId.present ? supplierId.value : this.supplierId,
    receivedDate: receivedDate ?? this.receivedDate,
    expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
    unitCost: unitCost ?? this.unitCost,
    remainingQty: remainingQty ?? this.remainingQty,
    createdAt: createdAt ?? this.createdAt,
  );
  Lot copyWithCompanion(LotsCompanion data) {
    return Lot(
      id: data.id.present ? data.id.value : this.id,
      ingredientId: data.ingredientId.present
          ? data.ingredientId.value
          : this.ingredientId,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      receivedDate: data.receivedDate.present
          ? data.receivedDate.value
          : this.receivedDate,
      expiryDate: data.expiryDate.present
          ? data.expiryDate.value
          : this.expiryDate,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
      remainingQty: data.remainingQty.present
          ? data.remainingQty.value
          : this.remainingQty,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lot(')
          ..write('id: $id, ')
          ..write('ingredientId: $ingredientId, ')
          ..write('supplierId: $supplierId, ')
          ..write('receivedDate: $receivedDate, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('unitCost: $unitCost, ')
          ..write('remainingQty: $remainingQty, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ingredientId,
    supplierId,
    receivedDate,
    expiryDate,
    unitCost,
    remainingQty,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lot &&
          other.id == this.id &&
          other.ingredientId == this.ingredientId &&
          other.supplierId == this.supplierId &&
          other.receivedDate == this.receivedDate &&
          other.expiryDate == this.expiryDate &&
          other.unitCost == this.unitCost &&
          other.remainingQty == this.remainingQty &&
          other.createdAt == this.createdAt);
}

class LotsCompanion extends UpdateCompanion<Lot> {
  final Value<int> id;
  final Value<int> ingredientId;
  final Value<int?> supplierId;
  final Value<DateTime> receivedDate;
  final Value<DateTime?> expiryDate;
  final Value<double> unitCost;
  final Value<double> remainingQty;
  final Value<DateTime> createdAt;
  const LotsCompanion({
    this.id = const Value.absent(),
    this.ingredientId = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.receivedDate = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.remainingQty = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LotsCompanion.insert({
    this.id = const Value.absent(),
    required int ingredientId,
    this.supplierId = const Value.absent(),
    required DateTime receivedDate,
    this.expiryDate = const Value.absent(),
    required double unitCost,
    required double remainingQty,
    this.createdAt = const Value.absent(),
  }) : ingredientId = Value(ingredientId),
       receivedDate = Value(receivedDate),
       unitCost = Value(unitCost),
       remainingQty = Value(remainingQty);
  static Insertable<Lot> custom({
    Expression<int>? id,
    Expression<int>? ingredientId,
    Expression<int>? supplierId,
    Expression<DateTime>? receivedDate,
    Expression<DateTime>? expiryDate,
    Expression<double>? unitCost,
    Expression<double>? remainingQty,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ingredientId != null) 'ingredient_id': ingredientId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (receivedDate != null) 'received_date': receivedDate,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (unitCost != null) 'unit_cost': unitCost,
      if (remainingQty != null) 'remaining_qty': remainingQty,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LotsCompanion copyWith({
    Value<int>? id,
    Value<int>? ingredientId,
    Value<int?>? supplierId,
    Value<DateTime>? receivedDate,
    Value<DateTime?>? expiryDate,
    Value<double>? unitCost,
    Value<double>? remainingQty,
    Value<DateTime>? createdAt,
  }) {
    return LotsCompanion(
      id: id ?? this.id,
      ingredientId: ingredientId ?? this.ingredientId,
      supplierId: supplierId ?? this.supplierId,
      receivedDate: receivedDate ?? this.receivedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      unitCost: unitCost ?? this.unitCost,
      remainingQty: remainingQty ?? this.remainingQty,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ingredientId.present) {
      map['ingredient_id'] = Variable<int>(ingredientId.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<int>(supplierId.value);
    }
    if (receivedDate.present) {
      map['received_date'] = Variable<DateTime>(receivedDate.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<double>(unitCost.value);
    }
    if (remainingQty.present) {
      map['remaining_qty'] = Variable<double>(remainingQty.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LotsCompanion(')
          ..write('id: $id, ')
          ..write('ingredientId: $ingredientId, ')
          ..write('supplierId: $supplierId, ')
          ..write('receivedDate: $receivedDate, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('unitCost: $unitCost, ')
          ..write('remainingQty: $remainingQty, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $StockMovementsTable extends StockMovements
    with TableInfo<$StockMovementsTable, StockMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lotIdMeta = const VerificationMeta('lotId');
  @override
  late final GeneratedColumn<int> lotId = GeneratedColumn<int>(
    'lot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lots (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lotId,
    type,
    quantity,
    occurredAt,
    memo,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockMovement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lot_id')) {
      context.handle(
        _lotIdMeta,
        lotId.isAcceptableOrUnknown(data['lot_id']!, _lotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lotIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockMovement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lot_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StockMovementsTable createAlias(String alias) {
    return $StockMovementsTable(attachedDatabase, alias);
  }
}

class StockMovement extends DataClass implements Insertable<StockMovement> {
  final int id;
  final int lotId;
  final String type;
  final double quantity;
  final DateTime occurredAt;
  final String? memo;
  final DateTime createdAt;
  const StockMovement({
    required this.id,
    required this.lotId,
    required this.type,
    required this.quantity,
    required this.occurredAt,
    this.memo,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lot_id'] = Variable<int>(lotId);
    map['type'] = Variable<String>(type);
    map['quantity'] = Variable<double>(quantity);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StockMovementsCompanion toCompanion(bool nullToAbsent) {
    return StockMovementsCompanion(
      id: Value(id),
      lotId: Value(lotId),
      type: Value(type),
      quantity: Value(quantity),
      occurredAt: Value(occurredAt),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      createdAt: Value(createdAt),
    );
  }

  factory StockMovement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockMovement(
      id: serializer.fromJson<int>(json['id']),
      lotId: serializer.fromJson<int>(json['lotId']),
      type: serializer.fromJson<String>(json['type']),
      quantity: serializer.fromJson<double>(json['quantity']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      memo: serializer.fromJson<String?>(json['memo']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lotId': serializer.toJson<int>(lotId),
      'type': serializer.toJson<String>(type),
      'quantity': serializer.toJson<double>(quantity),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'memo': serializer.toJson<String?>(memo),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StockMovement copyWith({
    int? id,
    int? lotId,
    String? type,
    double? quantity,
    DateTime? occurredAt,
    Value<String?> memo = const Value.absent(),
    DateTime? createdAt,
  }) => StockMovement(
    id: id ?? this.id,
    lotId: lotId ?? this.lotId,
    type: type ?? this.type,
    quantity: quantity ?? this.quantity,
    occurredAt: occurredAt ?? this.occurredAt,
    memo: memo.present ? memo.value : this.memo,
    createdAt: createdAt ?? this.createdAt,
  );
  StockMovement copyWithCompanion(StockMovementsCompanion data) {
    return StockMovement(
      id: data.id.present ? data.id.value : this.id,
      lotId: data.lotId.present ? data.lotId.value : this.lotId,
      type: data.type.present ? data.type.value : this.type,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      memo: data.memo.present ? data.memo.value : this.memo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockMovement(')
          ..write('id: $id, ')
          ..write('lotId: $lotId, ')
          ..write('type: $type, ')
          ..write('quantity: $quantity, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, lotId, type, quantity, occurredAt, memo, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMovement &&
          other.id == this.id &&
          other.lotId == this.lotId &&
          other.type == this.type &&
          other.quantity == this.quantity &&
          other.occurredAt == this.occurredAt &&
          other.memo == this.memo &&
          other.createdAt == this.createdAt);
}

class StockMovementsCompanion extends UpdateCompanion<StockMovement> {
  final Value<int> id;
  final Value<int> lotId;
  final Value<String> type;
  final Value<double> quantity;
  final Value<DateTime> occurredAt;
  final Value<String?> memo;
  final Value<DateTime> createdAt;
  const StockMovementsCompanion({
    this.id = const Value.absent(),
    this.lotId = const Value.absent(),
    this.type = const Value.absent(),
    this.quantity = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  StockMovementsCompanion.insert({
    this.id = const Value.absent(),
    required int lotId,
    required String type,
    required double quantity,
    required DateTime occurredAt,
    this.memo = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : lotId = Value(lotId),
       type = Value(type),
       quantity = Value(quantity),
       occurredAt = Value(occurredAt);
  static Insertable<StockMovement> custom({
    Expression<int>? id,
    Expression<int>? lotId,
    Expression<String>? type,
    Expression<double>? quantity,
    Expression<DateTime>? occurredAt,
    Expression<String>? memo,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lotId != null) 'lot_id': lotId,
      if (type != null) 'type': type,
      if (quantity != null) 'quantity': quantity,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (memo != null) 'memo': memo,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  StockMovementsCompanion copyWith({
    Value<int>? id,
    Value<int>? lotId,
    Value<String>? type,
    Value<double>? quantity,
    Value<DateTime>? occurredAt,
    Value<String?>? memo,
    Value<DateTime>? createdAt,
  }) {
    return StockMovementsCompanion(
      id: id ?? this.id,
      lotId: lotId ?? this.lotId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      occurredAt: occurredAt ?? this.occurredAt,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lotId.present) {
      map['lot_id'] = Variable<int>(lotId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementsCompanion(')
          ..write('id: $id, ')
          ..write('lotId: $lotId, ')
          ..write('type: $type, ')
          ..write('quantity: $quantity, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('memo: $memo, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SuppliersTable suppliers = $SuppliersTable(this);
  late final $IngredientsTable ingredients = $IngredientsTable(this);
  late final $LotsTable lots = $LotsTable(this);
  late final $StockMovementsTable stockMovements = $StockMovementsTable(this);
  late final SupplierDao supplierDao = SupplierDao(this as AppDatabase);
  late final IngredientDao ingredientDao = IngredientDao(this as AppDatabase);
  late final LotDao lotDao = LotDao(this as AppDatabase);
  late final StockMovementDao stockMovementDao = StockMovementDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    suppliers,
    ingredients,
    lots,
    stockMovements,
  ];
}

typedef $$SuppliersTableCreateCompanionBuilder =
    SuppliersCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> contact,
      Value<String?> memo,
      Value<DateTime> createdAt,
    });
typedef $$SuppliersTableUpdateCompanionBuilder =
    SuppliersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> contact,
      Value<String?> memo,
      Value<DateTime> createdAt,
    });

final class $$SuppliersTableReferences
    extends BaseReferences<_$AppDatabase, $SuppliersTable, Supplier> {
  $$SuppliersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LotsTable, List<Lot>> _lotsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.lots,
    aliasName: 'suppliers__id__lots__supplier_id',
  );

  $$LotsTableProcessedTableManager get lotsRefs {
    final manager = $$LotsTableTableManager(
      $_db,
      $_db.lots,
    ).filter((f) => f.supplierId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contact => $composableBuilder(
    column: $table.contact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> lotsRefs(
    Expression<bool> Function($$LotsTableFilterComposer f) f,
  ) {
    final $$LotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lots,
      getReferencedColumn: (t) => t.supplierId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LotsTableFilterComposer(
            $db: $db,
            $table: $db.lots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contact => $composableBuilder(
    column: $table.contact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get contact =>
      $composableBuilder(column: $table.contact, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> lotsRefs<T extends Object>(
    Expression<T> Function($$LotsTableAnnotationComposer a) f,
  ) {
    final $$LotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lots,
      getReferencedColumn: (t) => t.supplierId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LotsTableAnnotationComposer(
            $db: $db,
            $table: $db.lots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SuppliersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SuppliersTable,
          Supplier,
          $$SuppliersTableFilterComposer,
          $$SuppliersTableOrderingComposer,
          $$SuppliersTableAnnotationComposer,
          $$SuppliersTableCreateCompanionBuilder,
          $$SuppliersTableUpdateCompanionBuilder,
          (Supplier, $$SuppliersTableReferences),
          Supplier,
          PrefetchHooks Function({bool lotsRefs})
        > {
  $$SuppliersTableTableManager(_$AppDatabase db, $SuppliersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> contact = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SuppliersCompanion(
                id: id,
                name: name,
                contact: contact,
                memo: memo,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> contact = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SuppliersCompanion.insert(
                id: id,
                name: name,
                contact: contact,
                memo: memo,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SuppliersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lotsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (lotsRefs) db.lots],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lotsRefs)
                    await $_getPrefetchedData<Supplier, $SuppliersTable, Lot>(
                      currentTable: table,
                      referencedTable: $$SuppliersTableReferences
                          ._lotsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SuppliersTableReferences(db, table, p0).lotsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.supplierId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SuppliersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SuppliersTable,
      Supplier,
      $$SuppliersTableFilterComposer,
      $$SuppliersTableOrderingComposer,
      $$SuppliersTableAnnotationComposer,
      $$SuppliersTableCreateCompanionBuilder,
      $$SuppliersTableUpdateCompanionBuilder,
      (Supplier, $$SuppliersTableReferences),
      Supplier,
      PrefetchHooks Function({bool lotsRefs})
    >;
typedef $$IngredientsTableCreateCompanionBuilder =
    IngredientsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> category,
      required String baseUnit,
      required String purchaseUnit,
      required double conversionFactor,
      required bool isExpiryTracked,
      Value<double?> safetyStockQty,
      Value<DateTime> createdAt,
    });
typedef $$IngredientsTableUpdateCompanionBuilder =
    IngredientsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> category,
      Value<String> baseUnit,
      Value<String> purchaseUnit,
      Value<double> conversionFactor,
      Value<bool> isExpiryTracked,
      Value<double?> safetyStockQty,
      Value<DateTime> createdAt,
    });

final class $$IngredientsTableReferences
    extends BaseReferences<_$AppDatabase, $IngredientsTable, Ingredient> {
  $$IngredientsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LotsTable, List<Lot>> _lotsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.lots,
    aliasName: 'ingredients__id__lots__ingredient_id',
  );

  $$LotsTableProcessedTableManager get lotsRefs {
    final manager = $$LotsTableTableManager(
      $_db,
      $_db.lots,
    ).filter((f) => f.ingredientId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$IngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUnit => $composableBuilder(
    column: $table.baseUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purchaseUnit => $composableBuilder(
    column: $table.purchaseUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get conversionFactor => $composableBuilder(
    column: $table.conversionFactor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isExpiryTracked => $composableBuilder(
    column: $table.isExpiryTracked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get safetyStockQty => $composableBuilder(
    column: $table.safetyStockQty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> lotsRefs(
    Expression<bool> Function($$LotsTableFilterComposer f) f,
  ) {
    final $$LotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lots,
      getReferencedColumn: (t) => t.ingredientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LotsTableFilterComposer(
            $db: $db,
            $table: $db.lots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUnit => $composableBuilder(
    column: $table.baseUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purchaseUnit => $composableBuilder(
    column: $table.purchaseUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get conversionFactor => $composableBuilder(
    column: $table.conversionFactor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isExpiryTracked => $composableBuilder(
    column: $table.isExpiryTracked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get safetyStockQty => $composableBuilder(
    column: $table.safetyStockQty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get baseUnit =>
      $composableBuilder(column: $table.baseUnit, builder: (column) => column);

  GeneratedColumn<String> get purchaseUnit => $composableBuilder(
    column: $table.purchaseUnit,
    builder: (column) => column,
  );

  GeneratedColumn<double> get conversionFactor => $composableBuilder(
    column: $table.conversionFactor,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isExpiryTracked => $composableBuilder(
    column: $table.isExpiryTracked,
    builder: (column) => column,
  );

  GeneratedColumn<double> get safetyStockQty => $composableBuilder(
    column: $table.safetyStockQty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> lotsRefs<T extends Object>(
    Expression<T> Function($$LotsTableAnnotationComposer a) f,
  ) {
    final $$LotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lots,
      getReferencedColumn: (t) => t.ingredientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LotsTableAnnotationComposer(
            $db: $db,
            $table: $db.lots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IngredientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IngredientsTable,
          Ingredient,
          $$IngredientsTableFilterComposer,
          $$IngredientsTableOrderingComposer,
          $$IngredientsTableAnnotationComposer,
          $$IngredientsTableCreateCompanionBuilder,
          $$IngredientsTableUpdateCompanionBuilder,
          (Ingredient, $$IngredientsTableReferences),
          Ingredient,
          PrefetchHooks Function({bool lotsRefs})
        > {
  $$IngredientsTableTableManager(_$AppDatabase db, $IngredientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IngredientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IngredientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> baseUnit = const Value.absent(),
                Value<String> purchaseUnit = const Value.absent(),
                Value<double> conversionFactor = const Value.absent(),
                Value<bool> isExpiryTracked = const Value.absent(),
                Value<double?> safetyStockQty = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => IngredientsCompanion(
                id: id,
                name: name,
                category: category,
                baseUnit: baseUnit,
                purchaseUnit: purchaseUnit,
                conversionFactor: conversionFactor,
                isExpiryTracked: isExpiryTracked,
                safetyStockQty: safetyStockQty,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> category = const Value.absent(),
                required String baseUnit,
                required String purchaseUnit,
                required double conversionFactor,
                required bool isExpiryTracked,
                Value<double?> safetyStockQty = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => IngredientsCompanion.insert(
                id: id,
                name: name,
                category: category,
                baseUnit: baseUnit,
                purchaseUnit: purchaseUnit,
                conversionFactor: conversionFactor,
                isExpiryTracked: isExpiryTracked,
                safetyStockQty: safetyStockQty,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$IngredientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lotsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (lotsRefs) db.lots],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lotsRefs)
                    await $_getPrefetchedData<
                      Ingredient,
                      $IngredientsTable,
                      Lot
                    >(
                      currentTable: table,
                      referencedTable: $$IngredientsTableReferences
                          ._lotsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$IngredientsTableReferences(db, table, p0).lotsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.ingredientId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$IngredientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IngredientsTable,
      Ingredient,
      $$IngredientsTableFilterComposer,
      $$IngredientsTableOrderingComposer,
      $$IngredientsTableAnnotationComposer,
      $$IngredientsTableCreateCompanionBuilder,
      $$IngredientsTableUpdateCompanionBuilder,
      (Ingredient, $$IngredientsTableReferences),
      Ingredient,
      PrefetchHooks Function({bool lotsRefs})
    >;
typedef $$LotsTableCreateCompanionBuilder =
    LotsCompanion Function({
      Value<int> id,
      required int ingredientId,
      Value<int?> supplierId,
      required DateTime receivedDate,
      Value<DateTime?> expiryDate,
      required double unitCost,
      required double remainingQty,
      Value<DateTime> createdAt,
    });
typedef $$LotsTableUpdateCompanionBuilder =
    LotsCompanion Function({
      Value<int> id,
      Value<int> ingredientId,
      Value<int?> supplierId,
      Value<DateTime> receivedDate,
      Value<DateTime?> expiryDate,
      Value<double> unitCost,
      Value<double> remainingQty,
      Value<DateTime> createdAt,
    });

final class $$LotsTableReferences
    extends BaseReferences<_$AppDatabase, $LotsTable, Lot> {
  $$LotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $IngredientsTable _ingredientIdTable(_$AppDatabase db) =>
      db.ingredients.createAlias('lots__ingredient_id__ingredients__id');

  $$IngredientsTableProcessedTableManager get ingredientId {
    final $_column = $_itemColumn<int>('ingredient_id')!;

    final manager = $$IngredientsTableTableManager(
      $_db,
      $_db.ingredients,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ingredientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SuppliersTable _supplierIdTable(_$AppDatabase db) =>
      db.suppliers.createAlias('lots__supplier_id__suppliers__id');

  $$SuppliersTableProcessedTableManager? get supplierId {
    final $_column = $_itemColumn<int>('supplier_id');
    if ($_column == null) return null;
    final manager = $$SuppliersTableTableManager(
      $_db,
      $_db.suppliers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supplierIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StockMovementsTable, List<StockMovement>>
  _stockMovementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stockMovements,
    aliasName: 'lots__id__stock_movements__lot_id',
  );

  $$StockMovementsTableProcessedTableManager get stockMovementsRefs {
    final manager = $$StockMovementsTableTableManager(
      $_db,
      $_db.stockMovements,
    ).filter((f) => f.lotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockMovementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LotsTableFilterComposer extends Composer<_$AppDatabase, $LotsTable> {
  $$LotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedDate => $composableBuilder(
    column: $table.receivedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get remainingQty => $composableBuilder(
    column: $table.remainingQty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$IngredientsTableFilterComposer get ingredientId {
    final $$IngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableFilterComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliersTableFilterComposer get supplierId {
    final $$SuppliersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplierId,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableFilterComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> stockMovementsRefs(
    Expression<bool> Function($$StockMovementsTableFilterComposer f) f,
  ) {
    final $$StockMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.lotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableFilterComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LotsTableOrderingComposer extends Composer<_$AppDatabase, $LotsTable> {
  $$LotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedDate => $composableBuilder(
    column: $table.receivedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get remainingQty => $composableBuilder(
    column: $table.remainingQty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$IngredientsTableOrderingComposer get ingredientId {
    final $$IngredientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableOrderingComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliersTableOrderingComposer get supplierId {
    final $$SuppliersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplierId,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableOrderingComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LotsTable> {
  $$LotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedDate => $composableBuilder(
    column: $table.receivedDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  GeneratedColumn<double> get remainingQty => $composableBuilder(
    column: $table.remainingQty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$IngredientsTableAnnotationComposer get ingredientId {
    final $$IngredientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableAnnotationComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliersTableAnnotationComposer get supplierId {
    final $$SuppliersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplierId,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableAnnotationComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> stockMovementsRefs<T extends Object>(
    Expression<T> Function($$StockMovementsTableAnnotationComposer a) f,
  ) {
    final $$StockMovementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stockMovements,
      getReferencedColumn: (t) => t.lotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StockMovementsTableAnnotationComposer(
            $db: $db,
            $table: $db.stockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LotsTable,
          Lot,
          $$LotsTableFilterComposer,
          $$LotsTableOrderingComposer,
          $$LotsTableAnnotationComposer,
          $$LotsTableCreateCompanionBuilder,
          $$LotsTableUpdateCompanionBuilder,
          (Lot, $$LotsTableReferences),
          Lot,
          PrefetchHooks Function({
            bool ingredientId,
            bool supplierId,
            bool stockMovementsRefs,
          })
        > {
  $$LotsTableTableManager(_$AppDatabase db, $LotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ingredientId = const Value.absent(),
                Value<int?> supplierId = const Value.absent(),
                Value<DateTime> receivedDate = const Value.absent(),
                Value<DateTime?> expiryDate = const Value.absent(),
                Value<double> unitCost = const Value.absent(),
                Value<double> remainingQty = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LotsCompanion(
                id: id,
                ingredientId: ingredientId,
                supplierId: supplierId,
                receivedDate: receivedDate,
                expiryDate: expiryDate,
                unitCost: unitCost,
                remainingQty: remainingQty,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ingredientId,
                Value<int?> supplierId = const Value.absent(),
                required DateTime receivedDate,
                Value<DateTime?> expiryDate = const Value.absent(),
                required double unitCost,
                required double remainingQty,
                Value<DateTime> createdAt = const Value.absent(),
              }) => LotsCompanion.insert(
                id: id,
                ingredientId: ingredientId,
                supplierId: supplierId,
                receivedDate: receivedDate,
                expiryDate: expiryDate,
                unitCost: unitCost,
                remainingQty: remainingQty,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$LotsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                ingredientId = false,
                supplierId = false,
                stockMovementsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stockMovementsRefs) db.stockMovements,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (ingredientId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.ingredientId,
                                    referencedTable: $$LotsTableReferences
                                        ._ingredientIdTable(db),
                                    referencedColumn: $$LotsTableReferences
                                        ._ingredientIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (supplierId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.supplierId,
                                    referencedTable: $$LotsTableReferences
                                        ._supplierIdTable(db),
                                    referencedColumn: $$LotsTableReferences
                                        ._supplierIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stockMovementsRefs)
                        await $_getPrefetchedData<
                          Lot,
                          $LotsTable,
                          StockMovement
                        >(
                          currentTable: table,
                          referencedTable: $$LotsTableReferences
                              ._stockMovementsRefsTable(db),
                          managerFromTypedResult: (p0) => $$LotsTableReferences(
                            db,
                            table,
                            p0,
                          ).stockMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.lotId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LotsTable,
      Lot,
      $$LotsTableFilterComposer,
      $$LotsTableOrderingComposer,
      $$LotsTableAnnotationComposer,
      $$LotsTableCreateCompanionBuilder,
      $$LotsTableUpdateCompanionBuilder,
      (Lot, $$LotsTableReferences),
      Lot,
      PrefetchHooks Function({
        bool ingredientId,
        bool supplierId,
        bool stockMovementsRefs,
      })
    >;
typedef $$StockMovementsTableCreateCompanionBuilder =
    StockMovementsCompanion Function({
      Value<int> id,
      required int lotId,
      required String type,
      required double quantity,
      required DateTime occurredAt,
      Value<String?> memo,
      Value<DateTime> createdAt,
    });
typedef $$StockMovementsTableUpdateCompanionBuilder =
    StockMovementsCompanion Function({
      Value<int> id,
      Value<int> lotId,
      Value<String> type,
      Value<double> quantity,
      Value<DateTime> occurredAt,
      Value<String?> memo,
      Value<DateTime> createdAt,
    });

final class $$StockMovementsTableReferences
    extends BaseReferences<_$AppDatabase, $StockMovementsTable, StockMovement> {
  $$StockMovementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LotsTable _lotIdTable(_$AppDatabase db) =>
      db.lots.createAlias('stock_movements__lot_id__lots__id');

  $$LotsTableProcessedTableManager get lotId {
    final $_column = $_itemColumn<int>('lot_id')!;

    final manager = $$LotsTableTableManager(
      $_db,
      $_db.lots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StockMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LotsTableFilterComposer get lotId {
    final $$LotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lotId,
      referencedTable: $db.lots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LotsTableFilterComposer(
            $db: $db,
            $table: $db.lots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LotsTableOrderingComposer get lotId {
    final $$LotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lotId,
      referencedTable: $db.lots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LotsTableOrderingComposer(
            $db: $db,
            $table: $db.lots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LotsTableAnnotationComposer get lotId {
    final $$LotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lotId,
      referencedTable: $db.lots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LotsTableAnnotationComposer(
            $db: $db,
            $table: $db.lots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StockMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StockMovementsTable,
          StockMovement,
          $$StockMovementsTableFilterComposer,
          $$StockMovementsTableOrderingComposer,
          $$StockMovementsTableAnnotationComposer,
          $$StockMovementsTableCreateCompanionBuilder,
          $$StockMovementsTableUpdateCompanionBuilder,
          (StockMovement, $$StockMovementsTableReferences),
          StockMovement,
          PrefetchHooks Function({bool lotId})
        > {
  $$StockMovementsTableTableManager(
    _$AppDatabase db,
    $StockMovementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockMovementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lotId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => StockMovementsCompanion(
                id: id,
                lotId: lotId,
                type: type,
                quantity: quantity,
                occurredAt: occurredAt,
                memo: memo,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lotId,
                required String type,
                required double quantity,
                required DateTime occurredAt,
                Value<String?> memo = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => StockMovementsCompanion.insert(
                id: id,
                lotId: lotId,
                type: type,
                quantity: quantity,
                occurredAt: occurredAt,
                memo: memo,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StockMovementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (lotId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.lotId,
                                referencedTable: $$StockMovementsTableReferences
                                    ._lotIdTable(db),
                                referencedColumn:
                                    $$StockMovementsTableReferences
                                        ._lotIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StockMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StockMovementsTable,
      StockMovement,
      $$StockMovementsTableFilterComposer,
      $$StockMovementsTableOrderingComposer,
      $$StockMovementsTableAnnotationComposer,
      $$StockMovementsTableCreateCompanionBuilder,
      $$StockMovementsTableUpdateCompanionBuilder,
      (StockMovement, $$StockMovementsTableReferences),
      StockMovement,
      PrefetchHooks Function({bool lotId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db, _db.suppliers);
  $$IngredientsTableTableManager get ingredients =>
      $$IngredientsTableTableManager(_db, _db.ingredients);
  $$LotsTableTableManager get lots => $$LotsTableTableManager(_db, _db.lots);
  $$StockMovementsTableTableManager get stockMovements =>
      $$StockMovementsTableTableManager(_db, _db.stockMovements);
}
