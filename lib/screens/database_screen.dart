import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/sensor_reading.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({Key? key}) : super(key: key);

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> sensorData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSensorData();
  }

  Future<void> fetchSensorData() async {
    final response = await supabase
        .from('SensorData')
        .select()
        .order('created_at', ascending: true);
    setState(() {
      sensorData = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  Map<String, List<Map<String, dynamic>>> groupByMac(List<Map<String, dynamic>> data) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var entry in data) {
      final mac = entry['mac'] as String?;
      if (mac == null) continue;
      grouped.putIfAbsent(mac, () => []).add(entry);
    }
    return grouped;
  }

  Map<String, String> getMacNames(List<Map<String, dynamic>> data) {
    final Map<String, String> names = {};
    for (var entry in data) {
      final mac = entry['mac'] as String?;
      final name = entry['name'] as String? ;
      if (mac != null && name != null) {
        names[mac] = "$name ($mac)";
      }
    }
    return names;
  }

  List<LineChartBarData> getChartLines(String valueKey) {
    final grouped = groupByMac(sensorData);
    final names = getMacNames(sensorData);

    return grouped.entries.map((entry) {
      final mac = entry.key;
      final data = entry.value;
      final spots = data.map((e) {
        final createdAt = e['created_at'];
        double xValue;
        if (createdAt is String) {
          // Parse ISO8601 string to DateTime
          xValue = DateTime.parse(createdAt).millisecondsSinceEpoch.toDouble();
        } else if (createdAt is DateTime) {
          xValue = createdAt.millisecondsSinceEpoch.toDouble();
        } else {
          xValue = 0.0;
        }
        final value = (e[valueKey] as num?)?.toDouble() ?? 0.0;
        return FlSpot(xValue, value);
      }).toList();

      return LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: 2,
        dotData: FlDotData(show: false),
        color: Colors.primaries[mac.hashCode % Colors.primaries.length],
        showingIndicators: [],
      );
    }).toList();
  }

  Widget buildLegend(Map<String, String> names) {
    return Wrap(
      spacing: 16,
      children: names.entries.map((e) {
        final color = Colors.primaries[e.key.hashCode % Colors.primaries.length];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 16, height: 16, color: color),
            const SizedBox(width: 4),
            Text(e.value),
          ],
        );
      }).toList(),
    );
  }

  Widget sensorLineChart(List<LineChartBarData> lines, {String? title}) {
    // Find min and max X values for better axis formatting
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    for (final line in lines) {
      for (final spot in line.spots) {
        if (spot.x < minX) minX = spot.x;
        if (spot.x > maxX) maxX = spot.x;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              lineBarsData: lines,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 64,
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    // todo make this depend on a choice on min and max time also
                    //interval: 24 * 60 * 60 * 1000, // Show label every 24 hour
                    getTitlesWidget: (value, meta) {
                      final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      final dateStr = "${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
                      final timeStr = "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}";
                      return Transform.rotate(
                        angle: -0.5,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(dateStr, style: const TextStyle(fontSize: 10)),
                              Text(timeStr, style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: true),
              gridData: FlGridData(show: true),
              minX: minX,
              maxX: maxX,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = getMacNames(sensorData);

    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Data Chart')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sensorLineChart(getChartLines('temperature'), title: 'Temperature'),
                  sensorLineChart(getChartLines('humidity'), title: 'Humidity'),
                  sensorLineChart(getChartLines('co2'), title: 'Carbon Dioxide'),
                  sensorLineChart(getChartLines('battery'), title: 'Voltage Level'),

                  // Add more charts here as needed
                  Text('Legend:', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12), // Add space above the legend
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0), // Add space below the legend
                    child: buildLegend(names),
                  ),
                ],
              ),
            ),
    );
  }
}