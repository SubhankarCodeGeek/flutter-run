import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../wifi_provisioning/presentation/pages/wifi_selection_screen.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAndScan();
  }

  Future<void> _initializeAndScan() async {
    // Check Bluetooth is on
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bluetooth Required'),
            content: const Text('Please enable Bluetooth to scan for devices.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking Bluetooth state: $e')),
      );
      return;
    }

    // Request permissions
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
      if (statuses.values.any((status) => !status.isGranted)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions not granted')),
        );
        return;
      }
    }

    // Start scanning
    context.read<BluetoothBloc>().add(const StartBleScanEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select IoT Device'),
        actions: [
          BlocBuilder<BluetoothBloc, MyBleState>(
            // Refresh button reacts to BluetoothBloc state
            builder: (context, state) {
              bool isLoading = state is BluetoothScanning ||
                  state is BluetoothConnecting;
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: isLoading
                    ? null
                    : () => context.read<BluetoothBloc>().add(const StartBleScanEvent()),
                tooltip: "Refresh Wi-Fi List",
              );
            },
          )
        ],
      ),
      body: BlocConsumer<BluetoothBloc, MyBleState>(
        listener: (context, state) {
          if (state is BluetoothError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is BluetoothScanning) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is BluetoothDevicesFound) {
            return ListView.builder(
              itemCount: state.devices.length,
              itemBuilder: (context, index) {
                final device = state.devices[index];
                return ListTile(
                  title: Text(device.name.isEmpty ? 'Unknown' : device.name),
                  subtitle: Text(device.id.id),
                  onTap: () => context
                      .read<BluetoothBloc>()
                      .add(ConnectToDeviceEvent(device)),
                );
              },
            );
          } else if (state is BluetoothReadyForProvisioning) {
            // Navigate to Wi-Fi provisioning on connection
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      WiFiSelectionScreen(bleDevice: state.connectedDevice),
                ),
              );
            });
            return const Center(
                child:
                    Text('Device connected. Preparing Wi-Fi provisioning...'));
          }
          return const Center(child: Text('No Devices Found'));
        },
      ),
    );
  }
}

// class WiFiSelectionScreen extends StatelessWidget {
//   final BluetoothDevice device;
//
//   const WiFiSelectionScreen({super.key, required this.device});
//
//   @override
//   Widget build(BuildContext context) {
//     final List<Map<String, Object>> wifiList = [
//       {'ssid': 'HomeWiFi', 'rssi': -40, 'security': 'WPA2'},
//       {'ssid': 'OfficeWiFi', 'rssi': -60, 'security': 'WPA3'},
//       {'ssid': 'HiddenNetwork', 'rssi': -80, 'security': 'WEP'},
//     ];
//
//     // Sort by RSSI descending
//     wifiList.sort((a, b) => (b['rssi'] as int).compareTo(a['rssi'] as int));
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Select Wi-Fi')),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               itemCount: wifiList.length,
//               itemBuilder: (context, index) {
//                 final wifi = wifiList[index];
//                 return ListTile(
//                   title: Text(wifi['ssid'] as String),
//                   subtitle: Text(
//                       '${wifi['security']} • ${_signalLevel(wifi['rssi'] as int)}'),
//                   onTap: () =>
//                       _showPasswordDialog(context, wifi['ssid'] as String),
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: ElevatedButton(
//               onPressed: () => _showPasswordDialog(context, ''),
//               child: const Text('Enter Hidden Network'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _signalLevel(int rssi) {
//     if (rssi >= -50) return 'Excellent';
//     if (rssi >= -60) return 'Good';
//     if (rssi >= -70) return 'Fair';
//     return 'Weak';
//   }
//
//   void _showPasswordDialog(BuildContext context, String ssid) {
//     final ssidController = TextEditingController(text: ssid);
//     final passwordController = TextEditingController();
//     bool isSubmitting = false;
//
//     showDialog(
//       context: context,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setState) => AlertDialog(
//           title: Text(ssid.isEmpty ? 'Enter Hidden SSID' : 'Connect to $ssid'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (ssid.isEmpty)
//                 TextField(
//                   controller: ssidController,
//                   decoration: const InputDecoration(labelText: 'SSID'),
//                 ),
//               TextField(
//                 controller: passwordController,
//                 decoration: const InputDecoration(labelText: 'Password'),
//                 obscureText: true,
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: isSubmitting
//                   ? null
//                   : () async {
//                       setState(() => isSubmitting = true);
//                       final success = await _sendWiFiCredentials(
//                         context,
//                         ssidController.text.trim(),
//                         passwordController.text.trim(),
//                       );
//                       setState(() => isSubmitting = false);
//                     },
//               child: isSubmitting
//                   ? const CircularProgressIndicator()
//                   : const Text('Connect'),
//             )
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _sendWiFiCredentials(
//       BuildContext context, String ssid, String password) async {
//     final bloc = context.read<BluetoothBloc>();
//     final characteristic = await bloc.getProvisioningCharacteristic();
//     final payload = jsonEncode({'ssid': ssid, 'password': password});
//     final encryptedPayload = base64Encode(utf8.encode(payload));
//
//     await characteristic.write(utf8.encode(encryptedPayload),
//         withoutResponse: true);
//
//     try {
//       // Read first notification with timeout
//       final response = await characteristic.value.first.timeout(
//         const Duration(seconds: 10),
//         onTimeout: () => <int>[],
//       );
//       if (response.isNotEmpty && utf8.decode(response) == 'OK') {
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setBool('provisioned', true);
//         await FirebaseFirestore.instance.collection('provisioningStatus').add({
//           'device': device.id.id,
//           'ssid': ssid,
//           'timestamp': Timestamp.now(),
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Provisioning complete')));
//       } else {
//         throw Exception('Provisioning failed');
//       }
//     } catch (_) {
//       ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Failed to provision device')));
//     }
//   }
// }
