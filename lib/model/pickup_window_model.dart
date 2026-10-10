import 'package:intl/intl.dart';

/// A store's pickup window. The API sends instants as ISO-8601 UTC strings.
class PickupWindowModel {
  final DateTime start;
  final DateTime end;

  const PickupWindowModel({required this.start, required this.end});

  factory PickupWindowModel.fromJson(Map<String, dynamic> json) {
    return PickupWindowModel(
      start: DateTime.parse(json['start'] as String? ?? ''),
      end: DateTime.parse(json['end'] as String? ?? ''),
    );
  }

  /// Human readable label, e.g. "17:30 – 21:00", in the phone's time zone.
  /// [start] and [end] stay in UTC; they are converted only here, for display.
  String get label {
    final format = DateFormat('HH:mm');
    return '${format.format(start.toLocal())} – ${format.format(end.toLocal())}';
  }

  /// Whether pickup starts today, by the phone's calendar.
  bool get isToday => isTodayAt(DateTime.now());

  /// Same as [isToday], but with "now" passed in so tests can fix the clock.
  bool isTodayAt(DateTime now) {
    final localStart = start.toLocal();
    final localNow = now.toLocal();
    return localStart.year == localNow.year &&
        localStart.month == localNow.month &&
        localStart.day == localNow.day;
  }

  /// Whether the store is currently accepting pickups.
  bool get isOpenNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  Duration get untilStart => start.difference(DateTime.now());
}
