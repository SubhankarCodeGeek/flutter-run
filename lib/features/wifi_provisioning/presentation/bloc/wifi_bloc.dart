import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';

import 'wifi_event.dart';
import 'wifi_state.dart';

class WifiBloc extends Bloc<WifiEvent, WifiState> {
  StreamSubscription<List<WiFiAccessPoint>>? _wifiScanSubscription;
  bool _isScanInProgress = false;


  WifiBloc() : super(const WifiInitial()) {
    on<StartWifiScan>(_onStartWifiScan);
  }

  Future<void> _onStartWifiScan(
      StartWifiScan event,
      Emitter<WifiState> emit,
      ) async {
    if (_isScanInProgress) return; // Prevent multiple concurrent scans

    _isScanInProgress = true;
    emit(const WifiCheckingPermissions());

    // 1. Check and Request Location Permissions (required for Wi-Fi scan on Android)
    var locationStatus = await Permission.locationWhenInUse.request();
    if (locationStatus.isDenied || locationStatus.isPermanentlyDenied) {
      emit(const WifiPermissionsDenied(
          "Location permission is required to scan for Wi-Fi networks. Please enable it in settings."));
      _isScanInProgress = false;
      return;
    }
    if (!locationStatus.isGranted) { // Handle other cases like restricted
      emit(const WifiPermissionsDenied("Location permission was not granted. Cannot scan Wi-Fi."));
      _isScanInProgress = false;
      return;
    }


    // 2. Check if Wi-Fi service is available (e.g., Wi-Fi is turned on)
    final canStartScanCode = await WiFiScan.instance.canStartScan();
    if (canStartScanCode != CanStartScan.yes) {
      String errorMessage;
      switch (canStartScanCode) {
        case CanStartScan.noLocationPermissionRequired:
          errorMessage = "Location permission is required by the OS to get Wi-Fi scan results.";
          break;
        case CanStartScan.noLocationServiceTurnedOn:
          errorMessage = "Location services are turned off. Please enable them.";
          break;
        case CanStartScan.noWifiAdapter:
          errorMessage = "No Wi-Fi adapter found on this device.";
          break;
        case CanStartScan.error RetrievingScanResults:
          errorMessage = "Error retrieving scan results capability.";
          break;
        default:
          errorMessage = "Cannot start Wi-Fi scan. Ensure Wi-Fi and location services are on.";
      }
      emit(WifiScanFailure(errorMessage));
      _isScanInProgress = false;
      return;
    }

    emit(const WifiScanning());

    try {
      // 3. Start Scan
      final result = await WiFiScan.instance.startScan();
      if (!result) {
        emit(const WifiScanFailure("Failed to initiate Wi-Fi scan."));
        _isScanInProgress = false;
        return;
      }

      // 4. Listen to Results
      await _wifiScanSubscription?.cancel(); // Cancel previous subscription if any
      _wifiScanSubscription = WiFiScan.instance.onScannedResultsAvailable.listen(
              (List<WiFiAccessPoint> results) {
            // Sort by RSSI (strongest first), then by SSID for stability
            results.sort((a, b) {
              final rssiComp = b.level.compareTo(a.level);
              if (rssiComp != 0) return rssiComp;
              return a.ssid.compareTo(b.ssid);
            });
            if (state is WifiScanning || state is WifiScanSuccess) { // Only emit if still relevant
              emit(WifiScanSuccess(results));
            }
          },
          onError: (error) {
            // print("Error listening to Wi-Fi scan results: $error");
            if (state is WifiScanning || state is WifiScanSuccess) {
              emit(WifiScanFailure("Error receiving Wi-Fi scan results: ${error.toString()}"));
            }
            _isScanInProgress = false; // Reset flag on error
          },
          onDone: () {
            _isScanInProgress = false; // Reset flag when stream is done
          }
      );

      // Fetch initial results as onScannedResultsAvailable might not fire immediately
      final initialResults = await WiFiScan.instance.getScannedResults();
      initialResults.sort((a, b) {
        final rssiComp = b.level.compareTo(a.level);
        if (rssiComp != 0) return rssiComp;
        return a.ssid.compareTo(b.ssid);
      });
      emit(WifiScanSuccess(initialResults)); // Emit initial results
      // _isScanInProgress will be set to false when the stream is done or an error occurs.

    } catch (e) {
      // print("Error during Wi-Fi scan process: $e");
      emit(WifiScanFailure("Wi-Fi scan process failed: ${e.toString()}"));
      _isScanInProgress = false;
    }
    // Note: _isScanInProgress should be managed carefully, especially if scans are long-running
    // or if the stream is expected to stay open. For a "one-shot" scan that auto-stops,
    // you might reset it after a timeout or when the stream is explicitly closed.
    // The wifi_scan plugin might handle the "scan in progress" state internally too.
    // For now, we assume a scan is requested, and results will flow or an error will occur.
  }

  @override
  Future<void> close() {
    _wifiScanSubscription?.cancel();
    WiFiScan.instance.stopScan().catchError((_){}); // Attempt to stop scan on BLoC close
    return super.close();
  }
}
