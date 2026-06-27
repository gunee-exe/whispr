import 'package:hive/hive.dart';
import 'trigger_model.dart';
import 'recurrence_model.dart';

part 'reminder.g.dart';

@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  String reminderId;

  @HiveField(1)
  String taskTitle;

  @HiveField(2)
  String originalInputText;

  /// "text" | "voice"
  @HiveField(3)
  String inputMethod;

  /// "en" | "roman_ur" | "mixed"
  @HiveField(4)
  String detectedLanguage;

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

  /// "ai_create" | "manual_edit"
  @HiveField(11)
  String lastEditedVia;

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

  DateTime? get nextTriggerAt {
    final now = DateTime.now();
    final upcoming =
        triggers.where((t) => !t.fired && t.fireAt.isAfter(now)).toList()
          ..sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return upcoming.isEmpty ? null : upcoming.first.fireAt;
  }

  Reminder copyWith({
    String? taskTitle,
    DateTime? dueAt,
    List<TriggerModel>? triggers,
    RecurrenceModel? recurrence,
    String? status,
  }) {
    return Reminder(
      reminderId: reminderId,
      taskTitle: taskTitle ?? this.taskTitle,
      originalInputText: originalInputText,
      inputMethod: inputMethod,
      detectedLanguage: detectedLanguage,
      dueAt: dueAt ?? this.dueAt,
      triggers: triggers ?? this.triggers,
      recurrence: recurrence ?? this.recurrence,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      lastEditedVia: 'manual_edit',
      assumptionsMade: assumptionsMade,
    );
  }
}
