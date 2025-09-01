import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../utils/snackbar.dart';
import '../widgets/scan_result_tile.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        if (mounted) {
          setState(() => _scanResults = results);
        }
      },
      onError: (e) {
        Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
      },
    );

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() => _isScanning = state);
      }
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future onScanPressed() async {
    try {
      // `withServices` is required on iOS for privacy purposes, ignored on android.
      var withServices = [Guid("180f")]; // Battery Level Service
      _systemDevices = await FlutterBluePlus.systemDevices(withServices);
    } catch (e, backtrace) {
      Snackbar.show(
        ABC.b,
        prettyException("System Devices Error:", e),
        success: false,
      );
      print(e);
      print("backtrace: $backtrace");
    }
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(days: 1),
        webOptionalServices: [
          Guid("180f"), // battery
          Guid("180a"), // device info
          Guid("1800"), // generic access
          Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e"), // Nordic UART
        ],
        withKeywords: [
          "Ben",
          "Jiva",
          "Ligna Card",
          "Gwen",
        ], // *or* any of the specified names
      );
    } catch (e, backtrace) {
      Snackbar.show(
        ABC.b,
        prettyException("Start Scan Error:", e),
        success: false,
      );
      print(e);
      print("backtrace: $backtrace");
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future onStopPressed() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e, backtrace) {
      Snackbar.show(
        ABC.b,
        prettyException("Stop Scan Error:", e),
        success: false,
      );
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Future onRefresh() {
    if (_isScanning == false) {
      FlutterBluePlus.startScan(timeout: const Duration(days: 1));
    }
    if (mounted) {
      setState(() {});
    }
    return Future.delayed(Duration(milliseconds: 500));
  }

  Widget buildScanButton() {
    return Row(
      children: [
        if (FlutterBluePlus.isScanningNow)
          buildSpinner()
        else
          ElevatedButton(
            onPressed: onScanPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text("SCAN"),
          ),
      ],
    );

    // Widget buildScanButton(BuildContext context) {
    //   if (FlutterBluePlus.isScanningNow) {
    //     return FloatingActionButton(
    //       child: const Icon(Icons.stop),
    //       onPressed: onStopPressed,
    //       backgroundColor: Color(0xFF031a05),
    //     );
    //   } else {
    //     return FloatingActionButton(child: const Text("SCAN"), onPressed: onScanPressed);
    //   }
  }

  Widget buildSpinner() {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.white24,
          color: Colors.white30,
        ),
      ),
    );
  }

  Iterable<Widget> _buildScanResultTiles() {
    return _scanResults.map(
      (r) => ScanResultTile(result: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyB,
      child: Scaffold(
        appBar: AppBar(
          title: Image.asset(
            'assets/images/logo_white.png',
            height: 120, // Justera höjden efter behov
            fit: BoxFit.contain,
          ),
          actions: [buildScanButton(), const SizedBox(width: 15)],
          backgroundColor: Color(0xFF031a05),
        ),
        body: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(children: <Widget>[..._buildScanResultTiles()]),
        ),
        // floatingActionButton: buildScanButton(context),
      ),
    );
  }
}
