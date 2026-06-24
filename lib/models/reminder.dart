import 'package:hive/hive.dart';
import 'trigger_model.dart';
import 'recurrence_model.dart';

part 'reminder.g.dart';

/// One object = one task, regardless of how many times it fires.
/// Stored in the Hive box "reminders", keyed by reminderId.
@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  String reminderId;

  @HiveField(1)
  String taskTitle;

  /// The raw typed sentence, or a short label like "[voice]" if created via
  /// audio (no transcript is ever stored). Kept for "what did I actually
  /// say/do" lookups.
  @HiveField(2)
  String originalInputText;

  /// "text" | "voice"
  @HiveField(3)
  String inputMethod;

  /// "en" | "roman_ur" | "mixed"
  @HiveField(4)
  String detectedLanguage;

  /// The actual deadline/event time, if the task has one. Null for tasks
  /// with no single deadline (e.g. pure recurring "take medicine daily").
  @HiveField(5)
  DateTime? dueAt;

  @HiveField(6)
  List<TriggerModel> triggers;

  /// Null if one-time.
  @HiveField(7)
  RecurrenceModel? recurrence;

  /// "active" | "completed" | "cancelled"
  @HiveField(8)
  String status;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  /// "ai_create" | "manual_edit" — tracks whether the user has manually
  /// touched it since creation.
  @HiveField(11)
  String lastEditedVia;

  /// Plain-language notes the AI made about defaults it applied
  /// (e.g. "assumed 9:00 AM since no exact time was given").
  /// Not in the original schema table but useful to retain for display —
  /// stored here rather than discarded after the confirmation card closes.
  @HiveField(12)
  List<String> assumptionsMade;

  Reminder({
    required this.reminderId,
    required this.taskTitle,
    required this.originalInputText,
    required this.inputMethod,
    required this.detectedLanguage,
    this.dueAt,
    required this.triggers,
    this.recurrence,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.lastEditedVia = 'ai_create',
    this.assumptionsMade = const [],
  });
}
