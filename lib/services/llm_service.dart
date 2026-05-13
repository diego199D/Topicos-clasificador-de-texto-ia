import 'package:llamadart/llamadart.dart';

class LLMService {
  static const String systemPrompt =
      r"""You are an expert JSON command classifier for a store management system.
Given a user message in Spanish, respond ONLY with a valid JSON LIST containing one or more objects.

Each JSON object must have an "intent" field with EXACTLY one of these values:
- crear_producto     -> when adding a new product to the catalog (name, price, stock)
- crear_cliente      -> when registering a new customer (name, email, phone)
- registrar_venta    -> when a CUSTOMER BUYS a product (sale, purchase by client)
- registrar_compra   -> when the STORE BUYS stock from a SUPPLIER (restock, mercaderia)
- listar_productos   -> when listing or showing products
- listar_clientes    -> when listing or showing clients
- eliminar_producto  -> when deleting a product by id
- registrar_proveedor -> when adding a new supplier

RULES:
1. If the user provides multiple instructions in one message, return an object for EACH instruction inside a single list [{}, {}].
2. If there is only one instruction, return it inside a list of size one [{}].
3. Include ONLY relevant fields. No explanations, no markdown.

Examples:
User: "Agrega un teclado de 80 bs y registra a Maria con tel 77712345"
JSON: [
  {"intent": "crear_producto", "nombre": "teclado", "precio": 80},
  {"intent": "crear_cliente", "nombre": "Maria", "telefono": "77712345"}
]

User: "Vendi 2 mouses al cliente 3"
JSON: [{"intent": "registrar_venta", "cliente_id": 3, "producto": "mouse", "cantidad": 2}]

Include only the fields relevant to the detected intent.""";

  static const String grammar =
      r"""root   ::= "[" ws object (ws "," ws object)* ws "]"
object ::= "{" ws "\"intent\"" ws ":" ws string (ws "," ws pair)* ws "}"
pair   ::= string ws ":" ws value
value  ::= string | number | "true" | "false" | "null"
string ::= "\"" ([^"\\] | "\\" .)* "\""
number ::= "-"? [0-9]+ ("." [0-9]+)?
ws     ::= ([ \t\n])*""";

  static const String _gemmaTemplate =
      '<start_of_turn>user\n$systemPrompt\n\n{{INPUT}}<end_of_turn>\n<start_of_turn>model\nJSON:';

  LlamaEngine? _engine;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> initModel(String path) async {
    final engine = LlamaEngine(LlamaBackend());
    await engine.loadModel(path);
    _engine = engine;
    _isLoaded = true;
  }

  Future<String> clasificar(String input) async {
    final engine = _engine;
    if (engine == null || !_isLoaded) {
      throw Exception('Modelo no cargado. Llama a initModel() primero.');
    }
    final prompt = _gemmaTemplate.replaceAll('{{INPUT}}', input);
    final params = GenerationParams(
      temp: 0.1,
      topP: 0.9,
      topK: 40,
      maxTokens: 512,
      penalty: 1.1,
      grammar: grammar,
    );
    final sb = StringBuffer();
    await for (final token in engine.generate(prompt, params: params)) {
      sb.write(token);
    }
    return sb.toString().trim();
  }

  Future<void> dispose() async {
    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      _isLoaded = false;
    }
  }
}
