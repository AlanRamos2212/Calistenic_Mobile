/// Formats [value] as a Spanish relative time ("hace 5 min", "hace 2 h", ...).
class RelativeTime {
  RelativeTime._();

  static String format(DateTime? value) {
    if (value == null) return '';
    final diff = DateTime.now().difference(value.toLocal());
    if (diff.inSeconds < 45) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      return 'hace ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}';
    }
    if (diff.inDays < 7) {
      return 'hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
    }
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'hace $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return 'hace $months ${months == 1 ? 'mes' : 'meses'}';
    }
    final years = (diff.inDays / 365).floor();
    return 'hace $years ${years == 1 ? 'año' : 'años'}';
  }
}
