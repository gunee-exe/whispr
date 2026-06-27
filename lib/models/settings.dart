import 'package:hive/hive.dart';

part 'settings.g.dart';

@HiveType(typeId: 4)
class Settings extends HiveObject {
  /// "auto" | "en" | "roman_ur"
  @HiveField(0)
  String voiceLanguagePref;

  /// Minutes, default [5, 60]
  @HiveField(1)
  List<int> snoozeOptions;

  /// Use custom notification sound
  @HiveField(2)
  bool notificationSoundEnabled;

  /// Haptic feedback on reminders
  @HiveField(3)
  bool hapticsEnabled;

  /// Default live-activity countdown window in minutes
  @HiveField(4)
  int defaultCountdownWindowMinutes;

  Settings({
    this.voiceLanguagePref = 'auto',
    this.snoozeOptions = const [5, 60],
    this.notificationSoundEnabled = true,
    this.hapticsEnabled = true,
    this.defaultCountdownWindowMinutes = 30,
  });

  Settings copyWith({
    String? voiceLanguagePref,
    List<int>? snoozeOptions,
    bool? notificationSoundEnabled,
    bool? hapticsEnabled,
    int? defaultCountdownWindowMinutes,
  }) {
    return Settings(
      voiceLanguagePref: voiceLanguagePref ?? this.voiceLanguagePref,
      snoozeOptions: snoozeOptions ?? this.snoozeOptions,
      notificationSoundEnabled:
          notificationSoundEnabled ?? this.notificationSoundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      defaultCountdownWindowMinutes:
          defaultCountdownWindowMinutes ?? this.defaultCountdownWindowMinutes,
    );
  }
}
