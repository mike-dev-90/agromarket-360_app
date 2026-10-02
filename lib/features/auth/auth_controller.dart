import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.identityVerified,
    this.phone,
    this.whatsapp,
    this.address,
    this.city,
    this.state,
    this.purchasePurpose,
    this.userType = 'buyer',
    this.roles = const [],
    this.missingProfile = const [],
  });

  final int id;
  final String name;
  final String email;
  final bool identityVerified;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? city;
  final String? state;
  final String? purchasePurpose;
  final String userType;
  final List<String> roles;
  final List<String> missingProfile;

  bool hasRole(String role) => roles.contains(role);

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        identityVerified: json['identity_verified'] == true,
        phone: json['phone'] as String?,
        whatsapp: json['whatsapp'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        purchasePurpose: json['purchase_purpose'] as String?,
        userType: (json['user_type'] as String?) ?? 'buyer',
        roles: [for (final r in (json['roles'] as List? ?? const [])) '$r'],
        missingProfile: [for (final r in (json['missing_profile'] as List? ?? const [])) '$r'],
      );
}

/// Usuario autenticado (null = invitado). Carga la sesión guardada al arrancar.
class AuthController extends AsyncNotifier<AppUser?> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<AppUser?> build() async {
    final token = await _api.tokens.read();
    if (token == null) return null;
    try {
      final body = await _api.get('/auth/me');
      return AppUser.fromJson(body['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401) await _api.tokens.clear();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    final body = await _api.post('/auth/login', data: {'email': email, 'password': password, 'device_name': 'app-android'});
    await _saveSession(body);
  }

  Future<void> register(Map<String, String> data) async {
    final body = await _api.post('/auth/register', data: {...data, 'device_name': 'app-android'});
    await _saveSession(body);
  }

  /// Vuelve a pedir el usuario al servidor (p. ej. tras verificar identidad o editar el perfil).
  Future<void> refreshUser() async {
    final body = await _api.get('/profile');
    state = AsyncData(AppUser.fromJson(body['data'] as Map<String, dynamic>));
  }

  void setUser(Map<String, dynamic> json) => state = AsyncData(AppUser.fromJson(json));

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Si no hay red, igualmente se cierra la sesión local.
    }
    await _api.tokens.clear();
    state = const AsyncData(null);
  }

  Future<void> _saveSession(Map<String, dynamic> body) async {
    await _api.tokens.write(body['token'] as String);
    state = AsyncData(AppUser.fromJson(body['user'] as Map<String, dynamic>));
  }
}

final authProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);
