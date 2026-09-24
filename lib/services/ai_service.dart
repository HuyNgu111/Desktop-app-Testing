import 'dart:convert';
import 'dart:io';
import 'api_key.dart';

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
      if (safeSrs.length > 15000) {
        safeSrs = '${safeSrs.substring(0, 15000)}\n\n...[Đã cắt bớt phần sau của tài liệu SRS]...';
      }

      const systemPrompt =
          'Bạn là một Chuyên gia QA Lead / Technical Reviewer chuyên thẩm định và rà soát tài liệu kiểm thử phần mềm.';

      final userPrompt = '''
Dưới đây là 2 tài liệu của dự án:

TÀI LIỆU 1 (TỔNG QUAN YÊU CẦU & DANH SÁCH USE CASE TỪ SRS/WORD):
$safeSrs

TÀI LIỆU 2 (DANH SÁCH KỊCH BẢN SYSTEM TEST TỪ EXCEL):
$excelSummary

MỤC TIÊU DUY NHẤT: THẨM ĐỊNH VÀ REVIEW CHẤT LƯỢNG TÀI LIỆU (TUYỆT ĐỐI KHÔNG CHẤM ĐIỂM, KHÔNG CHO ĐIỂM SỐ).
Hãy đóng vai một Tester thực chiến giàu kinh nghiệm để phân tích sâu theo các tiêu chí sau:

1. ĐÁNH GIÁ ĐỘ BAO PHỦ USE CASE (COVERAGE GAP ANALYSIS):
   - Đọc danh sách Use Cases trong Tài liệu 1 và đối chiếu với các Module/Test Cases trong Tài liệu 2.
   - Chỉ ra cụ thể: Những Use Cases hoặc tính năng cốt lõi nào trong SRS HOÀN TOÀN BỊ BỎ QUÊN?
   - Nhóm có viết đủ ca kiểm thử cho cả "Happy Case" và "Bad/Negative Case" chưa? Liệt kê các Use Case thiếu Bad Case.

2. ĐÁNH GIÁ TÍNH HỢP LÝ & KHẢ NĂNG THỰC THI (TESTABILITY AUDIT):
   - Soi lỗi thiếu Dữ liệu test (Test Data): Procedure ghi chung chung kiểu "Enter PM email & password" mà không có dữ liệu mẫu -> Không đạt.
   - Soi lỗi Tiền điều kiện (Pre-condition): Ghi sơ sài kiểu "System deployed" là vô nghĩa.
   - Soi lỗi Kết quả mong đợi (Expected Results): Có kiểm chứng được không?
   - Trích dẫn cụ thể các Mã Test Case (ID) viết sơ sài để làm bằng chứng.

3. ĐÁNH GIÁ TIẾN TRÌNH TEST VÀ RỦI RO THỰC TẾ (DEFECT TREND).

BẮT BUỘC TRẢ VỀ DUY NHẤT ĐỊNH DẠNG JSON NHƯ SAU:
{
  "markdown_report": "Toàn bộ bài nhận xét review chi tiết của bạn bằng văn bản Markdown (ngắn gọn súc tích, chia mục 1, 2, 3 rõ ràng, TUYỆT ĐỐI KHÔNG CHO ĐIỂM SỐ).",
  "excel_defects": [
    {
      "type": "Thiếu Use Case",
      "id": "Tên Use Case bị thiếu",
      "description": "Mô tả tính năng trong SRS",
      "reason": "Chưa có bất kỳ test case nào kiểm thử tính năng này"
    },
    {
      "type": "Kịch bản sơ sài",
      "id": "TC-AUTH-LGN-PM",
      "description": "Enter PM email & password",
      "reason": "Thiếu test data cụ thể, Pre-condition quá sơ sài"
    }
  ]
}
(LƯU Ý: Phần excel_defects chỉ cần trích xuất TỐI ĐA 15 LỖI TIÊU BIỂU NHẤT để tránh bị quá tải độ dài JSON).
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
        'response_format': {'type': 'json_object'},
        'temperature': 0.5,
        'max_tokens': 8192, // MỞ RỘNG TỐI ĐA GIỚI HẠN OUTPUT LÊN 8192 TOKENS
      };

      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final jsonResponse = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        String aiContent = jsonResponse['choices'][0]['message']['content'] ?? '{}';

        // 1. Trích xuất ruột JSON
        final RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
        final match = jsonRegex.firstMatch(aiContent);
        if (match != null) {
          aiContent = match.group(0)!;
        }

        // 2. Thử giải mã JSON chuẩn
        try {
          Map<String, dynamic> parsedData = jsonDecode(aiContent);
          return AiReviewResult(
            markdownReport: parsedData['markdown_report'] ?? 'Không có nhận xét.',
            excelDefects: List<Map<String, dynamic>>.from(parsedData['excel_defects'] ?? []),
          );
        } catch (jsonErr) {
          // 3. CƠ CHẾ CỨU HỘ: Nếu JSON bị cắt cụt đuôi do quá dài, tự động bóc tách bài Markdown để hiện lên App
          print('Cảnh báo: JSON bị cụt đuôi, đang kích hoạt cơ chế cứu hộ Markdown...');
          
          String extractedMd = '';
          final mdRegex = RegExp(r'"markdown_report"\s*:\s*"([\s\S]*?)(?:"\s*,\s*"excel_defects"|$)', dotAll: true);
          final mdMatch = mdRegex.firstMatch(aiContent);
          
          if (mdMatch != null) {
            extractedMd = mdMatch.group(1) ?? '';
            // Giải mã ký tự xuống dòng và nháy kép
            extractedMd = extractedMd.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
          } else {
            extractedMd = aiContent; // Hiển thị nội dung thô nếu không bóc tách được
          }

          return AiReviewResult(
            markdownReport: extractedMd.isNotEmpty ? extractedMd : 'Không thể bóc tách nội dung review.',
            excelDefects: [],
          );
        }
      } else {
        return AiReviewResult(
          markdownReport: 'Lỗi API (${response.statusCode}): $responseBody',
          excelDefects: [],
        );
      }
    } catch (e) {
      return AiReviewResult(
        markdownReport: 'Lỗi chi tiết khi kết nối AI: $e',
        excelDefects: [],
      );
    }
  }
}