import 'package:hive/hive.dart';

part 'pending_clarification.g.dart';

@HiveType(typeId: 3)
class PendingClarification extends HiveObject {
  @HiveField(0)
  String clarificationId;

  @HiveField(1)
  String originalInputText;

  @HiveField(2)
  List<Map<String, String>> conversationTurns;

  @HiveField(3)
  Map<String, dynamic> partialParse;

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
