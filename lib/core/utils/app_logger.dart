class AppLogger {
  const AppLogger._();

  static void info(String message) {
    assert(() {
      // ignore: avoid_print
      print('[BLT] $message');
      return true;
    }());
  }
}
