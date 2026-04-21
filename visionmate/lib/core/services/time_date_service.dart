import 'package:intl/intl.dart';

class TimeDateService {
  String getCurrentTime() {
    return DateFormat('h:mm a').format(DateTime.now());
  }

  String getCurrentDate() {
    return DateFormat('MMMM d, yyyy').format(DateTime.now());
  }

  String getCurrentDay() {
    return DateFormat('EEEE').format(DateTime.now());
  }
}
