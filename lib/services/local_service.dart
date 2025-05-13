// Locale Service
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/localization/localization_helpers.dart';

class LocaleService extends Cubit<Locale> {
  LocaleService() : super(const Locale('en', 'US'));

  void changeLocale(Locale locale) => emit(locale);

  String translate(String key) {
    // Add your localization logic to fetch strings based on the key and current locale.
    final locale = state.languageCode; // You can access the current locale
    // Assuming you have a localized strings map for each locale:
    return localizedStrings[locale]?[key] ?? key; // Default to the key if no translation found
  }
}