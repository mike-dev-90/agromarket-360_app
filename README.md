# AgroMarket 360 · App móvil (Flutter)

App Android (iOS más adelante) de AgroMarket 360. Consume la API REST del proyecto web
([agromarket-360](https://github.com/mike-dev-90/agromarket-360), documentada en `docs/API.md`).

## Estado (v0.2)

Menú inferior con 5 accesos: **Catálogo · Subastas · Ofertas · Pedidos · Cuenta**.

- Registro e inicio de sesión de compradores (token en almacenamiento seguro, sesión restaurada al abrir).
- Catálogo con búsqueda, filtro por tipo, paginación y detalle; **favoritos**, **hacer oferta** y **comprar** desde el detalle.
- Subastas: listado (en curso / próximas / finalizadas) y detalle con **consulta periódica cada 5 s** (solo con la
  pantalla visible), cuenta atrás con la hora del servidor y pujas.
- Ofertas: lista, detalle, aceptar / rechazar / contraofertar y continuar con la compra.
- Pedidos: lista, detalle, datos bancarios, envío del comprobante de transferencia, cancelar y confirmar recepción.
- Favoritos y notificaciones (marcar una o todas) desde Cuenta.
- Ofertar, pujar y comprar exigen identidad verificada (se hace en la web); la app lo avisa.

Pendiente: publicar animales (ganaderos), insumos y servicios, mensajes por pedido, push, iOS, logo y colores exactos de la web.

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
flutter analyze
flutter test                      # 88 pruebas, sin red
```

- `test/layout_test.dart`: cada pantalla en móviles pequeños (320x568 y 360x640) con texto agrandado y datos con
  títulos larguísimos; falla si algo se desborda (la banda amarilla y negra).
- `test/flows_test.dart`: la app completa contra un servidor falso con estado (login, registro, favoritos, ofertas,
  compra, comprobante, cancelar, notificaciones, pujas y consulta periódica).
- `test/unit_test.dart`: cliente HTTP (errores, token, 429), sesión y modelos.
- `test/contract/`: ejecuta el cliente y los modelos reales contra **tu servidor Laravel** (requiere datos demo):

  ```powershell
  flutter test test/contract --dart-define=CONTRACT_API=http://127.0.0.1:8000/api/v1
  ```

  La API limita el login a 10 intentos por minuto; si repites la ejecución muy seguido verás el aviso de 429.
