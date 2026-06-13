class DistanceUtils {
  const DistanceUtils._();

  static String formatKilometers(double kilometers) {
    return '${kilometers.toStringAsFixed(1)} km';
  }
}
