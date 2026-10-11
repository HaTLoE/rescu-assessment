/// Formats the time left on a countdown: `mm:ss`, or `hh:mm:ss` from one hour
/// up. Never shows a negative time.
///
/// A part of a second is rounded UP, so `00:00` is only shown when the time
/// is really over (0.4 s left still reads `00:01`).
String formatCountdown(Duration remaining) {
  if (remaining.isNegative) return '00:00';

  final totalSeconds =
      (remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  final minutesAndSeconds = '${twoDigits(minutes)}:${twoDigits(seconds)}';
  return hours > 0
      ? '${twoDigits(hours)}:$minutesAndSeconds'
      : minutesAndSeconds;
}
