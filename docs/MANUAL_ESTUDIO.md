# 🧠 Clasificador de Texto con IA Local en Flutter

## 📚 Índice

1. [🎯 Introducción](#-introducción)
2. [🧩 ¿Qué es Flutter?](#-qué-es-flutter)
3. [🦙 ¿Qué es llama.cpp / llamadart?](#-qué-es-llamacpp--llamadart)
4. [📦 ¿Qué es un modelo GGUF?](#-qué-es-un-modelo-gguf)
5. [🤖 Gemma 2 — El Cerebro](#-gemma-2--el-cerebro)
6. [📐 GBNF Grammar — El Molde del JSON](#-gbnf-grammar--el-molde-del-json)
7. [✍️ Prompt Engineering — El Arte de Preguntar](#️-prompt-engineering--el-arte-de-preguntar)
8. [🏗️ Arquitectura de la App](#️-arquitectura-de-la-app)
9. [🔍 Código Explicado Paso a Paso](#-código-explicado-paso-a-paso)
   - [9.1 Dependencias (`pubspec.yaml`)](#91-dependencias-pubspecyaml)
   - [9.2 Servicio LLM (`llm_service.dart`)](#92-servicio-llm-llm_servicedart)
   - [9.3 Interfaz de Usuario (`main.dart`)](#93-interfaz-de-usuario-maindart)
   - [9.4 Permisos Android](#94-permisos-android)
10. [⚙️ ¿Cómo se Ejecuta Todo?](#️-cómo-se-ejecuta-todo)
11. [🧪 Probar y Depurar](#-probar-y-depurar)
12. [📖 Glosario](#-glosario)

---

## 🎯 Introducción

Este proyecto nace de una necesidad real: **ejecutar un modelo de lenguaje (LLM) directamente en un celular, sin internet, para clasificar comandos de texto en JSON estructurado**.

Imaginá que sos dueño de una tienda y decís:

> *"Agrega un teclado de 80 bs y registra a Maria con tel 77712345"*

La app toma esa frase, la procesa **localmente** con un modelo Gemma 2, y devuelve:

```json
[
  {"intent": "crear_producto", "nombre": "teclado", "precio": 80},
  {"intent": "crear_cliente", "nombre": "Maria", "telefono": "77712345"}
]
```

Todo esto **sin enviar datos a ningún servidor**, **sin pagar APIs**, **sin internet**.

---

## 🧩 ¿Qué es Flutter?

![Flutter logo](https://storage.googleapis.com/cms-storage-bucket/6e8b6e0f3f73b1cded4c.png)

**Flutter** es un framework de código abierto creado por Google para construir aplicaciones nativas desde un **solo código base** (Android, iOS, Web, Windows, macOS, Linux).

### 🎯 Conceptos Clave

| Concepto | Explicación |
|---|---|
| **Widget** | Todo en Flutter es un widget. Un botón es un widget, un texto es un widget, un margen es un widget. Son como **bloques LEGO** que se anidan. |
| **StatefulWidget** | Un widget que puede cambiar con el tiempo. Ej: el contador que aumenta cuando tocás un botón. |
| **StatelessWidget** | Un widget que no cambia. Ej: un texto fijo. |
| **BuildContext** | El "mapa" que sabe dónde está cada widget en el árbol. |
| **`setState()`** | Le dice a Flutter: "algo cambió, reconstruí la interfaz". |

### 📱 ¿Por qué usamos Flutter acá?

Porque necesitamos una app que corra en **Android** (el celular del usuario) pero con potencial de migrar a iOS sin reescribir nada. Además, Flutter tiene un excelente ecosistema de paquetes para IA local como `llamadart`.

---

## 🦙 ¿Qué es llama.cpp / llamadart?

![llama.cpp](https://avatars.githubusercontent.com/u/126734132)

**llama.cpp** es una biblioteca en C++ que permite ejecutar modelos de lenguaje (LLMs) en **hardware modesto**: laptops, celulares, Raspberry Pi. Su creador, **Georgi Gerganov**, logró optimizar la inferencia de modelos como LLaMA para que funcionen incluso en una CPU.

### 📉 La Magia de la Cuantización

Los modelos de lenguaje originales pesan **mucho** (Gemma 2 original ~5GB en FP16). La **cuantización** reduce el peso del modelo convirtiendo números de 16 bits a 4 u 8 bits, sacrificando un poquito de precisión pero ganando **enormemente en velocidad y memoria**.

| Tipo | Bits por peso | Tamaño Gemma 2 2B | Calidad |
|---|---|---|---|
| FP16 | 16 | ~4.5 GB | Original |
| Q8_0 | 8 | ~2.3 GB | Casi idéntico |
| **Q4_K_M** | **4** | **~1.5 GB** | **Recomendado** |
| Q2_K | 2 | ~0.8 GB | Pérdida notable |

### 📦 llamadart — El Puente Dart ↔ C++

**llamadart** es un paquete Dart/Flutter que envuelve llama.cpp y nos permite:

- Cargar modelos `.gguf` desde el almacenamiento del celular
- Generar texto con control fino (temperatura, top-p, etc.)
- Aplicar **gramáticas GBNF** para forzar la salida a un formato específico
- Usar GPU (Metal en iOS, Vulkan en Android) si está disponible

```dart
// Así de simple se usa llamadart
final engine = LlamaEngine(LlamaBackend());
await engine.loadModel('/ruta/al/modelo.gguf');

await for (final token in engine.generate('Hola mundo')) {
  print(token);  // 🪄 Texto generado token por token
}
```

---

## 📦 ¿Qué es un modelo GGUF?

**GGUF** (GPT-Generated Unified Format) es un formato de archivo para almacenar modelos de lenguaje. Fue creado por el equipo de llama.cpp para reemplazar al anterior formato GGML.

### 📁 Anatomía de un archivo .gguf

```
┌─────────────────────────────┐
│        HEADER (magic)       │  ← "GGUF" en ASCII
├─────────────────────────────┤
│      Metadata (KV pairs)    │  ← nombre, arquitectura, parámetros, etc.
├─────────────────────────────┤
│         Tokenizer           │  ← vocabulario (tokens)
├─────────────────────────────┤
│         Tensors             │  ← los pesos de la red neuronal
│  ┌───┐ ┌───┐ ┌───┐         │
│  │w₁₁│ │w₁₂│ │w₁₃│ ...     │
│  └───┘ └───┘ └───┘         │
│  ┌───┐ ┌───┐               │
│  │w₂₁│ │w₂₂│ ...           │
│  └───┘ └───┘               │
└─────────────────────────────┘
```

### 🎯 ¿Por qué GGUF?

| Formato | Ventaja |
|---|---|
| **GGUF** | Contiene todo (pesos + tokenizer + metadata) en UN solo archivo. Fácil de distribuir. |
| PyTorch (.pt) | Necesita Python y GPU para correr. |
| ONNX | Pesado, depende de runtime específico. |
| GGML (obsoleto) | Predecesor de GGUF, menos metadata. |

**Para el usuario:** solo necesita descargar un archivo `.gguf` y seleccionarlo desde la app. Nada más.

---

## 🤖 Gemma 2 — El Cerebro

**Gemma 2** es una familia de modelos de lenguaje abiertos creada por **Google**. Viene en versiones de 2B (2 mil millones) y 9B (9 mil millones) de parámetros.

### 🔬 ¿Qué son los "parámetros"?

Imaginá una red neuronal como una **fábrica con muchas perillas**. Cada "perilla" (peso sináptico) se ajusta durante el entrenamiento para que la fábrica produzca el resultado correcto. **Gemma 2 2B tiene 2 mil millones de esas perillas**.

> Más parámetros ≠ siempre mejor. Un modelo más grande necesita más RAM y es más lento. Para clasificar comandos de texto, 2B parámetros es **más que suficiente**.

### ⚡ Formato de Prompt de Gemma 2

Gemma 2 espera un formato específico de conversación. Es como un **protocolo de mensajería**:

```text
<start_of_turn>user
¿Cuál es la capital de Francia?<end_of_turn>
<start_of_turn>model
París<end_of_turn>
```

En nuestra app, el prompt se construye así:

```
<start_of_turn>user
[system_prompt]

[comando_del_usuario]<end_of_turn>
<start_of_turn>model
JSON:
```

El `JSON:` al final le indica al modelo que debe **completar** con un JSON, no con texto libre.

---

## 📐 GBNF Grammar — El Molde del JSON

**GBNF** (Grammar-Based Negative-log-likelihood Formatting) es un lenguaje para definir **gramáticas libres de contexto** que el modelo debe respetar al generar texto.

> 🤔 *"El modelo puede decir lo que quiera... pero la gramática es la jaula que lo obliga a hablar en JSON."*

### 🧬 Nuestra Gramática

```gbnf
root   ::= "[" ws object (ws "," ws object)* ws "]"
object ::= "{" ws "\"intent\"" ws ":" ws string (ws "," ws pair)* ws "}"
pair   ::= string ws ":" ws value
value  ::= string | number | "true" | "false" | "null"
string ::= "\"" ([^"\\] | "\\" .)* "\""
number ::= "-"? [0-9]+ ("." [0-9]+)?
ws     ::= ([ \t\n])*
```

### 📖 Leé la gramática como un mapa conceptual

```
            ┌──────────────┐
            │    root      │ ← "[" object ("," object)* "]"
            └──────┬───────┘
                   │ contiene
                   ▼
            ┌──────────────┐
            │   object     │ ← {"intent": string, ...pares}
            └──────┬───────┘
                   │ tiene
          ┌────────┴────────┐
          ▼                 ▼
   ┌────────────┐   ┌──────────────┐
   │   "intent" │   │    pair      │ ← string: value
   └────────────┘   └──────┬───────┘
                           │ puede ser
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         ┌────────┐  ┌────────┐  ┌──────────┐
         │ string │  │ number │  │ "true"   │
         └────────┘  └────────┘  │ "false"  │
                                 │ "null"   │
                                 └──────────┘
```

### 🎭 Sin gramática vs Con gramática

**Sin gramática** (el modelo divaga):
```
Claro, aquí tienes el JSON: [
  "intent": "crear_producto",
  nombre: "teclado",
  precio: 80,
  // esto es un comentario
]
```

**Con gramática** (el modelo no puede salirse del molde):
```json
[
  {"intent": "crear_producto", "nombre": "teclado", "precio": 80}
]
```

La gramática **no permite comentarios**, **no permite comillas simples**, **no permite faltar el `"intent"`**. El modelo físicamente no puede generar algo que no cumpla la gramática.

---

## ✍️ Prompt Engineering — El Arte de Preguntar

El **prompt** es la instrucción que le damos al modelo. Un buen prompt es como darle **instrucciones claras a un empleado nuevo**: contexto, reglas, ejemplos.

### 🧩 Anatomía de Nuestro System Prompt

```
1. IDENTIDAD
   "You are an expert JSON command classifier..."

2. FORMATO DE SALIDA
   "respond ONLY with a valid JSON LIST..."

3. VOCABULARIO CONTROLADO (8 intents)
   - crear_producto
   - crear_cliente
   - registrar_venta
   - registrar_compra
   - listar_productos
   - listar_clientes
   - eliminar_producto
   - registrar_proveedor

4. REGLAS
   "If multiple instructions → multiple objects in list"
   "Include ONLY relevant fields"

5. EJEMPLOS (few-shot)
   User: "Agrega un teclado de 80 bs..."
   JSON: [{"intent": "crear_producto", ...}]
```

### 🧪 Por qué funciona

| Técnica | Efecto |
|---|---|
| **Few-shot** (dar ejemplos) | El modelo imita el patrón |
| **Vocabulario cerrado** | Reduce la ambigüedad |
| **Gramática GBNF** | Fuerza la estructura JSON |
| **Temperatura baja (0.1)** | Vuelve la salida determinista |

---

## 🏗️ Arquitectura de la App

```
┌────────────────────────────────────────────────┐
│               FLUTTER APP                       │
│                                                  │
│  ┌──────────────┐      ┌──────────────────┐     │
│  │  main.dart    │◄────►│  llm_service.dart│     │
│  │  (UI Layer)   │      │  (Service Layer) │     │
│  └──────┬───────┘      └────────┬─────────┘     │
│         │                       │                │
│         ▼                       ▼                │
│  ┌──────────────┐      ┌──────────────────┐     │
│  │  FilePicker   │      │  llamadart       │     │
│  │  Permission   │      │  (Dart ↔ C++ FFI)│     │
│  └──────────────┘      └────────┬─────────┘     │
│                                  │                │
└──────────────────────────────────┼────────────────┘
                                   │
                                   ▼
                     ┌──────────────────────────┐
                     │  llama.cpp (C++)          │
                     │  ┌────────────────────┐   │
                     │  │  Gemma 2 2B Q4_K_M │   │
                     │  │  (.gguf file)      │   │
                     │  └────────────────────┘   │
                     └──────────────────────────┘
                                   │
                                   ▼
                     ┌──────────────────────────┐
                     │  CPU / GPU (Vulkan/Metal) │
                     └──────────────────────────┘
```

### 🔄 Flujo de Datos

```
Usuario escribe
     │
     ▼
┌─────────────┐
│ main.dart   │ ← Captura el texto, muestra loading
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ LLMService  │ ← Construye prompt con template Gemma 2
│ .clasificar │ ← Aplica gramática GBNF
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ llamadart   │ ← Envía a llama.cpp (C++ nativo)
│ .generate() │ ← Inferencia en el CPU/GPU
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Gemma 2     │ ← Genera tokens JSON
│ 2B + Q4_K_M │ ← Respetando la gramática
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ main.dart   │ ← Muestra el JSON formateado
└─────────────┘
```

---

## 🔍 Código Explicado Paso a Paso

### 9.1 Dependencias (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  llamadart: ^0.6.12        # 🦙 Motor de IA (envuelve llama.cpp)
  path_provider: ^2.1.0     # 📁 Rutas de archivos del sistema
  permission_handler: ^11.3.0  # 🔐 Permisos Android (almacenamiento)
  file_picker: ^8.0.0       # 📂 Selector de archivos nativo
```

| Paquete | Rol | Alternativas |
|---|---|---|
| **llamadart** | Cargar modelo GGUF + generar texto | `flutter_llama` (roto), `llm_llamacpp` |
| **file_picker** | Que el usuario elija el `.gguf` desde su celular | `file_selector` |
| **permission_handler** | Pedir acceso a almacenamiento en Android 11+ | `android_intent_plus` |
| **path_provider** | Obtener rutas del sistema (Descargas, Documentos) | `getApplicationDocumentsDirectory()` es estándar |

#### ❓ ¿Por qué `llamadart` y no otro?

| Paquete | Problema |
|---|---|
| `flutter_llama` | No incluye el código fuente de llama.cpp → error de build |
| `llama_cpp` | Package Dart, no Flutter plugin. No tiene bindings Android listos |
| `llm_llamacpp` | Requiere compilar la lib nativa manualmente |
| **`llamadart`** ✅ | **Descarga los binarios automáticamente. Zero config.** |

### 9.2 Servicio LLM (`llm_service.dart`)

```dart
import 'package:llamadart/llamadart.dart';
```

Este es el **corazón de la app**. Tiene tres responsabilidades:

#### 🧠 System Prompt (La Personalidad del Modelo)

```dart
static const String systemPrompt = r"""You are an expert JSON command classifier...
```

> Usamos **raw string** (`r"""..."""`) para que Dart no interprete caracteres especiales como `\n` o `\"`. Todo se pasa literal al modelo.

#### 📐 GBNF Grammar (El Molde)

```dart
static const String grammar = r"""root   ::= "[" ws object (ws "," ws object)* ws "]"
object ::= "{" ws "\"intent\"" ws ":" ws string (ws "," ws pair)* ws "}"
...
```

> La gramática **se pasa directamente al motor nativo**. No es un simple filtro — es una **restricción en el muestreo de tokens**. El modelo no puede elegir un token que no cumpla la gramática.

#### 🚀 Método `initModel(String path)`

```dart
Future<void> initModel(String path) async {
  final engine = LlamaEngine(LlamaBackend());  // 🏭 Crea el motor
  await engine.loadModel(path);                // 📂 Carga el .gguf
  _engine = engine;
  _isLoaded = true;
}
```

**¿Qué pasa acá?**
1. `LlamaEngine` crea una instancia del motor de inferencia
2. `LlamaBackend()` detecta automáticamente si estamos en Android/iOS/Desktop
3. `loadModel(path)` mmapa el archivo `.gguf` en memoria (no carga todo de una, **memory-mapped**)
4. Si el archivo no existe o está corrupto, lanza una excepción

#### 🔮 Método `clasificar(String input)`

```dart
Future<String> clasificar(String input) async {
  final prompt = _gemmaTemplate.replaceAll('{{INPUT}}', input);
  // Resultado: "<start_of_turn>user\nYou are an expert...\n\nVendi 2 mouses...<end_of_turn>\n..."

  final params = GenerationParams(
    temp: 0.1,        // 🎯 Temperatura baja = determinista
    grammar: grammar, // ⛓️ GBNF grammar activada
    maxTokens: 512,
  );

  final sb = StringBuffer();
  await for (final token in engine.generate(prompt, params: params)) {
    sb.write(token);  // 📝 Acumulá tokens hasta terminar
  }
  return sb.toString().trim();
}
```

**¿Por qué `temp: 0.1`?**
- Temperatura controla la **creatividad** del modelo
- 0.0 = siempre elige la palabra más probable (determinista)
- 1.0 = más variado, puede elegir palabras menos probables
- Para clasificación JSON queremos **máxima precisión**, no creatividad → `0.1`

**¿Streaming vs bloqueante?**
Usamos `await for` porque `engine.generate()` devuelve un **Stream**. Los tokens llegan de a uno a medida que el modelo los genera. Es como ver a alguien escribir en tiempo real. Acumulamos todo en un `StringBuffer` y devolvemos el texto completo.

#### 🧹 Método `dispose()`

```dart
Future<void> dispose() async {
  if (_engine != null) {
    await _engine!.dispose();  // 🧹 Liberá memoria nativa
    _engine = null;
    _isLoaded = false;
  }
}
```

> **IMPORTANTE**: llamadart asigna memoria **nativa** (C++, no Dart). Si no llamamos a `dispose()`, esa memoria nunca se libera. Es como alquilar un hotel y no devolver la llave.

### 9.3 Interfaz de Usuario (`main.dart`)

#### 🎭 Widgets Clave

```dart
class _ClasificadorScreenState extends State<ClasificadorScreen> {
  final LLMService _llmService = LLMService();
```

**`StatefulWidget`**: Necesitamos estado porque:
- `_isLoading` cambia mientras el modelo procesa
- `_modelLoaded` cambia cuando se carga el modelo
- `_resultJson` se llena cuando termina la inferencia
- `_errorMessage` muestra errores

#### 📂 Selector de archivos

```dart
Future<void> _pickModelFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    allowMultiple: false,
  );
  if (result != null && result.files.single.path != null) {
    _modelPathController.text = result.files.single.path!;
  }
}
```

> `FilePicker` abre el explorador de archivos nativo de Android. El usuario navega hasta su carpeta `Descargas` y selecciona el `.gguf`.

#### 🚀 Carga del Modelo

```dart
Future<void> _loadModel() async {
  setState(() => _isLoading = true);
  try {
    await _requestPermissions();  // 🔐 Android 11+ necesita permisos
    await _llmService.initModel(path);
    setState(() => _modelLoaded = true);
  } catch (e) {
    setState(() => _errorMessage = 'Error: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}
```

> El `try/catch` es crucial — cargar un modelo `.gguf` puede fallar por archivo corrupto, falta de RAM, o ruta inválida.

#### 📊 Mostrar resultado

```dart
try {
  final parsed = jsonDecode(raw);  // ¿Es JSON válido?
  final pretty = JsonEncoder.withIndent('  ').convert(parsed);
  setState(() => _resultJson = pretty);  // JSON lindo
} catch (_) {
  setState(() => _resultJson = raw);  // Si no es JSON, mostramos texto crudo
}
```

> **Doble validación**: el modelo con gramática debería generar JSON siempre, pero si falla, mostramos el texto crudo igual para depurar.

### 9.4 Permisos Android

En `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

| Permiso | ¿Para qué? | ¿Cuándo se necesita? |
|---|---|---|
| `READ_EXTERNAL_STORAGE` | Leer archivos del almacenamiento | Android 10 (API 29) y anteriores |
| `MANAGE_EXTERNAL_STORAGE` | Acceso completo a todos los archivos | Android 11+ (API 30+), necesario para leer `Downloads` |

> En Android 11+, Google introdujo **Almacenamiento con ámbito** (scoped storage). Cada app solo ve sus propios archivos. Para acceder a la carpeta `Downloads` y leer el `.gguf`, necesitamos `MANAGE_EXTERNAL_STORAGE`.

---

## ⚙️ ¿Cómo se Ejecuta Todo?

### 🔄 Ciclo Completo de una Clasificación

```
1. Usuario escribe: "Vendi 2 mouses al cliente 3"
       │
2. UI llama a LLMService.clasificar("Vendi 2 mouses al cliente 3")
       │
3. LLMService construye el prompt:
   ┌──────────────────────────────────────────┐
   │<start_of_turn>user                       │
   │You are an expert JSON...                 │
   │                                          │
   │Vendi 2 mouses al cliente 3               │
   │<end_of_turn>                             │
   │<start_of_turn>model                      │
   │JSON:                                     │
   └──────────────────────────────────────────┘
       │
4. Se crea GenerationParams con:
   - temp: 0.1 (baja creatividad)
   - grammar: (nuestra GBNF)
   - maxTokens: 512
       │
5. engine.generate(prompt, params) →
   llama.cpp carga el modelo Gemma 2 2B
       │
6. El modelo genera tokens UNO POR UNO:
   "[" → gramática permite "[", no hay otra opción
   "{" → gramática permite "{"
   "\"intent\"" → gramática exige "intent" primero
   ":" → gramática permite ":"
   "crear_producto" → no, no es un intent válido
   "registrar_venta" → sí, intent válido
   ...
   "]" → gramática cierra el array
       │
7. El stream entrega los tokens a Dart
   StringBuffer acumula: [{"intent": "registrar_venta", ...}]
       │
8. LLMService devuelve el string a main.dart
       │
9. main.dart parsea con jsonDecode y display JSON lindo
       │
10. ¡Usuario ve el resultado! 🎉
```

---

## 🧪 Probar y Depurar

### 🐛 Errores Comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `ModelLoadException` | El `.gguf` no existe o está corrupto | Verificá la ruta, descargá el modelo de nuevo |
| `OutOfMemoryError` | El modelo no entra en RAM | Usá Gemma 2 2B Q4_K_M (~1.5GB), no Q8_0 |
| Garbage en la salida | Prompt incorrecto o temperatura muy alta | Revisá el template, bajá `temp` |
| JSON inválido | La gramática no está funcionando | Verificá que `grammar:` esté en `GenerationParams` |
| Build falla con CMake | El paquete requiere compilar C++ | Usá `llamadart` que descarga binarios precompilados |

### 🔧 Comandos de Desarrollo

```bash
# Limpiar todo y reinstalar
flutter clean && flutter pub get

# Analizar código en busca de errores
flutter analyze

# Correr en el celular conectado
flutter run

# Ver logs específicos de Flutter
flutter logs
```

---

## 📖 Glosario

| Término | Traducción | Explicación |
|---|---|---|
| **LLM** | Large Language Model | Modelo de lenguaje grande. Red neuronal entrenada con terabytes de texto. |
| **GGUF** | GPT-Generated Unified Format | Formato de archivo para modelos optimizados con llama.cpp. |
| **Q4_K_M** | 4-bit K-quant, Medium | Tipo de cuantización: cada peso usa ~4 bits. K-quant es más inteligente que Q4_0 porque asigna más bits a capas importantes. |
| **GBNF** | Grammar-Based Formatting | Lenguaje para definir gramáticas que el modelo debe respetar al generar texto. |
| **Token** | — | Unidad básica de texto para el modelo. No son palabras completas. "Hola" = 1 token, "murciélago" = 3 tokens. |
| **Temperatura** | Temperature | Controla cuán "creativo" es el modelo. 0 = siempre lo mismo, 1 = variado, 2 = caótico. |
| **Top-P** | Nucleus Sampling | Solo considera los tokens cuya probabilidad acumulada suma P. Si P=0.9, ignora el 10% menos probable. |
| **Top-K** | — | Solo considera los K tokens más probables. Si K=40, el modelo solo elige entre los 40 mejores candidatos. |
| **FFI** | Foreign Function Interface | Mecanismo para que Dart llame código escrito en C/C++. `llamadart` usa FFI para hablar con llama.cpp. |
| **Memory-mapped** | Archivo mapeado en memoria | El archivo `.gguf` no se carga entero en RAM. Se "mapea" y el sistema operativo carga solo las partes que se necesitan. |
| **Few-shot** | Pocos ejemplos | Técnica de prompt engineering: darle al modelo ejemplos de lo que queremos antes de pedirle que lo haga. |

---

## 🏁 Conclusión

Esta app demuestra que **la IA generativa no necesita internet ni servidores costosos**. Con herramientas modernas:

- **Flutter** para la interfaz multiplataforma
- **llamadart/llama.cpp** para inferencia local eficiente
- **Modelos cuantizados GGUF** que caben en un celular
- **Gramáticas GBNF** para controlar exactamente la salida
- **Prompt engineering** para guiar al modelo sin reentrenarlo

...podemos construir asistentes inteligentes **offline, privados y gratuitos** que entiendan lenguaje natural y lo conviertan en datos estructurados.

> 🧠 *"El mejor modelo no es el más grande, sino el que mejor entiende tu problema."*

---

> *Documento generado para estudio personal. Proyecto: topicosllm — Clasificador de texto con IA local en Flutter.*
