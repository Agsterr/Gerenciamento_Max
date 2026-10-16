import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.session});

  final Session session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _weekdays = {1: 'Seg', 2: 'Ter', 3: 'Qua', 4: 'Qui', 5: 'Sex', 6: 'Sáb', 7: 'Dom'};

  Salon? _salon;
  String? _error;

  Session get _session => widget.session;
  String get _publicLink => '${AppConfig.siteUrl}/s/${_session.user.salonSlug}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = Salon.fromJson(await _session.api.get('/api/salon') as Map<String, dynamic>);
      if (mounted) setState(() => _salon = s);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _saveSalon() async {
    try {
      await _session.api.put('/api/salon', _salon!.toJson());
      if (mounted) showMessage(context, 'Salvo!');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pickTime(bool open) async {
    final current = (open ? _salon!.openTime : _salon!.closeTime).split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(current[0]), minute: int.parse(current[1])),
    );
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => open ? _salon!.openTime = v : _salon!.closeTime = v);
  }

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conta'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_session.user.isOwner
              ? 'Se você for o último dono, o salão e TODOS os dados (agenda, clientes, produtos e financeiro) '
                  'serão apagados de forma definitiva.'
              : 'Seu acesso ao salão será removido.'),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Confirme sua senha')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir definitivamente'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _session.deleteAccount(password.text);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final salon = _salon;
    final owner = _session.user.isOwner;
    final text = Theme.of(context).textTheme;
    final user = _session.user;

    Widget tile(IconData icon, String title, VoidCallback onTap, {Color? color}) => ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (color ?? Brand.rose).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color ?? Brand.rose, size: 20),
          ),
          title: Text(title, style: text.titleSmall?.copyWith(color: color)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        );

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          GradientHeader(
            gradient: Brand.nightGradient,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(gradient: Brand.gradient, shape: BoxShape.circle),
                child: InitialsAvatar(user.name, size: 60),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: text.titleLarge?.copyWith(color: Colors.white)),
                  Text(user.email, style: text.bodySmall?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Pill(owner ? 'Dono' : 'Funcionário',
                      icon: owner ? Icons.workspace_premium_rounded : Icons.badge_outlined,
                      color: Colors.white.withValues(alpha: 0.15),
                      textColor: Colors.white),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: Brand.gradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Brand.rose.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.link_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Seu link de agendamento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                  const SizedBox(height: 6),
                  Text('Compartilhe no Instagram, WhatsApp e Google. Seus clientes agendam sozinhos.',
                      style: text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                    child: Text(_publicLink, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.rose),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copiar'),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _publicLink));
                          if (context.mounted) showMessage(context, 'Link copiado!');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Brand.whatsapp, foregroundColor: Colors.white),
                        icon: const Icon(Icons.chat_rounded),
                        label: const Text('WhatsApp'),
                        onPressed: () => openUrl(Uri.parse(
                            'https://wa.me/?text=${Uri.encodeComponent('Agende seu horário comigo: $_publicLink')}')),
                      ),
                    ),
                  ]),
                ]),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!)),
              if (owner && salon != null) ...[
                const SectionTitle('Funcionamento'),
                SoftCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: _TimeBox(label: 'Abre', value: salon.openTime, onTap: () => _pickTime(true))),
                      const SizedBox(width: 10),
                      Expanded(child: _TimeBox(label: 'Fecha', value: salon.closeTime, onTap: () => _pickTime(false))),
                    ]),
                    const SizedBox(height: 14),
                    Text('Dias de atendimento', style: text.labelLarge),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final d in _weekdays.entries)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _DayToggle(
                              label: d.value,
                              selected: salon.workDays.contains(d.key),
                              onTap: () => setState(() =>
                                  salon.workDays.contains(d.key) ? salon.workDays.remove(d.key) : salon.workDays.add(d.key)),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: salon.slotMinutes,
                      decoration: const InputDecoration(labelText: 'Intervalo entre horários', prefixIcon: Icon(Icons.timelapse_rounded)),
                      items: [for (final m in [10, 15, 20, 30, 45, 60]) DropdownMenuItem(value: m, child: Text('$m min'))],
                      onChanged: (v) => setState(() => salon.slotMinutes = v!),
                    ),
                    const SizedBox(height: 14),
                    GradientButton(label: 'Salvar funcionamento', icon: Icons.save_outlined, onPressed: salon.workDays.isEmpty ? null : _saveSalon),
                  ]),
                ),
              ],
              const SectionTitle('Conta'),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  tile(Icons.privacy_tip_outlined, 'Política de Privacidade', () => openUrl(AppConfig.privacyUrl)),
                  tile(Icons.description_outlined, 'Termos de Uso', () => openUrl(AppConfig.termsUrl)),
                  tile(Icons.logout_rounded, 'Sair', _session.signOut, color: Brand.muted),
                  tile(Icons.delete_forever_outlined, 'Excluir conta', _deleteAccount, color: Theme.of(context).colorScheme.error),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFFFF1F6),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Brand.muted, fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Brand.ink)),
            ]),
          ),
        ),
      );
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected ? Brand.gradient : null,
              color: selected ? null : const Color(0xFFF6EEF3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : Brand.muted)),
          ),
        ),
      );
}
