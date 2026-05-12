import '../../../domain/entities/auth_user.dart';

abstract class AuthPort {
  Stream<AuthUser?> get onAuthStateChanged;
  Future<AuthUser?> signInWithEmail(String email, String password);
  Future<AuthUser?> signInWithGoogle();
  Future<void> signUpWithEmail(String email, String password);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<void> signOut();
}