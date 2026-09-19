import 'dart:io';
import 'package:excel/excel.dart';

class ExcelService {
  Future<List<Map<String, dynamic>>> parseTestCases(String filePath) async {
    List<Map<String, dynamic>> testCases = [];
    
    try {
      var bytes = File(filePath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      String firstSheet = excel.tables.keys.first;
      var table = excel.tables[firstSheet];

      if (table != null) {
        for (int i = 1; i < table.rows.length; i++) {
          var row = table.rows[i];
          if (row.isEmpty || row[0] == null) continue;

          testCases.add({
            'TestCaseID': row.isNotEmpty ? row[0]?.value?.toString() ?? '' : '',
            'FunctionName': row.length > 1 ? row[1]?.value?.toString() ?? '' : '',
            'Type': row.length > 2 ? row[2]?.value?.toString() ?? '' : '',
            'Result': row.length > 3 ? row[3]?.value?.toString() ?? '' : '',
          });
        }
      }
      return testCases;
    } catch (e) {
      print('Lỗi đọc file Excel: $e');
      return [];
    }
  }
}