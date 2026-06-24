abstract class PdfRepository {
  Future<List<String>> readPdfPages(String path);
}
