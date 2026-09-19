import 'package:flutter/material.dart';
// Lưu ý: Chữ 'Screens' viết hoa chữ S vì thư mục của bạn đang đặt tên viết hoa
import 'Screens/import_screen.dart'; 

void main() {
  runApp(const CapReviewApp());
}

class CapReviewApp extends StatelessWidget {
  const CapReviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Ẩn chữ debug ở góc màn hình
      title: 'CapReview - Chấm Điểm Testing',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ImportScreen(), // Trỏ thẳng đến màn hình Import bạn vừa tạo
    );
  }
}