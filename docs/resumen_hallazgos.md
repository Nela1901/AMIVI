# RESUMEN EJECUTIVO DE AUDITORÍA Y PLANES DE MEJORA
## Proyecto AMIVI - Aplicación Móvil de Inspección Vial Inteligente

**Institución:** Universidad  
**Fecha de Elaboración:** 11 de junio de 2026  
**Tipo de Documento:** Informe de Auditoría Técnica  
**Alcance:** Evaluación de Calidad (FURPS+) y Seguridad (OWASP Top 10)

---

## 1. INTRODUCCIÓN

El presente documento consolida los hallazgos de las auditorías de calidad y seguridad realizadas al proyecto AMIVI (Aplicación Móvil de Inspección Vial Inteligente), así como los planes de mejora propuestos. El sistema bajo evaluación es una aplicación móvil desarrollada en Flutter que implementa detección automática de daños viales mediante técnicas de Inteligencia Artificial, específicamente utilizando TensorFlow Lite con el modelo MobileNetV2.

### 1.1 Metodología de Evaluación

Se aplicaron dos marcos de evaluación complementarios:

1. **Modelo FURPS+**: Evaluación de calidad de software en cinco dimensiones (Funcionalidad, Usabilidad, Confiabilidad, Rendimiento y Mantenibilidad)
2. **OWASP Top 10:2021**: Análisis de vulnerabilidades de seguridad según las categorías más críticas definidas por el Open Web Application Security Project

### 1.2 Contexto del Proyecto

AMIVI constituye un proyecto académico que implementa una arquitectura hexagonal (Ports & Adapters) integrando los siguientes componentes tecnológicos:

- **Framework de desarrollo**: Flutter 3.11.4 con lenguaje Dart
- **Backend**: Firebase (Authentication, Firestore, Storage)
- **Inteligencia Artificial**: TensorFlow Lite (MobileNetV2, precisión reportada del 95%)
- **Servicios de geolocalización**: Geolocator + Geocoding
- **Almacenamiento de imágenes**: Cloudinary
- **Cartografía**: Google Maps Flutter

---

## 2. HALLAZGOS DE CALIDAD (FURPS+)

### 2.1 Evaluación General

**Calificación Global: 7.2/10** (BUENO - CON ÁREAS DE MEJORA)

El sistema presenta una base arquitectónica sólida y funcionalidad core operativa, no obstante, requiere mejoras significativas en aspectos de confiabilidad, rendimiento y mantenibilidad para alcanzar estándares de producción.

### 2.2 Evaluación por Dimensión

| Dimensión | Calificación | Estado | Observaciones Principales |
|-----------|--------------|--------|---------------------------|
| **Funcionalidad (F)** | 8.5/10 | Satisfactorio | 94% de casos de uso implementados (15/16) |
| **Usabilidad (U)** | 7.0/10 | Aceptable | Interfaz funcional, requiere mejoras de accesibilidad |
| **Confiabilidad (R)** | 6.0/10 | Deficiente | Ausencia de manejo de excepciones críticas |
| **Rendimiento (P)** | 6.5/10 | Aceptable | Algoritmos ineficientes (O(n²)) en operaciones de clustering |
| **Mantenibilidad (S)** | 5.5/10 | Deficiente | Archivo monolítico de 1629 líneas, 0% cobertura de tests |

### 2.3 Fortalezas Identificadas

1. **Arquitectura Hexagonal**: Correcta implementación de separación de responsabilidades entre capas de dominio, aplicación y adaptadores
2. **Integración de IA**: Implementación exitosa de inferencia on-device con TensorFlow Lite
3. **Funcionalidad Offline-First**: Sistema de almacenamiento local con sincronización manual operativo
4. **Interpretabilidad**: Implementación de Grad-CAM para explicabilidad de predicciones de IA

### 2.4 Debilidades Críticas

1. **Ausencia Total de Tests Automatizados**: Cobertura del 0%, imposibilidad de detectar regresiones
2. **Código Monolítico**: Archivo `main.dart` con 1629 líneas, conteniendo múltiples pantallas y lógica mezclada
3. **Sin Manejo de Excepciones**: Inferencia de IA sin bloque try-catch, potenciales crashes en caso de memoria insuficiente
4. **Algoritmos Ineficientes**: Cálculo de hotspots con complejidad O(n²), limitación a menos de 500 registros
5. **Credenciales Hardcoded**: Claves de Cloudinary expuestas en código fuente
6. **Sin Logging Estructurado**: Ausencia de instrumentación para debugging en producción
7. **Consumo Agresivo de Batería**: Configuración de GPS con `distanceFilter: 10m` sin throttling
8. **Sin Paginación**: Queries de Firestore sin límites, riesgo de saturación con más de 1000 registros

### 2.5 Estimación de Deuda Técnica

**Tiempo estimado de resolución**: 18-22 días de trabajo de desarrollo

---

## 3. HALLAZGOS DE SEGURIDAD (OWASP TOP 10)

### 3.1 Evaluación General

**Score de Seguridad: 3.2/10** (ESTADO CRÍTICO)

El sistema presenta múltiples vulnerabilidades de seguridad críticas que comprometen la confidencialidad, integridad y disponibilidad de los datos. Se identificaron 30 vulnerabilidades distribuidas en las siguientes severidades:

- **Críticas**: 15 vulnerabilidades (50%)
- **Altas**: 8 vulnerabilidades (27%)
- **Medias**: 7 vulnerabilidades (23%)

**Riesgo de Compromiso Estimado**: 85%  
**Tiempo Estimado para Ataque Exitoso**: Menos de 1 hora de exposición pública

### 3.2 Distribución por Categoría OWASP

| Categoría | Score | Hallazgos | Severidad |
|-----------|-------|-----------|-----------|
| A01: Broken Access Control | 2.0/10 | 4 | CRÍTICO |
| A02: Cryptographic Failures | 1.5/10 | 5 | CRÍTICO |
| A03: Injection | 6.0/10 | 2 | MEDIO |
| A04: Insecure Design | 3.5/10 | 4 | CRÍTICO |
| A05: Security Misconfiguration | 2.5/10 | 6 | CRÍTICO |
| A06: Vulnerable Components | 5.5/10 | 3 | MEDIO |
| A07: Authentication Failures | 4.0/10 | 3 | ALTO |
| A08: Data Integrity Failures | 4.5/10 | 2 | ALTO |
| A09: Logging and Monitoring | 1.0/10 | 1 | CRÍTICO |
| A10: SSRF | 8.0/10 | 0 | ACEPTABLE |

### 3.3 Vulnerabilidades Críticas (P0)

#### VULN-001: Ausencia de Firestore Security Rules

**Severidad**: CRÍTICA  
**Evidencia**: No existe archivo `firestore.rules` en el repositorio  
**Impacto**: Base de datos completamente expuesta; cualquier usuario puede leer, modificar o eliminar todos los registros sin autorización

#### VULN-002: Sin Validación de Ownership

**Severidad**: CRÍTICA  
**Evidencia**: Operaciones de escritura no incluyen campo `userId`  
**Impacto**: Imposibilidad de validar propiedad de registros, permitiendo modificación de datos ajenos

#### VULN-005: Credenciales Hardcoded

**Severidad**: CRÍTICA  
**Evidencia**: Credenciales de Cloudinary expuestas en código fuente (`firestore_adapter.dart:11-12`)  
**Impacto**: Acceso no autorizado a servicio de almacenamiento, riesgo de costos descontrolados y exposición de contenido

#### VULN-006: Firebase API Keys Expuestas

**Severidad**: ALTA  
**Evidencia**: Ausencia de Firebase App Check  
**Impacto**: Abuso de cuota de servicios, scraping de base de datos

#### VULN-012: Ausencia de Rate Limiting

**Severidad**: CRÍTICA  
**Evidencia**: No existe protección contra operaciones masivas  
**Impacto**: Denegación de servicio por spam de registros, uploads ilimitados, saturación de recursos

#### VULN-030: Sin Logging de Seguridad

**Severidad**: CRÍTICA  
**Evidencia**: Ausencia de registro de eventos de autenticación y acceso  
**Impacto**: Imposibilidad de detección de ataques, sin evidencia forense

### 3.4 Otras Vulnerabilidades Relevantes

- **VULN-007**: Almacenamiento local sin cifrado (datos sensibles en texto plano)
- **VULN-008**: Sin validación de complejidad de contraseñas
- **VULN-013**: Ausencia de validación de duplicados (permite spam de datos)
- **VULN-017**: Uso de keystore de debug en builds de release
- **VULN-025**: Sin verificación obligatoria de email en registro

---

## 4. PLAN DE MEJORA DE CALIDAD (FURPS+)

### 4.1 Estructura del Plan

**Duración Total**: 16 semanas (4 meses)  
**Número de Mejoras**: 14 mejoras priorizadas  
**Esfuerzo Estimado**: ~120 horas de desarrollo  
**Inversión Aproximada**: $12,000 - $18,000 USD (asumiendo $100-150/hora)

### 4.2 Fases del Plan

#### Fase 0: Preparación (Semanas 1-2)

**Objetivo**: Establecer infraestructura base para cambios seguros

- MEJ-001: Externalización de credenciales mediante `flutter_dotenv`
- MEJ-002: Implementación de feature flags con Firebase Remote Config

#### Fase 1: Estabilización Crítica (Semanas 3-6)

**Objetivo**: Resolver problemas que afectan confiabilidad del sistema

- MEJ-003: Manejo de excepciones en inferencia de IA
- MEJ-004: Logging estructurado con Firebase Crashlytics
- MEJ-005: Throttling de GPS para optimización de batería
- MEJ-006: Suite de testing base (objetivo: 30% cobertura)

#### Fase 2: Optimización de Rendimiento (Semanas 7-10)

**Objetivo**: Mejorar escalabilidad del sistema

- MEJ-007: Algoritmo eficiente para cálculo de hotspots (DBSCAN o quadtree)
- MEJ-008: Implementación de paginación en queries de Firestore
- MEJ-009: Sistema de caché para reverse geocoding

#### Fase 3: Refactoring y Mantenibilidad (Semanas 11-13)

**Objetivo**: Reducir deuda técnica y facilitar mantenimiento

- MEJ-010: Extracción de screens desde archivo monolítico `main.dart`
- MEJ-011: Reemplazo de "magic numbers" por constantes nombradas
- MEJ-012: Migración a Dependency Injection con GetIt

#### Fase 4: Nuevas Capacidades (Semanas 14-16)

**Objetivo**: Completar funcionalidades pendientes

- MEJ-013: Implementación completa de notificaciones locales (HU-22)
- MEJ-014: Internacionalización (español e inglés)

### 4.3 Principios de Implementación

Todas las mejoras deben adherirse a los siguientes principios:

1. **Compatibilidad hacia atrás**: Cambios no deben romper funcionalidad existente
2. **Cambios incrementales**: Implementación en pasos validables de 1-2 semanas
3. **Riesgo mínimo**: Preferencia por cambios aislados sobre refactorizaciones masivas
4. **Validación obligatoria**: Cada mejora requiere criterios de aceptación y tests
5. **Posibilidad de rollback**: Reversibilidad en menos de 1 hora mediante feature toggles

### 4.4 Score Objetivo

**Score FURPS+ Objetivo**: ≥8.5/10 (EXCELENTE - PRODUCTION-READY)

---

## 5. PLAN DE REMEDIACIÓN DE SEGURIDAD (OWASP)

### 5.1 Estructura del Plan

**Duración Total**: 8 semanas (2 meses)  
**Número de Remediaciones**: 30 vulnerabilidades  
**Esfuerzo Estimado**: ~130 horas de desarrollo  
**Inversión Aproximada**: $13,000 - $19,500 USD (asumiendo $100-150/hora)

### 5.2 Fases del Plan

#### Fase 0: Preparación Crítica (Semana 1)

**Objetivo**: Establecer respaldos y entornos de seguridad

- PREP-001: Backup completo de Firebase (Firestore, Authentication, Storage)
- PREP-002: Configuración de feature flags de seguridad

#### Fase 1: Remediación Crítica (Semanas 2-3)

**Objetivo**: Mitigar vulnerabilidades críticas (P0)

- SEC-001: Implementación de Firestore Security Rules (VULN-001, VULN-016)
- SEC-002: Validación de ownership mediante campo `userId` (VULN-002)
- SEC-003: Externalización de credenciales Cloudinary (VULN-005)
- SEC-004: Activación de Firebase App Check (VULN-006)
- SEC-005: Implementación de rate limiting básico (VULN-012)
- SEC-006: Sistema de logging de seguridad (VULN-030)

#### Fase 2: Protección de Acceso (Semanas 4-5)

**Objetivo**: Fortalecer controles de autenticación y autorización

- Sistema de roles y permisos (VULN-003)
- Filtrado de datos por usuario (VULN-004)
- Verificación obligatoria de email (VULN-025)
- Protección contra enumeración de usuarios (VULN-026)

#### Fase 3: Hardening y Cifrado (Semana 6)

**Objetivo**: Proteger datos sensibles

- Cifrado de almacenamiento local con AES-256 (VULN-007)
- Validación de complejidad de contraseñas (VULN-008)
- Configuración de keystore de producción (VULN-017, VULN-028)
- Validación de duplicados (VULN-013)

#### Fase 4: Monitoreo y Validación (Semanas 7-8)

**Objetivo**: Completar hardening del sistema

- Validación de inputs de geolocalización (VULN-014)
- Implementación de SSL Pinning (VULN-009)
- Configuración de package name corporativo (VULN-020)
- Escaneo automatizado de dependencias vulnerables (VULN-022)

### 5.3 Estrategia de Implementación

Cada remediación incluye:

1. **Análisis de impacto**: Evaluación de cambios en funcionalidad existente
2. **Código de ejemplo**: Implementación específica con sintaxis verificada
3. **Validación**: Tests de seguridad específicos
4. **Rollback**: Estrategia de reversión mediante feature flags
5. **Documentación**: Actualización de guías operativas

### 5.4 Score Objetivo

**Score OWASP Objetivo**: ≥7.0/10 (PRODUCCIÓN SEGURA)

---

## 6. INTEGRACIÓN DE PLANES

### 6.1 Solapamiento de Mejoras

Varios elementos aparecen en ambos planes, lo que permite optimización de esfuerzo:

| Mejora | Plan FURPS+ | Plan OWASP | Beneficio Dual |
|--------|-------------|------------|----------------|
| Externalización de credenciales | MEJ-001 | SEC-003 | Calidad + Seguridad |
| Feature flags | MEJ-002 | PREP-002 | Rollback seguro |
| Logging estructurado | MEJ-004 | SEC-006 | Debugging + Auditoría |
| Validación de duplicados | - | VULN-013 | Performance + Seguridad |

### 6.2 Cronograma Consolidado

Ambos planes pueden ejecutarse de forma coordinada:

- **Semanas 1-2**: Preparación (FURPS+ Fase 0 + OWASP Fase 0)
- **Semanas 3-8**: Ejecución paralela de remediaciones críticas y estabilización
- **Semanas 9-16**: Continuación de mejoras FURPS+ mientras se monitorean cambios de seguridad

**Duración Total Optimizada**: 16-20 semanas  
**Esfuerzo Total**: ~250 horas  
**Inversión Total**: $25,000 - $37,500 USD

---

## 7. ANÁLISIS DE RIESGOS

### 7.1 Riesgos de No Implementación

En caso de no implementar las mejoras propuestas, el sistema presenta los siguientes riesgos:

#### Riesgos de Seguridad (Probabilidad: 85%)

1. **Compromiso de base de datos**: Acceso no autorizado a todos los registros en menos de 1 hora
2. **Abuso de credenciales**: Uso malicioso de servicios de Cloudinary con costos descontrolados
3. **Denegación de servicio**: Saturación de recursos mediante spam de operaciones
4. **Sin detección de ataques**: Imposibilidad de investigar incidentes de seguridad

#### Riesgos de Calidad (Probabilidad: 70%)

1. **Regresiones no detectadas**: Cambios futuros pueden romper funcionalidad sin advertencia
2. **Crashes en producción**: Excepciones no manejadas causan terminación abrupta
3. **Degradación de rendimiento**: Sistema inutilizable con más de 500 inspecciones
4. **Imposibilidad de debugging**: Sin logs, errores en producción son imposibles de diagnosticar

### 7.2 Riesgos de Implementación

Los planes propuestos presentan riesgos controlados:

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| Downtime durante despliegue | Baja (10%) | Feature flags + blue-green deployment |
| Incompatibilidad de datos | Baja (15%) | Versionado de schema + migración gradual |
| Regresión funcional | Media (30%) | Suite de tests + smoke tests en staging |
| Impacto en performance | Baja (20%) | Benchmarks antes/después + rollback disponible |

### 7.3 Estrategia de Mitigación de Riesgos

1. **Enfoque incremental**: Cambios pequeños y validables de 1-2 semanas
2. **Entornos separados**: Dev → Staging → Producción con validación en cada etapa
3. **Feature flags**: Capacidad de desactivar cambios en menos de 1 minuto
4. **Backups automatizados**: Respaldos diarios de Firebase con retención de 30 días
5. **Monitoreo continuo**: Alertas automáticas ante errores o degradación de performance

---

## 8. MÉTRICAS DE ÉXITO

### 8.1 Indicadores de Calidad

| Métrica | Estado Actual | Objetivo | Método de Medición |
|---------|---------------|----------|-------------------|
| Score FURPS+ | 7.2/10 | ≥8.5/10 | Evaluación post-implementación |
| Cobertura de tests | 0% | ≥70% | Reporte de coverage |
| Líneas en main.dart | 1629 | <300 | Análisis estático |
| Tiempo de respuesta | Variable | <2s (p95) | APM (Application Performance Monitoring) |
| Crash rate | Desconocido | <0.1% | Firebase Crashlytics |

### 8.2 Indicadores de Seguridad

| Métrica | Estado Actual | Objetivo | Método de Medición |
|---------|---------------|----------|-------------------|
| Score OWASP | 3.2/10 | ≥7.0/10 | Re-auditoría post-implementación |
| Vulnerabilidades críticas | 15 | 0 | Análisis de código + pentesting |
| Tiempo de detección de ataque | ∞ (sin logs) | <5 min | Sistema de logging + alertas |
| Requests sin autenticación | 100% | 0% | Firestore Security Rules |
| Rate de spam | Sin control | <1% | Rate limiter metrics |

### 8.3 Indicadores de Negocio

| Métrica | Estado Actual | Objetivo | Método de Medición |
|---------|---------------|----------|-------------------|
| Tiempo de resolución de bugs | Desconocido | <48h | Sistema de ticketing |
| Costos de infraestructura | Variable | Predecible | Dashboard de Firebase + Cloudinary |
| Satisfacción de usuario | Sin medición | ≥4.0/5.0 | Encuestas in-app + app store ratings |
| Velocidad de desarrollo | Baja | +50% | Análisis de throughput de commits |

---

## 9. RECOMENDACIONES FINALES

### 9.1 Priorización de Esfuerzos

Con base en el análisis de riesgos y retorno de inversión, se recomienda el siguiente orden de implementación:

**Prioridad 1 (Semanas 1-4): Crítico - Seguridad Básica**

1. Implementar Firestore Security Rules (SEC-001)
2. Externalizar credenciales (MEJ-001/SEC-003)
3. Activar Firebase App Check (SEC-004)
4. Implementar rate limiting básico (SEC-005)
5. Agregar validación de ownership (SEC-002)

**Justificación**: Estos cambios mitigan el 80% del riesgo de seguridad crítico sin afectar funcionalidad existente.

**Prioridad 2 (Semanas 5-8): Alto - Estabilización**

1. Implementar logging de seguridad (SEC-006)
2. Agregar manejo de excepciones (MEJ-003)
3. Implementar logging estructurado (MEJ-004)
4. Crear suite de tests base (MEJ-006)

**Justificación**: Establece observabilidad del sistema y capacidad de detección de problemas.

**Prioridad 3 (Semanas 9-16): Medio - Optimización**

1. Optimizar algoritmos de rendimiento (MEJ-007)
2. Implementar paginación (MEJ-008)
3. Refactorizar código monolítico (MEJ-010)
4. Completar remediaciones de seguridad restantes

**Justificación**: Mejora la escalabilidad y mantenibilidad a largo plazo.

### 9.2 Alternativa: Plan Mínimo (4 semanas)

Si los recursos son limitados, se recomienda implementar únicamente las remediaciones críticas de seguridad (Prioridad 1) más el manejo de excepciones y logging básico.

**Resultado esperado**:
- Score OWASP: ~5.5/10 (mejora del 72%)
- Score FURPS+: ~7.8/10 (mejora del 8%)
- Esfuerzo: ~60 horas
- Inversión: $6,000 - $9,000 USD

### 9.3 Estado de Aptitud para Producción

**Dictamen Actual**: **NO APTO PARA PRODUCCIÓN**

El sistema presenta vulnerabilidades críticas de seguridad que lo hacen inapropiado para despliegue en entornos de producción accesibles públicamente. El riesgo de compromiso (85%) y la ausencia de controles de seguridad básicos constituyen un riesgo inaceptable.

**Criterios Mínimos para Producción**:

1. Firestore Security Rules implementadas y validadas
2. Credenciales externalizadas (no hardcoded)
3. Rate limiting operacional
4. Logging de seguridad funcionando
5. Campo userId en todas las inspecciones
6. Suite de tests básica (≥30% cobertura)
7. Manejo de excepciones en componentes críticos
8. Score OWASP ≥5.5/10
9. Score FURPS+ ≥7.8/10

**Estado Actual**: 0/9 criterios cumplidos

### 9.4 Próximos Pasos

1. **Aprobación de presupuesto**: Determinar inversión disponible (plan completo vs. plan mínimo)
2. **Asignación de recursos**: Identificar desarrollador(es) con experiencia en Flutter + Firebase
3. **Configuración de entornos**: Crear proyectos de Firebase para dev/staging/prod
4. **Inicio de implementación**: Comenzar con Prioridad 1 (semanas 1-4)
5. **Auditoría de progreso**: Evaluación cada 2 semanas para ajustar plan según necesidad

---

## 10. CONCLUSIONES

### 10.1 Resumen de Hallazgos

El proyecto AMIVI presenta una base técnica sólida con arquitectura bien estructurada y funcionalidad core operativa. No obstante, el análisis reveló deficiencias significativas en dos áreas críticas:

1. **Seguridad**: Estado crítico (3.2/10) con 15 vulnerabilidades críticas que exponen el sistema a compromiso inmediato
2. **Calidad**: Estado aceptable (7.2/10) pero con debilidades en confiabilidad, testing y mantenibilidad que limitan su viabilidad para producción

### 10.2 Viabilidad de Mejora

Los planes propuestos son técnicamente viables y financieramente razonables:

- **Plan completo**: 20 semanas, ~250 horas, $25,000-37,500 USD
- **Plan mínimo**: 4 semanas, ~60 horas, $6,000-9,000 USD

Ambos planes adhieren a principios de compatibilidad hacia atrás y cambios incrementales, minimizando riesgo de interrupción de funcionalidad existente.

### 10.3 Recomendación Final

Se recomienda enérgicamente la implementación de al menos el **Plan Mínimo de Seguridad** (Prioridad 1) antes de cualquier despliegue a producción. El sistema en su estado actual presenta un riesgo inaceptable de compromiso de seguridad (85% de probabilidad, <1 hora para ataque exitoso).

Para alcanzar un estado production-ready completo, se recomienda la implementación del **Plan Completo** en el horizonte de 20 semanas, lo cual elevará los scores a niveles profesionales (FURPS+ ≥8.5/10, OWASP ≥7.0/10).

### 10.4 Consideraciones Académicas

Desde una perspectiva académica, el proyecto demuestra exitosamente:

- Implementación de arquitectura hexagonal
- Integración de IA on-device con TensorFlow Lite
- Sistema offline-first con sincronización
- Uso de tecnologías actuales de desarrollo móvil

Los planes de mejora propuestos pueden servir como casos de estudio para:

- Auditoría de calidad de software
- Análisis de vulnerabilidades OWASP
- Planificación de remediación de seguridad
- Gestión de deuda técnica
- Estrategias de evolución de sistemas legacy

---

## REFERENCIAS

**Documentos Relacionados:**

1. `docs/01_auditoria_furps.md` - Auditoría de Calidad FURPS+ (detalle completo)
2. `docs/02_plan_furps.md` - Plan de Mejora FURPS+ (especificaciones técnicas)
3. `docs/04_auditoria_owasp.md` - Auditoría de Seguridad OWASP Top 10 (detalle completo)
4. `docs/05_plan_owasp.md` - Plan de Remediación OWASP (especificaciones técnicas)
5. `docs/03_auditoria_implementacion_furps.md` - Auditoría de Implementación de Calidad
6. `docs/06_auditoria_implementacion_owasp.md` - Auditoría de Implementación de Seguridad
7. `docs/07_auditoria_final.md` - Dictamen Final Integral

**Estándares y Frameworks de Referencia:**

- OWASP Top 10:2021 - https://owasp.org/Top10/
- Modelo FURPS+ (Hewlett-Packard, 1992)
- Flutter Security Best Practices - https://flutter.dev/security
- Firebase Security Rules Reference - https://firebase.google.com/docs/rules

---

**Fin del Documento**

**Elaborado por**: Equipo de Auditoría Técnica  
**Revisado por**: Auditor Principal de Calidad y Seguridad  
**Fecha de Publicación**: 11 de junio de 2026  
**Versión**: 1.0
