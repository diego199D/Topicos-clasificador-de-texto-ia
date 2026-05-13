import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/llm_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clasificador Local LLM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ClasificadorScreen(),
    );
  }
}

class ClasificadorScreen extends StatefulWidget {
  const ClasificadorScreen({super.key});

  @override
  State<ClasificadorScreen> createState() => _ClasificadorScreenState();
}

class _ClasificadorScreenState extends State<ClasificadorScreen> {
  final LLMService _llmService = LLMService();
  final TextEditingController _modelPathController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();

  bool _isLoading = false;
  bool _modelLoaded = false;
  String? _resultJson;
  String? _errorMessage;

  Future<void> _requestPermissions() async {
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _pickModelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      _modelPathController.text = result.files.single.path!;
    }
  }

  Future<void> _loadModel() async {
    final path = _modelPathController.text.trim();
    if (path.isEmpty) {
      setState(
        () => _errorMessage = 'Selecciona o escribe la ruta del modelo .gguf',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _resultJson = null;
    });

    try {
      await _requestPermissions();
      await _llmService.initModel(path);
      setState(() => _modelLoaded = true);
    } catch (e) {
      setState(() => _errorMessage = 'Error al cargar modelo: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _procesar() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = 'Escribe un comando para procesar');
      return;
    }
    if (!_modelLoaded) {
      setState(() => _errorMessage = 'Carga un modelo primero');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _resultJson = null;
    });

    try {
      final raw = await _llmService.clasificar(input);
      try {
        final parsed = jsonDecode(raw);
        final pretty = const JsonEncoder.withIndent('  ').convert(parsed);
        setState(() => _resultJson = pretty);
      } catch (_) {
        setState(() => _resultJson = raw);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error durante la clasificación: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _llmService.dispose();
    _modelPathController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clasificador Local LLM'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Modelo .gguf', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _modelPathController,
                    decoration: const InputDecoration(
                      hintText: 'Ruta al archivo .gguf',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    readOnly: _modelLoaded,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _modelLoaded ? null : _pickModelFile,
                  tooltip: 'Seleccionar archivo .gguf',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: (_isLoading || _modelLoaded) ? null : _loadModel,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_modelLoaded ? 'Modelo cargado' : 'Cargar Modelo'),
            ),
            const SizedBox(height: 24),
            Text(
              'Comando de venta',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                hintText: 'Ej: Vendi 2 teclados y 1 mouse',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: (_isLoading || !_modelLoaded) ? null : _procesar,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology),
              label: const Text('Procesar Localmente'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            if (_resultJson != null) ...[
              const SizedBox(height: 16),
              Text(
                'Resultado JSON',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _resultJson!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
