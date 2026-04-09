import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AsrMobileApp());
}

class AsrMobileApp extends StatelessWidget {
  const AsrMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASR Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9A3412)),
        useMaterial3: true,
      ),
      home: const TranscriptionScreen(),
    );
  }
}

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  final TextEditingController _serverController =
      TextEditingController(text: 'http://192.168.162.182:5000');
  final TextEditingController _languageController =
      TextEditingController(text: 'en');

  PlatformFile? _selectedFile;
  bool _isLoading = false;
  String? _transcript;
  String? _savedPath;
  String? _error;

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'flac', 'ogg'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFile = result.files.single;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedFile == null || _selectedFile!.path == null) {
      setState(() {
        _error = 'Please choose an audio file first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _transcript = null;
      _savedPath = null;
    });

    try {
      final uri = Uri.parse('${_serverController.text.trim()}/transcribe');
      final request = http.MultipartRequest('POST', uri)
        ..fields['lang'] = _languageController.text.trim()
        ..files.add(
          await http.MultipartFile.fromPath(
            'audio',
            _selectedFile!.path!,
            filename: _selectedFile!.name,
          ),
        );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 400) {
        throw Exception(body['error'] ?? 'Transcription failed.');
      }

      setState(() {
        _transcript = body['text'] as String?;
        _savedPath = body['saved_to'] as String?;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ASR Mobile Client')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _serverController,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _languageController,
              decoration: const InputDecoration(
                labelText: 'Language code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading ? null : _pickAudioFile,
              child: const Text('Choose Audio File'),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFile == null
                  ? 'No file selected'
                  : 'Selected: ${_selectedFile!.name}',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: Text(_isLoading ? 'Transcribing...' : 'Upload and Transcribe'),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              _StatusCard(
                title: 'Error',
                content: _error!,
                color: const Color(0xFFB91C1C),
              ),
            if (_savedPath != null)
              _StatusCard(
                title: 'Saved On Server',
                content: _savedPath!,
                color: const Color(0xFF1D4ED8),
              ),
            if (_transcript != null)
              _StatusCard(
                title: 'Transcript',
                content: _transcript!,
                color: const Color(0xFF15803D),
              ),
            const SizedBox(height: 20),
            const Text(
              'Next upgrade ideas: microphone recording, transcript history, translation, and share/export.',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.content,
    required this.color,
  });

  final String title;
  final String content;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            SelectableText(content),
          ],
        ),
      ),
    );
  }
}
