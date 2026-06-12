# PLAN DE MEJORA FURPS+ - AMIVI
## Roadmap Incremental de Estabilización y Evolución

**Fecha de Elaboración:** 11 de junio de 2026  
**Arquitecto de Software:** Asistente IA - Especialista en Mejora Continua  
**Basado en:** Auditoría FURPS+ v1.0 (docs/01_auditoria_furps.md)  
**Versión del Plan:** 1.0  
**Horizonte Temporal:** 16 semanas (4 meses)

---

## PRINCIPIOS RECTORES DEL PLAN

### ⚠️ RESTRICCIÓN PRINCIPAL: EL SISTEMA YA FUNCIONA

Este plan asume que AMIVI **puede estar desplegado en producción** con usuarios activos. Por tanto, NINGUNA mejora debe:
- Interrumpir funcionalidades existentes
- Requerir downtime prolongado
- Forzar migración de datos sin backward compatibility
- Introducir cambios breaking en APIs o contratos

### 🛡️ Principios Obligatorios

| Principio | Definición | Aplicación |
|-----------|------------|------------|
| **Compatibilidad hacia atrás** | Versiones nuevas deben funcionar con datos antiguos | Versionado de schema, feature flags |
| **Cambios incrementales** | Mejoras en pequeños pasos validables | Sprints de 1-2 semanas máximo |
| **Riesgo mínimo** | Preferir cambios aislados sobre refactors masivos | Estratificación por capas |
| **Validación obligatoria** | Cada cambio debe tener criterios de aceptación | Tests + smoke tests en staging |
| **Posibilidad de rollback** | Toda mejora debe ser reversible en <1 hora | Feature toggles, blue-green deployment |

---

## ROADMAP GENERAL

### 📅 Estructura por Fases

```
┌─────────────────────────────────────────────────────────────────┐
│                    FASE 0: PREPARACIÓN                          │
│                        (Semana 1-2)                             │
│  • Configuración de entornos (dev/staging/prod)                │
│  • Setup de CI/CD básico                                       │
│  • Externalización de credenciales                             │
│  • Implementación de feature flags                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              FASE 1: ESTABILIZACIÓN CRÍTICA                     │
│                        (Semana 3-6)                             │
│  • Manejo de excepciones en capas críticas                     │
│  • Logging y monitoreo con Crashlytics                         │
│  • Suite de testing base (unit + integration)                  │
│  • Optimización de consumo de batería (GPS throttling)         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│            FASE 2: OPTIMIZACIÓN DE RENDIMIENTO                  │
│                        (Semana 7-10)                            │
│  • Algoritmo eficiente para hotspots (O(n) o O(n log n))      │
│  • Paginación en Firestore                                     │
│  • Caché de reverse geocoding                                  │
│  • Compresión de imágenes antes de upload                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│             FASE 3: REFACTORING Y MANTENIBILIDAD                │
│                        (Semana 11-13)                           │
│  • Extracción de screens desde main.dart                       │
│  • Constantes nombradas para magic numbers                     │
│  • Documentación inline de lógica compleja                     │
│  • Migración a DI framework (get_it)                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              FASE 4: NUEVAS CAPACIDADES                         │
│                        (Semana 14-16)                           │
│  • Notificaciones locales (HU-22 completo)                     │
│  • Internacionalización (español + inglés)                     │
│  • Accesibilidad básica (Semantics + contraste)                │
│  • Validación de duplicados en sincronización                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## MEJORAS PRIORIZADAS

### 🔴 PRIORIDAD CRÍTICA (Semana 1-6)

---

#### **MEJ-001: Externalización de Credenciales**

**Objetivo:**  
Migrar credenciales hardcoded (Cloudinary, Firebase) a variables de entorno para prevenir exposición accidental en repositorios públicos.

**Justificación:**  
- **Hallazgo:** Auditoría identifica `firestore_adapter.dart:11-12` con credenciales en código
- **Riesgo Actual:** Exposición pública = uso no autorizado de servicios = costos no controlados
- **Impacto:** Seguridad crítica

**Prioridad:** 🔴 **CRÍTICA**

**Riesgo de Implementación:** 🟢 **BAJO**
- No altera lógica de negocio
- Cambio localizado en 1 archivo
- No requiere migración de datos

**Dependencias:**
- Ninguna (puede ejecutarse de forma aislada)

**Estrategia de Validación:**
1. **Pre-cambio:**
   - Verificar que credenciales actuales funcionan en todos los ambientes
   - Documentar valores actuales en vault seguro (1Password, AWS Secrets Manager)

2. **Implementación:**
   ```yaml
   # pubspec.yaml - Agregar dependencia
   dependencies:
     flutter_dotenv: ^5.1.0
   ```

   ```dart
   // lib/src/adapters/out/persistence/firestore_adapter.dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';
   
   class FirestoreAdapter implements SaveInspectionPort {
     // ANTES (líneas 11-12):
     // static const String _cloudName = 'djeruiyop';
     // static const String _uploadPreset = 'amivi_preset';
     
     // DESPUÉS:
     static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME']!;
     static String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET']!;
   }
   ```

   ```env
   # .env (añadir a .gitignore)
   CLOUDINARY_CLOUD_NAME=djeruiyop
   CLOUDINARY_UPLOAD_PRESET=amivi_preset
   ```

   ```dart
   // main.dart - Cargar antes de runApp
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await dotenv.load(fileName: ".env"); // ← AGREGAR ESTA LÍNEA
     await Firebase.initializeApp();
     runApp(AMIVIApp());
   }
   ```

3. **Post-cambio:**
   - Smoke test: Subir 1 imagen de prueba en staging
   - Verificar que URL de Cloudinary se genera correctamente
   - Confirmar que `.env` NO está en repositorio Git

**Estrategia de Rollback:**
- **Trigger:** Upload de imagen falla consistentemente (>3 intentos)
- **Acción:** 
  1. Revertir commit con `git revert <hash>`
  2. Redeploy versión anterior (tiempo estimado: 5 minutos)
  3. Credenciales hardcoded vuelven a funcionar automáticamente
- **Sin impacto:** Los datos de usuarios no se ven afectados

**Criterios de Aceptación:**
- ✅ `.env` presente en `.gitignore`
- ✅ Credenciales **NO** aparecen en código fuente
- ✅ App se ejecuta en dev/staging/prod con credenciales desde `.env`
- ✅ Documentación actualizada con instrucciones de configuración

**Estimación:** 4 horas

---

#### **MEJ-002: Implementación de Feature Flags**

**Objetivo:**  
Configurar sistema de feature toggles para habilitar rollback instantáneo de mejoras sin redeployment.

**Justificación:**  
- **Necesidad:** Base para todas las mejoras posteriores
- **Beneficio:** Permite desactivar features problemáticas en <1 minuto
- **Estrategia de Riesgo:** Cumple principio de "Posibilidad de rollback"

**Prioridad:** 🔴 **CRÍTICA**

**Riesgo de Implementación:** 🟢 **BAJO**
- No afecta funcionalidad existente
- Capa adicional sin cambios en lógica

**Dependencias:**
- MEJ-001 (externalización de config)

**Estrategia de Validación:**
1. **Implementación:**
   ```yaml
   # pubspec.yaml
   dependencies:
     firebase_remote_config: ^5.0.0
   ```

   ```dart
   // lib/src/infrastructure/config/feature_flags.dart (NUEVO ARCHIVO)
   import 'package:firebase_remote_config/firebase_remote_config.dart';
   
   class FeatureFlags {
     static final FeatureFlags _instance = FeatureFlags._internal();
     factory FeatureFlags() => _instance;
     FeatureFlags._internal();
   
     late FirebaseRemoteConfig _remoteConfig;
     bool _initialized = false;
   
     Future<void> initialize() async {
       _remoteConfig = FirebaseRemoteConfig.instance;
       await _remoteConfig.setConfigSettings(RemoteConfigSettings(
         fetchTimeout: const Duration(seconds: 10),
         minimumFetchInterval: const Duration(minutes: 5),
       ));
       
       // Valores por defecto (fallback si Remote Config falla)
       await _remoteConfig.setDefaults({
         'enable_notifications': false,
         'enable_improved_hotspots': false,
         'enable_pagination': false,
         'gps_throttle_seconds': 30,
       });
       
       await _remoteConfig.fetchAndActivate();
       _initialized = true;
     }
   
     bool get notificationsEnabled => 
       _initialized ? _remoteConfig.getBool('enable_notifications') : false;
     
     bool get improvedHotspotsEnabled => 
       _initialized ? _remoteConfig.getBool('enable_improved_hotspots') : false;
     
     bool get paginationEnabled => 
       _initialized ? _remoteConfig.getBool('enable_pagination') : false;
     
     int get gpsThrottleSeconds => 
       _initialized ? _remoteConfig.getInt('gps_throttle_seconds') : 30;
   }
   ```

   ```dart
   // main.dart - Inicializar flags
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await dotenv.load(fileName: ".env");
     await Firebase.initializeApp();
     await FeatureFlags().initialize(); // ← AGREGAR
     runApp(AMIVIApp());
   }
   ```

2. **Configuración en Firebase Console:**
   - Crear parámetros en Remote Config
   - Configurar valores por ambiente (dev=true, prod=false para features nuevas)
   - Establecer reglas de targeting (ej: solo 10% de usuarios inicialmente)

3. **Validación:**
   - Cambiar flag en Firebase Console
   - Verificar que app refleja cambio en <5 minutos (sin redeployment)
   - Probar rollback: desactivar flag y confirmar que feature se oculta

**Estrategia de Rollback:**
- **Trigger:** RemoteConfig no carga (network issue)
- **Acción:** App usa valores por defecto (todas las features nuevas desactivadas)
- **Fallback:** Código legacy sigue funcionando sin interrupciones

**Criterios de Aceptación:**
- ✅ FeatureFlags inicializa sin errores
- ✅ Cambio de flag en Firebase se refleja en app sin redeploy
- ✅ Si RemoteConfig falla, app funciona con defaults
- ✅ Documentación de cómo agregar nuevos flags

**Estimación:** 6 horas

---

#### **MEJ-003: Manejo de Excepciones en Inferencia de IA**

**Objetivo:**  
Envolver ejecución de TFLite en try-catch robusto con fallback a modo manual para prevenir crashes durante clasificación.

**Justificación:**  
- **Hallazgo Crítico:** `ai_detector_adapter.dart:106` ejecuta `_interpreter!.run(input, output)` sin manejo de errores
- **Impacto Actual:** Crash silencioso si memoria insuficiente o modelo corrupto
- **Evidencia:** Auditoría clasifica como riesgo CRÍTICO

**Prioridad:** 🔴 **CRÍTICA**

**Riesgo de Implementación:** 🟡 **MEDIO**
- Modifica flujo crítico de clasificación
- Requiere testing exhaustivo de casos edge

**Dependencias:**
- MEJ-002 (feature flags para rollback)

**Estrategia de Validación:**
1. **Pre-cambio:**
   - Documentar flujo actual: `imagen → TFLite → resultado`
   - Crear test de carga: 100 clasificaciones consecutivas sin fallos

2. **Implementación:**
   ```dart
   // lib/src/adapters/out/ai/ai_detector_adapter.dart
   
   @override
   Future<RoadIncidence> classifyImage(String imagePath) async {
     await _loadModel();
     
     String safePath;
     img.Image? image;
   
     // ... código de persistImage existente ...
   
     try {
       final input = _preprocessImage(image);
       final output = List.filled(3, 0.0).reshape([1, 3]);
       
       // ← AGREGAR TRY-CATCH AQUÍ
       try {
         _interpreter!.run(input, output);
       } on StateError catch (e) {
         // Modelo no cargado o corrupto
         throw AiClassificationException(
           'El modelo de IA no se inicializó correctamente. Por favor, reinicia la app.',
           originalError: e,
           recoverable: false,
         );
       } on OutOfMemoryError catch (e) {
         // Dispositivo sin recursos
         throw AiClassificationException(
           'Memoria insuficiente para clasificar la imagen. Cierra otras apps e intenta nuevamente.',
           originalError: e,
           recoverable: true,
         );
       } catch (e) {
         // Error genérico de TFLite
         throw AiClassificationException(
           'Error inesperado al analizar la imagen. Intenta con el modo manual.',
           originalError: e,
           recoverable: true,
         );
       }
   
       final probabilities = List<double>.from(output[0] as List);
       // ... resto del código existente ...
       
     } on AiClassificationException {
       rethrow; // Propagar excepción personalizada
     } catch (e) {
       // Cualquier otro error (ej: imagen corrupta)
       throw AiClassificationException(
         'No fue posible procesar la imagen seleccionada.',
         originalError: e,
         recoverable: true,
       );
     }
   }
   ```

   ```dart
   // lib/src/domain/exceptions/ai_classification_exception.dart (NUEVO)
   class AiClassificationException implements Exception {
     final String userMessage;
     final dynamic originalError;
     final bool recoverable;
   
     AiClassificationException(
       this.userMessage, {
       this.originalError,
       this.recoverable = true,
     });
   
     @override
     String toString() => userMessage;
   }
   ```

   ```dart
   // lib/src/adapters/in/controllers/classification_controller.dart
   // Modificar método classify() para manejar nueva excepción
   
   Future<void> classify() async {
     // ... código existente ...
     
     try {
       final aiResult = await _classifyImagePort.execute(_selectedImagePath!);
       _result = _applyLocation(aiResult, lat, lng, address);
       _state = ClassificationState.success;
     } on AiClassificationException catch (e) {
       // ← AGREGAR MANEJO ESPECÍFICO
       _errorMessage = e.userMessage;
       _state = ClassificationState.error;
       
       // Si es recuperable, sugerir modo manual
       if (e.recoverable) {
         _warningMessage = 'Consejo: Puedes usar el botón "Manual" para registrar esta incidencia sin IA.';
       }
       
       // Log para monitoreo (será capturado por Crashlytics en MEJ-005)
       debugPrint('AiClassificationException: ${e.userMessage} | Original: ${e.originalError}');
       
     } catch (e) {
       _errorMessage = 'Error al clasificar: $e';
       _state = ClassificationState.error;
     }
   }
   ```

3. **Testing:**
   - **Caso 1:** Clasificación normal → debe funcionar igual que antes
   - **Caso 2:** Simular OutOfMemoryError → mostrar mensaje amigable + sugerencia de modo manual
   - **Caso 3:** Modelo corrupto (renombrar .tflite) → mensaje de reiniciar app
   - **Caso 4:** 50 clasificaciones consecutivas → todas deben manejarse sin crash

4. **Smoke Test en Staging:**
   - 10 inspectores beta realizan 20 clasificaciones cada uno
   - Monitorear crashes en Firebase Crashlytics (debe ser 0)

**Estrategia de Rollback:**
- **Trigger:** Tasa de error en clasificación >20% comparado con versión anterior
- **Acción:** 
  1. Desactivar feature flag `enable_improved_error_handling` en RemoteConfig
  2. App usa código legacy (sin try-catch adicional)
  3. Tiempo de rollback: <2 minutos
- **Fallback Automático:** Si try-catch nuevo falla, el catch exterior captura y mantiene comportamiento previo

**Criterios de Aceptación:**
- ✅ Clasificación exitosa funciona idéntico a versión anterior
- ✅ Error de memoria muestra mensaje amigable (no crash)
- ✅ Modelo corrupto muestra mensaje de reiniciar app
- ✅ Usuarios pueden continuar con modo manual después de error
- ✅ Logs de errores capturados para análisis

**Estimación:** 12 horas (incluye testing exhaustivo)

---

#### **MEJ-004: Logging Estructurado y Crashlytics**

**Objetivo:**  
Implementar sistema de logging con niveles (ERROR/WARN/INFO) y captura automática de crashes con Firebase Crashlytics.

**Justificación:**  
- **Hallazgo:** Auditoría identifica "Sin logs persistentes, imposible debuggear en producción"
- **Impacto:** Actualmente, errores en producción son invisibles
- **Beneficio:** Visibilidad operacional para detectar problemas antes que usuarios

**Prioridad:** 🔴 **CRÍTICA**

**Riesgo de Implementación:** 🟢 **BAJO**
- No altera comportamiento funcional
- Solo agrega instrumentación

**Dependencias:**
- MEJ-002 (feature flags)
- MEJ-003 (excepciones estructuradas para capturar)

**Estrategia de Validación:**
1. **Implementación:**
   ```yaml
   # pubspec.yaml
   dependencies:
     firebase_crashlytics: ^4.0.0
     logger: ^2.0.0
   ```

   ```dart
   // lib/src/infrastructure/logging/app_logger.dart (NUEVO)
   import 'package:logger/logger.dart';
   import 'package:firebase_crashlytics/firebase_crashlytics.dart';
   
   class AppLogger {
     static final AppLogger _instance = AppLogger._internal();
     factory AppLogger() => _instance;
     AppLogger._internal();
   
     late Logger _logger;
     late FirebaseCrashlytics _crashlytics;
   
     void initialize() {
       _logger = Logger(
         printer: PrettyPrinter(
           methodCount: 2,
           errorMethodCount: 8,
           lineLength: 120,
           colors: true,
           printEmojis: true,
           printTime: true,
         ),
       );
   
       _crashlytics = FirebaseCrashlytics.instance;
       
       // Captura automática de errores no manejados
       FlutterError.onError = _crashlytics.recordFlutterFatalError;
       PlatformDispatcher.instance.onError = (error, stack) {
         _crashlytics.recordError(error, stack, fatal: true);
         return true;
       };
     }
   
     void info(String message, {Map<String, dynamic>? context}) {
       _logger.i(message);
       if (context != null) {
         _crashlytics.log('INFO: $message | Context: $context');
       }
     }
   
     void warning(String message, {Map<String, dynamic>? context}) {
       _logger.w(message);
       _crashlytics.log('WARN: $message');
       if (context != null) {
         for (var entry in context.entries) {
           _crashlytics.setCustomKey(entry.key, entry.value);
         }
       }
     }
   
     void error(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? context}) {
       _logger.e(message, error: error, stackTrace: stackTrace);
       
       // Enviar a Crashlytics solo si es error significativo
       if (error != null) {
         _crashlytics.recordError(error, stackTrace, reason: message, fatal: false);
       }
       
       if (context != null) {
         for (var entry in context.entries) {
           _crashlytics.setCustomKey(entry.key, entry.value);
         }
       }
     }
   
     void setUserId(String userId) {
       _crashlytics.setUserIdentifier(userId);
     }
   }
   ```

   ```dart
   // main.dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await dotenv.load(fileName: ".env");
     await Firebase.initializeApp();
     AppLogger().initialize(); // ← AGREGAR
     await FeatureFlags().initialize();
     runApp(AMIVIApp());
   }
   ```

2. **Reemplazar debugPrint existente:**
   ```dart
   // ANTES:
   debugPrint('POC UC-IA-12: Error/Timeout en georreferenciación: $e');
   
   // DESPUÉS:
   AppLogger().error(
     'Error en georreferenciación',
     error: e,
     context: {
       'use_case': 'UC-IA-12',
       'operation': 'getCurrentLocation',
       'timeout_seconds': 3,
     },
   );
   ```

3. **Instrumentar operaciones críticas:**
   - Clasificación de IA (inicio, éxito, fallo)
   - Upload de imágenes (inicio, progreso, éxito, fallo)
   - Sincronización de reportes offline
   - Autenticación (login, logout, errores)

4. **Configurar alertas en Firebase Console:**
   - Email/Slack cuando crashrate >2%
   - Alerta si error específico se repite >10 veces/hora

**Estrategia de Rollback:**
- **Trigger:** Crashlytics reporta loop infinito de logs (performance degradation)
- **Acción:** 
  1. Desactivar flag `enable_enhanced_logging`
  2. App vuelve a `debugPrint` simple
  3. Tiempo: <1 minuto

**Criterios de Aceptación:**
- ✅ Logs con timestamp y nivel visible en consola dev
- ✅ Crashes automáticamente reportados a Firebase Console
- ✅ Contexto personalizado (userId, operación) visible en Crashlytics
- ✅ Alertas configuradas y funcionando
- ✅ Performance de la app no degradada (overhead <5ms por log)

**Estimación:** 10 horas

---

#### **MEJ-005: Throttling de GPS para Optimizar Batería**

**Objetivo:**  
Reducir consumo de batería implementando throttling inteligente en monitoreo continuo de ubicación (actualmente cada 10m).

**Justificación:**  
- **Hallazgo Crítico:** `classification_controller.dart:310-324` usa `distanceFilter: 10` (actualización cada 10 metros)
- **Impacto:** GPS en alta precisión constantemente drena batería en 3-4 horas
- **Riesgo de Negocio:** Usuarios desinstalan la app por mal rendimiento

**Prioridad:** 🔴 **CRÍTICA**

**Riesgo de Implementación:** 🟡 **MEDIO**
- Modifica comportamiento de alertas de proximidad (HU-22)
- Requiere balance entre precisión y eficiencia

**Dependencias:**
- MEJ-002 (feature flags para ajustar distanceFilter remotamente)

**Estrategia de Validación:**
1. **Análisis Pre-cambio:**
   - Medir consumo de batería actual con app en foreground/background (2 horas de prueba)
   - Baseline: Drenaje de X% por hora

2. **Implementación:**
   ```dart
   // lib/src/adapters/in/controllers/classification_controller.dart
   
   void _startLocationMonitoring() {
     _locationPort.getCurrentLocation().then((_) {
       
       // ← AGREGAR LÓGICA DE THROTTLING
       final featureFlags = FeatureFlags();
       final int throttleSeconds = featureFlags.gpsThrottleSeconds; // Default: 30s
       final int distanceFilterMeters = throttleSeconds < 20 ? 10 : 50; // Si throttle corto → precisión alta
       
       final LocationSettings settings;
       
       // Detectar si app está en foreground o background
       if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
         // Foreground: Mayor precisión
         settings = LocationSettings(
           accuracy: LocationAccuracy.high,
           distanceFilter: distanceFilterMeters, // 10m o 50m según config
           timeLimit: Duration(seconds: throttleSeconds),
         );
       } else {
         // Background: Conservar batería
         settings = LocationSettings(
           accuracy: LocationAccuracy.medium, // ← CAMBIO DE high → medium
           distanceFilter: 100, // Actualizar cada 100m en background
           timeLimit: Duration(seconds: 60), // Max 1 actualización por minuto
         );
       }
       
       _positionSubscription = Geolocator.getPositionStream(
         locationSettings: settings,
       ).listen((Position position) {
         _userLocation = (latitude: position.latitude, longitude: position.longitude, address: null);
         _userAddress = null;
         
         // ← AGREGAR DEBOUNCING PARA _checkForCriticalIncidents
         _debouncedCheckIncidents();
         
         notifyListeners();
       }, onError: (e) {
         AppLogger().warning('Error en position stream', context: {'error': e.toString()});
         _warningMessage = 'No se pudo mantener la ubicación en tiempo real para alertas.';
         notifyListeners();
       });
     }).catchError((e) {
       AppLogger().error('Fallo inicial de ubicación para monitoreo', error: e);
     });
   }
   
   Timer? _incidentCheckTimer;
   void _debouncedCheckIncidents() {
     // Evitar ejecutar query de Firestore en cada actualización GPS
     _incidentCheckTimer?.cancel();
     _incidentCheckTimer = Timer(const Duration(seconds: 5), () {
       _checkForCriticalIncidents();
     });
   }
   ```

3. **Ajustar lógica de lifecycle:**
   ```dart
   // Agregar listener de ciclo de vida de la app
   @override
   void didChangeAppLifecycleState(AppLifecycleState state) {
     if (state == AppLifecycleState.paused) {
       // Usuario sale de la app → reducir frecuencia GPS
       _positionSubscription?.cancel();
       _startLocationMonitoring(); // Reiniciar con settings de background
     } else if (state == AppLifecycleState.resumed) {
       // Usuario regresa → aumentar precisión
       _positionSubscription?.cancel();
       _startLocationMonitoring(); // Reiniciar con settings de foreground
     }
   }
   ```

4. **Testing:**
   - **Prueba de Batería (2 horas con app activa):**
     - Versión antigua: X% de drenaje/hora
     - Versión nueva: Objetivo <70% del drenaje anterior
   - **Prueba de Alertas:**
     - Simular usuario acercándose a zona crítica
     - Verificar que alerta se activa dentro de 500m (tolerancia aceptable)
   - **Prueba de Background:**
     - Dejar app en background por 30 minutos
     - Verificar que GPS no mantiene alta precisión constantemente

5. **A/B Testing:**
   - 50% de usuarios beta con throttle activado
   - Comparar métricas:
     - Tasa de desinstalación
     - Duración de sesión promedio
     - Cantidad de alertas generadas (no debe bajar >10%)

**Estrategia de Rollback:**
- **Trigger:** Alertas de proximidad bajan >25% o quejas de usuarios >10% de la base
- **Acción:** 
  1. Cambiar `gps_throttle_seconds` a 10 en RemoteConfig
  2. App recupera comportamiento de alta frecuencia
  3. Tiempo: Instantáneo (sin redeploy)

**Criterios de Aceptación:**
- ✅ Consumo de batería reducido en ≥30% comparado con baseline
- ✅ Alertas de proximidad funcionan dentro de 500m de zona crítica
- ✅ App responde a cambios de foreground/background
- ✅ Configuración de throttle ajustable vía RemoteConfig
- ✅ Logs de ubicación incluyen accuracy y distanceFilter usados

**Estimación:** 16 horas

---

#### **MEJ-006: Suite de Testing Base (Unit + Integration)**

**Objetivo:**  
Implementar cobertura mínima de tests (30% inicialmente) para casos de uso críticos, adaptadores y lógica de negocio.

**Justificación:**  
- **Hallazgo Crítico:** Auditoría identifica cobertura de 0%, estado CRÍTICO
- **Impacto:** Sin tests, cualquier cambio puede introducir regresiones silenciosas
- **Necesidad:** Base para todas las mejoras futuras

**Prioridad:** 🔴 **CRÍTICA**

**Riesgo de Implementación:** 🟢 **BAJO**
- No altera código de producción
- Solo agrega validaciones paralelas

**Dependencias:**
- Ninguna (tests se pueden escribir retroactivamente)

**Estrategia de Validación:**
1. **Priorización de Tests (por ROI):**
   
   **Orden 1: Unit Tests para Casos de Uso**
   ```dart
   // test/unit/application/usecases/classify_road_image_usecase_test.dart
   import 'package:flutter_test/flutter_test.dart';
   import 'package:mockito/mockito.dart';
   import 'package:mockito/annotations.dart';
   
   @GenerateMocks([AiDetectorPort])
   void main() {
     late ClassifyRoadImageUsecase usecase;
     late MockAiDetectorPort mockAiDetector;
   
     setUp(() {
       mockAiDetector = MockAiDetectorPort();
       usecase = ClassifyRoadImageUsecase(mockAiDetector);
     });
   
     group('ClassifyRoadImageUsecase', () {
       test('should call AiDetectorPort with correct imagePath', () async {
         // Arrange
         const testPath = '/path/to/image.jpg';
         final mockIncidence = RoadIncidence(
           id: '123',
           imagePath: testPath,
           damageLevel: DamageLevel.leve,
           confidence: 0.85,
           probabilities: {},
           detectedAt: DateTime.now(),
         );
         when(mockAiDetector.classifyImage(testPath))
             .thenAnswer((_) async => mockIncidence);
   
         // Act
         final result = await usecase.execute(testPath);
   
         // Assert
         expect(result, equals(mockIncidence));
         verify(mockAiDetector.classifyImage(testPath)).called(1);
       });
   
       test('should throw ArgumentError when imagePath is empty', () async {
         // Arrange
         const emptyPath = '';
   
         // Act & Assert
         expect(
           () => usecase.execute(emptyPath),
           throwsA(isA<ArgumentError>()),
         );
         verifyNever(mockAiDetector.classifyImage(any));
       });
   
       test('should propagate exception from AiDetectorPort', () async {
         // Arrange
         const testPath = '/path/to/image.jpg';
         when(mockAiDetector.classifyImage(testPath))
             .thenThrow(AiClassificationException('Model error'));
   
         // Act & Assert
         expect(
           () => usecase.execute(testPath),
           throwsA(isA<AiClassificationException>()),
         );
       });
     });
   }
   ```

   **Orden 2: Unit Tests para Servicios de Dominio**
   ```dart
   // test/unit/domain/services/road_safety_service_test.dart
   void main() {
     late RoadSafetyService service;
   
     setUp(() {
       service = RoadSafetyService();
     });
   
     group('RoadSafetyService - determineUrgency', () {
       test('should return verificationRequired when confidence < 0.65', () {
         final urgency = service.determineUrgency(DamageLevel.danado, 0.60);
         expect(urgency, equals(UrgencyLevel.verificationRequired));
       });
   
       test('should return critical when danado + confidence > 0.85', () {
         final urgency = service.determineUrgency(DamageLevel.danado, 0.90);
         expect(urgency, equals(UrgencyLevel.critical));
       });
   
       test('should return high when danado + confidence 0.65-0.85', () {
         final urgency = service.determineUrgency(DamageLevel.danado, 0.75);
         expect(urgency, equals(UrgencyLevel.high));
       });
   
       test('should return low for normal damage', () {
         final urgency = service.determineUrgency(DamageLevel.normal, 0.95);
         expect(urgency, equals(UrgencyLevel.low));
       });
     });
   
     group('RoadSafetyService - shouldTriggerEmergencyAlert', () {
       test('should return true only for critical urgency', () {
         expect(service.shouldTriggerEmergencyAlert(DamageLevel.danado, 0.90), true);
         expect(service.shouldTriggerEmergencyAlert(DamageLevel.danado, 0.75), false);
         expect(service.shouldTriggerEmergencyAlert(DamageLevel.leve, 0.95), false);
       });
     });
   }
   ```

   **Orden 3: Integration Tests para Adaptadores**
   ```dart
   // test/integration/adapters/out/persistence/local_storage_adapter_test.dart
   void main() {
     late LocalStorageAdapter adapter;
     late Directory tempDir;
   
     setUp(() async {
       adapter = LocalStorageAdapter();
       tempDir = await Directory.systemTemp.createTemp('amivi_test');
       // Mock path_provider para usar directorio temporal
     });
   
     tearDown(() async {
       await tempDir.delete(recursive: true);
     });
   
     group('LocalStorageAdapter - saveOffline', () {
       test('should save incidence to local JSON file', () async {
         // Arrange
         final incidence = RoadIncidence(
           id: 'test-123',
           imagePath: '/path/image.jpg',
           damageLevel: DamageLevel.leve,
           confidence: 0.80,
           probabilities: {},
           detectedAt: DateTime.now(),
           latitude: -12.0,
           longitude: -75.0,
         );
   
         // Act
         await adapter.saveOffline(
           incidence,
           incidence.imagePath,
           direccion: 'Test St',
           observaciones: 'Test notes',
         );
   
         // Assert
         final reports = await adapter.getAllPendingReports();
         expect(reports.length, 1);
         expect(reports[0]['id'], 'test-123');
         expect(reports[0]['clase'], 'leve');
       });
   
       test('should append to existing reports without overwriting', () async {
         // ... test de no sobrescritura ...
       });
     });
   }
   ```

2. **Configurar CI/CD para ejecutar tests:**
   ```yaml
   # .github/workflows/flutter_test.yml (NUEVO)
   name: Flutter Tests
   on: [push, pull_request]
   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - uses: subosito/flutter-action@v2
           with:
             flutter-version: '3.11.4'
         - run: flutter pub get
         - run: flutter test --coverage
         - name: Upload coverage to Codecov
           uses: codecov/codecov-action@v3
           with:
             files: ./coverage/lcov.info
   ```

3. **Meta de Cobertura Incremental:**
   - **Fase 1 (Semana 3-4):** 30% cobertura (casos de uso + servicios dominio)
   - **Fase 2 (Semana 5-6):** 50% cobertura (agregar adaptadores)
   - **Fase 3 (Semana 7+):** 70% cobertura (UI tests críticos)

**Estrategia de Rollback:**
- No aplica (tests no afectan producción)
- Si CI falla, bloquear merge pero no afecta deploy actual

**Criterios de Aceptación:**
- ✅ 30% cobertura de código mínima
- ✅ Tests de casos de uso con mocks funcionando
- ✅ Tests de servicios de dominio 100% cubiertos
- ✅ CI ejecuta tests automáticamente en cada PR
- ✅ Badge de cobertura visible en README

**Estimación:** 40 horas (distribuidas en 2 semanas)

---

### 🟡 PRIORIDAD ALTA (Semana 7-10)

---

#### **MEJ-007: Optimización de Algoritmo de Hotspots (O(n²) → O(n log n))**

**Objetivo:**  
Reemplazar algoritmo cuadrático de detección de hotspots por clustering eficiente (DBSCAN o quadtree) para soportar >1000 incidencias.

**Justificación:**  
- **Hallazgo:** `map_screen.dart:252-267` tiene nested loops O(n²)
- **Impacto:** Con 500 incidencias → 250,000 comparaciones → lag visible
- **Escalabilidad:** Bloqueante para crecimiento

**Prioridad:** 🟡 **ALTA**

**Riesgo de Implementación:** 🟡 **MEDIO**
- Cambia lógica de visualización de hotspots
- Requiere validación de que resultados sean equivalentes

**Dependencias:**
- MEJ-002 (feature flag `enable_improved_hotspots`)
- MEJ-006 (tests para validar equivalencia)

**Estrategia de Validación:**
1. **Análisis de Performance Actual:**
   - Benchmark con dataset de 100, 500, 1000 incidencias
   - Registrar tiempo de ejecución de `_updateHotspots`

2. **Implementación:**
   ```dart
   // lib/src/domain/services/hotspot_clustering_service.dart (NUEVO)
   import 'dart:math' as math;
   
   class HotspotClusteringService {
     final double _radiusKm;
     final int _minPoints;
   
     HotspotClusteringService({
       double radiusKm = 0.2, // 200 metros por defecto
       int minPoints = 2,
     })  : _radiusKm = radiusKm,
           _minPoints = minPoints;
   
     /// Algoritmo DBSCAN simplificado para clustering geoespacial
     List<Cluster> findClusters(List<RoadIncidence> incidents) {
       final List<Cluster> clusters = [];
       final Set<String> visited = {};
       final Set<String> clustered = {};
   
       for (var incident in incidents) {
         if (visited.contains(incident.id)) continue;
         visited.add(incident.id);
   
         final neighbors = _getNeighbors(incident, incidents);
   
         if (neighbors.length >= _minPoints) {
           // Nuevo cluster
           final cluster = Cluster(
             center: (lat: incident.latitude!, lng: incident.longitude!),
             members: [incident],
           );
   
           _expandCluster(incident, neighbors, cluster, incidents, visited, clustered);
           clusters.add(cluster);
         }
       }
   
       return clusters;
     }
   
     List<RoadIncidence> _getNeighbors(RoadIncidence center, List<RoadIncidence> all) {
       return all.where((inc) {
         if (inc.latitude == null || inc.longitude == null) return false;
         if (center.latitude == null || center.longitude == null) return false;
         
         final distance = _calculateDistance(
           center.latitude!, center.longitude!,
           inc.latitude!, inc.longitude!,
         );
         
         return distance <= _radiusKm;
       }).toList();
     }
   
     void _expandCluster(
       RoadIncidence seed,
       List<RoadIncidence> neighbors,
       Cluster cluster,
       List<RoadIncidence> all,
       Set<String> visited,
       Set<String> clustered,
     ) {
       final queue = List<RoadIncidence>.from(neighbors);
   
       while (queue.isNotEmpty) {
         final current = queue.removeAt(0);
   
         if (!visited.contains(current.id)) {
           visited.add(current.id);
           final currentNeighbors = _getNeighbors(current, all);
   
           if (currentNeighbors.length >= _minPoints) {
             queue.addAll(currentNeighbors);
           }
         }
   
         if (!clustered.contains(current.id)) {
           cluster.members.add(current);
           clustered.add(current.id);
         }
       }
     }
   
     double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
       // Fórmula de Haversine (copiada de classification_controller.dart)
       var p = 0.017453292519943295;
       var c = math.cos;
       var a = 0.5 - c((lat2 - lat1) * p) / 2 + 
             c(lat1 * p) * c(lat2 * p) * 
             (1 - c((lon2 - lon1) * p)) / 2;
       return 12742 * math.asin(math.sqrt(a));
     }
   }
   
   class Cluster {
     final ({double lat, double lng}) center;
     final List<RoadIncidence> members;
   
     Cluster({required this.center, required this.members});
   
     int get size => members.length;
   }
   ```

   ```dart
   // lib/src/adapters/in/views/map_screen.dart
   void _updateHotspots(List<RoadIncidence> incidents) {
     _circles.clear();
     
     // ← AGREGAR FEATURE FLAG
     if (!FeatureFlags().improvedHotspotsEnabled) {
       // Usar algoritmo legacy (O(n²))
       _updateHotspotsLegacy(incidents);
       return;
     }
     
     // NUEVO ALGORITMO
     final safetyService = RoadSafetyService();
     final criticalIncidents = incidents.where((inc) => 
       safetyService.shouldTriggerEmergencyAlert(inc.damageLevel, inc.confidence)
     ).toList();
     
     final clusteringService = HotspotClusteringService(radiusKm: 0.2, minPoints: 2);
     final clusters = clusteringService.findClusters(criticalIncidents);
     
     for (var cluster in clusters) {
       _circles.add(Circle(
         circleId: CircleId('cluster_${cluster.center.lat}_${cluster.center.lng}'),
         center: LatLng(cluster.center.lat, cluster.center.lng),
         radius: 120,
         fillColor: Colors.red.withOpacity(0.35),
         strokeColor: Colors.red.withOpacity(0.6),
         strokeWidth: 2,
       ));
     }
   }
   
   // Preservar algoritmo anterior para rollback
   void _updateHotspotsLegacy(List<RoadIncidence> incidents) {
     // ... código original O(n²) ...
   }
   ```

3. **Testing de Equivalencia:**
   ```dart
   // test/unit/domain/services/hotspot_clustering_service_test.dart
   void main() {
     test('DBSCAN produces same hotspots as legacy algorithm', () {
       // Arrange: Dataset fijo de 50 incidencias
       final incidents = _generateTestIncidents(50);
       
       // Act: Ejecutar ambos algoritmos
       final legacyHotspots = _computeHotspotsLegacy(incidents);
       final dbscanClusters = HotspotClusteringService().findClusters(incidents);
       
       // Assert: Cantidad de hotspots debe ser similar (±10%)
       expect(dbscanClusters.length, closeTo(legacyHotspots.length, 5));
       
       // Verificar que clusters contienen incidencias críticas
       for (var cluster in dbscanClusters) {
         expect(cluster.size, greaterThanOrEqualTo(2));
       }
     });
     
     test('DBSCAN completes in <100ms for 1000 incidents', () {
       final incidents = _generateTestIncidents(1000);
       
       final stopwatch = Stopwatch()..start();
       final clusters = HotspotClusteringService().findClusters(incidents);
       stopwatch.stop();
       
       expect(stopwatch.elapsedMilliseconds, lessThan(100));
       expect(clusters, isNotEmpty);
     });
   }
   ```

4. **A/B Testing en Producción:**
   - 20% de usuarios con `enable_improved_hotspots=true`
   - Métricas a comparar:
     - Tiempo de renderizado del mapa (objetivo: <100ms)
     - Cantidad de hotspots mostrados (debe ser similar a legacy)
     - Crashes relacionados con mapa (debe ser 0)

**Estrategia de Rollback:**
- **Trigger:** Tiempo de render >500ms o cantidad de hotspots difiere >30% del algoritmo legacy
- **Acción:** 
  1. Cambiar `enable_improved_hotspots` a `false` en RemoteConfig
  2. App usa `_updateHotspotsLegacy` automáticamente
  3. Tiempo: <1 minuto

**Criterios de Aceptación:**
- ✅ Benchmark: 1000 incidencias procesadas en <100ms
- ✅ Tests unitarios confirman equivalencia funcional
- ✅ Hotspots mostrados son visualmente correctos en staging
- ✅ A/B test muestra mejora de ≥70% en performance
- ✅ Código legacy preservado para rollback

**Estimación:** 20 horas

---

#### **MEJ-008: Paginación en Queries de Firestore**

**Objetivo:**  
Implementar infinite scroll con paginación en historial de inspecciones y carga lazy de marcadores en mapa.

**Justificación:**  
- **Hallazgo:** `main.dart:252` carga todas las inspecciones sin `.limit()`
- **Impacto Actual:** Con 1000+ registros, app se congela
- **Riesgo de Escalabilidad:** Bloqueante para producción real

**Prioridad:** 🟡 **ALTA**

**Riesgo de Implementación:** 🟡 **MEDIO**
- Cambia comportamiento de UI (scroll infinito)
- Usuarios podrían notar diferencia en tiempo de carga inicial

**Dependencias:**
- MEJ-002 (feature flag `enable_pagination`)
- MEJ-006 (tests de regresión)

**Estrategia de Validación:**
1. **Implementación para Historial:**
   ```dart
   // lib/src/adapters/in/views/history_screen.dart (EXTRAER DE main.dart)
   class HistoryScreen extends StatefulWidget {
     // ... código existente ...
   }
   
   class _HistoryScreenState extends State<HistoryScreen> {
     static const int _pageSize = 20; // Cargar 20 inspecciones por página
     
     List<DocumentSnapshot> _inspections = [];
     DocumentSnapshot? _lastDocument;
     bool _isLoading = false;
     bool _hasMore = true;
     final ScrollController _scrollController = ScrollController();
   
     @override
     void initState() {
       super.initState();
       _loadInitialInspections();
       _scrollController.addListener(_onScroll);
     }
   
     void _onScroll() {
       if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
         // Usuario llegó al 80% del scroll → cargar más
         if (!_isLoading && _hasMore) {
           _loadMoreInspections();
         }
       }
     }
   
     Future<void> _loadInitialInspections() async {
       setState(() => _isLoading = true);
       
       final query = FirebaseFirestore.instance
           .collection('inspecciones')
           .orderBy('fechaHora', descending: true)
           .limit(_pageSize); // ← AGREGAR LÍMITE
       
       final snapshot = await query.get();
       
       setState(() {
         _inspections = snapshot.docs;
         _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
         _hasMore = snapshot.docs.length == _pageSize;
         _isLoading = false;
       });
     }
   
     Future<void> _loadMoreInspections() async {
       if (_lastDocument == null) return;
       
       setState(() => _isLoading = true);
       
       final query = FirebaseFirestore.instance
           .collection('inspecciones')
           .orderBy('fechaHora', descending: true)
           .startAfterDocument(_lastDocument!) // ← CONTINUAR DESDE ÚLTIMO
           .limit(_pageSize);
       
       final snapshot = await query.get();
       
       setState(() {
         _inspections.addAll(snapshot.docs);
         _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
         _hasMore = snapshot.docs.length == _pageSize;
         _isLoading = false;
       });
     }
   
     @override
     Widget build(BuildContext context) {
       return Scaffold(
         appBar: AppBar(title: const Text('Historial de Inspecciones')),
         body: ListView.builder(
           controller: _scrollController,
           itemCount: _inspections.length + (_hasMore ? 1 : 0),
           itemBuilder: (context, index) {
             if (index == _inspections.length) {
               // Mostrar loader al final
               return const Center(
                 child: Padding(
                   padding: EdgeInsets.all(16.0),
                   child: CircularProgressIndicator(),
                 ),
               );
             }
             
             final doc = _inspections[index];
             final data = doc.data() as Map<String, dynamic>;
             // ... renderizar card de inspección ...
           },
         ),
       );
     }
   
     @override
     void dispose() {
       _scrollController.dispose();
       super.dispose();
     }
   }
   ```

2. **Implementación para Mapa (Viewport-based Loading):**
   ```dart
   // lib/src/adapters/in/views/map_screen.dart
   Stream<List<RoadIncidence>> getFilteredInspectionsStream() {
     Query<Map<String, dynamic>> query = FirebaseFirestore.instance
         .collection('inspecciones')
         .orderBy('fechaHora', descending: true);
     
     // ← AGREGAR LÍMITE GLOBAL PARA MAPA
     if (FeatureFlags().paginationEnabled) {
       query = query.limit(500); // Max 500 marcadores en mapa por performance
     }
     
     return query.snapshots().map((snapshot) {
       // ... código de transformación existente ...
     });
   }
   ```

3. **Testing:**
   - **Caso 1:** DB con 5 inspecciones → debe cargar todas sin paginación
   - **Caso 2:** DB con 100 inspecciones → debe cargar 20 inicialmente, resto on-demand
   - **Caso 3:** Scroll rápido hasta el final → debe cargar todas las páginas sin duplicados
   - **Caso 4:** Mapa con 1000 inspecciones → debe cargar máx 500 y no congelarse

4. **Smoke Test:**
   - Insertar 500 inspecciones de prueba en Firestore staging
   - Verificar que historial carga en <2s
   - Hacer scroll hasta el final → todas las inspecciones deben aparecer
   - Mapa debe renderizar en <3s

**Estrategia de Rollback:**
- **Trigger:** Usuarios reportan inspecciones faltantes o duplicadas
- **Acción:** 
  1. Desactivar `enable_pagination` en RemoteConfig
  2. App vuelve a query sin `.limit()`
  3. Tiempo: <1 minuto

**Criterios de Aceptación:**
- ✅ Historial carga 20 inspecciones inicialmente en <2s
- ✅ Scroll infinito funciona sin duplicados
- ✅ Mapa limita a 500 marcadores máximo
- ✅ Tests de regresión confirman no hay pérdida de datos
- ✅ Performance en dispositivos gama baja (Android 10) aceptable

**Estimación:** 16 horas

---

#### **MEJ-009: Caché de Reverse Geocoding**

**Objetivo:**  
Implementar caché en memoria y persistente para resultados de reverse geocoding, reduciendo llamadas a Google Maps API.

**Justificación:**  
- **Hallazgo:** `geolocator_adapter.dart:56-68` ejecuta geocoding siempre sin memoización
- **Impacto:** Desperdicio de cuota de API + latencia innecesaria
- **ROI:** Reducción de costos operativos

**Prioridad:** 🟡 **ALTA**

**Riesgo de Implementación:** 🟢 **BAJO**
- No altera comportamiento visible para usuario
- Solo optimización interna

**Dependencias:**
- Ninguna (independiente)

**Estrategia de Validación:**
1. **Implementación:**
   ```dart
   // lib/src/adapters/out/location/geocoding_cache.dart (NUEVO)
   import 'dart:convert';
   import 'package:shared_preferences/shared_preferences.dart';
   
   class GeocodingCache {
     static final GeocodingCache _instance = GeocodingCache._internal();
     factory GeocodingCache() => _instance;
     GeocodingCache._internal();
   
     // Caché en memoria (session cache)
     final Map<String, CachedAddress> _memoryCache = {};
     
     // Precisión de caché: coordenadas redondeadas a 4 decimales (~11m)
     String _cacheKey(double lat, double lng) => 
       '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
   
     Future<String?> get(double lat, double lng) async {
       final key = _cacheKey(lat, lng);
       
       // 1. Verificar caché en memoria
       if (_memoryCache.containsKey(key)) {
         final cached = _memoryCache[key]!;
         if (!cached.isExpired()) {
           AppLogger().info('Geocoding: hit from memory cache', 
             context: {'lat': lat, 'lng': lng});
           return cached.address;
         } else {
           _memoryCache.remove(key);
         }
       }
       
       // 2. Verificar caché persistente
       final prefs = await SharedPreferences.getInstance();
       final json = prefs.getString('geocache_$key');
       if (json != null) {
         try {
           final cached = CachedAddress.fromJson(jsonDecode(json));
           if (!cached.isExpired()) {
             _memoryCache[key] = cached; // Promover a memoria
             AppLogger().info('Geocoding: hit from disk cache',
               context: {'lat': lat, 'lng': lng});
             return cached.address;
           } else {
             await prefs.remove('geocache_$key');
           }
         } catch (e) {
           AppLogger().warning('Error al parsear geocache', 
             context: {'error': e.toString()});
         }
       }
       
       return null; // Cache miss
     }
   
     Future<void> put(double lat, double lng, String address) async {
       final key = _cacheKey(lat, lng);
       final cached = CachedAddress(
         address: address,
         timestamp: DateTime.now(),
         ttl: const Duration(days: 30), // Direcciones raramente cambian
       );
       
       // Guardar en memoria
       _memoryCache[key] = cached;
       
       // Guardar en disco
       final prefs = await SharedPreferences.getInstance();
       await prefs.setString('geocache_$key', jsonEncode(cached.toJson()));
       
       AppLogger().info('Geocoding: cached', 
         context: {'lat': lat, 'lng': lng, 'address': address});
     }
   
     Future<void> clearExpired() async {
       // Limpiar caché en memoria
       _memoryCache.removeWhere((key, value) => value.isExpired());
       
       // Limpiar caché persistente
       final prefs = await SharedPreferences.getInstance();
       final keys = prefs.getKeys().where((k) => k.startsWith('geocache_'));
       for (var key in keys) {
         try {
           final json = prefs.getString(key);
           if (json != null) {
             final cached = CachedAddress.fromJson(jsonDecode(json));
             if (cached.isExpired()) {
               await prefs.remove(key);
             }
           }
         } catch (_) {
           await prefs.remove(key); // Remover corrupto
         }
       }
     }
   }
   
   class CachedAddress {
     final String address;
     final DateTime timestamp;
     final Duration ttl;
   
     CachedAddress({
       required this.address,
       required this.timestamp,
       required this.ttl,
     });
   
     bool isExpired() => DateTime.now().difference(timestamp) > ttl;
   
     Map<String, dynamic> toJson() => {
       'address': address,
       'timestamp': timestamp.toIso8601String(),
       'ttl_seconds': ttl.inSeconds,
     };
   
     factory CachedAddress.fromJson(Map<String, dynamic> json) {
       return CachedAddress(
         address: json['address'],
         timestamp: DateTime.parse(json['timestamp']),
         ttl: Duration(seconds: json['ttl_seconds']),
       );
     }
   }
   ```

   ```dart
   // lib/src/adapters/out/location/geolocator_adapter.dart
   @override
   Future<({double latitude, double longitude, String? address})> getCurrentLocation() async {
     // ... código existente hasta obtener Position ...
     
     // [HU-07]: Implementación de Reverse Geocoding con CACHÉ
     String? address;
     try {
       // ← AGREGAR VERIFICACIÓN DE CACHÉ
       address = await GeocodingCache().get(position.latitude, position.longitude);
       
       if (address == null) {
         // Cache miss → hacer llamada a API
         List<Placemark> placemarks = await placemarkFromCoordinates(
           position.latitude, 
           position.longitude
         );
         
         if (placemarks.isNotEmpty) {
           final p = placemarks.first;
           address = "${p.street}, ${p.locality}";
           
           // Guardar en caché para futuras consultas
           await GeocodingCache().put(position.latitude, position.longitude, address);
         }
       }
     } catch (e) {
       AppLogger().error('Error en Geocoding', error: e);
     }
     
     return (latitude: position.latitude, longitude: position.longitude, address: address);
   }
   ```

2. **Testing:**
   - **Caso 1:** Primera consulta de ubicación → debe llamar a API
   - **Caso 2:** Segunda consulta de misma ubicación → debe usar caché (sin llamada a API)
   - **Caso 3:** Consulta de ubicación cercana (<11m) → debe usar caché
   - **Caso 4:** Caché expirado (>30 días) → debe renovar con llamada a API

3. **Métricas de Éxito:**
   - Hit rate de caché ≥70% después de 1 semana de uso
   - Reducción de costos de Google Maps API ≥60%
   - Latencia de geocoding reducida de ~500ms a <10ms en hits

**Estrategia de Rollback:**
- **Trigger:** Direcciones incorrectas reportadas por usuarios (caché corrupto)
- **Acción:** 
  1. Llamar a `GeocodingCache().clearAll()`
  2. Desactivar caché en siguiente release
  3. Tiempo: <5 minutos

**Criterios de Aceptación:**
- ✅ Caché en memoria funciona correctamente
- ✅ Caché persistente sobrevive a cierre de app
- ✅ Direcciones cached son precisas (validar con 100 ubicaciones)
- ✅ Cleanup automático de entradas expiradas
- ✅ Logs de hit/miss visibles en analytics

**Estimación:** 12 horas

---

### 🟢 PRIORIDAD MEDIA (Semana 11-13)

---

#### **MEJ-010: Refactorización de main.dart (1629 → <300 líneas)**

**Objetivo:**  
Extraer 5 screens desde `main.dart` a archivos independientes, reduciendo complejidad y mejorando mantenibilidad.

**Justificación:**  
- **Hallazgo:** `main.dart` contiene 1629 líneas, dificultando colaboración
- **Impacto:** Merge conflicts frecuentes, difícil navegación en código
- **Beneficio:** Mejor organización, facilita onboarding de nuevos devs

**Prioridad:** 🟢 **MEDIA**

**Riesgo de Implementación:** 🟢 **BAJO**
- No altera lógica, solo reorganiza archivos
- Cambio puramente estructural

**Dependencias:**
- MEJ-006 (tests para detectar regresiones)

**Estrategia de Validación:**
1. **Plan de Extracción:**
   ```
   main.dart (1629 líneas)
     ↓
   main.dart (100 líneas) - Solo inicialización
   ├─ lib/src/adapters/in/views/
   │  ├─ login_screen.dart (150 líneas)
   │  ├─ register_screen.dart (120 líneas)
   │  ├─ forgot_password_screen.dart (80 líneas)
   │  ├─ classification_screen.dart (600 líneas)
   │  ├─ history_screen.dart (200 líneas)
   │  └─ pending_reports_screen.dart (150 líneas)
   └─ lib/src/adapters/in/widgets/
      ├─ social_button.dart (30 líneas)
      └─ metadata_tag.dart (25 líneas)
   ```

2. **Proceso Incremental (1 screen por commit):**
   
   **Paso 1: Extraer LoginScreen**
   ```dart
   // lib/src/adapters/in/views/login_screen.dart (NUEVO)
   import 'package:flutter/material.dart';
   import '../controllers/auth_controller.dart';
   
   class LoginScreen extends StatefulWidget {
     final AuthController authController;
     const LoginScreen({super.key, required this.authController});
   
     @override
     State<LoginScreen> createState() => _LoginScreenState();
   }
   
   class _LoginScreenState extends State<LoginScreen> {
     // ... copiar código de main.dart líneas 84-233 ...
   }
   ```
   
   ```dart
   // main.dart - Reemplazar clase inline por import
   import 'src/adapters/in/views/login_screen.dart'; // ← AGREGAR
   
   // Eliminar class LoginScreen extends StatefulWidget { ... }
   // (líneas 84-233)
   ```

   **Paso 2-6: Repetir para RegisterScreen, ForgotPasswordScreen, etc.**

3. **Validación Post-Extracción:**
   - **Tests de Humo:**
     - Login con email/password → debe funcionar
     - Registro de nuevo usuario → debe funcionar
     - Recuperación de contraseña → debe funcionar
     - Clasificación de imagen → debe funcionar
     - Historial → debe funcionar
   
   - **Tests de Regresión:**
     - Ejecutar suite completa de tests
     - Todas las pruebas deben pasar sin cambios
   
   - **Revisión Manual:**
     - Hot reload funciona correctamente
     - No hay imports circulares
     - Navegación entre screens intacta

**Estrategia de Rollback:**
- **Trigger:** Algún screen no funciona después de extracción
- **Acción:** 
  1. `git revert <commit-hash>` del screen problemático
  2. Restaurar código inline en main.dart
  3. Tiempo: <5 minutos

**Criterios de Aceptación:**
- ✅ `main.dart` reducido a <300 líneas
- ✅ Cada screen en archivo independiente <700 líneas
- ✅ Todos los tests pasan
- ✅ Hot reload funciona sin errores
- ✅ Documentación actualizada con nueva estructura

**Estimación:** 16 horas

---

#### **MEJ-011: Constantes Nombradas para Magic Numbers**

**Objetivo:**  
Reemplazar valores hardcoded (0.65, 0.5, 75%, etc.) por constantes nombradas con documentación de justificación.

**Justificación:**  
- **Hallazgo:** Auditoría identifica múltiples magic numbers sin explicación
- **Impacto:** Dificulta ajustes y entendimiento de umbrales
- **Mantenibilidad:** Cambios futuros requieren búsqueda manual

**Prioridad:** 🟢 **MEDIA**

**Riesgo de Implementación:** 🟢 **BAJO**
- No altera valores, solo los centraliza
- Cambio de refactoring puro

**Dependencias:**
- Ninguna

**Estrategia de Validación:**
1. **Identificación de Magic Numbers:**
   ```dart
   // ANTES:
   if (confidence < 0.65) // ← ¿Por qué 0.65?
   if (distance < 0.5)    // ← ¿Por qué 0.5 km?
   if (densityCount >= 2) // ← ¿Por qué 2?
   static const double _minConfidenceForManualValidation = 0.75; // ← Mejor, pero sin doc
   ```

2. **Implementación:**
   ```dart
   // lib/src/domain/constants/ai_thresholds.dart (NUEVO)
   
   /// Umbrales de confianza para el modelo de IA de clasificación vial.
   /// 
   /// Estos valores fueron determinados mediante validación empírica
   /// sobre el dataset de entrenamiento (500 imágenes, 3 clases).
   class AiThresholds {
     AiThresholds._(); // Prevent instantiation
     
     /// Umbral mínimo de confianza para considerar una predicción válida.
     /// 
     /// **Valor:** 65%
     /// **Justificación:** Evaluación en test set mostró que predicciones
     /// con confidence <65% tienen tasa de error >30%. Este umbral balancea
     /// precision (85%) y recall (78%).
     /// **Fuente:** Análisis de matriz de confusión en notebook de entrenamiento.
     static const double minimumConfidenceThreshold = 0.65;
     
     /// Umbral de confianza para sugerir validación manual al usuario.
     /// 
     /// **Valor:** 75%
     /// **Justificación:** Usuarios reportan mayor confianza en resultados
     /// cuando la IA supera este umbral. Valor intermedio reduce falsos positivos
     /// sin incrementar significativamente carga de validación manual.
     static const double manualValidationSuggestionThreshold = 0.75;
     
     /// Umbral de confianza para alertas críticas automáticas.
     /// 
     /// **Valor:** 85%
     /// **Justificación:** Solo predicciones con >85% de confianza en clase
     /// "Dañado" disparan alertas a autoridades. Este umbral minimiza falsos
     /// positivos (precision >95% en clase crítica).
     static const double emergencyAlertThreshold = 0.85;
   }
   ```

   ```dart
   // lib/src/domain/constants/geo_thresholds.dart (NUEVO)
   
   /// Umbrales geográficos para clustering y alertas de proximidad.
   class GeoThresholds {
     GeoThresholds._();
     
     /// Radio de búsqueda para considerar dos incidencias como cercanas.
     /// 
     /// **Valor:** 200 metros
     /// **Justificación:** Distancia típica de un bloque urbano. Permite
     /// detectar múltiples baches en misma vía sin agrupar calles paralelas.
     static const double hotspotRadiusKm = 0.2; // 200 metros
     
     /// Mínimo de incidencias críticas en radio para formar un hotspot.
     /// 
     /// **Valor:** 2 incidencias
     /// **Justificación:** Balance entre sensibilidad (detectar zonas problema)
     /// y especificidad (evitar ruido por incidencias aisladas).
     static const int hotspotMinIncidents = 2;
     
     /// Radio de proximidad para alertas de navegación.
     /// 
     /// **Valor:** 500 metros
     /// **Justificación:** Distancia suficiente para que conductor/ciclista
     /// pueda tomar ruta alternativa con seguridad (30s a 60 km/h).
     static const double proximityAlertRadiusKm = 0.5; // 500 metros
   }
   ```

   ```dart
   // lib/src/domain/constants/performance_config.dart (NUEVO)
   
   /// Configuraciones de performance y optimización de recursos.
   class PerformanceConfig {
     PerformanceConfig._();
     
     /// Timeout para adquisición de ubicación GPS.
     /// 
     /// **Valor:** 3 segundos
     /// **Justificación:** KPI definido en UC-IA-12. Balancea precisión
     /// con experiencia de usuario. Si excede, usa última ubicación conocida.
     static const Duration gpsTimeout = Duration(seconds: 3);
     
     /// Intervalo de actualización de ubicación en foreground.
     /// 
     /// **Valor:** 30 segundos
     /// **Justificación:** Balance entre batería y precisión de alertas.
     /// Actualización más frecuente drena batería significativamente.
     static const Duration locationUpdateIntervalForeground = Duration(seconds: 30);
     
     /// Intervalo de actualización de ubicación en background.
     /// 
     /// **Valor:** 60 segundos
     /// **Justificación:** Conservación de batería es prioridad cuando
     /// usuario no interactúa activamente con la app.
     static const Duration locationUpdateIntervalBackground = Duration(seconds: 60);
     
     /// Tamaño de página para queries paginadas de Firestore.
     /// 
     /// **Valor:** 20 registros
     /// **Justificación:** Compromiso entre cantidad de datos iniciales
     /// (tiempo de carga <2s) y frecuencia de requests adicionales.
     static const int firestorePageSize = 20;
     
     /// Máximo de marcadores en mapa simultáneamente.
     /// 
     /// **Valor:** 500 marcadores
     /// **Justificación:** Límite de performance en Google Maps Flutter.
     /// Más marcadores causan lag en dispositivos gama media/baja.
     static const int maxMapMarkers = 500;
   }
   ```

3. **Reemplazo en Código:**
   ```dart
   // ANTES (road_safety_service.dart):
   if (confidence < 0.65) {
     return UrgencyLevel.verificationRequired;
   }
   
   // DESPUÉS:
   import '../../constants/ai_thresholds.dart';
   
   if (confidence < AiThresholds.minimumConfidenceThreshold) {
     return UrgencyLevel.verificationRequired;
   }
   ```

4. **Testing:**
   - Tests unitarios no deben cambiar (valores numéricos iguales)
   - Verificar que todas las referencias a magic numbers usan constantes
   - Lint rule: agregar regla que alerta sobre números hardcoded

**Estrategia de Rollback:**
- No aplica (no cambia comportamiento funcional)
- Si algo falla, es un bug de refactoring simple de revertir

**Criterios de Aceptación:**
- ✅ Todos los magic numbers críticos reemplazados por constantes
- ✅ Cada constante tiene JSDoc con justificación
- ✅ Tests pasan sin cambios
- ✅ Documentación de umbrales agregada a README

**Estimación:** 8 horas

---

#### **MEJ-012: Migración a Dependency Injection con GetIt**

**Objetivo:**  
Reemplazar inyección manual de dependencias por framework automático (GetIt) para facilitar testing y escalabilidad.

**Justificación:**  
- **Hallazgo:** Auditoría sugiere "Migrar a `get_it` para DI automático"
- **Beneficio:** Simplifica creación de mocks, centraliza configuración
- **Escalabilidad:** Necesario para agregar más adaptadores sin tocar main.dart

**Prioridad:** 🟢 **MEDIA**

**Riesgo de Implementación:** 🟡 **MEDIO**
- Refactoring estructural moderado
- Requiere cambios en múltiples archivos

**Dependencias:**
- MEJ-010 (screens separadas)
- MEJ-006 (tests para validar equivalencia)

**Estrategia de Validación:**
1. **Implementación:**
   ```yaml
   # pubspec.yaml
   dependencies:
     get_it: ^7.6.0
   ```

   ```dart
   // lib/src/infrastructure/di/service_locator.dart (NUEVO)
   import 'package:get_it/get_it.dart';
   import '../../adapters/out/ai/ai_detector_adapter.dart';
   import '../../adapters/out/persistence/firestore_adapter.dart';
   import '../../adapters/out/persistence/local_storage_adapter.dart';
   import '../../adapters/out/location/geolocator_adapter.dart';
   import '../../adapters/out/auth/firebase_auth_adapter.dart';
   import '../../application/usecases/classify_road_image_usecase.dart';
   import '../../application/usecases/save_inspection_usecase.dart';
   import '../controllers/auth_controller.dart';
   import '../controllers/classification_controller.dart';
   
   final getIt = GetIt.instance;
   
   /// Configuración centralizada de dependencias.
   /// 
   /// **Orden de registro:**
   /// 1. Adaptadores (singleton) - instancia compartida
   /// 2. Use cases (factory) - nueva instancia por llamada
   /// 3. Controllers (singleton) - estado compartido
   Future<void> setupServiceLocator() async {
     // ─── Adaptadores Out (Singleton) ───
     getIt.registerLazySingleton<AiDetectorAdapter>(
       () => AiDetectorAdapter(),
     );
     
     getIt.registerLazySingleton<FirestoreAdapter>(
       () => FirestoreAdapter(),
     );
     
     getIt.registerLazySingleton<LocalStorageAdapter>(
       () => LocalStorageAdapter(),
     );
     
     getIt.registerLazySingleton<GeolocatorAdapter>(
       () => GeolocatorAdapter(),
     );
     
     getIt.registerLazySingleton<FirebaseAuthAdapter>(
       () => FirebaseAuthAdapter(),
     );
     
     // ─── Use Cases (Factory) ───
     getIt.registerFactory<ClassifyRoadImageUsecase>(
       () => ClassifyRoadImageUsecase(getIt<AiDetectorAdapter>()),
     );
     
     getIt.registerFactory<SaveInspectionUsecase>(
       () => SaveInspectionUsecase(
         getIt<FirestoreAdapter>(),
         getIt<LocalStorageAdapter>(),
       ),
     );
     
     // ─── Controllers (Singleton) ───
     getIt.registerLazySingleton<AuthController>(
       () => AuthController(getIt<FirebaseAuthAdapter>()),
     );
     
     getIt.registerLazySingleton<ClassificationController>(
       () => ClassificationController(
         getIt<ClassifyRoadImageUsecase>(),
         getIt<SaveInspectionUsecase>(),
         getIt<GeolocatorAdapter>(),
         getIt<LocalStorageAdapter>(),
       ),
     );
   }
   
   /// Configuración para testing con mocks.
   /// 
   /// Permite sobrescribir dependencias reales con mocks.
   void setupTestServiceLocator({
     AiDetectorAdapter? mockAiAdapter,
     FirestoreAdapter? mockFirestoreAdapter,
     // ... otros mocks ...
   }) {
     getIt.reset(); // Limpiar registros previos
     
     if (mockAiAdapter != null) {
       getIt.registerLazySingleton<AiDetectorAdapter>(() => mockAiAdapter);
     } else {
       getIt.registerLazySingleton<AiDetectorAdapter>(() => AiDetectorAdapter());
     }
     
     // ... registrar resto con mocks o reales ...
   }
   ```

   ```dart
   // main.dart - SIMPLIFICADO
   import 'src/infrastructure/di/service_locator.dart';
   
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await dotenv.load(fileName: ".env");
     await Firebase.initializeApp();
     AppLogger().initialize();
     await FeatureFlags().initialize();
     
     // ← REEMPLAZAR INYECCIÓN MANUAL POR GETIT
     await setupServiceLocator(); // Una sola línea
     
     runApp(const AMIVIApp());
   }
   
   class AMIVIApp extends StatelessWidget {
     const AMIVIApp({super.key});
   
     @override
     Widget build(BuildContext context) {
       // ANTES:
       // final aiAdapter = AiDetectorAdapter();
       // final firestoreAdapter = FirestoreAdapter();
       // ... 10 líneas de setup ...
       
       // DESPUÉS:
       final authController = getIt<AuthController>();
       final classificationController = getIt<ClassificationController>();
       
       return MaterialApp(
         // ... resto igual ...
         home: AuthWrapper(
           authController: authController,
           classificationController: classificationController,
         ),
       );
     }
   }
   ```

2. **Testing con Mocks:**
   ```dart
   // test/unit/application/usecases/classify_road_image_usecase_test.dart
   @GenerateMocks([AiDetectorAdapter])
   void main() {
     late ClassifyRoadImageUsecase usecase;
     late MockAiDetectorAdapter mockAiDetector;
   
     setUp(() {
       mockAiDetector = MockAiDetectorAdapter();
       
       // ← USAR GETIT PARA TESTS
       setupTestServiceLocator(mockAiAdapter: mockAiDetector);
       usecase = getIt<ClassifyRoadImageUsecase>();
     });
   
     tearDown(() {
       getIt.reset(); // Limpiar después de cada test
     });
   
     // ... tests ...
   }
   ```

3. **Validación:**
   - Todos los tests existentes deben pasar
   - App debe iniciar sin errores
   - Funcionalidad debe ser idéntica a versión anterior

**Estrategia de Rollback:**
- **Trigger:** App no inicia o tests fallan masivamente
- **Acción:** 
  1. `git revert <commit-hash>` de migración a GetIt
  2. Volver a inyección manual en main.dart
  3. Tiempo: <10 minutos

**Criterios de Aceptación:**
- ✅ `main.dart` tiene <20 líneas de setup de DI
- ✅ Todos los tests pasan con nueva configuración
- ✅ Fácil agregar nuevos adaptadores sin tocar main.dart
- ✅ Tests pueden usar mocks fácilmente con `setupTestServiceLocator`
- ✅ Documentación de cómo registrar nuevas dependencias

**Estimación:** 12 horas

---

### 🔵 PRIORIDAD BAJA (Semana 14-16)

---

#### **MEJ-013: Completar Notificaciones Locales (HU-22)**

**Objetivo:**  
Implementar notificaciones push locales cuando usuario se aproxima a zona con daño crítico.

**Justificación:**  
- **Hallazgo:** Funcionalidad parcialmente implementada con TODO visible
- **Impacto:** Feature diferenciador para seguridad vial activa
- **Completitud:** 94% → 100% de HUs implementadas

**Prioridad:** 🔵 **BAJA** (funcionalidad nueva, no crítica)

**Riesgo de Implementación:** 🟡 **MEDIO**
- Requiere permisos de notificación en Android/iOS
- Puede causar fatiga de notificaciones si no se implementa throttling

**Dependencias:**
- MEJ-005 (GPS throttling ya implementado)
- MEJ-002 (feature flag para desactivar si molesta usuarios)

**Estrategia de Validación:**
1. **Implementación:**
   ```yaml
   # pubspec.yaml
   dependencies:
     flutter_local_notifications: ^17.2.2
   ```

   ```dart
   // lib/src/infrastructure/notifications/notification_service.dart (NUEVO)
   import 'package:flutter_local_notifications/flutter_local_notifications.dart';
   
   class NotificationService {
     static final NotificationService _instance = NotificationService._internal();
     factory NotificationService() => _instance;
     NotificationService._internal();
   
     late FlutterLocalNotificationsPlugin _notificationsPlugin;
     final Set<String> _recentlyNotified = {}; // Evitar spam
   
     Future<void> initialize() async {
       _notificationsPlugin = FlutterLocalNotificationsPlugin();
   
       const AndroidInitializationSettings androidSettings = 
           AndroidInitializationSettings('@mipmap/ic_launcher');
       
       const DarwinInitializationSettings iOSSettings = 
           DarwinInitializationSettings(
             requestAlertPermission: true,
             requestBadgePermission: true,
             requestSoundPermission: true,
           );
   
       const InitializationSettings initSettings = InitializationSettings(
         android: androidSettings,
         iOS: iOSSettings,
       );
   
       await _notificationsPlugin.initialize(
         initSettings,
         onDidReceiveNotificationResponse: _onNotificationTapped,
       );
     }
   
     Future<bool> requestPermissions() async {
       if (Platform.isAndroid) {
         final plugin = _notificationsPlugin
             .resolvePlatformSpecificImplementation<
                 AndroidFlutterLocalNotificationsPlugin>();
         return await plugin?.requestNotificationsPermission() ?? false;
       } else if (Platform.isIOS) {
         final plugin = _notificationsPlugin
             .resolvePlatformSpecificImplementation<
                 IOSFlutterLocalNotificationsPlugin>();
         return await plugin?.requestPermissions(
           alert: true,
           badge: true,
           sound: true,
         ) ?? false;
       }
       return false;
     }
   
     Future<void> showProximityAlert({
       required String incidenceId,
       required DamageLevel damageLevel,
       required String address,
       required double distanceKm,
     }) async {
       // Throttling: No notificar mismo incidence >1 vez por hora
       if (_recentlyNotified.contains(incidenceId)) return;
       
       _recentlyNotified.add(incidenceId);
       Future.delayed(const Duration(hours: 1), () {
         _recentlyNotified.remove(incidenceId);
       });
   
       const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
         'proximity_alerts',
         'Alertas de Proximidad',
         channelDescription: 'Notificaciones cuando te acercas a zonas con daños viales críticos',
         importance: Importance.high,
         priority: Priority.high,
         playSound: true,
         sound: RawResourceAndroidNotificationSound('alert'),
       );
   
       const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
         presentAlert: true,
         presentBadge: true,
         presentSound: true,
         sound: 'alert.aiff',
       );
   
       const NotificationDetails details = NotificationDetails(
         android: androidDetails,
         iOS: iOSDetails,
       );
   
       await _notificationsPlugin.show(
         incidenceId.hashCode, // ID único basado en incidencia
         '⚠️ Zona de Riesgo Adelante',
         'Daño ${damageLevel.label} detectado a ${(distanceKm * 1000).toInt()}m (${address ?? 'ubicación desconocida'}). Conduce con precaución.',
         details,
         payload: incidenceId,
       );
       
       AppLogger().info('Notificación de proximidad enviada', context: {
         'incidence_id': incidenceId,
         'damage_level': damageLevel.name,
         'distance_km': distanceKm,
       });
     }
   
     void _onNotificationTapped(NotificationResponse response) {
       final incidenceId = response.payload;
       if (incidenceId != null) {
         // Navegar a detalle de la incidencia
         AppLogger().info('Usuario tapped notificación', 
           context: {'incidence_id': incidenceId});
         // TODO: Implementar navegación global a InspectionDetailScreen
       }
     }
   }
   ```

   ```dart
   // lib/src/adapters/in/controllers/classification_controller.dart
   // Completar método _checkForCriticalIncidents
   
   Future<void> _checkForCriticalIncidents() async {
     if (_userLocation == null) return;
     
     // ← VERIFICAR FEATURE FLAG
     if (!FeatureFlags().notificationsEnabled) return;
   
     final snapshot = await FirebaseFirestore.instance
         .collection('inspecciones')
         .get(); // TODO: Agregar geohashing query para eficiencia
   
     final incidents = snapshot.docs.map((doc) {
       // ... código de mapeo existente ...
     }).toList();
   
     final roadSafetyService = RoadSafetyService();
   
     for (var incidence in incidents) {
       if (incidence.latitude != null && incidence.longitude != null) {
         final distance = calculateDistance(
           _userLocation!.latitude,
           _userLocation!.longitude,
           incidence.latitude!,
           incidence.longitude!,
         );
   
         if (distance < GeoThresholds.proximityAlertRadiusKm) { // 0.5 km
           if (roadSafetyService.shouldTriggerEmergencyAlert(
               incidence.damageLevel, incidence.confidence)) {
             
             // ← AGREGAR LLAMADA A NOTIFICATION SERVICE
             await NotificationService().showProximityAlert(
               incidenceId: incidence.id,
               damageLevel: incidence.damageLevel,
               address: incidence.address ?? 'Ubicación desconocida',
               distanceKm: distance,
             );
           }
         }
       }
     }
   }
   ```

   ```dart
   // main.dart - Inicializar servicio
   void main() async {
     // ... código existente ...
     await setupServiceLocator();
     
     // ← AGREGAR INICIALIZACIÓN DE NOTIFICACIONES
     await NotificationService().initialize();
     await NotificationService().requestPermissions();
     
     runApp(const AMIVIApp());
   }
   ```

2. **Testing:**
   - **Caso 1:** Usuario se acerca a zona crítica (simular GPS) → debe recibir notificación
   - **Caso 2:** Usuario ya fue notificado hace <1h → NO debe recibir notificación duplicada
   - **Caso 3:** Usuario deniega permisos → app funciona sin notificaciones
   - **Caso 4:** Tap en notificación → debe navegar a detalle de incidencia

3. **UX Considerations:**
   - Configuración en app para activar/desactivar notificaciones
   - Radio de alerta ajustable (500m por defecto)
   - Sonido diferenciado para alertas críticas vs. moderadas

**Estrategia de Rollback:**
- **Trigger:** Usuarios reportan spam de notificaciones o bugs de permisos
- **Acción:** 
  1. Desactivar `enable_notifications` en RemoteConfig
  2. Feature se desactiva instantáneamente sin redeploy
  3. Tiempo: <1 minuto

**Criterios de Aceptación:**
- ✅ Notificación se dispara correctamente en proximidad
- ✅ Throttling evita spam (<1 notificación por hora por incidencia)
- ✅ Permisos solicitados correctamente en Android/iOS
- ✅ Tap en notificación navega a detalle
- ✅ Logs de notificaciones enviadas visibles en analytics

**Estimación:** 16 horas

---

#### **MEJ-014: Internacionalización (i18n) - Español + Inglés**

**Objetivo:**  
Extraer strings hardcoded a archivos de localización y soportar español + inglés para expansión internacional.

**Justificación:**  
- **Hallazgo:** Auditoría identifica falta de i18n como limitante de mercado
- **Impacto:** Habilita adopción en países anglófonos
- **ROI:** Expansión geográfica del producto

**Prioridad:** 🔵 **BAJA** (no crítica para operación actual)

**Riesgo de Implementación:** 🟡 **MEDIO**
- Requiere cambio en todos los widgets con texto
- Testing exhaustivo de ambos idiomas

**Dependencias:**
- MEJ-010 (screens separadas facilitan extracción de strings)

**Estrategia de Validación:**
1. **Implementación:**
   ```yaml
   # pubspec.yaml
   dependencies:
     flutter_localizations:
       sdk: flutter
     intl: ^0.19.0
   ```

   ```dart
   // lib/l10n/app_es.arb (NUEVO - Español)
   {
     "@@locale": "es",
     "appTitle": "AMIVI",
     "@appTitle": {
       "description": "Título de la aplicación"
     },
     "appSubtitle": "Inspección Vial con IA",
     "loginTitle": "Iniciar Sesión",
     "loginEmailLabel": "Correo electrónico",
     "loginPasswordLabel": "Contraseña",
     "loginButton": "Iniciar Sesión",
     "loginForgotPassword": "¿Olvidaste tu contraseña?",
     "loginNoAccount": "¿No tienes cuenta?",
     "loginRegister": "Regístrate",
     "classificationScreenTitle": "AMIVI",
     "classificationSelectImage": "Selecciona o captura una imagen",
     "classificationGalleryButton": "Galería",
     "classificationCameraButton": "Cámara",
     "classificationAnalyzeButton": "Clasificar con IA",
     "classificationManualButton": "Manual",
     "damageLevelNormal": "Normal",
     "damageLevelLeve": "Leve",
     "damageLevelDanado": "Dañado",
     "damageLevelNormalDesc": "La vía se encuentra en buen estado. No requiere intervención.",
     "damageLevelLeveDesc": "Se detectan daños leves. Requiere seguimiento preventivo.",
     "damageLevelDanadoDesc": "Daño significativo detectado. Requiere intervención inmediata.",
     "confidenceLabel": "Confianza: {percent}%",
     "@confidenceLabel": {
       "description": "Etiqueta de confianza del modelo",
       "placeholders": {
         "percent": {
           "type": "String"
         }
       }
     },
     "observationsLabel": "Observaciones",
     "observationsHint": "Ej: Grieta profunda en carril derecho...",
     "registerButton": "Registrar inspección",
     "discardButton": "Descartar y nueva inspección",
     "errorClassification": "Error al clasificar: {error}",
     "@errorClassification": {
       "placeholders": {
         "error": {
           "type": "String"
         }
       }
     }
   }
   ```

   ```dart
   // lib/l10n/app_en.arb (NUEVO - Inglés)
   {
     "@@locale": "en",
     "appTitle": "AMIVI",
     "appSubtitle": "AI-Powered Road Inspection",
     "loginTitle": "Sign In",
     "loginEmailLabel": "Email",
     "loginPasswordLabel": "Password",
     "loginButton": "Sign In",
     "loginForgotPassword": "Forgot your password?",
     "loginNoAccount": "Don't have an account?",
     "loginRegister": "Register",
     "classificationScreenTitle": "AMIVI",
     "classificationSelectImage": "Select or capture an image",
     "classificationGalleryButton": "Gallery",
     "classificationCameraButton": "Camera",
     "classificationAnalyzeButton": "Analyze with AI",
     "classificationManualButton": "Manual",
     "damageLevelNormal": "Normal",
     "damageLevelLeve": "Minor",
     "damageLevelDanado": "Damaged",
     "damageLevelNormalDesc": "The road is in good condition. No intervention required.",
     "damageLevelLeveDesc": "Minor damage detected. Preventive monitoring required.",
     "damageLevelDanadoDesc": "Significant damage detected. Immediate intervention required.",
     "confidenceLabel": "Confidence: {percent}%",
     "observationsLabel": "Observations",
     "observationsHint": "E.g.: Deep crack on right lane...",
     "registerButton": "Register inspection",
     "discardButton": "Discard and new inspection",
     "errorClassification": "Classification error: {error}"
   }
   ```

   ```dart
   // lib/l10n/app_localizations.dart (AUTO-GENERADO)
   // Generar con: flutter gen-l10n
   
   import 'package:flutter_gen/gen_l10n/app_localizations.dart';
   ```

   ```dart
   // main.dart - Configurar localizaciones
   import 'package:flutter_localizations/flutter_localizations.dart';
   import 'package:flutter_gen/gen_l10n/app_localizations.dart';
   
   class AMIVIApp extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       return MaterialApp(
         // ← AGREGAR SOPORTE DE LOCALIZACIÓN
         localizationsDelegates: const [
           AppLocalizations.delegate,
           GlobalMaterialLocalizations.delegate,
           GlobalWidgetsLocalizations.delegate,
           GlobalCupertinoLocalizations.delegate,
         ],
         supportedLocales: const [
           Locale('es'), // Español
           Locale('en'), // Inglés
         ],
         // ... resto de configuración ...
       );
     }
   }
   ```

   ```dart
   // Ejemplo de uso en LoginScreen
   import 'package:flutter_gen/gen_l10n/app_localizations.dart';
   
   class _LoginScreenState extends State<LoginScreen> {
     @override
     Widget build(BuildContext context) {
       final l10n = AppLocalizations.of(context)!;
       
       return Scaffold(
         body: Column(
           children: [
             // ANTES:
             // const Text('AMIVI', style: ...)
             
             // DESPUÉS:
             Text(l10n.appTitle, style: ...),
             Text(l10n.appSubtitle, style: ...),
             
             TextField(
               decoration: InputDecoration(
                 labelText: l10n.loginEmailLabel,
                 prefixIcon: const Icon(Icons.email_outlined),
               ),
             ),
             
             ElevatedButton(
               onPressed: () => ...,
               child: Text(l10n.loginButton),
             ),
           ],
         ),
       );
     }
   }
   ```

2. **Testing:**
   - **Caso 1:** Dispositivo en español → app muestra textos en español
   - **Caso 2:** Cambiar idioma de sistema a inglés → app cambia automáticamente
   - **Caso 3:** Todos los strings visibles tienen traducción (no "missing translation")
   - **Caso 4:** Formato de fechas respeta locale (DD/MM/YYYY en es, MM/DD/YYYY en en)

3. **Herramientas de Validación:**
   - Script para detectar strings hardcoded:
     ```bash
     # find_hardcoded_strings.sh
     grep -r "Text\s*(\s*'" lib/src/adapters/in/views/ | grep -v "l10n\."
     ```

**Estrategia de Rollback:**
- **Trigger:** Traducciones incorrectas o strings faltantes
- **Acción:** 
  1. Revertir commit de i18n
  2. App vuelve a español hardcoded
  3. Tiempo: <5 minutos

**Criterios de Aceptación:**
- ✅ App funciona en español e inglés
- ✅ Cambio de idioma se refleja sin reiniciar app
- ✅ Todas las pantallas principales tienen traducción completa
- ✅ Formato de fechas y números respeta locale
- ✅ Documentación de cómo agregar nuevos idiomas

**Estimación:** 24 horas

---

## ORDEN RECOMENDADO DE EJECUCIÓN

### Fase 0: Preparación (Semana 1-2) - **FUNDACIONAL**

| # | Mejora | Duración | Dependencias | Justificación |
|---|--------|----------|--------------|---------------|
| 1 | MEJ-001: Externalizar credenciales | 4h | Ninguna | Seguridad crítica, sin impacto funcional |
| 2 | MEJ-002: Feature flags | 6h | MEJ-001 | Base para rollback de todas las mejoras |

**Total Fase 0:** 10 horas (1.25 días) | **Riesgo Acumulado:** 🟢 BAJO

---

### Fase 1: Estabilización Crítica (Semana 3-6) - **CALIDAD Y ESTABILIDAD**

| # | Mejora | Duración | Dependencias | Justificación |
|---|--------|----------|--------------|---------------|
| 3 | MEJ-003: Manejo de excepciones en IA | 12h | MEJ-002 | Previene crashes en operación crítica |
| 4 | MEJ-004: Logging y Crashlytics | 10h | MEJ-003 | Visibilidad de errores para monitoreo |
| 5 | MEJ-005: Throttling GPS | 16h | MEJ-002 | Optimiza batería, mejora UX |
| 6 | MEJ-006: Suite de testing (30%) | 40h | Ninguna | Base para validar todas las mejoras |

**Total Fase 1:** 78 horas (9.75 días) | **Riesgo Acumulado:** 🟡 MEDIO

**Hito:** App es estable, monitoreada y testeable. Se puede operar con confianza en producción.

---

### Fase 2: Optimización de Rendimiento (Semana 7-10) - **ESCALABILIDAD**

| # | Mejora | Duración | Dependencias | Justificación |
|---|--------|----------|--------------|---------------|
| 7 | MEJ-007: Hotspots O(n log n) | 20h | MEJ-002, MEJ-006 | Desbloquea escalabilidad del mapa |
| 8 | MEJ-008: Paginación Firestore | 16h | MEJ-002, MEJ-006 | Evita congelamiento con >1000 registros |
| 9 | MEJ-009: Caché geocoding | 12h | Ninguna | Reduce costos de API y latencia |

**Total Fase 2:** 48 horas (6 días) | **Riesgo Acumulado:** 🟡 MEDIO

**Hito:** App soporta >10,000 inspecciones sin degradación de performance.

---

### Fase 3: Refactoring y Mantenibilidad (Semana 11-13) - **DEUDA TÉCNICA**

| # | Mejora | Duración | Dependencias | Justificación |
|---|--------|----------|--------------|---------------|
| 10 | MEJ-010: Refactorizar main.dart | 16h | MEJ-006 | Facilita colaboración y mantenimiento |
| 11 | MEJ-011: Constantes nombradas | 8h | Ninguna | Mejora legibilidad y documentación |
| 12 | MEJ-012: Migración a GetIt | 12h | MEJ-010, MEJ-006 | Simplifica DI y testing |

**Total Fase 3:** 36 horas (4.5 días) | **Riesgo Acumulado:** 🟢 BAJO

**Hito:** Código es mantenible, documentado y fácil de extender.

---

### Fase 4: Nuevas Capacidades (Semana 14-16) - **EXPANSIÓN**

| # | Mejora | Duración | Dependencias | Justificación |
|---|--------|----------|--------------|---------------|
| 13 | MEJ-013: Notificaciones locales | 16h | MEJ-005, MEJ-002 | Completa HU-22, feature diferenciador |
| 14 | MEJ-014: Internacionalización | 24h | MEJ-010 | Habilita expansión a mercados anglófonos |

**Total Fase 4:** 40 horas (5 días) | **Riesgo Acumulado:** 🟡 MEDIO

**Hito:** App tiene 100% de funcionalidades y está lista para mercado internacional.

---

## RESUMEN DEL ROADMAP

| Fase | Semanas | Horas | Días | Riesgo | Entregable Clave |
|------|---------|-------|------|--------|------------------|
| **Fase 0** | 1-2 | 10 | 1.25 | 🟢 BAJO | Infraestructura de rollback |
| **Fase 1** | 3-6 | 78 | 9.75 | 🟡 MEDIO | App estable y monitoreada |
| **Fase 2** | 7-10 | 48 | 6.00 | 🟡 MEDIO | App escalable a 10K+ registros |
| **Fase 3** | 11-13 | 36 | 4.50 | 🟢 BAJO | Código mantenible y documentado |
| **Fase 4** | 14-16 | 40 | 5.00 | 🟡 MEDIO | Features completos + i18n |
| **TOTAL** | **16** | **212** | **26.5** | - | **App production-ready** |

**Esfuerzo Total:** 26.5 días de desarrollo (asumiendo 8 horas/día)  
**Distribución Recomendada:** 1 developer full-time durante 4 meses

---

## RIESGOS DE EJECUCIÓN

### Riesgos Técnicos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **Tests descubren bugs críticos durante implementación** | Alta | Alto | Priorizar MEJ-006 temprano, tests deben pasar antes de avanzar |
| **Feature flags fallan en producción** | Baja | Alto | Múltiples tests de RemoteConfig, validar antes de Fase 1 |
| **Hotspots optimizados muestran resultados diferentes a legacy** | Media | Medio | Validación A/B con dataset fijo, preservar algoritmo legacy |
| **Migración a GetIt rompe DI existente** | Media | Alto | Implementar incrementalmente, validar con tests después de cada paso |
| **Notificaciones causan spam de alertas** | Media | Medio | Throttling agresivo (1/hora), feature flag para desactivar rápidamente |

### Riesgos de Proyecto

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **Scope creep: nuevas features solicitadas durante ejecución** | Alta | Medio | Mantener roadmap fijo, nuevas features van a Fase 5 (post-plan) |
| **Tests toman más tiempo del estimado** | Alta | Medio | Buffer de 20% en estimaciones de Fase 1, priorizar cobertura crítica |
| **Breaking changes en dependencias** | Media | Alto | Versiones exactas para críticas, tests de regresión automáticos |
| **Usuarios reportan bugs en nueva versión** | Media | Alto | Despliegue gradual (10% → 50% → 100%), feature flags para rollback |

### Riesgos de Negocio

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **Usuarios rechazan cambios en UX (ej: paginación)** | Baja | Medio | A/B testing, métricas de adopción, comunicación proactiva |
| **Costos de desarrollo exceden presupuesto** | Media | Alto | Priorizar Fases 0-2, Fases 3-4 son "nice to have" |
| **Tiempo de desarrollo excede timeline** | Media | Medio | Checkpoints semanales, re-priorizar si hay retrasos |

---

## ESTRATEGIA DE PRESERVACIÓN DE FUNCIONALIDAD

### Principio de No-Regresión

**Regla de Oro:** Ningún cambio debe alterar comportamiento observable por usuarios sin consentimiento explícito.

### Mecanismos de Protección

1. **Feature Flags (MEJ-002):**
   - Toda mejora riesgosa debe estar detrás de feature flag
   - Default: OFF para features nuevas en producción
   - Habilitación gradual: 10% usuarios → 50% → 100%

2. **Testing Obligatorio (MEJ-006):**
   - Suite de regresión debe ejecutarse antes de merge
   - CI/CD bloquea merges si tests fallan
   - Smoke tests en staging antes de producción

3. **Despliegue Gradual:**
   ```
   Staging (100% features) → 2 días testing
      ↓
   Producción Canary (10% usuarios) → 2 días monitoreo
      ↓
   Producción Beta (50% usuarios) → 3 días monitoreo
      ↓
   Producción General (100% usuarios)
   ```

4. **Métricas de Salud:**
   - Crashrate: Debe mantenerse <2%
   - Tiempo de carga: No debe aumentar >20%
   - Tasa de éxito de clasificación: No debe bajar >5%

### Plan de Rollback Automático

```dart
// Ejemplo de implementación de circuit breaker
class AutoRollbackMonitor {
  static void checkHealth() {
    final crashRate = Crashlytics.instance.getCrashRateLastHour();
    final loadTime = PerformanceMonitoring.getAverageLoadTime();
    
    if (crashRate > 0.02) { // >2% crashes
      FeatureFlags().disableAllNewFeatures();
      AppLogger().error('Auto-rollback triggered: high crash rate');
      NotificationService().notifyDevTeam('CRITICAL: Auto-rollback executed');
    }
    
    if (loadTime > 5000) { // >5s load time
      FeatureFlags().disablePerformanceFeatures();
      AppLogger().warning('Performance degradation detected, rolling back');
    }
  }
}
```

### Compatibilidad de Datos

**Regla:** Toda modificación de schema de Firestore debe ser backward-compatible.

**Ejemplo:**
```dart
// INCORRECTO (rompe versiones anteriores):
final doc = {
  'clase': damageLevel.name, // ANTES: 'leve', DESPUÉS: 1 (enum index)
};

// CORRECTO (mantiene compatibilidad):
final doc = {
  'clase': damageLevel.name, // String mantiene formato
  'clase_v2': damageLevel.index, // Nuevo campo opcional
};
```

---

## CRITERIOS DE ÉXITO DEL PLAN

### Métricas Cuantitativas

| Métrica | Baseline | Objetivo Post-Plan | Método de Medición |
|---------|----------|--------------------|--------------------|
| **Cobertura de tests** | 0% | ≥70% | Codecov |
| **Crashrate** | ~5%* | <2% | Firebase Crashlytics |
| **Tiempo de carga inicial** | ~3s | <2s | Firebase Performance |
| **Consumo de batería (2h uso)** | ~40%** | <28% (-30%) | Battery Historian |
| **Puntaje FURPS+** | 7.2/10 | ≥8.5/10 | Re-auditoría post-plan |
| **Deuda técnica** | 18-22 días | <10 días | SonarQube |

*Estimado, no medido actualmente  
**Estimado basado en GPS continuo

### Métricas Cualitativas

| Criterio | Estado Actual | Objetivo |
|----------|---------------|----------|
| **Mantenibilidad** | Difícil (main.dart monolítico) | Fácil (código modular) |
| **Observabilidad** | Nula (sin logs) | Alta (Crashlytics + Analytics) |
| **Escalabilidad** | Limitada (1000 registros) | Alta (10,000+ registros) |
| **Seguridad** | Riesgosa (credenciales expuestas) | Segura (.env + vault) |
| **Internacionalización** | No soportada | Español + Inglés |

---

## PRÓXIMOS PASOS INMEDIATOS

### Semana 1 - Kickoff

1. **Lunes:**
   - Revisión de este plan con equipo
   - Asignación de responsabilidades
   - Setup de entorno de staging

2. **Martes-Miércoles:**
   - **MEJ-001:** Externalizar credenciales
   - Validación en dev + staging

3. **Jueves-Viernes:**
   - **MEJ-002:** Implementar feature flags
   - Configurar Firebase Remote Config
   - Smoke tests

### Checkpoint Semana 2

- ✅ Infraestructura de rollback funcional
- ✅ Credenciales seguras
- ✅ Feature flags testeados
- 🎯 **LISTO PARA FASE 1**

---

## CONCLUSIÓN

Este plan de mejora está diseñado para llevar a AMIVI desde su estado actual (7.2/10) a un producto **production-ready** (≥8.5/10) en **16 semanas**, siguiendo los principios de:

- ✅ **Compatibilidad hacia atrás:** Todas las mejoras preservan funcionalidad existente
- ✅ **Cambios incrementales:** 14 mejoras independientes y validables
- ✅ **Riesgo mínimo:** Feature flags permiten rollback instantáneo
- ✅ **Validación obligatoria:** Tests + smoke tests en cada fase
- ✅ **Posibilidad de rollback:** Estrategias documentadas para cada mejora

**Fases críticas (0-2)** deben completarse antes de considerar el sistema production-ready.  
**Fases opcionales (3-4)** mejoran mantenibilidad y capacidades, pero no son bloqueantes.

El éxito de este plan depende de:
1. Adherencia estricta a los principios de no-regresión
2. Testing exhaustivo en cada fase
3. Monitoreo continuo de métricas de salud
4. Comunicación proactiva con usuarios sobre cambios

---

**Arquitecto de Software:** Asistente IA - Especialista en Mejora Continua  
**Firma Digital:** [PLAN DE MEJORA FURPS+ - JUNIO 2026]  
**Próxima Revisión:** Post-Fase 2 (Semana 10) para evaluar progreso y ajustar Fases 3-4
