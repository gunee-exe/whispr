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
  /// Always stored as an absolute timestamp, never a relative expression.
  @HiveField(1)
  DateTime fireAt;

  /// Human-readable description shown in UI, e.g. "1 day before" or "2:00 PM"
  @HiveField(2)
  String label;

  /// "fixed_time" | "offset_before_due" — informational, for display logic only.
  @HiveField(3)
  String kind;

  /// Whether the notification has already been sent (prevents duplicate sends).
  @HiveField(4)
  bool fired;

  /// flutter_local_notifications requires a stable int ID per scheduled
  /// notification — generated and stored at creation so it can be
  /// cancelled/rescheduled by reference.
  @HiveField(5)
  int localNotificationId;

  /// How many minutes before fireAt the Live Activity/countdown should start.
  /// Computed at creation time (Section 7.3 of the implementation plan).
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
}
