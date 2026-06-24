import 'package:hive/hive.dart';

part 'pending_clarification.g.dart';

/// A short-lived object representing an in-progress AI conversation that
/// hasn't resolved into a saved reminder yet — exists only while the
/// Confirmation Card is showing a clarifying question and waiting on the
/// user's reply.
@HiveType(typeId: 3)
class PendingClarification extends HiveObject {
  @HiveField(0)
  String clarificationId;

  /// The user's first message (or "[voice]" label).
  @HiveField(1)
  String originalInputText;

  /// Each turn: {"role": "user"|"ai", "text": "..."}
  @HiveField(2)
  List<Map<String, String>> conversationTurns;

  /// Whatever the AI has structured so far (task title, partial time info)
  /// — kept as a loosely-typed map since its shape varies by how far the
  /// conversation has progressed.
  @HiveField(3)
  Map<String, dynamic> partialParse;

  /// Entries older than 24 hours are auto-deleted by the app-open cleanup
  /// routine (see LocalReminderService.cleanupExpiredClarifications).
  @HiveField(4)
  DateTime createdAt;

  PendingClarification({
    required this.clarificationId,
    required this.originalInputText,
    required this.conversationTurns,
    required this.partialParse,
    required this.createdAt,
  });
}
