import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:salao_core/salao_core.dart';

/// Nome e telefone escolhidos na agenda do celular.
typedef PickedContact = ({String? name, String? phone});

/// Abre a agenda de contatos do próprio celular (seletor do sistema) e devolve o contato escolhido.
/// Não pede a permissão "ler contatos": o app só recebe o contato que a pessoa tocar.
Future<PickedContact?> pickPhoneContact() async {
  final c = await FlutterNativeContactPicker().selectPhoneNumber();
  if (c == null) return null;
  final phone = c.selectedPhoneNumber ?? c.phoneNumbers?.firstOrNull;
  return (name: c.fullName, phone: phone);
}

/// Telefone do contato no formato do cadastro: só números do Brasil, sem +55, com máscara quando dá.
/// "+55 (11) 98888-7777" → "(11) 98888-7777"; número que não parece brasileiro fica como veio.
String normalizeBrazilianPhone(String raw) {
  // com + e um país que não é o Brasil, deixa como veio (não dá para saber o formato)
  final trimmed = raw.trim();
  if (trimmed.startsWith('+') && !trimmed.startsWith('+55')) return trimmed;
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('55') && digits.length >= 12) digits = digits.substring(2);
  if (digits.length == 11 || digits.length == 10) return formatPhone(digits);
  return raw.trim();
}

/// Botão "Importar da agenda do celular" para o cadastro de cliente: preenche nome e telefone.
/// Os avisos aparecem embaixo do botão (um SnackBar ficaria escondido atrás da folha do formulário).
class ContactPickerButton extends StatefulWidget {
  const ContactPickerButton({super.key, required this.controllers, this.pick = pickPhoneContact});

  /// Controladores do formulário: usa `name` e `phone`.
  final Map<String, TextEditingController> controllers;

  /// Quem escolhe o contato (trocado nos testes).
  final Future<PickedContact?> Function() pick;

  @override
  State<ContactPickerButton> createState() => _ContactPickerButtonState();
}

class _ContactPickerButtonState extends State<ContactPickerButton> {
  String? _note;

  Future<void> _import() async {
    String? note;
    try {
      final contact = await widget.pick();
      if (contact == null) return; // fechou o seletor sem escolher
      final name = contact.name?.trim();
      final phone = contact.phone;
      if (name != null && name.isNotEmpty) widget.controllers['name']?.text = name;
      if (phone != null && phone.trim().isNotEmpty) {
        widget.controllers['phone']?.text = normalizeBrazilianPhone(phone);
      } else {
        note = 'Esse contato não tem telefone. Digite o WhatsApp.';
      }
    } catch (_) {
      note = 'Não foi possível abrir a agenda do celular.';
    }
    if (mounted) setState(() => _note = note);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          OutlinedButton.icon(
            onPressed: _import,
            icon: const Icon(Icons.contacts_rounded),
            label: Text(
              MediaQuery.textScalerOf(context).scale(14) > 17 ? 'Importar da agenda' : 'Importar da agenda do celular',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_note!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Brand.rose)),
            ),
        ]),
      );
}
