/// How often the poll surfaces refresh themselves while in the foreground.
///
/// Each case carries the cadence it stands for; [off] carries none — a null
/// duration the poll sites read as "run no timer".
enum RefreshInterval {
  tenSeconds(Duration(seconds: 10)),
  thirtySeconds(Duration(seconds: 30)),
  oneMinute(Duration(seconds: 60)),
  fiveMinutes(Duration(minutes: 5)),
  off(null);

  const RefreshInterval(this.duration);

  final Duration? duration;
}
