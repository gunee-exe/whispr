import 'package:hive/hive.dart';

part 'recurrence_model.g.dart';

@HiveType(typeId: 2)
class RecurrenceModel extends HiveObject {
  /// "daily" | "weekly" | "custom_days"
  @HiveField(0)
  String type;

  /// 0=Sun…6=Sat, only used if type = "custom_days" or "weekly"
  @HiveField(1)
  List<int>? daysOfWeek;

  /// "HH:MM" 24hr format — e.g. ["14:00","17:00"] for medicine at 2pm and 5pm
  @HiveField(2)
  List<String> timesOfDay;

  /// Null means "repeats indefinitely until cancelled"
  @HiveField(3)
  DateTime? endDate;

  RecurrenceModel({
    required this.type,
    this.daysOfWeek,
    required this.timesOfDay,
    this.endDate,
  });
}
