import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

enum FieldKind { text, number, decimal, phone, email, toggle }

class FieldSpec {
  const FieldSpec(this.key, this.label, {this.kind = FieldKind.text, this.required = false, this.hint});

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final String? hint;
}

/// Formulário genérico em bottom sheet para os cadastros simples.
/// [onSave] recebe os valores convertidos (números como num, toggles como bool).
Future<bool> showFormSheet(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required Map<String, Object?> initial,
  required Future<void> Function(Map<String, Object?> values) onSave,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormSheet(title: title, fields: fields, initial: initial, onSave: onSave),
  );
  return saved ?? false;
}

class _FormSheet extends StatefulWidget {
  const _FormSheet({required this.title, required this.fields, required this.initial, required this.onSave});

  final String title;
  final List<FieldSpec> fields;
  final Map<String, Object?> initial;
  final Future<void> Function(Map<String, Object?>) onSave;

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _text = {
    for (final f in widget.fields)
      if (f.kind != FieldKind.toggle) f.key: TextEditingController(text: _initialText(widget.initial[f.key])),
  };
  late final Map<String, bool> _toggles = {
    for (final f in widget.fields)
      if (f.kind == FieldKind.toggle) f.key: (widget.initial[f.key] as bool?) ?? true,
  };
  bool _busy = false;

  static String _initialText(Object? v) => v == null ? '' : (v is num ? formatQuantity(v) : v.toString());

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final values = <String, Object?>{..._toggles};
    for (final f in widget.fields.where((f) => f.kind != FieldKind.toggle)) {
      final raw = _text[f.key]!.text.trim();
      values[f.key] = switch (f.kind) {
        FieldKind.number || FieldKind.decimal => num.tryParse(raw.replaceAll(',', '.')) ?? 0,
        _ => raw.isEmpty ? null : raw,
      };
    }
    setState(() => _busy = true);
    try {
      await widget.onSave(values);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              for (final f in widget.fields) ...[
                if (f.kind == FieldKind.toggle)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.label),
                    value: _toggles[f.key]!,
                    onChanged: (v) => setState(() => _toggles[f.key] = v),
                  )
                else
                  TextFormField(
                    controller: _text[f.key],
                    decoration: InputDecoration(labelText: f.label, hintText: f.hint),
                    keyboardType: switch (f.kind) {
                      FieldKind.number => TextInputType.number,
                      FieldKind.decimal => const TextInputType.numberWithOptions(decimal: true),
                      FieldKind.phone => TextInputType.phone,
                      FieldKind.email => TextInputType.emailAddress,
                      _ => TextInputType.text,
                    },
                    validator: (v) => f.required && (v ?? '').trim().isEmpty ? 'Obrigatório' : null,
                  ),
                const SizedBox(height: 12),
              ],
              FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Salvando...' : 'Salvar')),
            ],
          ),
        ),
      ),
    );
  }
}
