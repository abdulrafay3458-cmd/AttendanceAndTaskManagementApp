// lib/utils/app_date.dart
//
// One place for date/time handling in the app. Rules:
//   - The API sends instants as UTC: parse them as UTC, show them with .toLocal().
//   - If the API sends a timestamp with NO zone ("Z" / +hh:mm), it is the server's local wall-clock time:
//     convert it to UTC using [AppDate.serverOffset].
//   - The API decides business days ("work date"): send it back as-is, never derive it from DateTime.now().
//   - For anything compared against server time (countdowns, running timers) use ServerClock, not DateTime.now().
import 'package:intl/intl.dart';

class AppDate {
  AppDate._();

  /// Offset of the time zone the server uses when it writes timestamps WITHOUT "Z" / offset.
  /// Pakistan = UTC+5. Change this one constant if the server uses a different zone.
  static const Duration serverOffset = Duration(hours: 5);

  /// Parses an API timestamp into a true UTC instant.
  ///  - Has "Z" or +hh:mm  -> unambiguous, used as-is.
  ///  - Has no zone        -> server sent its LOCAL wall-clock time, so [serverOffset] is subtracted.
  static DateTime parseUtc(String s) {
    final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(s);
    if (hasZone) return DateTime.parse(s).toUtc();

    final p = DateTime.parse(s); // only the date/time components are used here
    return DateTime.utc(
      p.year,
      p.month,
      p.day,
      p.hour,
      p.minute,
      p.second,
      p.millisecond,
      p.microsecond,
    ).subtract(serverOffset);
  }

  static DateTime? tryParseUtc(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    try {
      return parseUtc(v);
    } catch (_) {
      return null;
    }
  }

  /// UTC instant -> phone's local time (works even if [t] was built without the UTC flag).
  static DateTime toLocal(DateTime t) =>
      (t.isUtc ? t : DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond)).toLocal();

  // ---- display (input = UTC instant from the API) ----
  /// Any pattern, null-safe: returns [fallback] when the value is missing.
  ///   AppDate.format(AppDate.tryParseUtc(json['createdAt']), 'MMM dd, yyyy hh:mm a')
  static String format(DateTime? utc, String pattern, {String fallback = '-'}) =>
      utc == null ? fallback : DateFormat(pattern).format(toLocal(utc));

  static String time(DateTime? utc) => utc == null ? '--:--' : DateFormat('hh:mm a').format(toLocal(utc));
  static String date(DateTime? utc) => utc == null ? '-' : DateFormat('dd MMM yyyy').format(toLocal(utc));
  static String dateTime(DateTime? utc) =>
      utc == null ? '-' : DateFormat('dd MMM, hh:mm a').format(toLocal(utc));

  /// yyyy-MM-dd for a calendar day the USER picked (e.g. the date strip). Not for server work dates.
  static String apiDate(DateTime localDay) => DateFormat('yyyy-MM-dd').format(localDay);

  /// hh:mm:ss for timers.
  static String clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

/// Server-synchronised clock. Call sync() whenever an API response carries "serverNow"
/// (replaces the global _serverOffset / calculateOffset in dashboard.dart).
class ServerClock {
  ServerClock._();
  static Duration _offset = Duration.zero;

  static void sync(DateTime serverNowUtc) {
    _offset = serverNowUtc.difference(DateTime.now().toUtc());
  }

  static DateTime get nowUtc => DateTime.now().toUtc().add(_offset);
  static DateTime get nowLocal => nowUtc.toLocal();
}