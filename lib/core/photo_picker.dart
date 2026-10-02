import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Elegir una foto (cámara o galería). Es una interfaz para poder sustituirla en las pruebas.
abstract class PhotoPicker {
  /// Devuelve la ruta del archivo elegido, o null si se cancela.
  Future<String?> pick({required bool fromCamera});
}

class DevicePhotoPicker implements PhotoPicker {
  final _picker = ImagePicker();

  @override
  Future<String?> pick({required bool fromCamera}) async {
    final file = await _picker.pickImage(source: fromCamera ? ImageSource.camera : ImageSource.gallery, maxWidth: 1800, imageQuality: 85);
    return file?.path;
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());
