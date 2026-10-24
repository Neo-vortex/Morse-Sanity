import 'package:flutter/widgets.dart';

import 'services/morse_player.dart';
import 'services/progress.dart';
import 'services/settings.dart';

/// Makes the app-wide services available to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.progress,
    required this.player,
    required super.child,
  });

  final Settings settings;
  final Progress progress;
  final MorsePlayer player;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      settings != oldWidget.settings ||
      progress != oldWidget.progress ||
      player != oldWidget.player;
}
