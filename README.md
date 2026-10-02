# AgroMarket 360 · App móvil (Flutter)

App Android (iOS más adelante) de AgroMarket 360. Consume la API REST del proyecto web
([agromarket-360](https://github.com/mike-dev-90/agromarket-360), documentada en `docs/API.md`).

## Estado (v0.1)

- Registro e inicio de sesión de compradores (token guardado en almacenamiento seguro).
- Catálogo de ganado con búsqueda, filtro por tipo, paginación y detalle.
- Subastas: listado (en curso / próximas / finalizadas) y detalle con **consulta periódica cada 5 s**
  (solo con la pantalla visible), cuenta atrás calculada con la hora del servidor y pujas.
- Cuenta: estado de verificación de identidad y cierre de sesión.

Pendiente: ofertas, pedidos, favoritos, notificaciones, publicar animales (ganaderos), push, iOS.

## Primera vez en tu PC (Windows)

```powershell
git clone https://github.com/mike-dev-90/agromarket-360_app.git
cd agromarket-360_app
flutter create --project-name agromarket_360_app --platforms=android .
Remove-Item test\widget_test.dart      # lo genera flutter create y no aplica a esta app
git checkout lib                        # por si flutter create tocó lib/
flutter pub get
```

Para hablar con un servidor `http://` en desarrollo, en `android/app/src/main/AndroidManifest.xml` añade al
elemento `<application ...>` el atributo `android:usesCleartextTraffic="true"` (en producción usa HTTPS y quítalo).

## Ejecutar

1. Levanta el proyecto web (`php artisan serve --host=0.0.0.0 --port=8000`) con `php artisan migrate` hecho.
2. Emulador de Android (usa `10.0.2.2` para llegar a tu PC, ya es el valor por defecto):

   ```powershell
   flutter run
   ```

3. Móvil físico o servidor remoto:

   ```powershell
   flutter run --dart-define=API_BASE_URL=http://IP_DE_TU_PC:8000/api/v1
   ```

## Pruebas

```powershell
flutter test
flutter analyze
```
