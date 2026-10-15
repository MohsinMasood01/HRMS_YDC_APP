/// Parses an instant sent by the LMS backend into a UTC [DateTime].
///
/// The backend is asked to send ISO-8601 with an explicit offset
/// (`2026-09-22T19:00:00+05:00`) or `Z`; those are exact. A naive value
/// (`2026-09-22T19:00:00` or `2026-09-22 19:00:00`) carries no zone and is read
/// as device-local time -- the server and the workforce share a timezone, so
/// that is the least-surprising reading of a legacy value.
///
/// Returns null for anything missing or unparseable, so callers fall back to
/// their own safe default instead of acting on a garbage instant.
DateTime? parseServerInstant(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  // Oracle's TO_CHAR default uses a space instead of the ISO 'T'.
  return DateTime.tryParse(text.replaceFirst(' ', 'T'))?.toUtc();
}
