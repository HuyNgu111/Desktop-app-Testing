import 'dart:convert';
import 'dart:developer' as developer;
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  // BẠN HÃY DÁN API KEY CỦA BẠN VÀO ĐÂY (API Key đang dùng ở Free Tier)
  static const String apiKey = 'AIzaSyDBeRLoXhhg9xNoqq-PrkMAomoGxbE1q-c'; 

  Future<Map<String, dynamic>?> analyzeTestCases(String rawText) async {
    try {
      // Sử dụng model 1.5 flash vì nó cực kỳ nhanh, rẻ và ổn định
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      // Đây chính là Prompt "Thần chú" ép AI đọc mọi loại file Excel
      final prompt = '''
Bạn là một Chuyên gia Đảm bảo Chất lượng Phần mềm (QA/Tester).
Dưới đây là dữ liệu thô (được phân tách bằng dấu |) trích xuất từ một file Excel chứa kịch bản kiểm thử (Test Case). File này có thể là Unit Test, UAT, hoặc Functional Test với cấu trúc cột lộn xộn.

NHIỆM VỤ CỦA BẠN:
1. Tự động nhận diện dòng nào là Tiêu đề cột (Header), dòng nào là Dữ liệu Test Case.
2. Trích xuất các thông tin cốt lõi sau cho mỗi Test Case (nếu không có thì để trống): 
   - Mã Test Case (ID)
   - Tên tính năng / Mô tả Test Case (Name)
   - Kết quả (Result: thường là Pass, Fail, OK, NG...)
3. Bỏ qua các dòng rác, metadata, lịch sử cập nhật (Histories) không liên quan.
4. Tổng hợp nhận xét (Feedback) về chất lượng của bộ Test Case này (ví dụ: mô tả có chi tiết không, test có bao phủ đủ các trường hợp không).

KẾT QUẢ TRẢ VỀ: BẮT BUỘC trả về duy nhất một chuỗi JSON hợp lệ với cấu trúc sau, không kèm bất kỳ giải thích hay định dạng markdown (```json) nào khác:
{
  "feedback": "Nhận xét tổng quan của bạn ở đây...",
  "test_cases": [
    { "id": "1.1.1", "name": "Login with valid Manager...", "result": "PASSED" }
  ]
}

DỮ LIỆU THÔ CẦN PHÂN TÍCH:
$rawText
''';

      // Gửi yêu cầu lên Google Gemini
      final response = await model.generateContent([Content.text(prompt)]);
      String aiResponseText = response.text ?? '{}';

      // SỬA LỖI: Dùng Biểu thức chính quy (Regex) để trích xuất đúng cái ruột JSON 
      // Bỏ qua mọi lời chào hỏi luyên thuyên của AI
      final RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
      final match = jsonRegex.firstMatch(aiResponseText);
      
      if (match != null) {
        aiResponseText = match.group(0)!;
      }

      // Ép kiểu chuỗi Text thành dạng JSON/Map
      Map<String, dynamic> finalData = jsonDecode(aiResponseText);
      return finalData;

    } catch (e) {
      developer.log('Lỗi khi gọi AI: $e', name: 'AiService');
      return null; // Trả về null nếu AI bị lỗi
    }
  }
}