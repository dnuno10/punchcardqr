import 'package:intl/intl.dart';

String fmtDate(String iso) => DateFormat.MMMd().add_jm().format(DateTime.parse(iso).toLocal());
String fmtDay(String iso) => DateFormat.MMMd().format(DateTime.parse(iso).toLocal());

String timeAgo(String iso) {
  final d = DateTime.now().difference(DateTime.parse(iso));
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

String customerLabel(Map c) {
  final name = (c['first_name'] as String?)?.trim();
  return name != null && name.isNotEmpty ? name : 'Customer #${c['customer_number']}';
}
