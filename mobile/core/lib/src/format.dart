import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

final _money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _date = DateFormat('dd/MM/yyyy', 'pt_BR');
final _time = DateFormat('HH:mm', 'pt_BR');
final _weekday = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');
final _weekdayShort = DateFormat('EEE', 'pt_BR');

String formatMoney(num value) => _money.format(value);

String formatDate(DateTime d) => _date.format(d);

String formatTime(DateTime d) => _time.format(d);

String formatWeekday(DateTime d) {
  final s = _weekday.format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String formatWeekdayShort(DateTime d) => _weekdayShort.format(d).replaceAll('.', '');

/// yyyy-MM-dd (formato da API).
String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String formatPhone(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11) return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  if (d.length == 10) return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  return phone;
}

String formatQuantity(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Abre conversa no WhatsApp (número brasileiro).
/// [text] vira a mensagem já digitada na conversa.
Future<void> openWhatsApp(String phone, {String? text}) async {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final query = text == null ? '' : '?text=${Uri.encodeComponent(text)}';
  await launchUrl(Uri.parse('https://wa.me/55$digits$query'), mode: LaunchMode.externalApplication);
}

/// "Ter, 20/10 às 14:30"
String formatShortDateTime(DateTime d) {
  final day = DateFormat("EEE, dd/MM", 'pt_BR').format(d).replaceAll('.', '');
  return '${day[0].toUpperCase()}${day.substring(1)} às ${formatTime(d)}';
}

Future<void> openUrl(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

String formatMonthShort(DateTime d) => DateFormat('MMM', 'pt_BR').format(d).replaceAll('.', '');

/// Saudação pelo horário do dia.
String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  return h < 12 ? 'Bom dia' : (h < 18 ? 'Boa tarde' : 'Boa noite');
}
