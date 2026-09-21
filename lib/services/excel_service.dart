import 'dart:io';
import 'package:excel/excel.dart';

class SystemTestCase {
  final String id;
  final String description;
  final String procedure;
  final String expectedResult;
  final String result; // Passed / Failed

  SystemTestCase({
    required this.id,
    required this.description,
    required this.procedure,
    required this.expectedResult,
    required this.result,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'procedure': procedure,
        'expected': expectedResult,
        'result': result,
      };
}

class ModuleSummary {
  final String sheetName;
  final String featureName;
  final String requirement;
  final int totalTCs;
  final int passedCount;
  final int failedCount;
  final List<SystemTestCase> testCases;

  ModuleSummary({
    required this.sheetName,
    required this.featureName,
    required this.requirement,
    required this.totalTCs,
    required this.passedCount,
    required this.failedCount,
    required this.testCases,
  });

  double get passRate => totalTCs > 0 ? (passedCount / totalTCs) * 100 : 0.0;
}

class SystemTestReportData {
  final int totalModules;
  final int grandTotalTCs;
  final int totalPassed;
  final int totalFailed;
  final List<ModuleSummary> modules;

  SystemTestReportData({
    required this.totalModules,
    required this.grandTotalTCs,
    required this.totalPassed,
    required this.totalFailed,
    required this.modules,
  });

  double get overallPassRate =>
      grandTotalTCs > 0 ? (totalPassed / grandTotalTCs) * 100 : 0.0;

  /// Tạo chuỗi tóm tắt sạch, tối ưu hóa token để gửi cho Gemini AI
  String toAiPromptSummary() {
    StringBuffer sb = StringBuffer();
    sb.writeln('=== TỔNG HỢP SYSTEM TEST CỦA DỰ ÁN ===');
    sb.writeln('Tổng số Module kiểm thử: $totalModules');
    sb.writeln('Tổng số Test Cases: $grandTotalTCs');
    sb.writeln('Passed: $totalPassed | Failed: $totalFailed | Tỷ lệ Pass: ${overallPassRate.toStringAsFixed(1)}%\n');

    for (var mod in modules) {
      sb.writeln('--- Module: ${mod.featureName} (${mod.sheetName}) ---');
      sb.writeln('Yêu cầu kiểm thử: ${mod.requirement}');
      sb.writeln('Số lượng TC: ${mod.totalTCs} (Passed: ${mod.passedCount}, Failed: ${mod.failedCount})');
      
      // Liệt kê các ca failed để AI chú ý review
      var failedTCs = mod.testCases.where((tc) => tc.result.toLowerCase().contains('fail')).toList();
      if (failedTCs.isNotEmpty) {
        sb.writeln('Các ca FAIL cần lưu ý:');
        for (var ftc in failedTCs) {
          sb.writeln('  - [${ftc.id}] ${ftc.description} -> Mong đợi: ${ftc.expectedResult}');
        }
      }
      sb.writeln();
    }
    return sb.toString();
  }
}

class ExcelService {
  Future<SystemTestReportData?> parseSystemTestExcel(String filePath) async {
    try {
      var bytes = File(filePath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      List<ModuleSummary> modules = [];
      int grandTotal = 0;
      int grandPassed = 0;
      int grandFailed = 0;

      for (var sheetName in excel.tables.keys) {
        var table = excel.tables[sheetName];
        if (table == null || table.rows.isEmpty) continue;

        // 1. Tìm vị trí dòng Tiêu đề (Header row chứa 'Test Case ID')
        int headerRowIndex = -1;
        int idCol = -1, descCol = -1, procCol = -1, expCol = -1;
        int r1Col = -1, r2Col = -1, r3Col = -1;

        for (int r = 0; r < table.rows.length; r++) {
          var row = table.rows[r];
          for (int c = 0; c < row.length; c++) {
            String val = row[c]?.value?.toString().trim().toLowerCase() ?? '';
            if (val == 'test case id') {
              headerRowIndex = r;
              break;
            }
          }
          if (headerRowIndex != -1) break;
        }

        // Nếu sheet này không có bảng Test Case thì bỏ qua (VD: sheet Cover, Note...)
        if (headerRowIndex == -1) continue;

        // 2. Xác định vị trí các cột
        var headerRow = table.rows[headerRowIndex];
        for (int c = 0; c < headerRow.length; c++) {
          String val = headerRow[c]?.value?.toString().trim().toLowerCase() ?? '';
          if (val.contains('test case id')) idCol = c;
          if (val.contains('description')) descCol = c;
          if (val.contains('procedure')) procCol = c;
          if (val.contains('expected')) expCol = c;
          if (val == 'round 1') r1Col = c;
          if (val == 'round 2') r2Col = c;
          if (val == 'round 3') r3Col = c;
        }

        // 3. Đọc Metadata phần trên (Feature Name, Requirement)
        String featureName = sheetName;
        String requirement = '';
        for (int r = 0; r < headerRowIndex; r++) {
          var row = table.rows[r];
          for (int c = 0; c < row.length; c++) {
            String val = row[c]?.value?.toString().trim().toLowerCase() ?? '';
            if (val == 'feature' && c + 1 < row.length) {
              featureName = row[c + 1]?.value?.toString().trim() ?? featureName;
            }
            if (val == 'test requirement' && c + 1 < row.length) {
              requirement = row[c + 1]?.value?.toString().trim() ?? '';
            }
          }
        }

        // 4. Lặp qua các dòng dữ liệu để bóc tách Test Cases
        List<SystemTestCase> testCases = [];
        int passed = 0;
        int failed = 0;

        for (int r = headerRowIndex + 1; r < table.rows.length; r++) {
          var row = table.rows[r];
          if (row.isEmpty || idCol >= row.length || row[idCol] == null) continue;

          String tcId = row[idCol]?.value?.toString().trim() ?? '';
          // Chỉ lấy dòng có mã bắt đầu bằng TC (bỏ qua các dòng phân nhóm như 'Member Management')
          if (!tcId.toUpperCase().startsWith('TC')) continue;

          String desc = (descCol != -1 && descCol < row.length)
              ? row[descCol]?.value?.toString().trim() ?? ''
              : '';
          String proc = (procCol != -1 && procCol < row.length)
              ? row[procCol]?.value?.toString().trim() ?? ''
              : '';
          String exp = (expCol != -1 && expCol < row.length)
              ? row[expCol]?.value?.toString().trim() ?? ''
              : '';

          // Lấy kết quả từ Round 3 -> Round 2 -> Round 1
          String res = '';
          if (r3Col != -1 && r3Col < row.length && row[r3Col]?.value != null) {
            res = row[r3Col]!.value.toString().trim();
          }
          if (res.isEmpty && r2Col != -1 && r2Col < row.length && row[r2Col]?.value != null) {
            res = row[r2Col]!.value.toString().trim();
          }
          if (res.isEmpty && r1Col != -1 && r1Col < row.length && row[r1Col]?.value != null) {
            res = row[r1Col]!.value.toString().trim();
          }

          if (res.toLowerCase() == 'passed') {
            passed++;
          } else if (res.toLowerCase() == 'failed') {
            failed++;
          }

          testCases.add(SystemTestCase(
            id: tcId,
            description: desc,
            procedure: proc,
            expectedResult: exp,
            result: res.isNotEmpty ? res : 'Pending',
          ));
        }

        if (testCases.isNotEmpty) {
          modules.add(ModuleSummary(
            sheetName: sheetName,
            featureName: featureName,
            requirement: requirement,
            totalTCs: testCases.length,
            passedCount: passed,
            failedCount: failed,
            testCases: testCases,
          ));

          grandTotal += testCases.length;
          grandPassed += passed;
          grandFailed += failed;
        }
      }

      return SystemTestReportData(
        totalModules: modules.length,
        grandTotalTCs: grandTotal,
        totalPassed: grandPassed,
        totalFailed: grandFailed,
        modules: modules,
      );
    } catch (e) {
      print('Lỗi đọc file System Test Excel: $e');
      return null;
    }
  }
}