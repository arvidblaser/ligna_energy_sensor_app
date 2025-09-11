import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/sensor_reading.dart';

class ExportService {
  String convertToCSV(List<SensorReading> dataList) {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Temperature,Humidity,Voltage,CO2level');
    for (var item in dataList) {
      buffer.writeln(
        '${item.timestamp},${item.temperature},${item.humidity},${item.voltage},${item.ppm}',
      );
    }
    return buffer.toString();
  }

  Future<File> saveCSVToFile(String csvData, String fileName) async {
    final directory = await getTemporaryDirectory();
    final path = directory.path;
    final file = File('$path/$fileName.csv');
    return file.writeAsString(csvData);
  }

  Future<void> shareFile(String path) async {
    final params = ShareParams(
      text: 'Exported data from the Ligna Energy Sensor App',
      files: [XFile(path)],
    );
    await SharePlus.instance.share(params);
  }

  Future<void> shareCSVData(String csvData) async {
    await SharePlus.instance.share(
      ShareParams(
        title: 'Exported data from the Ligna Energy Sensor App',
        text: csvData,
      ),
    );
  }

  Future<void> exportAndShare(List<SensorReading> dataList) async {
    final csvData = convertToCSV(dataList);
    final file = await saveCSVToFile(csvData, 'ble_data');
    await shareFile(file.path);
  }
}