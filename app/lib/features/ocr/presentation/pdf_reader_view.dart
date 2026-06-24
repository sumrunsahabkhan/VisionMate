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

class _PdfReaderViewState extends ConsumerState<PdfReaderView> with TickerProviderStateMixin {
  StreamSubscription? _voskSubscription;
  Timer? _reminderTimer;
  late AnimationController _pulseController;
  
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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

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

  Future<void> _startWordReadingLoop() async {
    final tts = ref.read(ttsServiceProvider);
    
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
  void dispose() { 
    _cleanup(); 
    _pulseController.dispose();
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(ocrViewModelProvider);
    const accentColor = Colors.orangeAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5,
                    colors: [accentColor.withOpacity(0.05), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _pauseReadingManually, 
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(accentColor),
                    const SizedBox(height: 20),
                    _buildStatusBadge(accentColor),
                    const SizedBox(height: 20),
                    
                    if (viewModel.isSearchingFiles) 
                      const Expanded(child: Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2)))
                    else if (viewModel.pdfFiles.isEmpty) 
                      const Expanded(child: Center(child: Text("NO DOCUMENTS FOUND", style: TextStyle(color: Colors.white24, letterSpacing: 2, fontWeight: FontWeight.bold))))
                    else ...[
                      Expanded(
                        flex: viewModel.detectedText.isEmpty ? 4 : 1,
                        child: _buildFileList(viewModel, accentColor),
                      ),
                    ],

                    if (viewModel.detectedText.isNotEmpty)
                      Expanded(
                        flex: 3,
                        child: _buildTextContent(viewModel.detectedText, accentColor),
                      ),

                    const SizedBox(height: 20),
                    if (viewModel.pdfFiles.isNotEmpty && !viewModel.isProcessing && !_isAwaitingDecision && !_isReadingText && !_isPaused)
                      _buildReadButton(accentColor),
                    
                    const SizedBox(height: 10),
                    _buildExitLink(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white38, size: 20),
          onPressed: _handleExit,
        ),
        Column(
          children: [
            const Text("DOCUMENT READER", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4)),
            const SizedBox(height: 4),
            Container(width: 30, height: 2, color: color),
          ],
        ),
        const SizedBox(width: 48), // Spacer for balance
      ],
    );
  }

  Widget _buildStatusBadge(Color color) {
    String label = "SELECT A FILE";
    if (_isReadingText) label = "READING...";
    else if (_isPaused) label = "PAUSED";
    else if (_isAwaitingDecision) label = "FINISHED";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isReadingText)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)),
            ),
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildFileList(OCRViewModel viewModel, Color color) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: viewModel.pdfFiles.length,
      itemBuilder: (context, index) {
        final isSelected = viewModel.selectedIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? color.withOpacity(0.5) : Colors.white10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Icon(Icons.picture_as_pdf_rounded, color: isSelected ? color : Colors.white24),
            title: Text(
              viewModel.pdfFiles[index].path.split('/').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
            trailing: isSelected ? Icon(Icons.chevron_right_rounded, color: color) : null,
          ),
        );
      },
    );
  }

  Widget _buildTextContent(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 14, color: color.withOpacity(0.5)),
              const SizedBox(width: 8),
              Text("EXTRACTED TEXT", style: TextStyle(color: color.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadButton(Color color) {
    return GestureDetector(
      onTap: _readSelectedPdf,
      child: Container(
        height: 65,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: const Center(
          child: Text(
            "READ SELECTED",
            style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildExitLink() {
    return TextButton(
      onPressed: _handleExit,
      child: const Text(
        "GO BACK",
        style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
      ),
    );
  }
}
