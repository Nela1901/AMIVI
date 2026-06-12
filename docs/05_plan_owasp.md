# PLAN DE REMEDIACIÓN OWASP TOP 10 - AMIVI
## Roadmap de Seguridad para Mitigación de Vulnerabilidades

**Fecha de Elaboración:** 11 de junio de 2026 (4:07 PM)  
**Arquitecto de Seguridad:** Asistente IA - Especialista en Remediación OWASP  
**Basado en:** Auditoría OWASP Top 10 v1.0 (docs/04_auditoria_owasp.md)  
**Versión del Plan:** 1.0  
**Horizonte Temporal:** 8 semanas (2 meses)  
**Score Actual:** 3.2/10 (CRÍTICO)  
**Score Objetivo:** ≥7.0/10 (PRODUCCIÓN SEGURA)

---

## PRINCIPIOS RECTORES DEL PLAN DE SEGURIDAD

### ⚠️ RESTRICCIÓN PRINCIPAL: SISTEMA EN FUNCIONAMIENTO

Este plan asume que AMIVI **está operativo o próximo a estar en producción** con usuarios potenciales. Por tanto, NINGUNA remediación debe:

- Interrumpir funcionalidades existentes
- Requerir downtime prolongado (>30 minutos)
- Forzar migración de datos destructiva
- Introducir cambios breaking en flujos de usuario
- Comprometer la experiencia del usuario actual

### 🛡️ Principios de Seguridad

| Principio | Definición | Aplicación |
|-----------|------------|------------|
| **Defensa en profundidad** | Múltiples capas de seguridad | Combinar Security Rules + Validación cliente + Rate limiting |
| **Privilegio mínimo** | Otorgar solo permisos necesarios | Roles granulares, acceso restrictivo por defecto |
| **Fallo seguro** | Ante error, denegar acceso | Reglas Firestore deniegan por defecto |
| **Separación de responsabilidades** | Dividir funciones críticas | Autenticación ≠ Autorización ≠ Auditoría |
| **Auditoría completa** | Registrar eventos de seguridad | Logging de todas las operaciones críticas |
| **Validación obligatoria** | Cada cambio debe tener criterios de aceptación | Tests de seguridad + smoke tests |
| **Rollback instantáneo** | Reversibilidad en <1 hora | Feature flags para cada remediación |

---

## ROADMAP GENERAL

### 📅 Estructura por Fases

```
┌─────────────────────────────────────────────────────────────────┐
│                 FASE 0: PREPARACIÓN CRÍTICA                     │
│                        (Semana 1)                               │
│  • Backup completo de Firebase                                 │
│  • Setup de entornos (dev/staging/prod)                        │
│  • Configuración de feature flags de seguridad                 │
│  • Implementación de logging básico                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              FASE 1: REMEDIACIÓN CRÍTICA                        │
│                        (Semana 2-3)                             │
│  • Firestore Security Rules (VULN-001, VULN-016)              │
│  • Externalización de credenciales (VULN-005)                  │
│  • Firebase App Check (VULN-006)                               │
│  • Validación de ownership (VULN-002)                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│               FASE 2: PROTECCIÓN DE ACCESO                      │
│                        (Semana 4-5)                             │
│  • Rate Limiting (VULN-012)                                    │
│  • Sistema de roles (VULN-003)                                 │
│  • Filtrado por usuario (VULN-004)                             │
│  • Verificación de email (VULN-025)                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│            FASE 3: HARDENING Y CIFRADO                          │
│                        (Semana 6)                               │
│  • Cifrado de almacenamiento local (VULN-007)                  │
│  • Validación de contraseñas (VULN-008)                        │
│  • Keystore de producción (VULN-017, VULN-028)                │
│  • Validación de duplicados (VULN-013)                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              FASE 4: MONITOREO Y VALIDACIÓN                     │
│                        (Semana 7-8)                             │
│  • Logging de seguridad completo (VULN-030)                    │
│  • Validación de geolocalización (VULN-014)                    │
│  • SSL Pinning (VULN-009)                                      │
│  • Package name corporativo (VULN-020)                         │
│  • Escaneo de dependencias (VULN-022)                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## MATRIZ DE PRIORIZACIÓN

### Vulnerabilidades por Prioridad

| Prioridad | Vulnerabilidades | Tiempo Estimado | Riesgo Actual |
|-----------|------------------|-----------------|---------------|
| **P0 - CRÍTICO** | 7 vulns | 38 horas | 🔴 Exposición total |
| **P1 - ALTO** | 8 vulns | 42 horas | 🟠 Comprometible |
| **P2 - MEDIO** | 10 vulns | 35 horas | 🟡 Vulnerable |
| **P3 - BAJO** | 5 vulns | 15 horas | 🟢 Aceptable |
| **TOTAL** | **30 vulns** | **130 horas** | |

---

## FASE 0: PREPARACIÓN CRÍTICA

**Duración:** Semana 1 (5 días)  
**Objetivo:** Establecer infraestructura de seguridad sin afectar funcionalidad

---

### PREP-001: Backup y Preparación de Entornos

**Riesgo:** 🟢 **BAJO**  
**Prioridad:** 🔴 **P0 - CRÍTICO** (Prerequisito)  
**Tiempo Estimado:** 6 horas

#### Objetivo

Crear respaldo completo de Firebase y configurar entornos separados para desarrollo, staging y producción antes de aplicar cambios de seguridad.

#### Componentes Afectados

- Firebase Firestore
- Firebase Authentication
- Firebase Storage
- Configuración de proyecto Flutter

#### Estrategia de Mitigación

**Paso 1: Backup de Firestore (2h)**

```bash
# 1. Exportar colección de usuarios
gcloud firestore export gs://amivi-backup/usuarios-$(date +%Y%m%d) \
  --collection-ids=usuarios

# 2. Exportar colección de inspecciones
gcloud firestore export gs://amivi-backup/inspecciones-$(date +%Y%m%d) \
  --collection-ids=inspecciones

# 3. Documentar estructura actual
firebase firestore:get usuarios > backup/usuarios_schema.json
firebase firestore:get inspecciones > backup/inspecciones_schema.json
```

**Paso 2: Configurar Proyectos de Firebase (2h)**

```bash
# Crear proyectos separados en Firebase Console
# - amivi-dev (desarrollo)
# - amivi-staging (pruebas)
# - amivi-prod (producción actual)

# Descargar archivos de configuración
# - google-services.json (Android) x3
# - GoogleService-Info.plist (iOS) x3
```

**Paso 3: Configuración de Flavor en Flutter (2h)**

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^3.0.0
  flutter_dotenv: ^5.1.0

flutter:
  assets:
    - .env.dev
    - .env.staging
    - .env.prod
```

```dart
// lib/config/environment.dart (NUEVO)
enum Environment { dev, staging, prod }

class EnvironmentConfig {
  static Environment currentEnvironment = Environment.dev;
  
  static String get firebaseProjectId {
    switch (currentEnvironment) {
      case Environment.dev:
        return 'amivi-dev';
      case Environment.staging:
        return 'amivi-staging';
      case Environment.prod:
        return 'amivi-prod';
    }
  }
  
  static bool get isProduction => currentEnvironment == Environment.prod;
}
```

```bash
# Scripts de build por ambiente
# scripts/build_dev.sh
flutter build apk --flavor dev --dart-define=ENVIRONMENT=dev

# scripts/build_staging.sh
flutter build apk --flavor staging --dart-define=ENVIRONMENT=staging

# scripts/build_prod.sh
flutter build apk --flavor prod --dart-define=ENVIRONMENT=prod
```

#### Estrategia de Validación

```bash
# Validar backup
gsutil ls gs://amivi-backup/
# Debe mostrar exportaciones completas

# Validar configuración de entornos
flutter run --flavor dev
flutter run --flavor staging
# Verificar que se conectan a proyectos correctos
```

#### Estrategia de Rollback

- N/A (Preparación sin cambios en producción)
- Backups disponibles en `gs://amivi-backup/`

#### Criterios de Aceptación

- ✅ Backups completos de Firestore (usuarios + inspecciones)
- ✅ 3 proyectos Firebase configurados (dev, staging, prod)
- ✅ App compila y ejecuta en cada ambiente
- ✅ Documentación de estructura de datos actual

---

### PREP-002: Feature Flags de Seguridad

**Riesgo:** 🟢 **BAJO**  
**Prioridad:** 🔴 **P0 - CRÍTICO**  
**Tiempo Estimado:** 4 horas

#### Objetivo

Implementar sistema de feature flags para habilitar/deshabilitar remediaciones de seguridad sin redeploy.

#### Componentes Afectados

- Firebase Remote Config
- Lógica de aplicación (todas las capas)

#### Estrategia de Mitigación

**Implementación:**

```yaml
# pubspec.yaml
dependencies:
  firebase_remote_config: ^5.0.0
```

```dart
// lib/config/security_features.dart (NUEVO)
import 'package:firebase_remote_config/firebase_remote_config.dart';

class SecurityFeatures {
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  
  static Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    
    // Valores por defecto (seguridad desactivada inicialmente)
    await _remoteConfig.setDefaults({
      'security_rules_enforced': false,
      'rate_limiting_enabled': false,
      'ownership_validation_enabled': false,
      'email_verification_required': false,
      'app_check_enabled': false,
      'local_encryption_enabled': false,
      'security_logging_enabled': false,
    });
    
    await _remoteConfig.fetchAndActivate();
  }
  
  // Feature flags individuales
  static bool get securityRulesEnforced => 
      _remoteConfig.getBool('security_rules_enforced');
  
  static bool get rateLimitingEnabled => 
      _remoteConfig.getBool('rate_limiting_enabled');
  
  static bool get ownershipValidationEnabled => 
      _remoteConfig.getBool('ownership_validation_enabled');
  
  static bool get emailVerificationRequired => 
      _remoteConfig.getBool('email_verification_required');
  
  static bool get appCheckEnabled => 
      _remoteConfig.getBool('app_check_enabled');
  
  static bool get localEncryptionEnabled => 
      _remoteConfig.getBool('local_encryption_enabled');
  
  static bool get securityLoggingEnabled => 
      _remoteConfig.getBool('security_logging_enabled');
}

// lib/main.dart (MODIFICAR)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await SecurityFeatures.initialize(); // ← AGREGAR
  runApp(AMIVIApp());
}
```

#### Estrategia de Validación

```dart
// Test en Firebase Console
// 1. Cambiar flag 'security_rules_enforced' a true
// 2. Esperar 1 minuto
// 3. Verificar en app:
if (SecurityFeatures.securityRulesEnforced) {
  print('✅ Feature flag funcionando');
}
```

#### Estrategia de Rollback

- Cambiar flag a `false` en Firebase Console
- App responde en <5 minutos (fetch interval)
- Sin necesidad de redeploy

#### Criterios de Aceptación

- ✅ Remote Config inicializado sin errores
- ✅ Cambio de flag se refleja en app en <5 min
- ✅ Todos los flags de seguridad definidos
- ✅ Valores por defecto conservadores (seguridad OFF)

---

## FASE 1: REMEDIACIÓN CRÍTICA

**Duración:** Semanas 2-3 (10 días)  
**Objetivo:** Mitigar vulnerabilidades críticas (P0)

---

### SEC-001: Firestore Security Rules

**Vulnerabilidades:** VULN-001, VULN-016  
**Riesgo:** 🔴 **CRÍTICO**  
**Prioridad:** 🔴 **P0 - CRÍTICO**  
**Tiempo Estimado:** 8 horas

#### Impacto de la Vulnerabilidad

- 🔴 **Confidencialidad:** Exposición total de datos (ubicaciones GPS, fotos, datos personales)
- 🔴 **Integridad:** Modificación/eliminación masiva de datos sin autorización
- 🔴 **Disponibilidad:** Posibilidad de eliminar toda la base de datos

#### Componentes Afectados

- `firestore.rules` (nuevo archivo)
- Firebase Console (despliegue de reglas)
- `lib/src/adapters/out/persistence/firestore_adapter.dart`
- `lib/src/adapters/out/auth/firebase_auth_adapter.dart`

#### Estrategia de Mitigación

**Paso 1: Crear archivo de reglas (2h)**

```javascript
// firestore.rules (NUEVO)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Funciones auxiliares
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function getUserRole() {
      return get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.role;
    }
    
    function isAdmin() {
      return isAuthenticated() && getUserRole() == 'admin';
    }
    
    // Colección de usuarios
    match /usuarios/{userId} {
      // Lectura: solo el propio perfil
      allow read: if isOwner(userId);
      
      // Creación: durante registro (Firebase Auth se encarga)
      allow create: if isOwner(userId);
      
      // Actualización: solo el propietario (excepto campo 'role')
      allow update: if isOwner(userId)
                    && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['role']);
      
      // Actualización de rol: solo admins
      allow update: if isAdmin();
      
      // Eliminación: solo admins (soft delete preferido)
      allow delete: if isAdmin();
      
      // Subcollección de sesiones
      match /sessions/{sessionId} {
        allow read, write: if isOwner(userId);
      }
    }
    
    // Colección de inspecciones
    match /inspecciones/{inspeccionId} {
      // Lectura: todos los usuarios autenticados pueden ver todas las inspecciones
      // (caso de uso: mapa público de incidencias)
      allow read: if isAuthenticated();
      
      // Escritura: solo usuarios autenticados y con userId válido
      allow create: if isAuthenticated()
                    && request.resource.data.userId == request.auth.uid
                    && request.resource.data.keys().hasAll(['userId', 'clase', 'confianza', 'fechaHora'])
                    && request.resource.data.fechaHora == request.time;
      
      // Actualización: solo el propietario
      allow update: if isOwner(resource.data.userId)
                    && request.resource.data.userId == resource.data.userId; // No cambiar owner
      
      // Eliminación: propietario o admin
      allow delete: if isOwner(resource.data.userId) || isAdmin();
    }
    
    // Colección de logs de seguridad
    match /security_logs/{logId} {
      // Solo escritura (lectura solo desde Firebase Console)
      allow read: if false;
      allow write: if isAuthenticated();
    }
    
    // Colección de rate limiting
    match /rate_limits/{userId} {
      match /rate_limits/{userId}/attempts/{attemptId} {
        allow read: if isOwner(userId);
        allow write: if isOwner(userId);
      }
    }
    
    // Denegar todo lo demás
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Paso 2: Testing de reglas en emulador (3h)**

```bash
# Instalar Firebase CLI
npm install -g firebase-tools

# Inicializar emulador
firebase init emulators
# Seleccionar: Firestore

# Iniciar emulador
firebase emulators:start --only firestore
```

```dart
// test/security/firestore_rules_test.dart (NUEVO)
import 'package:test/test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  setUpAll(() async {
    // Conectar a emulador
    await Firebase.initializeApp();
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });
  
  group('Security Rules Tests', () {
    test('Usuario no autenticado NO puede leer inspecciones', () async {
      // Simular usuario no autenticado
      final firestore = FirebaseFirestore.instance;
      
      expect(
        () => firestore.collection('inspecciones').get(),
        throwsA(isA<FirebaseException>()),
      );
    });
    
    test('Usuario autenticado PUEDE leer inspecciones', () async {
      // TODO: Implementar con autenticación de test
    });
    
    test('Usuario NO puede cambiar userId de inspección', () async {
      // TODO: Implementar
    });
    
    test('Usuario NO puede cambiar su propio rol', () async {
      // TODO: Implementar
    });
  });
}
```

**Paso 3: Despliegue gradual (3h)**

```bash
# 1. Desplegar a ambiente de dev
firebase use amivi-dev
firebase deploy --only firestore:rules

# 2. Validar en dev durante 24h

# 3. Desplegar a staging
firebase use amivi-staging
firebase deploy --only firestore:rules

# 4. Validar en staging durante 48h

# 5. Activar feature flag en prod (sin desplegar reglas aún)
# Firebase Console → Remote Config → 'security_rules_enforced' = true

# 6. Monitorear logs por 24h

# 7. Desplegar reglas a producción
firebase use amivi-prod
firebase deploy --only firestore:rules
```

#### Estrategia de Validación

**Tests Manuales (Staging):**

```bash
# Test 1: Usuario no autenticado
# 1. Abrir app sin login
# 2. Intentar ver mapa
# ✅ Esperado: Error de permisos, redirect a login

# Test 2: Usuario autenticado puede ver inspecciones
# 1. Login exitoso
# 2. Ver mapa
# ✅ Esperado: Mapa carga correctamente

# Test 3: Usuario NO puede ver perfil de otros
# 1. Login como usuario A
# 2. Intentar acceder a /usuarios/{userB_uid}
# ✅ Esperado: Error de permisos

# Test 4: Usuario NO puede modificar inspección ajena
# 1. Login como usuario A
# 2. Obtener ID de inspección de usuario B
# 3. Intentar actualizar campo 'observaciones'
# ✅ Esperado: Error de permisos

# Test 5: Crear inspección con userId correcto
# 1. Capturar foto y clasificar
# 2. Guardar inspección
# ✅ Esperado: Inspección guardada con userId del usuario actual
```

**Métricas de Monitoreo:**

```javascript
// Firebase Console → Firestore → Usage
// Monitorear:
// - Lecturas denegadas (expected: >0 tras despliegue)
// - Escrituras denegadas (expected: >0 si hay intentos maliciosos)
// - Latencia de queries (expected: sin cambio significativo)
```

#### Estrategia de Rollback

**Opción 1: Rollback de reglas (30 segundos)**

```bash
# Volver a reglas permisivas (SOLO EN EMERGENCIA)
firebase use amivi-prod
firebase deploy --only firestore:rules --force

# firestore.rules (TEMPORAL - INSEGURO)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null; // Permisivo temporalmente
    }
  }
}
```

**Opción 2: Desactivar feature flag (5 minutos)**

```bash
# Firebase Console → Remote Config
# Cambiar 'security_rules_enforced' = false
# App ajusta comportamiento sin requerir reglas estrictas
```

#### Criterios de Aceptación

- ✅ Archivo `firestore.rules` creado y versionado en Git
- ✅ Reglas desplegadas en dev, staging y prod
- ✅ Tests de seguridad pasan en emulador
- ✅ Usuarios autenticados pueden usar app normalmente
- ✅ Usuarios NO autenticados son bloqueados
- ✅ Intentos de acceso no autorizado son denegados
- ✅ Sin incremento significativo de latencia (<50ms)
- ✅ Monitoreo de Firebase muestra denegaciones esperadas

---

### SEC-002: Validación de Ownership (userId)

**Vulnerabilidad:** VULN-002  
**Riesgo:** 🔴 **CRÍTICO**  
**Prioridad:** 🔴 **P0 - CRÍTICO**  
**Tiempo Estimado:** 4 horas

#### Impacto de la Vulnerabilidad

- 🔴 **Integridad:** Modificación de datos ajenos
- 🟠 **Disponibilidad:** Eliminación de inspecciones de otros usuarios

#### Componentes Afectados

- `lib/src/adapters/out/persistence/firestore_adapter.dart`
- `lib/src/adapters/in/controllers/classification_controller.dart`
- `lib/main.dart` (HistoryScreen)

#### Estrategia de Mitigación

**Paso 1: Agregar userId en FirestoreAdapter (2h)**

```dart
// lib/src/adapters/out/persistence/firestore_adapter.dart (MODIFICAR)
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreAdapter implements SaveInspectionPort {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // ← AGREGAR
  
  // ... credenciales ...
  
  @override
  Future<String> saveInspection({
    required RoadIncidence incidence,
    required String imagePath,
    double? latitud,
    double? longitud,
    String? direccion,
    String? observaciones,
  }) async {
    // ✅ Validar usuario autenticado
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuario no autenticado. Por favor inicia sesión.');
    }
    
    // Subir imagen a Cloudinary
    final imageUrl = await _uploadToCloudinary(imagePath);

    // Borrar copia temporal después de subir
    try { await File(imagePath).delete(); } catch (_) {}

    // ✅ Guardar en Firestore CON userId
    final docRef = await _firestore.collection('inspecciones').add({
      'userId': currentUser.uid, // ← AGREGAR
      'userEmail': currentUser.email, // ← AGREGAR (opcional, para auditoría)
      'imagenUrl': imageUrl,
      'clase': incidence.damageLevel.name,
      'confianza': incidence.confidence,
      'latitud': latitud,
      'longitud': longitud,
      'direccion': direccion,
      'observaciones': observaciones,
      'fechaHora': FieldValue.serverTimestamp(),
      'requiereIntervencion': incidence.requiresIntervention,
      'requiereMonitoreo': incidence.requiresMonitoring,
    });

    return docRef.id;
  }
}
```

**Paso 2: Actualizar queries para incluir userId (2h)**

```dart
// lib/src/adapters/in/controllers/classification_controller.dart (MODIFICAR)
import 'package:firebase_auth/firebase_auth.dart';

class ClassificationController extends ChangeNotifier {
  // ... campos existentes ...
  final FirebaseAuth _auth = FirebaseAuth.instance; // ← AGREGAR
  
  // ...
  
  Stream<List<RoadIncidence>> getFilteredInspectionsStream() {
    // ✅ Validar usuario autenticado
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]); // Usuario no autenticado → lista vacía
    }

    Query query = FirebaseFirestore.instance.collection('inspecciones');
    
    // ✅ OPCIÓN A: Filtrar SOLO inspecciones del usuario actual (privado)
    // query = query.where('userId', isEqualTo: currentUser.uid);
    
    // ✅ OPCIÓN B: Mostrar TODAS las inspecciones (mapa público)
    // (Mantener comportamiento actual para caso de uso de mapa público)
    // Security Rules ya validan que solo usuarios autenticados pueden leer
    
    // Aplicar filtros de nivel de daño
    if (_filterLevels.isNotEmpty) {
      final levelNames = _filterLevels.map((l) => l.name).toList();
      query = query.where('clase', whereIn: levelNames);
    }

    // Aplicar filtro de rango de fechas
    if (_filterDateRange != null) {
      query = query
          .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(_filterDateRange!.start))
          .where('fechaHora', isLessThanOrEqualTo: Timestamp.fromDate(_filterDateRange!.end.add(const Duration(days: 1))));
    }

    // Ordenar por fecha
    query = query.orderBy('fechaHora', descending: true);
    
    // ✅ Limitar cantidad (evitar sobrecarga)
    query = query.limit(500);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // ... mapeo a RoadIncidence ...
      }).toList();
    });
  }
}
```

```dart
// lib/main.dart - HistoryScreen (MODIFICAR)
class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // ✅ Validar usuario autenticado
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historial')),
        body: const Center(
          child: Text('Por favor inicia sesión para ver tu historial'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Inspecciones')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inspecciones')
            .where('userId', isEqualTo: currentUser.uid) // ← FILTRO AGREGADO
            .orderBy('fechaHora', descending: true)
            .limit(50) // ← LÍMITE AGREGADO
            .snapshots(),
        builder: (context, snapshot) {
          // ... resto del código existente ...
        },
      ),
    );
  }
}
```

#### Estrategia de Validación

**Test Manual:**

```dart
// Escenario 1: Crear inspección
// 1. Login como usuario A (uid: userA123)
// 2. Capturar foto y clasificar
// 3. Guardar inspección
// 4. Verificar en Firebase Console:
//    - Campo 'userId' existe
//    - userId == 'userA123'
//    - Campo 'userEmail' == email de usuario A

// Escenario 2: Ver solo inspecciones propias en historial
// 1. Login como usuario A
// 2. Abrir Historial
// 3. Verificar que solo muestra inspecciones de usuario A
// 4. Login como usuario B
// 5. Verificar que historial es diferente (solo inspecciones de B)

// Escenario 3: Mapa público sigue mostrando todas
// 1. Login como usuario A
// 2. Abrir Mapa
// 3. Verificar que muestra inspecciones de todos los usuarios
// (Comportamiento actual preservado)
```

**Test Automatizado:**

```dart
// test/integration/ownership_test.dart (NUEVO)
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  testWidgets('Inspección guardada con userId correcto', (tester) async {
    // Arrange: Login como usuario test
    final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'test@example.com',
      password: 'password123',
    );
    
    // Act: Crear inspección
    final docRef = await FirebaseFirestore.instance.collection('inspecciones').add({
      'userId': userCredential.user!.uid,
      'clase': 'leve',
      'confianza': 0.85,
      'fechaHora': FieldValue.serverTimestamp(),
    });
    
    // Assert: Verificar userId
    final doc = await docRef.get();
    expect(doc.data()?['userId'], equals(userCredential.user!.uid));
  });
}
```

#### Estrategia de Rollback

**Opción 1: Modificación de código permite backward compatibility**

```dart
// Si se detecta problema, código puede manejar inspecciones sin userId:
final data = doc.data() as Map<String, dynamic>;
final userId = data['userId'] as String?; // ← Nullable

if (userId == null) {
  // Inspección creada antes de la migración
  // Asignar a "usuario desconocido" o migrar dato
}
```

**Opción 2: Migración de datos existentes**

```javascript
// Cloud Function para agregar userId a inspecciones antiguas (OPCIONAL)
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.migrateInspectionsUserId = functions.https.onRequest(async (req, res) => {
  const inspecciones = await admin.firestore().collection('inspecciones').get();
  
  let migratedCount = 0;
  for (const doc of inspecciones.docs) {
    if (!doc.data().userId) {
      // Inspección sin userId → asignar a "sistema" o usuario específico
      await doc.ref.update({
        userId: 'sistema', // Placeholder para inspecciones antiguas
        migrated: true,
      });
      migratedCount++;
    }
  }
  
  res.send(`Migradas ${migratedCount} inspecciones`);
});
```

#### Criterios de Aceptación

- ✅ Todas las nuevas inspecciones tienen campo `userId`
- ✅ Campo `userId` coincide con usuario autenticado
- ✅ Historial muestra solo inspecciones del usuario actual
- ✅ Mapa sigue mostrando inspecciones de todos (caso de uso público)
- ✅ Usuario no autenticado no puede crear inspecciones
- ✅ Tests automatizados pasan
- ✅ Sin errores en producción durante 48h

---

### SEC-003: Externalización de Credenciales Cloudinary

**Vulnerabilidad:** VULN-005  
**Riesgo:** 🔴 **CRÍTICO**  
**Prioridad:** 🔴 **P0 - CRÍTICO**  
**Tiempo Estimado:** 6 horas

#### Impacto de la Vulnerabilidad

- 🔴 **Confidencialidad:** Exposición de todas las imágenes en Cloudinary
- 🔴 **Integridad:** Inyección de contenido malicioso
- 🔴 **Disponibilidad:** Costos económicos descontrolados

#### Componentes Afectados

- `lib/src/adapters/out/persistence/firestore_adapter.dart`
- `.env` (nuevo archivo)
- `.gitignore`
- `lib/main.dart`

#### Estrategia de Mitigación

**Paso 1: URGENTE - Rotar credenciales de Cloudinary (1h)**

```bash
# 1. Acceder a Cloudinary Dashboard
# https://cloudinary.com/console

# 2. Settings → Upload → Upload presets
#    - ELIMINAR preset 'amivi_preset'
#    - CREAR nuevo preset 'amivi_secure_preset_2026'
#    - Configurar restricciones:
#      • Allowed formats: jpg, png, webp
#      • Max file size: 10MB
#      • Folder: inspecciones/
#      • Unsigned: false (requiere firma)

# 3. Anotar nuevo preset y cloud name
CLOUDINARY_CLOUD_NAME=nuevo_cloud_name_seguro
CLOUDINARY_UPLOAD_PRESET=amivi_secure_preset_2026
```

**Paso 2: Implementar variables de entorno (2h)**

```yaml
# pubspec.yaml (MODIFICAR)
dependencies:
  flutter_dotenv: ^5.1.0

flutter:
  assets:
    - .env
    - .env.example
```

```env
# .env.example (NUEVO - Commitear a Git)
# Copiar este archivo a .env y completar con valores reales
CLOUDINARY_CLOUD_NAME=tu_cloud_name
CLOUDINARY_UPLOAD_PRESET=tu_upload_preset
```

```env
# .env (NUEVO - NUNCA commitear a Git)
CLOUDINARY_CLOUD_NAME=nuevo_cloud_name_seguro
CLOUDINARY_UPLOAD_PRESET=amivi_secure_preset_2026
```

```gitignore
# .gitignore (MODIFICAR)
# Credenciales
.env
.env.local
.env.*.local

# Excepciones
!.env.example
```

```dart
// lib/src/adapters/out/persistence/firestore_adapter.dart (MODIFICAR)
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirestoreAdapter implements SaveInspectionPort {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Leer de variables de entorno
  static String get _cloudName {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    if (cloudName == null || cloudName.isEmpty) {
      throw Exception('CLOUDINARY_CLOUD_NAME no configurado en .env');
    }
    return cloudName;
  }
  
  static String get _uploadPreset {
    final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];
    if (preset == null || preset.isEmpty) {
      throw Exception('CLOUDINARY_UPLOAD_PRESET no configurado en .env');
    }
    return preset;
  }

  Future<String> _uploadToCloudinary(String imagePath) async {
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'inspecciones'
      ..files.add(await http.MultipartFile.fromPath('file', imagePath));

    final response = await request.send();
    final responseData = await response.stream.toBytes();
    final jsonResponse = json.decode(String.fromCharCodes(responseData));

    if (response.statusCode == 200) {
      return jsonResponse['secure_url'];
    } else {
      throw Exception('Error al subir imagen: ${jsonResponse['error']['message']}');
    }
  }
  
  // ... resto del código ...
}
```

```dart
// lib/main.dart (MODIFICAR)
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Cargar variables de entorno ANTES de Firebase
  await dotenv.load(fileName: ".env");
  
  await Firebase.initializeApp();
  await SecurityFeatures.initialize();
  runApp(AMIVIApp());
}
```

**Paso 3: Limpiar historial de Git (3h)**

```bash
# ⚠️ PELIGROSO: Solo si repo es privado y con backup

# 1. Backup completo del repositorio
git clone --mirror https://github.com/user/amivi-flutter.git amivi-backup

# 2. Instalar git-filter-repo
pip install git-filter-repo

# 3. Eliminar archivo con credenciales del historial
git filter-repo --path lib/src/adapters/out/persistence/firestore_adapter.dart --invert-paths

# 4. Forzar push (PELIGROSO - coordinar con equipo)
git push --force --all

# 5. Notificar a todos los colaboradores que deben re-clonar el repo
```

**Alternativa segura (si repo es público o con múltiples colaboradores):**

```bash
# Crear nuevo repositorio desde cero
git init amivi-flutter-secure
cp -r amivi-flutter-backup/* amivi-flutter-secure/
cd amivi-flutter-secure

# Eliminar archivos sensibles
rm -rf .git
git init
git add .
git commit -m "Initial commit - Credenciales removidas"

# Migrar issues, PRs, wiki manualmente si es necesario
```

#### Estrategia de Validación

**Test Manual:**

```bash
# Test 1: Validar que .env NO está en Git
git status
git ls-files | grep .env
# ✅ Esperado: Solo .env.example

# Test 2: Validar carga de credenciales
# 1. Renombrar .env a .env.backup
# 2. Ejecutar app
# ✅ Esperado: Crash con mensaje "CLOUDINARY_CLOUD_NAME no configurado"

# Test 3: Restaurar .env y probar upload
# 1. Restaurar .env
# 2. Capturar foto y guardar inspección
# ✅ Esperado: Subida exitosa a Cloudinary con nuevo preset
```

**Validación en Cloudinary:**

```bash
# Cloudinary Dashboard → Media Library
# Verificar que nuevas imágenes están en:
# /inspecciones/ (carpeta)
# Con transformaciones aplicadas según preset
```

#### Estrategia de Rollback

**Si upload falla:**

```dart
// Opción temporal (NO commitear): Hardcodear credenciales nuevas temporalmente
class FirestoreAdapter {
  static String get _cloudName => 
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'nuevo_cloud_name_seguro'; // Fallback
  static String get _uploadPreset => 
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'amivi_secure_preset_2026'; // Fallback
}

// Deployar esta versión temporalmente mientras se diagnostica problema con .env
```

**Si credenciales antiguas fueron expuestas:**

```bash
# Cloudinary Dashboard
# 1. Regenerar API key (si se usa)
# 2. Eliminar preset comprometido
# 3. Cambiar nombre de cloud (opción nuclear, requiere migración de imágenes)
```

#### Criterios de Aceptación

- ✅ Archivo `.env` creado y en `.gitignore`
- ✅ Archivo `.env.example` commitado a Git
- ✅ Credenciales antiguas NO aparecen en código fuente
- ✅ Credenciales antiguas rotadas en Cloudinary
- ✅ App carga credenciales desde `.env` correctamente
- ✅ Upload de imágenes funciona con nuevas credenciales
- ✅ Historial de Git limpiado (si es factible)
- ✅ Documentación actualizada con setup de `.env`

---

### SEC-004: Firebase App Check

**Vulnerabilidad:** VULN-006  
**Riesgo:** 🔴 **CRÍTICO**  
**Prioridad:** 🔴 **P0 - CRÍTICO**  
**Tiempo Estimado:** 6 horas

#### Impacto de la Vulnerabilidad

- 🟠 **Disponibilidad:** Abuso de cuota de Firebase (costos)
- 🟠 **Integridad:** Scraping masivo de datos
- 🟡 **Reputación:** App etiquetada como spam

#### Componentes Afectados

- `pubspec.yaml`
- `lib/main.dart`
- Firebase Console (App Check configuration)
- Android: `android/app/build.gradle.kts`
- iOS: `ios/Runner/Info.plist`

#### Estrategia de Mitigación

**Paso 1: Configurar App Check en Firebase Console (2h)**

```bash
# 1. Firebase Console → Build → App Check
# 2. Register app:
#    - Select: Android app (com.example.flutter_application_1)
#    - Provider: Play Integrity API
#    - Click "Register"

# 3. Register app:
#    - Select: iOS app (com.example.flutterApplication1)
#    - Provider: App Attest
#    - Click "Register"

# 4. Enforcement:
#    - Cloud Firestore: Enable enforcement (después de testing)
#    - Cloud Storage: Enable enforcement
#    - Keep "Unenforced" initially for gradual rollout
```

**Paso 2: Integrar SDK de App Check (2h)**

```yaml
# pubspec.yaml (MODIFICAR)
dependencies:
  firebase_app_check: ^0.3.0
```

```dart
// lib/main.dart (MODIFICAR)
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  
  // ✅ Activar App Check
  await FirebaseAppCheck.instance.activate(
    // Web
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    // Android
    androidProvider: AndroidProvider.playIntegrity,
    // iOS
    appleProvider: AppleProvider.appAttest,
  );
  
  // Para desarrollo/testing, usar debug token
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }
  
  await SecurityFeatures.initialize();
  runApp(AMIVIApp());
}
```

**Paso 3: Configurar debug tokens para desarrollo (1h)**

```bash
# Obtener debug token en logs
flutter run --debug
# Buscar en logs: "App Check debug token: XXXXX-XXXXX-XXXXX"

# Agregar token en Firebase Console
# App Check → Apps → Android → Debug tokens
# Pegar token copiado de logs

# Repetir para iOS
flutter run --debug --device=ios
```

**Paso 4: Testing y enforcement gradual (1h)**

```dart
// lib/config/security_features.dart (AGREGAR FLAG)
static bool get appCheckEnabled => 
    _remoteConfig.getBool('app_check_enabled');

// lib/main.dart (CONDICIONAL)
void main() async {
  // ...
  
  // Solo activar App Check si feature flag está habilitado
  if (!kDebugMode && SecurityFeatures.appCheckEnabled) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
  }
  
  // ...
}
```

#### Estrategia de Validación

**Test en Dev:**

```bash
# 1. Compilar app en debug mode
flutter run --debug

# 2. Verificar en logs:
# ✅ "App Check initialized successfully"
# ✅ "App Check token: ..."

# 3. Intentar operación en Firestore
# ✅ Esperado: Funciona normalmente (debug token válido)
```

**Test en Staging (Sin enforcement):**

```bash
# 1. Compilar app en release mode
flutter build apk --release

# 2. Instalar en dispositivo físico
adb install build/app/outputs/flutter-apk/app-release.apk

# 3. Usar app normalmente
# ✅ Esperado: Funciona normalmente

# 4. Verificar en Firebase Console → App Check → Metrics
# ✅ "Recent requests": Debería mostrar requests con tokens válidos
```

**Test de Enforcement (Staging):**

```bash
# 1. Firebase Console → App Check → Cloud Firestore
#    Cambiar a "Enforced"

# 2. Intentar usar app SIN App Check (modificar código temporalmente)
# ✅ Esperado: Requests fallan con error de App Check

# 3. Restaurar App Check en código
# ✅ Esperado: App funciona normalmente

# 4. Volver a "Unenforced" en Firebase Console
```

#### Estrategia de Rollback

**Opción 1: Desactivar enforcement (30 segundos)**

```bash
# Firebase Console → App Check → Services
# Cloud Firestore: Cambiar de "Enforced" a "Unenforced"
# ✅ Efecto inmediato: Requests sin token funcionan
```

**Opción 2: Desactivar feature flag (5 minutos)**

```bash
# Firebase Console → Remote Config
# 'app_check_enabled' = false
# Publicar cambios
# ✅ Nueva compilación de app no inicializará App Check
```

**Opción 3: Remover código de App Check (1 hora)**

```bash
# Revertir commit
git revert <commit-hash-app-check>
# Deployar versión sin App Check
```

#### Criterios de Aceptación

- ✅ `firebase_app_check` instalado y configurado
- ✅ App Check inicializa sin errores en dev/staging/prod
- ✅ Debug tokens configurados para desarrollo
- ✅ Requests incluyen token de App Check (visible en Firebase Console)
- ✅ Enforcement funciona en staging sin afectar usuarios legítimos
- ✅ Métricas de App Check muestran 100% de requests válidos
- ✅ Sin incremento de latencia perceptible (<100ms)
- ✅ Documentación de setup para nuevos desarrolladores

---

### SEC-005: Rate Limiting Básico

**Vulnerabilidad:** VULN-012  
**Riesgo:** 🔴 **CRÍTICO**  
**Prioridad:** 🔴 **P0 - CRÍTICO**  
**Tiempo Estimado:** 8 horas

#### Impacto de la Vulnerabilidad

- 🔴 **Disponibilidad:** DoS completo (spam de registros, uploads, emails)
- 🔴 **Costos:** Miles de dólares en servicios (Firebase, Cloudinary)
- 🟠 **Integridad:** Base de datos contaminada con datos falsos

#### Componentes Afectados

- `lib/src/infrastructure/security/rate_limiter.dart` (nuevo)
- `lib/src/adapters/in/controllers/auth_controller.dart`
- `lib/src/adapters/in/controllers/classification_controller.dart`
- Firebase Cloud Functions (backend rate limiting)

#### Estrategia de Mitigación

**Paso 1: Rate Limiting en Cliente (4h)**

```yaml
# pubspec.yaml (AGREGAR)
dependencies:
  shared_preferences: ^2.2.0
```

```dart
// lib/src/infrastructure/security/rate_limiter.dart (NUEVO)
import 'package:shared_preferences/shared_preferences.dart';

enum RateLimitAction {
  register('register'),
  login('login'),
  passwordReset('password_reset'),
  createInspection('create_inspection'),
  syncInspections('sync_inspections');

  final String code;
  const RateLimitAction(this.code);
}

class RateLimiter {
  static const _keyPrefix = 'rate_limit_';
  
  // Configuración de límites
  static const _limits = {
    RateLimitAction.register: (maxAttempts: 3, windowMinutes: 60),
    RateLimitAction.login: (maxAttempts: 5, windowMinutes: 15),
    RateLimitAction.passwordReset: (maxAttempts: 3, windowMinutes: 60),
    RateLimitAction.createInspection: (maxAttempts: 10, windowMinutes: 60),
    RateLimitAction.syncInspections: (maxAttempts: 5, windowMinutes: 30),
  };
  
  static Future<RateLimitResult> checkLimit(RateLimitAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${action.code}';
    
    final limit = _limits[action]!;
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowMs = limit.windowMinutes * 60 * 1000;
    
    // Obtener intentos previos
    final attempts = prefs.getStringList(key) ?? [];
    
    // Filtrar intentos dentro de la ventana de tiempo
    final recentAttempts = attempts
        .map((e) => int.parse(e))
        .where((timestamp) => now - timestamp < windowMs)
        .toList();
    
    // Verificar si se excedió el límite
    if (recentAttempts.length >= limit.maxAttempts) {
      final oldestAttempt = recentAttempts.reduce((a, b) => a < b ? a : b);
      final retryAfterMs = windowMs - (now - oldestAttempt);
      return RateLimitResult.exceeded(
        retryAfterSeconds: (retryAfterMs / 1000).ceil(),
      );
    }
    
    // Registrar nuevo intento
    recentAttempts.add(now);
    await prefs.setStringList(
      key,
      recentAttempts.map((e) => e.toString()).toList(),
    );
    
    final remaining = limit.maxAttempts - recentAttempts.length;
    return RateLimitResult.allowed(remaining: remaining);
  }
  
  static Future<void> resetLimit(RateLimitAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${action.code}';
    await prefs.remove(key);
  }
}

class RateLimitResult {
  final bool isAllowed;
  final int? remaining;
  final int? retryAfterSeconds;
  
  RateLimitResult.allowed({required this.remaining})
      : isAllowed = true,
        retryAfterSeconds = null;
  
  RateLimitResult.exceeded({required this.retryAfterSeconds})
      : isAllowed = false,
        remaining = null;
  
  String get errorMessage {
    if (isAllowed) return '';
    final minutes = (retryAfterSeconds! / 60).ceil();
    return 'Demasiados intentos. Por favor espera $minutes minutos.';
  }
}
```

**Usar en AuthController:**

```dart
// lib/src/adapters/in/controllers/auth_controller.dart (MODIFICAR)
import '../../infrastructure/security/rate_limiter.dart';

Future<void> registerWithEmail(String email, String password) async {
  // ✅ Verificar rate limit ANTES de intentar registro
  final rateLimit = await RateLimiter.checkLimit(RateLimitAction.register);
  if (!rateLimit.isAllowed) {
    _errorMessage = rateLimit.errorMessage;
    notifyListeners();
    return;
  }
  
  try {
    _errorMessage = null;
    _status = AuthStatus.authenticating;
    notifyListeners();
    await _authPort.signUpWithEmail(email, password);
    await _authPort.sendEmailVerification();
    await _authPort.signOut();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  } catch (e) {
    _errorMessage = _parseAuthError(e);
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    rethrow;
  }
}

Future<void> recoverPassword(String email) async {
  // ✅ Verificar rate limit para password reset
  final rateLimit = await RateLimiter.checkLimit(RateLimitAction.passwordReset);
  if (!rateLimit.isAllowed) {
    _errorMessage = rateLimit.errorMessage;
    notifyListeners();
    throw Exception(rateLimit.errorMessage);
  }
  
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
```

**Paso 2: Rate Limiting en Backend con Cloud Functions (4h)**

```bash
# Instalar Firebase Functions
npm install -g firebase-tools
firebase init functions
# Seleccionar: JavaScript o TypeScript
```

```javascript
// functions/index.js (NUEVO)
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Rate limiter usando Firestore
async function checkRateLimit(userId, action, maxAttempts, windowMs) {
  const now = Date.now();
  const windowStart = now - windowMs;
  
  const attemptsRef = admin.firestore()
    .collection('rate_limits')
    .doc(userId)
    .collection(action);
  
  // Obtener intentos recientes
  const recentAttempts = await attemptsRef
    .where('timestamp', '>', windowStart)
    .get();
  
  if (recentAttempts.size >= maxAttempts) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `Rate limit exceeded. Max ${maxAttempts} attempts per ${windowMs/1000}s`
    );
  }
  
  // Registrar nuevo intento
  await attemptsRef.add({ timestamp: now });
  
  // Cleanup de intentos antiguos (después de 2x window)
  const oldAttempts = await attemptsRef
    .where('timestamp', '<', now - (windowMs * 2))
    .get();
  
  const batch = admin.firestore().batch();
  oldAttempts.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  
  return {
    remaining: maxAttempts - recentAttempts.size - 1,
  };
}

// Cloud Function para crear inspección con rate limiting
exports.createInspection = functions.https.onCall(async (data, context) => {
  // Validar autenticación
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }
  
  // ✅ Rate limit: 10 inspecciones por hora
  await checkRateLimit(
    context.auth.uid,
    'create_inspection',
    10,
    60 * 60 * 1000
  );
  
  // Validar datos
  if (!data.clase || !data.confianza) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }
  
  // Crear inspección
  const docRef = await admin.firestore().collection('inspecciones').add({
    userId: context.auth.uid,
    userEmail: context.auth.token.email,
    clase: data.clase,
    confianza: data.confianza,
    latitud: data.latitud || null,
    longitud: data.longitud || null,
    direccion: data.direccion || null,
    observaciones: data.observaciones || null,
    imagenUrl: data.imagenUrl,
    fechaHora: admin.firestore.FieldValue.serverTimestamp(),
    requiereIntervencion: data.requiereIntervencion || false,
    requiereMonitoreo: data.requiereMonitoreo || false,
  });
  
  return { id: docRef.id };
});

// Desplegar:
// firebase deploy --only functions
```

#### Estrategia de Validación

**Test Manual - Rate Limiting Cliente:**

```bash
# Test 1: Límite de registros
# 1. Intentar registrar 4 cuentas consecutivas con emails diferentes
# ✅ Esperado: Primeras 3 exitosas, 4ta bloqueada con mensaje "espera 60 minutos"

# Test 2: Límite de password reset
# 1. Solicitar reset de password 4 veces
# ✅ Esperado: Primeras 3 exitosas, 4ta bloqueada

# Test 3: Límite de creación de inspecciones
# 1. Crear 11 inspecciones rápidamente
# ✅ Esperado: Primeras 10 exitosas, 11va bloqueada
```

**Test Manual - Rate Limiting Backend:**

```dart
// Test desde Flutter
final functions = FirebaseFunctions.instance;
for (int i = 0; i < 12; i++) {
  try {
    final result = await functions.httpsCallable('createInspection').call({
      'clase': 'leve',
      'confianza': 0.8,
      'imagenUrl': 'https://example.com/image.jpg',
    });
    print('Inspección $i creada: ${result.data['id']}');
  } catch (e) {
    print('Error en inspección $i: $e');
    // ✅ Esperado: Error de rate limit después de 10
  }
}
```

#### Estrategia de Rollback

**Opción 1: Desactivar rate limiting con feature flag**

```dart
// lib/src/infrastructure/security/rate_limiter.dart (MODIFICAR)
static Future<RateLimitResult> checkLimit(RateLimitAction action) async {
  // ✅ Bypass si feature flag está desactivado
  if (!SecurityFeatures.rateLimitingEnabled) {
    return RateLimitResult.allowed(remaining: 999);
  }
  
  // ... resto del código ...
}
```

**Opción 2: Incrementar límites temporalmente**

```dart
// Cambiar configuración sin redeploy
static const _limits = {
  RateLimitAction.register: (
    maxAttempts: SecurityFeatures.rateLimitingEnabled ? 3 : 999,
    windowMinutes: 60
  ),
  // ...
};
```

**Opción 3: Eliminar Cloud Functions**

```bash
# Si Cloud Functions causan problemas
firebase functions:delete createInspection
# App vuelve a usar adaptador directo a Firestore
```

#### Criterios de Aceptación

- ✅ Rate limiter en cliente funciona correctamente
- ✅ Límites configurados previenen abuso (3 registros/hora, 5 logins/15min, 10 inspecciones/hora)
- ✅ Mensajes de error son claros y amigables
- ✅ Cloud Function de rate limiting desplegada (opcional)
- ✅ Tests manuales confirman límites funcionando
- ✅ Feature flag permite desactivar rate limiting si hay problemas
- ✅ Sin afectación a usuarios normales (no alcanzan límites)
- ✅ Monitoreo en Firebase muestra intentos bloqueados

---

### SEC-006: Logging de Seguridad Completo

**Vulnerabilidad:** VULN-030  
**Riesgo:** 🔴 **CRÍTICO**  
**Prioridad:** 🔴 **P0 - CRÍTICO**  
**Tiempo Estimado:** 6 horas

#### Impacto de la Vulnerabilidad

- 🔴 **Detección:** Imposible detectar ataques en curso
- 🔴 **Respuesta:** Sin logs, no se puede investigar incidentes
- 🔴 **Compliance:** Violación de GDPR, CCPA

#### Componentes Afectados

- `lib/src/infrastructure/logging/security_logger.dart` (nuevo)
- Todos los controladores (auth, classification)
- Firebase Crashlytics
- Firebase Analytics
- Firestore (colección `security_logs`)

#### Estrategia de Mitigación

Ver auditoría OWASP (líneas 2880-3100) para código completo de `SecurityLogger`.

**Implementación resumida:**

```yaml
# pubspec.yaml
dependencies:
  firebase_crashlytics: ^4.0.0
  firebase_analytics: ^11.0.0
  logger: ^2.0.0
  device_info_plus: ^9.1.0
  package_info_plus: ^5.0.0
```

```dart
// lib/src/infrastructure/logging/security_logger.dart
// (Ver código completo en auditoría OWASP)

// Eventos a loggear:
enum SecurityEvent {
  loginSuccess,
  loginFailure,
  loginLocked,
  logout,
  registerUser,
  passwordReset,
  emailVerified,
  dataCreate,
  dataModify,
  dataDelete,
  dataExport,
  permissionDenied,
  rateLimitExceeded,
  sessionExpired,
  suspiciousActivity,
}

// Uso en AuthController:
await SecurityLogger.logSecurityEvent(
  SecurityEvent.loginSuccess,
  userId: currentUser.id,
  email: email,
);
```

#### Estrategia de Validación

```bash
# Verificar logs en Firebase Console
# 1. Firebase Console → Analytics → Events
# ✅ Debe mostrar eventos: security_loginSuccess, security_loginFailure

# 2. Firebase Console → Crashlytics → Breadcrumbs
# ✅ Debe mostrar eventos críticos registrados

# 3. Firebase Console → Firestore → security_logs collection
# ✅ Debe contener documentos con eventos de seguridad completos
```

#### Estrategia de Rollback

- Desactivar feature flag `security_logging_enabled`
- Logs dejan de escribirse, sin afectar funcionalidad

#### Criterios de Aceptación

- ✅ `SecurityLogger` implementado y funcionando
- ✅ Eventos de autenticación loggeados (login, register, logout)
- ✅ Eventos de datos loggeados (create, modify, delete)
- ✅ Logs incluyen metadata (deviceId, IP, timestamp)
- ✅ Logs visibles en Firebase Console
- ✅ Sin degradación de rendimiento (<50ms overhead)

---

## RESUMEN DE FASE 1

**Total de Vulnerabilidades Críticas Remediadas:** 7  
**Tiempo Total Fase 1:** 38 horas (~5 días)  
**Score Estimado Después de Fase 1:** 5.5/10 (MEDIO)

**Vulnerabilidades P0 Remediadas:**

| # | Vulnerabilidad | Estado |
|---|----------------|--------|
| VULN-001 | Firestore Security Rules | ✅ Remediado |
| VULN-002 | Validación de Ownership | ✅ Remediado |
| VULN-005 | Credenciales Hardcoded | ✅ Remediado |
| VULN-006 | Firebase API Keys | ✅ Remediado (App Check) |
| VULN-012 | Sin Rate Limiting | ✅ Remediado |
| VULN-016 | Security Rules (duplicado) | ✅ Remediado |
| VULN-030 | Sin Logging | ✅ Remediado |

**Próximas Fases:**
- **Fase 2:** Protección de Acceso (P1) - Semanas 4-5
- **Fase 3:** Hardening y Cifrado (P1-P2) - Semana 6
- **Fase 4:** Monitoreo y Validación (P2-P3) - Semanas 7-8

---

## ESTRATEGIA GLOBAL DE PRESERVACIÓN DE FUNCIONALIDAD

### Principios de No-Regresión

1. **Feature Flags Obligatorios**
   - Cada remediación debe tener feature flag
   - Permite rollback instantáneo sin redeploy

2. **Validación Progresiva**
   - Dev → Staging → Prod
   - Mínimo 48h en cada ambiente antes de avanzar

3. **Backward Compatibility**
   - Código nuevo debe manejar datos antiguos
   - Ejemplo: inspecciones sin `userId` → asignar "sistema"

4. **Tests de Regresión**
   - Smoke tests automatizados antes de cada despliegue
   - Validar flujos críticos: login, clasificar, guardar

5. **Monitoreo Activo**
   - Firebase Analytics: monitorear crash rate
   - Objetivo: <2% crash rate post-despliegue

6. **Plan de Comunicación**
   - Notificar a usuarios de cambios de seguridad
   - Documentar nuevos requisitos (ej: verificación de email)

---

## MÉTRICAS DE ÉXITO

### Objetivos Cuantificables

| Métrica | Antes | Objetivo | Medición |
|---------|-------|----------|----------|
| **Score OWASP** | 3.2/10 | ≥7.0/10 | Auditoría post-implementación |
| **Vulnerabilidades Críticas** | 15 | 0 | Escaneo de seguridad |
| **Crash Rate** | <2% | <2% | Firebase Crashlytics |
| **Tiempo de Login** | <2s | <3s | Firebase Performance |
| **Cobertura de Logs** | 0% | 100% | Revisión manual |
| **Rate Limit Violations** | N/A | <1% | Logs de security |

### Criterios de Aprobación para Producción

- ✅ Todas las vulnerabilidades P0 remediadas
- ✅ Score OWASP ≥7.0/10
- ✅ Firestore Security Rules desplegadas y validadas
- ✅ App Check activo y enforced
- ✅ Rate limiting funcionando sin afectar usuarios legítimos
- ✅ Logging de seguridad operacional
- ✅ Tests de penetración básicos pasados
- ✅ Sin regresiones funcionales detectadas
- ✅ Documentación de seguridad completa

---

## RIESGOS DE IMPLEMENTACIÓN

### Riesgos Técnicos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **Security Rules bloquean usuarios legítimos** | Media | Alto | Testing exhaustivo en staging, rollback inmediato disponible |
| **App Check causa latencia** | Baja | Medio | Monitorear Firebase Performance, desactivar si latencia >100ms |
| **Rate Limiting muy restrictivo** | Media | Medio | Ajustar límites basado en métricas reales, feature flag para desactivar |
| **Logging consume mucho Firestore** | Baja | Bajo | Limitar logs a eventos críticos, cleanup automático >30 días |
| **Migración de datos falla** | Baja | Alto | Backup completo antes de migración, script de rollback |

### Riesgos de Proyecto

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **Cambios toman más tiempo del estimado** | Alta | Medio | Buffer del 30% en estimaciones, priorizar P0 sobre P1-P3 |
| **Conflictos con otras funcionalidades** | Media | Alto | Coordinación con equipo, branch separado para seguridad |
| **Falta de recursos para testing** | Media | Alto | Automatizar tests donde sea posible, smoke tests mínimos |
| **Usuarios rechazan cambios (ej: email verification)** | Baja | Medio | Comunicación clara de beneficios de seguridad |

### Riesgos de Negocio

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **Tiempo de implementación retrasa lanzamiento** | Media | Alto | Plan flexible, MVP de seguridad con solo P0 |
| **Costos de Firebase/Cloudinary aumentan** | Baja | Medio | Monitorear facturación, alertas de presupuesto |
| **Incidente de seguridad antes de completar plan** | Media | Crítico | Priorizar P0, monitoreo activo mientras se implementa |

---

## PLAN DE CONTINGENCIA

### Si se Detecta Incidente de Seguridad Durante Implementación

1. **Pausa inmediata del plan de remediación**
2. **Activar protocolo de respuesta a incidentes:**
   - Aislar sistema comprometido
   - Analizar logs disponibles
   - Notificar a usuarios afectados
   - Implementar remediación de emergencia
3. **Acelerar remediaciones P0 relacionadas con el incidente**
4. **Auditoría post-incidente antes de continuar**

### Si Remediación Causa Regresión Crítica

1. **Rollback inmediato** (feature flag o revert de código)
2. **Análisis de causa raíz**
3. **Re-implementación con correcciones**
4. **Testing extendido antes de re-despliegue**

---

## CONCLUSIÓN Y PRÓXIMOS PASOS

### Estado Actual del Plan

Este plan de remediación cubre las **7 vulnerabilidades críticas (P0)** identificadas en la auditoría OWASP. La implementación completa de la Fase 1 elevará el score de seguridad de **3.2/10 a ~5.5/10**, eliminando los riesgos más severos.

### Recomendación Inmediata

**INICIAR FASE 1 INMEDIATAMENTE** con los siguientes pasos:

1. **Día 1-2:** PREP-001 y PREP-002 (Backups y feature flags)
2. **Día 3-5:** SEC-001 (Firestore Security Rules) en dev
3. **Día 6-7:** SEC-002 y SEC-003 (Ownership y credenciales)
4. **Día 8-10:** SEC-004, SEC-005, SEC-006 (App Check, Rate Limiting, Logging)

### Próxima Auditoría

Después de completar Fase 1 (Semana 3):
- Ejecutar auditoría de seguridad intermedia
- Validar score objetivo de 5.5/10 alcanzado
- Decidir priorización de Fases 2-4 basado en resultados

---

**Documento Aprobado por:**  
Arquitecto de Seguridad - Asistente IA  
**Fecha:** 11 de junio de 2026  
**Versión:** 1.0

**Próxima Revisión:** Post-Fase 1 (Estimado: Semana del 2 de julio de 2026)

---

**NOTA IMPORTANTE:** Este plan asume que el sistema puede permanecer en operación durante la implementación. Si se requiere downtime, coordinar ventanas de mantenimiento con anticipación.

---

**Fin del Plan de Remediación OWASP Top 10**
