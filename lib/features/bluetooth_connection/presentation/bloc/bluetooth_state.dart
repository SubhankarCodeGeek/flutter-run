import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

abstract class BluetoothState extends Equatable {
  const BluetoothState();

  @override
  List<Object?> get props => [];
}

/// Initial state of the BluetoothBloc.
class BluetoothInitial extends BluetoothState { // Renamed for clarity
  const BluetoothInitial();
}

/// State indicating that BLE scanning is in progress.
class BluetoothScanning extends BluetoothState { // Renamed for clarity
  const BluetoothScanning();
}

/// State indicating that BLE scanning has finished and devices have been found.
class BluetoothDevicesFound extends BluetoothState { // Renamed for clarity
  final List<BluetoothDevice> devices;

  const BluetoothDevicesFound(this.devices);

  @override
  List<Object> get props => [devices];
}

/// State indicating that a connection attempt to a BLE device is in progress.
class BluetoothConnecting extends BluetoothState { // Renamed for clarity
  final BluetoothDevice device;

  const BluetoothConnecting(this.device);

  @override
  List<Object> get props => [device];
}

/// State indicating that the app is connected to a BLE device,
/// services have been discovered, and the provisioning characteristic is ready.
class BluetoothReadyForProvisioning extends BluetoothState { // Renamed for clarity
  final BluetoothDevice connectedDevice;

  const BluetoothReadyForProvisioning(this.connectedDevice);

  @override
  List<Object> get props => [connectedDevice];
}

/// State indicating that Wi-Fi credentials are being sent to the BLE device.
class BluetoothSendingWifiCredentials extends BluetoothState { // Renamed for clarity
  const BluetoothSendingWifiCredentials();
}

/// State indicating that the app is waiting for a provisioning confirmation
/// (success/failure) from the BLE device after sending credentials.
class BluetoothAwaitingProvisioningConfirmation extends BluetoothState { // Renamed for clarity
  const BluetoothAwaitingProvisioningConfirmation();
}

/// State indicating that the Wi-Fi provisioning process on the BLE device was successful.
class BluetoothProvisioningSuccess extends BluetoothState { // Renamed for clarity
  final BluetoothDevice device;
  final String message;

  const BluetoothProvisioningSuccess(this.device, {this.message = "Provisioning successful!"});

  @override
  List<Object> get props => [device, message];
}

/// State indicating that the Wi-Fi provisioning process on the BLE device failed.
class BluetoothProvisioningFailure extends BluetoothState { // Renamed for clarity
  final BluetoothDevice? device;
  final String error;

  const BluetoothProvisioningFailure(this.error, {this.device});

  @override
  List<Object?> get props => [error, device];
}

/// Generic state emitted when any general BLE operation fails.
class BluetoothError extends BluetoothState { // Renamed for clarity
  final String message;

  const BluetoothError(this.message);

  @override
  List<Object> get props => [message];
}
