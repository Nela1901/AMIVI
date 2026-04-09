El archivo .py: Ponlo directamente en lib/src/adapters/out/ai/poc/classification_poc.py. Esto es el código "crudo".
El archivo .ipynb (Opcional): También puedes ponerlo ahí mismo. GitHub permite verlo muy bonito desde la web.
El Enlace al Colab: Aquí es donde entra la documentación. En lugar de "pegar el link" en el código, lo correcto es crear un archivo README.md dentro de esa misma carpeta (lib/src/adapters/out/ai/poc/README.md).


# AMIVI - Aplicación Móvil de Inspección Vial Inteligente 

AMIVI es un proyecto académico diseñado para la detección, registro y visualización de daños viales (baches) utilizando Inteligencia Artificial, geolocalización y Arquitectura Hexagonal en Flutter.

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

## PoC - Inteligencia Artificial (PMV 1)

Como parte del primer hito (PMV 1), se desarrolló una **Prueba de Concepto (PoC)** para validar la clasificación automática de daños viales.

### Detalles Técnicos:
*   **Modelo:** Transfer Learning con **MobileNetV2** (ideal para dispositivos móviles).
*   **Dataset:** 400 imágenes clasificadas en 4 niveles: `Normal`, `Leve`, `Moderado` y `Severo`.
*   **Resultados:** Se logró un **95% de Accuracy** en el conjunto de prueba (Test Set).

### Ubicación de la PoC en la Arquitectura:
Siguiendo la investigación arquitectónica, el código de la PoC se encuentra en:
`lib/src/adapters/out/ai/poc/`

Aquí se encuentran los archivos:
1.  `PoC_Clasificación_de_Daños_Viales_(PMV_1).ipynb`: Notebook interactivo con visualizaciones y resultados.
2.  `poc_clasificación_de_daños_viales_(pmv_1).py`: Script de Python con la lógica de construcción y entrenamiento del modelo.

> **Nota:** La integración de la PoC dentro de los adaptadores de salida (`adapters/out`) justifica que la IA es una herramienta técnica que satisface los requerimientos definidos en el dominio del proyecto.

---

## Tecnologías Utilizadas

*   **Flutter & Dart:** Para el desarrollo de la aplicación móvil.
*   **Python & TensorFlow/Keras:** Para el entrenamiento del modelo de visión computacional.
*   **Google Colab:** Entorno de experimentación para la PoC.
