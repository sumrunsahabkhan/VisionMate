import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../domain/repositories/pdf_repository.dart';

class PdfRepositoryImpl implements PdfRepository {
  @override
  Future<List<String>> readPdfPages(String path) async {
    try {
      // Load the PDF document
      final List<int> bytes = await File(path).readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      List<String> pagesText = [];
      int total = document.pages.count;
      // Reading only first 3 pages as per requirement to avoid long processing
      int limit = total >= 3 ? 3 : total;

      PdfTextExtractor extractor = PdfTextExtractor(document);

      for (int i = 0; i < limit; i++) {
        // Extract text from the specific page
        final String text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        pagesText.add(text);
      }

      document.dispose();
      return pagesText;
    } catch (e) {
      print("Error extracting PDF text: $e");
      return [];
    }
  }
}
