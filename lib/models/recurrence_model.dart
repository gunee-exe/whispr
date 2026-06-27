import 'package:hive/hive.dart';

part 'recurrence_model.g.dart';

@HiveType(typeId: 2)
class RecurrenceModel extends HiveObject {
  /// "daily" | "weekly" | "custom_days"
  @HiveField(0)
  String type;

  /// 0=Sun…6=Sat
  @HiveField(1)
  List<int>? daysOfWeek;

  /// "HH:MM" 24hr format
  @HiveField(2)
  List<String> timesOfDay;

  /// Null means "repeats indefinitely"
  @HiveField(3)
  DateTime? endDate;

  RecurrenceModel({
    required this.type,
    this.daysOfWeek,
    required this.timesOfDay,
    this.endDate,
  });
}
