import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../application/ports/output/auth_port.dart';
import '../../../domain/entities/auth_user.dart';

enum AuthStatus { authenticated, unauthenticated, authenticating }

class AuthController extends ChangeNotifier {
  final AuthPort _authPort;
  AuthUser? _currentUser;
  AuthStatus _status = AuthStatus.unauthenticated;
  String? _errorMessage;

  AuthController(this._authPort) {
    _authPort.onAuthStateChanged.listen((user) {
      _currentUser = user;
      _status = user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
      notifyListeners();
    });
  }

  AuthUser? get currentUser => _currentUser;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;

  void resetError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loginWithEmail(String email, String password) async {
    try {
      _errorMessage = null;
      _status = AuthStatus.authenticating;
      notifyListeners();
      await _authPort.signInWithEmail(email, password);
    } catch (e) {
      _errorMessage = _parseAuthError(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  String _parseAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Este correo electrónico ya está registrado. Intenta iniciar sesión.';
        case 'weak-password':
          return 'La contraseña es muy débil. Debe tener al menos 6 caracteres.';
        case 'invalid-email':
          return 'El formato del correo electrónico no es válido.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Usuario o contraseña incorrectos.';
        case 'network-request-failed':
          return 'Error de conexión. Verifica tu internet.';
        default:
          return e.message ?? 'Ocurrió un error inesperado.';
      }
    }
    return e.toString();
  }

  Future<void> registerWithEmail(String email, String password) async {
    try {
      _errorMessage = null;
      _status = AuthStatus.authenticating;
      notifyListeners();
      await _authPort.signUpWithEmail(email, password);
      await _authPort.sendEmailVerification();
      await _authPort.signOut(); // Cerramos sesión para obligar el login manual tras verificar
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = _parseAuthError(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendVerificationEmail() async {
    try {
      await _authPort.sendEmailVerification();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> recoverPassword(String email) async {
    try {
      _errorMessage = null;
      notifyListeners();
      await _authPort.sendPasswordResetEmail(email);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      _errorMessage = null;
      await _authPort.signInWithGoogle();
    } catch (e) {
      _errorMessage = _parseAuthError(e);
      notifyListeners();
    }
  }

  Future<void> logout() => _authPort.signOut();
}