import '../../models/trigger_model.dart';
import '../../models/recurrence_model.dart';

/// Mirrors Section 6.3's three JSON response shapes — from Person 1 work
enum ConfirmationCardType { ready, needsClarification, multiTaskDetected }

class ConfirmationCardData {
  final ConfirmationCardType cardType;
  final String inputMethod; // "text" | "voice"
  final String originalInputText;

  // --- Shape A: ready ---
  final String? taskTitle;
  final DateTime? dueAt;
  final List<TriggerModel>? triggers;
  final RecurrenceModel? recurrence;
  final List<String> assumptionsMade;

  // --- Shape B: needs_clarification ---
  final String? question;
  final List<String>? quickReplyOptions;
  final Map<String, dynamic>? partialParse;

  // --- Shape C: multi_task_detected ---
  final ConfirmationCardData? interpretationSingleTask;
  final List<ConfirmationCardData>? interpretationTwoTasks;

  const ConfirmationCardData({
    required this.cardType,
    required this.inputMethod,
    required this.originalInputText,
    this.taskTitle,
    this.dueAt,
    this.triggers,
    this.recurrence,
    this.assumptionsMade = const [],
    this.question,
    this.quickReplyOptions,
    this.partialParse,
    this.interpretationSingleTask,
    this.interpretationTwoTasks,
  });

  factory ConfirmationCardData.fromAiResponse(
    Map<String, dynamic> json, {
    required String inputMethod,
    required String originalInputText,
  }) {
    final responseType = json['responseType'] as String?;
    switch (responseType) {
      case 'needs_clarification':
        return ConfirmationCardData(
          cardType: ConfirmationCardType.needsClarification,
          inputMethod: inputMethod,
          originalInputText: originalInputText,
          question: json['question'] as String?,
          quickReplyOptions: (json['quickReplyOptions'] as List?)
              ?.cast<String>(),
          partialParse: json['partialParse'] as Map<String, dynamic>?,
        );
      case 'multi_task_detected':
        final single =
            json['interpretationSingleTask'] as Map<String, dynamic>?;
        final twoTasksRaw = json['interpretationTwoTasks'] as List?;
        return ConfirmationCardData(
          cardType: ConfirmationCardType.multiTaskDetected,
          inputMethod: inputMethod,
          originalInputText: originalInputText,
          interpretationSingleTask: single == null
              ? null
              : ConfirmationCardData.fromAiResponse(
                  {...single, 'responseType': 'ready'},
                  inputMethod: inputMethod,
                  originalInputText: originalInputText,
                ),
          interpretationTwoTasks: twoTasksRaw
              ?.map(
                (t) => ConfirmationCardData.fromAiResponse(
                  {...t as Map<String, dynamic>, 'responseType': 'ready'},
                  inputMethod: inputMethod,
                  originalInputText: originalInputText,
                ),
              )
              .toList(),
        );
      case 'ready':
      default:
        return ConfirmationCardData(
          cardType: ConfirmationCardType.ready,
          inputMethod: inputMethod,
          originalInputText: originalInputText,
          taskTitle: json['taskTitle'] as String?,
          dueAt: json['dueAt'] != null
              ? DateTime.tryParse(json['dueAt'] as String)?.toLocal()
              : null,
          triggers: _parseTriggers(json['triggers'] as List?),
          recurrence: _parseRecurrence(
            json['recurrence'] as Map<String, dynamic>?,
          ),
          assumptionsMade:
              (json['assumptionsMade'] as List?)?.cast<String>() ?? const [],
        );
    }
  }

  static List<TriggerModel>? _parseTriggers(List? raw) {
    if (raw == null) return null;
    int counter = 0;
    return raw.map((t) {
      final map = t as Map<String, dynamic>;
      return TriggerModel(
        triggerId: '${DateTime.now().microsecondsSinceEpoch}_${counter++}',
        fireAt: DateTime.parse(map['fireAt'] as String).toLocal(),
        label: map['label'] as String? ?? '',
        kind: map['kind'] as String? ?? 'fixed_time',
        localNotificationId: 0,
      );
    }).toList();
  }

  static RecurrenceModel? _parseRecurrence(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    return RecurrenceModel(
      type: raw['type'] as String,
      daysOfWeek: (raw['daysOfWeek'] as List?)?.cast<int>(),
      timesOfDay: (raw['timesOfDay'] as List?)?.cast<String>() ?? const [],
      endDate: raw['endDate'] != null
          ? DateTime.tryParse(raw['endDate'] as String)?.toLocal()
          : null,
    );
  }
}
