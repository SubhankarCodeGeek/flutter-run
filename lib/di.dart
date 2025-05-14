
import 'package:get_it/get_it.dart';

import 'features/presentation/bloc/bluetooth_bloc.dart';

final s1 = GetIt.instance;

Future<void> initDependencies() async{
  s1.registerFactory<BluetoothBloc>(() => BluetoothBloc());
}