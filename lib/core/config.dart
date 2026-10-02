/// URL base de la API. En el emulador de Android, 10.0.2.2 es el ordenador anfitrión.
/// Para otro servidor: flutter run --dart-define=API_BASE_URL=https://tu-dominio.com/api/v1
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// Cada cuántos segundos se consulta una subasta abierta.
  static const auctionPollSeconds = 5;
}
