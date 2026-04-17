/// Small helper to convert byte counts into human-readable sizes.
class SizeFormatter {
  SizeFormatter._();

  static const List<String> _units = ['B', 'KB', 'MB', 'GB', 'TB'];

  /// Returns a compact size label, e.g. "2.3 MB".
  static String humanReadable(int bytes) {
    if (bytes <= 0) return '0 B';
    double value = bytes.toDouble();
    int unitIndex = 0;

    while (value >= 1024 && unitIndex < _units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final shown = value >= 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(2);
    return '$shown ${_units[unitIndex]}';
  }
}
