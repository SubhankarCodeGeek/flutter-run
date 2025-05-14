
import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

abstract class BluetoothEvent extends Equatable {
  const BluetoothEvent();

  @override
  List<Object?> get props => [];
}

/// Event to trigger scanning for nearby BLE devices.
class StartBleScanEvent extends BluetoothEvent { // Renamed for clarity
  const StartBleScanEvent();
}

/// Event to connect to a specific BLE device.
class ConnectToDeviceEvent extends BluetoothEvent {
  final BluetoothDevice device;

  const ConnectToDeviceEvent(this.device);

  @override
  List<Object> get props => [device];
}

/// Event to send Wi-Fi credentials (SSID and password) to the connected BLE device.
class SendWifiCredentialsEvent extends BluetoothEvent {
  final String ssid;
  final String password;
  final BluetoothDevice device;

  const SendWifiCredentialsEvent({
    required this.ssid,
    required this.password,
    required this.device,
  });

  @override
  List<Object> get props => [ssid, password, device];
}

/// Event to disconnect from the currently connected BLE device.
class DisconnectFromDeviceEvent extends BluetoothEvent {
  final BluetoothDevice device;
  const DisconnectFromDeviceEvent(this.device);

  @override
  List<Object> get props => [device];
}

