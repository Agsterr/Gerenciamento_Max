import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:salao_core/salao_core.dart';

/// Portfólio: fotos dos trabalhos, que aparecem na página de agendamento e no app do cliente.
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key, required this.api, this.picker});

  final ApiClient api;

  /// Substituível nos testes.
  final ImagePicker? picker;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<Photo>? _photos;
  List<ServiceItem> _services = const [];
  List<Professional> _professionals = const [];
  (int, int)? _usage;
  String? _error;
  String? _progress;

  late final ImagePicker _picker = widget.picker ?? ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([
        widget.api.get('/api/portfolio'),
        widget.api.get('/api/services'),
        widget.api.get('/api/professionals'),
      ]);
      if (!mounted) return;
      setState(() {
        _photos = (r[0] as List).map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList();
        _services = (r[1] as List).map((e) => ServiceItem.fromJson(e as Map<String, dynamic>)).toList();
        _professionals = (r[2] as List).map((e) => Professional.fromJson(e as Map<String, dynamic>)).toList();
      });
      _loadUsage();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadUsage() async {
    try {
      final plan = PlanInfo.fromJson(await widget.api.get('/api/salon/plan') as Map<String, dynamic>);
      if (mounted) setState(() => _usage = plan.photos);
    } catch (_) {}
  }

  Future<void> _add(ImageSource source) async {
    final List<XFile> files;
    try {
      // o servidor ainda reduz para 1600px; aqui só evita mandar 10 MB pelo 4G
      files = source == ImageSource.camera
          ? [?await _picker.pickImage(source: source, maxWidth: 2400, imageQuality: 85)]
          : await _picker.pickMultiImage(maxWidth: 2400, imageQuality: 85, limit: 20);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (files.isEmpty) return;
    try {
      for (final (i, f) in files.indexed) {
        setState(() => _progress = 'Enviando ${i + 1} de ${files.length}...');
        await widget.api.upload('/api/portfolio', bytes: await f.readAsBytes(), filename: _jpegName(f.name));
      }
      if (mounted) showMessage(context, files.length == 1 ? 'Foto enviada!' : '${files.length} fotos enviadas!');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _progress = null);
      await _load();
    }
  }

  static String _jpegName(String name) => name.contains('.') ? name : '$name.jpg';

  Future<void> _move(int index, int delta) async {
    final ids = [for (final p in _photos!) p.id];
    final target = index + delta;
    if (target < 0 || target >= ids.length) return;
    final id = ids.removeAt(index);
    ids.insert(target, id);
    try {
      final json = await widget.api.put('/api/portfolio/order', {'ids': ids}) as List;
      if (mounted) setState(() => _photos = json.map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(Photo p) async {
    if (!await confirmDialog(context, 'Apagar esta foto?', confirm: 'Apagar', danger: true)) return;
    try {
      await widget.api.delete('/api/portfolio/${p.id}');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _edit(Photo p) async {
    final caption = TextEditingController(text: p.caption);
    int? serviceId = p.serviceId, professionalId = p.professionalId;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: StatefulBuilder(
          builder: (context, setSheet) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Editar foto', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(controller: caption, maxLength: 200, decoration: const InputDecoration(labelText: 'Legenda')),
            DropdownButtonFormField<int?>(
              initialValue: _services.any((s) => s.id == serviceId) ? serviceId : null,
              decoration: const InputDecoration(labelText: 'Serviço'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Nenhum')),
                for (final s in _services) DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setSheet(() => serviceId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _professionals.any((x) => x.id == professionalId) ? professionalId : null,
              decoration: const InputDecoration(labelText: 'Profissional'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Nenhum')),
                for (final x in _professionals) DropdownMenuItem<int?>(value: x.id, child: Text(x.name)),
              ],
              onChanged: (v) => setSheet(() => professionalId = v),
            ),
            const SizedBox(height: 20),
            GradientButton(label: 'Salvar', icon: Icons.save_outlined, onPressed: () => Navigator.pop(context, true)),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.put('/api/portfolio/${p.id}',
          {'caption': caption.text.trim(), 'serviceId': serviceId, 'professionalId': professionalId});
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _options(int index) {
    final p = _photos![index];
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.fullscreen_rounded),
          title: const Text('Ver em tela cheia'),
          onTap: () {
            Navigator.pop(context);
            PhotoViewer.open(this.context, _photos!, index);
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Legenda, serviço e profissional'),
          onTap: () {
            Navigator.pop(context);
            _edit(p);
          },
        ),
        if (index > 0)
          ListTile(
            leading: const Icon(Icons.arrow_back_rounded),
            title: const Text('Mover para antes'),
            onTap: () {
              Navigator.pop(context);
              _move(index, -1);
            },
          ),
        if (index < _photos!.length - 1)
          ListTile(
            leading: const Icon(Icons.arrow_forward_rounded),
            title: const Text('Mover para depois'),
            onTap: () {
              Navigator.pop(context);
              _move(index, 1);
            },
          ),
        ListTile(
          leading: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
          title: Text('Apagar', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: () {
            Navigator.pop(context);
            _delete(p);
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final text = Theme.of(context).textTheme;
    final usage = _usage;
    return Scaffold(
      appBar: AppBar(title: const Text('Portfólio de fotos')),
      floatingActionButton: _progress != null || photos == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Escolher da galeria'),
                    onTap: () {
                      Navigator.pop(context);
                      _add(ImageSource.gallery);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Tirar foto'),
                    onTap: () {
                      Navigator.pop(context);
                      _add(ImageSource.camera);
                    },
                  ),
                ]),
              ),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Adicionar fotos'),
            ),
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : photos == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
                    Text(
                      'Fotos dos seus trabalhos aparecem na página de agendamento e no app do cliente. '
                      'Toque numa foto para editar, mudar a ordem ou apagar.',
                      style: text.bodySmall?.copyWith(color: Brand.muted),
                    ),
                    if (usage != null && usage.$2 > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${usage.$1} de ${usage.$2} fotos', style: text.labelLarge),
                      ),
                    if (_progress != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Text(_progress!),
                        ]),
                      ),
                    const SizedBox(height: 12),
                    if (photos.isEmpty)
                      const EmptyState(
                        icon: Icons.photo_library_outlined,
                        title: 'Nenhuma foto ainda',
                        message: 'Mostre seus melhores trabalhos: cortes, cores, penteados...',
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                        itemCount: photos.length,
                        itemBuilder: (context, i) => PhotoThumb(photo: photos[i], onTap: () => _options(i)),
                      ),
                  ]),
                ),
    );
  }
}
