import 'dart:convert';
import 'dart:io';
import 'api_key.dart';

class AiService {
  // Lấy key DeepSeek từ file đã giấu
  static const String apiKey = deepseekApiKey;

  Future<String> reviewSystemTestWithSRS({
    required String srsContent,
    required String excelSummary,
  }) async {
    try {
      // 1. Rút gọn file Word nếu quá dài để tối ưu tốc độ và chi phí
      String safeSrs = srsContent;
      if (safeSrs.length > 20000) {
        safeSrs = safeSrs.substring(0, 20000) + '\n\n...[Đã cắt bớt phần sau của tài liệu SRS]...';
      }

      const systemPrompt = 'Bạn là Giảng viên / Chuyên gia QA chấm đồ án Capstone Project.';
      final userPrompt = '''
Dưới đây là 2 tài liệu của nhóm sinh viên:

TÀI LIỆU 1: TỔNG QUAN YÊU CẦU DỰ ÁN (Trích từ file SRS/Word):
$safeSrs

TÀI LIỆU 2: KẾT QUẢ THỰC HIỆN SYSTEM TEST (Trích từ file Excel):
$excelSummary

NHIỆM VỤ CỦA BẠN:
1. Đánh giá độ bao phủ (Coverage): Các Module trong System Test đã kiểm thử hết các tính năng cốt lõi được mô tả trong tài liệu dự án chưa?
2. Đánh giá chất lượng kiểm thử: Nhận xét về số lượng test case và tỷ lệ Pass/Fail qua các vòng test.
3. Đề xuất cải thiện: Nhóm sinh viên cần lưu ý bổ sung thêm kịch bản kiểm thử nào (Security, Performance, Edge Cases...) trước khi bảo vệ đồ án?

YÊU CẦU ĐỊNH DẠNG:
- Trả về dạng văn bản nhận xét chuyên nghiệp, chia đề mục rõ ràng bằng Markdown.
- Cho điểm số dự kiến (thang điểm 10) ở cuối bài.
''';

      // 2. Cấu hình gọi API DeepSeek
      final url = Uri.parse('https://api.deepseek.com/chat/completions');
      final httpClient = HttpClient();
      final request = await httpClient.postUrl(url);

      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Bearer $apiKey');

      final payload = {
        'model': 'deepseek-chat', // Bản DeepSeek-V3 cực nhanh và ổn định
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.7,
        'stream': false,
      };

      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();

      // 3. Đọc dữ liệu trả về
      final responseBody = await response.transform(utf8.decoder).join();
      final jsonResponse = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        return jsonResponse['choices'][0]['message']['content'] ?? 'Không có phản hồi từ DeepSeek.';
      } else {
        return 'Lỗi từ DeepSeek API (Mã ${response.statusCode}):\n${jsonResponse['error']?['message'] ?? responseBody}';
      }
    } catch (e) {
      print('Lỗi gọi DeepSeek: $e');
      return 'Lỗi chi tiết khi kết nối DeepSeek: $e';
    }
  }
}