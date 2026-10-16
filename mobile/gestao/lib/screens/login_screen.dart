import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final Session session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _salonName = TextEditingController();
  final _slug = TextEditingController();
  final _ownerName = TextEditingController();
  bool _register = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_email, _password, _salonName, _slug, _ownerName]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _toSlug(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    var out = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    out = out.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return out.length > 60 ? out.substring(0, 60) : out;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_register) {
        await widget.session.register({
          'salonName': _salonName.text.trim(),
          'slug': _slug.text.trim(),
          'ownerName': _ownerName.text.trim(),
          'email': _email.text.trim(),
          'password': _password.text,
        });
      } else {
        await widget.session.login(_email.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Obrigatório' : null;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Salão Max Gestão',
                          style: text.headlineSmall?.copyWith(color: AppTheme.seed, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_register ? 'Cadastre seu salão' : 'Entre na sua conta', style: text.titleMedium),
                      const SizedBox(height: 24),
                      if (_register) ...[
                        TextFormField(
                          controller: _salonName,
                          decoration: const InputDecoration(labelText: 'Nome do salão'),
                          validator: _required,
                          onChanged: (v) => _slug.text = _toSlug(v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _slug,
                          decoration: const InputDecoration(
                              labelText: 'Endereço de agendamento', helperText: 'Usado no link que você envia aos clientes'),
                          validator: (v) => RegExp(r'^[a-z0-9-]{3,60}$').hasMatch(v ?? '') ? null : 'Letras minúsculas, números e hífen',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _ownerName,
                          decoration: const InputDecoration(labelText: 'Seu nome'),
                          autofillHints: const [AutofillHints.name],
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(labelText: 'Senha'),
                        obscureText: true,
                        autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                        validator: (v) => (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Aguarde...' : (_register ? 'Criar salão' : 'Entrar')),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _register = !_register),
                        child: Text(_register ? 'Já tenho conta' : 'Novo por aqui? Cadastre seu salão'),
                      ),
                      if (_register)
                        Text.rich(
                          TextSpan(text: 'Ao criar a conta você aceita os ', children: [
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => openUrl(AppConfig.termsUrl),
                                child: Text('Termos', style: TextStyle(color: AppTheme.seed, decoration: TextDecoration.underline)),
                              ),
                            ),
                            const TextSpan(text: ' e a '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => openUrl(AppConfig.privacyUrl),
                                child: Text('Política de Privacidade',
                                    style: TextStyle(color: AppTheme.seed, decoration: TextDecoration.underline)),
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ]),
                          style: text.bodySmall,
                          textAlign: TextAlign.center,
                        )
                      else
                        TextButton(onPressed: () => openUrl(AppConfig.privacyUrl), child: const Text('Política de Privacidade')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
