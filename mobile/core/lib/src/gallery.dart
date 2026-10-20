import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Grade de fotos do portfólio; tocar abre em tela cheia ([PhotoViewer]).
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.photos, this.crossAxisCount = 3, this.maxItems});

  final List<Photo> photos;
  final int crossAxisCount;

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
        onTap: () => PhotoViewer.open(context, photos, i),
      ),
    );
  }
}

class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.photo, this.onTap});

  final Photo photo;
  final VoidCallback? onTap;

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
              child: const SizedBox.expand(),
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
