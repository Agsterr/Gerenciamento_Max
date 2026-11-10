import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import '../shop/purchases_screen.dart';
import '../shop/shop_access.dart';
import '../shop/shop_screen.dart';
import '../widgets/booking_link_card.dart';
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
  late final ShopAccess _shop = ShopAccess(widget.session);
  String get _publicLink => '${AppConfig.siteUrl}/s/${_session.user.salonSlug}';

  @override
  void initState() {
    super.initState();
    _load();
    // a loja só aparece para salões com vendedor (ou convite); quem veio direto da Play não vê nada disso
    _shop.addListener(_shopChanged);
    _shop.load();
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

  void _shopChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shop.removeListener(_shopChanged);
    _shop.dispose();
    super.dispose();
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
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
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

    Widget tile(IconData icon, String title, VoidCallback onTap, {Color? color, String? subtitle, Widget? trailing}) => ListTile(
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
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
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
                decoration: BoxDecoration(gradient: Brand.gradient, shape: BoxShape.circle),
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
              BookingLinkCard(link: _publicLink),
              if (owner && _shop.visible) ...[
                const SectionTitle('Loja dos vendedores'),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    tile(
                      Icons.storefront_outlined,
                      'Produtos dos vendedores',
                      () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(session: _session, onChanged: _shop.refresh)));
                        _shop.refresh();
                      },
                      subtitle: _shop.pendingInvites > 0
                          ? (_shop.pendingInvites == 1 ? '1 convite esperando resposta' : '${_shop.pendingInvites} convites esperando resposta')
                          : null,
                      trailing: _shop.pendingInvites > 0
                          ? Badge(label: Text('${_shop.pendingInvites}'), child: const Icon(Icons.chevron_right_rounded))
                          : null,
                    ),
                    if (_shop.hasVendor)
                      tile(Icons.receipt_long_outlined, 'Minhas compras', () => _open(PurchasesScreen(session: _session))),
                  ]),
                ),
              ],
              const SectionTitle('Cor do aplicativo'),
              SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Escolha a cor que combina com você. Muda o app todo e o ícone.',
                      style: text.bodySmall?.copyWith(color: Brand.muted)),
                  const SizedBox(height: 14),
                  const ThemePicker(),
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
                  tile(Icons.logout_rounded, 'Sair', _session.logout),
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
