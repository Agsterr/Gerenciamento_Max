import 'package:flutter/material.dart';

/// Campo de senha com o "olhinho" para mostrar/esconder o que foi digitado.
class PasswordFormField extends StatefulWidget {
  const PasswordFormField({
    super.key,
    required this.controller,
    this.label = 'Senha',
    this.validator,
    this.autofillHints,
    this.onFieldSubmitted,
    this.textInputAction,
    this.showIcon = true,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final bool showIcon;

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: !_visible,
        enableSuggestions: false,
        autocorrect: false,
        autofillHints: widget.autofillHints,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: widget.showIcon ? const Icon(Icons.lock_outline_rounded) : null,
          suffixIcon: IconButton(
            tooltip: _visible ? 'Esconder senha' : 'Mostrar senha',
            icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ),
      );
}
