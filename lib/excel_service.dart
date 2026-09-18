import 'dart:io';
import 'package:flutter/foundation.dart'; // Sử dụng debugPrint, kIsWeb
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;

/// 1. Định nghĩa Data Model
class TestCase {
  String testCaseId;
  String useCaseName;
  String testDescription;
  String testSteps;
  String expectedResult;
  String actualResult;
  String status;

  TestCase({
    required this.testCaseId,
    required this.useCaseName,
    required this.testDescription,
    required this.testSteps,
    required this.expectedResult,
    required this.actualResult,
    this.status = 'Pending', // Mặc định là 'Pending'
  });
}

class ExcelService {
  /// 2. Chức năng Import (Đọc Excel)
  Future<List<TestCase>> readTestCasesFromExcel() async {
    List<TestCase> testCases = [];

    try {
      // Sử dụng file_picker để người dùng chọn file .xlsx
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true, // Bắt buộc cho Web
      );

      // Kiểm tra nếu người dùng đã chọn file
      if (result != null) {
        var bytes;
        if (kIsWeb) {
          bytes = result.files.single.bytes;
        } else {
          String? filePath = result.files.single.path;
          if (filePath != null) {
            bytes = File(filePath).readAsBytesSync();
          }
        }

        if (bytes == null) {
          debugPrint('Không thể đọc dữ liệu file.');
          return testCases;
        }
        var excel = Excel.decodeBytes(bytes);

        // Lấy sheet đầu tiên (mặc định)
        if (excel.tables.keys.isEmpty) {
          debugPrint('File Excel không có sheet nào.');
          return testCases;
        }
        String sheetName = excel.tables.keys.first;
        var table = excel.tables[sheetName];

        if (table != null) {
          // Duyệt qua các dòng, bắt đầu từ i = 1 để bỏ qua dòng đầu tiên (header)
          for (int i = 1; i < table.maxRows; i++) {
            var row = table.rows[i];

            // Nếu dòng trống (null) thì bỏ qua
            if (row.isEmpty) continue;

            try {
              // Map dữ liệu từ các cột vào class TestCase
              // Đảm bảo lấy đúng thứ tự cột từ 0 đến 6 và an toàn với null
              TestCase testCase = TestCase(
                testCaseId: row.length > 0 ? row[0]?.value?.toString() ?? '' : '',
                useCaseName: row.length > 1 ? row[1]?.value?.toString() ?? '' : '',
                testDescription: row.length > 2 ? row[2]?.value?.toString() ?? '' : '',
                testSteps: row.length > 3 ? row[3]?.value?.toString() ?? '' : '',
                expectedResult: row.length > 4 ? row[4]?.value?.toString() ?? '' : '',
                actualResult: row.length > 5 ? row[5]?.value?.toString() ?? '' : '',
                status: row.length > 6 ? (row[6]?.value?.toString() ?? 'Pending') : 'Pending',
              );

              testCases.add(testCase);
            } catch (rowError) {
              // Bắt lỗi trong quá trình đọc từng dòng và in ra log
              debugPrint('Lỗi khi parse dữ liệu ở dòng $i: $rowError');
            }
          }
        }
      } else {
        debugPrint('Người dùng đã hủy thao tác chọn file.');
      }
    } catch (e) {
      debugPrint('Lỗi khi mở/đọc file Excel: $e');
      throw Exception('Lỗi đọc file: $e'); // Ném lỗi ra để main.dart catch
    }

    return testCases;
  }

  /// 3. Chức năng Export (Ghi Excel)
  Future<void> exportTestCasesToExcel(List<TestCase> testCases, String outputFilePath) async {
    try {
      // Tạo file excel mới
      var excel = Excel.createExcel();

      // Mặc định tạo ra sheet có tên 'Sheet1', ta sẽ sử dụng sheet này
      Sheet sheetObject = excel['Sheet1'];

      // Tạo dòng header chuẩn xác theo yêu cầu
      List<String> headers = [
        'Test Case ID',
        'Use Case',
        'Test Description',
        'Steps',
        'Expected Result',
        'Actual Result',
        'Status'
      ];
      
      // Thêm dòng header vào sheet (Sử dụng TextCellValue cho các package excel phiên bản mới)
      sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

      // Duyệt qua danh sách testCases và đổ dữ liệu vào các dòng tương ứng
      for (var tc in testCases) {
        List<TextCellValue> rowData = [
          TextCellValue(tc.testCaseId),
          TextCellValue(tc.useCaseName),
          TextCellValue(tc.testDescription),
          TextCellValue(tc.testSteps),
          TextCellValue(tc.expectedResult),
          TextCellValue(tc.actualResult),
          TextCellValue(tc.status),
        ];
        
        // Thêm dữ liệu vào dòng tiếp theo
        sheetObject.appendRow(rowData);
      }

      // Lưu file xuống đường dẫn outputFilePath
      List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        if (kIsWeb) {
          final blob = html.Blob([fileBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", "Report5_TestReport.xlsx")
            ..click();
          html.Url.revokeObjectUrl(url);
          debugPrint('Đã tải xuống file Excel trên Web.');
        } else {
          File(outputFilePath)
            ..createSync(recursive: true) // Tạo file và các thư mục nếu chưa tồn tại
            ..writeAsBytesSync(fileBytes); // Ghi dữ liệu dạng byte vào file
          
          debugPrint('Lưu file Excel thành công tại: $outputFilePath');
        }
      }
    } catch (e) {
      debugPrint('Lỗi khi xuất file Excel: $e');
      rethrow; // Ném lỗi ra để main.dart catch và báo lỗi trên UI
    }
  }
}
