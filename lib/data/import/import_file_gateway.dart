import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../export/purchase_order_exporter.dart' show savedDisplayText;
import 'import_template.dart';

/// 양식 저장과 엑셀 파일 선택. 화면과 테스트는 이 인터페이스만 안다.
abstract class ImportFileGateway {
  /// 양식을 저장한다. 저장했으면 화면에 보여 줄 문구, 취소했으면 null.
  Future<String?> saveTemplate(Uint8List bytes);

  /// 엑셀 파일을 고른다. 취소했으면 null.
  Future<Uint8List?> pickWorkbook();
}

class FilePickerImportFileGateway implements ImportFileGateway {
  @override
  Future<String?> saveTemplate(Uint8List bytes) async {
    final saved = await FilePicker.saveFile(
      fileName: importTemplateFileName,
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      dialogTitle: '업로드 양식 저장',
    );
    return savedDisplayText(saved, importTemplateFileName);
  }

  @override
  Future<Uint8List?> pickWorkbook() async {
    final file = await FilePicker.pickFile(
      dialogTitle: '엑셀 파일 선택',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (file == null) return null;
    // 플랫폼마다 파일을 가리키는 방식이 달라서(경로, content 주소) 파일을 직접
    // 읽지 않고 선택 결과가 주는 읽기 함수를 쓴다.
    return file.readAsBytes();
  }
}

final importFileGatewayProvider = Provider<ImportFileGateway>(
  (ref) => FilePickerImportFileGateway(),
);
