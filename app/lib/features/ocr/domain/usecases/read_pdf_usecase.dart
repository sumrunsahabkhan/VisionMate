import '../repositories/pdf_repository.dart';

class ReadPdfUseCase {
  final PdfRepository repository;

  ReadPdfUseCase(this.repository);

  Future<List<String>> call(String path) async {
    return await repository.readPdfPages(path);
  }
}
