import 'dart:io';
import 'package:archive/archive.dart';

class WordService {
  /// Rút toàn bộ văn bản từ file Word .docx
  Future<String> extractText(String filePath) async {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Tìm file word/document.xml bên trong file .docx
      for (final file in archive) {
        if (file.name == 'word/document.xml') {
          final content = String.fromCharCodes(file.content as List<int>);
          // Lọc bỏ các thẻ XML <w:...>, chỉ giữ lại text
          final text = content
              .replaceAll(RegExp(r'<w:p[^>]*>'), '\n') // Xuống dòng khi hết đoạn văn
              .replaceAll(RegExp(r'<[^>]*>'), '')       // Xóa các tag XML
              .replaceAll(RegExp(r'\s+'), ' ')          // Chuẩn hóa khoảng trắng
              .trim();
          return text;
        }
      }
      return '';
    } catch (e) {
      print('Lỗi đọc file Word: $e');
      return '';
    }
  }
}