import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as ex; // Import thư viện tạo Excel

import '../services/excel_service.dart';
import '../services/ai_service.dart';

class ReportScreen extends StatefulWidget {
  final String groupName;
  final SystemTestReportData reportData;
  // SỬA: Đổi String aiFeedback thành AiReviewResult aiResult
  final AiReviewResult aiResult; 

  const ReportScreen({
    super.key,
    required this.groupName,
    required this.reportData,
    required this.aiResult, // SỬA CHỖ NÀY
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late TextEditingController _feedbackController;
  bool _isExportingPdf = false;
  bool _isExportingExcel = false;
  bool _isPreviewMode = true;

  @override
  void initState() {
    super.initState();
    // SỬA: Trỏ vào markdownReport nằm bên trong aiResult
    _feedbackController = TextEditingController(text: widget.aiResult.markdownReport);
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  // --- Hàm xuất Excel Danh sách lỗi ---
  Future<void> _exportDefectExcel() async {
    if (widget.aiResult.excelDefects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có lỗi nào để xuất!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isExportingExcel = true);

    try {
      var excel = ex.Excel.createExcel();
      ex.Sheet sheetObject = excel['Defects_Log'];
      excel.setDefaultSheet('Defects_Log');

      // Tạo Header cho Excel
      sheetObject.appendRow([
        ex.TextCellValue('Loại Vấn Đề'),
        ex.TextCellValue('Mã TC / Use Case'),
        ex.TextCellValue('Mô Tả / Nội Dung'),
        ex.TextCellValue('Phân Tích Của QA (AI)'),
      ]);

      // Bôi đậm Header
      for (int col = 0; col < 4; col++) {
        var cell = sheetObject.cell(ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.cellStyle = ex.CellStyle(bold: true, backgroundColorHex: ex.ExcelColor.blue200);
      }

      // Đổ dữ liệu từ mảng AI trả về vào các dòng
      for (var defect in widget.aiResult.excelDefects) {
        sheetObject.appendRow([
          ex.TextCellValue(defect['type']?.toString() ?? ''),
          ex.TextCellValue(defect['id']?.toString() ?? ''),
          ex.TextCellValue(defect['description']?.toString() ?? ''),
          ex.TextCellValue(defect['reason']?.toString() ?? ''),
        ]);
      }

      // 1. Mã hóa và ép kiểu sang Uint8List
      final fileBytes = Uint8List.fromList(excel.encode()!);

      // 2. Mở hộp thoại và đưa luôn fileBytes cho thư viện tự lưu
      var outputFile = await FilePicker.saveFile(
        dialogTitle: 'Lưu file Excel danh sách lỗi',
        fileName: 'Defects_Review_${widget.groupName}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: fileBytes, // <--- TRUYỀN DỮ LIỆU EXCEL VÀO ĐÂY ĐỂ NÓ TỰ LƯU
      );

      // 3. Nếu người dùng không bấm Cancel, hiện thông báo thành công
      if (outputFile != null) {
        String filePath = outputFile is Uri ? outputFile.toFilePath() : outputFile.toString();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Xuất Excel thành công tại:\n$filePath'), 
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất Excel: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  // --- Giữ nguyên các hàm build PDF cũ ở đây (mình viết tắt để khỏi dài, bạn lấy hàm _buildFormattedPdfMarkdown và _exportPdf từ file cũ dán vào nhé) ---
  List<pw.Widget> _buildFormattedPdfMarkdown(String rawText, pw.Font regular, pw.Font bold) {
     // ... (Copy nội dung hàm này từ bản code trước của bạn)
     return []; // Thay bằng code thật
  }

  Future<void> _exportPdf() async {
     // ... (Copy nội dung hàm _exportPdf từ bản code trước của bạn)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Báo cáo System Test - ${widget.groupName}'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.purple, size: 28),
                        SizedBox(width: 8),
                        Text('AI Review & Feedback', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple)),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
                          icon: Icon(_isPreviewMode ? Icons.edit : Icons.remove_red_eye, size: 18),
                          label: Text(_isPreviewMode ? 'Chỉnh sửa' : 'Xem định dạng', style: const TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 16),
                        
                        // NÚT MỚI: EXPORT EXCEL
                        ElevatedButton.icon(
                          onPressed: _isExportingExcel ? null : _exportDefectExcel,
                          icon: _isExportingExcel
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                              : const Icon(Icons.table_view, color: Colors.green),
                          label: Text(_isExportingExcel ? 'Đang tạo...' : 'Xuất Lỗi (Excel)', style: const TextStyle(fontSize: 16, color: Colors.green)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade50,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isExportingPdf ? null : _exportPdf,
                          icon: _isExportingPdf
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(_isExportingPdf ? 'Đang tạo...' : 'Xuất Báo Cáo (PDF)', style: const TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32, thickness: 1),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isPreviewMode
                        ? Markdown(data: _feedbackController.text, selectable: true)
                        : Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                              controller: _feedbackController,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                              decoration: const InputDecoration(border: InputBorder.none),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}