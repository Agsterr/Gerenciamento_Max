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
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(_session.user.name),
            subtitle: Text('${_session.user.email} · ${owner ? 'Dono' : 'Funcionário'}'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Link de agendamento online'),
            subtitle: Text(_publicLink),
            trailing: IconButton(
              tooltip: 'Copiar link',
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _publicLink));
                if (context.mounted) showMessage(context, 'Link copiado. Compartilhe no WhatsApp e Instagram!');
              },
            ),
          ),
          if (_error != null) ListTile(title: Text(_error!)),
          if (owner && salon != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Funcionamento', style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              title: const Text('Horário'),
              subtitle: Text('${salon.openTime} às ${salon.closeTime} · intervalo de ${salon.slotMinutes} min'),
              trailing: Wrap(children: [
                TextButton(onPressed: () => _pickTime(true), child: const Text('Abre')),
                TextButton(onPressed: () => _pickTime(false), child: const Text('Fecha')),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final d in _weekdays.entries)
                  FilterChip(
                    label: Text(d.value),
                    selected: salon.workDays.contains(d.key),
                    onSelected: (v) => setState(() => v ? salon.workDays.add(d.key) : salon.workDays.remove(d.key)),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<int>(
                initialValue: salon.slotMinutes,
                decoration: const InputDecoration(labelText: 'Intervalo entre horários'),
                items: [for (final m in [10, 15, 20, 30, 45, 60]) DropdownMenuItem(value: m, child: Text('$m min'))],
                onChanged: (v) => setState(() => salon.slotMinutes = v!),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(onPressed: salon.workDays.isEmpty ? null : _saveSalon, child: const Text('Salvar funcionamento')),
            ),
          ],
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de Privacidade'),
            onTap: () => openUrl(AppConfig.privacyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Termos de Uso'),
            onTap: () => openUrl(AppConfig.termsUrl),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: _session.signOut,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text('Excluir conta', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
