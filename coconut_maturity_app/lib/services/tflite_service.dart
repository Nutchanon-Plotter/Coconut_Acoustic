import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:developer' as dev;

class TFLiteService {
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      dev.log('เตรียมพร้อมโหลดโมเดล');
    } catch (e) {
      dev.log('Error loading model: $e');
    }
  }

  // เปลี่ยนมารับ List ของที่อยู่ไฟล์เสียง (path) แทน
  Future<String> predictMaturity(List<String> audioPaths) async {
    // โค้ดจำลองการทำงาน: รับไฟล์ 3 ไฟล์มาประมวลผล
    dev.log('กำลังวิเคราะห์ไฟล์: $audioPaths');
    await Future.delayed(const Duration(seconds: 2)); 
    
    final mockResult = ["อ่อน (Premature)", "สุกพอดี (Mature)", "แก่ (Overmature)"];
    return mockResult[DateTime.now().second % 3];
  }

  void dispose() {
    _interpreter?.close();
  }
}