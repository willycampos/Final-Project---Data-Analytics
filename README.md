# 🏠 El Motor del Valor Inmobiliario en Madrid — Análisis Exploratorio (EDA)

Este repositorio contiene el **Análisis Exploratorio de Datos (EDA)** y la estrategia de **Data Wrangling** aplicada sobre un dataset de **21,742 inmuebles en Madrid** procedentes del portal Idealista (`houses_Madrid.csv`). 

El foco principal de este proyecto es trascender el análisis univariante tradicional y aplicar un **enfoque bivariante**, enfrentando las variables de dos en dos para descubrir los verdaderos multiplicadores e inhibidores del precio de venta (`buy_price`).

---

## 🎯 Objetivos del Proyecto

1. **Aislamiento del Ruido Estadístico:** Limpiar, imputar y estructurar una base de datos compleja con más de 58 variables originales.
2. **Análisis de Impacto Bivariante:** Identificar y modelar cómo interactúan los metros cuadrados, las tipologías y la distribución interna frente al valor de mercado.
3. **Generación de Insights Accionables:** Proveer métricas estadísticas estables (basadas en medianas) para guiar decisiones de inversión en reformas (*flipping*) y tasaciones automatizadas.

---

## 🧼 1. Estrategia de Limpieza de Datos (Data Wrangling)

Antes de realizar cruces de variables, se aplicó un pipeline de curación de datos para garantizar la salud estadística del modelo:
* **Eliminación por Vacío Absoluto:** Columnas con 100% de registros nulos (`latitude`, `longitude`, `portal`, `rent_price_by_area`, etc.) fueron dadas de baja de inmediato.
* **Resolución de Colinealidad:** Se eliminó la variable `sq_mt_useful` debido a que presentaba un **62.2% de nulos**. En su lugar, se priorizó `sq_mt_built` (0.6% de nulos), imputando los registros faltantes mediante la mediana del barrio correspondiente.
* **Tratamiento de Amenidades (Amenities):** Variables como `has_pool` o `has_ac` con altos índices de ausencia se transformaron bajo la regla de negocio: *"La ausencia de registro equivale a la no disponibilidad del servicio (`False`)"*.
* **Remoción de Varianza Cero:** Campos unívocos que no aportaban variabilidad (`operation`, `is_buy_price_known`) se descartaron para optimizar la eficiencia computacional.

---

## 📊 2. Anatomía del Precio y Sesgo del Lujo (Análisis Univariante)

El estudio inicial del precio de venta (`buy_price`) reveló una fuerte distorsión en las métricas tradicionales:
* **Precio Medio:** ~651,691 €
* **Precio Mediano:** ~280,000 €

La visualización mediante histogramas y curvas de densidad KDE muestra una **asimetría positiva extrema (sesgo a la derecha)**. Las propiedades de súper lujo empujan la media artificialmente hacia arriba. 

> ⚠️ **Decisión de Negocio:** Todas las valoraciones y análisis bivariantes subsiguientes se estructuran utilizando la **Mediana** como métrica de referencia para evitar el ruido del sector premium.

---

## 🔀 3. Cruce de Variables e Insights Aplicados (Análisis Bivariante)

### A. El Mapa de Calor (Correlación de Spearman)
Se utilizó el coeficiente de Spearman para capturar relaciones no lineales y mitigar el efecto de los valores atípicos (*outliers*):
1. `buy_price` vs `sq_mt_built` ➡️ **r = 0.8123** (Fuerza Crítica)
2. `buy_price` vs `n_bathrooms` ➡️ **r = 0.7811** (Fuerza Alta)
3. `buy_price` vs `n_rooms` ➡️ **r = 0.5924** (Fuerza Moderada)

* **El Descubrimiento:** El número de baños está significativamente más acoplado al valor de la vivienda que el propio número de habitaciones. El mercado en Madrid premia la ratio de confort sobre la cantidad de estancias.

### B. Precio vs. Superficie Construida (Continuo vs. Continuo)
Al analizar el gráfico de dispersión (*Scatter Plot*), se observa que la relación es ascendente pero pierde linealidad a partir de los 150 $m^2$. En formatos pequeños el precio se rige de forma matemática por metro cuadrado; en formatos grandes entran en juego factores intangibles de exclusividad y ubicación.

### C. Precio vs. Tipología de Vivienda (Continuo vs. Categórico)
La agrupación mediante `groupby` por `house_type_label` determinó la jerarquía económica del suelo en Madrid:
* **Chalets / Casas unifamiliares:** Techo del mercado (máxima prima por suelo independiente).
* **Pisos / Áticos:** Rango medio y motor de volumen transaccional.
* **Estudios:** Suelo comercial del dataset.

---

## 💡 4. Conclusiones y Recomendaciones Estratégicas

* **Para Inversores (Flipping / Reformas):** Al redistribuir una vivienda de tamaño medio (>90 $m^2$), añade más valor marginal en el mercado madrileño la construcción de un **segundo baño** que la adición de una habitación extra.
* **Para Desarrolladores de Modelos (AVM):** Evitar los modelos lineales simples basados en precios medios de la región. Las tasaciones deben segmentarse de forma mandatoria por medianas y rangos no lineales de tamaño.

---

## 🛠️ Requisitos e Instalación

Para replicar este análisis de forma local, asegúrate de clonar el repositorio e instalar las dependencias requeridas:

```bash
# Clonar el repositorio
git clone [https://github.com/tu-usuario/eda-inmuebles-madrid.git](https://github.com/tu-usuario/eda-inmuebles-madrid.git)

# Acceder al directorio
cd eda-inmuebles-madrid

# Instalar dependencias
pip install -r requirements.txt
