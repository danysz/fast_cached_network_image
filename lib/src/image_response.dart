import 'dart:typed_data';

class ImageResponse {
  late Uint8List imageData;
  String? error;
  ImageResponse({required this.imageData, required this.error});
}