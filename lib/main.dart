import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add for kIsWeb
import 'package:path_provider/path_provider.dart';
import 'excel_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Excel Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ExcelTestPage(),
    );
  }
}

class ExcelTestPage extends StatefulWidget {
  const ExcelTestPage({Key? key}) : super(key: key);

  @override
  State<ExcelTestPage> createState() => _ExcelTestPageState();
}

class _ExcelTestPageState extends State<ExcelTestPage> {
  final ExcelService _excelService = ExcelService();
  String _log = 'Kết quả sẽ hiển thị ở đây...';

  void _printLog(String message) {
    setState(() {
      _log = '$message\n\n$_log';
    });
    debugPrint(message);
  }

  // 1. Test Import
  Future<void> _testImport() async {
    _printLog('--- Bắt đầu Test Import ---');
    try {
      List<TestCase> testCases = await _excelService.readTestCasesFromExcel();
      if (testCases.isNotEmpty) {
        _printLog('Thành công! Đã đọc được ${testCases.length} dòng dữ liệu.');
        _printLog('Dòng đầu tiên: ID=${testCases.first.testCaseId}, UseCase=${testCases.first.useCaseName}, Description=${testCases.first.testDescription}');
      } else {
        _printLog('Không đọc được dữ liệu nào hoặc người dùng đã hủy.');
      }
    } catch (e) {
      _printLog('Lỗi (Crash) khi Import: $e');
    }
  }

  // 2. Test Export
  Future<void> _testExport() async {
    _printLog('--- Bắt đầu Test Export ---');
    try {
      // Fake data
      List<TestCase> mockData = [
        TestCase(
            testCaseId: 'TC_001',
            useCaseName: 'Đăng nhập',
            testDescription: 'Đăng nhập với mật khẩu đúng',
            testSteps: '1. Nhập username\n2. Nhập password đúng\n3. Bấm Đăng nhập',
            expectedResult: 'Vào được màn hình chính',
            actualResult: 'Chưa test',
            status: 'Pending'),
        TestCase(
            testCaseId: 'TC_002',
            useCaseName: 'Đăng nhập',
            testDescription: 'Đăng nhập với mật khẩu sai',
            testSteps: '1. Nhập username\n2. Nhập password sai\n3. Bấm Đăng nhập',
            expectedResult: 'Hiện thông báo lỗi',
            actualResult: 'Chưa test',
            status: 'Pending'),
      ];

      // Đặt đường dẫn xuất file (Tuỳ biến theo máy người dùng)
      String filePath = 'Report5_TestReport.xlsx';
      if (!kIsWeb) {
        // Sử dụng path_provider để lấy thư mục an toàn trên thiết bị (Android/iOS)
        final directory = await getApplicationDocumentsDirectory();
        String docPath = directory.path;
        filePath = '$docPath/Report5_TestReport.xlsx';
      }

      await _excelService.exportTestCasesToExcel(mockData, filePath);
      _printLog('Đã chạy xong lệnh Export! Hãy kiểm tra file tại: $filePath');
    } catch (e) {
      _printLog('Lỗi (Crash) khi Export: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smoke Test - Excel Service')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _testImport,
                  child: const Text('Test Import (.xlsx)'),
                ),
                ElevatedButton(
                  onPressed: _testExport,
                  child: const Text('Test Export'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Logs Test:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.grey[200],
                child: SingleChildScrollView(
                  child: Text(_log, style: const TextStyle(fontFamily: 'monospace')),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
