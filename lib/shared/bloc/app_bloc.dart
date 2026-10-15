import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/local_storage_service.dart';

/// AppBloc manages global app state including theme mode
/// 
/// Theme modes supported:
/// - system: Follow device theme automatically
/// - light: Always light theme
/// - dark: Always dark theme
class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc({LocalStorageService? storageService})
      : _storageService = storageService,
        super(const AppState()) {
    on<AppThemeToggled>(_onThemeToggled);
    on<AppThemeLoaded>(_onThemeLoaded);
  }

  final LocalStorageService? _storageService;
  static const _themeKey = 'app_theme_mode';

  /// Load theme from storage on app start
  Future<void> loadTheme() async {
    final storage = _storageService;
    if (storage == null) return;
    
    final savedTheme = storage.readString(_themeKey);
    final ThemeMode themeMode = switch (savedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    
    add(AppThemeLoaded(themeMode));
  }

  void _onThemeLoaded(AppThemeLoaded event, Emitter<AppState> emit) {
    emit(state.copyWith(themeMode: event.themeMode, isLoaded: true));
  }

  Future<void> _onThemeToggled(AppThemeToggled event, Emitter<AppState> emit) async {
    emit(state.copyWith(themeMode: event.themeMode));
    
    // Persist theme preference
    final storage = _storageService;
    if (storage != null) {
      final themeString = switch (event.themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await storage.writeString(_themeKey, themeString);
    }
  }
}

// Events
abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

class AppThemeToggled extends AppEvent {
  const AppThemeToggled(this.themeMode);

  final ThemeMode themeMode;

  @override
  List<Object?> get props => [themeMode];
}

class AppThemeLoaded extends AppEvent {
  const AppThemeLoaded(this.themeMode);

  final ThemeMode themeMode;

  @override
  List<Object?> get props => [themeMode];
}

// State
class AppState extends Equatable {
  const AppState({
    this.themeMode = ThemeMode.system,
    this.isLoaded = false,
  });

  final ThemeMode themeMode;
  final bool isLoaded;

  /// Check if current theme is dark (considering system theme)
  bool isDarkMode(BuildContext context) {
    if (themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return themeMode == ThemeMode.dark;
  }

  AppState copyWith({ThemeMode? themeMode, bool? isLoaded}) {
    return AppState(
      themeMode: themeMode ?? this.themeMode,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  List<Object?> get props => [themeMode, isLoaded];
}
