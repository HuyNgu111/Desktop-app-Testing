import 'dart:convert';
import 'dart:io';
import 'api_key.dart';

// Class chứa cả báo cáo văn bản và danh sách lỗi xuất Excel
class AiReviewResult {
  final String markdownReport;
  final List<Map<String, dynamic>> excelDefects;

  AiReviewResult({required this.markdownReport, required this.excelDefects});
}

class AiService {
  static const String apiKey = deepseekApiKey;

  Future<AiReviewResult?> reviewSystemTestWithSRS({
    required String srsContent,
    required String excelSummary,
  }) async {
    try {
      String safeSrs = srsContent;
      if (safeSrs.length > 20000) {
        safeSrs = safeSrs.substring(0, 20000) + '\n\n...[Đã cắt bớt phần sau của tài liệu SRS]...';
      }

      const systemPrompt = 'Bạn là Giảng viên / Chuyên gia QA Audit khó tính.';
      final userPrompt = '''
Dưới đây là tài liệu SRS và Báo cáo System Test:

TÀI LIỆU 1 (SRS):
$safeSrs

TÀI LIỆU 2 (SYSTEM TEST):
$excelSummary

NHIỆM VỤ CỦA BẠN:
1. Đánh giá Mức độ bao phủ (Missing Test Cases): Chỉ ra các Use Case/Tính năng có trong SRS nhưng bị bỏ sót trong System Test.
2. Soi lỗi Kịch bản (Poor Test Cases): Tìm các Test Case viết hời hợt (thiếu Test Data, Pre-condition chung chung, Expected Result không thể kiểm chứng).
3. Đánh giá Defect Trend: Đánh giá quá trình bắt lỗi từ Round 1 đến Round 3.

BẮT BUỘC TRẢ VỀ DUY NHẤT ĐỊNH DẠNG JSON NHƯ SAU (Không có chú thích thừa):
{
  "markdown_report": "Viết toàn bộ bài nhận xét chuyên nghiệp của bạn vào đây (Dùng Markdown, có xuống dòng \\n, có in đậm, có chấm điểm).",
  "excel_defects": [
    {
      "type": "Thiếu Bao Phủ",
      "id": "N/A (Tên Use Case bị thiếu)",
      "description": "Tính năng ABC chưa có test case",
      "reason": "Đây là tính năng cốt lõi nhưng bị bỏ quên"
    },
    {
      "type": "Lỗi Kịch Bản",
      "id": "TC-AUTH-01",
      "description": "Navigate to login, enter email",
      "reason": "Thiếu dữ liệu email/password mẫu. Expected Result chung chung."
    }
  ]
}
''';

      final url = Uri.parse('https://api.deepseek.com/chat/completions');
      final httpClient = HttpClient();
      final request = await httpClient.postUrl(url);

      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Bearer $apiKey');

      final payload = {
        'model': 'deepseek-chat',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        // Ép model trả về JSON Object
        'response_format': {'type': 'json_object'},
        'temperature': 0.7,
      };

      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final jsonResponse = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        String aiContent = jsonResponse['choices'][0]['message']['content'];
        
        // Trích xuất JSON từ chuỗi trả về
        final RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
        final match = jsonRegex.firstMatch(aiContent);
        if (match != null) {
          aiContent = match.group(0)!;
        }

        Map<String, dynamic> parsedData = jsonDecode(aiContent);
        
        return AiReviewResult(
          markdownReport: parsedData['markdown_report'] ?? 'Không có nhận xét',
          excelDefects: List<Map<String, dynamic>>.from(parsedData['excel_defects'] ?? []),
        );
      } else {
        print('Lỗi từ API: $responseBody');
        return AiReviewResult(markdownReport: 'Lỗi API: ${response.statusCode}', excelDefects: []);
      }
    } catch (e) {
      print('Lỗi gọi DeepSeek: $e');
      return AiReviewResult(markdownReport: 'Lỗi kết nối: $e', excelDefects: []);
    }
  }
}