import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ocr_viewmodel.dart';
import '../../../core/services/service_providers.dart';
import '../../assistant/presentation/assistant_viewmodel.dart';

class PdfReaderView extends ConsumerStatefulWidget {
  const PdfReaderView({super.key});

  @override
  ConsumerState<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends ConsumerState<PdfReaderView> {
  StreamSubscription? _voskSubscription;
  Timer? _reminderTimer;
  bool _isAwaitingDecision = false;
  bool _isReadingText = false;
  bool _isPaused = false;
  
  List<String> _words = [];
  int _currentWordIndex = 0;
  DateTime _lastCommandTime = DateTime.now();
  bool _shouldStopReading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _initPdfReader());
  }

  Future<void> _initPdfReader() async {
    final viewModel = ref.read(ocrViewModelProvider);
    await viewModel.fetchPdfFiles();
    
    String message = "";
    if (viewModel.pdfFiles.isEmpty) {
      message = "No PDF files found. Say Exit to go back.";
    } else {
      message = "Found ${viewModel.pdfFiles.length} files. Currently selected: ${viewModel.pdfFiles[0].path.split('/').last}. Say Next, Previous, Read, or Exit.";
    }

    _speakWithListeningRestart(message);
  }

  Future<void> _speakWithListeningRestart(String text) async {
    final tts = ref.read(ttsServiceProvider);
    final vosk = ref.read(voskServiceProvider);

    _voskSubscription?.cancel();
    vosk.stop();
    _reminderTimer?.cancel();

    tts.onComplete(() {
      if (mounted) {
        _startVoiceListening();
        _resetReminder();
        tts.onComplete(() {}); 
      }
    });
    
    await tts.speak(text);
  }

  void _resetReminder() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && !_isReadingText) {
        if (_isPaused) {
           _speakWithListeningRestart("Reading is paused. Say Resume, Another, or Exit.");
        } else if (_isAwaitingDecision) {
          _speakWithListeningRestart("Reading complete. Say Another or Exit.");
        } else {
          final viewModel = ref.read(ocrViewModelProvider);
          if (viewModel.pdfFiles.isNotEmpty) {
             _speakWithListeningRestart("Selected file is ${viewModel.selectedFile?.path.split('/').last}. Say Next, Previous, Read, or Exit.");
          }
        }
      }
    });
  }

  void _startVoiceListening() {
    _voskSubscription?.cancel();
    final vosk = ref.read(voskServiceProvider);
    vosk.start();
    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted || _isReadingText) return;
      
      final isFinal = data['isFinal'] ?? false;
      if (!isFinal) return;

      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      if (text.isEmpty) return;

      if (DateTime.now().difference(_lastCommandTime).inMilliseconds < 800) return;
      _lastCommandTime = DateTime.now();

      debugPrint("PDF Command: $text");
      
      if (text.contains("exit") || text.contains("back") || text.contains("stop")) {
        _handleExit();
        return;
      }

      final viewModel = ref.read(ocrViewModelProvider);
      
      if (_isPaused) {
        if (text.contains("resume") || text.contains("dobara") || text.contains("continue") || text.contains("shuru")) {
          _resumeReading();
          return;
        }
      }

      if (_isPaused || _isAwaitingDecision) {
        if (text.contains("another") || text.contains("aur") || text.contains("next") || text.contains("yes")) {
          setState(() { 
            _isPaused = false; 
            _isAwaitingDecision = false; 
            viewModel.detectedText = ""; 
            _currentWordIndex = 0; 
            _words = [];
          });
          _speakWithListeningRestart("Sure. Browsing files. Say Next, Previous, or Read.");
          return;
        } 
      }

      if (!_isPaused && !_isAwaitingDecision && !_isReadingText) {
        if (text.contains("next") || text.contains("agla")) {
          viewModel.nextFile();
          _announceCurrentFile();
        } else if (text.contains("previous") || text.contains("pichla")) {
          viewModel.previousFile();
          _announceCurrentFile();
        } else if (text.contains("read") || text.contains("parho") || text.contains("shuru")) {
          _readSelectedPdf();
        }
      }
    });
  }

  void _announceCurrentFile() {
    final viewModel = ref.read(ocrViewModelProvider);
    if (viewModel.selectedFile != null) {
      _speakWithListeningRestart("Selected: ${viewModel.selectedFile!.path.split('/').last}. Say Read or Exit.");
    }
  }

  void _pauseReadingManually() {
    if (_isReadingText) {
      _shouldStopReading = true;
      setState(() {
        _isReadingText = false;
        _isPaused = true;
      });
      ref.read(ttsServiceProvider).stop();
      _speakWithListeningRestart("Reading paused. Say Resume, Another, or Exit.");
    }
  }

  void _resumeReading() async {
    if (_isPaused) {
      setState(() {
        _isPaused = false;
        _isReadingText = true;
        _shouldStopReading = false;
      });
      _startWordReadingLoop();
    }
  }

  Future<void> _readSelectedPdf() async {
    final viewModel = ref.read(ocrViewModelProvider);
    if (viewModel.selectedFile == null) return;

    final tts = ref.read(ttsServiceProvider);
    _voskSubscription?.cancel();
    ref.read(voskServiceProvider).stop();
    _reminderTimer?.cancel();
    
    final completer = Completer<void>();
    tts.onComplete(() { if(!completer.isCompleted) completer.complete(); tts.onComplete(() {}); });
    await tts.speak("Extracting text. Please wait.");
    await completer.future;

    await viewModel.readPdf(viewModel.selectedFile!.path);
    
    if (mounted && viewModel.detectedText.isNotEmpty) {
      // 🔥 WORD TRACKING LOGIC: Split by words
      _words = viewModel.detectedText.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
      _currentWordIndex = 0;
      _shouldStopReading = false;

      final guideCompleter = Completer<void>();
      tts.onComplete(() { if(!guideCompleter.isCompleted) guideCompleter.complete(); tts.onComplete(() {}); });
      await tts.speak("Extraction successful. Double tap to pause. Starting now.");
      await guideCompleter.future;

      if (!_shouldStopReading) {
        setState(() => _isReadingText = true);
        _startWordReadingLoop();
      }
    } else if (mounted) {
      _speakWithListeningRestart("Sorry, no readable text found.");
    }
  }

  // 🔥 CORE FIX: WORD-BY-WORD LOOP
  Future<void> _startWordReadingLoop() async {
    final tts = ref.read(ttsServiceProvider);
    
    // We read in chunks of 5 words for natural flow but keep tracking precise
    while (_currentWordIndex < _words.length && _isReadingText && !_shouldStopReading) {
      int end = (_currentWordIndex + 10 < _words.length) ? _currentWordIndex + 10 : _words.length;
      String chunk = _words.sublist(_currentWordIndex, end).join(" ");
      
      final completer = Completer<void>();
      tts.onComplete(() { if (!completer.isCompleted) completer.complete(); });
      tts.onCancel(() { if (!completer.isCompleted) completer.complete(); });
      
      await tts.speak(chunk);
      await completer.future;
      
      if (_isReadingText && !_shouldStopReading) {
        _currentWordIndex = end;
      } else {
        break; 
      }
    }

    if (_currentWordIndex >= _words.length && mounted && _isReadingText && !_shouldStopReading) {
      setState(() {
        _isReadingText = false;
        _isAwaitingDecision = true;
        _currentWordIndex = 0;
      });
      _speakWithListeningRestart("Reading complete. Would you like to read another file or exit?");
    }
  }

  void _handleExit() {
    _cleanup();
    ref.read(ttsServiceProvider).speak("Exiting PDF reader.");
    ref.read(assistantViewModelProvider.notifier).exitSubModule();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _cleanup() {
    _shouldStopReading = true;
    _reminderTimer?.cancel();
    _voskSubscription?.cancel();
    try {
      ref.read(voskServiceProvider).stop();
      ref.read(ocrViewModelProvider).clear();
      ref.read(ttsServiceProvider).onComplete(() {});
      ref.read(ttsServiceProvider).stop();
    } catch (_) {}
  }

  @override
  void dispose() { _cleanup(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrViewModelProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      appBar: AppBar(
        title: const Text("PDF READER", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: _handleExit),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _pauseReadingManually, 
        child: Container(
          decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.topCenter, radius: 1.5, colors: [Colors.orangeAccent.withOpacity(0.05), Colors.transparent])),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                if (ocrState.isSearchingFiles) const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.orangeAccent)))
                else if (ocrState.pdfFiles.isEmpty) const Expanded(child: Center(child: Text("NO PDF FILES FOUND", style: TextStyle(color: Colors.white54, fontSize: 16))))
                else ...[
                  Text(
                    _isReadingText ? "READING (DOUBLE TAP TO PAUSE)" : (_isPaused ? "PAUSED - SAY 'RESUME' OR 'EXIT'" : (_isAwaitingDecision ? "SAY 'ANOTHER' OR 'EXIT'" : "SAY 'NEXT', 'PREVIOUS', 'READ' OR 'EXIT'")),
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 4),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    flex: ocrState.detectedText.isEmpty ? 4 : 1,
                    child: ListView.builder(
                      itemCount: ocrState.pdfFiles.length,
                      itemBuilder: (context, index) {
                        final isSelected = ocrState.selectedIndex == index;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: isSelected ? Colors.orangeAccent.withOpacity(0.1) : Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.orangeAccent : Colors.white10, width: 2)),
                          child: ListTile(
                            leading: Icon(Icons.picture_as_pdf, color: isSelected ? Colors.orangeAccent : Colors.white38),
                            title: Text(ocrState.pdfFiles[index].path.split('/').last, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 16)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (ocrState.detectedText.isNotEmpty)
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))),
                      child: SingleChildScrollView(child: Text(ocrState.detectedText, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.6))),
                    ),
                  ),
                const SizedBox(height: 20),
                if (ocrState.pdfFiles.isNotEmpty && !ocrState.isProcessing && !_isAwaitingDecision && !_isReadingText && !_isPaused)
                  ElevatedButton(
                    onPressed: _readSelectedPdf,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 70), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35))),
                    child: const Text("READ SELECTED FILE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
