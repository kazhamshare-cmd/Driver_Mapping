/// 時間スロット計算ユーティリティ（ガントチャート用）
class TimeSlotUtils {
  /// 時間スロットを生成（例：10:00〜23:00、30分刻み）
  static List<String> generateTimeSlots({
    String startTime = '10:00',
    String endTime = '23:00',
    int intervalMinutes = 30,
  }) {
    final slots = <String>[];
    var current = parseTime(startTime);
    final end = parseTime(endTime);

    while (current <= end) {
      slots.add(formatTime(current));
      current += intervalMinutes;
    }

    return slots;
  }

  /// "HH:MM" を深夜0時からの分数に変換
  static int parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// 深夜0時からの分数を "HH:MM" に変換
  static String formatTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 予約のスロット数を計算
  static int calculateSlotSpan(String start, String end, int intervalMinutes) {
    final startMin = parseTime(start);
    final endMin = parseTime(end);
    return ((endMin - startMin) / intervalMinutes).ceil();
  }

  /// 時間からスロットインデックスを取得
  static int getSlotIndex(String time, String firstSlotTime, int intervalMinutes) {
    final timeMin = parseTime(time);
    final firstMin = parseTime(firstSlotTime);
    return ((timeMin - firstMin) / intervalMinutes).floor();
  }
}
