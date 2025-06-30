import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:share_plus/share_plus.dart';


class ScanResultTile extends StatefulWidget {
  const ScanResultTile({super.key, required this.result, this.onTap});

  final ScanResult result;
  final VoidCallback? onTap;

  @override
  State<ScanResultTile> createState() => _ScanResultTileState();
}

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

class _ScanResultTileState extends State<ScanResultTile> {
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
//
 // Timer? _updateTimer;
 // int _secondsSinceLastUpdate = 0;
  
  final List<SensorReading> _sensorReadingList = [];
  static const int maxDataPoints = 2160; // var 5:e sekund -> 3h, 3*3600/5

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.result.device.connectionState.listen((state) {
      _connectionState = state;
      if (mounted) {
        setState(() {}); // Uppdatera bara UI för anslutningsstatus
      }
    });

    // Prenumerera på scanresultat för att få nya avläsningar direkt
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        // Hitta resultatet för denna enhet
        ScanResult? deviceResult;
        for (var result in results) {
          if (result.device.remoteId == widget.result.device.remoteId) {
            deviceResult = result;
            break;
          }
        }
        
        if (deviceResult != null && hasSensorReading(deviceResult.advertisementData)) {
          SensorReading sr = decodeData(deviceResult.advertisementData.advName, deviceResult.advertisementData.serviceData);
          addToSensorReadingList(sr);
          setState(() {}); // Uppdatera UI för att visa nya data
        }
      }
    });

   // // Starta timern för att uppdatera räknaren varje sekund
   // _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
   //       print("Build anropas: ${DateTime.now()}"); // Debug-utskrift
//
   //   if (mounted && _sensorReadingList.isNotEmpty) {
   //     setState(() {
   //       _secondsSinceLastUpdate = DateTime.now().difference(_sensorReadingList.last.timestamp).inSeconds;
   //     });
   //   }
   // });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _scanResultsSubscription.cancel();
    //_updateTimer?.cancel(); // Avbryt timern när widgeten förstörs
    super.dispose();
  }

  String getNiceHexArray(List<int> bytes) {
    return '[${bytes.map((i) => i.toRadixString(16).padLeft(2, '0')).join(', ')}]';
  }

  String getNiceManufacturerData(List<List<int>> data) {
    return data.map((val) => getNiceHexArray(val)).join(', ').toUpperCase();
  }

  String getNiceServiceData(Map<Guid, List<int>> data) {
    return data.entries.map((v) => '${v.key}: ${getNiceHexArray(v.value)}').join(', ').toUpperCase();
  }

  String getDecodedServiceData(SensorReading sr) {
    List<String> parts = [];
    if (sr.voltage != null) parts.add('Voltage: ${sr.voltage}mV');
    parts.add('Temp: ${sr.temperature}°C');
    parts.add('Hum: ${sr.humidity}%');
    if (sr.ppm != null) parts.add('CO2: ${sr.ppm} PPM');
    return parts.join(', ');
  }

  void addToSensorReadingList(SensorReading sr){
    // Lägg till det nya temperaturvärdet i historiken
    _sensorReadingList.add(sr);
    if (_sensorReadingList.length > maxDataPoints) {
      _sensorReadingList.removeAt(0);
    }
  }

  SensorReading decodeData(String name, Map<Guid, List<int>> data){
    int? voltage;
    int? co2;
    double temperature;
    double humidity;
    int tempFromBytes;
    int humFromBytes;
    if(name.startsWith("Ligna Card") || name == "Jiva"){ // Hantera både Ligna Card och Jiva
        tempFromBytes = (data.entries.first.value[1] << 8) | data.entries.first.value[0];
        humFromBytes = (data.entries.first.value[3] << 8) | data.entries.first.value[1];
    }
    else{
        voltage = (data.entries.first.value[1] << 8) | data.entries.first.value[0];
        tempFromBytes = (data.entries.first.value[3] << 8) | data.entries.first.value[2];
        humFromBytes = (data.entries.first.value[5] << 8) | data.entries.first.value[4];
        co2 = (data.entries.first.value[7] << 8) | data.entries.first.value[6];
        if(co2 == 0) co2 = null;
    }
    if (tempFromBytes & 0x8000 != 0) tempFromBytes = tempFromBytes - 0x10000;
    temperature = tempFromBytes / 10;
    humidity = humFromBytes / 10;
    return SensorReading(humidity: humidity, temperature: temperature, timestamp:DateTime.now(), voltage: voltage, ppm: co2);
  }

  String getCurrentTimeString() {
    DateTime now = DateTime.now();
    String formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    return formattedTime;
  }

  int getTimeDifferenceInSeconds(DateTime previous, DateTime current) {
    return current.difference(previous).inSeconds;
  }

  SensorReading? getSecondLastReading() {
  return _sensorReadingList.length > 1 
    ? _sensorReadingList[_sensorReadingList.length - 2] 
    : null;
}

  String getNiceServiceUuids(List<Guid> serviceUuids) {
    return serviceUuids.join(', ').toUpperCase();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  bool hasSensorReading (AdvertisementData ad){
    return (ad.advName.isNotEmpty && ad.serviceData.isNotEmpty);
  }

  /*        *********** */
  // Export thing consider using own file
  String convertToCSV(List<SensorReading> dataList) {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Temperature,Humidity,Voltage,CO2level');
    for (var item in dataList) {
      buffer.writeln('${item.timestamp},${item.temperature},${item.humidity},${item.voltage},${item.ppm}');
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

  final result = await SharePlus.instance.share(params);
  //if (result.status == ShareResultStatus.success) 

}
  void shareCSVData(String csvData){
    SharePlus.instance.share(
      ShareParams(title: 'Exported data from the Ligna Energy Sensor App', text: csvData)
    );
  }

  void exportAndShare(List<SensorReading> dataList) async {
    final csvData = convertToCSV(dataList);
    //shareCSVData(csvData);
    final file = await saveCSVToFile(csvData, 'ble_data');
    shareFile(file.path);
}



  Widget _buildConnectButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.share_outlined), // https://api.flutter.dev/flutter/material/Icons-class.html
      onPressed: () {
          exportAndShare(_sensorReadingList);
      },
    );
  }
  /*        *********** */

  Widget _buildTitle(BuildContext context) {
    if (widget.result.device.platformName.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.result.device.platformName,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            widget.result.device.remoteId.str,
            style: Theme.of(context).textTheme.bodySmall,
          )
        ],
      );
    } else {
      return Text(widget.result.device.remoteId.str);
    }
  }

  Widget _buildAdvRow(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(
            width: 12.0,
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.apply(color: Colors.black),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureChart() {
    // Skapa en lista med datapunkter från höger till vänster
    final spots = List.generate(_sensorReadingList.length, (index) {
      final data = _sensorReadingList[index];
      // Använd millisekunder sedan epoch som x-värde
      return FlSpot(data.timestamp.millisecondsSinceEpoch.toDouble(), data.temperature);
    });

    // Hitta min och max tid för x-axeln
    final minTime = _sensorReadingList.isEmpty ? 0.0 : _sensorReadingList.first.timestamp.millisecondsSinceEpoch.toDouble();
    final maxTime = _sensorReadingList.isEmpty ? 0.0 : _sensorReadingList.last.timestamp.millisecondsSinceEpoch.toDouble();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                    "${value.toStringAsFixed(1)}°C",
                    style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  // Konvertera millisekunder till DateTime
                  final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Transform.rotate(
                    angle: -0.5,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF031a05),
              dotData: FlDotData(show: true),
              preventCurveOverShooting: true,
            ),
          ],
          minX: minTime - 2000,
          maxX: maxTime + 2000,
          minY: _sensorReadingList.isEmpty ? 0 : _sensorReadingList.map((e) => e.temperature).reduce((a, b) => a < b ? a : b) - 0.2,
          maxY: _sensorReadingList.isEmpty ? 0 : _sensorReadingList.map((e) => e.temperature).reduce((a, b) => a > b ? a : b) + 0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var adv = widget.result.advertisementData;

    // Calculate the time difference if a previous timestamp exists
    int? timeDifferenceInSeconds;
    if (getSecondLastReading() != null) {
      timeDifferenceInSeconds = getTimeDifferenceInSeconds(getSecondLastReading()!.timestamp, _sensorReadingList.last.timestamp);
    }

    return ExpansionTile(
      title: _buildTitle(context),
      leading: Text(widget.result.rssi.toString()),
      trailing: _buildConnectButton(context),
      children: <Widget>[
        if (adv.txPowerLevel != null) _buildAdvRow(context, 'Tx Power Level:', '${adv.txPowerLevel}'),
        if ((adv.appearance ?? 0) > 0) _buildAdvRow(context, 'Appearance:', '0x${adv.appearance!.toRadixString(16)}'),
        if (adv.msd.isNotEmpty) _buildAdvRow(context, 'Manufacturer Data:', getNiceManufacturerData(adv.msd)),
        if (adv.serviceUuids.isNotEmpty) _buildAdvRow(context, 'Service UUIDs:', getNiceServiceUuids(adv.serviceUuids)),
        if (adv.serviceData.isNotEmpty) _buildAdvRow(context, 'Service Data:', getNiceServiceData(adv.serviceData)),
        if (hasSensorReading(adv)) _buildAdvRow(context, 'Decoded Data:', getDecodedServiceData(_sensorReadingList.last)),
        _buildAdvRow(context, 'Updated at:', getCurrentTimeString()),
        if (timeDifferenceInSeconds != null) _buildAdvRow(context, 'Time between latest updates:', '$timeDifferenceInSeconds seconds'),
        //if (_sensorReadingList.isNotEmpty) _buildAdvRow(context, 'Time since last update', '$_secondsSinceLastUpdate seconds'),
        if (_sensorReadingList.isNotEmpty) _buildTemperatureChart(),
      ],
    );
  }
}
