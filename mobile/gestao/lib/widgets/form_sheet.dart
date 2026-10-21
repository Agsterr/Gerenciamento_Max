import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

enum FieldKind { text, number, decimal, phone, email, toggle, choices }

class FieldSpec {
  const FieldSpec(this.key, this.label,
      {this.kind = FieldKind.text, this.required = false, this.hint, this.suggestions = const [], this.loadOptions, this.emptyHint});

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final String? hint;

  /// Atalhos para preencher o texto (ex.: categorias comuns).
  final List<String> suggestions;

  /// [FieldKind.choices]: carrega as opções (id → nome); o valor salvo é a lista de ids marcados.
  final Future<Map<int, String>> Function()? loadOptions;

  /// [FieldKind.choices]: explicação mostrada abaixo das opções.
  final String? emptyHint;
}

/// Formulário genérico em bottom sheet para os cadastros simples.
/// [onSave] recebe os valores convertidos (números como num, toggles como bool).
Future<bool> showFormSheet(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required Map<String, Object?> initial,
  required Future<void> Function(Map<String, Object?> values) onSave,
  /// Conteúdo extra (ex.: fotos) logo acima do botão Salvar.
  Widget? extra,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormSheet(title: title, fields: fields, initial: initial, onSave: onSave, extra: extra),
  );
  return saved ?? false;
}

class _FormSheet extends StatefulWidget {
  const _FormSheet({required this.title, required this.fields, required this.initial, required this.onSave, this.extra});

  final Widget? extra;

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
      if (f.kind != FieldKind.toggle && f.kind != FieldKind.choices) f.key: TextEditingController(text: _initialText(widget.initial[f.key])),
  };
  late final Map<String, bool> _toggles = {
    for (final f in widget.fields)
      if (f.kind == FieldKind.toggle) f.key: (widget.initial[f.key] as bool?) ?? true,
  };
  late final Map<String, Set<int>> _chosen = {
    for (final f in widget.fields)
      if (f.kind == FieldKind.choices) f.key: {for (final id in (widget.initial[f.key] as List?) ?? const []) id as int},
  };
  final Map<String, Map<int, String>> _options = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields.where((f) => f.kind == FieldKind.choices)) {
      f.loadOptions?.call().then((o) {
        if (mounted) setState(() => _options[f.key] = o);
      }).catchError((Object _) {});
    }
  }

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
    final values = <String, Object?>{..._toggles, for (final e in _chosen.entries) e.key: e.value.toList()..sort()};
    for (final f in widget.fields.where((f) => f.kind != FieldKind.toggle && f.kind != FieldKind.choices)) {
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

  Widget _choices(FieldSpec f) {
    final options = _options[f.key];
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(f.label, style: text.titleSmall),
      const SizedBox(height: 6),
      if (options == null)
        const LinearProgressIndicator()
      else
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final o in options.entries)
            FilterChip(
              label: Text(o.value),
              selected: _chosen[f.key]!.contains(o.key),
              onSelected: (v) => setState(() => v ? _chosen[f.key]!.add(o.key) : _chosen[f.key]!.remove(o.key)),
            ),
        ]),
      if (f.emptyHint != null) Text(f.emptyHint!, style: text.bodySmall?.copyWith(color: Brand.muted)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: sheetBottomInset(context) + 16),
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
                else if (f.kind == FieldKind.choices)
                  _choices(f)
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
                if (f.suggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 6, children: [
                      for (final s in f.suggestions)
                        ActionChip(label: Text(s), onPressed: () => setState(() => _text[f.key]!.text = s)),
                    ]),
                  ),
                const SizedBox(height: 12),
              ],
              if (widget.extra != null) ...[widget.extra!, const SizedBox(height: 16)],
              GradientButton(label: 'Salvar', icon: Icons.check_rounded, loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
