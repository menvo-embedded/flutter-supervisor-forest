import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const String _key = 'theme_mode';

  ThemeBloc() : super(const ThemeState(ThemeMode.light)) {
    on<ThemeCheckRequested>(_onCheckRequested);
    on<ThemeModeChanged>(_onModeChanged);
  }

  void _onCheckRequested(ThemeCheckRequested event, Emitter<ThemeState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString(_key);
      if (modeString == 'dark') {
        emit(const ThemeState(ThemeMode.dark));
      } else if (modeString == 'light') {
        emit(const ThemeState(ThemeMode.light));
      } else {
        emit(const ThemeState(ThemeMode.light));
      }
    } catch (_) {
      emit(const ThemeState(ThemeMode.light));
    }
  }

  void _onModeChanged(ThemeModeChanged event, Emitter<ThemeState> emit) async {
    emit(ThemeState(event.mode));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, event.mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}
