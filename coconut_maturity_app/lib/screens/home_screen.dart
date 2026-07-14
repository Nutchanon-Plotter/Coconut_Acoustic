import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart'; // ⚠️ เปลี่ยนเป็นตัวนี้
import '../services/tflite_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TFLiteService _tfLiteService = TFLiteService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<String?> _audioPaths = [null, null, null];
  int? _recordingIndex;
  int? _playingIndex;
  
  String _resultText = "กำลังเตรียมความพร้อมของระบบ AI...";
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _initAndLoadModel();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() => _playingIndex = null);
    });
  }

  Future<void> _initAndLoadModel() async {
    await _tfLiteService.loadModel();
    if (mounted) {
      setState(() {
        _resultText = "รอรับข้อมูลเสียง 3 จุด (AI พร้อม)";
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _tfLiteService.dispose();
    super.dispose();
  }

  // --------------------------------------------------------
  // ฟังก์ชันอัปโหลดไฟล์เสียงจากเครื่อง
  // --------------------------------------------------------
// --------------------------------------------------------
  // ฟังก์ชันอัปโหลดไฟล์เสียงจากเครื่อง (อัปเดตรองรับ file_picker V.ล่าสุด)
  // --------------------------------------------------------
// --------------------------------------------------------
  // ฟังก์ชันอัปโหลดไฟล์ (ใช้ file_selector ของ Official)
  // --------------------------------------------------------
  Future<void> _pickAudioFile(int index) async {
    try {
      // กำหนดประเภทไฟล์ที่อนุญาต
      const XTypeGroup audioType = XTypeGroup(
        label: 'Audio Files',
        extensions: ['wav', 'm4a', 'mp3', 'aac'],
      );
      
      // เปิดหน้าต่างเลือกไฟล์
      final XFile? file = await openFile(acceptedTypeGroups: [audioType]);

      if (file != null) {
        setState(() {
          _audioPaths[index] = file.path;
          _resultText = "อัปโหลดไฟล์จุดที่ ${index + 1} สำเร็จ";
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  // --------------------------------------------------------
  // ฟังก์ชันบันทึกเสียงผ่านไมค์
  // --------------------------------------------------------
  Future<void> _startRecording(int index) async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/coconut_light_$index.wav';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav), 
          path: filePath
        );
        setState(() {
          _recordingIndex = index;
          _resultText = "กำลังฟังเสียงจุดที่ ${index + 1}...";
        });
      }
    } catch (e) {
      debugPrint('Error recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    if (path != null && _recordingIndex != null) {
      setState(() {
        _audioPaths[_recordingIndex!] = path;
        _recordingIndex = null;
        _resultText = "บันทึกเสียงสำเร็จ";
      });
    }
  }

  Future<void> _playAudio(int index) async {
    final path = _audioPaths[index];
    if (path != null) {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _playingIndex = index);
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() => _playingIndex = null);
  }

  void _deleteAudio(int index) {
    setState(() {
      _audioPaths[index] = null;
      _resultText = "ลบไฟล์จุดที่ ${index + 1} แล้ว";
    });
  }

  Future<void> _submitToAI() async {
    setState(() {
      _isAnalyzing = true;
      _resultText = "AI กำลังประมวลผลแบบออฟไลน์...";
    });

    List<String> validPaths = _audioPaths.whereType<String>().toList();
    String prediction = await _tfLiteService.predictMaturity(validPaths);

    setState(() {
      _isAnalyzing = false;
      _resultText = prediction;
    });
  }

  Widget _buildGlassCard(int index) {
    bool hasFile = _audioPaths[index] != null;
    bool isRecordingThis = _recordingIndex == index;
    bool isPlayingThis = _playingIndex == index;
    bool isOtherRecording = _recordingIndex != null && _recordingIndex != index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRecordingThis 
                  ? Colors.red.withOpacity(0.05) 
                  : Colors.white.withOpacity(hasFile ? 0.8 : 0.5), 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRecordingThis 
                    ? Colors.redAccent.withOpacity(0.3) 
                    : Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isRecordingThis 
                      ? Colors.redAccent.withOpacity(0.1) 
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: hasFile 
                          ? [const Color(0xFF34D399), const Color(0xFF059669)] 
                          : [Colors.grey.shade300, Colors.grey.shade400],
                    ),
                    boxShadow: hasFile ? [
                      BoxShadow(color: const Color(0xFF059669).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))
                    ] : [],
                  ),
                  child: Center(
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'จุดเคาะที่ ${index + 1}',
                        style: const TextStyle(color: Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          isRecordingThis ? 'กำลังอัดเสียง...' : (hasFile ? 'พร้อมวิเคราะห์' : 'แตะเพื่อบันทึก หรืออัปโหลด'),
                          key: ValueKey(isRecordingThis ? 1 : (hasFile ? 2 : 3)),
                          style: TextStyle(
                            color: isRecordingThis ? Colors.redAccent : (hasFile ? const Color(0xFF059669) : Colors.grey.shade600), 
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (isRecordingThis)
                  IconButton(
                    icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 38),
                    onPressed: _stopRecording,
                  )
                else if (hasFile) ...[
                  IconButton(
                    icon: Icon(isPlayingThis ? Icons.pause_circle : Icons.play_circle, color: const Color(0xFF059669), size: 34),
                    onPressed: isPlayingThis ? _stopAudio : () => _playAudio(index),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: 28),
                    onPressed: () => _deleteAudio(index),
                  ),
                ]
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ⚠️ ปุ่มอัปโหลดไฟล์ที่เพิ่มเข้ามา
                      IconButton(
                        icon: const Icon(Icons.upload_file_rounded, color: Color(0xFF059669), size: 28),
                        onPressed: isOtherRecording ? null : () => _pickAudioFile(index),
                        tooltip: 'อัปโหลดไฟล์',
                      ),
                      IconButton(
                        icon: const Icon(Icons.mic_none_rounded, color: Color(0xFF059669), size: 32),
                        onPressed: isOtherRecording ? null : () => _startRecording(index),
                        tooltip: 'บันทึกเสียง',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isReadyToAnalyze = _audioPaths.every((path) => path != null);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('COCONUT AI', style: TextStyle(color: Color(0xFF064E3B), fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -50, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD1FAE5).withOpacity(0.6),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()),
            ),
          ),
          Positioned(
            bottom: -100, right: -50,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFA7F3D0).withOpacity(0.4),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
            ),
          ),

          SafeArea(
            // ⚠️ ปรับ LayoutBuilder เพื่อแก้ปัญหาหน้าจอล้น 100%
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildGlassCard(0),
                          _buildGlassCard(1),
                          _buildGlassCard(2),
                          
                          const Spacer(),

                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            margin: const EdgeInsets.symmetric(horizontal: 30),
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF059669).withOpacity(isReadyToAnalyze ? 0.15 : 0.05), blurRadius: 30, spreadRadius: 5)
                              ],
                            ),
                            child: Column(
                              children: [
                                Text("STATUS", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, letterSpacing: 2, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _resultText,
                                    key: ValueKey(_resultText),
                                    style: TextStyle(
                                      fontSize: isReadyToAnalyze || _isAnalyzing ? 22 : 16, 
                                      fontWeight: FontWeight.w700, 
                                      color: isReadyToAnalyze || _isAnalyzing ? const Color(0xFF064E3B) : Colors.grey.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 30),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: isReadyToAnalyze ? 1.0 : 0.5,
                              child: GestureDetector(
                                onTap: (isReadyToAnalyze && !_isAnalyzing) ? _submitToAI : null,
                                child: Container(
                                  width: double.infinity,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)], 
                                    ),
                                    borderRadius: BorderRadius.circular(32),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF059669).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))
                                    ],
                                  ),
                                  child: Center(
                                    child: _isAnalyzing 
                                      ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                      : const Text('เริ่มวิเคราะห์ความสุก', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}