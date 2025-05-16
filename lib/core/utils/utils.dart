import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/local_service.dart';

extension TranslateString on String {
  String translate(BuildContext context) {
    return context.watch<LocaleService>().translate(this);
  }
}
