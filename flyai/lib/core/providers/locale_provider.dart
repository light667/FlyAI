import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings_base.dart';
import '../l10n/app_strings_fr.dart';
import '../l10n/app_strings_en.dart';

const _kLocalePrefKey = 'app_locale';

/// Provides the current [Locale] of the application.
/// Defaults to French ('fr'). Persisted via SharedPreferences.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('fr')) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocalePrefKey) ?? 'fr';
    state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocalePrefKey, locale.languageCode);
  }

  Future<void> toggleLocale() async {
    final next =
        state.languageCode == 'fr' ? const Locale('en') : const Locale('fr');
    await setLocale(next);
  }
}

/// Provides the correct [AppStringsBase] based on the current locale.
final stringsProvider = Provider<AppStringsBase>((ref) {
  final locale = ref.watch(localeProvider);
  if (locale.languageCode == 'fr') return const AppStringsFr();
  return const AppStringsEn();
});

/// Supported locales.
const kSupportedLocales = [Locale('fr'), Locale('en')];
