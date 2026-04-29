El archivo .py: Ponlo directamente en lib/src/adapters/out/ai/poc/classification_poc.py. Esto es el código "crudo".
El archivo .ipynb (Opcional): También puedes ponerlo ahí mismo. GitHub permite verlo muy bonito desde la web.
El Enlace al Colab: Aquí es donde entra la documentación. En lugar de "pegar el link" en el código, lo correcto es crear un archivo README.md dentro de esa misma carpeta (lib/src/adapters/out/ai/poc/README.md).


# AMIVI - Aplicación Móvil de Inspección Vial Inteligente 

AMIVI es un proyecto académico diseñado para la detección, registro y visualización de daños viales (baches) utilizando Inteligencia Artificial, geolocalización y Arquitectura Hexagonal en Flutter.

## Equipo del Proyecto (Roles)
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

## Entorno de Calidad y Machine Learning

Como parte del primer hito (PMV 1), se desarrolló una **Prueba de Concepto (PoC)** para validar la clasificación automática de daños viales.

### Estándares de Calidad Aplicados:
1.  **Desacoplamiento:** Uso de Puertos para la IA, permitiendo cambiar el modelo TFLite sin afectar la UI.
2.  **Interpretabilidad:** Implementación de Grad-CAM para asegurar que la IA sea auditable.
3.  **Trazabilidad:** Registro georreferenciado automático vinculado a evidencias en la nube.

### Detalles Técnicos:
*   **Modelo:** Transfer Learning con **MobileNetV2** (ideal para dispositivos móviles).
*   **Dataset:** 500 imágenes clasificadas en 3 niveles: `Normal`, `Leve` y `Dañado`.
*   **Resultados:** Se logró un **95% de Accuracy** en el conjunto de prueba (Test Set) para las 3 clases.

**Modelos:** Los archivos productivos `.tflite` se encuentran en `lib/src/adapters/out/ai/models/`.

## Tecnologías Utilizadas

*   **Flutter & Dart:** Para el desarrollo de la aplicación móvil.
*   **Python & TensorFlow/Keras:** Para el entrenamiento del modelo de visión computacional.
*   **Google Colab:** Entorno de experimentación para la PoC.
