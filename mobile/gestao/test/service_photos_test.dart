import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/widgets/service_photos.dart';

class _FakePicker extends ImagePicker {
  @override
  Future<List<XFile>> pickMultiImage({double? maxWidth, double? maxHeight, int? imageQuality, int? limit, bool requestFullMetadata = true}) async =>
      [XFile.fromData(utf8.encode('foto'), name: 'a.jpg'), XFile.fromData(utf8.encode('foto2'), name: 'b.jpg')];
}

Map<String, Object?> _photo(int id, int serviceId) => {
      'id': id,
      'url': 'http://x/$id.jpg',
      'thumbUrl': 'http://x/$id-t.jpg',
      'caption': null,
      'width': 10,
      'height': 10,
      'serviceId': serviceId,
      'serviceName': 'Corte',
      'professionalId': null,
      'professionalName': null,
    };

void main() {
  test('serviço novo: fotos esperam e são enviadas com o id do serviço salvo', () async {
    final uploads = <String>[];
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async {
        if (req.method == 'POST' && req.url.path == '/api/portfolio') {
          uploads.add(req.body);
          return http.Response(jsonEncode(_photo(1, 9)), 201, headers: {'content-type': 'application/json'});
        }
        if (req.method == 'GET' && req.url.path == '/api/portfolio') {
          expect(req.url.queryParameters['serviceId'], '9');
          return http.Response(jsonEncode([_photo(1, 9), _photo(2, 9)]), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 404);
      }),
    );
    final c = ServicePhotosController(api: api, picker: _FakePicker());

    expect(await c.add(ImageSource.gallery), isNull);
    expect(c.pending, hasLength(2));
    expect(uploads, isEmpty, reason: 'sem serviço salvo, nada é enviado ainda');

    expect(await c.uploadPending(9), isNull);
    expect(uploads, hasLength(2));
    for (final body in uploads) {
      expect(body, contains('name="serviceId"'));
      expect(body, contains('\r\n9\r\n'));
    }
    expect(c.pending, isEmpty);
    expect(c.photos, hasLength(2));
  });

  test('serviço existente: foto escolhida vai direto e apagar remove da lista', () async {
    var uploads = 0;
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async {
        if (req.method == 'POST') {
          uploads++;
          return http.Response(jsonEncode(_photo(uploads, 5)), 201, headers: {'content-type': 'application/json'});
        }
        if (req.method == 'DELETE') return http.Response('', 204);
        return http.Response(jsonEncode([_photo(1, 5), _photo(2, 5)]), 200, headers: {'content-type': 'application/json'});
      }),
    );
    final c = ServicePhotosController(api: api, serviceId: 5, picker: _FakePicker());
    expect(await c.add(ImageSource.gallery), isNull);
    expect(uploads, 2);
    expect(c.pending, isEmpty);
    expect(await c.remove(c.photos.first), isNull);
    expect(c.photos.map((p) => p.id), [2]);
  });
}
