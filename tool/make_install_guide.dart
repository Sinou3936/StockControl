// 재고관리 앱 설치 방법 안내서 PDF를 만든다 (매장 PC·폰에 설치하는 사람용).
//
// 실행: dart run tool/make_install_guide.dart
// 입력: assets/fonts/NanumGothic-*.ttf (캡처 이미지는 쓰지 않는다)
// 출력: docs/manual/install-guide.pdf  (docs/manual/은 git이 무시한다)
//
// 설치 파일 이름·버전이 바뀌면 아래 _setupFile, _apkFile을 고친다.
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _setupFile = 'StockControl-Setup-1.0.0.exe';
const _apkFile = 'app-release.apk';

const _ink = PdfColor.fromInt(0xFF0F172A);
const _body = PdfColor.fromInt(0xFF334155);
const _muted = PdfColor.fromInt(0xFF64748B);
const _line = PdfColor.fromInt(0xFFCBD5E1);
const _soft = PdfColor.fromInt(0xFFF1F5F9);
const _warnBg = PdfColor.fromInt(0xFFFEF2F2);
const _warnLine = PdfColor.fromInt(0xFFFECACA);
const _warnInk = PdfColor.fromInt(0xFF991B1B);

pw.Font _font(String file) => pw.Font.ttf(
  File('assets/fonts/$file').readAsBytesSync().buffer.asByteData(),
);

pw.Widget _title(String title, String subtitle) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 22,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
      ),
    ),
    pw.SizedBox(height: 3),
    pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11, color: _muted)),
    pw.SizedBox(height: 14),
  ],
);

pw.Widget _h1(String text) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 12, bottom: 8),
  padding: const pw.EdgeInsets.only(bottom: 4),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.2)),
  ),
  child: pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 15,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  ),
);

pw.Widget _p(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 4),
  child: pw.Text(
    text,
    style: const pw.TextStyle(fontSize: 10.5, color: _body, lineSpacing: 3),
  ),
);

/// 번호가 붙은 순서 한 줄. 번호는 동그라미 안에 둔다.
pw.Widget _step(int number, String text, {String? detail}) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 17,
        height: 17,
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(
          color: _ink,
          shape: pw.BoxShape.circle,
        ),
        child: pw.Text(
          '$number',
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
      pw.SizedBox(width: 9),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              text,
              style: const pw.TextStyle(
                fontSize: 10.5,
                color: _body,
                lineSpacing: 3,
              ),
            ),
            if (detail != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  detail,
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: _muted,
                    lineSpacing: 2.5,
                  ),
                ),
              ),
          ],
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
                line,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: warn ? _warnInk : _body,
                  lineSpacing: 2.5,
                ),
              ),
            ),
        ],
      ),
    );

/// 문제와 해결을 두 칸으로 보여 주는 표.
pw.Widget _troubleTable(List<(String, String)> rows) => pw.Table(
  border: pw.TableBorder.all(color: _line, width: 0.6),
  columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3.4)},
  children: [
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _soft),
      children: [_cell('이런 때', bold: true), _cell('이렇게 하세요', bold: true)],
    ),
    for (final (problem, fix) in rows)
      pw.TableRow(children: [_cell(problem), _cell(fix)]),
  ],
);

pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
  child: pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 9.8,
      color: bold ? _ink : _body,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      lineSpacing: 2.5,
    ),
  ),
);

/// 덩어리가 남은 자리에 안 들어가면 통째로 다음 쪽으로 보낸다.
pw.Widget _keep(List<pw.Widget> children) => pw.Container(
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: children,
  ),
);

Future<void> main() async {
  final regular = _font('NanumGothic-Regular.ttf');
  final bold = _font('NanumGothic-Bold.ttf');

  final doc = pw.Document(
    title: '재고관리 앱 설치 방법',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 44, 44, 48),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '재고관리 앱 설치 방법  ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
      ),
      build: (context) => [
        _title('재고관리 앱 설치 방법', 'Windows PC와 안드로이드 폰에 설치하고 처음 로그인하는 방법'),
        _box('시작하기 전에 준비하세요', [
          '1. 설치 파일: 사장님께 직접 받은 파일만 설치하세요.',
          '    · Windows PC용: $_setupFile',
          '    · 안드로이드 폰용: $_apkFile',
          '2. 인터넷 연결: 처음 로그인할 때와 데이터를 서버와 맞출 때 필요합니다.',
          '3. 로그인 정보: 사장님은 이메일과 6자리 PIN, 직원은 사장님이 정해 준 이름과 6자리 PIN입니다.',
        ]),
        _h1('1. Windows PC에 설치'),
        _keep([
          _step(1, '받은 $_setupFile 을 더블클릭합니다.'),
          _step(
            2,
            '"Windows의 PC 보호" 파란 창이 나오면 [추가 정보]를 누르고 [실행]을 누릅니다.',
            detail:
                '설치 파일에 아직 마이크로소프트 서명이 없어서 나오는 안내입니다. 사장님께 직접 받은 파일일 때만 실행하세요.',
          ),
          _step(
            3,
            '설치 창에서 [다음]을 누릅니다. "바탕 화면에 바로 가기 만들기"에 체크하면 편합니다. 마지막에 [설치]를 누릅니다.',
            detail: '관리자 암호를 묻지 않습니다.',
          ),
          _step(4, '설치가 끝나면 "재고관리 실행"에 체크하고 [마침]을 누릅니다.'),
          _step(5, '다음부터는 바탕 화면이나 시작 메뉴의 "재고관리"를 눌러 실행합니다.'),
        ]),
        _h1('2. 안드로이드 폰에 설치'),
        _keep([
          _step(
            1,
            '받은 $_apkFile 파일을 폰으로 옮깁니다 (카카오톡 "나와의 채팅", 구글 드라이브, USB 등).',
          ),
          _step(2, '폰의 [내 파일]에서 그 파일을 눌러 엽니다.'),
          _step(
            3,
            '"보안을 위해 이 출처의 앱 설치가 차단되었습니다" 같은 안내가 나오면 [설정]을 누르고 "이 출처 허용"을 켠 다음 뒤로 돌아옵니다.',
            detail:
                '기종마다 문구가 조금 다릅니다. 앱이 아니라 파일을 연 앱(내 파일, 카카오톡 등)에 허용하는 것입니다.',
          ),
          _step(4, '[설치]를 누릅니다. "Play 프로텍트" 안내가 나오면 [설치 계속]을 누릅니다.'),
          _step(5, '설치가 끝나면 [열기]를 누릅니다. 설치한 뒤에는 위에서 켠 허용을 꺼 두는 것을 권합니다.'),
        ]),
        _h1('3. 처음 로그인'),
        _p('이 기기에서 처음 쓸 때는 이름 목록이 비어 있습니다. 사장님과 직원의 순서가 다릅니다.'),
        _keep([
          pw.Text(
            '사장님',
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 4),
          _step(1, '로그인 화면 아래의 "이메일로 로그인 (이 기기가 처음이신가요?)"을 누릅니다.'),
          _step(2, '이메일과 6자리 PIN을 입력하고 [로그인]을 누릅니다. 인터넷이 연결되어 있어야 합니다.'),
          _step(3, '한 번 로그인하면 다음부터는 이름 목록에서 이름을 눌러 PIN만 입력하면 됩니다.'),
        ]),
        pw.SizedBox(height: 6),
        _keep([
          pw.Text(
            '직원',
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 4),
          _p('직원 계정은 그 기기에서 사장님이 먼저 만들어 주어야 이름 목록에 나타납니다.'),
          _step(1, '사장님이 위의 방법으로 그 기기에서 사장님 계정으로 로그인합니다.'),
          _step(
            2,
            '메뉴의 [직원 추가]를 엽니다 (폰은 [더보기] > [직원 추가]). 이름, 6자리 PIN, 소속 매장을 고르고 [추가]를 누릅니다.',
          ),
          _step(3, '로그아웃합니다 (PC는 왼쪽 아래 문 모양 아이콘, 폰은 [더보기] > [로그아웃]).'),
          _step(4, '직원이 이름 목록에서 자기 이름을 눌러 PIN 6자리를 입력하고 로그인합니다.'),
        ]),
        _box('알아 두세요', [
          '· 직원 PIN은 사장님이 정해서 직원에게 알려 줍니다.',
          '· 직원은 소속 매장의 재고만 볼 수 있습니다.',
          '· 같은 직원을 다른 기기에서도 쓰려면 그 기기에서도 사장님이 직원을 추가해야 합니다.',
        ]),
        _h1('4. 업데이트와 제거'),
        _keep([
          _p(
            '새 버전이 나오면 새 설치 파일을 받아 같은 방법으로 실행하세요. 옛 버전 위에 설치되고 입력한 데이터는 그대로 남습니다. 실행 중인 앱은 먼저 닫아 주세요.',
          ),
          _p(
            '제거할 때는 Windows는 [설정] > [앱] > [설치된 앱]에서 "재고관리"를 제거하고, 폰은 앱을 길게 눌러 제거합니다. 제거 전에 앱의 [지금 동기화]를 눌러 데이터를 서버에 올려 두세요.',
          ),
        ]),
        _h1('5. 문제가 생기면'),
        _troubleTable(const [
          (
            '설치할 때 파란 경고창이 나온다',
            '[추가 정보]를 누르고 [실행]을 누르세요. 사장님께 직접 받은 파일일 때만 하세요.',
          ),
          (
            '폰에서 설치가 막힌다',
            '파일을 연 앱에 "이 출처 허용"을 켜세요 (위의 2번 3단계). 같은 앱이 이미 있어 안 되면 옛 앱을 지우고 다시 설치하세요.',
          ),
          (
            '"이 기기에서 온라인으로 로그인한 기록이 없습니다"',
            '인터넷에 연결한 뒤 로그인 화면 아래의 "이메일로 로그인"으로 처음 한 번 로그인하세요.',
          ),
          ('"PIN이 올바르지 않습니다"', 'PIN은 6자리 숫자입니다. 잊었으면 사장님께 문의하세요.'),
          ('내 이름이 목록에 없다', '그 기기에서 사장님이 [직원 추가]로 이름을 만들어 주어야 합니다 (위의 3번).'),
          (
            '재고나 입고가 다른 기기와 다르다',
            '인터넷에 연결되어 있는지 보고 [지금 동기화]를 눌러 보세요 (PC는 왼쪽 메뉴, 폰은 [더보기]).',
          ),
          (
            '설치했는데 앱이 바로 꺼진다 (PC)',
            '설치 파일을 한 번 더 실행해 다시 설치해 보세요. 계속되면 사장님을 통해 담당자에게 알려 주세요.',
          ),
        ]),
      ],
    ),
  );

  final out = File('docs/manual/install-guide.pdf')
    ..createSync(recursive: true);
  out.writeAsBytesSync(await doc.save());
  stdout.writeln('만들었습니다: ${out.path}');
}
