// 사장용 사용 설명서 PDF를 만든다.
//
// 실행: dart run tool/make_manual.dart <캡처가 들어 있는 폴더>
// 입력: 캡처 폴더의 번호 붙은 PNG (아래 _imageFiles), assets/fonts/NanumGothic-*.ttf
// 출력: docs/manual/owner-manual.pdf
//
// 캡처 이미지는 저장소에 두지 않는다. 폴더 경로를 인자로 받아 읽기만 한다.
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _ink = PdfColor.fromInt(0xFF0F172A);
const _body = PdfColor.fromInt(0xFF334155);
const _muted = PdfColor.fromInt(0xFF64748B);
const _line = PdfColor.fromInt(0xFFCBD5E1);
const _soft = PdfColor.fromInt(0xFFF1F5F9);
const _warnBg = PdfColor.fromInt(0xFFFEF2F2);
const _warnLine = PdfColor.fromInt(0xFFFECACA);
const _warnInk = PdfColor.fromInt(0xFF991B1B);

/// 설명서에서 쓰는 이름 → 캡처 폴더의 파일 번호.
const _imageFiles = {
  'login_pin': 27,
  'login_email': 29,
  'stock_today': 30,
  'adjust_dispose': 31,
  'adjust_adjust': 32,
  'inbound_form': 33,
  'count_blank': 34,
  'count_confirm': 35,
  'count_done': 36,
  'shortage': 37,
  'po_form': 38,
  'suppliers': 39,
  'supplier_dialog': 40,
  'items': 41,
  'item_dialog': 42,
  'staff_add': 43,
  'store_dialog': 45,
  'safety_dialog': 48,
  'stock_past': 49,
  'inbound_all': 50,
  'calendar': 51,
  'stores': 52,
};

late String _imageDir;

pw.Font _font(String file) =>
    pw.Font.ttf(File('assets/fonts/$file').readAsBytesSync().buffer.asByteData());

pw.Widget _h1(String text) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 6, bottom: 10),
  padding: const pw.EdgeInsets.only(bottom: 4),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.2)),
  ),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _ink),
  ),
);

pw.Widget _h2(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink),
  ),
);

/// 소제목, 설명, 이미지를 한 덩어리로 묶는다. Container는 쪽 사이에서 쪼개지지
/// 않으므로, 덩어리가 남은 자리에 안 들어가면 통째로 다음 쪽으로 간다 (제목은
/// 윗쪽에, 이미지는 다음 쪽에 떨어지지 않는다).
pw.Widget _keep(List<pw.Widget> children) => pw.Container(
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: children,
  ),
);

pw.Widget _p(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 4),
  child: pw.Text(
    text,
    style: const pw.TextStyle(fontSize: 10.5, color: _body, lineSpacing: 3),
  ),
);

pw.Widget _step(String number, String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 3),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 18,
        child: pw.Text(
          number,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 10.5, color: _body, lineSpacing: 3),
        ),
      ),
    ],
  ),
);

pw.Widget _box(String title, List<String> lines, {bool warn = false}) =>
    pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: warn ? _warnBg : _soft,
        border: pw.Border.all(color: warn ? _warnLine : _line),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: warn ? _warnInk : _ink,
            ),
          ),
          pw.SizedBox(height: 3),
          for (final line in lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '· $line',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: warn ? _warnInk : _body,
                  lineSpacing: 2,
                ),
              ),
            ),
        ],
      ),
    );

/// 캡처에서 보여 줄 세로 구간: (보일 높이 비율, 세로 위치 1=위, 0=가운데; PDF는 y가 위로 늘어난다).
/// 화면 아래쪽이 비어 있는 캡처는 잘라서 한 줄의 높이를 줄인다. 높이가 크면
/// 쪽 끝에 안 들어가 통째로 다음 쪽으로 밀리며 빈 공간이 생긴다.
/// 원본 이미지는 그대로 두고 PDF 안에서만 자른다.
const _crops = <String, (double, double)>{
  'login_pin': (0.6, 0.0),
  'login_email': (0.6, 0.0),
  // 매장·거래처 관리는 + 버튼(오른쪽 아래)을 본문이 설명하므로 자르지 않는다.
  // 짝이 되는 등록 창 이미지도 같은 높이로 맞추려고 자르지 않는다.
  'staff_add': (0.5, 1.0),
  'safety_dialog': (0.6, 0.0),
  'inbound_form': (0.85, 1.0),
  'shortage': (0.5, 1.0),
  'adjust_dispose': (0.7, 1.0),
  'adjust_adjust': (0.7, 1.0),
};

pw.Widget _shot(String name, String caption, {double width = 250}) {
  final bytes = File('$_imageDir/${_imageFiles[name]}.png').readAsBytesSync();
  pw.Widget image = pw.Image(pw.MemoryImage(bytes), width: width);
  final crop = _crops[name];
  if (crop != null) {
    image = pw.ClipRect(
      child: pw.Align(
        alignment: pw.Alignment(0, crop.$2),
        heightFactor: crop.$1,
        child: image,
      ),
    );
  }
  return pw.SizedBox(
    width: width,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
          child: image,
        ),
        pw.SizedBox(height: 3),
        pw.Text(caption, style: const pw.TextStyle(fontSize: 9, color: _muted)),
      ],
    ),
  );
}

// Row는 쪽을 넘어 쪼개지지 않아서 이미지 줄 전체가 다음 쪽으로 밀리며 빈 공간이
// 생긴다. Wrap은 쪽 경계에서 이미지를 한 장씩 나눠 놓을 수 있다.
pw.Widget _shots(List<pw.Widget> items) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 6),
  child: pw.Wrap(
    spacing: 12,
    runSpacing: 8,
    crossAxisAlignment: pw.WrapCrossAlignment.start,
    children: items,
  ),
);

pw.Widget _table(List<List<String>> rows) => pw.Container(
  margin: const pw.EdgeInsets.symmetric(vertical: 6),
  decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
  child: pw.Table(
    columnWidths: const {
      0: pw.FixedColumnWidth(120),
      1: pw.FlexColumnWidth(),
    },
    border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line)),
    children: [
      for (final row in rows)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                row[0],
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                row[1],
                style: const pw.TextStyle(fontSize: 10, color: _body, lineSpacing: 2),
              ),
            ),
          ],
        ),
    ],
  ),
);

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('사용법: dart run tool/make_manual.dart <캡처 폴더>');
    exit(64);
  }
  _imageDir = args.first;
  final doc = pw.Document(
    title: '재고관리 사용 설명서 (사장용)',
    theme: pw.ThemeData.withFont(
      base: _font('NanumGothic-Regular.ttf'),
      bold: _font('NanumGothic-Bold.ttf'),
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 44),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '재고관리 사용 설명서 · 사장용   ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
      ),
      build: (context) => [
        pw.Text(
          '재고관리 사용 설명서',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: _ink),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '사장 계정 기준 · 매장 설정부터 매일 업무까지',
          style: const pw.TextStyle(fontSize: 11, color: _muted),
        ),
        pw.SizedBox(height: 12),
        _box('먼저 알아 두세요', [
          '인터넷이 끊겨도 입고, 실사, 폐기는 저장됩니다. 연결되면 자동으로 서버에 올라가고 다른 기기에도 반영됩니다.',
          '화면 왼쪽 아래의 동기화 아이콘 아래 시각이 마지막 동기화 시각입니다. 아이콘을 누르면 바로 동기화합니다.',
          'PIN은 6자리 숫자입니다.',
          '직원 계정은 소속 매장의 재고만 볼 수 있습니다. 매장 관리와 직원 추가는 사장만 쓸 수 있습니다.',
          '폰에서는 아래쪽 탭(재고, 입고, 실사, 부족, 더보기)을 씁니다. 거래처, 품목, 매장, 직원 추가는 더보기 안에 있습니다.',
        ]),

        _h1('1. 로그인'),
        _step('1)', '앱을 켜면 이 기기에서 로그인한 적 있는 이름 목록이 나옵니다. 이름을 눌러 PIN 6자리를 입력하고 로그인합니다.'),
        _step('2)', '이 기기에서 처음이면 목록이 비어 있습니다. "이메일로 로그인"을 눌러 이메일과 PIN을 입력합니다.'),
        _step('3)', '로그아웃은 화면 왼쪽 아래의 문 모양 아이콘입니다 (폰은 더보기 > 로그아웃).'),
        _shots([
          _shot('login_pin', '이름을 고르고 PIN 입력'),
          _shot('login_email', '처음 쓰는 기기는 이메일로 로그인'),
        ]),

        _h1('2. 처음 설정 (한 번만)'),
        _p('아래 순서대로 하면 편합니다. 거래처와 품목이 있어야 입고를 등록할 수 있습니다.'),
        _keep([
          _h2('1단계. 매장 등록'),
          _step('1)', '매장 관리를 열고 오른쪽 아래 + 버튼을 누릅니다.'),
          _step('2)', '매장 이름을 입력하고 저장합니다.'),
          _shots([
            _shot('stores', '매장 관리'),
            _shot('store_dialog', '매장 등록'),
          ]),
        ]),
        _keep([
          _h2('2단계. 직원 추가'),
          _step('1)', '직원 추가에서 이름, PIN 6자리, 소속 매장을 고르고 추가를 누릅니다.'),
          _step('2)', '직원은 이 이름과 PIN으로 로그인하고, 소속 매장의 재고만 봅니다.'),
          _shots([_shot('staff_add', '직원 추가')]),
        ]),
        pw.SizedBox(height: 18),
        _keep([
          _h2('3단계. 거래처 등록'),
          _step('1)', '거래처 관리에서 + 버튼을 누르고 이름과 연락처를 입력해 저장합니다.'),
          _shots([
            _shot('suppliers', '거래처 관리'),
            _shot('supplier_dialog', '거래처 등록'),
          ]),
        ]),
        // 품목 등록은 표, 경고, 이미지가 이어져 있어서 새 쪽에서 여유 있게 시작한다.
        pw.NewPage(),
        _h2('4단계. 품목 등록'),
        _step('1)', '품목 관리에서 + 버튼을 누르고 아래 칸을 채웁니다.'),
        pw.SizedBox(height: 10),
        _table([
          ['품목명', '재고 화면에 보이는 이름입니다.'],
          ['기본 단위', 'g, ml, ea 중 하나입니다. 재고 수량은 이 단위로 계산됩니다.'],
          ['구매 단위', '주문하는 단위입니다. 예: 박스, 포, EA.'],
          ['구매단위 1개 = base unit 몇 개', '구매 단위 한 개가 기본 단위로 몇 개인지입니다. 예: 쌀 1포 = 20kg이면 기본 단위 g, 값 20000.'],
          ['안전재고 (선택)', '이 수량보다 적어지면 부족 재고에 나타납니다. 비우면 알림에서 제외됩니다.'],
          ['유통기한 관리', '켜 두면 입고할 때 유통기한을 입력하고, 기한이 3일 이내이면 "임박"으로 표시됩니다.'],
        ]),
        _box('등록할 때 꼭 확인하세요', [
          '용기, 장갑처럼 유통기한이 없는 품목은 "유통기한 관리"를 끄고 저장하세요. 기본값은 켜져 있습니다.',
          '등록한 뒤에는 품목명, 단위, 환산 값, 유통기한 관리를 바꿀 수 없습니다. 안전재고만 다시 고칠 수 있습니다.',
        ], warn: true),
        pw.SizedBox(height: 12),
        _shots([
          _shot('items', '품목 관리 (품목을 누르면 안전재고 설정)'),
          _shot('item_dialog', '품목 등록'),
        ]),
        pw.SizedBox(height: 14),
        _keep([
          _h2('안전재고 나중에 바꾸기'),
          _step('1)', '품목 관리에서 품목을 누르면 안전재고 창이 열립니다. 수량을 입력하고 저장합니다. 비우면 그 품목은 부족 알림에서 제외됩니다.'),
          _shots([_shot('safety_dialog', '품목별 안전재고 설정')]),
        ]),

        _h1('3. 입고 등록 (물건이 들어올 때)'),
        _step('1)', '사장 계정은 오른쪽 위에서 매장을 먼저 고릅니다. 매장을 고르지 않으면 "매장을 선택해주세요"가 나옵니다.'),
        _step('2)', '거래처와 품목을 고릅니다. 목록에 없으면 "+ 신규 거래처 등록", "+ 신규 품목 등록"을 누릅니다.'),
        _step('3)', '수량은 구매 단위로 입력합니다 (예: 1 KG). 아래에 기본 단위로 환산한 값이 바로 표시됩니다.'),
        _step('4)', '단가를 입력합니다. 유통기한 관리 품목은 유통기한도 고릅니다. 저장을 누르면 끝입니다.'),
        pw.SizedBox(height: 10),
        _shots([_shot('inbound_form', '입고 등록')]),

        pw.SizedBox(height: 30),
        _h1('4. 마감 실사 (재고를 직접 세어 맞출 때)'),
        _step('1)', '매장을 고르면 품목별 이론재고(앱이 계산한 재고)가 나옵니다.'),
        _step('2)', '실제로 센 수량을 기본 단위로 입력합니다. 비워 둔 품목은 건너뜁니다.'),
        _step('3)', '실사 제출을 누르면 이론 재고, 실사 수량, 차이를 보여 주는 확인 창이 나옵니다. 맞으면 확정을 누릅니다.'),
        _step('4)', '차이는 조정 기록으로 남고, 재고가 센 수량에 맞게 바뀝니다.'),
        pw.SizedBox(height: 10),
        _shots([
          _shot('count_blank', '실사 수량 입력', width: 163),
          _shot('count_confirm', '차이 확인', width: 163),
          _shot('count_done', '반영 완료', width: 163),
        ]),

        pw.NewPage(),
        _h1('5. 재고 조회'),
        _p('품목별로 카드가 나오고, 카드 안에 입고 건(로트)마다 유통기한, 매장, 수량이 한 줄씩 보입니다.'),
        _step('·', '오른쪽 위에서 매장을 고르거나 "전체 합산"으로 모든 매장을 한꺼번에 봅니다.'),
        _step('·', '요약에 재고 품목 수와 유통기한 임박 건수가 보입니다. 임박한 건은 빨갛게 표시됩니다.'),
        _step('·', '한 품목의 입고 건이 4개 이상이면 3개만 보이고 "나머지 N개 보기"를 누르면 펼쳐집니다. 임박한 건은 접혀 있어도 항상 보입니다.'),
        _shots([_shot('stock_today', '재고 조회 (전체 합산)', width: 300)]),
        _h2('지난 날짜의 재고 보기'),
        _step('1)', '위쪽 날짜 버튼을 눌러 날짜를 고릅니다. 오늘 이후는 고를 수 없습니다.'),
        _step('2)', '그날 끝 기준의 재고와 그날 들어온 입고가 나옵니다. "N월 N일 기준 (조회 전용)" 안내가 보입니다.'),
        _step('3)', '입고 카드에는 처음 3건만 보이고 "전체 N건 보기"를 누르면 그날 입고 전체가 나옵니다.'),
        _step('4)', '지난 날짜 화면은 보기만 가능합니다. "오늘로 돌아가기"를 누르면 오늘로 돌아갑니다.'),
        _shots([
          _shot('calendar', '날짜 선택'),
          _shot('stock_past', '지난 날짜 (조회 전용)'),
        ]),
        _shots([_shot('inbound_all', '"전체 N건 보기"를 누른 화면')]),

        pw.SizedBox(height: 20),
        _h1('6. 폐기와 조정'),
        _p('상했거나 버린 재고, 또는 센 수량과 다른 재고를 고칠 때 씁니다.'),
        _step('1)', '재고 조회에서 고칠 입고 건(줄)을 누릅니다.'),
        _step('2)', '유형을 고릅니다. "폐기"는 버린 만큼 줄이고, "조정"은 증가 또는 감소를 고릅니다.'),
        _step('3)', '수량과 메모(선택)를 입력하고 저장합니다.'),
        _box('기억할 점', [
          '기록은 지우거나 고칠 수 없고 새 기록이 쌓입니다. 잘못 입력했다면 반대로 조정해서 바로잡으세요.',
          '지난 날짜를 보는 중에는 줄을 눌러도 이 화면이 열리지 않습니다.',
        ]),
        _shots([
          _shot('adjust_dispose', '폐기'),
          _shot('adjust_adjust', '조정 (증가/감소 선택)'),
        ]),

        pw.NewPage(),
        _h1('7. 부족 재고와 발주서'),
        _step('1)', '부족 재고 탭에는 안전재고보다 적어진 품목이 매장별로 나옵니다. 탭의 빨간 숫자는 부족한 품목 수입니다.'),
        _step('2)', '발주서는 매장 하나 단위로 만듭니다. 오른쪽 위에서 매장을 고르면 "발주서 만들기"가 켜집니다 (사장만, 전체 합산에서는 불가).'),
        _step('3)', '거래처를 고르면 부족한 품목이 목록으로 나옵니다. 체크와 수량을 조정합니다. 수량은 구매 단위 기준으로 부족분을 올림해서 채워 줍니다.'),
        _step('4)', '"PDF 저장" 또는 "엑셀 저장"을 누르고 저장할 위치를 고릅니다.'),
        _shots([
          _shot('shortage', '부족 재고'),
          _shot('po_form', '발주서 만들기'),
        ]),

        _h1('자주 묻는 질문'),
        _h2('입고를 잘못 넣었어요.'),
        _p('기록은 수정하지 못합니다. 재고 조회에서 그 입고 건을 눌러 "폐기" 또는 "조정(감소)"으로 줄여 주세요.'),
        _h2('직원 폰에 다른 매장 재고가 안 보여요.'),
        _p('정상입니다. 직원은 소속 매장의 재고만 볼 수 있습니다. 매장을 바꾸려면 직원 계정을 새로 만들어 주세요.'),
        _h2('다른 기기에 입고가 안 보여요.'),
        _p('왼쪽 아래 동기화 아이콘의 시각을 확인하고 아이콘을 눌러 보세요. 인터넷이 연결되어 있으면 곧 반영됩니다.'),
      ],
    ),
  );

  final out = File('docs/manual/owner-manual.pdf');
  out.parent.createSync(recursive: true);
  doc.save().then((bytes) {
    out.writeAsBytesSync(bytes);
    stdout.writeln('wrote ${out.path}');
  });
}
