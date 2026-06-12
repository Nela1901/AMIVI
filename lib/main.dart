import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/adapters/out/ai/ai_detector_adapter.dart';
import 'src/adapters/out/persistence/firestore_adapter.dart';
import 'src/adapters/in/controllers/classification_controller.dart';
import 'src/application/usecases/classify_road_image_usecase.dart';
import 'src/application/usecases/save_inspection_usecase.dart';
import 'src/domain/entities/road_incidence.dart';
import 'src/domain/valueobjects/damage_level.dart';
import 'src/adapters/out/location/geolocator_adapter.dart';
import 'src/domain/constants/ai_thresholds.dart';
import 'src/adapters/out/auth/firebase_auth_adapter.dart';
import 'src/adapters/in/controllers/auth_controller.dart';
import 'src/adapters/in/views/map_screen.dart';
import 'src/adapters/out/persistence/local_storage_adapter.dart';
import 'src/adapters/in/views/inspection_detail_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  runApp(AMIVIApp());
}
//LA CLASE AMIVIApp ES EL PUNTO DE ENTRADA DE LA APLICACIÓN, 
//CONFIGURA LOS ADAPTERS Y USECASES, Y PROPORCIONA EL CONTROLADOR A LA UI.
class AMIVIApp extends StatelessWidget {
  const AMIVIApp({super.key});

//CONEXIÓN CON LA ARQUITECTURA HEXAGONAL: 
//INYECTAN LAS DEPENDENCIAS DE LOS ADAPTERS Y USECASES EN EL CONTROLADOR, 
  @override
  Widget build(BuildContext context) {
    final aiAdapter = AiDetectorAdapter();
    final firestoreAdapter = FirestoreAdapter();
    final locationAdapter = GeolocatorAdapter();
    // Instanciamos el adaptador para almacenamiento local (HU-17/18)
    final localAdapter = LocalStorageAdapter();
    
    final classifyUsecase = ClassifyRoadImageUsecase(aiAdapter);
    // Inyectamos el localAdapter en el caso de uso y en el controlador
    final saveUsecase = SaveInspectionUsecase(firestoreAdapter, localAdapter);
    final controller = ClassificationController(classifyUsecase, saveUsecase, locationAdapter, localAdapter);

    final authAdapter = FirebaseAuthAdapter();
    final authController = AuthController(authAdapter);

    return MaterialApp(
      title: 'AMIVI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF185FA5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: AuthWrapper(authController: authController, classificationController: controller),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final AuthController authController;
  final ClassificationController classificationController;

  const AuthWrapper({super.key, required this.authController, required this.classificationController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authController,
      builder: (context, _) {
        final user = FirebaseAuth.instance.currentUser;
        if (authController.status == AuthStatus.authenticated && (user?.emailVerified ?? false)) {
          return ClassificationScreen(controller: classificationController, authController: authController);
        }
        return LoginScreen(authController: authController);
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  final AuthController authController;
  const LoginScreen({super.key, required this.authController});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isUnverified = false;

  @override
  void initState() {
    super.initState();
    // Comprobar si ya hay un usuario logueado pero no verificado al iniciar
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      _isUnverified = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF185FA5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.map_outlined, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('AMIVI', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF185FA5))),
              const Text('Inspección Vial con IA', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 48),

              if (_isUnverified)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Debes verificar tu correo electrónico antes de ingresar. Revisa tu bandeja de entrada.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          try {
                            await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Correo de verificación reenviado.')),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error al reenviar: $e');
                          }
                        },
                        child: const Text('Reenviar correo de verificación', style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              
              if (widget.authController.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(widget.authController.errorMessage!, 
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),

              // Campos de Correo y Contraseña
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    widget.authController.resetError(); // Limpia errores previos
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ForgotPasswordScreen(authController: widget.authController)),
                    );
                  },
                  child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: Color(0xFF185FA5))),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.authController.status == AuthStatus.authenticating
                      ? null
                      : () async {
                          await widget.authController.loginWithEmail(
                                _emailController.text.trim(),
                                _passwordController.text.trim(),
                              );
                          
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await user.reload(); // Actualizar estado de verificación
                            if (mounted) {
                              if (!FirebaseAuth.instance.currentUser!.emailVerified) {
                                setState(() => _isUnverified = true);
                              } else {
                                setState(() => _isUnverified = false);
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF185FA5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('O', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              
              if (widget.authController.status == AuthStatus.authenticating)
                const Center(child: CircularProgressIndicator())
              else ...[
                _SocialButton(
                  label: 'Continuar con Google',
                  icon: Icons.login,
                  onPressed: () => widget.authController.loginWithGoogle(),
                  color: Colors.red[700]!,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿No tienes cuenta?'),
                  TextButton(
                    onPressed: () {
                      widget.authController.resetError(); // Limpia errores previos
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RegisterScreen(authController: widget.authController)),
                      );
                    },
                    child: const Text('Regístrate', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF185FA5))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final ClassificationController controller;
  const HistoryScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Historial de Inspecciones', 
            style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF185FA5)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Se asume la colección 'inspecciones' basada en el flujo de guardado del sistema
        stream: FirebaseFirestore.instance
            .collection('inspecciones')
            .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .orderBy('fechaHora', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar datos: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aún no tienes inspecciones registradas.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final date = (data['fechaHora'] as Timestamp?)?.toDate() ?? DateTime.now();
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // [HU-15 - Escenario 1]: Navegación al detalle de la incidencia.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InspectionDetailScreen(data: data, docId: docs[index].id),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: const Icon(Icons.analytics_outlined, color: Color(0xFF185FA5)),
                    title: Text('Daño: ${data['clase']?.toUpperCase() ?? 'N/A'}', 
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Fecha: ${date.day}/${date.month}/${date.year}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  final AuthController authController;
  const RegisterScreen({super.key, required this.authController});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hasMinLength = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final text = _passwordController.text;
    setState(() {
      _hasMinLength = text.length >= 8;
      _hasLowercase = text.contains(RegExp(r'[a-z]'));
      _hasNumber = text.contains(RegExp(r'[0-9]'));
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.removeListener(_validatePassword);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildValidationRow(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check : Icons.close,
            color: isValid ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isValid ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Cuenta')),
      body: AnimatedBuilder(
        animation: widget.authController,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                if (widget.authController.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(widget.authController.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                const Text('Completa tus datos para empezar', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildValidationRow('Mínimo 8 caracteres', _hasMinLength),
                    _buildValidationRow('Al menos una letra en minúscula', _hasLowercase),
                    _buildValidationRow('Al menos un número', _hasNumber),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Contraseña',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.authController.status == AuthStatus.authenticating
                        ? null
                        : () async {
                            if (_passwordController.text != _confirmPasswordController.text) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Las contraseñas no coinciden')),
                              );
                              return;
                            }
                            try {
                              await widget.authController.registerWithEmail(
                                _emailController.text.trim(),
                                _passwordController.text.trim(),
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('¡Registro exitoso! Verifica tu correo e inicia sesión.'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 5),
                                  ),
                                );
                                Navigator.pop(context); // Regresa al Login
                              }
                            } catch (e) {
                              // El error se muestra mediante el AnimatedBuilder
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185FA5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: widget.authController.status == AuthStatus.authenticating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Registrarse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  final AuthController authController;
  const ForgotPasswordScreen({super.key, required this.authController});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            if (widget.authController.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(widget.authController.errorMessage!, 
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            const Text(
              'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await widget.authController.recoverPassword(_emailController.text.trim());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correo de recuperación enviado')));
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    // Error manejado por el controller
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185FA5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Enviar Enlace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            ],
          ),
        ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _SocialButton({required this.label, required this.icon, required this.onPressed, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
//LA CLASE CLASSIFICATIONSCREEN ES LA INTERFAZ DE USUARIO PRINCIPAL,
//MUESTRA LA IMAGEN SELECCIONADA, LOS RESULTADOS DE LA CLASIFICACIÓN, 
//LOS BOTONES DE ACCIÓN, Y LOS MENSAJES DE ERROR O ÉXITO.

//EL STATEFUL WIDGET ESCUCHA LOS CAMBIOS EN EL CONTROLADOR Y RECONSTRUYE LA UI EN CONSECUENCIA.
class ClassificationScreen extends StatefulWidget {
  final ClassificationController controller;
  final AuthController authController;

  const ClassificationScreen({super.key, required this.controller, required this.authController});

  @override
  State<ClassificationScreen> createState() => _ClassificationScreenState();

}
//LA CLASE _ClassificationScreenState CONTIENE LA LÓGICA DE
//INTERACCIÓN CON EL USUARIO, COMO SELECCIONAR IMAGEN, MOSTRAR RESULTADOS, 
//MANEJAR ERRORES, Y MOSTRAR DIÁLOGOS DE CONFIRMACIÓN O EDICIÓN.

class _ClassificationScreenState extends State<ClassificationScreen> {
  Widget _buildDrawer(BuildContext context) {
    final user = widget.authController.currentUser;
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF185FA5)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: user?.photoUrl != null
                  ? ClipOval(child: Image.network(user!.photoUrl!))
                  : const Icon(Icons.person, color: Color(0xFF185FA5), size: 40),
            ),
            accountName: Text(user?.displayName ?? 'Usuario AMIVI',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(user?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFF185FA5)),
            title: const Text('Mis Inspecciones'),
            subtitle: const Text('Ver registros anteriores'),
            onTap: () {
              Navigator.pop(context); // Cerrar drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryScreen(controller: widget.controller)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: Color(0xFF185FA5)),
            title: const Text('Mapa Interactivo'),
            subtitle: const Text('Zonas afectadas en tiempo real'),
            onTap: () {
              Navigator.pop(context); // Cerrar drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MapScreen(controller: widget.controller)),
              );
            },
          ),
          // [HU-16/18]: Opción de sincronización manual para reportes guardados localmente
          if (widget.controller.pendingCount > 0)
            ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'PENDIENTES DE ENVÍO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_outlined, color: Color(0xFF185FA5)),
                title: const Text('Gestionar Pendientes'),
                subtitle: const Text('Ver y borrar reportes locales'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PendingReportsScreen(controller: widget.controller),
                    ),
                  );
                },
              ),
              ListTile(
                leading: widget.controller.syncStatus == SyncStatus.syncing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Badge(
                        backgroundColor: Colors.orange,
                        label: Text('${widget.controller.pendingCount}'),
                        child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF185FA5)),
                      ),
                title: const Text('Sincronizar ahora'),
                subtitle: Text(
                  widget.controller.syncStatus == SyncStatus.error 
                      ? 'Error en la sincronización' 
                      : 'Toca para subir ${widget.controller.pendingCount} registros',
                  style: TextStyle(
                    color: widget.controller.syncStatus == SyncStatus.error ? Colors.red : Colors.grey[600],
                    fontWeight: widget.controller.syncStatus == SyncStatus.error ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () async {
                  await widget.controller.syncPendingReports();
                  if (context.mounted && widget.controller.syncStatus == SyncStatus.completed) {
                    // [HU-16 - Escenario 1]: Notificación de éxito
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sincronización completada con éxito'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Cerrar Sesión'),
            onTap: () {
              Navigator.pop(context);
              widget.authController.logout();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  final ImagePicker _picker = ImagePicker();
  // [HU-IA-01] Umbral de confianza para sugerir validación manual
  static const double _minConfidenceForManualValidation = AiThresholds.manualValidationSuggestionThreshold; // 75%
//EL METODO PICKIMAGE SE ENCARGA DE ABRIR LA CÁMARA O LA GALERÍA, 
//MANEJAR LOS PERMISOS, Y ACTUALIZAR EL CONTROLADOR CON LA RUTA DE LA IMAGEN SELECCIONADA.
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source);
      
      if (file == null) return; // El usuario canceló la selección sin cerrar con error
      // [PMV1 - HU-04 - Escenario 1]: Captura exitosa desde cámara.
      // [PMV1 - HU-05 - Escenario 1]: Carga exitosa desde galería.
      widget.controller.setImagePath(file.path);
      
    } on PlatformException catch (e) {
      // [PMV1 - HU-04 - Escenario 2] y [PMV1 - HU-05 - Escenario 2]: El usuario deniega permisos o hay un error de acceso.
      //El sistema muestra mensaje indicando que no puede acceder.
      String message = 'No se pudo acceder a la ${source == ImageSource.camera ? 'cámara' : 'galería'}.';
      
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied' || e.code == 'access_denied' || e.code == 'camera_permission_denied') {
        message = '¡Atención! El permiso ha sido denegado. Actívalo en los ajustes del sistema para continuar.';
      }
      _showSnackBar(message, isError: true);
    } catch (e) {
      // [PMV1 - HU-05 - Escenario 2]: Error al cargar un archivo no compatible o corrupto.
      _showSnackBar('Error inesperado: ${e.toString()}', isError: true);
    }
  }

  // [HU-13/17]: Diálogo de éxito que limpia la interfaz para un nuevo flujo.
  void _showSuccessRegistrationDialog(BuildContext context, ClassificationController controller) {
    final bool isOffline = controller.savedDocumentId?.startsWith('offline_') ?? false;

    showDialog(
      context: context,
      barrierDismissible: false, // Obliga al usuario a interactuar con el botón
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isOffline ? Icons.cloud_off_outlined : Icons.check_circle_outline,
              color: const Color(0xFF3B6D11),
            ),
            const SizedBox(width: 10),
            const Text('Registro Exitoso'),
          ],
        ),
        content: Text(
          isOffline
              ? 'La inspección se guardó localmente en el dispositivo. Podrás sincronizarla después desde el menú lateral cuando tengas internet.'
              : 'La inspección ha sido registrada correctamente en la nube.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.reset(); // [HU-13]: Limpia todo para volver a registrar otra inspección
            },
            child: const Text('ACEPTAR', 
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF185FA5))),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showEditDialog(BuildContext context, ClassificationController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // [PMV1 - HU-13 - Escenario 1]: Interfaz para editar el resultado.
        title: const Text('Editar tipo de daño'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DamageLevel.values.map((level) {
            return ListTile(
              leading: Icon(_getIconDataForLevel(level), color: _getColorForLevel(level)),
              title: Text(level.label),
              onTap: () {
                controller.updateDamageLevel(level);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showDiscardConfirmationDialog(BuildContext context, ClassificationController controller) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // [PMV1 - HU-13 - Escenario 1]: Confirmación antes de descartar.
        title: const Text('Confirmar descarte'),
        content: const Text('¿Estás seguro de que quieres descartar esta inspección y comenzar una nueva? Se perderán los datos actuales.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // No descartar
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirmar descarte
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      controller.reset();
    }
  }

//SE DEFINE LA LÓGICA DE COLORES, ICONOS, Y ESTILOS PARA LOS DIFERENTES NIVELES DE DAÑO,
//ASÍ COMO LOS ESTADOS DE CARGA Y ERROR, PARA MANTENER LA CONSISTENCIA VISUAL 
//Y DE USABILIDAD EN LA INTERFAZ.


  // [PMV1 - HU-12 - Escenario 1]: Lógica de colores para visualización clara e interpretable.
  Color _getColorForLevel(DamageLevel level) {
    switch (level) {
      case DamageLevel.normal:
        return const Color(0xFF3B6D11);
      case DamageLevel.leve:
        return const Color(0xFF854F0B);
      case DamageLevel.danado:
        return const Color(0xFFA32D2D);
    }
  }

// [HU-12] Lógica de colores de fondo para una visualización clara e interpretable del resultado.
//COLORES DE FONDO MÁS SUAVES PARA LOS DIFERENTES NIVELES DE DAÑO,
//PROPORCIONANDO UN CONTRASTE ADECUADO CON EL TEXTO Y LOS ICONOS, 
//Y MEJORANDO LA LEGIBILIDAD DE LA INFORMACIÓN MOSTRADA.
  Color _getBgColorForLevel(DamageLevel level) {
    switch (level) {
      case DamageLevel.normal:
        return const Color(0xFFEAF3DE);
      case DamageLevel.leve:
        return const Color(0xFFFAEEDA);
      case DamageLevel.danado:
        return const Color(0xFFFCEBEB);
    }
  }
//SE ASOCIAN ICONOS SIMBÓLICOS PARA CADA NIVEL DE DAÑO, 
  // [HU-12] Lógica de iconos profesionales para una visualización clara e interpretable del resultado.
  IconData _getIconDataForLevel(DamageLevel level) {
    switch (level) {
      case DamageLevel.normal:
        return Icons.check_circle_outline;
      case DamageLevel.leve:
        return Icons.info_outline;
      case DamageLevel.danado:
        return Icons.error_outline;
    }
  }
//EL AnimatedBuilder ESCUCHA LOS CAMBIOS EN EL CONTROLADOR 
//Y RECONSTRUYE LA UI EN CONSECUENCIA, 
//MOSTRANDO LOS DATOS ACTUALIZADOS O LOS MENSAJES DE ERROR/ÉXITO SEGÚN CORRESPONDA.  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xFF185FA5)),
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF185FA5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map_outlined,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AMIVI',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF185FA5))),
                    Text('Inspección Vial Inteligente',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Color(0xFF185FA5)),
                onPressed: () => widget.authController.logout(),
                tooltip: 'Cerrar sesión',
              ),
            ],
          ),
          drawer: _buildDrawer(context),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Zona de imagen
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: controller.selectedImagePath != null
                          ? const Color(0xFF185FA5)
                          : const Color(0xFFDDE3ED),
                      width: controller.selectedImagePath != null ? 2 : 1,
                    ),
                  ),
                  child: controller.selectedImagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            File(controller.selectedImagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Este errorBuilder se activa si Image.file no puede cargar el archivo
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No se pudo cargar la imagen seleccionada.',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 14),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Selecciona o captura una imagen',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text('JPG, PNG recomendado',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 11)),
                          ],
                        ),
                ),
                const SizedBox(height: 12),

                // Botones selección
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined,
                            size: 18),
                        label: const Text('Galería'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF185FA5)),
                          foregroundColor: const Color(0xFF185FA5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Cámara'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF185FA5)),
                          foregroundColor: const Color(0xFF185FA5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Botón clasificar
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: controller.selectedImagePath != null &&
                                controller.state != ClassificationState.loading
                            // [PMV1 - HU-08 - Escenario 1]: El usuario solicita el análisis automático.
                            ? () => widget.controller.classify()
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF185FA5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: controller.state == ClassificationState.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Clasificar con IA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: controller.selectedImagePath != null &&
                                controller.state != ClassificationState.loading
                            // [HU-14 - Escenario 1]: Registro manual.
                            ? () => widget.controller.startManualRegistration()
                            : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: controller.selectedImagePath != null && controller.state != ClassificationState.loading
                                ? const Color(0xFF185FA5)
                                : Colors.grey.shade400,
                          ),
                          foregroundColor: const Color(0xFF185FA5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Manual', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Resultado
                if (controller.warningMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_off_outlined, color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Aviso: ${controller.warningMessage!}', style: const TextStyle(color: Color(0xFF663C00), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                if (controller.state == ClassificationState.success &&
                    controller.result != null)
                  // [PMV1 - HU-12 - Escenario 1]: Presentación del resultado interpretable.
                  _buildResult(controller.result!, controller),

                // Error clasificación
                if (controller.state == ClassificationState.error)
                  // [PMV1 - HU-12 - Escenario 2]: Resultado incompleto o error.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCEBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA32D2D), width: 1),
                    ),
                    child: Column( // [PMV1 - HU-13 - Escenario 2]: Resultado no editable por error.
                      // [HU-08 Escenario de Error] Mensaje de error si la clasificación falla.
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFA32D2D), size: 28),
                        const SizedBox(height: 8),
                        Text(
                          controller.errorMessage ?? 'Error desconocido',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFA32D2D), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'La edición y validación manual no están disponibles temporalmente porque no se pudo generar un resultado base.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFA32D2D), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
//EL MÉTODO _BUILDRESULT CONSTRUYE LA SECCIÓN DE RESULTADOS DE LA INTERFAZ, 
//MOSTRANDO EL NIVEL DE DAÑO DETECTADO,
  Widget _buildResult(
      RoadIncidence result, ClassificationController controller) {
    final color = _getColorForLevel(result.damageLevel);
    final bgColor = _getBgColorForLevel(result.damageLevel);
    final iconData = _getIconDataForLevel(result.damageLevel);

    // [PMV1 - HU-IA-01 - Escenario 1]: Clasificación automática exitosa con confianza.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card resultado
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // [PMV1 - HU-12 - Escenario 1]: Visualización del tipo de daño.
              Icon(iconData, size: 48, color: color),
              const SizedBox(height: 8),
              Text(result.damageLevel.label,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: color)),
              // [PMV1 - HU-12 - Escenario 1]: Visualización de la descripción clara.
              const SizedBox(height: 4),
              Text(result.damageLevel.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: color)),
              const SizedBox(height: 12),
              Text(
                'Confianza: ${(result.confidence * 100).toStringAsFixed(1)}%', 
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
              const SizedBox(height: 12),
              // [HU-07]: Visualización de metadatos (Fecha, Hora y Ubicación)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetadataTag(
                    Icons.calendar_today_outlined, 
                    '${result.detectedAt.day}/${result.detectedAt.month}/${result.detectedAt.year} ${result.detectedAt.hour.toString().padLeft(2, '0')}:${result.detectedAt.minute.toString().padLeft(2, '0')}',
                    color
                  ),
                  if (result.latitude != null && result.longitude != null)
                    _buildMetadataTag(
                      Icons.location_on_outlined,
                      '${result.latitude!.toStringAsFixed(4)}, ${result.longitude!.toStringAsFixed(4)}',
                      color
                    ),
                  if (controller.georefLatencyMs != null)
                    _buildMetadataTag(
                      Icons.speed_outlined,
                      'GPS: ${(controller.georefLatencyMs! / 1000).toStringAsFixed(1)}s',
                      color
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // [HU-07]: Campo de observaciones para enriquecer el reporte vial
        if (controller.saveState != SaveState.saved) ...[
          if (result.latitude == null || result.longitude == null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_location_alt_outlined, color: Colors.orange, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sin ubicación: Por seguridad, indica la dirección exacta o puntos de referencia en el campo de Observaciones.',
                      style: TextStyle(color: Color(0xFF663C00), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              onChanged: (value) => controller.setObservations(value),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Observaciones',
                hintText: 'Ej: Grieta profunda en carril derecho...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.edit_note_outlined),
              ),
            ),
          ),
        ],
        
        if (result.confidence < _minConfidenceForManualValidation)
          Container(
            // [PMV1 - HU-IA-01 - Escenario 2]: La baja confianza indica necesidad de validación manual.
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12), // Añadir margen inferior para separar del siguiente elemento
            decoration: BoxDecoration(
              color: const Color(0xFFFAEEDA), // Color de advertencia
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    color: Color(0xFF854F0B), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La confianza de la detección es baja. Se recomienda validación manual antes de registrar.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF854F0B)),
                  ),
                ),
              ],
            ),
          ),
        // Si la advertencia no se muestra, el SizedBox(height: 12) anterior ya proporciona el espaciado.
        // Si se muestra, el margin: const EdgeInsets.only(bottom: 12) ya lo hace.

        // Probabilidades
        Container(
          // [PMV1 - HU-12 - Escenario 1]: Atributos esperados (probabilidades).
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE3ED)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Probabilidades por clase',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey)),
              const SizedBox(height: 12),
              ...result.probabilities.entries.map((e) {
                final pct = e.value * 100;
                final barColor = _getColorForLevel(e.key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key.label,
                              style: const TextStyle(fontSize: 13)),
                          Text('${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: e.value,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(barColor),
                          minHeight: 7,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (result.gradcamPath != null)
          Container( // [PMV1 - HU-10 - Escenario 1]: Delimitación correcta resaltando la región.
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE3ED)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.thermostat_outlined,
                        color: Color(0xFFA32D2D), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Zona de mayor daño detectado',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA32D2D)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(result.gradcamPath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
                const SizedBox(height: 8),
                // Leyenda COLORMAP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(Colors.blue[700]!, 'Sin daño'),
                    const SizedBox(width: 12),
                    _buildLegendItem(Colors.green, 'Leve'),
                    const SizedBox(width: 12),
                    _buildLegendItem(Colors.orange, 'Moderado'),
                    const SizedBox(width: 12),
                    _buildLegendItem(const Color(0xFFA32D2D), 'Daño'),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            // [PMV1 - HU-10 - Escenario 2]: No se pudo representar visualmente la zona (resultado incompleto).
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAEEDA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    color: Color(0xFF854F0B), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No se pudo representar visualmente la zona afectada.',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF854F0B)),
                  ),
                ),
              ],
            ),
          ),
        // ── Fin HU-10 ─────────────────────────────────────────────────

        const SizedBox(height: 12),

        // Advertencia galería
        if (controller.selectedImagePath != null &&
            !controller.selectedImagePath!.contains('camera'))
          Container(
            // Contexto adicional para HU-05 (Imágenes de galería).
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAEEDA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: Color(0xFF854F0B), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La ubicación corresponde a tu posición actual, no a la de la foto.',
                    style:
                        TextStyle(fontSize: 11, color: Color(0xFF854F0B)),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // Botón registrar inspección y editar (HU-13)
        if (controller.saveState != SaveState.saved) ...[
          ElevatedButton.icon(
            onPressed: (controller.saveState == SaveState.saving || controller.selectedImagePath == null)
                ? null
                // [PMV1 - HU-13 - Escenario 1]: Acción de confirmar el resultado.
                : () async {
                    await controller.saveInspection();
                    // Al terminar con éxito, mostramos el diálogo de confirmación y limpieza
                    if (mounted && controller.saveState == SaveState.saved) {
                      _showSuccessRegistrationDialog(context, controller);
                    }
                  },
            icon: controller.saveState == SaveState.saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(
              controller.saveState == SaveState.saving
                  ? 'Registrando...'
                  : 'Registrar inspección',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F6E56),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.saveState == SaveState.saving
                ? null
                // [PMV1 - HU-13 - Escenario 1]: Acción de editar el resultado.
                : () => _showEditDialog(context, controller),
            icon: const Icon(Icons.edit_note_outlined, size: 18),
            label: const Text('Corregir detección manualmente'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.grey[400]!),
              foregroundColor: Colors.grey[700],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],

        // Error guardado
        if (controller.saveState == SaveState.error)
          // Error durante el proceso de guardado (HU-13).
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCEBEB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              controller.errorMessage ?? 'Error al registrar',
              style: const TextStyle(color: Color(0xFFA32D2D)),
            ),
          ),

        const SizedBox(height: 12),

        OutlinedButton(
          // [PMV1 - HU-13 - Escenario 1]: Acción de descartar el resultado.
          onPressed: () => _showDiscardConfirmationDialog(context, controller),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Color(0xFF185FA5)),
            foregroundColor: const Color(0xFF185FA5),
          ),
          child: const Text('Descartar y nueva inspección'),
        ),
      ],
    );
  }

  Widget _buildMetadataTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  // ── Widget leyenda colormap ─────────────────────────────────────────
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class PendingReportsScreen extends StatelessWidget {
  final ClassificationController controller;

  const PendingReportsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final reports = controller.pendingReportsList;
        final isAllSelected = reports.isNotEmpty && controller.selectedCount == reports.length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pendientes de Envío', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (reports.isNotEmpty)
                IconButton(
                  icon: Icon(isAllSelected ? Icons.check_box : Icons.check_box_outline_blank),
                  tooltip: 'Seleccionar todo',
                  onPressed: () => controller.toggleSelectAll(),
                ),
              if (reports.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  tooltip: 'Borrar seleccionados',
                  onPressed: controller.selectedCount > 0 ? () => _confirmDeleteSelected(context) : null,
                ),
            ],
          ),
          body: reports.isEmpty
              ? const Center(child: Text('No hay reportes pendientes.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final date = DateTime.parse(report['fechaHora']);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: CheckboxListTile(
                        value: controller.selectedIds.contains(report['id']),
                        onChanged: (_) => controller.toggleSelection(report['id']),
                        activeColor: const Color(0xFF185FA5),
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: const Icon(Icons.cloud_off, color: Colors.orange),
                        title: Text('Daño: ${report['clase']?.toUpperCase()}', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Fecha: ${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12)),
                      ),
                    );
                  },
                ),
          floatingActionButton: reports.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: controller.syncStatus == SyncStatus.syncing
                      ? null
                      : () => controller.syncPendingReports(
                            specificIds: controller.selectedCount > 0 ? controller.selectedIds.toList() : null,
                          ),
                  label: Text(controller.syncStatus == SyncStatus.syncing 
                      ? 'Sincronizando...' 
                      : (controller.selectedCount > 0 ? 'Subir Seleccionados (${controller.selectedCount})' : 'Sincronizar Todo')),
                  icon: controller.syncStatus == SyncStatus.syncing 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.sync),
                  backgroundColor: const Color(0xFF185FA5),
                  foregroundColor: Colors.white,
                )
              : null,
        );
      },
    );
  }

  void _confirmDeleteSelected(BuildContext context) {
    final count = controller.selectedCount;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Borrar $count reportes?'),
        content: const Text('Esta acción eliminará permanentemente los registros seleccionados del dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () async {
              for (var id in controller.selectedIds.toList()) {
                await controller.deletePendingReport(id);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('BORRAR', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
