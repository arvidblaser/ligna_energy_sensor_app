import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/sensor_reading.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> sensorData = [];
  bool isLoading = true;
  List<String> allMacs = [];
  Map<String, String> macNames = {};
  Set<String> selectedMacs = {};
  bool isFilterDropdownOpen = false;
  int fetchLimit = 100; // <-- Add this line

  @override
  void initState() {
    super.initState();
    fetchAllMacs();
  }


/*
SELECT DISTINCT ON (mac) mac, name
FROM public."SensorData"
ORDER BY mac, created_at DESC;
*/

  Future<void> fetchAllMacs() async {
    final response = await supabase.rpc('get_unique_sensordata');

    final rows = response as List<dynamic>;
    final macSet = <String>{};
    final names = <String, String>{};
    for (final row in rows) {
      final mac = row['mac'] as String?;
      final name = row['name'] as String?;
      if (mac != null) {
        macSet.add(mac);
        names[mac] = name != null ? "$name ($mac)" : mac;
      }
    }
    setState(() {
      allMacs = macSet.toList();
      macNames = names;
      selectedMacs = Set<String>.from(macSet); // All selected by default
      fetchSensorData();
    });
  }

  Future<void> fetchSensorData() async {
    if (selectedMacs.isEmpty) {
      setState(() {
        sensorData = [];
        isLoading = false;
      });
      return;
    }
    setState(() => isLoading = true);
    final response = await supabase
        .from('SensorData')
        .select()
        .inFilter('mac', selectedMacs.toList())
        .order('created_at', ascending: false)
        .limit(fetchLimit); // <-- Use fetchLimit here
    setState(() {
      sensorData = List<Map<String, dynamic>>.from(response.reversed);
      isLoading = false;
    });
  }

  Map<String, List<Map<String, dynamic>>> groupByMac(
    List<Map<String, dynamic>> data,
  ) {
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
      final name = entry['name'] as String?;
      if (mac != null && name != null) {
        names[mac] = "$name ($mac)";
      }
    }
    return names;
  }

  List<LineChartBarData> getChartLines(String valueKey) {
    final grouped = groupByMac(sensorData);

    return grouped.entries.map((entry) {
      final mac = entry.key;
      final data = entry.value;
      final spots =
          data.map((e) {
            final createdAt = e['created_at'];
            double xValue;
            if (createdAt is String) {
              // Parse ISO8601 string to DateTime
              xValue =
                  DateTime.parse(createdAt).millisecondsSinceEpoch.toDouble();
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
      children:
          names.entries.map((e) {
            final color =
                Colors.primaries[e.key.hashCode % Colors.primaries.length];
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
    // Find min and max X and Y values for better axis formatting
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final line in lines) {
      for (final spot in line.spots) {
        if (spot.x < minX) minX = spot.x;
        if (spot.x > maxX) maxX = spot.x;
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }

    // Add 10% headroom to the top of the Y axis
    final yRange = maxY - minY;
    final yHeadroom = yRange > 0 ? yRange * 0.1 : 1.0;
    final displayMaxY = maxY + yHeadroom;

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
                  sideTitles: SideTitles(showTitles: true, reservedSize: 64),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) {
                      final dateTime = DateTime.fromMillisecondsSinceEpoch(
                        value.toInt(),
                      );
                      final dateStr =
                          "${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
                      final timeStr =
                          "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}";
                      return Transform.rotate(
                        angle: -0.5,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dateStr,
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                timeStr,
                                style: const TextStyle(fontSize: 10),
                              ),
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
              minY: minY,
              maxY: displayMaxY,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget buildFilterDropdown() {
    // Sort MACs by their device name (alphabetically, fallback to MAC if name is null)
    final sortedMacs = List<String>.from(allMacs)..sort((a, b) {
      final nameA = (macNames[a] ?? a).toLowerCase();
      final nameB = (macNames[b] ?? b).toLowerCase();
      return nameA.compareTo(nameB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Filter Settings'),
          trailing: Icon(
            isFilterDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          ),
          onTap: () {
            setState(() {
              isFilterDropdownOpen = !isFilterDropdownOpen;
            });
          },
        ),
        if (isFilterDropdownOpen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selectedMacs = Set<String>.from(allMacs);
                        });
                        fetchSensorData();
                      },
                      child: const Text('Select All'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selectedMacs.clear();
                        });
                        fetchSensorData();
                      },
                      child: const Text('Unselect All'),
                    ),
                    const SizedBox(width: 16),
                    // Dropdown for fetchLimit
                    const Text('Values:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: fetchLimit,
                      items: const [
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                        DropdownMenuItem(value: 250, child: Text('250')),
                        DropdownMenuItem(value: 500, child: Text('500')),
                        DropdownMenuItem(value: 1000, child: Text('1000')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            fetchLimit = val;
                          });
                          fetchSensorData();
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(
                  height: 200,
                  child: ListView(
                    children:
                        sortedMacs.map((mac) {
                          return CheckboxListTile(
                            value: selectedMacs.contains(mac),
                            title: Text(macNames[mac] ?? mac),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  selectedMacs.add(mac);
                                } else {
                                  selectedMacs.remove(mac);
                                }
                              });
                              fetchSensorData();
                            },
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Data Chart')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildFilterDropdown(),
                    sensorLineChart(
                      getChartLines('temperature'),
                      title: 'Temperature',
                    ),
                    sensorLineChart(
                      getChartLines('humidity'),
                      title: 'Humidity',
                    ),
                    sensorLineChart(
                      getChartLines('co2'),
                      title: 'Carbon Dioxide',
                    ),
                    sensorLineChart(
                      getChartLines('battery'),
                      title: 'Voltage Level',
                    ),
                    Text(
                      'Legend:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: buildLegend(getMacNames(sensorData)),
                    ),
                  ],
                ),
              ),
    );
  }
}
