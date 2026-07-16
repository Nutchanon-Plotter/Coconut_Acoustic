import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;

class TFLiteService {
  static const MethodChannel _channel = MethodChannel('com.example.coconut_maturity_app/tflite');
  bool _isModelLoaded = false;
  
  String _debugError = "ไม่ทราบสาเหตุ"; 

  final List<String> _labels = [
    "อ่อน (Premature)",
    "สุกพอดี (Mature)",
    "แก่ (Overmature)"
  ];

  Future<void> loadModel() async {
    try {
      dev.log('กำลังสั่งให้ Android โหลดโมเดล...');
      await _channel.invokeMethod('loadModel');
      _isModelLoaded = true;
      dev.log('ระบบ Native Android โหลดโมเดลสำเร็จ!');
    } catch (e) {
      _debugError = e.toString();
      dev.log('Error loading model via Native: $e');
    }
  }

  // ⚠️ ปรับการ Return จาก String เป็น Map<String, dynamic> เพื่อส่งค่าเปอร์เซ็นต์ออกไปด้วย
  Future<Map<String, dynamic>> predictMaturity(List<String> audioPaths) async {
    if (!_isModelLoaded) {
      return {
        "label": "Error: $_debugError",
        "young": 0.0,
        "perfect": 0.0,
        "old": 0.0,
      };
    }

    try {
      List<double> totalScores = [0.0, 0.0, 0.0];

      for (String path in audioPaths) {
        Float64List inputFeature = _processWavToFlatList(path);
        final List<dynamic> result = await _channel.invokeMethod('predict', {'input': inputFeature});

        // ดึงค่าผลลัพธ์จากการคำนวณของโมเดลจริงมาสะสมไว้
        totalScores[0] += (result[0] as double);
        totalScores[1] += (result[1] as double);
        totalScores[2] += (result[2] as double);
      }

      // หา Index ที่มีคะแนนสูงสุดเพื่อระบุคำตอบ
      int maxIndex = 0;
      double maxScore = totalScores[0];
      for (int i = 1; i < totalScores.length; i++) {
        if (totalScores[i] > maxScore) {
          maxScore = totalScores[i];
          maxIndex = i;
        }
      }

      // คำนวณหาอัตราส่วน (สัดส่วนความมั่นใจรวม) เพื่อแปลงกลับเป็นเปอร์เซ็นต์ให้ถูกต้อง
      double sum = totalScores[0] + totalScores[1] + totalScores[2];
      if (sum == 0) sum = 1.0; // ป้องกันการหารด้วยศูนย์

      return {
        "label": _labels[maxIndex],
        "young": totalScores[0] / sum,     // เปอร์เซ็นต์จริงจากโมเดลฝั่ง อ่อน
        "perfect": totalScores[1] / sum,   // เปอร์เซ็นต์จริงจากโมเดลฝั่ง สุกพอดี
        "old": totalScores[2] / sum,       // เปอร์เซ็นต์จริงจากโมเดลฝั่ง แก่
      };
    } catch (e) {
      dev.log('Prediction Error: $e');
      return {
        "label": "วิเคราะห์ล้มเหลว: $e",
        "young": 0.0,
        "perfect": 0.0,
        "old": 0.0,
      };
    }
  }

  Float64List _processWavToFlatList(String filePath) {
    File file = File(filePath);
    Uint8List bytes = file.readAsBytesSync();

    List<double> audioSignal = [];
    for (int i = 44; i < bytes.length - 1; i += 2) {
      int sample = bytes[i] | (bytes[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      audioSignal.add(sample / 32768.0);
    }

    Float64List flatList = Float64List(224 * 224 * 3);
    int step = max(1, (audioSignal.length / (224 * 224)).floor());
    int signalIndex = 0;
    int listIndex = 0;

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        double val = 0.0;
        if (signalIndex < audioSignal.length) {
          val = audioSignal[signalIndex].abs();
          signalIndex += step;
        }
        
        flatList[listIndex++] = val;         
        flatList[listIndex++] = val * 0.8;   
        flatList[listIndex++] = val * 0.5;   
      }
    }

    return flatList;
  }

  void dispose() {}
}