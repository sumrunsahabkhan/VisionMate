import '../presentation/assistant_viewmodel.dart';
import '../../voice/intent.dart';

class TimeIntentLogic {
  static String execute() {
    final now = DateTime.now();
    return "The time is ${now.hour}:${now.minute}";
  }

  static String executeDate() {
    final now = DateTime.now();
    return "Today is ${now.day}-${now.month}-${now.year}";
  }
}
