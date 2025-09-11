class SensorReading {
  final double temperature;
  final double humidity;
  final DateTime timestamp;
  final int? voltage;
  final int? ppm;

  SensorReading({
    required this.humidity,
    required this.temperature,
    required this.timestamp,
    this.voltage,
    this.ppm,
  });
}