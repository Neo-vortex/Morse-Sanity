import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../morse/keyer.dart';
import '../services/settings.dart';
import '../widgets/dit.dart';
import 'onboarding_screen.dart';
import '../l10n/strings.dart';
import '../widgets/language_picker.dart';
import '../morse/tone_generator.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final theme = Theme.of(context);
          final farnsworth = settings.effectiveWpm < settings.charWpm;
          Widget value(String text) =>
              Text(text, style: theme.textTheme.titleMedium);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _SectionHeader(s.language),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const Expanded(child: LanguagePicker()),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: settings.languageCode.isEmpty
                          ? null
                          : () => settings.languageCode = '',
                      child: Text(s.systemLanguage),
                    ),
                  ],
                ),
              ),
              _SectionHeader(s.profile),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(s.operatorName),
                subtitle: Text(
                  settings.operatorName.isEmpty
                      ? s.notSet
                      : settings.operatorName,
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editName(context),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(s.dailyGoal),
                trailing: DropdownButton<int>(
                  value: dailyGoals.contains(settings.dailyGoal)
                      ? settings.dailyGoal
                      : dailyGoals[1],
                  onChanged: (v) => settings.dailyGoal = v!,
                  items: [
                    for (final g in dailyGoals)
                      DropdownMenuItem(
                        value: g,
                        child: Text('${s.goalName(g)} · ${s.xp(g)}'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(s.themeAuto),
                      icon: const Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(s.themePaper),
                      icon: const Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(s.themeNight),
                      icon: const Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => settings.themeMode = s.first,
                ),
              ),
              _SectionHeader(s.speed),
              ListTile(
                title: Text(s.wordsPerMinute),
                subtitle: Text(s.wpmSub),
                trailing: value(s.wpm(settings.charWpm)),
              ),
              Slider(
                value: settings.charWpm.toDouble(),
                min: 5,
                max: 50,
                divisions: 45,
                label: '${settings.charWpm}',
                onChanged: (v) => settings.charWpm = v.round(),
              ),
              ListTile(
                title: Text(s.farnsworth),
                subtitle: Text(farnsworth ? s.farnsworthOn : s.farnsworthOff),
                trailing: value(s.wpm(settings.effectiveWpm)),
              ),
              Slider(
                value: settings.effectiveWpm.toDouble(),
                min: 5,
                max: 50,
                divisions: 45,
                label: '${settings.effectiveWpm}',
                onChanged: (v) => settings.effectiveWpm = v.round(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(s.speedTip),
              ),
              _SectionHeader(s.sound),
              ListTile(
                title: Text(s.tonePitch),
                trailing: value(s.hz(settings.frequency.round())),
              ),
              Slider(
                value: settings.frequency,
                min: 300,
                max: 1200,
                divisions: 90,
                label: '${settings.frequency.round()} Hz',
                onChanged: (v) => settings.frequency = v.roundToDouble(),
              ),
              ListTile(
                title: Text(s.volume),
                trailing: value(s.percent((settings.volume * 100).round())),
              ),
              Slider(
                value: settings.volume,
                divisions: 20,
                onChanged: (v) => settings.volume = v,
              ),

              SwitchListTile(
                title: Text(s.interfaceSounds),
                subtitle: Text(s.interfaceSoundsSub),
                value: settings.interfaceSounds,
                onChanged: (v) => settings.interfaceSounds = v,
              ),
              _SectionHeader(s.radioNoise),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(s.noiseSub),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<NoiseType>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: NoiseType.white,
                      label: Text(s.noiseWhite),
                    ),
                    ButtonSegment(
                      value: NoiseType.pink,
                      label: Text(s.noisePink),
                    ),
                    ButtonSegment(
                      value: NoiseType.receiver,
                      label: Text(s.noiseReceiver),
                    ),
                  ],
                  selected: {settings.noiseType},
                  onSelectionChanged: (v) => settings.noiseType = v.first,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  s.noiseTypeBlurb(settings.noiseType),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                title: Text(s.noiseIntensity),
                trailing: value(
                  settings.noiseLevel == 0
                      ? s.noiseOff
                      : s.percent((settings.noiseLevel * 100).round()),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: settings.noiseLevel,
                      divisions: 20,
                      onChanged: (v) => settings.noiseLevel = v,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: FilledButton.tonalIcon(
                      onPressed: () => scope.player.playText('CQ CQ DE DIT K'),
                      icon: const Icon(Icons.radio_rounded),
                      label: Text(s.hearIt),
                    ),
                  ),
                ],
              ),
              _SectionHeader(s.outputModes),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up),
                title: Text(s.sound),
                value: settings.soundEnabled,
                onChanged: (v) => settings.soundEnabled = v,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.lightbulb),
                title: Text(s.blinkingLight),
                subtitle: Text(s.blinkingLightSub),
                value: settings.flashEnabled,
                onChanged: (v) => settings.flashEnabled = v,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.flashlight_on),
                title: Text(s.flashlight),
                subtitle: Text(s.flashlightSub),
                value: settings.torchEnabled,
                onChanged: (v) => settings.torchEnabled = v,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.vibration),
                title: Text(s.vibration),
                subtitle: Text(s.vibrationSub),
                value: settings.vibrationEnabled,
                onChanged: (v) => settings.vibrationEnabled = v,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.touch_app),
                title: Text(s.haptics),
                subtitle: Text(s.hapticsSub),
                value: settings.hapticsEnabled,
                onChanged: (v) => settings.hapticsEnabled = v,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Dit(size: 64, signal: scope.player.signal),
                    const SizedBox(width: 16),
                    FilledButton.tonalIcon(
                      onPressed: () => scope.player.playText('PARIS PARIS'),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(s.testParis),
                    ),
                  ],
                ),
              ),
              _SectionHeader(s.sendingKey),
              RadioGroup<KeyType>(
                groupValue: settings.keyType,
                onChanged: (v) => settings.keyType = v!,
                child: Column(
                  children: [
                    for (final t in KeyType.values)
                      RadioListTile<KeyType>(
                        value: t,
                        title: Text(s.keyLabel(t)),
                        subtitle: Text(s.keyDescription(t)),
                      ),
                  ],
                ),
              ),
              SwitchListTile(
                title: Text(s.swapPaddles),
                subtitle: Text(s.swapPaddlesSub),
                value: settings.swapPaddles,
                onChanged: settings.keyType.hasTwoContacts
                    ? (v) => settings.swapPaddles = v
                    : null,
              ),
              _SectionHeader(s.course),
              ListTile(
                title: Text(s.keyboardLayout),
                subtitle: Text(s.keyboardLayoutSub),
                trailing: DropdownButton<KeyboardLayout>(
                  value: settings.keyboardLayout,
                  onChanged: (v) => settings.keyboardLayout = v!,
                  items: [
                    for (final l in KeyboardLayout.values)
                      DropdownMenuItem(value: l, child: Text(s.layoutName(l))),
                  ],
                ),
              ),
              SwitchListTile(
                title: Text(s.unlockAll),
                subtitle: Text(s.unlockAllSub),
                value: settings.unlockAll,
                onChanged: (v) => settings.unlockAll = v,
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _editName(BuildContext context) async {
  final settings = AppScope.of(context).settings;
  final controller = TextEditingController(text: settings.operatorName);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.s.whatToCallYou),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: context.s.yourName),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(context.s.save),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name != null) settings.operatorName = name;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
