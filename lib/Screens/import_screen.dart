import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'report_screen.dart';
import '../services/excel_service.dart';
import '../services/ai_service.dart';
import '../services/word_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String? wordPath;
  String? excelPath;
  final TextEditingController _groupNameController = TextEditingController();

  // Biến quản lý trạng thái Loading và thông báo tiến trình
  bool _isLoading = false;
  String _loadingMessage = '';

  Future<void> _pickWordFile() async {
    if (_isLoading) return;
    PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );

    if (file != null && file.path != null) {
      setState(() {
        wordPath = file.path;
      });
    }
  }

  Future<void> _pickExcelFile() async {
    if (_isLoading) return;
    PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (file != null && file.path != null) {
      setState(() {
        excelPath = file.path;
      });
    }
  }

  Future<void> _handleStartReview() async {
    String groupName = _groupNameController.text.trim();

    if (wordPath == null || excelPath == null || groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn đủ 2 file và nhập tên nhóm!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 1. Kích hoạt Loading ngay lập tức trên UI
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Đang đọc và bóc tách dữ liệu từ file Word & Excel...';
    });

    // Khoảng trễ 100ms giúp Flutter kịp vẽ thanh Loading lên màn hình trước khi đọc file nặng
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // 2. Bóc tách dữ liệu file
      final reportData = await ExcelService().parseSystemTestExcel(excelPath!);
      if (reportData == null || reportData.modules.isEmpty) {
        throw Exception('Không thể đọc dữ liệu test case từ file Excel này!');
      }

      final wordText = await WordService().extractText(wordPath!);

      // 3. Cập nhật thông báo sang bước AI
      if (mounted) {
        setState(() {
          _loadingMessage = 'Đang gửi tài liệu và chờ DeepSeek AI phân tích...';
        });
      }

      // 4. Gửi cho AI Review
      final aiResult = await AiService().reviewSystemTestWithSRS(
        srsContent: wordText.isNotEmpty ? wordText : 'Không có thông tin Word',
        excelSummary: reportData.toAiPromptSummary(),
      );

      if (aiResult == null) {
        throw Exception('Không nhận được phản hồi từ AI.');
      }

      // 5. Chuyển sang màn hình Report
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportScreen(
              groupName: groupName,
              reportData: reportData,
              aiResult: aiResult,
            ),
          ),
        );
      }
    } catch (e) {
      // Bắt lỗi và dừng Loading để người dùng thử lại
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CapReview - Import Data'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Thẩm Định Chất Lượng Tài Liệu Testing',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chọn tài liệu yêu cầu (Word) và báo cáo System Test (Excel)',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Nút chọn file Word
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickWordFile,
                  icon: const Icon(Icons.description, size: 26, color: Colors.blue),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Text('1. Chọn file SRS (Word .docx)', style: TextStyle(fontSize: 16)),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                if (wordPath != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Đã chọn: $wordPath',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),

                // Nút chọn file Excel
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickExcelFile,
                  icon: const Icon(Icons.table_chart, size: 26, color: Colors.green),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Text('2. Chọn file System Test (Excel .xlsx)', style: TextStyle(fontSize: 16)),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                if (excelPath != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Đã chọn: $excelPath',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 24),

                // Ô nhập tên nhóm
                TextField(
                  controller: _groupNameController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Nhập tên nhóm / Tên dự án',
                    hintText: 'Ví dụ: WorkGang',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                ),
                const SizedBox(height: 28),

                // KHU VỰC NÚT BẤM VÀ LOADING TIẾN TRÌNH
                if (_isLoading) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _loadingMessage,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Vui lòng không thao tác cho đến khi hoàn tất phân tích.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: _handleStartReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Bắt Đầu Thẩm Định (AI Review)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}