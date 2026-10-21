import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:salao_core/salao_core.dart';

/// Fotos de um serviço dentro do cadastro dele. Serviço novo: as fotos escolhidas esperam na tela e
/// são enviadas quando o serviço for salvo ([uploadPending]). Serviço existente: envia na hora.
class ServicePhotosController extends ChangeNotifier {
  ServicePhotosController({required this.api, this.serviceId, ImagePicker? picker}) : picker = picker ?? ImagePicker();

  final ApiClient api;
  final ImagePicker picker;
  int? serviceId;

  List<Photo> photos = const [];
  final List<XFile> pending = [];
  String? progress;
  bool loading = false;

  Future<void> load() async {
    if (serviceId == null) return;
    loading = true;
    notifyListeners();
    try {
      final json = await api.get('/api/portfolio?serviceId=$serviceId') as List;
      photos = json.map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Abre a galeria (várias fotos) ou a câmera. Devolve mensagem de erro, se houver.
  Future<String?> add(ImageSource source) async {
    final List<XFile> files;
    try {
      // o servidor ainda reduz para 1600px; aqui só evita mandar 10 MB pelo 4G
      files = source == ImageSource.camera
          ? [?await picker.pickImage(source: source, maxWidth: 2400, imageQuality: 85)]
          : await picker.pickMultiImage(maxWidth: 2400, imageQuality: 85, limit: 20);
    } catch (e) {
      return e.toString();
    }
    if (files.isEmpty) return null;
    if (serviceId == null) {
      pending.addAll(files);
      notifyListeners();
      return null;
    }
    return _send(files);
  }

  /// Envia as fotos que estavam esperando o serviço ser criado. Devolve mensagem de erro, se houver.
  Future<String?> uploadPending(int newServiceId) async {
    serviceId = newServiceId;
    final files = List<XFile>.of(pending);
    pending.clear();
    return files.isEmpty ? null : _send(files);
  }

  Future<String?> _send(List<XFile> files) async {
    String? error;
    try {
      for (final (i, f) in files.indexed) {
        progress = 'Enviando ${i + 1} de ${files.length}...';
        notifyListeners();
        await api.upload('/api/portfolio',
            bytes: await f.readAsBytes(), filename: f.name.contains('.') ? f.name : '${f.name}.jpg', fields: {'serviceId': '$serviceId'});
      }
    } catch (e) {
      error = e.toString();
    } finally {
      progress = null;
      notifyListeners();
    }
    try {
      await load();
    } catch (_) {}
    return error;
  }

  Future<String?> remove(Photo p) async {
    try {
      await api.delete('/api/portfolio/${p.id}');
      photos = photos.where((x) => x.id != p.id).toList();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  void removePending(XFile f) {
    pending.remove(f);
    notifyListeners();
  }
}

class ServicePhotosSection extends StatefulWidget {
  const ServicePhotosSection({super.key, required this.controller});

  final ServicePhotosController controller;

  @override
  State<ServicePhotosSection> createState() => _ServicePhotosSectionState();
}

class _ServicePhotosSectionState extends State<ServicePhotosSection> {
  ServicePhotosController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    c.load().catchError((Object e) {
      if (mounted) showError(context, e);
    });
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _pick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final error = await c.add(source);
    if (error != null && mounted) showError(context, error);
  }

  Future<void> _delete(Photo p) async {
    if (!await confirmDialog(context, 'Apagar esta foto?', confirm: 'Apagar', danger: true)) return;
    final error = await c.remove(p);
    if (error != null && mounted) showError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final empty = c.photos.isEmpty && c.pending.isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Fotos deste serviço', style: text.titleSmall),
      const SizedBox(height: 2),
      Text(
        c.serviceId == null
            ? 'Escolha agora; elas são enviadas quando você salvar o serviço.'
            : 'Aparecem na página de agendamento e no app do cliente.',
        style: text.bodySmall?.copyWith(color: Brand.muted),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 84,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          _AddTile(onTap: c.progress == null ? _pick : null, busy: c.progress != null),
          for (final p in c.photos)
            _Thumb(
              child: PhotoThumb(photo: p, onTap: () => PhotoViewer.open(context, c.photos, c.photos.indexOf(p))),
              onRemove: () => _delete(p),
            ),
          for (final f in c.pending)
            _Thumb(
              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: _PendingImage(f)),
              onRemove: () => c.removePending(f),
            ),
        ]),
      ),
      if (c.progress != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(c.progress!, style: text.bodySmall)),
      if (empty && c.progress == null && !c.loading)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Nenhuma foto ainda.', style: text.bodySmall?.copyWith(color: Brand.muted)),
        ),
    ]);
  }
}

class _PendingImage extends StatelessWidget {
  const _PendingImage(this.file);

  final XFile file;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: file.readAsBytes(),
        builder: (context, snap) => snap.hasData
            ? Image.memory(snap.data!, fit: BoxFit.cover, width: 84, height: 84, cacheWidth: 200)
            : const SizedBox(width: 84, height: 84, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      );
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, required this.busy});

  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          button: true,
          label: 'Adicionar foto',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Brand.rose.withValues(alpha: 0.6), width: 1.5),
                color: Brand.rose.withValues(alpha: 0.08),
              ),
              child: busy
                  ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_outlined, color: Brand.rose),
                      SizedBox(height: 4),
                      Text('Foto', style: TextStyle(fontWeight: FontWeight.w700, color: Brand.rose, fontSize: 12)),
                    ]),
            ),
          ),
        ),
      );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(children: [
            Positioned.fill(child: child),
            Positioned(
              top: 2,
              right: 2,
              child: Semantics(
                button: true,
                label: 'Remover foto',
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}
