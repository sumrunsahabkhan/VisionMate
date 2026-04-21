import '../repositories/ocr_repository.dart';

class ScanTextUseCase {
  final OCRRepository repository;

  ScanTextUseCase(this.repository);

  Future<String> call(String imagePath) async {
    return await repository.scanTextFromImage(imagePath);
  }
}
