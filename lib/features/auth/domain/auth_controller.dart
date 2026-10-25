import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user_profile.dart';
import '../data/auth_repository.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return appSecureStorage;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage: storage);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConstants.isDemoMode) return DemoAuthRepository();
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepository(client: client, storage: storage);
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final repo = ref.watch(authRepositoryProvider);
    return AuthController(repo);
  },
);

/// Convenience provider — the authenticated user profile (null if not logged in)
final currentUserProvider = Provider<UserProfile?>((ref) {
  final state = ref.watch(authControllerProvider);
  return switch (state) {
    AuthAuthenticated a => a.user,
    _ => null,
  };
});

// ── Controller ───────────────────────────────────────────────────────────────

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthController(this._repo) : super(const AuthInitial()) {
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    if (AppConstants.isDemoMode) {
      state = const AuthUnauthenticated();
      return;
    }
    state = const AuthLoading();
    final token = await _repo.getSavedToken();
    if (token == null || token.isEmpty) {
      state = const AuthUnauthenticated();
      return;
    }
    final result = await _repo.getMe();
    switch (result) {
      case Success<UserProfile>(:final data):
        state = AuthAuthenticated(user: data, sessionToken: token);
      case Failure<UserProfile>():
        await _repo.clearSession();
        state = const AuthUnauthenticated();
    }
  }

  Future<bool> login(String email, String password) async {
    state = const AuthLoading();
    final result = await _repo.login(
      LoginRequest(email: email, password: password),
    );
    switch (result) {
      case Success<AuthResponse>(:final data):
        return _acceptAuthentication(data);
      case Failure<AuthResponse>(:final error):
        state = AuthError(error);
        return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = const AuthLoading();
    final result = await _repo.register(
      RegisterRequest(displayName: name, email: email, password: password),
    );
    switch (result) {
      case Success<AuthResponse>(:final data):
        return _acceptAuthentication(data);
      case Failure<AuthResponse>(:final error):
        state = AuthError(error);
        return false;
    }
  }

  /// Store the session and verify it with a protected endpoint before showing
  /// the signed-in area. This prevents a successful-looking login followed by
  /// every CRUD request failing because the token was not persisted/accepted.
  Future<bool> _acceptAuthentication(AuthResponse response) async {
    if (response.sessionToken.trim().isEmpty ||
        response.userId.trim().isEmpty) {
      state = const AuthError(
        ConfigurationError('Respons autentikasi tidak berisi sesi yang valid.'),
      );
      return false;
    }

    try {
      await _repo.saveSession(response);
      if (!AppConstants.isDemoMode) {
        final savedToken = await _repo.getSavedToken();
        if (savedToken != response.sessionToken) {
          await _repo.clearSession();
          state = const AuthError(
            StorageError(
              'Sesi gagal disimpan di perangkat. Coba masuk kembali.',
            ),
          );
          return false;
        }
      }

      final profileResult = await _repo.getMe();
      switch (profileResult) {
        case Success<UserProfile>(:final data):
          state = AuthAuthenticated(
            user: data,
            sessionToken: response.sessionToken,
          );
          return true;
        case Failure<UserProfile>(:final error):
          await _repo.clearSession();
          state = AuthError(error);
          return false;
      }
    } catch (_) {
      await _repo.clearSession();
      state = const AuthError(
        StorageError('Tidak dapat memverifikasi sesi di perangkat. Coba lagi.'),
      );
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    state = const AuthLoading();
    final result = await _repo.forgotPassword(email);
    switch (result) {
      case Success<bool>():
        state = const AuthUnauthenticated();
        return true;
      case Failure<bool>(:final error):
        state = AuthError(error);
        return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    await _repo.clearSession();
    state = const AuthUnauthenticated();
  }

  Future<bool> updateProfile(UserProfile updated) async {
    final current = state;
    if (current is! AuthAuthenticated) return false;
    if (AppConstants.isDemoMode) {
      state = AuthAuthenticated(
        user: updated,
        sessionToken: current.sessionToken,
      );
      return true;
    }
    final result = await _repo.updateProfile(
      displayName: updated.displayName,
      bio: updated.bio,
      photoUrl: updated.photoUrl,
    );
    switch (result) {
      case Success<UserProfile>(:final data):
        state = AuthAuthenticated(
          user: data,
          sessionToken: current.sessionToken,
        );
        return true;
      case Failure<UserProfile>(:final error):
        state = AuthError(error);
        return false;
    }
  }

  void clearError() {
    final current = state;
    if (current is AuthError) {
      state = const AuthUnauthenticated();
    }
  }
}
