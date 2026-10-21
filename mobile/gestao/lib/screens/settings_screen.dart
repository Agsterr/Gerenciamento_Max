import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import '../widgets/weekly_hours_editor.dart';
import 'my_reminders_screen.dart';
import 'portfolio_screen.dart';
import 'promotions_screen.dart';
import 'reminders_screen.dart';
import 'subscribe_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.session});

  final Session session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Salon? _salon;
  String? _error;
  PlanInfo? _plan;

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
      PlanInfo? plan;
      if (_session.user.isOwner && AppConfig.storeBuild) {
        plan = PlanInfo.fromJson(await _session.api.get('/api/salon/plan') as Map<String, dynamic>);
      }
      if (mounted) {
        setState(() {
          _salon = s;
          _plan = plan;
        });
      }
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

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

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
          PasswordFormField(controller: password, label: 'Confirme sua senha', showIcon: false),
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
                    Text('Cada dia pode ter um horário diferente e uma pausa, como o almoço. '
                        'Nas pausas e nos dias fechados ninguém consegue agendar online.',
                        style: text.bodySmall?.copyWith(color: Brand.muted)),
                    const SizedBox(height: 12),
                    WeeklyHoursEditor(hours: salon.hours, onChanged: (h) => setState(() => salon.hours = h)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: Salon.timezones.containsKey(salon.timezone) ? salon.timezone : 'America/Sao_Paulo',
                      decoration: const InputDecoration(labelText: 'Fuso horário do salão', prefixIcon: Icon(Icons.public_rounded)),
                      items: [for (final z in Salon.timezones.entries) DropdownMenuItem(value: z.key, child: Text(z.value))],
                      onChanged: (v) => setState(() => salon.timezone = v!),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: salon.slotMinutes,
                      decoration: const InputDecoration(labelText: 'Intervalo entre horários', prefixIcon: Icon(Icons.timelapse_rounded)),
                      items: [for (final m in [10, 15, 20, 30, 45, 60]) DropdownMenuItem(value: m, child: Text('$m min'))],
                      onChanged: (v) => setState(() => salon.slotMinutes = v!),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ReminderMode>(
                      isExpanded: true,
                      initialValue: salon.reminderMode,
                      decoration: const InputDecoration(
                        labelText: 'Lembrete para o cliente confirmar',
                        prefixIcon: Icon(Icons.notifications_active_outlined),
                      ),
                      items: [for (final m in ReminderMode.values) DropdownMenuItem(value: m, child: Text(m.label))],
                      onChanged: (v) => setState(() => salon.reminderMode = v!),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Liberar a vaga quando o cliente cancelar'),
                      subtitle: Text(
                        salon.releaseSlotOnCancel
                            ? 'O horário volta para a agenda e outra pessoa pode marcar.'
                            : 'O horário continua bloqueado e você só recebe o aviso.',
                        style: text.bodySmall?.copyWith(color: Brand.muted),
                      ),
                      value: salon.releaseSlotOnCancel,
                      onChanged: (v) => setState(() => salon.releaseSlotOnCancel = v),
                    ),
                    const SizedBox(height: 8),
                    GradientButton(label: 'Salvar funcionamento', icon: Icons.save_outlined, onPressed: salon.hours.isEmpty ? null : _saveSalon),
                  ]),
                ),
              ],
              const SectionTitle('Lembretes, portfólio e promoções'),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  tile(Icons.mark_chat_read_outlined, 'Lembretes dos clientes', () => _open(RemindersScreen(api: _session.api))),
                  tile(Icons.alarm_rounded, 'Meus lembretes de atendimento', () => _open(MyRemindersScreen(api: _session.api))),
                  tile(Icons.photo_library_outlined, 'Portfólio de fotos', () => _open(PortfolioScreen(api: _session.api))),
                  tile(Icons.local_offer_outlined, 'Pacotes e promoções', () => _open(PromotionsScreen(session: _session))),
                ]),
              ),
              if (_plan != null && (_plan!.billingAvailable || _plan!.managedByPlay)) ...[
                const SectionTitle('Assinatura'),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _plan!.managedByPlay
                      ? tile(Icons.manage_accounts_outlined, 'Gerenciar assinatura na Google Play',
                          () => openUrl(Uri.parse('https://play.google.com/store/account/subscriptions')))
                      : tile(Icons.workspace_premium_outlined, 'Assinar o plano completo', () async {
                          final ok = await Navigator.push<bool>(context,
                              MaterialPageRoute(builder: (_) => SubscribeScreen(session: _session, plan: _plan!)));
                          if (ok == true) _load();
                        }),
                ),
              ],
              const SectionTitle('Conta'),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  tile(Icons.privacy_tip_outlined, 'Política de Privacidade', () => openUrl(AppConfig.privacyUrl)),
                  tile(Icons.description_outlined, 'Termos de Uso', () => openUrl(AppConfig.termsUrl)),
                  const AppVersionTile(app: 'gestao'),
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
