import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local imports for events and states, assuming they are in the same feature folder or accessible path
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';

class BluetoothBloc extends Bloc<BluetoothEvent, MyBleState> {
  BluetoothCharacteristic? _provisioningCharacteristic;
  Stream<List<int>>? _charValueStream;
  StreamSubscription<List<int>>? _charValueSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  // --- IMPORTANT: Replace with your actual characteristic UUIDs ---
  // These UUIDs MUST match the ones defined in your IoT device's firmware
  // for the Wi-Fi provisioning service and characteristic.
  // Example format: Guid("0000XXXX-0000-1000-8000-00805f9b34fb")
  // final Guid _provisioningServiceUuid = Guid("YOUR_SERVICE_UUID_HERE");
  // final Guid _provisioningCharacteristicUuid = Guid("YOUR_CHARACTERISTIC_UUID_HERE");
  // Example BLE “Provisioning” Service (using Nordic UART Service UUID)
  final Guid _provisioningServiceUuid = Guid(
      "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"); // NUS service :contentReference[oaicite:0]{index=0}

// Example BLE Characteristic (NUS RX characteristic for writes from the central)
  final Guid _provisioningCharacteristicUuid = Guid(
      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"); // NUS RX char :contentReference[oaicite:1]{index=1}

  BluetoothBloc() : super(const BluetoothInitial()) {
    // Register event handlers
    on<StartBleScanEvent>(_onStartBleScan);
    on<ConnectToDeviceEvent>(_onConnectToDevice);
    on<SendWifiCredentialsEvent>(_onSendWifiCredentials);
    on<DisconnectFromDeviceEvent>(_onDisconnect);
  }

  /// Handles the [StartBleScanEvent] to scan for nearby BLE devices.
  Future<void> _onStartBleScan(
    StartBleScanEvent event,
    Emitter<MyBleState> emit,
  ) async {
    emit(const BluetoothScanning());
    try {
      // Check if Bluetooth is supported on the device
      if (!(await FlutterBluePlus.isSupported)) {
        emit(const BluetoothError("Bluetooth not supported on this device."));
        return;
      }
      // Check if Bluetooth adapter is enabled
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        emit(const BluetoothError("Bluetooth is off. Please turn it on."));
        return;
      }

      final List<BluetoothDevice> foundDevices = [];
      final Set<DeviceIdentifier> discoveredDeviceIds =
          {}; // To avoid duplicate device entries

      final scanCompleter = Completer<void>();
      StreamSubscription? scanResultsSubscription;

      // Listen to scan results
      scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          // Add device if it has a platform name and hasn't been discovered yet
          if (r.device.platformName.isNotEmpty &&
              !discoveredDeviceIds.contains(r.device.remoteId)) {
            // print('Found BLE device: ${r.device.platformName} (${r.device.remoteId})');
            foundDevices.add(r.device);
            discoveredDeviceIds.add(r.device.remoteId);
          }
        }
      });

      // Start scanning for a predefined duration
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      // Ensure the scan completer finishes after the timeout
      Future.delayed(const Duration(seconds: 5), () {
        if (!scanCompleter.isCompleted) {
          scanCompleter.complete();
        }
      });

      await scanCompleter.future; // Wait for scan to complete
      await FlutterBluePlus.stopScan(); // Explicitly stop scanning
      await scanResultsSubscription
          ?.cancel(); // Cancel the subscription to scan results

      if (foundDevices.isEmpty) {
        // print("No BLE devices found");
        emit(const BluetoothDevicesFound(
            [])); // Emit empty list if no devices are found
      } else {
        emit(BluetoothDevicesFound(
            List.from(foundDevices))); // Emit the list of found devices
      }
    } catch (e) {
      // print('BLE Scan failed: $e');
      emit(BluetoothError('BLE Scan failed: ${e.toString()}'));
    }
  }

  /// Handles the [ConnectToDeviceEvent] to connect to a selected BLE device
  /// and discover its services and characteristics for provisioning.
  Future<void> _onConnectToDevice(
    ConnectToDeviceEvent event,
    Emitter<MyBleState> emit,
  ) async {
    emit(BluetoothConnecting(event.device)); // Indicate connection attempt
    try {
      final device = event.device;

      // Cancel any previous connection state subscription
      await _connectionStateSubscription?.cancel();
      // Listen to the device's connection state
      _connectionStateSubscription = device.connectionState
          .listen((BluetoothConnectionState connectionState) {
        // print('Device ${device.remoteId} connection state: $connectionState');
        if (connectionState == BluetoothConnectionState.disconnected) {
          // Handle unexpected disconnections
          // Only emit error if not intentionally disconnecting or after successful provisioning
          bool isRelevantState = this.state is BluetoothReadyForProvisioning ||
              this.state is BluetoothConnecting ||
              this.state is BluetoothAwaitingProvisioningConfirmation ||
              this.state is BluetoothSendingWifiCredentials;

          if (isRelevantState &&
              !(this.state is BluetoothProvisioningSuccess)) {
            // print('Device ${device.remoteId} disconnected unexpectedly.');
            add(DisconnectFromDeviceEvent(device)); // Trigger cleanup logic
            emit(BluetoothError('Device ${device.remoteId} disconnected'));
          }
        }
      });

      // Attempt to connect to the device
      await device.connect(
          timeout: const Duration(seconds: 15), autoConnect: false);
      // Discover services offered by the device
      List<BluetoothService> services = await device.discoverServices();

      _provisioningCharacteristic = null; // Reset before searching

      // Iterate through services and characteristics to find the provisioning characteristic
      for (final service in services) {
        // print('Service found: ${service.uuid.str}');
        // IMPORTANT: Filter by your specific provisioning service UUID
        if (service.uuid == _provisioningServiceUuid) {
          for (final characteristic in service.characteristics) {
            // print('Characteristic found: ${characteristic.uuid.str} with props ${characteristic.properties}');
            // IMPORTANT: Filter by your specific provisioning characteristic UUID
            if (characteristic.uuid == _provisioningCharacteristicUuid) {
              final canWrite = characteristic.properties.write ||
                  characteristic.properties.writeWithoutResponse;
              final canNotify = characteristic.properties.notify ||
                  characteristic.properties.indicate;

              // Check if the characteristic supports required properties (write and notify/indicate)
              if (canWrite && canNotify) {
                _provisioningCharacteristic = characteristic;
                _charValueStream = characteristic
                    .onValueReceived; // Stream for characteristic value changes

                // Cancel previous characteristic value subscription
                await _charValueSubscription?.cancel();
                // Subscribe to value changes (notifications/indications)
                _charValueSubscription = _charValueStream?.listen((value) {
                  // This is a general listener. Specific responses are handled after write operations.
                  // print("BLE Char Value Received (General Listener): ${utf8.decode(value, allowMalformed: true)}");
                });

                // Enable notifications/indications on the characteristic
                await characteristic.setNotifyValue(true);
                // print("Provisioning characteristic (${characteristic.uuid.str}) found and notifications enabled.");
                break; // Characteristic found
              }
            }
          }
        }
        if (_provisioningCharacteristic != null)
          break; // Service and characteristic found
      }

      // If the provisioning characteristic is not found, report an error
      if (_provisioningCharacteristic == null) {
        await device.disconnect(); // Disconnect if setup failed
        throw Exception(
            'Provisioning characteristic not found. Ensure UUIDs match and it supports Write & Notify/Indicate.');
      }

      emit(BluetoothReadyForProvisioning(
          device)); // Indicate device is ready for provisioning
    } catch (e) {
      // print('Connection or service discovery failed: $e');
      await event.device
          .disconnect()
          .catchError((_) {}); // Attempt to clean up by disconnecting
      emit(BluetoothError(
          'Connection/Service Discovery failed: ${e.toString()}'));
    }
  }

  /// Handles the [SendWifiCredentialsEvent] to send Wi-Fi SSID and password
  /// to the connected device and await provisioning status.
  Future<void> _onSendWifiCredentials(
    SendWifiCredentialsEvent event,
    Emitter<MyBleState> emit,
  ) async {
    // Ensure characteristic is available
    if (_provisioningCharacteristic == null || _charValueStream == null) {
      emit(const BluetoothProvisioningFailure(
          'Characteristic not available. Please reconnect.'));
      return;
    }
    emit(
        const BluetoothSendingWifiCredentials()); // Indicate credentials are being sent

    try {
      // Prepare payload (SSID and password)
      final payload =
          jsonEncode({'ssid': event.ssid, 'password': event.password});
      final base64Payload =
          base64Encode(utf8.encode(payload)); // Example encoding
      final List<int> bytesToSend = utf8.encode(base64Payload);

      // Ensure notifications are enabled on the characteristic
      if (!_provisioningCharacteristic!.isNotifying) {
        await _provisioningCharacteristic!.setNotifyValue(true);
      }

      // Write credentials to the characteristic
      bool canWriteWithResponse = _provisioningCharacteristic!
          .properties.write; // Check if acknowledged write is supported
      await _provisioningCharacteristic!
          .write(bytesToSend, withoutResponse: !canWriteWithResponse);
      // print('Wi-Fi credentials sent to ${event.device.remoteId}. SSID: ${event.ssid}');

      emit(
          const BluetoothAwaitingProvisioningConfirmation()); // Indicate waiting for device response

      // Wait for the first notification/indication from the device after writing
      final response = await _charValueStream!.first.timeout(
        const Duration(seconds: 30),
        // Timeout for device to process and respond
        onTimeout: () {
          // print("Timeout waiting for provisioning confirmation from device.");
          throw TimeoutException(
              'Device did not respond with provisioning status in time.');
        },
      );

      if (response.isEmpty) {
        throw Exception('Empty response from device during provisioning.');
      }

      final String status =
          utf8.decode(response, allowMalformed: true); // Decode response
      // print('Received provisioning status from device: $status');

      // Check device status response
      if (status.toUpperCase().startsWith('SUCCESS') ||
          status.toUpperCase() == 'OK') {
        // Provisioning successful
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('provisioned_${event.device.remoteId.str}',
            true); // Mark device as provisioned

        // Log success to Firestore (optional)
        await FirebaseFirestore.instance.collection('provisioningStatus').add({
          'deviceId': event.device.remoteId.str,
          'deviceName': event.device.platformName,
          'ssid': event.ssid,
          'status': 'success',
          'detail': status,
          'timestamp': Timestamp.now(),
        });
        emit(BluetoothProvisioningSuccess(event.device,
            message: "Successfully provisioned: $status"));
      } else {
        // Provisioning failed on the device side
        throw Exception('Provisioning failed on device: $status');
      }
    } catch (e) {
      // print('Error sending Wi-Fi credentials or processing response: $e');
      // Log failure to Firestore (optional)
      await FirebaseFirestore.instance.collection('provisioningStatus').add({
        'deviceId': event.device.remoteId.str,
        'deviceName': event.device.platformName,
        'ssid': event.ssid,
        'status': 'failure',
        'error': e.toString(),
        'timestamp': Timestamp.now(),
      }).catchError((_) {}); // Catch Firestore errors too, if any
      emit(BluetoothProvisioningFailure(e.toString(), device: event.device));
    }
  }

  /// Handles the [DisconnectFromDeviceEvent] to disconnect from the BLE device
  /// and clean up resources.
  Future<void> _onDisconnect(
    DisconnectFromDeviceEvent event,
    Emitter<MyBleState> emit,
  ) async {
    try {
      // print('Attempting to disconnect from ${event.device.remoteId}');
      // Cancel subscriptions
      await _charValueSubscription?.cancel();
      _charValueSubscription = null;
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;

      // Clear characteristic references
      _provisioningCharacteristic = null;
      _charValueStream = null;

      // Disconnect from the device
      await event.device.disconnect();

      emit(const BluetoothInitial()); // Reset to initial state
      // print('Disconnected from ${event.device.remoteId}');
    } catch (e) {
      // print('Error disconnecting: $e');
      // Avoid emitting error if already in a terminal clean state or after success
      if (!(state is BluetoothInitial ||
          state is BluetoothProvisioningSuccess)) {
        emit(BluetoothError('Failed to disconnect: ${e.toString()}'));
      } else {
        emit(const BluetoothInitial()); // Ensure state is reset
      }
    }
  }

  /// Called when the BLoC is closed.
  /// Ensures that any active subscriptions are cancelled.
  @override
  Future<void> close() {
    _charValueSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    // Consider disconnecting from any connected device if the BLoC is globally closed
    // This depends on your app's lifecycle management.
    // Example:
    // if (state is BluetoothReadyForProvisioning) {
    //   (state as BluetoothReadyForProvisioning).connectedDevice.disconnect().catchError((_){});
    // } else if (state is BluetoothConnecting) {
    //   (state as BluetoothConnecting).device.disconnect().catchError((_){});
    // }
    return super.close();
  }
}
