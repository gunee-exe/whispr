import 'package:hive/hive.dart';

part 'settings.g.dart';

@HiveType(typeId: 4)
class Settings extends HiveObject {
  /// "auto" | "en" | "roman_ur"
  @HiveField(0)
  String voiceLanguagePref;

  /// Minutes, default [5, 60] meaning "5 min" and "1 hour" quick-snooze buttons.
  @HiveField(1)
  List<int> snoozeOptions;

  /// Whether the distinct custom notification sound is used (true) or the
  /// device falls back to silent/vibrate-only (false).
  @HiveField(2)
  bool notificationSoundEnabled;

  Settings({
    this.voiceLanguagePref = 'auto',
    this.snoozeOptions = const [5, 60],
    this.notificationSoundEnabled = true,
  });
}
