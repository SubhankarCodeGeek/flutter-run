import 'package:equatable/equatable.dart';
import 'package:wifi_scan/wifi_scan.dart'; // For WiFiAccessPoint type

abstract class WifiState extends Equatable {
  const WifiState();

  @override
  List<Object?> get props => [];
}

/// Initial state for Wi-Fi BLoC.
class WifiInitial extends WifiState {
  const WifiInitial();
}

/// State indicating Wi-Fi permissions are being checked or requested.
class WifiCheckingPermissions extends WifiState {
  const WifiCheckingPermissions();
}

/// State indicating Wi-Fi permissions have been denied by the user.
class WifiPermissionsDenied extends WifiState {
  final String message;
  const WifiPermissionsDenied(this.message);

  @override
  List<Object> get props => [message];
}

/// State indicating Wi-Fi scanning is in progress.
class WifiScanning extends WifiState {
  const WifiScanning();
}

/// State indicating Wi-Fi scan was successful and results are available.
class WifiScanSuccess extends WifiState {
  final List<WiFiAccessPoint> accessPoints;

  const WifiScanSuccess(this.accessPoints);

  @override
  List<Object> get props => [accessPoints];
}

/// State indicating Wi-Fi scan failed.
class WifiScanFailure extends WifiState {
  final String error;

  const WifiScanFailure(this.error);

  @override
  List<Object> get props => [error];
}
