import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme.dart';
import '../../models/settings.dart';
import '../../services/local_reminder_service.dart';

/// Section 5.3 — Settings Screen
///
/// Exposes voice language pref, snooze options, and notification sound toggle.
/// Changes to sound/snooze trigger a full re-schedule of active reminders.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: WhisprText.display(size: 22))),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Settings>('settings').listenable(),
        builder: (context, box, _) {
          final settings = box.isNotEmpty ? box.values.first : Settings();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // --- Voice language ---
              const _SectionHeader('Voice & Language'),
              _DropdownTile<String>(
                title: 'Voice language',
                subtitle: 'What language you speak when recording',
                value: settings.voiceLanguagePref,
                items: const {
                  'auto': 'Auto-detect (EN + Roman Urdu)',
                  'en': 'English only',
                  'roman_ur': 'Roman Urdu only',
                },
                onChanged: (val) async {
                  final updated = settings.copyWith(voiceLanguagePref: val);
                  await box.put(0, updated);
                },
              ),
              const SizedBox(height: 24),

              // --- Notifications ---
              const _SectionHeader('Notifications'),
              SwitchListTile(
                title: Text('Custom sound', style: WhisprText.body(size: 16)),
                subtitle: Text(
                  'Play the Whispr chime instead of the system default',
                  style: WhisprText.body(size: 13, color: WhisprColors.mutedInk),
                ),
                value: settings.notificationSoundEnabled,
                activeTrackColor: WhisprColors.sparkCyan,
                onChanged: (val) async {
                  final updated = settings.copyWith(notificationSoundEnabled: val);
                  await box.put(0, updated);
                  // Re-schedule all active reminders so channel changes apply.
                  await ref.read(localReminderServiceProvider).rescheduleAllActive();
                },
              ),
              SwitchListTile(
                title: Text('Haptics', style: WhisprText.body(size: 16)),
                value: settings.hapticsEnabled,
                activeTrackColor: WhisprColors.sparkCyan,
                onChanged: (val) async {
                  final updated = settings.copyWith(hapticsEnabled: val);
                  await box.put(0, updated);
                },
              ),
              const SizedBox(height: 24),

              // --- Live Activity window ---
              const _SectionHeader('Countdown'),
              _SliderTile(
                title: 'Default countdown window',
                subtitle: '${settings.defaultCountdownWindowMinutes} minutes before the reminder',
                value: settings.defaultCountdownWindowMinutes.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                onChanged: (val) async {
                  final updated = settings.copyWith(
                    defaultCountdownWindowMinutes: val.round(),
                  );
                  await box.put(0, updated);
                },
              ),
              const SizedBox(height: 24),

              // --- Snooze options ---
              const _SectionHeader('Snooze'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Quick snooze: ${settings.snoozeOptions.map((m) => '${m}m').join(', ')}',
                  style: WhisprText.body(size: 15),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Snooze option customisation coming in V2.',
                style: WhisprText.body(size: 13, color: WhisprColors.mutedInk),
              ),
              const SizedBox(height: 32),

              // --- Data notice ---
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: WhisprColors.spokenViolet.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '⚠️  All reminders are stored only on this device. Uninstalling '
                  'the app or clearing app storage will remove them permanently — '
                  'there is no cloud backup.',
                  style: WhisprText.body(size: 13, color: WhisprColors.mutedInk),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: WhisprText.body(
          size: 11,
          weight: FontWeight.w700,
          color: WhisprColors.mutedInk,
        ),
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  const _DropdownTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: WhisprText.body(size: 16)),
      subtitle: Text(subtitle,
          style: WhisprText.body(size: 13, color: WhisprColors.mutedInk)),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        items: items.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: WhisprText.body(size: 16)),
        Text(subtitle,
            style: WhisprText.body(size: 13, color: WhisprColors.mutedInk)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: WhisprColors.sparkCyan,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
