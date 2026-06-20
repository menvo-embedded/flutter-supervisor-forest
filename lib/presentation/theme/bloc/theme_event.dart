import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();
  @override
  List<Object?> get props => [];
}

class ThemeCheckRequested extends ThemeEvent {
  const ThemeCheckRequested();
}

class ThemeModeChanged extends ThemeEvent {
  final ThemeMode mode;
  const ThemeModeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}
