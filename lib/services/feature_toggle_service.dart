// Feature Toggle Service
import 'package:flutter_bloc/flutter_bloc.dart';

class FeatureToggleService extends Cubit<Map<String, bool>> {
  FeatureToggleService() : super({"new_nav_enabled": true});

  void updateFeatures(Map<String, bool> features) => emit(features);

  bool isFeatureEnabled(String featureKey) => state[featureKey] ?? false;
}
