import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/excel_service.dart';

class ReportScreen extends StatefulWidget {
  final String groupName;
  final SystemTestReportData reportData;
  final String aiFeedback;

  const ReportScreen({
    super.key,
    required this.groupName,
    required this.reportData,
    required this.aiFeedback,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late TextEditingController _feedbackController;
  bool _isExporting = false;
  bool _isPreviewMode = true; // Mặc định bật chế độ xem Markdown đẹp

  @override
  void initState() {
    super.initState();
    _feedbackController = TextEditingController(text: widget.aiFeedback);
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  // BỘ PHÂN TÍCH VÀ ĐỊNH DẠNG MARKDOWN THÔNG MINH CHO PDF
  List<pw.Widget> _buildFormattedPdfMarkdown(
    String rawText,
    pw.Font regular,
    pw.Font bold,
  ) {
    // 1. Xử lý triệt để lỗi ô vuông: Đổi emoji thành chữ ký hiệu chuyên nghiệp
    String text = rawText
        .replaceAll('✅', '[PASS]')
        .replaceAll('❌', '[FAIL]')
        .replaceAll('⚠️', '[LƯU Ý]')
        .replaceAll('👉', '->')
        .replaceAll('---', '');

    List<pw.Widget> widgets = [];
    List<String> lines = text.split('\n');

    int i = 0;
    while (i < lines.length) {
      String line = lines[i].trim();

      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: 3));
        i++;
        continue;
      }

      // 2. Tự động nhận diện BẢNG MARKDOWN (| Cột 1 | Cột 2 |) và vẽ thành Bảng PDF kẻ viền
      if (line.startsWith('|') && line.endsWith('|')) {
        List<List<String>> tableData = [];
        while (i < lines.length &&
            lines[i].trim().startsWith('|') &&
            lines[i].trim().endsWith('|')) {
          String tableLine = lines[i].trim();
          // Bỏ qua dòng kẻ phân cách |---|---|
          if (!tableLine.contains('---')) {
            var cells = tableLine
                .split('|')
                .map((c) => c.trim().replaceAll('**', ''))
                .where((c) => c.isNotEmpty)
                .toList();
            if (cells.isNotEmpty) tableData.add(cells);
          }
          i++;
        }
        if (tableData.length > 1) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.TableHelper.fromTextArray(
                headers: tableData.first,
                data: tableData.sublist(1),
                headerStyle: pw.TextStyle(
                  font: bold,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: pw.TextStyle(font: regular, fontSize: 7.5),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 2.5,
                  horizontal: 4,
                ),
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
              ),
            ),
          );
        }
        continue;
      }

      // 3. Tiêu đề H1, H2, H3
      if (line.startsWith('# ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
            child: pw.Text(
              line.substring(2).replaceAll('**', ''),
              style: pw.TextStyle(
                font: bold,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
            child: pw.Text(
              line.substring(3).replaceAll('**', ''),
              style: pw.TextStyle(
                font: bold,
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
            child: pw.Text(
              line.substring(4).replaceAll('**', ''),
              style: pw.TextStyle(
                font: bold,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      }
      // 4. Danh sách gạch đầu dòng (- hoặc *)
      else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 1.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('- ', style: pw.TextStyle(font: bold, fontSize: 8)),
                pw.Expanded(
                  child: pw.Text(
                    line.substring(2).replaceAll('**', ''),
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 8,
                      lineSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // 5. Đoạn văn bản thông thường
      else {
        widgets.add(
          pw.Paragraph(
            text: line.replaceAll('**', ''),
            style: pw.TextStyle(font: regular, fontSize: 8, lineSpacing: 1.2),
            margin: const pw.EdgeInsets.only(bottom: 2),
          ),
        );
      }

      i++;
    }
    return widgets;
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);

    try {
      // 1. Khai báo đúng tên biến 'regular' và 'bold'
      final regular = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              'CapReview - Thẩm định System Testing • Nhóm: ${widget.groupName}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Trang ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
            ),
          ),
          build: (context) => [
            // Header
            pw.Center(
              child: pw.Text(
                'BÁO CÁO ĐÁNH GIÁ SYSTEM TEST',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Dự án / Nhóm: ${widget.groupName}',
                style: pw.TextStyle(font: bold, fontSize: 12),
              ),
            ),
            pw.SizedBox(height: 10),

            // KPI Banner
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 8,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpiItem(
                    'Modules',
                    '${widget.reportData.totalModules}',
                    bold,
                  ),
                  _buildPdfKpiItem(
                    'Tổng TCs',
                    '${widget.reportData.grandTotalTCs}',
                    bold,
                  ),
                  _buildPdfKpiItem(
                    'Tỷ lệ Pass',
                    '${widget.reportData.overallPassRate.toStringAsFixed(1)}%',
                    bold,
                  ),
                  _buildPdfKpiItem(
                    'Passed',
                    '${widget.reportData.totalPassed}',
                    bold,
                  ),
                  _buildPdfKpiItem(
                    'Failed',
                    '${widget.reportData.totalFailed}',
                    bold,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Bảng Modules
            pw.Text(
              '1. TỔNG HỢP THEO MODULE KIỂM THỬ:',
              style: pw.TextStyle(
                font: bold,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['STT', 'Tên Module / Tính năng', 'Số TC', 'Kết quả'],
              data: List<List<String>>.generate(
                widget.reportData.modules.length,
                (i) {
                  final mod = widget.reportData.modules[i];
                  return [
                    '${i + 1}',
                    mod.featureName,
                    '${mod.totalTCs}',
                    '${mod.passedCount} Pass / ${mod.failedCount} Fail',
                  ];
                },
              ),
              headerStyle: pw.TextStyle(
                font: bold,
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: pw.TextStyle(font: regular, fontSize: 7.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
              cellPadding: const pw.EdgeInsets.symmetric(
                vertical: 2,
                horizontal: 4,
              ),
            ),
            pw.SizedBox(height: 12),

            // Nội dung AI Review
            pw.Text(
              '2. NHẬN XÉT VÀ ĐÁNH GIÁ CHI TIẾT (AI REVIEW):',
              style: pw.TextStyle(
                font: bold,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),

            ..._buildFormattedPdfMarkdown(
              _feedbackController.text,
              regular,
              bold,
            ),

            pw.SizedBox(height: 16),

            // Chữ ký
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Người thẩm định',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 35),
                    pw.Text(
                      '(Ký và ghi rõ họ tên)',
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'BaoCao_SystemTest_${widget.groupName}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.Widget _buildPdfKpiItem(String title, String value, pw.Font bold) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            font: bold,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Báo cáo System Test - ${widget.groupName}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CỘT TRÁI: KPI & DANH SÁCH MODULE
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildKpiCard(
                        'Modules',
                        '${widget.reportData.totalModules}',
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _buildKpiCard(
                        'Tổng TCs',
                        '${widget.reportData.grandTotalTCs}',
                        Colors.purple,
                      ),
                      const SizedBox(width: 8),
                      _buildKpiCard(
                        'Tỷ lệ Pass',
                        '${widget.reportData.overallPassRate.toStringAsFixed(0)}%',
                        Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _buildKpiCard(
                        'Failed',
                        '${widget.reportData.totalFailed}',
                        Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chi tiết theo Module',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.reportData.modules.length,
                      itemBuilder: (context, index) {
                        final mod = widget.reportData.modules[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: mod.failedCount > 0
                                  ? Colors.orange.shade100
                                  : Colors.green.shade100,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              mod.featureName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Sheet: ${mod.sheetName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              '${mod.passedCount}/${mod.totalTCs} Pass',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: mod.failedCount > 0
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // CỘT PHẢI: AI FEEDBACK (CÓ CHẾ ĐỘ XEM ĐẸP VÀ CHỈNH SỬA)
            Expanded(
              flex: 5,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AI Review & Feedback',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          Row(
                            children: [
                              // Nút chuyển đổi Xem trước / Chỉnh sửa
                              TextButton.icon(
                                onPressed: () => setState(
                                  () => _isPreviewMode = !_isPreviewMode,
                                ),
                                icon: Icon(
                                  _isPreviewMode
                                      ? Icons.edit
                                      : Icons.remove_red_eye,
                                  size: 18,
                                ),
                                label: Text(
                                  _isPreviewMode ? 'Chỉnh sửa' : 'Xem trước',
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _isExporting ? null : _exportPdf,
                                icon: _isExporting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.picture_as_pdf),
                                label: Text(
                                  _isExporting ? 'Đang tạo...' : 'Export PDF',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _isPreviewMode
                              // CHẾ ĐỘ XEM TRƯỚC: Render Markdown đẹp lung linh (tự kẻ bảng, tự làm đậm)
                              ? Markdown(
                                  data: _feedbackController.text,
                                  selectable: true,
                                )
                              // CHẾ ĐỘ CHỈNH SỬA: Cho phép giảng viên gõ sửa trực tiếp
                              : Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextField(
                                    controller: _feedbackController,
                                    maxLines: null,
                                    expands: true,
                                    textAlignVertical: TextAlignVertical.top,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
