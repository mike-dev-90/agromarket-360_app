import 'package:agromarket_360_app/app.dart';
import 'package:agromarket_360_app/core/api_client.dart';
import 'package:agromarket_360_app/core/photo_picker.dart';
import 'package:agromarket_360_app/features/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';

Future<void> _settle(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
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

Future<FakeApi> _pump(WidgetTester tester, List<String> roles, {FakeApi? api, bool verified = true, List<String> missing = const [], FakePhotoPicker? picker}) async {
  api ??= FakeApi(loggedIn: true);
  api.roles = roles;
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith(() => LoggedInAuth(roles: roles, verified: verified, missing: missing)),
      if (picker != null) photoPickerProvider.overrideWithValue(picker),
    ],
    child: const AgroMarketApp(),
  ));
  await _settle(tester);
  return api;
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _openBusiness(WidgetTester tester, String tile) async {
  await tester.tap(_tab('Cuenta'));
  await _settle(tester);
  await _tapVisible(tester, find.text('Mi negocio'));
  await _tapVisible(tester, find.text(tile));
}

Future<void> _pickPhoto(WidgetTester tester, String buttonText) async {
  await _tapVisible(tester, find.text(buttonText));
  await _tapVisible(tester, find.text('Elegir de la galería'));
}

void main() {
  group('Acceso al negocio', () {
    testWidgets('un comprador no ve "Mi negocio"; un vendedor sí, con su resumen y accesos', (tester) async {
      await _pump(tester, ['buyer']);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      expect(find.text('Mi negocio'), findsNothing);
      await _close(tester);

      final api = FakeApi(loggedIn: true);
      api.sellerOrders.add({'id': 1, 'status': 'pending', 'payment_status': 'pending', 'total': 10.0, 'items': <Map<String, dynamic>>[]});
      await _pump(tester, ['buyer', 'rancher'], api: api);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      await _tapVisible(tester, find.text('Mi negocio'));
      expect(find.text('Mi ganado'), findsOneWidget);
      expect(find.text('Mis subastas'), findsOneWidget);
      expect(find.text('Ofertas recibidas'), findsOneWidget);
      expect(find.text('Mis productos'), findsNothing, reason: 'no es proveedor');
      expect(find.text('Por cobrar'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('sin perfil de negocio o sin verificar se avisa con un enlace', (tester) async {
      await _pump(tester, ['buyer', 'supplier'], missing: const ['supplier_profile'], verified: false);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      await _tapVisible(tester, find.text('Mi negocio'));
      expect(find.text('Completa el perfil de tu negocio'), findsOneWidget);
      await tester.tap(find.text('Completa el perfil de tu negocio'));
      await _settle(tester);
      expect(find.text('Perfil de empresa'), findsWidgets);
      await _close(tester);
    });
  });

  group('Ganadero', () {
    testWidgets('publicar un animal: exige la foto principal, envía el formulario y aparece en la lista', (tester) async {
      final picker = FakePhotoPicker();
      final api = await _pump(tester, ['buyer', 'rancher'], picker: picker);
      await _openBusiness(tester, 'Mi ganado');
      expect(find.text('Aún no has publicado animales.'), findsOneWidget);
      await tester.tap(find.text('Publicar animal'));
      await _settle(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Título *'), 'Toro Brahman');
      await tester.enterText(find.widgetWithText(TextFormField, 'Descripción *'), 'Ejemplar sano y vacunado');
      await tester.enterText(find.widgetWithText(TextFormField, 'Precio (USD) *'), '2500');
      await _tapVisible(tester, find.text('Tipo de animal *'));
      await _tapVisible(tester, find.text('Bovino').last);
      await _tapVisible(tester, find.text('Sexo *'));
      await _tapVisible(tester, find.text('Macho').last);
      await _tapVisible(tester, find.text('Provincia *'));
      await _tapVisible(tester, find.text('Azuay').last);

      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Publicar'));
      expect(find.text('Agrega la foto principal del animal.'), findsOneWidget);
      expect(api.lastLivestockForm, isNull);

      await _pickPhoto(tester, 'Foto principal (obligatoria)');
      await _pickPhoto(tester, 'Fotos adicionales (0/5)');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Publicar'));

      final sent = api.lastLivestockForm!;
      expect((sent['fields'] as Map)['title'], 'Toro Brahman');
      expect((sent['fields'] as Map)['type'], 'cattle');
      expect((sent['fields'] as Map)['sex'], 'male');
      expect((sent['fields'] as Map)['location'], 'Azuay');
      expect((sent['fields'] as Map)['negotiable'], '1');
      expect((sent['files'] as Map).keys, ['main_image', 'additional_images[0]']);
      expect(find.text('Toro Brahman'), findsOneWidget, reason: 'vuelve a la lista y aparece');
      await _close(tester);
    });

    testWidgets('editar y eliminar un animal; filtrar por estado', (tester) async {
      final api = FakeApi(loggedIn: true);
      api.myLivestock.addAll([
        {'id': 1, 'title': 'Toro A', 'type': 'cattle', 'breed': 'Brahman', 'price': 2000.0, 'status': 'active', 'negotiable': true, 'location': 'Guayaquil, Guayas', 'province': 'Guayas', 'image': null, 'views': 5, 'offers_count': 2, 'description': 'Sano', 'sex': 'male', 'images': [{'id': 7, 'url': 'http://x/a.jpg'}]},
        {'id': 2, 'title': 'Vaca B', 'type': 'cattle', 'breed': 'Brahman', 'price': 1500.0, 'status': 'draft', 'negotiable': false, 'location': 'Quito, Pichincha', 'province': 'Pichincha', 'image': null, 'views': 0, 'offers_count': 0, 'description': 'Sana', 'sex': 'female', 'images': <Map<String, dynamic>>[]},
      ]);
      await _pump(tester, ['buyer', 'rancher'], api: api);
      await _openBusiness(tester, 'Mi ganado');
      expect(find.text('Toro A'), findsOneWidget);
      expect(find.text('Vaca B'), findsOneWidget);

      await tester.tap(find.text('Borrador'));
      await _settle(tester);
      expect(find.text('Toro A'), findsNothing);
      await tester.tap(find.text('Todos'));
      await _settle(tester);

      await tester.tap(find.text('Toro A'));
      await _settle(tester);
      expect(find.text('Editar animal'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Título *'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Título *'), 'Toro A editado');
      await tester.enterText(find.widgetWithText(TextFormField, 'Precio (USD) *'), '2100');
      // Quitar la foto adicional guardada
      await _tapVisible(tester, find.byTooltip('Quitar foto'));
      expect(api.myLivestock.first['images'], isEmpty);
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar cambios'));
      expect(api.myLivestock.first['title'], 'Toro A editado');
      expect(api.myLivestock.first['price'], 2100.0);
      expect(find.text('Toro A editado'), findsOneWidget);

      await tester.tap(find.text('Vaca B'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Eliminar'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sí'));
      await _settle(tester);
      expect(api.myLivestock, hasLength(1));
      expect(find.text('Vaca B'), findsNothing);
      await _close(tester);
    });

    testWidgets('ofertas recibidas: aceptar, contraofertar y rechazar con motivo', (tester) async {
      final api = FakeApi(loggedIn: true);
      for (final id in [1, 2, 3]) {
        api.rancherOffers.add({'id': id, 'status': 'pending', 'offered_by': 'buyer', 'offer_price': 1000.0 * id, 'message': 'Oferta $id', 'rancher_response': null, 'awaiting_you': true, 'buyer': {'id': 5, 'name': 'Comprador $id'}, 'livestock': {'id': 1, 'title': 'Toro A', 'price': 2000.0}});
      }
      await _pump(tester, ['buyer', 'rancher'], api: api);
      await _openBusiness(tester, 'Ofertas recibidas');
      expect(find.text('Te toca responder'), findsNWidgets(3));

      await tester.tap(find.widgetWithText(FilledButton, 'Aceptar').first);
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await _settle(tester);
      expect(api.rancherOffers[0]['status'], 'accepted');

      await tester.tap(find.widgetWithText(OutlinedButton, 'Contraofertar').first);
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, '1900');
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await _settle(tester);
      expect(api.rancherOffers[1]['status'], 'negotiating');
      expect(api.rancherOffers[1]['offer_price'], 1900.0);

      await tester.tap(find.widgetWithText(TextButton, 'Rechazar').first);
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await _settle(tester);
      expect(api.rancherOffers[2]['status'], 'pending', reason: 'el motivo es obligatorio');
      await tester.enterText(find.byType(TextField).last, 'Precio muy bajo');
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await _settle(tester);
      expect(api.rancherOffers[2]['status'], 'rejected');
      expect(api.rancherOffers[2]['rancher_response'], 'Precio muy bajo');
      await _close(tester);
    });

    testWidgets('subastas: crear (con fechas), ver pujas y cancelar sin pujas', (tester) async {
      final api = await _pump(tester, ['buyer', 'rancher']);
      await _openBusiness(tester, 'Mis subastas');
      await tester.tap(find.text('Nueva subasta'));
      await _settle(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Título *'), 'Lote de novillos');
      await tester.enterText(find.widgetWithText(TextFormField, 'Descripción *'), 'Cinco novillos');
      await tester.enterText(find.widgetWithText(TextFormField, 'Precio inicial (USD) *'), '500');
      await _tapVisible(tester, find.text('Tipo de animal *'));
      await _tapVisible(tester, find.text('Bovino').last);
      await _tapVisible(tester, find.text('Sexo *'));
      await _tapVisible(tester, find.text('Macho').last);

      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Crear subasta'));
      expect(find.text('Elige la fecha de inicio y la de cierre.'), findsOneWidget);

      await _close(tester);
      expect(api.myAuctions, isEmpty);
    });

    testWidgets('detalle de subasta propia: con pujas no se cancela; sin pujas sí', (tester) async {
      final api = FakeApi(loggedIn: true);
      api.myAuctions.addAll([
        {'id': 1, 'title': 'Con pujas', 'description': 'x', 'status': 'active', 'starting_price': 500.0, 'current_price': 650.0, 'min_bid_increment': 25.0, 'bid_count': 1, 'is_running': true, 'starts_at': '2026-10-01T10:00:00Z', 'ends_at': '2026-10-05T10:00:00Z', 'bids': [{'amount': 650.0, 'bidder': 'Ana'}]},
        {'id': 2, 'title': 'Sin pujas', 'description': 'x', 'status': 'active', 'starting_price': 500.0, 'current_price': 500.0, 'min_bid_increment': 25.0, 'bid_count': 0, 'is_running': true, 'starts_at': '2026-10-01T10:00:00Z', 'ends_at': '2026-10-05T10:00:00Z', 'bids': <Map<String, dynamic>>[]},
      ]);
      await _pump(tester, ['buyer', 'rancher'], api: api);
      await _openBusiness(tester, 'Mis subastas');

      await tester.tap(find.text('Con pujas'));
      await _settle(tester);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Cancelar subasta'), findsNothing);
      expect(find.textContaining('Con pujas ya no se puede cancelar'), findsOneWidget);
      await tester.pageBack();
      await _settle(tester);

      await tester.tap(find.text('Sin pujas'));
      await _settle(tester);
      await _tapVisible(tester, find.text('Cancelar subasta'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sí'));
      await _settle(tester);
      expect(api.myAuctions.last['status'], 'cancelled');
      expect(find.text('Cancelada'), findsWidgets);
      await _close(tester);
    });
  });

  group('Pedidos de venta', () {
    testWidgets('confirmar pago, preparar y enviar con guía; los botones siguen el estado', (tester) async {
      final api = FakeApi(loggedIn: true);
      api.sellerOrders.add({'id': 1, 'order_number': 'AGM-1', 'status': 'pending', 'payment_status': 'pending', 'payment_method': 'transfer', 'total': 50.0, 'buyer': {'id': 5, 'name': 'Ana', 'phone': '099'}, 'shipping_address': 'Calle 1', 'transfer': {'reference': 'REF-9', 'bank': 'Pichincha', 'date': '2026-10-02'}, 'items': [{'name': 'Sal mineral', 'quantity': 2, 'unit_price': 25.0, 'total': 50.0}]});
      await _pump(tester, ['buyer', 'supplier'], api: api);
      await _openBusiness(tester, 'Pedidos de venta');
      expect(find.text('Comprobante: ref. REF-9 · Pichincha · 2026-10-02'), findsOneWidget);
      expect(find.text('Marcar enviado'), findsNothing);

      await tester.tap(find.text('Confirmar pago'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sí'));
      await _settle(tester);
      expect(api.sellerOrders.single['status'], 'confirmed');

      await tester.tap(find.widgetWithText(OutlinedButton, 'En preparación'));
      await _settle(tester);
      expect(api.sellerOrders.single['status'], 'processing');

      await tester.tap(find.widgetWithText(FilledButton, 'Marcar enviado'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, 'TRK-77');
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await _settle(tester);
      expect(api.sellerOrders.single['status'], 'shipped');
      expect(api.sellerOrders.single['tracking_number'], 'TRK-77');
      expect(find.text('Guía: TRK-77'), findsOneWidget);
      expect(find.text('Confirmar pago'), findsNothing);
      await _close(tester);
    });

    testWidgets('el vendedor abre la conversación del pedido', (tester) async {
      final api = FakeApi(loggedIn: true);
      api.sellerOrders.add({'id': 1, 'order_number': 'AGM-1', 'status': 'confirmed', 'payment_status': 'paid', 'payment_method': 'cash', 'total': 50.0, 'buyer': {'id': 5, 'name': 'Ana'}, 'items': <Map<String, dynamic>>[]});
      await _pump(tester, ['buyer', 'supplier'], api: api);
      await _openBusiness(tester, 'Pedidos de venta');
      await tester.tap(find.text('Mensajes'));
      await _settle(tester);
      expect(find.text('Chat con Hacienda La Esperanza'), findsOneWidget);
      await _close(tester);
    });
  });

  group('Proveedor', () {
    testWidgets('crear, editar y eliminar un producto', (tester) async {
      final picker = FakePhotoPicker();
      final api = await _pump(tester, ['buyer', 'supplier'], picker: picker);
      await _openBusiness(tester, 'Mis productos');
      expect(find.text('Aún no has publicado productos.'), findsOneWidget);
      await tester.tap(find.text('Nuevo producto'));
      await _settle(tester);

      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Publicar producto'));
      expect(find.text('Campo obligatorio'), findsWidgets);
      expect(api.lastProductForm, isNull);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre *'), 'Sal mineral');
      await tester.enterText(find.widgetWithText(TextFormField, 'Descripción *'), 'Bolsa de 25 kg');
      await _tapVisible(tester, find.text('Categoría *'));
      await _tapVisible(tester, find.text('Alimentos y suplementos').last);
      await tester.enterText(find.widgetWithText(TextFormField, 'Precio (USD) *'), '12.50');
      await tester.enterText(find.widgetWithText(TextFormField, 'Stock *'), '40');
      await _pickPhoto(tester, 'Agregar foto');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Publicar producto'));

      expect((api.lastProductForm!['fields'] as Map)['name'], 'Sal mineral');
      expect((api.lastProductForm!['fields'] as Map)['quantity'], '40');
      expect((api.lastProductForm!['fields'] as Map)['category_id'], '1');
      expect((api.lastProductForm!['files'] as Map).keys, ['image']);
      expect(find.text('Sal mineral'), findsOneWidget);

      await tester.tap(find.text('Sal mineral'));
      await _settle(tester);
      expect(find.text('Editar producto'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Stock *'), '10');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar cambios'));
      expect(api.myProducts.single['stock'], 10);

      await tester.tap(find.text('Sal mineral'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Eliminar'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sí'));
      await _settle(tester);
      expect(api.myProducts, isEmpty);
      await _close(tester);
    });
  });

  group('Profesional', () {
    testWidgets('publicar un servicio', (tester) async {
      final api = await _pump(tester, ['buyer', 'professional']);
      await _openBusiness(tester, 'Mis servicios');
      await tester.tap(find.text('Nuevo servicio'));
      await _settle(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Título *'), 'Vacunación de hatos');
      await tester.enterText(find.widgetWithText(TextFormField, 'Descripción *'), 'Vacunación completa con certificado');
      await _tapVisible(tester, find.text('Categoría *'));
      await _tapVisible(tester, find.text('Veterinaria General').last);
      await tester.enterText(find.widgetWithText(TextFormField, 'Precio (USD) *'), '25');
      await _tapVisible(tester, find.text('Visita a domicilio'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Publicar servicio'));

      expect(api.lastServiceForm!['title'], 'Vacunación de hatos');
      expect(api.lastServiceForm!['home_visit'], '1');
      expect(api.lastServiceForm!['emergency_service'], '0');
      expect(find.text('Vacunación de hatos'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('solicitudes: aceptar, programar con cotización, completar y rechazar con motivo', (tester) async {
      final api = FakeApi(loggedIn: true);
      for (final id in [1, 2]) {
        api.proRequests.add({'id': id, 'status': 'pending', 'service_title': 'Vacunación', 'description': 'Vacunar reses $id', 'request_date': '2030-01-15', 'location': 'Finca', 'scheduled_date': null, 'price_quoted': null, 'response_message': null, 'client': {'id': 5, 'name': 'Cliente $id'}});
      }
      await _pump(tester, ['buyer', 'professional'], api: api);
      await _openBusiness(tester, 'Solicitudes de clientes');
      expect(find.text('Cliente 1'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Aceptar').first);
      await _settle(tester);
      expect(api.proRequests[0]['status'], 'accepted');

      await tester.tap(find.widgetWithText(OutlinedButton, 'Programar').first);
      await _settle(tester);
      await tester.tap(find.text('OK'));
      await _settle(tester);
      await tester.tap(find.text('OK'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, '300');
      await tester.tap(find.widgetWithText(FilledButton, 'Programar'));
      await _settle(tester);
      expect(api.proRequests[0]['status'], 'scheduled');
      expect(api.lastSchedule!['price_quoted'], 300.0);
      expect(api.lastSchedule!['scheduled_date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:00$')));

      await tester.tap(find.widgetWithText(FilledButton, 'Completar').first);
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await _settle(tester);
      expect(api.proRequests[0]['status'], 'completed');

      await tester.tap(find.widgetWithText(TextButton, 'Rechazar').first);
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await _settle(tester);
      expect(api.proRequests[1]['status'], 'pending', reason: 'el motivo es obligatorio');
      await tester.enterText(find.byType(TextField).last, 'Fuera de mi zona');
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
      await _settle(tester);
      expect(api.proRequests[1]['status'], 'rejected');
      await _close(tester);
    });
  });

  group('Perfiles de negocio y registro', () {
    testWidgets('perfil de ganadero: guardar, ver estado completo y subir documento', (tester) async {
      final picker = FakePhotoPicker();
      final api = await _pump(tester, ['buyer', 'rancher'], picker: picker, missing: const ['rancher_profile'], verified: false);
      await _openBusiness(tester, 'Perfil de ganadero');
      expect(find.text('Perfil incompleto'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la finca'), 'La Esperanza');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ubicación de la finca'), 'Guayas');
      await tester.enterText(find.widgetWithText(TextFormField, 'Tamaño (hectáreas)'), '120.5');
      await tester.enterText(find.widgetWithText(TextFormField, 'Capacidad de ganado (cabezas)'), '200');
      await tester.enterText(find.widgetWithText(TextFormField, 'Años de experiencia'), '10');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar perfil'));
      expect(api.businessProfile['farm_name'], 'La Esperanza');
      expect(api.businessProfile['farm_size'], 120.5);
      expect(api.businessProfile['cattle_capacity'], 200);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await _settle(tester);
      expect(find.text('Perfil completo'), findsOneWidget);

      await _tapVisible(tester, find.textContaining('documento de respaldo'));
      expect(picker.picks, 1);
      expect(api.businessProfile['has_backup_document'], true);
      await _close(tester);
    });

    testWidgets('perfil de empresa: tipos de producto como lista', (tester) async {
      final api = await _pump(tester, ['buyer', 'supplier']);
      await _openBusiness(tester, 'Perfil de empresa');
      await tester.enterText(find.widgetWithText(TextFormField, 'Tipos de productos'), 'alimentos, vacunas , equipos');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la empresa'), 'Agro SA');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar perfil'));
      expect(api.businessProfile['tipo_productos'], ['alimentos', 'vacunas', 'equipos']);
      await _close(tester);
    });

    testWidgets('registrarse como ganadero envía los campos de la finca', (tester) async {
      final api = FakeApi();
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const AgroMarketApp()));
      await _settle(tester);
      await tester.tap(_tab('Cuenta'));
      await _settle(tester);
      await tester.tap(find.text('Crear una cuenta'));
      await _settle(tester);

      await _tapVisible(tester, find.byType(DropdownButtonFormField<String>).at(0));
      await _tapVisible(tester, find.text('Ganadero').last);
      await _tapVisible(tester, find.text('Provincia'));
      await _tapVisible(tester, find.text('Azuay').last);
      await _tapVisible(tester, find.text('¿Para qué compras?'));
      await _tapVisible(tester, find.text('Cría').last);
      expect(find.widgetWithText(TextFormField, 'Nombre de la finca'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo'), 'Juan Pérez');
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'juan@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Teléfono'), '0991234567');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), 'Guayaquil');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la finca'), 'La Esperanza');
      await tester.enterText(find.widgetWithText(TextFormField, 'Tipo de ganado (bovino, porcino...)'), 'Bovino');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña (mínimo 8 caracteres)'), 'secreta123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Repite la contraseña'), 'secreta123');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));

      final sent = api.lastRegister!;
      expect(sent['user_type'], 'ganadero');
      expect(sent['nombre_finca'], 'La Esperanza');
      expect(sent['tipo_ganado'], 'Bovino');
      expect(sent['purchase_purpose'], 'cria');
      expect(sent.containsKey('profesion'), isFalse);
      await _close(tester);
    });
  });
}
