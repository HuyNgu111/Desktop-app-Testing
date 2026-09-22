import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'report_screen.dart';
import '../services/excel_service.dart';
import '../services/word_service.dart';
import '../services/ai_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String? wordPath;
  String? excelPath;
  final TextEditingController _groupNameController = TextEditingController();

  Future<void> _pickWordFile() async {
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

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CapReview - Import Data')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Vui lòng chọn tài liệu cần Review',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickWordFile,
              icon: const Icon(Icons.description, size: 28),
              label: const Text('Chọn file SRS (Word)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            if (wordPath != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Đã chọn: $wordPath',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickExcelFile,
              icon: const Icon(Icons.table_chart, size: 28),
              label: const Text('Chọn file Test Case (Excel)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            if (excelPath != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Đã chọn: $excelPath',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Nhập tên nhóm',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                String groupName = _groupNameController.text.trim();

                if (wordPath == null ||
                    excelPath == null ||
                    groupName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Vui lòng chọn đủ 2 file và nhập tên nhóm!',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // 1. Thông báo đang đọc
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đang đọc các sheet Excel & đối chiếu với Word... Vui lòng đợi!',
                    ),
                  ),
                );

                // 2. Đọc System Test Excel (nhiều sheet)
                final reportData = await ExcelService().parseSystemTestExcel(
                  excelPath!,
                );
                if (reportData == null || reportData.modules.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Không thể đọc dữ liệu test case từ file Excel này!',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // 3. Đọc file Word
                final wordText = await WordService().extractText(wordPath!);

                print("Đang gửi cho AI...");
                AiReviewResult? aiResult = await AiService().reviewSystemTestWithSRS(
                  srsContent: wordText.isNotEmpty ? wordText : 'Không có thông tin Word',
                  excelSummary: reportData.toAiPromptSummary(),
                );

                if (aiResult == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lỗi: AI không thể phân tích file này!'), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }

                // 4. Chuyển sang màn hình Report
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportScreen(
                        groupName: groupName,
                        reportData: reportData,
                        aiResult: aiResult, // CHUYỀN TOÀN BỘ KẾT QUẢ AI SANG
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Phân Tích Coverage'),
            ),
          ],
        ),
      ),
    );
  }
}
