import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/usecases/scan_text_usecase.dart';
import '../domain/usecases/read_pdf_usecase.dart';
import '../data/ocr_repository_impl.dart';
import '../data/pdf_repository_impl.dart';

class OCRViewModel extends ChangeNotifier {
  final ScanTextUseCase scanTextUseCase;
  final ReadPdfUseCase readPdfUseCase;

  String detectedText = "";
  bool isProcessing = false;
  
  List<File> pdfFiles = [];
  int selectedIndex = -1;
  bool isSearchingFiles = false;

  OCRViewModel(this.scanTextUseCase, this.readPdfUseCase);

  Future<void> fetchPdfFiles() async {
    isSearchingFiles = true;
    pdfFiles = [];
    notifyListeners();

    try {
      // 1. Check Common Android Root Directories (External Storage)
      List<String> roots = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents', // WhatsApp PDFs
      ];

      for (var path in roots) {
        final dir = Directory(path);
        if (await dir.exists()) {
          _scanDirectory(dir);
        }
      }

      // 2. Use path_provider for app-specific and external storage
      final extDir = await getExternalStorageDirectory(); // Android/data/com.example/files
      if (extDir != null) {
        // Go up to the root of external storage to scan more broadly if possible
        String rootPath = extDir.path.split('/Android')[0];
        final rootDir = Directory(rootPath);
        if (await rootDir.exists()) {
          // Recursive scan is heavy, so we target common folders first, then maybe shallow scan others
          _scanDirectory(rootDir, recursive: false);
        }
      }
      
      final docDir = await getApplicationDocumentsDirectory();
      _scanDirectory(docDir);

      // Remove duplicates and sort by name
      final seen = <String>{};
      pdfFiles = pdfFiles.where((file) => seen.add(file.path)).toList();
      pdfFiles.sort((a, b) => a.path.split('/').last.toLowerCase().compareTo(b.path.split('/').last.toLowerCase()));
      
      if (pdfFiles.isNotEmpty) {
        selectedIndex = 0;
      }
    } catch (e) {
      debugPrint("Error fetching PDFs: $e");
    } finally {
      isSearchingFiles = false;
      notifyListeners();
    }
  }

  void _scanDirectory(Directory dir, {bool recursive = false}) {
    try {
      if (!dir.existsSync()) return;
      final entities = dir.listSync(recursive: recursive, followLinks: false);
      for (var entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          pdfFiles.add(entity);
        }
      }
    } catch (e) {
      debugPrint("Could not list directory ${dir.path}: $e");
    }
  }

  void nextFile() {
    if (pdfFiles.isEmpty) return;
    selectedIndex = (selectedIndex + 1) % pdfFiles.length;
    notifyListeners();
  }

  void previousFile() {
    if (pdfFiles.isEmpty) return;
    selectedIndex = (selectedIndex - 1 + pdfFiles.length) % pdfFiles.length;
    notifyListeners();
  }

  File? get selectedFile => selectedIndex != -1 ? pdfFiles[selectedIndex] : null;

  Future<String> scanText(String imagePath) async {
    isProcessing = true;
    notifyListeners();
    
    try {
      detectedText = await scanTextUseCase(imagePath);
      return detectedText;
    } catch (e) {
      debugPrint("OCR Error: $e");
      return "";
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> readPdf(String path) async {
    isProcessing = true;
    notifyListeners();

    try {
      List<String> pages = await readPdfUseCase(path);
      detectedText = pages.join("\n");
    } catch (e) {
      debugPrint("PDF Error: $e");
      detectedText = "Error reading PDF content.";
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }
  
  void clear() {
    detectedText = "";
    pdfFiles = [];
    selectedIndex = -1;
    notifyListeners();
  }
}

final ocrRepositoryProvider = Provider((ref) => OCRRepositoryImpl());
final pdfRepositoryProvider = Provider((ref) => PdfRepositoryImpl());

final scanTextUseCaseProvider = Provider((ref) => ScanTextUseCase(ref.read(ocrRepositoryProvider)));
final readPdfUseCaseProvider = Provider((ref) => ReadPdfUseCase(ref.read(pdfRepositoryProvider)));

final ocrViewModelProvider = ChangeNotifierProvider((ref) => OCRViewModel(
  ref.read(scanTextUseCaseProvider),
  ref.read(readPdfUseCaseProvider)
));
