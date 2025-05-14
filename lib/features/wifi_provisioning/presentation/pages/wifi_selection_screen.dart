import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' show BluetoothDevice; // Only import what's needed
import 'package:wifi_scan/wifi_scan.dart' show WiFiAccessPoint; // For type hinting

// Import your BLoCs, Events, and States
import 'bluetooth_bloc.dart';
import 'bluetooth_event.dart';
import 'bluetooth_state.dart' as ble; // Aliased to avoid name collision

import 'wifi_bloc.dart';
import 'wifi_event.dart';
import 'wifi_state.dart' as wifi; // Aliased

class WiFiSelectionScreen extends StatefulWidget {
  final BluetoothDevice bleDevice; // The BLE device we are provisioning

  const WiFiSelectionScreen({super.key, required this.bleDevice});

  @override
  State<WiFiSelectionScreen> createState() => _WiFiSelectionScreenState();
}

class _WiFiSelectionScreenState extends State<WiFiSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger initial Wi-Fi scan when the screen loads
    context.read<WifiBloc>().add(const StartWifiScan());
  }

  String _getSecurityType(WiFiAccessPoint ap) {
    // Simplified security type detection
    if (ap.capabilities.contains("WPA3")) return "WPA3";
    if (ap.capabilities.contains("WPA2")) return "WPA2";
    if (ap.capabilities.contains("WPA")) return "WPA";
    if (ap.capabilities.contains("WEP")) return "WEP";
    if (ap.capabilities.toUpperCase().contains("ESS") &&
        !ap.capabilities.toUpperCase().contains("WPA") &&
        !ap.capabilities.toUpperCase().contains("WEP")) return "OPEN";
    return "Secured"; // Default for unknown but likely secured networks
  }

  String _signalLevel(int rssi) {
    if (rssi >= -55) return 'Excellent';
    if (rssi >= -67) return 'Good';
    if (rssi >= -80) return 'Fair';
    return 'Weak';
  }

  IconData _getSignalIcon(int rssi) {
    if (rssi >= -55) return Icons.wifi_sharp;
    if (rssi >= -67) return Icons.wifi_2_bar_sharp;
    if (rssi >= -80) return Icons.wifi_1_bar_sharp;
    return Icons.signal_wifi_0_bar_sharp;
  }

  void _showPasswordDialog(BuildContext context, String currentSsid, String currentSecurity) {
    final ssidController = TextEditingController(text: currentSsid);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSsidEditable = currentSsid.isEmpty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Use a local BlocProvider if BluetoothBloc is not provided above this dialog in the widget tree,
        // or ensure it's accessible via context.read<BluetoothBloc>()
        return BlocListener<BluetoothBloc, ble.BluetoothState>(
          // Ensure this listener is specific to BluetoothBloc
          listener: (context, btState) { // Use btState to avoid conflict with wifi.WifiState
            if (btState is ble.BluetoothProvisioningSuccess) {
              if (Navigator.canPop(dialogContext)) {
                Navigator.of(dialogContext).pop();
              }
              ScaffoldMessenger.of(this.context).showSnackBar( // Use this.context for ScaffoldMessenger
                SnackBar(content: Text(btState.message), backgroundColor: Colors.green),
              );
              // Optionally, navigate back or to a success screen
              // Navigator.of(this.context).pop(); // Pop WiFiSelectionScreen
            } else if (btState is ble.BluetoothProvisioningFailure) {
              // Dialog's StatefulBuilder will handle button state, but show a SnackBar for clarity
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text("Provisioning Failed: ${btState.error}"), backgroundColor: Colors.red),
              );
            }
          },
          child: StatefulBuilder(
            builder: (stfContext, setStateDialog) {
              // Listen to BluetoothBloc state for disabling button during submission
              final bluetoothBlocState = BlocProvider.of<BluetoothBloc>(context).state;
              final bool isSubmitting = bluetoothBlocState is ble.BluetoothSendingWifiCredentials ||
                  bluetoothBlocState is ble.BluetoothAwaitingProvisioningConfirmation;

              return AlertDialog(
                title: Text(isSsidEditable ? 'Enter Hidden Network' : 'Connect to $currentSsid'),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView( // In case of smaller screens
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSsidEditable)
                          TextFormField(
                            controller: ssidController,
                            decoration: const InputDecoration(labelText: 'SSID', hintText: 'Hidden Network Name'),
                            validator: (value) =>
                            value == null || value.isEmpty ? 'SSID cannot be empty' : null,
                          ),
                        if (currentSecurity != "OPEN")
                          TextFormField(
                            controller: passwordController,
                            decoration: const InputDecoration(labelText: 'Password'),
                            obscureText: true,
                            validator: (value) {
                              if (currentSecurity != "OPEN" && (value == null || value.isEmpty)) {
                                return 'Password is required for secured networks';
                              }
                              return null;
                            },
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: const Text("This is an OPEN network. No password is required.", style: TextStyle(fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                      if (formKey.currentState!.validate()) {
                        final finalSsid = ssidController.text.trim();
                        final finalPassword = currentSecurity == "OPEN" ? "" : passwordController.text.trim();

                        // Dispatch event to BluetoothBloc
                        context.read<BluetoothBloc>().add(
                          SendWifiCredentialsEvent(
                            ssid: finalSsid,
                            password: finalPassword,
                            device: widget.bleDevice,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isSubmitting ? Colors.grey : Theme.of(context).primaryColor,
                        foregroundColor: Colors.white
                    ),
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Connect'),
                  )
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wi-Fi for ${widget.bleDevice.platformName.isNotEmpty ? widget.bleDevice.platformName : widget.bleDevice.remoteId.str}'),
        actions: [
          BlocBuilder<WifiBloc, wifi.WifiState>( // Refresh button reacts to WifiBloc state
            builder: (context, state) {
              bool isLoading = state is wifi.WifiScanning || state is wifi.WifiCheckingPermissions;
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: isLoading ? null : () => context.read<WifiBloc>().add(const StartWifiScan()),
                tooltip: "Refresh Wi-Fi List",
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          BlocBuilder<WifiBloc, wifi.WifiState>(
            builder: (context, state) {
              if (state is wifi.WifiScanning || state is wifi.WifiCheckingPermissions) {
                return const LinearProgressIndicator();
              }
              if (state is wifi.WifiScanFailure) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: Text(state.error, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center)),
                );
              }
              if (state is wifi.WifiPermissionsDenied) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: Text(state.message, style: const TextStyle(color: Colors.orange, fontSize: 16), textAlign: TextAlign.center)),
                );
              }
              if (state is wifi.WifiScanSuccess) {
                if (state.accessPoints.isEmpty) {
                  return const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            "No Wi-Fi networks found. Try refreshing or moving to a different location.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey)
                        ),
                      ),
                    ),
                  );
                }
                return Expanded(
                  child: ListView.builder(
                    itemCount: state.accessPoints.length,
                    itemBuilder: (context, index) {
                      final ap = state.accessPoints[index];
                      final String ssid = ap.ssid.isNotEmpty ? ap.ssid : "Hidden Network";
                      final int rssi = ap.level;
                      final String security = _getSecurityType(ap);
                      return ListTile(
                        leading: Icon(_getSignalIcon(rssi), color: Theme.of(context).primaryColor),
                        title: Text(ssid, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('$security • ${_signalLevel(rssi)} (RSSI: $rssi dBm)'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showPasswordDialog(context, ssid, security),
                      );
                    },
                  ),
                );
              }
              // Initial state or unhandled
              return const Expanded(
                child: Center(child: Text("Press refresh to scan for Wi-Fi networks.", style: TextStyle(fontSize: 16, color: Colors.grey))),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.wifi_tethering_outlined),
              onPressed: () => _showPasswordDialog(context, '', 'Unknown'), // For hidden, security type is unknown
              label: const Text('Connect to Hidden Network'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white
              ),
            ),
          ),
        ],
      ),
    );
  }
}
