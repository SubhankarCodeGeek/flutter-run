
import 'package:fultter_run/services/feature_toggle_service.dart';
import 'package:fultter_run/services/local_service.dart';
import 'package:get_it/get_it.dart';

import 'features/bluetooth_connection/presentation/bloc/bluetooth_bloc.dart';
import 'features/wifi_provisioning/presentation/bloc/wifi_bloc.dart';


final sl = GetIt.instance;

Future<void> initDependencies() async{
  sl.registerFactory<LocaleService>(() => LocaleService());
  sl.registerFactory<FeatureToggleService>(() => FeatureToggleService());
  sl.registerFactory<BluetoothBloc>(() => BluetoothBloc());
  sl.registerFactory<WifiBloc>(() => WifiBloc());
}