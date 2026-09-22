import 'dart:io';
import 'package:excel/excel.dart';

class SystemTestCase {
  final String id;
  final String description;
  final String procedure;
  final String expectedResult;
  final String r1Result;
  final String r2Result;
  final String round3Result;
  final String result;

  SystemTestCase({
    required this.id,
    required this.description,
    required this.procedure,
    required this.expectedResult,
    required this.r1Result,
    required this.r2Result,
    required this.round3Result,
    required this.result,
  });
}

class ModuleSummary {
  final String sheetName;
  final String featureName;
  final String requirement;
  final int totalTCs;

  final int r1Passed;
  final int r1Failed;
  final int r2Passed;
  final int r2Failed;
  final int r3Passed;
  final int r3Failed;

  final int passedCount;
  final int failedCount;
  final List<SystemTestCase> testCases;

  ModuleSummary({
    required this.sheetName,
    required this.featureName,
    required this.requirement,
    required this.totalTCs,
    required this.r1Passed,
    required this.r1Failed,
    required this.r2Passed,
    required this.r2Failed,
    required this.r3Passed,
    required this.r3Failed,
    required this.passedCount,
    required this.failedCount,
    required this.testCases,
  });
}

class SystemTestReportData {
  final int totalModules;
  final int grandTotalTCs;
  final int grandR1Passed;
  final int grandR1Failed;
  final int grandR2Passed;
  final int grandR2Failed;
  final int grandR3Passed;
  final int grandR3Failed;

  final int totalPassed;
  final int totalFailed;
  final List<ModuleSummary> modules;

  SystemTestReportData({
    required this.totalModules,
    required this.grandTotalTCs,
    required this.grandR1Passed,
    required this.grandR1Failed,
    required this.grandR2Passed,
    required this.grandR2Failed,
    required this.grandR3Passed,
    required this.grandR3Failed,
    required this.totalPassed,
    required this.totalFailed,
    required this.modules,
  });

  String toAiPromptSummary() {
    StringBuffer sb = StringBuffer();
    sb.writeln('=== BẢNG TỔNG HỢP SỐ LIỆU SYSTEM TEST TOÀN DỰ ÁN ===');
    sb.writeln('Quy mô: $totalModules Modules | $grandTotalTCs Test Cases');
    sb.writeln('Tiến trình: R1 ($grandR1Passed P / $grandR1Failed F) -> R2 ($grandR2Passed P / $grandR2Failed F) -> R3 ($grandR3Passed P / $grandR3Failed F)\n');

    sb.writeln('=== DANH SÁCH CHI TIẾT KỊCH BẢN KIỂM THỬ (TEST CASES) ===');
    for (var mod in modules) {
      sb.writeln('--- Module: ${mod.featureName} [Sheet: ${mod.sheetName}] ---');
      if (mod.requirement.isNotEmpty) {
        sb.writeln('Yêu cầu kiểm thử: ${mod.requirement}');
      }
      sb.writeln('Danh sách Kịch bản:');
      
      for (var tc in mod.testCases) {
        String proc = tc.procedure.isNotEmpty ? ' | Các bước: ${tc.procedure.replaceAll('\n', ' ')}' : '';
        String exp = tc.expectedResult.isNotEmpty ? ' | Kỳ vọng: ${tc.expectedResult.replaceAll('\n', ' ')}' : '';
        sb.writeln('  * [${tc.id}] ${tc.description}$proc$exp | Lịch sử Test: R1[${tc.r1Result}] -> R2[${tc.r2Result}] -> R3[${tc.round3Result}]');
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
      final Set<String> seenSheets = {};

      int grandTotal = 0;
      int gR1P = 0, gR1F = 0, gR2P = 0, gR2F = 0, gR3P = 0, gR3F = 0;

      for (var sheetName in excel.tables.keys) {
        String cleanSheetKey = sheetName.trim().toLowerCase();
        if (seenSheets.contains(cleanSheetKey)) continue;

        var table = excel.tables[sheetName];
        if (table == null || table.rows.isEmpty) continue;

        String featureName = sheetName;
        String requirement = '';

        int headerRowIndex = -1;
        int idCol = -1, descCol = -1, procCol = -1, expCol = -1;
        int r1Col = -1, r2Col = -1, r3Col = -1;

        // 1. Quét tìm Feature, Requirement & Dòng Header (BỎ QUA LUÔN CÁC Ô TỔNG HỢP PASS/FAIL BẰNG CÔNG THỨC)
        int scanLimit = table.rows.length < 20 ? table.rows.length : 20;
        for (int r = 0; r < scanLimit; r++) {
          var row = table.rows[r];
          if (row.isEmpty) continue;

          for (int c = 0; c < row.length; c++) {
            String cellText = row[c]?.value?.toString().trim().toLowerCase() ?? '';
            cellText = cellText.replaceAll(RegExp(r'\s+'), ' ');

            if (cellText.contains('feature') && c + 1 < row.length) {
              featureName = row[c + 1]?.value?.toString().trim() ?? featureName;
            } else if (cellText.contains('test requirement') && c + 1 < row.length) {
              requirement = row[c + 1]?.value?.toString().trim() ?? '';
            } else if (cellText.contains('test case id')) {
              headerRowIndex = r;
            }
          }
        }

        // 2. Xác định các cột chi tiết
        if (headerRowIndex != -1) {
          var headerRow = table.rows[headerRowIndex];
          for (int c = 0; c < headerRow.length; c++) {
            String val = headerRow[c]?.value?.toString().trim().toLowerCase() ?? '';
            val = val.replaceAll(RegExp(r'\s+'), ' ');
            if (val.contains('test case id')) idCol = c;
            if (val.contains('description')) descCol = c;
            if (val.contains('procedure')) procCol = c;
            if (val.contains('expected')) expCol = c;
            if (val.contains('round 1')) r1Col = c;
            if (val.contains('round 2')) r2Col = c;
            if (val.contains('round 3')) r3Col = c;
          }
        }

        List<SystemTestCase> allTestCases = [];
        
        // CÁC BIẾN ĐẾM THỦ CÔNG ĐẢM BẢO CHUẨN 100%
        int r1P = 0, r1F = 0;
        int r2P = 0, r2F = 0;
        int r3P = 0, r3F = 0;

        if (headerRowIndex != -1 && idCol != -1) {
          for (int r = headerRowIndex + 1; r < table.rows.length; r++) {
            var row = table.rows[r];
            if (row.isEmpty || idCol >= row.length || row[idCol] == null) continue;

            String tcId = row[idCol]?.value?.toString().trim() ?? '';
            if (!tcId.toUpperCase().startsWith('TC')) continue;

            String desc = (descCol != -1 && descCol < row.length) ? row[descCol]?.value?.toString().trim() ?? '' : '';
            String proc = (procCol != -1 && procCol < row.length) ? row[procCol]?.value?.toString().trim() ?? '' : '';
            String exp = (expCol != -1 && expCol < row.length) ? row[expCol]?.value?.toString().trim() ?? '' : '';

            String r1Val = (r1Col != -1 && r1Col < row.length) ? row[r1Col]?.value?.toString().trim() ?? '' : '';
            String r2Val = (r2Col != -1 && r2Col < row.length) ? row[r2Col]?.value?.toString().trim() ?? '' : '';
            String r3Val = (r3Col != -1 && r3Col < row.length) ? row[r3Col]?.value?.toString().trim() ?? '' : '';

            // TỰ ĐỘNG ĐẾM TRỰC TIẾP
            if (r1Val.toLowerCase().contains('pass')) r1P++;
            if (r1Val.toLowerCase().contains('fail')) r1F++;
            if (r2Val.toLowerCase().contains('pass')) r2P++;
            if (r2Val.toLowerCase().contains('fail')) r2F++;
            if (r3Val.toLowerCase().contains('pass')) r3P++;
            if (r3Val.toLowerCase().contains('fail')) r3F++;

            String finalRes = r3Val.isNotEmpty ? r3Val : (r2Val.isNotEmpty ? r2Val : (r1Val.isNotEmpty ? r1Val : 'Pending'));

            allTestCases.add(SystemTestCase(
              id: tcId,
              description: desc,
              procedure: proc,
              expectedResult: exp,
              r1Result: r1Val,
              r2Result: r2Val,
              round3Result: r3Val,
              result: finalRes,
            ));
          }
        }

        if (allTestCases.isEmpty) continue;
        seenSheets.add(cleanSheetKey);

        // TỔNG SỐ TC CHÍNH LÀ ĐỘ DÀI CỦA MẢNG TEST CASES
        int totalCount = allTestCases.length; 

        modules.add(ModuleSummary(
          sheetName: sheetName,
          featureName: featureName,
          requirement: requirement,
          totalTCs: totalCount,
          r1Passed: r1P,
          r1Failed: r1F,
          r2Passed: r2P,
          r2Failed: r2F,
          r3Passed: r3P,
          r3Failed: r3F,
          passedCount: r3P,
          failedCount: r3F,
          testCases: allTestCases,
        ));

        grandTotal += totalCount;
        gR1P += r1P;
        gR1F += r1F;
        gR2P += r2P;
        gR2F += r2F;
        gR3P += r3P;
        gR3F += r3F;
      }

      return SystemTestReportData(
        totalModules: modules.length,
        grandTotalTCs: grandTotal,
        grandR1Passed: gR1P,
        grandR1Failed: gR1F,
        grandR2Passed: gR2P,
        grandR2Failed: gR2F,
        grandR3Passed: gR3P,
        grandR3Failed: gR3F,
        totalPassed: gR3P,
        totalFailed: gR3F,
        modules: modules,
      );
    } catch (e) {
      print('Lỗi đọc System Test Excel: $e');
      return null;
    }
  }
}