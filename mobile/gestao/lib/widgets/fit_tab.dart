import 'package:flutter/material.dart';

/// Aba cujo nome encolhe em vez de ser cortado quando a fonte do sistema é grande.
class FitTab extends StatelessWidget implements PreferredSizeWidget {
  const FitTab(this.label, {super.key});

  final String label;

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) => Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)));
}
