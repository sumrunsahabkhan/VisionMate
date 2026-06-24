import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../domain/repositories/ocr_repository.dart';

class OCRRepositoryImpl implements OCRRepository {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> scanTextFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _recognizer.processImage(inputImage);
    return recognizedText.text;
  }

  void dispose() {
    _recognizer.close();
  }
}
