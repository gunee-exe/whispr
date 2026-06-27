import 'package:hive/hive.dart';

part 'trigger_model.g.dart';

/// One independent moment a reminder notifies the user.
/// A task with "remind 2 days before, 1 day before, 3 hours before"
/// has three of these, all on the same parent Reminder.
@HiveType(typeId: 1)
class TriggerModel extends HiveObject {
  @HiveField(0)
  String triggerId;

  /// Absolute, resolved point in time this trigger fires.
  @HiveField(1)
  DateTime fireAt;

  /// Human-readable description shown in UI
  @HiveField(2)
  String label;

  /// "fixed_time" | "offset_before_due"
  @HiveField(3)
  String kind;

  /// Whether the notification has already been sent
  @HiveField(4)
  bool fired;

  /// flutter_local_notifications stable int ID
  @HiveField(5)
  int localNotificationId;

  /// How many minutes before fireAt the Live Activity/countdown should start
  @HiveField(6)
  int liveActivityWindowMinutes;

  TriggerModel({
    required this.triggerId,
    required this.fireAt,
    required this.label,
    required this.kind,
    this.fired = false,
    required this.localNotificationId,
    this.liveActivityWindowMinutes = 30,
  });

  TriggerModel copyWith({
    DateTime? fireAt,
    String? label,
    bool? fired,
    int? localNotificationId,
  }) {
    return TriggerModel(
      triggerId: triggerId,
      fireAt: fireAt ?? this.fireAt,
      label: label ?? this.label,
      kind: kind,
      fired: fired ?? this.fired,
      localNotificationId: localNotificationId ?? this.localNotificationId,
      liveActivityWindowMinutes: liveActivityWindowMinutes,
    );
  }
}
