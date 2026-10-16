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
    final link = TextStyle(color: Brand.rose, fontWeight: FontWeight.w700, decoration: TextDecoration.underline);
    return Scaffold(
      backgroundColor: Brand.nightDeep,
      body: Container(
        decoration: const BoxDecoration(gradient: Brand.nightGradient),
        child: Stack(children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Brand.rose.withValues(alpha: 0.55), Brand.rose.withValues(alpha: 0)]),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [BoxShadow(color: Brand.rose.withValues(alpha: 0.45), blurRadius: 40, offset: const Offset(0, 12))],
                        ),
                        child: ClipRRect(borderRadius: BorderRadius.circular(26), child: Image.asset('assets/icon.png', width: 92, height: 92)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Salão Max Gestão',
                        textAlign: TextAlign.center, style: text.headlineMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(_register ? 'Crie seu salão em 1 minuto' : 'Agenda, clientes e lucro na palma da mão',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.75))),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, 20))],
                      ),
                      child: Form(
                        key: _form,
                        child: AutofillGroup(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text(_register ? 'Cadastre seu salão' : 'Entre na sua conta', style: text.titleLarge),
                            const SizedBox(height: 16),
                            if (_register) ...[
                              TextFormField(
                                controller: _salonName,
                                decoration: const InputDecoration(labelText: 'Nome do salão', prefixIcon: Icon(Icons.storefront_outlined)),
                                validator: _required,
                                onChanged: (v) => _slug.text = _toSlug(v),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _slug,
                                decoration: const InputDecoration(
                                  labelText: 'Endereço de agendamento',
                                  prefixIcon: Icon(Icons.link_rounded),
                                  helperText: 'Usado no link que você envia aos clientes',
                                ),
                                validator: (v) =>
                                    RegExp(r'^[a-z0-9-]{3,60}$').hasMatch(v ?? '') ? null : 'Letras minúsculas, números e hífen',
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _ownerName,
                                decoration: const InputDecoration(labelText: 'Seu nome', prefixIcon: Icon(Icons.person_outline_rounded)),
                                autofillHints: const [AutofillHints.name],
                                validator: _required,
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _email,
                              decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline_rounded)),
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              validator: _required,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock_outline_rounded)),
                              obscureText: true,
                              autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                              validator: (v) => (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 20),
                            GradientButton(
                              label: _register ? 'Criar salão' : 'Entrar',
                              icon: _register ? Icons.rocket_launch_outlined : Icons.login_rounded,
                              loading: _busy,
                              onPressed: _submit,
                            ),
                            if (_register) ...[
                              const SizedBox(height: 12),
                              Text.rich(
                                TextSpan(text: 'Ao criar a conta você aceita os ', children: [
                                  WidgetSpan(child: GestureDetector(onTap: () => openUrl(AppConfig.termsUrl), child: Text('Termos', style: link))),
                                  const TextSpan(text: ' e a '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                        onTap: () => openUrl(AppConfig.privacyUrl), child: Text('Política de Privacidade', style: link)),
                                  ),
                                  const TextSpan(text: '.'),
                                ]),
                                style: text.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: () => setState(() => _register = !_register),
                      child: Text(_register ? 'Já tenho conta' : 'Novo por aqui? Cadastre seu salão'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      onPressed: () => openUrl(AppConfig.privacyUrl),
                      child: const Text('Política de Privacidade'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
