import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/data/hive_database.dart';

abstract class ThemeEvent {}

class ToggleTheme extends ThemeEvent {}

class LoadTheme extends ThemeEvent {}

class ThemeState {
  final ThemeMode themeMode;
  ThemeState(this.themeMode);
}

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const String _themeKey = 'is_dark_mode';

  ThemeBloc() : super(ThemeState(ThemeMode.light)) {
    on<LoadTheme>((event, emit) {
      final isDark = HiveDatabase.settingsBox.get(_themeKey, defaultValue: false);
      emit(ThemeState(isDark ? ThemeMode.dark : ThemeMode.light));
    });

    on<ToggleTheme>((event, emit) async {
      final isCurrentlyDark = state.themeMode == ThemeMode.dark;
      final nextMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
      
      await HiveDatabase.settingsBox.put(_themeKey, !isCurrentlyDark);
      emit(ThemeState(nextMode));
    });
  }
}
