import 'dart:async';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/sensor_reading.dart';
import '../utils/database_service.dart';
import '../utils/export_service.dart';

final log = Logger('ScanResultLogger');
final databaseService = DatabaseService(Supabase.instance.client);
final exportService = ExportService();

class ScanResultTile extends StatefulWidget {
  const ScanResultTile({super.key, required this.result, this.onTap});

  final ScanResult result;
  final VoidCallback? onTap;

  @override
  State<ScanResultTile> createState() => _ScanResultTileState();
}

class _ScanResultTileState extends State<ScanResultTile> {
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;

  late StreamSubscription<BluetoothConnectionState>
  _connectionStateSubscription;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;

  final List<SensorReading> _sensorReadingList = [];
  static const int maxDataPoints = 2160; // var 5:e sekund -> 3h, 3*3600/5

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.result.device.connectionState.listen((
      state,
    ) {
      _connectionState = state;
      if (mounted) {
        setState(() {}); // Uppdatera bara UI för anslutningsstatus
      }
    });

    // Prenumerera på scanresultat för att få nya avläsningar direkt
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        ScanResult? deviceResult;
        for (var result in results) {
          if (result.device.remoteId == widget.result.device.remoteId) {
            deviceResult = result;
            break;
          }
        }

        if (deviceResult != null &&
            hasSensorReading(
              deviceResult.advertisementData,
              deviceResult.device.platformName,
            )) {
          String correctName = getCorrectName(
            deviceResult.advertisementData.advName,
            deviceResult.device.platformName,
          );
          SensorReading sr = decodeData(
            correctName,
            deviceResult.advertisementData.serviceData,
          );
          addToSensorReadingList(sr);
          databaseService.addToDatabase(
            sr,
            correctName,
            widget.result.device.remoteId.str,
          ); // todo check if this needs to be await
          setState(() {}); // Uppdatera UI för att visa nya data
        }
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _scanResultsSubscription.cancel();
    super.dispose();
  }

  String getNiceHexArray(List<int> bytes) {
    return '[${bytes.map((i) => i.toRadixString(16).padLeft(2, '0')).join(', ')}]';
  }

  String getNiceManufacturerData(List<List<int>> data) {
    return data.map((val) => getNiceHexArray(val)).join(', ').toUpperCase();
  }

  String getNiceServiceData(Map<Guid, List<int>> data) {
    return data.entries
        .map((v) => '${v.key}: ${getNiceHexArray(v.value)}')
        .join(', ')
        .toUpperCase();
  }

  String getDecodedServiceData(SensorReading sr) {
    List<String> parts = [];
    if (sr.voltage != null) parts.add('Voltage: ${sr.voltage}mV');
    parts.add('Temp: ${sr.temperature}°C');
    parts.add('Hum: ${sr.humidity}%');
    if (sr.ppm != null) parts.add('CO2: ${sr.ppm} PPM');
    return parts.join(', ');
  }

  void addToSensorReadingList(SensorReading sr) {
    _sensorReadingList.add(sr);
    if (_sensorReadingList.length > maxDataPoints) {
      _sensorReadingList.removeAt(0);
    }
  }

  SensorReading decodeData(String name, Map<Guid, List<int>> data) {
    int? voltage;
    int? co2;
    double temperature;
    double humidity;
    int tempFromBytes;
    int humFromBytes;
    if (name.startsWith("Ligna Card") || name.startsWith("Jiva")) {
      tempFromBytes =
          (data.entries.first.value[1] << 8) | data.entries.first.value[0];
      humFromBytes =
          (data.entries.first.value[3] << 8) | data.entries.first.value[2];
    } else if (name.startsWith("Gwen")) {
      tempFromBytes =
          (data.entries.first.value[1] << 8) | data.entries.first.value[0];
      humFromBytes =
          (data.entries.first.value[3] << 8) | data.entries.first.value[2];
      voltage =
          (data.entries.first.value[5] << 8) | data.entries.first.value[4];
    } else {
      voltage =
          (data.entries.first.value[1] << 8) | data.entries.first.value[0];
      tempFromBytes =
          (data.entries.first.value[3] << 8) | data.entries.first.value[2];
      humFromBytes =
          (data.entries.first.value[5] << 8) | data.entries.first.value[4];
      co2 = (data.entries.first.value[7] << 8) | data.entries.first.value[6];
      if (co2 == 0) co2 = null;
    }
    if (tempFromBytes & 0x8000 != 0) tempFromBytes = tempFromBytes - 0x10000;
    temperature = tempFromBytes / 10;
    humidity = humFromBytes / 10;
    return SensorReading(
      humidity: humidity,
      temperature: temperature,
      timestamp: DateTime.now(),
      voltage: voltage,
      ppm: co2,
    );
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

  bool hasSensorReading(AdvertisementData ad, String platformName) {
    if ((ad.advName.isNotEmpty || platformName.isNotEmpty) &&
        ad.serviceData.isNotEmpty) {
      if (haCorrectName(ad.advName, platformName)) {
        return true;
      }
    }
    return false;
  }

  // Assumes function is ony called if haCorrectName has returned true
  String getCorrectName(String name, String platformName) {
    if (nameFilter(name)) {
      return name;
    }
    return platformName;
  }

  bool nameFilter(String name) {
    if (name.startsWith("Ligna Card") ||
        name.startsWith("Jiva") ||
        name.startsWith("Gwen") ||
        name.startsWith("Ben")) {
      return true;
    }
    return false;
  }

  bool haCorrectName(String name, String platformName) {
    if (nameFilter(name)) {
      return true;
    }
    if (nameFilter(platformName)) {
      return true;
    }
    return false;
  }

  Widget _buildShareButton(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.share_outlined,
      ), // https://api.flutter.dev/flutter/material/Icons-class.html
      onPressed: () {
        exportService.exportAndShare(_sensorReadingList);
      },
    );
  }

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
          ),
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
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.apply(color: Colors.black),
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
      return FlSpot(
        data.timestamp.millisecondsSinceEpoch.toDouble(),
        data.temperature,
      );
    });

    // Hitta min och max tid för x-axeln
    final minTime =
        _sensorReadingList.isEmpty
            ? 0.0
            : _sensorReadingList.first.timestamp.millisecondsSinceEpoch
                .toDouble();
    final maxTime =
        _sensorReadingList.isEmpty
            ? 0.0
            : _sensorReadingList.last.timestamp.millisecondsSinceEpoch
                .toDouble();

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
                  final dateTime = DateTime.fromMillisecondsSinceEpoch(
                    value.toInt(),
                  );
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
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
          minY:
              _sensorReadingList.isEmpty
                  ? 0
                  : _sensorReadingList
                          .map((e) => e.temperature)
                          .reduce((a, b) => a < b ? a : b) -
                      0.2,
          maxY:
              _sensorReadingList.isEmpty
                  ? 0
                  : _sensorReadingList
                          .map((e) => e.temperature)
                          .reduce((a, b) => a > b ? a : b) +
                      0.2,
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
      timeDifferenceInSeconds = getTimeDifferenceInSeconds(
        getSecondLastReading()!.timestamp,
        _sensorReadingList.last.timestamp,
      );
    }
    if (_sensorReadingList.isEmpty ||
        !hasSensorReading(
          widget.result.advertisementData,
          widget.result.device.platformName,
        )) {
      log.fine("build a empty result tile");
      return const SizedBox.shrink(); // Or show a placeholder/error
    }
    log.fine("build a scan result tile");

    return ExpansionTile(
      title: _buildTitle(context),
      leading: Text(widget.result.rssi.toString()),
      trailing: _buildShareButton(context),
      children: <Widget>[
        if (adv.txPowerLevel != null)
          _buildAdvRow(context, 'Tx Power Level:', '${adv.txPowerLevel}'),
        if ((adv.appearance ?? 0) > 0)
          _buildAdvRow(
            context,
            'Appearance:',
            '0x${adv.appearance!.toRadixString(16)}',
          ),
        if (adv.msd.isNotEmpty)
          _buildAdvRow(
            context,
            'Manufacturer Data:',
            getNiceManufacturerData(adv.msd),
          ),
        if (adv.serviceUuids.isNotEmpty)
          _buildAdvRow(
            context,
            'Service UUIDs:',
            getNiceServiceUuids(adv.serviceUuids),
          ),
        if (adv.serviceData.isNotEmpty)
          _buildAdvRow(
            context,
            'Service Data:',
            getNiceServiceData(adv.serviceData),
          ),
        if (hasSensorReading(adv, widget.result.device.platformName))
          _buildAdvRow(
            context,
            'Decoded Data:',
            getDecodedServiceData(_sensorReadingList.last),
          ),
        _buildAdvRow(context, 'Updated at:', getCurrentTimeString()),
        if (timeDifferenceInSeconds != null)
          _buildAdvRow(
            context,
            'Time between latest updates:',
            '$timeDifferenceInSeconds seconds',
          ),
        if (_sensorReadingList.isNotEmpty) _buildTemperatureChart(),
      ],
    );
  }
}
