import 'package:agromarket_360_app/app.dart';
import 'package:agromarket_360_app/core/api_client.dart';
import 'package:agromarket_360_app/core/photo_picker.dart';
import 'package:agromarket_360_app/features/favorites/favorites_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

Future<void> _settle(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _pumpApp(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const AgroMarketApp()));
  await _settle(tester);
}

Future<void> _closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox()); // libera temporizadores de las pantallas abiertas
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder);
  await _settle(tester);
}

Finder _tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _openFirstAnimal(WidgetTester tester) async {
  await tester.tap(find.textContaining('Vaca 2').first);
  await _settle(tester);
}

void main() {
  group('Sesión', () {
    testWidgets('invitado: las secciones privadas piden iniciar sesión; login con error y con éxito; cerrar sesión', (tester) async {
      final api = FakeApi();
      await _pumpApp(tester, api);

      await tester.tap(_tab('Ofertas'));
      await _settle(tester);
      expect(find.text('Inicia sesión para ver y gestionar tus ofertas.'), findsOneWidget);
      expect(api.calls.where((c) => c == 'GET /offers'), isEmpty, reason: 'un invitado no debe consultar /offers');

      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await _settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'comprador@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'mala');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await _settle(tester);
      expect(find.text('Las credenciales no coinciden con nuestros registros.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'secreta123');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await _settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget, reason: 'tras el login vuelve al inicio');

      // La pestaña de ofertas se actualiza sola al haber sesión (sin error 401 pegado).
      await tester.tap(_tab('Ofertas'));
      await _settle(tester);
      expect(find.textContaining('Aún no has hecho ofertas'), findsOneWidget);

      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      expect(find.text('comprador@test.com'), findsOneWidget);
      expect(find.text('Identidad verificada'), findsOneWidget);

      await tester.tap(find.text('Cerrar sesión'));
      await _settle(tester);
      expect(find.text('Inicia sesión para ofertar, pujar y comprar.'), findsOneWidget);
      expect(api.tokens_.token, isNull);
      await _closeApp(tester);
    });

    testWidgets('sesión guardada: al abrir la app ya está dentro', (tester) async {
      final api = FakeApi(loggedIn: true);
      await _pumpApp(tester, api);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      expect(find.text('Comprador Test'), findsOneWidget);
      await _closeApp(tester);
    });

    testWidgets('registro: valida contraseñas, informa correo repetido y entra al crear la cuenta', (tester) async {
      final api = FakeApi();
      await _pumpApp(tester, api);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      await tester.tap(find.text('Crear una cuenta'));
      await _settle(tester);

      Future<void> fill(String email, {String confirm = 'secreta123'}) async {
        await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo'), 'Ana Pérez');
        await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), email);
        await tester.enterText(find.widgetWithText(TextFormField, 'Teléfono'), '0991234567');
        await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), 'Quito');
        await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña (mínimo 8 caracteres)'), 'secreta123');
        await tester.enterText(find.widgetWithText(TextFormField, 'Repite la contraseña'), confirm);
      }

      await fill('ana@test.com', confirm: 'otra');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await _settle(tester);
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(find.text('Selecciona tu provincia'), findsOneWidget);
      expect(find.text('Selecciona una opción'), findsOneWidget);
      expect(api.calls.where((c) => c == 'POST /auth/register'), isEmpty);

      await _tapVisible(tester, find.byType(DropdownButtonFormField<String>).first);
      await _tapVisible(tester, find.text('Azuay').last);
      await _tapVisible(tester, find.byType(DropdownButtonFormField<String>).last);
      await _tapVisible(tester, find.text('Cría').last);
      await fill('repetido@test.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await _settle(tester);
      expect(find.text('The email has already been taken.'), findsOneWidget);

      await fill('ana@test.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await _settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(api.tokens_.token, isNotNull);
      await _closeApp(tester);
    });
  });

  group('Perfil y verificación', () {
    testWidgets('editar perfil guarda los cambios y valida el correo', (tester) async {
      final api = FakeApi(loggedIn: true);
      await _pumpApp(tester, api);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      await _tapVisible(tester, find.text('Editar perfil'));

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo'), 'Nombre Nuevo');
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'ocupado@test.com');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar cambios'));
      expect(find.text('The email has already been taken.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'nuevo@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), 'Cuenca');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar cambios'));
      expect(find.text('Perfil actualizado correctamente.'), findsOneWidget);
      expect(api.profile['name'], 'Nombre Nuevo');
      expect(api.profile['city'], 'Cuenca');
      expect(api.profile['purchase_purpose'], 'cria');

      await tester.pageBack();
      await _settle(tester);
      expect(find.text('Nombre Nuevo'), findsOneWidget, reason: 'la cuenta se actualiza sin volver a iniciar sesión');
      await _closeApp(tester);
    });

    testWidgets('cambiar contraseña: contraseña actual incorrecta, no coinciden y éxito', (tester) async {
      final api = FakeApi(loggedIn: true);
      await _pumpApp(tester, api);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      await _tapVisible(tester, find.text('Cambiar contraseña'));

      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña actual'), 'incorrecta');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nueva contraseña (mínimo 8 caracteres)'), 'nuevaClave123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Repite la nueva contraseña'), 'otraDistinta');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Actualizar contraseña'));
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(api.calls.where((c) => c == 'PUT /profile/password'), isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Repite la nueva contraseña'), 'nuevaClave123');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Actualizar contraseña'));
      expect(find.text('La contraseña actual no es correcta.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña actual'), 'secreta123');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Actualizar contraseña'));
      expect(find.text('Contraseña actualizada correctamente.'), findsOneWidget);
      expect(api.password, 'nuevaClave123');
      await _closeApp(tester);
    });

    testWidgets('verificación: exige las 3 fotos, envía los documentos y queda en revisión', (tester) async {
      final api = FakeApi(loggedIn: true)
        ..identityVerified = false
        ..verificationStatus = 'none';
      final picker = FakePhotoPicker();
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api), photoPickerProvider.overrideWithValue(picker)], child: const AgroMarketApp()));
      await _settle(tester);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      expect(find.text('Identidad sin verificar'), findsOneWidget);
      await _tapVisible(tester, find.text('Verificación de identidad'));
      expect(find.text('Estado: Sin enviar'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Número de documento'), '0912345678');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Enviar documentos'));
      expect(find.text('Agrega las tres fotos: frente, reverso y selfie.'), findsOneWidget);
      expect(api.formCalls, isEmpty);

      for (final label in ['Documento (frente)', 'Documento (reverso)', 'Selfie sosteniendo el documento']) {
        await _tapVisible(tester, find.text(label));
        await _tapVisible(tester, find.text('Elegir de la galería'));
      }
      expect(picker.picks, 3);
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Enviar documentos'));

      expect(api.formCalls.single['fields'], {'document_type': 'cedula', 'document_number': '0912345678'});
      expect((api.formCalls.single['files'] as Map).keys, ['document_front', 'document_back', 'selfie']);
      expect(find.text('Estado: En revisión'), findsOneWidget);
      expect(find.text('Enviar documentos'), findsOneWidget, reason: 'aún quedan intentos');
      await _closeApp(tester);
    });

    testWidgets('verificada pero sin propósito de compra: avisa y lleva al perfil', (tester) async {
      final api = FakeApi(loggedIn: true)
        ..identityVerified = false
        ..verificationStatus = 'verified'
        ..missingProfile = ['purchase_purpose'];
      await _pumpApp(tester, api);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      await _tapVisible(tester, find.text('Verificación de identidad'));
      expect(find.text('Antes de verificarte falta:'), findsOneWidget);
      await _tapVisible(tester, find.text('Completar mi perfil'));
      expect(find.text('Editar perfil'), findsWidgets);
      await _closeApp(tester);
    });
  });

  group('Catálogo y favoritos', () {
    testWidgets('el catálogo lista animales, filtra por tipo y abre el detalle', (tester) async {
      final api = FakeApi();
      await _pumpApp(tester, api);
      expect(find.textContaining('Vaca 2'), findsWidgets);

      await tester.tap(find.text('Porcino'));
      await _settle(tester);
      expect(api.calls.last, 'GET /livestock');

      await _openFirstAnimal(tester);
      expect(find.text('Detalle del animal'), findsOneWidget);
      expect(find.text('Hacer oferta'), findsOneWidget);
      expect(find.text('Comprar'), findsOneWidget);
      await _closeApp(tester);
    });

    testWidgets('invitado que intenta ofertar, comprar o guardar va al login', (tester) async {
      final api = FakeApi();
      await _pumpApp(tester, api);
      for (final action in [find.text('Hacer oferta'), find.text('Comprar'), find.byIcon(Icons.favorite_border)]) {
        await _openFirstAnimal(tester);
        await tester.tap(action);
        await _settle(tester);
        expect(find.text('Iniciar sesión'), findsWidgets);
        await tester.pageBack();
        await _settle(tester);
        await tester.pageBack();
        await _settle(tester);
      }
      expect(api.calls.where((c) => c.startsWith('POST /offers') || c.startsWith('POST /orders') || c.startsWith('POST /favorites')), isEmpty);
      await _closeApp(tester);
    });

    testWidgets('guardar y quitar favorito; aparece en Mis favoritos', (tester) async {
      final api = FakeApi(loggedIn: true);
      await _pumpApp(tester, api);
      await _openFirstAnimal(tester);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await _settle(tester);
      expect(api.calls, contains('POST /favorites'));
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.pageBack();
      await _settle(tester);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      await tester.tap(find.text('Mis favoritos'));
      await _settle(tester);
      expect(find.textContaining('Vaca 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar de favoritos'));
      await _settle(tester);
      expect(api.calls, contains('DELETE /favorites/99'));
      expect(find.textContaining('Aún no tienes favoritos'), findsOneWidget);
      await _closeApp(tester);
    });
  });

  group('Insumos, carrito y checkout', () {
    Future<void> openSupplies(WidgetTester tester) async {
      await tester.tap(find.text('Insumos'));
      await _settle(tester);
    }

    testWidgets('explorar insumos: listar, buscar y abrir el detalle', (tester) async {
      final api = FakeApi();
      await _pumpApp(tester, api);
      await openSupplies(tester);
      expect(find.textContaining('Balanceado 2'), findsOneWidget);
      expect(find.text('Sin stock'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'balanceado 4');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(find.textContaining('Balanceado 4'), findsOneWidget);
      expect(find.textContaining('Balanceado 2'), findsNothing);

      await tester.tap(find.textContaining('Balanceado 4'));
      await _settle(tester);
      expect(find.text('Detalle del insumo'), findsOneWidget);
      expect(find.text('Vendedor: Agro Insumos SA'), findsOneWidget);
      await _closeApp(tester);
    });

    testWidgets('invitado que intenta agregar al carrito va al login', (tester) async {
      final api = FakeApi();
      await _pumpApp(tester, api);
      await openSupplies(tester);
      await tester.tap(find.textContaining('Balanceado 2'));
      await _settle(tester);
      await _tapVisible(tester, find.textContaining('Agregar al carrito'));
      expect(find.text('Iniciar sesión'), findsWidgets);
      expect(api.calls.where((c) => c.contains('/cart')), isEmpty);
      await _closeApp(tester);
    });

    testWidgets('agregar con cantidad, límite de stock, cambiar cantidades, quitar y vaciar', (tester) async {
      final api = FakeApi(loggedIn: true);
      await _pumpApp(tester, api);
      await openSupplies(tester);
      await tester.tap(find.textContaining('Balanceado 2'));
      await _settle(tester);

      // El stock es 5: el botón "más" se detiene en 5.
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byTooltip('Más'));
        await tester.pump();
      }
      await _tapVisible(tester, find.textContaining('Agregar al carrito'));
      expect(api.cartItems.single['quantity'], 5);
      expect(find.text('Agregado al carrito.'), findsOneWidget);

      // Agregar más supera el stock: el servidor lo rechaza y la app lo muestra.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await _tapVisible(tester, find.textContaining('Agregar al carrito'));
      expect(find.text('Solo hay 5 disponibles de este producto.'), findsOneWidget);

      await tester.pageBack();
      await _settle(tester);
      expect(find.text('1'), findsWidgets, reason: 'insignia del carrito');
      await tester.tap(find.byTooltip('Carrito'));
      await _settle(tester);
      expect(find.text('Mi carrito'), findsOneWidget);
      expect(find.text('\$105.00'), findsWidgets); // 5 x 21

      await tester.tap(find.byTooltip('Menos'));
      await _settle(tester);
      expect(api.cartItems.single['quantity'], 4);
      await tester.tap(find.byTooltip('Más'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Más'));
      await _settle(tester);
      expect(api.cartItems.single['quantity'], 5, reason: 'no pasa del stock');
      expect(find.text('Solo hay 5 disponibles de este producto.'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar'));
      await _settle(tester);
      expect(find.text('Tu carrito está vacío.'), findsOneWidget);
      expect(api.cartItems, isEmpty);
      await _closeApp(tester);
    });

    testWidgets('checkout con un solo vendedor lleva al pedido; valida campos; transferencia o efectivo', (tester) async {
      final api = FakeApi(loggedIn: true)..profile['state'] = null; // sin provincia previa: el menú abre desde el inicio
      api.cartItems.add({'id': 1, 'product_id': 2, 'name': 'Balanceado 2', 'image': null, 'unit': 'bolsa', 'quantity': 2, 'unit_price': 21.0, 'stock': 5});
      await _pumpApp(tester, api);
      await tester.tap(find.byTooltip('Carrito'));
      await _settle(tester);
      await _tapVisible(tester, find.text('Continuar con la compra'));
      expect(find.text('Finalizar compra'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Dirección'), '');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Confirmar pedido'));
      expect(find.text('Campo obligatorio'), findsWidgets);
      expect(api.lastCheckout, isNull);

      await tester.enterText(find.widgetWithText(TextFormField, 'Dirección'), 'Av. 9 de Octubre 100');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), 'Guayaquil');
      await _tapVisible(tester, find.byType(DropdownButtonFormField<String>));
      await _tapVisible(tester, find.text('Azuay').last);
      await _tapVisible(tester, find.text('Efectivo contra entrega'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Confirmar pedido'));

      expect(api.lastCheckout!['payment_method'], 'cash');
      expect(api.lastCheckout!['shipping_state'], 'Azuay');
      expect(api.cartItems, isEmpty);
      expect(find.text('Detalle del pedido'), findsOneWidget);
      expect(find.text('\$42.00'), findsWidgets);
      await _closeApp(tester);
    });

    testWidgets('checkout con dos vendedores crea dos pedidos y vuelve al inicio', (tester) async {
      final api = FakeApi(loggedIn: true)..profile['state'] = null; // sin provincia previa: el menú abre desde el inicio
      api.cartItems.addAll([
        {'id': 1, 'product_id': 2, 'name': 'Balanceado 2', 'image': null, 'unit': 'bolsa', 'quantity': 1, 'unit_price': 21.0, 'stock': 5},
        {'id': 2, 'product_id': 1, 'name': 'Sal', 'image': null, 'unit': 'bolsa', 'quantity': 1, 'unit_price': 10.5, 'stock': 5},
      ]);
      await _pumpApp(tester, api);
      await tester.tap(find.byTooltip('Carrito'));
      await _settle(tester);
      await _tapVisible(tester, find.text('Continuar con la compra'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Dirección'), 'Calle 1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), 'Quito');
      await _tapVisible(tester, find.byType(DropdownButtonFormField<String>));
      await _tapVisible(tester, find.text('Azuay').last);
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Confirmar pedido'));
      expect(api.orders, hasLength(2));
      expect(find.text('Se crearon 2 pedidos (uno por vendedor).'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await _closeApp(tester);
    });

    testWidgets('sin identidad verificada el servidor rechaza la compra y la app lo explica', (tester) async {
      final api = FakeApi(loggedIn: true)
        ..identityVerified = false
        ..profile['state'] = null;
      api.cartItems.add({'id': 1, 'product_id': 2, 'name': 'Balanceado 2', 'image': null, 'unit': 'bolsa', 'quantity': 1, 'unit_price': 21.0, 'stock': 5});
      await _pumpApp(tester, api);
      await tester.tap(find.byTooltip('Carrito'));
      await _settle(tester);
      await _tapVisible(tester, find.text('Continuar con la compra'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Dirección'), 'Calle 1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), 'Quito');
      await _tapVisible(tester, find.byType(DropdownButtonFormField<String>));
      await _tapVisible(tester, find.text('Azuay').last);
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Confirmar pedido'));
      expect(find.text('Debes verificar tu identidad para comprar.'), findsOneWidget);
      expect(api.orders, isEmpty);
      await _closeApp(tester);
    });
  });

  group('Ofertas', () {
    testWidgets('hacer una oferta; una oferta muy baja muestra el error del servidor', (tester) async {
      final api = FakeApi(loggedIn: true);
      await _pumpApp(tester, api);
      await _openFirstAnimal(tester);

      await tester.tap(find.text('Hacer oferta'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, '50');
      await tester.tap(find.widgetWithText(FilledButton, 'Ofertar'));
      await _settle(tester);
      expect(find.text('La oferta es demasiado baja.'), findsOneWidget);
      expect(api.offers, isEmpty);

      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('Hacer oferta'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, '1500');
      await tester.tap(find.widgetWithText(FilledButton, 'Ofertar'));
      await _settle(tester);
      expect(find.text('Oferta enviada. Te avisaremos cuando el vendedor responda.'), findsOneWidget);
      expect(api.offers, hasLength(1));

      await tester.pageBack();
      await _settle(tester);
      await tester.tap(_tab('Ofertas'));
      await _settle(tester);
      expect(find.text('Pendiente'), findsOneWidget);
      await _closeApp(tester);
    });

    testWidgets('el vendedor contraofertó: el comprador acepta y continúa con la compra', (tester) async {
      final api = FakeApi(loggedIn: true);
      api.offers.add({'id': 1, 'status': 'negotiating', 'offered_by': 'rancher', 'offer_price': 1800.0, 'message': null, 'rancher_response': 'Último precio'});
      await _pumpApp(tester, api);
      await tester.tap(_tab('Ofertas'));
      await _settle(tester);
      expect(find.text('El vendedor respondió: te toca'), findsOneWidget);

      await tester.tap(find.byType(ListTile).first);
      await _settle(tester);
      expect(find.text('Respuesta del vendedor: Último precio'), findsOneWidget);
      await tester.tap(find.text('Aceptar \$1,800.00'));
      await _settle(tester);
      expect(find.text('Aceptada'), findsOneWidget);

      await tester.tap(find.text('Continuar con la compra'));
      await _settle(tester);
      expect(find.text('Detalle del pedido'), findsOneWidget);
      expect(api.orders.single['total'], 1800.0, reason: 'el pedido usa el precio negociado');
      await _closeApp(tester);
    });

    testWidgets('contraofertar y rechazar una negociación', (tester) async {
      final api = FakeApi(loggedIn: true);
      api.offers.add({'id': 1, 'status': 'negotiating', 'offered_by': 'rancher', 'offer_price': 1800.0, 'message': null, 'rancher_response': null});
      await _pumpApp(tester, api);
      await tester.tap(_tab('Ofertas'));
      await _settle(tester);
      await tester.tap(find.byType(ListTile).first);
      await _settle(tester);

      await tester.tap(find.text('Hacer contraoferta'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, '1600');
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await _settle(tester);
      expect(api.offers.single['offer_price'], 1600);
      expect(find.text('Esperando la respuesta del vendedor.'), findsOneWidget);

      await tester.tap(find.text('Rechazar / cerrar negociación'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sí'));
      await _settle(tester);
      expect(api.offers.single['status'], 'rejected');
      expect(find.text('Rechazada'), findsOneWidget);
      await _closeApp(tester);
    });
  });

  group('Pedidos', () {
    testWidgets('comprar, ver datos bancarios, enviar comprobante y cancelar', (tester) async {
      final api = FakeApi(loggedIn: true);
      await _pumpApp(tester, api);
      await _openFirstAnimal(tester);

      await tester.tap(find.text('Comprar'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sí'));
      await _settle(tester);
      expect(find.text('Detalle del pedido'), findsOneWidget);
      expect(find.text('AGM-0005'), findsOneWidget);
      expect(find.text('Cuenta: 2200123456'), findsOneWidget);
      expect(find.text('Titular: AgroMarket 360 S.A.'), findsOneWidget);

      await _tapVisible(tester, find.text('Ya hice la transferencia'));
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar comprobante'));
      await _settle(tester);
      expect(find.text('Obligatorio'), findsNWidgets(2), reason: 'referencia y banco son obligatorios');

      await tester.enterText(find.widgetWithText(TextFormField, 'Número de referencia'), 'REF-123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Banco desde el que transferiste'), 'Pichincha');
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar comprobante'));
      await _settle(tester);
      expect(find.text('Comprobante enviado. El vendedor confirmará tu pago.'), findsOneWidget);
      expect(api.orders.single['transfer_reference'], 'REF-123');

      await tester.pump(const Duration(seconds: 5)); // el aviso inferior tapa el botón mientras se muestra
      await tester.pump(const Duration(seconds: 1));
      await _tapVisible(tester, find.text('Cancelar pedido'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sí'));
      await _settle(tester);
      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.text('Cancelar pedido'), findsNothing);
      expect(find.text('Ya hice la transferencia'), findsNothing);
      await _closeApp(tester);
    });

    testWidgets('sin datos bancarios configurados se avisa en lugar de mostrar una cuenta', (tester) async {
      final api = FakeApi(loggedIn: true)..bankConfigured = false;
      api.orders.add({'id': 5, 'order_number': 'AGM-0005', 'status': 'pending', 'payment_status': 'pending', 'total': 2000.0, 'items': <Map<String, dynamic>>[]});
      await _pumpApp(tester, api);
      await tester.tap(_tab('Pedidos'));
      await _settle(tester);
      await tester.tap(find.byType(ListTile).first);
      await _settle(tester);
      expect(find.textContaining('datos bancarios aún no están configurados'), findsOneWidget);
      await _closeApp(tester);
    });

    testWidgets('pedido enviado: confirmar recepción; entregado ya no ofrece acciones', (tester) async {
      final api = FakeApi(loggedIn: true);
      api.orders.add({'id': 5, 'order_number': 'AGM-0005', 'status': 'shipped', 'payment_status': 'paid', 'total': 2000.0, 'items': [{'name': 'Vaca', 'quantity': 1, 'unit_price': 2000.0, 'total': 2000.0}]});
      await _pumpApp(tester, api);
      await tester.tap(_tab('Pedidos'));
      await _settle(tester);
      await tester.tap(find.byType(ListTile).first);
      await _settle(tester);
      expect(find.text('Cancelar pedido'), findsNothing, reason: 'un pedido enviado no se cancela');

      await _tapVisible(tester, find.text('Confirmar que lo recibí'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sí'));
      await _settle(tester);
      expect(find.text('Entregado'), findsOneWidget);
      expect(find.text('Confirmar que lo recibí'), findsNothing);
      await _closeApp(tester);
    });
  });

  group('Notificaciones', () {
    testWidgets('marcar una y todas como leídas', (tester) async {
      final api = FakeApi(loggedIn: true);
      await _pumpApp(tester, api);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      await tester.tap(find.text('Notificaciones'));
      await _settle(tester);
      expect(find.byIcon(Icons.notifications_active), findsNWidgets(2));

      await tester.tap(find.text('Oferta aceptada'));
      await _settle(tester);
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);

      await tester.tap(find.text('Marcar todas como leídas'));
      await _settle(tester);
      expect(find.byIcon(Icons.notifications_active), findsNothing);
      expect(find.text('Marcar todas como leídas'), findsNothing);
      await _closeApp(tester);
    });
  });

  group('Subastas', () {
    testWidgets('pujar: mínimo respetado, precio actualizado y consulta periódica cada 5 s solo con la app visible', (tester) async {
      final api = FakeApi(loggedIn: true);
      await _pumpApp(tester, api);
      await tester.tap(_tab('Subastas'));
      await _settle(tester);
      await tester.tap(find.text('Lote 2'));
      await _settle(tester);
      expect(find.text('Subasta'), findsOneWidget);

      int detailCalls() => api.calls.where((c) => c == 'GET /auctions/2').length;
      final before = detailCalls();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(detailCalls(), greaterThanOrEqualTo(before + 2), reason: 'consulta periódica');

      // En segundo plano no se consulta.
      for (final st in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      final paused = detailCalls();
      await tester.pump(const Duration(seconds: 20));
      expect(detailCalls(), paused);
      for (final st in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      await _settle(tester);
      expect(detailCalls(), greaterThan(paused), reason: 'al volver se actualiza al instante');

      await tester.tap(find.textContaining('Pujar (mín.'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, '100');
      await tester.tap(find.widgetWithText(FilledButton, 'Pujar'));
      await _settle(tester);
      expect(find.textContaining('La puja mínima es'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.textContaining('Pujar (mín.'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, '600');
      await tester.tap(find.widgetWithText(FilledButton, 'Pujar'));
      await _settle(tester);
      expect(find.text('¡Puja realizada!'), findsOneWidget);
      expect(find.text('\$600.00'), findsWidgets);
      expect(find.text('Tu mejor puja: \$600.00'), findsOneWidget);
      await _closeApp(tester);
    });

    testWidgets('invitado que intenta pujar va al login', (tester) async {
      final api = FakeApi();
      await _pumpApp(tester, api);
      await tester.tap(_tab('Subastas'));
      await _settle(tester);
      await tester.tap(find.text('Lote 2'));
      await _settle(tester);
      await tester.tap(find.textContaining('Pujar (mín.'));
      await _settle(tester);
      expect(find.text('Iniciar sesión'), findsWidgets);
      expect(api.calls.where((c) => c.contains('/bids')), isEmpty);
      await _closeApp(tester);
    });
  });

  test('FavoriteItem lee la respuesta de la API', () {
    final f = FavoriteItem.fromJson({'id': 1, 'type': 'livestock', 'item_id': 4, 'title': 'Toro', 'price': 10});
    expect(f.itemId, 4);
    expect(f.price, 10.0);
  });
}
