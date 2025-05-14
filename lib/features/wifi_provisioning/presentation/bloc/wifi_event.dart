import 'package:equatable/equatable.dart';

abstract class WifiEvent extends Equatable {
  const WifiEvent();

  @override
  List<Object> get props => [];
}

/// Event to trigger scanning for Wi-Fi networks.
class StartWifiScan extends WifiEvent {
  const StartWifiScan();
}

/// Event triggered when Wi-Fi scan results are updated (internal or for refresh).
/// Not typically dispatched from UI directly unless forcing an update with existing data.
class WifiScanResultsUpdated extends WifiEvent {
  // final List<WiFiAccessPoint> accessPoints; // From wifi_scan package
  final List<Map<String, dynamic>> accessPointsJson; // Using Map for simplicity if not directly using WiFiAccessPoint type

  const WifiScanResultsUpdated(this.accessPointsJson);

  @override
  List<Object> get props => [accessPointsJson];
}
