import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local imports for events and states
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
    on<StartBleScanEvent>(_onStartBleScan);
    on<ConnectToDeviceEvent>(_onConnectToDevice);
    on<SendWifiCredentialsEvent>(_onSendWifiCredentials);
    on<DisconnectFromDeviceEvent>(_onDisconnect);
  }

  Future<void> _onStartBleScan(
    StartBleScanEvent event,
    Emitter<MyBleState> emit,
  ) async {
    emit(const BluetoothScanning());
    try {
      if (!(await FlutterBluePlus.isSupported)) {
        emit(const BluetoothError("Bluetooth not supported on this device."));
        return;
      }
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        emit(const BluetoothError("Bluetooth is off. Please turn it on."));
        return;
      }

      final List<BluetoothDevice> foundDevices = [];
      final Set<DeviceIdentifier> discoveredDeviceIds = {};
      final scanCompleter = Completer<void>();
      StreamSubscription? scanResultsSubscription;

      // Listen to scan results
      scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          // Filter by devices that advertise your specific service UUID (done by startScan's withServices)
          // and ensure it has a name and is not already added.
          if (r.device.platformName.isNotEmpty &&
              !discoveredDeviceIds.contains(r.device.remoteId)) {
            // print('Found target device: ${r.device.platformName} (${r.device.remoteId})');
            foundDevices.add(r.device);
            discoveredDeviceIds.add(r.device.remoteId);
          }
        }
      });

      // --- KEY IMPROVEMENT: Scan specifically for devices advertising your provisioning service ---
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 7), // Slightly longer scan
        withServices: [], // Filter by your service UUID
      );

      Future.delayed(const Duration(seconds: 7), () {
        if (!scanCompleter.isCompleted) scanCompleter.complete();
      });

      await scanCompleter.future;
      // No need to call FlutterBluePlus.stopScan() if timeout is used in startScan,
      // but it doesn't hurt to call it to be sure.
      await FlutterBluePlus.stopScan();
      await scanResultsSubscription?.cancel();

      if (foundDevices.isEmpty) {
        // print("No relevant BLE devices found advertising the provisioning service.");
        emit(const BluetoothDevicesFound([]));
      } else {
        emit(BluetoothDevicesFound(List.from(foundDevices)));
      }
    } catch (e) {
      // print('BLE Scan failed: $e');
      emit(BluetoothError('BLE Scan failed: ${e.toString()}'));
    }
  }

  Future<void> _onConnectToDevice(
    ConnectToDeviceEvent event,
    Emitter<MyBleState> emit,
  ) async {
    emit(BluetoothConnecting(event.device));
    final device = event.device;
    int maxRetries = 2; // Max 2 retries (total 3 attempts)
    int currentAttempt = 0;
    bool isConnectedAndSetup = false;

    // Stop scanning before attempting to connect, if not already stopped.
    // This should ideally be handled by the UI flow (e.g., not allowing connect while scanning).
    // However, an explicit stop here can be a safeguard.
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    await _connectionStateSubscription?.cancel(); // Cancel previous listener
    _connectionStateSubscription = device.connectionState
        .listen((BluetoothConnectionState connectionState) {
      // print('Device ${device.remoteId} connection state changed: $connectionState');
      if (connectionState == BluetoothConnectionState.disconnected) {
        bool isRelevantState = state is BluetoothReadyForProvisioning ||
            state is BluetoothConnecting ||
            state is BluetoothAwaitingProvisioningConfirmation ||
            state is BluetoothSendingWifiCredentials;
        if (isRelevantState && state is! BluetoothProvisioningSuccess) {
          // print('Device ${device.remoteId} disconnected unexpectedly during active phase.');
          add(DisconnectFromDeviceEvent(device)); // Trigger cleanup
          // Avoid emitting error here if retry logic will handle it or if disconnect is part of cleanup
        }
      }
    });

    while (currentAttempt <= maxRetries && !isConnectedAndSetup) {
      currentAttempt++;
      print("Connection attempt $currentAttempt for ${device.remoteId}");
      try {
        await device.connect(
            timeout: const Duration(seconds: 15),
            autoConnect: false // Explicitly false for provisioning
            );

        // Short delay to allow connection to stabilize before service discovery
        // This can sometimes help with peripherals that are slow to initialize post-connection.
        await Future.delayed(const Duration(milliseconds: 500));

        if (!device.isConnected) {
          throw Exception(
              "Device failed to report connected state after connect call.");
        }

        List<BluetoothService> services = await device.discoverServices();
        _provisioningCharacteristic = null;

        // for (final service in services) {
        //   if (service.uuid == _provisioningServiceUuid) {
        //     for (final characteristic in service.characteristics) {
        //       if (characteristic.uuid == _provisioningCharacteristicUuid) {
        //         final canWrite = characteristic.properties.write ||
        //             characteristic.properties.writeWithoutResponse;
        //         final canNotify = characteristic.properties.notify ||
        //             characteristic.properties.indicate;
        //         if (canWrite && canNotify) {
        //           _provisioningCharacteristic = characteristic;
        //           _charValueStream = characteristic.onValueReceived;
        //           await _charValueSubscription?.cancel();
        //           _charValueSubscription = _charValueStream?.listen((value) {
        //             /* General listener */
        //           });
        //           await characteristic.setNotifyValue(true);
        //           isConnectedAndSetup = true; // Mark as successful setup
        //           print(
        //               "Provisioning characteristic found and notifications enabled.");
        //           break;
        //         }
        //       }
        //     }
        //   }
        //   if (isConnectedAndSetup) break;
        // }
        //
        // if (!isConnectedAndSetup) {
        //   // This means services were discovered, but the specific characteristic wasn't found.
        //   throw Exception(
        //       'Provisioning characteristic not found after connection. Check UUIDs/device firmware.');
        // }

        emit(BluetoothReadyForProvisioning(device));
        return; // Successfully connected and setup
      } catch (e) {
        // print('Connection attempt $currentAttempt for ${device.remoteId} failed: $e');
        // The device.disconnect() call is important to clean up resources before a retry.
        // It will also trigger the connectionState listener if not already disconnected.
        await device.disconnect().catchError((_) {
          // print("Error during disconnect cleanup in retry: $_");
        });

        if (currentAttempt > maxRetries) {
          print("Max connection retries reached for ${device.remoteId}.");
          await _connectionStateSubscription
              ?.cancel(); // Final cleanup of listener
          _connectionStateSubscription = null;
          emit(BluetoothError(
              'Connection failed after $currentAttempt attempts: ${e.toString()}'));
          return;
        }
        // Wait before retrying (except for the last attempt)
        if (currentAttempt <= maxRetries) {
          await Future.delayed(
              Duration(seconds: currentAttempt * 1)); // Increasing delay
        }
      }
    }

    // If loop finishes without isConnectedAndSetup being true (should be caught by rethrow)
    if (!isConnectedAndSetup) {
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;
      emit(BluetoothError(
          'Failed to connect and setup device ${device.remoteId} after multiple attempts.'));
    }
  }

  Future<void> _onSendWifiCredentials(
    SendWifiCredentialsEvent event,
    Emitter<MyBleState> emit,
  ) async {
    if (_provisioningCharacteristic == null || _charValueStream == null) {
      emit(const BluetoothProvisioningFailure(
          'Characteristic not available. Please reconnect.'));
      return;
    }
    // Ensure device is still connected before attempting to write
    if (!event.device.isConnected) {
      emit(BluetoothProvisioningFailure(
          'Device disconnected before sending credentials.',
          device: event.device));
      add(DisconnectFromDeviceEvent(event.device)); // Clean up
      return;
    }

    emit(const BluetoothSendingWifiCredentials());

    try {
      final payload =
          jsonEncode({'ssid': event.ssid, 'password': event.password});
      final base64Payload = base64Encode(utf8.encode(payload));
      final List<int> bytesToSend = utf8.encode(base64Payload);

      if (!_provisioningCharacteristic!.isNotifying) {
        await _provisioningCharacteristic!.setNotifyValue(true);
      }

      bool canWriteAck = _provisioningCharacteristic!.properties.write;
      await _provisioningCharacteristic!
          .write(bytesToSend, withoutResponse: !canWriteAck);
      print(
          'Wi-Fi credentials sent to ${event.device.remoteId}. SSID: ${event.ssid}');

      emit(const BluetoothAwaitingProvisioningConfirmation());

      final response = await _charValueStream!.first.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print("Timeout waiting for provisioning confirmation from device.");
          throw TimeoutException(
              'Device did not respond with provisioning status in time.');
        },
      );

      if (response.isEmpty) {
        throw Exception('Empty response from device during provisioning.');
      }

      final String status = utf8.decode(response, allowMalformed: true);
      print('Received provisioning status from device: $status');

      if (status.toUpperCase().startsWith('SUCCESS') ||
          status.toUpperCase() == 'OK') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('provisioned_${event.device.remoteId.str}', true);

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
        throw Exception('Provisioning failed on device: $status');
      }
    } catch (e) {
      // print('Error sending Wi-Fi credentials or processing response: $e');
      await FirebaseFirestore.instance.collection('provisioningStatus').add({
        'deviceId': event.device.remoteId.str,
        'deviceName': event.device.platformName,
        'ssid': event.ssid,
        'status': 'failure',
        'error': e.toString(),
        'timestamp': Timestamp.now(),
      }).catchError((_) {});
      emit(BluetoothProvisioningFailure(e.toString(), device: event.device));
    }
  }

  Future<void> _onDisconnect(
    DisconnectFromDeviceEvent event,
    Emitter<MyBleState> emit,
  ) async {
    try {
      // print('Explicit disconnect requested for ${event.device.remoteId}');
      await _charValueSubscription?.cancel();
      _charValueSubscription = null;
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;

      _provisioningCharacteristic = null;
      _charValueStream = null;

      if (event.device.isConnected) {
        // Check if actually connected before calling disconnect
        await event.device.disconnect();
      }

      emit(const BluetoothInitial());
      // print('Disconnected successfully from ${event.device.remoteId}');
    } catch (e) {
      // print('Error during explicit disconnect: $e');
      if (!(state is BluetoothInitial ||
          state is BluetoothProvisioningSuccess)) {
        emit(BluetoothError('Failed to disconnect: ${e.toString()}'));
      } else {
        emit(const BluetoothInitial());
      }
    }
  }

  @override
  Future<void> close() {
    _charValueSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    // Consider if you need to disconnect from a device if the BLoC is closed during an active connection.
    // For example:
    // if (state is BluetoothReadyForProvisioning) {
    //   (state as BluetoothReadyForProvisioning).connectedDevice.disconnect().catchError((_){});
    // }
    return super.close();
  }
}
