import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol/domain/excel_import/excel_import_types.dart';
import 'package:stockcontrol/domain/excel_import/import_validator.dart';

final now = DateTime(2026, 10, 12, 10, 0);

RawWorkbook book({
  List<List<Object?>> suppliers = const [],
  List<List<Object?>> ingredients = const [],
  List<List<Object?>> inbound = const [],
}) => RawWorkbook(
  suppliers: [kSupplierHeaders, ...suppliers],
  ingredients: [kIngredientHeaders, ...ingredients],
  inbound: [kInboundHeaders, ...inbound],
);

ImportValidation validate(
  RawWorkbook b, {
  Set<String> suppliers = const {},
  Map<String, ExistingIngredient> ingredients = const {},
}) => validateImport(
  b,
  existingSupplierNames: suppliers,
  existingIngredients: ingredients,
  now: now,
);

List<String> texts(ImportValidation v) => v.errors.map((e) => e.text).toList();

typedef ValidationPhones = ({List<String?> contacts, int restored});

/// 품목 시트 한 줄: 쌀, g, 포, 20000, 안전재고 없음, 예(기한 관리)
List<Object?> rice({Object? factor = 20000, Object? tracked = '아니오'}) => [
  '쌀',
  'g',
  '포',
  factor,
  null,
  tracked,
];

/// 입고 시트 한 줄.
List<Object?> inboundRow({
  Object? date = '2026-09-29',
  Object? supplier = '가나다상사',
  Object? item = '쌀',
  Object? qty = 2,
  Object? cost = 45000,
  Object? expiry,
}) => [date, supplier, item, qty, cost, expiry];

const _supplierSet = {'가나다상사'};

/// 쌀 품목 한 줄 + 입고 한 줄(들)로 검증한다. 거래처는 이미 등록되어 있다.
ImportValidation validateInbound(
  List<List<Object?>> inbound, {
  List<Object?>? ingredient,
}) => validate(
  book(ingredients: [ingredient ?? rice()], inbound: inbound),
  suppliers: _supplierSet,
);

const _existingRice = ExistingIngredient(
  baseUnit: 'g',
  purchaseUnit: '포',
  conversionFactor: 20000,
  isExpiryTracked: false,
);

void main() {
  group('머리글', () {
    test('빠진 머리글을 알려 주고 plan은 없다', () {
      final b = RawWorkbook(
        suppliers: [kSupplierHeaders],
        ingredients: [
          ['품목명', '기본 단위', '구매 단위', '안전재고', '유통기한 관리'],
        ],
        inbound: [kInboundHeaders],
      );
      final v = validate(b);
      expect(texts(v), ["품목 시트 1번째 줄: '환산계수' 열이 없습니다"]);
      expect(v.plan, isNull);
      expect(v.isValid, isFalse);
    });

    test('머리글이 하나씩 빠진 세 시트는 오류 세 개가 한 번에 나온다', () {
      final b = RawWorkbook(
        suppliers: [
          ['이름'],
        ],
        ingredients: [
          ['품목명', '기본 단위', '구매 단위', '환산계수', '안전재고'],
        ],
        inbound: [
          ['날짜', '거래처', '품목명', '수량', '단가'],
        ],
      );
      final v = validate(b);
      expect(texts(v), [
        "거래처 시트 1번째 줄: '연락처' 열이 없습니다",
        "품목 시트 1번째 줄: '유통기한 관리' 열이 없습니다",
        "입고 시트 1번째 줄: '유통기한' 열이 없습니다",
      ]);
      expect(v.plan, isNull);
    });

    test('머리글이 틀리면 데이터 줄 검사는 하지 않는다', () {
      final b = RawWorkbook(
        suppliers: [
          kSupplierHeaders,
          [null, 'x'], // 이름 비어 있음 -> 검사했다면 오류
        ],
        ingredients: [
          ['품목명', '기본 단위', '구매 단위', '안전재고', '유통기한 관리'],
          ['쌀', 'oz', null, 'abc', '네'],
        ],
        inbound: [kInboundHeaders, inboundRow(qty: 0)],
      );
      final v = validate(b);
      expect(texts(v), ["품목 시트 1번째 줄: '환산계수' 열이 없습니다"]);
    });

    test('열 순서를 바꿔도 통과하고 모르는 열은 무시한다', () {
      final b = RawWorkbook(
        suppliers: [
          ['연락처', '메모', '이름'],
          ['010-1111', '무시', '가나다상사'],
        ],
        ingredients: [
          ['환산계수', '품목명', '기본 단위', '비고', '구매 단위', '유통기한 관리', '안전재고'],
          [20000, '쌀', 'g', '무시', '포', '아니오', 5000],
        ],
        inbound: [
          ['품목명', '날짜', '단가', '거래처', '수량', '유통기한'],
          ['쌀', '2026-09-29', 45000, '가나다상사', 2, null],
        ],
      );
      final v = validate(b);
      expect(texts(v), isEmpty);
      final plan = v.plan!;
      expect(plan.newSuppliers.single.name, '가나다상사');
      expect(plan.newSuppliers.single.contact, '010-1111');
      expect(plan.newIngredients.single.safetyStockQty, 5000);
      expect(plan.inboundLines.single.baseQty, 40000);
      expect(plan.inboundLines.single.unitCost, 45000);
    });

    test('같은 머리글이 두 번 있으면 첫 번째 열이 이긴다', () {
      final b = RawWorkbook(
        suppliers: [kSupplierHeaders],
        ingredients: [
          [...kIngredientHeaders, '환산계수'],
          ['쌀', 'g', '포', 20000, null, '아니오', 1],
        ],
        inbound: [kInboundHeaders],
      );
      final v = validate(b);
      expect(texts(v), isEmpty);
      expect(v.plan!.newIngredients.single.conversionFactor, 20000);
    });

    test('빈 시트는 머리글마다 열이 없다는 오류를 내고 예외 없이 끝난다', () {
      final b = RawWorkbook(
        suppliers: [kSupplierHeaders],
        ingredients: [],
        inbound: [kInboundHeaders],
      );
      final v = validate(b);
      expect(texts(v), [
        for (final h in kIngredientHeaders) "품목 시트 1번째 줄: '$h' 열이 없습니다",
      ]);
      expect(v.plan, isNull);
    });
  });

  group('빈 양식', () {
    test('줄이 하나도 없으면 통과하고 입고는 비어 있다', () {
      final v = validate(book());
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines, isEmpty);
      expect(v.plan!.newSuppliers, isEmpty);
      expect(v.plan!.newIngredients, isEmpty);
    });
  });

  group('연락처 앞자리 0', () {
    // 엑셀은 숫자로 친 전화번호의 앞 0을 파일에 저장하기 전에 이미 지운다.
    // 9~10자리 숫자 칸은 앞에 0이 있었던 전화번호로 보고 되살린다.
    ValidationPhones phones(List<Object?> contacts) {
      final v = validate(
        book(
          suppliers: [
            for (var i = 0; i < contacts.length; i++) ['거래처$i', contacts[i]],
          ],
        ),
      );
      expect(v.isValid, isTrue);
      return (
        contacts: [for (final s in v.plan!.newSuppliers) s.contact],
        restored: v.plan!.restoredPhoneCount,
      );
    }

    test('숫자 칸 1012345678(휴대폰)과 212345678(서울)에 0을 붙인다', () {
      final r = phones([1012345678, 212345678]);
      expect(r.contacts, ['01012345678', '0212345678']);
      expect(r.restored, 2);
    });

    test('문자로 적힌 번호, 대시가 든 번호는 손대지 않는다', () {
      final r = phones(['01012345678', '010-1234-5678', '1012345678']);
      expect(r.contacts, ['01012345678', '010-1234-5678', '1012345678']);
      expect(r.restored, 0);
    });

    test('8자리 숫자(1588-1234 같은 대표번호)나 너무 긴 숫자는 추측하지 않는다', () {
      final r = phones([15881234, 12345678901]);
      expect(r.contacts, ['15881234', '12345678901']);
      expect(r.restored, 0);
    });

    test('이미 등록된 거래처의 연락처는 쓰지 않으므로 세지 않는다', () {
      final v = validate(
        book(
          suppliers: [
            ['가나다', 1012345678],
          ],
        ),
        suppliers: {'가나다'},
      );
      expect(v.plan!.restoredPhoneCount, 0);
    });
  });

  group('거래처 시트', () {
    test('이름이 비면 오류', () {
      final v = validate(
        book(
          suppliers: [
            [null, '010'],
          ],
        ),
      );
      expect(texts(v), ['거래처 시트 2번째 줄: 이름이 비어 있습니다']);
    });

    test('같은 이름이 두 번이면 두 번째 줄에 오류 (공백 차이도 같은 이름)', () {
      final v = validate(
        book(
          suppliers: [
            ['가나다 ', null],
            ['가나다', null],
          ],
        ),
      );
      expect(texts(v), ['거래처 시트 3번째 줄: 같은 이름이 시트 안에 두 번 있습니다 (2번째 줄과 같음)']);
    });

    test('이미 등록된 이름은 newSuppliers에 없다', () {
      final v = validate(
        book(
          suppliers: [
            ['가나다', '010'],
            ['라마바', '011'],
          ],
        ),
        suppliers: {'가나다'},
      );
      expect(v.isValid, isTrue);
      expect(v.plan!.newSuppliers.map((s) => s.name), ['라마바']);
    });

    test('연락처가 빈칸이면 contact는 null', () {
      final v = validate(
        book(
          suppliers: [
            ['가나다', null],
            ['라마바', '  '],
            ['사아자', ' 010 '],
          ],
        ),
      );
      final s = v.plan!.newSuppliers;
      expect(s[0].contact, isNull);
      expect(s[1].contact, isNull);
      expect(s[2].contact, '010');
    });
  });

  group('품목 시트', () {
    test('정상 줄은 NewIngredient로 나온다', () {
      final v = validate(book(ingredients: [rice()]));
      expect(v.isValid, isTrue);
      final i = v.plan!.newIngredients.single;
      expect(i.name, '쌀');
      expect(i.baseUnit, 'g');
      expect(i.purchaseUnit, '포');
      expect(i.conversionFactor, 20000);
      expect(i.safetyStockQty, isNull);
      expect(i.isExpiryTracked, isFalse);
    });

    test("기본 단위 'G'는 'g'로 읽는다", () {
      final v = validate(
        book(
          ingredients: [
            ['쌀', 'G', '포', 20000, null, '아니오'],
          ],
        ),
      );
      expect(v.plan!.newIngredients.single.baseUnit, 'g');
    });

    test("기본 단위 'kg'와 'L'도 받는다 (표기는 대소문자와 상관없이 정해진 모양으로)", () {
      final v = validate(
        book(
          ingredients: [
            ['쌀', ' KG ', '포', 20, null, '아니오'],
            ['우유', 'l', '팩', 1, null, '아니오'],
          ],
        ),
      );
      expect(v.isValid, isTrue);
      expect(v.plan!.newIngredients.map((i) => i.baseUnit), ['kg', 'L']);
    });

    test("허용하지 않는 기본 단위는 오류 (목록을 알려 준다)", () {
      final v = validate(
        book(
          ingredients: [
            ['쌀', 'oz', '포', 20000, null, '아니오'],
          ],
        ),
      );
      expect(texts(v), ['품목 시트 2번째 줄: 기본 단위는 g, kg, ml, L, ea 중 하나여야 합니다']);
    });

    test("이미 등록된 품목은 단위를 대소문자로 다르게 적어도 같은 단위로 본다", () {
      final v = validate(
        book(
          ingredients: [
            ['우유', 'l', '팩', 1, null, '아니오'],
          ],
        ),
        ingredients: {
          '우유': const ExistingIngredient(
            baseUnit: 'L',
            purchaseUnit: '팩',
            conversionFactor: 1,
            isExpiryTracked: false,
          ),
        },
      );
      expect(v.isValid, isTrue);
      expect(v.plan!.newIngredients, isEmpty);
    });

    for (final unit in <Object?>[10, '10', '2.5', ' 100 ']) {
      test('구매 단위에 숫자($unit)만 적으면 오류 (칸을 잘못 채운 것)', () {
        final v = validate(
          book(
            ingredients: [
              ['감자튀김', 'g', unit, 2500, null, '아니오'],
            ],
          ),
        );
        expect(texts(v), [
          '품목 시트 2번째 줄: 구매 단위에 숫자가 적혀 있습니다. '
              'EA, 포, 박스처럼 단위 이름을 적어 주세요 (몇 개인지는 환산계수 칸)',
        ]);
        expect(v.plan, isNull);
      });
    }

    test('숫자가 섞여도 단위 이름이면 받는다 (10KG, 2.5kg 박스)', () {
      final v = validate(
        book(
          ingredients: [
            ['감자튀김', 'g', '10KG', 10000, null, '아니오'],
            ['쌈무', 'g', '2.8kg팩', 2800, null, '아니오'],
            ['목장갑', 'ea', 'EA', 1, null, '아니오'],
          ],
        ),
      );
      expect(v.isValid, isTrue);
      expect(v.plan!.newIngredients.map((i) => i.purchaseUnit), [
        '10KG',
        '2.8kg팩',
        'EA',
      ]);
    });

    test('구매 단위 빈칸은 오류', () {
      final v = validate(
        book(
          ingredients: [
            ['쌀', 'g', null, 20000, null, '아니오'],
          ],
        ),
      );
      expect(texts(v), ['품목 시트 2번째 줄: 구매 단위가 비어 있습니다']);
    });

    for (final factor in <Object?>[0, -1, 'abc', null]) {
      test('환산계수 $factor 는 오류', () {
        final v = validate(book(ingredients: [rice(factor: factor)]));
        expect(texts(v), ['품목 시트 2번째 줄: 환산계수는 0보다 큰 숫자여야 합니다']);
      });
    }

    test('안전재고: 빈칸과 0은 null, 숫자는 그대로', () {
      final v = validate(
        book(
          ingredients: [
            ['쌀', 'g', '포', 20000, null, '아니오'],
            ['콩', 'g', '포', 1000, 0, '아니오'],
            ['팥', 'g', '포', 1000, 5000, '아니오'],
          ],
        ),
      );
      final i = v.plan!.newIngredients;
      expect(i[0].safetyStockQty, isNull);
      expect(i[1].safetyStockQty, isNull);
      expect(i[2].safetyStockQty, 5000);
    });

    for (final safety in <Object?>['abc', -1]) {
      test('안전재고 $safety 는 오류', () {
        final v = validate(
          book(
            ingredients: [
              ['쌀', 'g', '포', 20000, safety, '아니오'],
            ],
          ),
        );
        expect(texts(v), ['품목 시트 2번째 줄: 안전재고를 숫자로 적어 주세요 (비우면 알림에서 제외)']);
      });
    }

    test("유통기한 관리: '예'는 true, '아니오'와 빈칸은 false", () {
      final v = validate(
        book(
          ingredients: [
            ['쌀', 'g', '포', 20000, null, '예'],
            ['콩', 'g', '포', 1000, null, '아니오'],
            ['팥', 'g', '포', 1000, null, null],
          ],
        ),
      );
      final i = v.plan!.newIngredients;
      expect(i[0].isExpiryTracked, isTrue);
      expect(i[1].isExpiryTracked, isFalse);
      expect(i[2].isExpiryTracked, isFalse);
    });

    test("유통기한 관리 '네'는 오류", () {
      final v = validate(book(ingredients: [rice(tracked: '네')]));
      expect(texts(v), ["품목 시트 2번째 줄: 유통기한 관리는 '예' 또는 '아니오'로 적어 주세요"]);
    });

    test('품목명이 비면 오류', () {
      final v = validate(
        book(
          ingredients: [
            [null, 'g', '포', 20000, null, '아니오'],
          ],
        ),
      );
      expect(texts(v), ['품목 시트 2번째 줄: 품목명이 비어 있습니다']);
    });

    test('시트 안 같은 이름은 오류', () {
      final v = validate(book(ingredients: [rice(), rice()]));
      expect(texts(v), ['품목 시트 3번째 줄: 같은 이름이 시트 안에 두 번 있습니다']);
    });
  });

  group('이미 등록된 품목', () {
    test('이름과 단위·환산계수가 같으면 newIngredients에 없다', () {
      final v = validate(
        book(ingredients: [rice()]),
        ingredients: {'쌀': _existingRice},
      );
      expect(v.isValid, isTrue);
      expect(v.plan!.newIngredients, isEmpty);
    });

    test('환산계수가 다르면 오류', () {
      final v = validate(
        book(ingredients: [rice(factor: 10000)]),
        ingredients: {'쌀': _existingRice},
      );
      expect(texts(v), [
        '품목 시트 2번째 줄: 이미 등록된 품목과 기본 단위나 환산계수가 다릅니다 (등록된 값: g, 20000)',
      ]);
    });

    test('기본 단위가 다르면 같은 오류', () {
      final v = validate(
        book(
          ingredients: [
            ['쌀', 'ml', '포', 20000, null, '아니오'],
          ],
        ),
        ingredients: {'쌀': _existingRice},
      );
      expect(texts(v), [
        '품목 시트 2번째 줄: 이미 등록된 품목과 기본 단위나 환산계수가 다릅니다 (등록된 값: g, 20000)',
      ]);
    });

    test('유통기한 관리는 파일이 아니라 기존 값을 쓴다', () {
      final v = validate(
        book(
          ingredients: [rice(tracked: '예')],
          inbound: [inboundRow(expiry: '2026-12-31')],
        ),
        suppliers: _supplierSet,
        ingredients: {'쌀': _existingRice},
      );
      expect(v.isValid, isTrue);
      expect(v.plan!.ignoredExpiryCount, 1);
      expect(v.plan!.inboundLines.single.expiryDate, isNull);
    });

    test('품목 시트에 없어도 등록된 품목이면 입고에 쓸 수 있다', () {
      final v = validate(
        book(inbound: [inboundRow()]),
        suppliers: _supplierSet,
        ingredients: {'쌀': _existingRice},
      );
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines.single.baseQty, 40000);
    });
  });

  group('입고 정상', () {
    test('한 줄이 계획으로 나온다', () {
      final v = validateInbound([inboundRow()]);
      expect(v.isValid, isTrue);
      final plan = v.plan!;
      final line = plan.inboundLines.single;
      expect(line.receivedAt, DateTime(2026, 9, 29, 9));
      expect(line.baseQty, 40000);
      expect(line.purchaseQty, 2);
      expect(line.unitCost, 45000);
      expect(line.rowNumber, 2);
      expect(line.supplierName, '가나다상사');
      expect(line.ingredientName, '쌀');
      expect(line.purchaseUnit, '포');
      expect(line.baseUnit, 'g');
      expect(line.conversionFactor, 20000);
      expect(line.expiryDate, isNull);
      expect(plan.noPriceCount, 0);
    });

    test('거래처는 거래처 시트에 있어도 된다', () {
      final v = validate(
        book(
          suppliers: [
            ['가나다상사', '010'],
          ],
          ingredients: [rice()],
          inbound: [inboundRow()],
        ),
      );
      expect(v.isValid, isTrue);
      expect(v.plan!.newSuppliers.single.name, '가나다상사');
      expect(v.plan!.inboundLines, hasLength(1));
    });
  });

  group('입고 날짜', () {
    test('엑셀 날짜 셀, 2026-09-29, 26/09/29 모두 그날 09:00', () {
      final v = validateInbound([
        inboundRow(date: DateTime(2026, 9, 29, 13, 30)),
        inboundRow(date: '2026-09-29'),
        inboundRow(date: '26/09/29'),
      ]);
      expect(v.isValid, isTrue);
      expect(
        v.plan!.inboundLines.map((l) => l.receivedAt),
        everyElement(DateTime(2026, 9, 29, 9)),
      );
      expect(v.plan!.inboundLines, hasLength(3));
    });

    test('빈칸은 오류', () {
      final v = validateInbound([inboundRow(date: null)]);
      expect(texts(v), ['입고 시트 2번째 줄: 날짜가 비어 있습니다']);
    });

    test('읽을 수 없는 글자는 오류', () {
      final v = validateInbound([inboundRow(date: 'abc')]);
      expect(texts(v), ['입고 시트 2번째 줄: 날짜를 읽을 수 없습니다 (예: 2026-09-29)']);
    });

    test('오늘은 통과', () {
      final v = validateInbound([inboundRow(date: '2026-10-12')]);
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines.single.receivedAt, DateTime(2026, 10, 12, 9));
    });

    test('내일은 오류', () {
      final v = validateInbound([inboundRow(date: '2026-10-13')]);
      expect(texts(v), ['입고 시트 2번째 줄: 오늘 이후 날짜입니다']);
    });

    test('오늘 이후 날짜는 유통기한 오류를 한 번 더 내지 않는다', () {
      final v = validateInbound([
        inboundRow(date: '2026-10-13', expiry: '2026-10-01'),
      ], ingredient: rice(tracked: '예'));
      expect(texts(v), ['입고 시트 2번째 줄: 오늘 이후 날짜입니다']);
    });
  });

  group('입고 거래처·품목', () {
    test('거래처 빈칸은 오류', () {
      final v = validateInbound([inboundRow(supplier: null)]);
      expect(texts(v), ['입고 시트 2번째 줄: 거래처가 비어 있습니다']);
    });

    test('품목 빈칸은 오류', () {
      final v = validateInbound([inboundRow(item: null)]);
      expect(texts(v), ['입고 시트 2번째 줄: 품목명이 비어 있습니다']);
    });

    test('모르는 거래처 이름은 오류', () {
      final v = validateInbound([inboundRow(supplier: '가나다상사2')]);
      expect(texts(v), ['입고 시트 2번째 줄: 거래처 "가나다상사2"가 거래처 시트나 등록된 거래처에 없습니다']);
    });

    test('모르는 품목 이름은 오류', () {
      final v = validateInbound([inboundRow(item: '쌀2')]);
      expect(texts(v), ['입고 시트 2번째 줄: 품목 "쌀2"이(가) 품목 시트나 등록된 품목에 없습니다']);
    });

    test('앞뒤 공백은 같은 이름으로 본다', () {
      final v = validateInbound([inboundRow(item: ' 쌀 ', supplier: ' 가나다상사 ')]);
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines.single.ingredientName, '쌀');
      expect(v.plan!.inboundLines.single.supplierName, '가나다상사');
    });

    test('영문 대소문자만 다른 거래처는 다른 이름이다', () {
      final v = validate(
        book(
          suppliers: [
            ['CJ', null],
          ],
          ingredients: [rice()],
          inbound: [inboundRow(supplier: 'cj')],
        ),
      );
      expect(texts(v), ['입고 시트 2번째 줄: 거래처 "cj"가 거래처 시트나 등록된 거래처에 없습니다']);
    });

    test('대소문자가 다르면 다른 이름이다', () {
      final v = validate(
        book(
          ingredients: [
            ['Rice', 'g', '포', 20000, null, '아니오'],
          ],
          inbound: [inboundRow(item: 'rice')],
        ),
        suppliers: _supplierSet,
      );
      expect(texts(v), ['입고 시트 2번째 줄: 품목 "rice"이(가) 품목 시트나 등록된 품목에 없습니다']);
    });
  });

  group('수량', () {
    for (final qty in <Object?>[0, -1, 'abc', null, '1,5', 1e12]) {
      test('수량 $qty 는 오류', () {
        final v = validateInbound([inboundRow(qty: qty)]);
        expect(texts(v), ['입고 시트 2번째 줄: 수량은 0보다 큰 숫자여야 합니다']);
      });
    }

    test("' 5 ', '1,000', 2.5는 통과", () {
      final v = validateInbound([
        inboundRow(qty: ' 5 '),
        inboundRow(qty: '1,000'),
        inboundRow(qty: 2.5),
      ]);
      expect(v.isValid, isTrue);
      final lines = v.plan!.inboundLines;
      expect(lines.map((l) => l.purchaseQty), [5, 1000, 2.5]);
      expect(lines.map((l) => l.baseQty), [100000, 20000000, 50000]);
    });
  });

  group('단가', () {
    test('빈칸은 0이고 noPriceCount에 센다', () {
      final v = validateInbound([inboundRow(cost: null)]);
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines.single.unitCost, 0);
      expect(v.plan!.noPriceCount, 1);
    });

    test('0은 빈칸이 아니므로 noPriceCount에 안 센다', () {
      final v = validateInbound([inboundRow(cost: 0)]);
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines.single.unitCost, 0);
      expect(v.plan!.noPriceCount, 0);
    });

    for (final cost in <Object?>[-1, 'abc']) {
      test('단가 $cost 는 오류', () {
        final v = validateInbound([inboundRow(cost: cost)]);
        expect(texts(v), ['입고 시트 2번째 줄: 단가를 0 이상의 숫자로 적어 주세요 (비우면 0)']);
      });
    }
  });

  group('유통기한', () {
    test('유통기한 관리 품목이면 expiryDate에 들어간다', () {
      final v = validateInbound([
        inboundRow(expiry: '2026-12-31'),
      ], ingredient: rice(tracked: '예'));
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines.single.expiryDate, DateTime(2026, 12, 31));
      expect(v.plan!.ignoredExpiryCount, 0);
    });

    test('입고 날짜와 같은 날은 통과', () {
      final v = validateInbound([
        inboundRow(expiry: '2026-09-29'),
      ], ingredient: rice(tracked: '예'));
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines.single.expiryDate, DateTime(2026, 9, 29));
    });

    test('입고 날짜보다 이르면 오류', () {
      final v = validateInbound([
        inboundRow(expiry: '2026-09-28'),
      ], ingredient: rice(tracked: '예'));
      expect(texts(v), ['입고 시트 2번째 줄: 유통기한이 입고 날짜보다 이릅니다']);
    });

    test('읽을 수 없으면 오류', () {
      final v = validateInbound([
        inboundRow(expiry: 'abc'),
      ], ingredient: rice(tracked: '예'));
      expect(texts(v), ['입고 시트 2번째 줄: 유통기한을 읽을 수 없습니다 (예: 2026-12-31)']);
    });

    test('유통기한 관리가 아닌 품목의 값은 오류가 아니고 무시한다', () {
      final v = validateInbound([inboundRow(expiry: '2026-12-31')]);
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines.single.expiryDate, isNull);
      expect(v.plan!.ignoredExpiryCount, 1);
    });

    test('유통기한 관리가 아닌 품목에는 읽을 수 없는 글자를 적어도 오류가 아니다', () {
      final v = validateInbound([inboundRow(expiry: 'abc')]);
      expect(texts(v), isEmpty);
      expect(v.plan!.inboundLines.single.expiryDate, isNull);
      expect(v.plan!.ignoredExpiryCount, 1);
    });

    test('유통기한 관리가 아닌 품목에는 입고 날짜보다 이른 날짜를 적어도 오류가 아니다', () {
      final v = validateInbound([inboundRow(expiry: '2026-09-28')]);
      expect(texts(v), isEmpty);
      expect(v.plan!.inboundLines.single.expiryDate, isNull);
      expect(v.plan!.ignoredExpiryCount, 1);
    });
  });

  group('빈 줄', () {
    test('완전히 빈 줄은 건너뛰고 뒤 줄의 오류 번호는 엑셀 번호와 같다', () {
      final v = validateInbound([
        inboundRow(),
        [null, null, null, null, null, null],
        inboundRow(qty: null),
      ]);
      expect(texts(v), ['입고 시트 4번째 줄: 수량은 0보다 큰 숫자여야 합니다']);
    });

    test('공백만 든 줄도 빈 줄이다', () {
      final v = validateInbound([
        inboundRow(),
        [' ', '', null, ' ', null, null],
      ]);
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines, hasLength(1));
    });

    test('일부 칸만 빈 줄은 오류', () {
      final v = validateInbound([inboundRow(qty: null)]);
      expect(texts(v), ['입고 시트 2번째 줄: 수량은 0보다 큰 숫자여야 합니다']);
    });

    test('거래처·품목 시트의 빈 줄도 번호를 유지한다', () {
      final v = validate(
        book(
          suppliers: [
            ['가나다', null],
            [null, null],
            [null, '010'],
          ],
        ),
      );
      expect(texts(v), ['거래처 시트 4번째 줄: 이름이 비어 있습니다']);
    });
  });

  group('수식 칸', () {
    // 리더는 수식 칸을 '=결과글자'로 넘긴다 (읽는 쪽 테스트 참고).
    test('품목명 칸의 수식은 이름에 = 이 붙은 채 등록되지 않고 오류가 된다', () {
      final v = validate(
        book(
          ingredients: [
            ['=쌀', 'g', '포', 20000, null, '아니오'],
          ],
        ),
      );
      expect(texts(v), ['품목 시트 2번째 줄: 수식이 들어 있습니다 (1번째 칸). 값만 복사해 붙여넣어 주세요']);
      expect(v.plan, isNull);
    });

    test('거래처·입고 시트의 수식도 같은 오류, 같은 줄의 칸마다 하나가 아니라 줄마다 하나', () {
      final v = validate(
        book(
          suppliers: [
            ['=가나다', '=010'],
          ],
          inbound: [
            ['=A1', '=B1', '쌀', 1, null, null],
          ],
        ),
      );
      expect(texts(v), [
        '거래처 시트 2번째 줄: 수식이 들어 있습니다 (1번째 칸). 값만 복사해 붙여넣어 주세요',
        '입고 시트 2번째 줄: 수식이 들어 있습니다 (1번째 칸). 값만 복사해 붙여넣어 주세요',
      ]);
    });

    test('수식 오류가 있으면 다른 줄 검사는 하지 않는다 (같은 문제가 두 번 보이지 않게)', () {
      final v = validate(
        book(
          ingredients: [
            ['=쌀', 'g', '포', 20000, null, '아니오'],
          ],
          inbound: [inboundRow(qty: 0)], // 수식이 없는 줄의 다른 오류
        ),
        suppliers: _supplierSet,
      );
      expect(texts(v), ['품목 시트 2번째 줄: 수식이 들어 있습니다 (1번째 칸). 값만 복사해 붙여넣어 주세요']);
    });

    test('아래로 끌어 둔 수식의 결과가 빈 글자("=")인 줄은 빈 줄이다', () {
      final v = validateInbound([
        inboundRow(),
        ['=', '=', '=', '=', '=', '='],
      ]);
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines, hasLength(1));
    });

    test('머리글 칸의 수식은 보지 않는다', () {
      expect(validate(book()).isValid, isTrue);
    });
  });

  group('거의 같은 이름', () {
    test('품목 시트와 입고 시트의 이름이 NBSP·전각 공백만 달라도 같은 품목이다', () {
      final v = validate(
        book(
          ingredients: [
            ['청양 고추', 'g', '봉', 500, null, '아니오'],
          ],
          inbound: [inboundRow(item: '청양　고추')],
        ),
        suppliers: _supplierSet,
      );
      expect(v.isValid, isTrue);
      expect(v.plan!.newIngredients.single.name, '청양 고추');
      expect(v.plan!.inboundLines.single.ingredientName, '청양 고추');
    });

    test('이미 등록된 품목 이름과 NBSP만 달라도 새 품목이 생기지 않는다', () {
      final v = validate(
        book(
          ingredients: [
            ['청양 고추', 'g', '봉', 500, null, '아니오'],
          ],
        ),
        ingredients: {
          '청양 고추': const ExistingIngredient(
            baseUnit: 'g',
            purchaseUnit: '봉',
            conversionFactor: 500,
            isExpiryTracked: false,
          ),
        },
      );
      expect(v.isValid, isTrue);
      expect(v.plan!.newIngredients, isEmpty);
    });

    test('거래처도 같은 규칙이고, 시트 안에서 보이지 않는 차이로 두 번 쓰면 중복 오류', () {
      final v = validate(
        book(
          suppliers: [
            ['가나다 상사', null],
            ['가나다 상사', null],
          ],
        ),
      );
      expect(texts(v), ['거래처 시트 3번째 줄: 같은 이름이 시트 안에 두 번 있습니다 (2번째 줄과 같음)']);
    });

    test('글자가 하나라도 다르면 다른 이름이다 (조용히 합쳐지지 않는다)', () {
      final v = validateInbound([inboundRow(item: '쌀 ')], ingredient: rice());
      expect(v.isValid, isTrue);
      final w = validateInbound([inboundRow(item: '쌀알')]);
      expect(w.isValid, isFalse);
    });
  });

  group('오류 모으기', () {
    test('서로 다른 문제를 가진 두 줄은 줄 번호 순으로 오류 두 개', () {
      final v = validateInbound([inboundRow(date: 'abc'), inboundRow(qty: 0)]);
      expect(texts(v), [
        '입고 시트 2번째 줄: 날짜를 읽을 수 없습니다 (예: 2026-09-29)',
        '입고 시트 3번째 줄: 수량은 0보다 큰 숫자여야 합니다',
      ]);
      expect(v.plan, isNull);
    });

    test('오류가 되는 입고 줄 60개: 전체 60, 표시 50, 숨김 10', () {
      final v = validateInbound([
        for (var i = 0; i < 60; i++) inboundRow(qty: 0),
      ]);
      expect(v.errors.length, 60);
      expect(v.shownErrors.length, 50);
      expect(v.hiddenErrorCount, 10);
    });

    test('오류가 50개 이하면 숨김은 0', () {
      final v = validateInbound([inboundRow(qty: 0)]);
      expect(v.hiddenErrorCount, 0);
      expect(v.shownErrors.length, 1);
    });
  });

  group('줄 수 한도', () {
    test('입고 줄 3,001개는 오류 하나, 줄 검사는 하지 않는다', () {
      final v = validateInbound([
        for (var i = 0; i < 3001; i++) inboundRow(qty: 0),
      ]);
      expect(texts(v), ['입고 시트 1번째 줄: 입고 줄이 3,000개를 넘습니다 (3001개)']);
      expect(v.plan, isNull);
    });

    test('입고 줄 3,000개는 통과', () {
      final v = validateInbound([for (var i = 0; i < 3000; i++) inboundRow()]);
      expect(v.isValid, isTrue);
      expect(v.plan!.inboundLines, hasLength(3000));
    });

    test('빈 줄은 줄 수에 세지 않는다', () {
      final v = validateInbound([
        for (var i = 0; i < 3000; i++) inboundRow(),
        for (var i = 0; i < 10; i++) [null, null, null, null, null, null],
      ]);
      expect(v.isValid, isTrue);
    });
  });

  group('무효 품목 줄을 가리키는 입고', () {
    test('품목 줄 오류 하나뿐이고 입고에 품목 없음 오류가 따로 생기지 않는다', () {
      final v = validateInbound([inboundRow()], ingredient: rice(factor: 0));
      expect(texts(v), ['품목 시트 2번째 줄: 환산계수는 0보다 큰 숫자여야 합니다']);
    });

    test('불일치한 기존 품목을 쓰는 입고도 따로 알리지 않는다', () {
      final v = validate(
        book(ingredients: [rice(factor: 10000)], inbound: [inboundRow()]),
        suppliers: _supplierSet,
        ingredients: {'쌀': _existingRice},
      );
      expect(texts(v), [
        '품목 시트 2번째 줄: 이미 등록된 품목과 기본 단위나 환산계수가 다릅니다 (등록된 값: g, 20000)',
      ]);
    });
  });

  group('날짜 범위', () {
    test('firstDate와 lastDate는 입고 날짜의 최소·최대 (자정)', () {
      final v = validateInbound([
        inboundRow(date: '2026-09-29'),
        inboundRow(date: '2026-09-30'),
        inboundRow(date: '2026-09-29'),
      ]);
      expect(v.plan!.firstDate, DateTime(2026, 9, 29));
      expect(v.plan!.lastDate, DateTime(2026, 9, 30));
    });

    test('입고가 없으면 null', () {
      final v = validate(book());
      expect(v.plan!.firstDate, isNull);
      expect(v.plan!.lastDate, isNull);
    });
  });
}
