# AMIVI - Aplicación Móvil de Inspección Vial Inteligente 

AMIVI es un proyecto académico diseñado para la detección, registro y visualización de daños viales (baches) utilizando Inteligencia Artificial, geolocalización y Arquitectura Hexagonal en Flutter.

## Equipo del Proyecto
*   **Arquitecto de Software:** Espinoza Tiza Yago Imanol
*   **Ingeniero de IA:** Uscuvilca Ramos Abraham Luis
*   **Desarrollador Backend:** Guerra Lozano Keen
*   **Desarrolladora Frontend e Implementación Core:** Inciso Aguilar Elizabeth Antonela
*   **Ingeniero de Integración:** Janampa Navarro Clinton

**Curso:** Taller de Proyectos 1 | **NRC:** 28601

## Arquitectura del Proyecto

El proyecto sigue los principios de la **Arquitectura Hexagonal (Ports & Adapters)** para garantizar escalabilidad, mantenibilidad y desacoplamiento de la lógica de negocio frente a las tecnologías externas.

### Estructura de Capas:
*   **Domain:** El corazón de la aplicación. Contiene las entidades (`RoadIncidence`) y objetos de valor (`DamageSeverity`) que definen las reglas del negocio, sin dependencias de frameworks.
*   **Application:** Define los casos de uso (como "Analizar Daño") y los puertos (interfaces) que actúan como contratos para los adaptadores.
*   **Adapters:** Implementaciones técnicas.
    *   **In:** Controladores de la interfaz de usuario.
    *   **Out:** Persistencia de datos y el motor de IA.
*   **Infrastructure:** Configuración global y el "pegamento" del sistema (Inyección de Dependencias).

---

## Ingeniería del Producto y AI

Como parte del primer hito (PMV 1), se implementó un motor de clasificación automática de daños viales integrado mediante puertos y adaptadores.

### Estándares de Calidad Aplicados:
1.  **Desacoplamiento:** Uso de Puertos para la IA, permitiendo cambiar el modelo TFLite sin afectar la UI.
2.  **Interpretabilidad:** Implementación de Grad-CAM para asegurar que la IA sea auditable.
3.  **Trazabilidad:** Registro georreferenciado automático vinculado a evidencias en la nube.

### Detalles Técnicos:
*   **Modelo:** Transfer Learning con **MobileNetV2** (ideal para dispositivos móviles).
*   **Dataset:** 500 imágenes clasificadas en 3 niveles: `Normal`, `Leve` y `Dañado`.
*   **Resultados:** Se logró un **95% de Accuracy** en el conjunto de prueba (Test Set) para las 3 clases.

**Modelos:** Los artefactos `.tflite` se encuentran en `lib/src/adapters/out/ai/models/`.

## Tecnologías Utilizadas

*   **Flutter & Dart:** Para el desarrollo de la aplicación móvil.
*   **Python & TensorFlow/Keras:** Para el entrenamiento del modelo de visión computacional.

## Lecciones Aprendidas y Conclusiones

1. **Arquitectura Escalable:** La separación en capas (Hexagonal) permite una independencia total de la base de datos y frameworks, facilitando el mantenimiento a largo plazo.
2. **IA Interpretable (XAI):** El uso de Grad-CAM elimina el efecto de "caja negra", permitiendo a los inspectores visualizar la zona de falla detectada por el modelo.
3. **Optimización Móvil:** La implementación de modelos ligeros (MobileNetV2 + TFLite) garantiza un rendimiento fluido sin comprometer los recursos del dispositivo.
4. **Validación de Datos (Human-in-the-loop):** El flujo de confirmación manual previene que errores de predicción afecten la integridad de los reportes viales.
5. **Trazabilidad:** La integración nativa con GPS y servicios en la nube asegura que cada incidencia sea auditable y localizable en tiempo real.
