class DateTimeUtil {
  DateTimeUtil._();

  static String watermarkStamp(DateTime date) {
    return '${_two(date.day)}-${_two(date.month)}-${date.year} '
        '${_two(date.hour)}:${_two(date.minute)}:${_two(date.second)}';
  }

  static String fileStamp(DateTime date) {
    return '${date.year}${_two(date.month)}${_two(date.day)}_'
        '${_two(date.hour)}${_two(date.minute)}${_two(date.second)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
