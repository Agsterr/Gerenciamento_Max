import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Grade de fotos do portfólio; tocar abre em tela cheia ([PhotoViewer]).
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.photos, this.crossAxisCount = 3, this.maxItems, this.showServiceName = false});

  final List<Photo> photos;
  final int crossAxisCount;

  /// Escreve o nome do serviço em cada foto (para saber a que serviço ela se refere).
  final bool showServiceName;

  /// Mostra só as primeiras N (a tela cheia continua com todas).
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    final shown = maxItems == null ? photos : photos.take(maxItems!).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, mainAxisSpacing: 6, crossAxisSpacing: 6),
      itemCount: shown.length,
      itemBuilder: (context, i) => PhotoThumb(
        photo: shown[i],
        label: showServiceName ? shown[i].serviceName : null,
        onTap: () => PhotoViewer.open(context, photos, i),
      ),
    );
  }
}

class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.photo, this.onTap, this.label});

  final Photo photo;
  final VoidCallback? onTap;

  /// Faixa com texto na base da foto (ex.: nome do serviço).
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: photo.caption ?? 'Foto',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: const Color(0xFFF6EEF3),
          child: InkWell(
            onTap: onTap,
            child: Ink.image(
              image: NetworkImage(photo.thumbUrl),
              fit: BoxFit.cover,
              child: label == null
                  ? const SizedBox.expand()
                  : Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(6, 14, 6, 5),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xCC000000)],
                          ),
                        ),
                        child: Text(
                          label!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fotos em tela cheia: deslizar para os lados, pinça para zoom, legenda embaixo.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.photos, this.initialIndex = 0});

  final List<Photo> photos;
  final int initialIndex;

  static Future<void> open(BuildContext context, List<Photo> photos, int index) => Navigator.push(
        context,
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => PhotoViewer(photos: photos, initialIndex: index)),
      );

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    final subtitle = [photo.serviceName, if (photo.professionalName != null) 'por ${photo.professionalName}']
        .whereType<String>()
        .join(' · ');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} de ${widget.photos.length}', style: const TextStyle(color: Colors.white70, fontSize: 15)),
      ),
      body: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.photos[i].url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Stack(alignment: Alignment.center, children: [
                          Image.network(widget.photos[i].thumbUrl, fit: BoxFit.contain),
                          const CircularProgressIndicator(color: Colors.white),
                        ]),
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (photo.caption != null)
                Text(photo.caption!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              if (subtitle.isNotEmpty)
                Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Brand.line, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }
}
