import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/purchase_order.dart';
import 'purchase_order_pdf.dart';
import 'purchase_order_xlsx.dart';

const regularFontAsset = 'assets/fonts/NanumGothic-Regular.ttf';
const boldFontAsset = 'assets/fonts/NanumGothic-Bold.ttf';

/// 발주서를 파일로 저장한다. 화면과 테스트는 이 인터페이스만 안다.
abstract class PurchaseOrderExporter {
  /// 저장했으면 화면에 보여줄 문구(Windows는 경로, Android는 파일 이름),
  /// 사용자가 저장 창을 취소했으면 null.
  Future<String?> save(PurchaseOrder order, PurchaseOrderFormat format);
}

/// 저장 창을 띄워 파일을 쓴다. 저장한 곳의 주소를 돌려주고, 취소하면 null.
typedef SaveFileFn =
    Future<Uri?> Function({
      required String fileName,
      required Uint8List bytes,
      required String mimeType,
    });

typedef LoadFontFn = Future<ByteData> Function(String assetPath);

/// 저장 결과를 화면에 보여줄 문구로 바꾼다. 취소했으면 null.
///
/// Windows는 `file:` 주소라 실제 경로를 보여준다. Android는 `content:`
/// 주소라 사람이 읽을 수 없으므로 파일 이름만 보여준다.
String? savedDisplayText(Uri? saved, String fileName) {
  if (saved == null) return null;
  if (saved.scheme == 'file') return saved.toFilePath();
  return fileName;
}

class FilePurchaseOrderExporter implements PurchaseOrderExporter {
  FilePurchaseOrderExporter({SaveFileFn? saveFile, LoadFontFn? loadFont})
    : _saveFile = saveFile ?? _pickAndSave,
      _loadFont = loadFont ?? rootBundle.load;

  final SaveFileFn _saveFile;
  final LoadFontFn _loadFont;

  /// 시스템의 "다른 이름으로 저장" 창에서 위치를 고르게 한다. 폰에서 앱 전용
  /// 폴더에 조용히 저장하면 사용자가 파일을 찾을 수 없다.
  static Future<Uri?> _pickAndSave({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: '발주서 저장',
    );
  }

  @override
  Future<String?> save(PurchaseOrder order, PurchaseOrderFormat format) async {
    final Uint8List bytes;
    switch (format) {
      case PurchaseOrderFormat.xlsx:
        bytes = buildPurchaseOrderXlsx(order);
      case PurchaseOrderFormat.pdf:
        bytes = await buildPurchaseOrderPdf(
          order,
          regularFont: await _loadFont(regularFontAsset),
          boldFont: await _loadFont(boldFontAsset),
        );
    }

    final fileName = purchaseOrderFileName(order, format);
    final saved = await _saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: format.mimeType,
    );
    return savedDisplayText(saved, fileName);
  }
}

final purchaseOrderExporterProvider = Provider<PurchaseOrderExporter>(
  (ref) => FilePurchaseOrderExporter(),
);
