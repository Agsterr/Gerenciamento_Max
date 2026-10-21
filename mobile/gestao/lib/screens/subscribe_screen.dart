import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';

/// Assinatura mensal pela Google Play. O app só entrega o token da compra;
/// quem confirma com o Google e libera o plano é o servidor.
class SubscribeScreen extends StatefulWidget {
  const SubscribeScreen({super.key, required this.session, required this.plan});

  final Session session;
  final PlanInfo plan;

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) => _fail(e));
    _loadProduct();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _fail(Object e) {
    if (mounted) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadProduct() async {
    try {
      if (!await _iap.isAvailable()) throw 'A Google Play não está disponível neste aparelho.';
      final res = await _iap.queryProductDetails({widget.plan.playProductId});
      if (res.productDetails.isEmpty) throw 'A assinatura ainda não está disponível na loja. Tente mais tarde.';
      if (mounted) setState(() => _product = res.productDetails.first);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy() async {
    final product = _product;
    if (product == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          if (mounted) setState(() => _busy = true);
        case PurchaseStatus.error:
          _fail(p.error?.message ?? 'Não foi possível concluir a compra.');
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
        case PurchaseStatus.canceled:
          if (mounted) setState(() => _busy = false);
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(p);
      }
    }
  }

  Future<void> _verify(PurchaseDetails p) async {
    try {
      await widget.session.api.post('/api/billing/play/verify', {
        'productId': p.productID,
        'purchaseToken': p.verificationData.serverVerificationData,
      });
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final price = _product?.price;
    return Scaffold(
      appBar: AppBar(title: const Text('Assinar o Salão Max')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (_done) ...[
            const Icon(Icons.check_circle_rounded, size: 72, color: Brand.rose),
            const SizedBox(height: 12),
            Text('Assinatura ativa!', textAlign: TextAlign.center, style: text.headlineSmall),
            const SizedBox(height: 8),
            const Text('Obrigado! Seu plano está liberado, sem limites do teste grátis.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Voltar')),
          ] else ...[
            Text('Plano completo', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(price == null ? 'Mensal' : '$price por mês', style: text.titleLarge?.copyWith(color: Brand.rose)),
            const SizedBox(height: 16),
            const _Benefit('Profissionais, serviços e clientes sem limite'),
            const _Benefit('Agendamento online pelo seu link e pelo app do cliente'),
            const _Benefit('Financeiro, estoque, lembretes e portfólio de fotos'),
            const _Benefit('Cancele quando quiser, direto na Google Play'),
            const SizedBox(height: 20),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!)),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              GradientButton(
                label: _busy ? 'Aguarde...' : 'Assinar',
                icon: Icons.workspace_premium_outlined,
                onPressed: _busy || _product == null ? null : _buy,
              ),
            const SizedBox(height: 12),
            Text(
              'A cobrança é feita pela sua conta Google e renova todo mês até você cancelar em '
              'Play Store › Pagamentos e assinaturas › Assinaturas.',
              style: text.bodySmall?.copyWith(color: Brand.muted),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_rounded, color: Brand.rose, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ]),
      );
}
