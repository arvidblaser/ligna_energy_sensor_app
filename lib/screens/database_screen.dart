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

  List<FlSpot> getChartSpots() {
    // Assuming each sensorData has 'timestamp' and 'value'
    return sensorData.asMap().entries.map((entry) {
      final idx = entry.key.toDouble();
      final value = (entry.value['value'] as num?)?.toDouble() ?? 0.0;
      return FlSpot(idx, value);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Data Chart')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: getChartSpots(),
                      isCurved: true,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  gridData: FlGridData(show: true),
                ),
              ),
            ),
    );
  }
}