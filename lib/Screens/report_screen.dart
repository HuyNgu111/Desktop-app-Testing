import 'package:flutter/material.dart';

class ReportScreen extends StatelessWidget {
  final String groupName;
  final String? wordPath;
  final String? excelPath;
  final List<Map<String, dynamic>> excelData;

  const ReportScreen({
    super.key,
    required this.groupName,
    this.wordPath,
    this.excelPath,
    required this.excelData,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController(
      text: 'Nhóm đã hoàn thiện phần lớn các Use Case cơ bản.\n'
          'Tuy nhiên, cần bổ sung thêm kiểm thử và bao phủ (coverage) cho UC03 và UC05 trước khi bàn giao bản chính thức.',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Báo cáo Coverage - $groupName'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          Widget tableSection = Card(
            elevation: 2,
            margin: const EdgeInsets.all(12.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Danh sách Test Cases từ Excel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Mã TC', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Tên Hàm', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Loại', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Kết quả', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: excelData.map((tc) {
                            return DataRow(
                              cells: [
                                DataCell(Text(tc['TestCaseID']?.toString() ?? '')),
                                DataCell(Text(tc['FunctionName']?.toString() ?? '')),
                                DataCell(Text(tc['Type']?.toString() ?? '')),
                                DataCell(
                                  Text(
                                    tc['Result']?.toString() ?? '',
                                    style: TextStyle(
                                      color: tc['Result']?.toString().toLowerCase() == 'pass' 
                                          ? Colors.green 
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          Widget feedbackSection = Card(
            elevation: 2,
            margin: const EdgeInsets.all(12.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Feedback & Nhận xét',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Nút này để sau tích hợp AI tính năng bấm là sinh text
                        },
                        icon: const Icon(Icons.auto_awesome, color: Colors.purple),
                        label: const Text('AI Auto Review'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade50,
                          foregroundColor: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: feedbackController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Nhập feedback tại đây...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã lưu Feedback thành công!')),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Lưu Feedback'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          if (isDesktop) {
            return Row(
              children: [
                Expanded(flex: 1, child: tableSection),
                Expanded(flex: 1, child: feedbackSection),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(flex: 1, child: tableSection),
                Expanded(flex: 1, child: feedbackSection),
              ],
            );
          }
        },
      ),
    );
  }
}