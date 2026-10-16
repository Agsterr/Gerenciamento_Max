import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_core/salao_core.dart';

void main() {
  test('ícone do serviço pelo nome', () {
    expect(ServiceIcon.iconFor('Corte feminino'), Icons.content_cut);
    expect(ServiceIcon.iconFor('Coloração'), Icons.palette_outlined);
    expect(ServiceIcon.iconFor('Manicure'), Icons.back_hand_outlined);
    expect(ServiceIcon.iconFor('Escova modelada'), Icons.air);
    expect(ServiceIcon.iconFor('Design de sobrancelha'), Icons.remove_red_eye_outlined);
  });

  test('iniciais do avatar', () {
    expect(InitialsAvatar.initials('Ana Souza'), 'AS');
    expect(InitialsAvatar.initials('Studio Bella Moema'), 'SM');
    expect(InitialsAvatar.initials('Bruno'), 'B');
  });
}
