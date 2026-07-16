import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
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

  int _currentIndex = 0;
  String? _audioPath;
  bool _isRecording = false;
  bool _isPlaying = false;
  
  String _resultText = "AI พร้อมวิเคราะห์เสียงเคาะมะพร้าว";
  bool _isAnalyzing = false;
  
  bool _hasResult = false;
  double _youngProb = 0.0;
  double _perfectProb = 0.0;
  double _oldProb = 0.0;

  double _noiseCancellationLevel = 50.0;

  Timer? _waveformTimer;
  List<double> _waveformData = List.filled(40, 0.0);

  final List<Map<String, String>> _mockHistory = [
    {"date": "16 ก.ค. 2026 - 10:30 น.", "result": "สุกพอดี", "status": "perfect"},
    {"date": "15 ก.ค. 2026 - 14:15 น.", "result": "มะพร้าวอ่อน", "status": "young"},
    {"date": "14 ก.ค. 2026 - 09:00 น.", "result": "มะพร้าวแก่", "status": "old"},
    {"date": "12 ก.ค. 2026 - 16:45 น.", "result": "สุกพอดี", "status": "perfect"},
    {"date": "10 ก.ค. 2026 - 11:20 น.", "result": "มะพร้าวอ่อน", "status": "young"},
    {"date": "08 ก.ค. 2026 - 13:10 น.", "result": "สุกพอดี", "status": "perfect"},
  ];

  @override
  void initState() {
    super.initState();
    _initAndLoadModel();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _initAndLoadModel() async {
    await _tfLiteService.loadModel();
  }

  @override
  void dispose() {
    _waveformTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _tfLiteService.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    try {
      const XTypeGroup audioType = XTypeGroup(
        label: 'Audio Files',
        extensions: ['wav', 'm4a', 'mp3', 'aac'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [audioType]);
      if (file != null) {
        setState(() {
          _audioPath = file.path;
          _hasResult = false;
          _resultText = "อัปโหลดไฟล์สำเร็จ พร้อมวิเคราะห์";
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _startWaveformTimer() {
    _waveformData = List.filled(40, 0.0);
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      if (await _audioRecorder.isRecording()) {
        final amp = await _audioRecorder.getAmplitude();
        setState(() {
          double normalized = (amp.current + 60) / 60;
          if (normalized < 0.05) normalized = 0.05;
          if (normalized > 1.0) normalized = 1.0;
          
          _waveformData.add(normalized);
          if (_waveformData.length > 40) {
            _waveformData.removeAt(0);
          }
        });
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _waveformTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _audioPath = path;
          _isRecording = false;
          _resultText = "บันทึกเสียงสำเร็จ";
        });
      }
    } else {
      try {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final filePath = '${dir.path}/coconut_single_record.wav';

          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.wav), 
            path: filePath
          );
          
          _startWaveformTimer();

          setState(() {
            _isRecording = true;
            _audioPath = null;
            _hasResult = false;
            _resultText = "กำลังฟังเสียงเคาะ...";
          });
        }
      } catch (e) {
        debugPrint('Error recording: $e');
      }
    }
  }

  Future<void> _togglePlayAudio() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else {
      if (_audioPath != null) {
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
        setState(() => _isPlaying = true);
      }
    }
  }

  void _deleteAudio() {
    setState(() {
      _audioPath = null;
      _hasResult = false;
      _resultText = "ลบไฟล์แล้ว แตะไมค์เพื่ออัดใหม่";
      _waveformData = List.filled(40, 0.0);
    });
  }

  Future<void> _submitToAI() async {
    if (_audioPath == null) return;
    setState(() {
      _isAnalyzing = true;
      _hasResult = false;
      _resultText = "AI กำลังประมวลผล...";
    });

    Map<String, dynamic> result = await _tfLiteService.predictMaturity([_audioPath!]);

    setState(() {
      _isAnalyzing = false;
      _resultText = result["label"];
      _youngProb = result["young"];     
      _perfectProb = result["perfect"]; 
      _oldProb = result["old"];         
      _hasResult = true;
    });
  }

  Widget _buildProbBar(String label, double prob, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 75, 
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700))
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.fastOutSlowIn,
                  height: 14,
                  width: (_hasResult ? prob : 0) * 200, 
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 45, 
            child: Text(
              " ${(_hasResult ? prob * 100 : 0).toInt()}%", 
              textAlign: TextAlign.right, 
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildScanScreen() {
    bool hasFile = _audioPath != null;

    return SafeArea(
      // ⚠️ ครอบด้วย SingleChildScrollView เพื่อแก้ปัญหาจอล้น (Scroll ได้)
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 15, spreadRadius: 2)],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.noise_control_off_rounded, color: Colors.grey.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text("ตัดเสียงรบกวน", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          Text("${_noiseCancellationLevel.toInt()}%", style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: _noiseCancellationLevel,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        activeColor: const Color(0xFF059669),
                        inactiveColor: Colors.grey.shade200,
                        onChanged: (val) => setState(() => _noiseCancellationLevel = val),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: _hasResult ? Border.all(color: const Color(0xFF059669).withOpacity(0.3), width: 2) : null,
                      boxShadow: [
                        BoxShadow(
                          color: _hasResult ? const Color(0xFF059669).withOpacity(0.1) : Colors.grey.shade200, 
                          blurRadius: 20, 
                          spreadRadius: 5
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Text("STATUS", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, letterSpacing: 2, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(
                          _resultText,
                          style: TextStyle(
                            fontSize: hasFile || _isAnalyzing ? 22 : 18, 
                            fontWeight: FontWeight.w700, 
                            color: hasFile || _isAnalyzing ? const Color(0xFF064E3B) : Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        if (_hasResult) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: Colors.black12),
                          ),
                          _buildProbBar("มะพร้าวอ่อน", _youngProb, const Color(0xFF3B82F6)),
                          _buildProbBar("สุกพอดี", _perfectProb, const Color(0xFF10B981)),
                          _buildProbBar("มะพร้าวแก่", _oldProb, const Color(0xFFF59E0B)),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),

              SizedBox(
                height: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(40, (index) {
                    double height = 4.0;
                    if (_isRecording || hasFile) {
                      height = _waveformData[index] * 80;
                      if (height < 4.0) height = 4.0;
                    }
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 50),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 5,
                      height: height,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.redAccent : const Color(0xFF34D399),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    );
                  }),
                ),
              ),
              
              const SizedBox(height: 30),

              GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isRecording ? 100 : 90,
                  height: _isRecording ? 100 : 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? Colors.redAccent : const Color(0xFF059669),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? Colors.redAccent : const Color(0xFF059669)).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: _isRecording ? 10 : 5,
                      )
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isRecording ? "แตะเพื่อหยุดบันทึก" : "แตะเพื่อบันทึกเสียงเคาะ",
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!hasFile && !_isRecording)
                    ElevatedButton.icon(
                      onPressed: _pickAudioFile,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('อัปโหลดไฟล์'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF059669),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(0xFF059669)),
                        ),
                      ),
                    ),
                  
                  if (hasFile) ...[
                    IconButton(
                      onPressed: _togglePlayAudio,
                      icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, color: const Color(0xFF059669), size: 48),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: _deleteAudio,
                      icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: 36),
                    ),
                  ]
                ],
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: hasFile ? 1.0 : 0.4,
                  child: ElevatedButton(
                    onPressed: (hasFile && !_isAnalyzing) ? _submitToAI : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 5,
                      shadowColor: const Color(0xFF10B981).withOpacity(0.5),
                    ),
                    child: _isAnalyzing
                        ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('เริ่มวิเคราะห์ความสุก', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryScreen() {
    int totalCount = _mockHistory.length;
    int youngCount = _mockHistory.where((item) => item["status"] == "young").length;
    int perfectCount = _mockHistory.where((item) => item["status"] == "perfect").length;
    int oldCount = _mockHistory.where((item) => item["status"] == "old").length;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
            child: Text(
              "คลังบันทึกสถิติ",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF0A5C43)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: const Color(0xFF064E3B).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("จำนวนที่สแกนสะสมทั้งหมด", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Text("ทั้งหมด", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text("$totalCount", style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Text("ผล", style: TextStyle(color: Colors.white70, fontSize: 16)), 
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Colors.white24, height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryMiniCard("มะพร้าวอ่อน", youngCount, const Color(0xFF3B82F6)),
                      _buildSummaryMiniCard("สุกพอดี", perfectCount, const Color(0xFF10B981)),
                      _buildSummaryMiniCard("มะพร้าวแก่", oldCount, const Color(0xFFF59E0B)),
                    ],
                  )
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text("รายการประวัติล่าสุด", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: _mockHistory.length,
              itemBuilder: (context, index) {
                final item = _mockHistory[index];
                
                Color statusColor = item["status"] == "perfect" ? const Color(0xFF10B981) 
                                  : item["status"] == "young" ? const Color(0xFF3B82F6) 
                                  : const Color(0xFFF59E0B);
                IconData statusIcon = item["status"] == "perfect" ? Icons.check_circle_rounded 
                                    : item["status"] == "young" ? Icons.water_drop_rounded 
                                    : Icons.wb_sunny_rounded;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    title: Text(item["result"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(item["date"]!, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMiniCard(String title, int count, Color indicatorColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text("  $count ผล", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('COCONUT AI', style: TextStyle(color: Color(0xFF064E3B), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _currentIndex == 0 ? _buildScanScreen() : _buildHistoryScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF059669),
          unselectedItemColor: Colors.grey.shade400,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.radar_rounded), label: 'สแกนความสุก'),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'คลังสถิติ'),
          ],
        ),
      ),
    );
  }
}