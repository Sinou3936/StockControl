import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/purchase_order.dart';

/// 발주서를 PDF 파일 바이트로 만든다.
///
/// 한글이 깨지지 않으려면 한글 글꼴이 필요하다. 글꼴 파일은 호출하는 쪽이
/// 읽어서 넘긴다 — 테스트가 실제 글꼴로 만들어 볼 수 있게 하려는 것이다.
/// 글꼴은 PDF 안에 쓴 글자만 담겨서 파일이 수십 KB에 그친다.
Future<Uint8List> buildPurchaseOrderPdf(
  PurchaseOrder order, {
  required ByteData regularFont,
  required ByteData boldFont,
}) {
  final regular = pw.Font.ttf(regularFont);
  final bold = pw.Font.ttf(boldFont);
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  // 줄이 많으면 여러 쪽으로 나뉘도록 MultiPage를 쓴다.
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Text('발주서', style: pw.TextStyle(font: bold, fontSize: 24)),
        pw.SizedBox(height: 16),
        pw.Text('발주일: ${formatPurchaseOrderDate(order.date)}'),
        pw.Text('매장: ${order.store.name}'),
        pw.Text('거래처: ${order.supplier.name}'),
        pw.Text('연락처: ${order.supplier.contact ?? ''}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['품목', '수량', '단위', '비고'],
          data: [
            for (final line in order.lines)
              [
                line.ingredient.name,
                '${line.qty}',
                line.ingredient.purchaseUnit,
                '',
              ],
          ],
          cellAlignments: {1: pw.Alignment.centerRight},
          cellHeight: 28,
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(4),
          },
        ),
      ],
    ),
  );

  return doc.save();
}
