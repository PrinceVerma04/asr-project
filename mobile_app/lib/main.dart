import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

void main() {
  runApp(const AsrMobileApp());
}

class AsrMobileApp extends StatefulWidget {
  const AsrMobileApp({super.key});

  @override
  State<AsrMobileApp> createState() => _AsrMobileAppState();
}

class _AsrMobileAppState extends State<AsrMobileApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = switch (_themeMode) {
        ThemeMode.system => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.light,
        ThemeMode.light => ThemeMode.system,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASR Mobile',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: TranscriptionScreen(
        onToggleTheme: _toggleTheme,
        themeMode: _themeMode,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final seed = brightness == Brightness.dark
        ? const Color(0xFFFF8A5B)
        : const Color(0xFFB45309);
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          brightness == Brightness.dark ? const Color(0xFF0F1115) : const Color(0xFFF8F2EA),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        color: brightness == Brightness.dark
            ? const Color(0xFF171A20).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.82),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? const Color(0xFF1F2430)
            : Colors.white.withValues(alpha: 0.86),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
  });

  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  final TextEditingController _serverController =
      TextEditingController(text: 'http://192.168.162.182:5000');
  final TextEditingController _languageController =
      TextEditingController(text: 'en');
  final AudioRecorder _audioRecorder = AudioRecorder();

  PlatformFile? _selectedFile;
  bool _isLoading = false;
  bool _isRecording = false;
  String? _transcript;
  String? _savedPath;
  String? _error;
  final List<TranscriptEntry> _history = [];

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'flac', 'ogg'],
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFile = result.files.single;
      _error = null;
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final recordedPath = await _audioRecorder.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        if (recordedPath != null) {
          _selectedFile = PlatformFile(
            name: p.basename(recordedPath),
            path: recordedPath,
            size: 0,
          );
        }
      });
      return;
    }

    if (!await _audioRecorder.hasPermission()) {
      setState(() {
        _error = 'Microphone permission was not granted.';
      });
      return;
    }

    final directory = await getTemporaryDirectory();
    final filePath = p.join(
      directory.path,
      'live_recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: filePath,
    );

    setState(() {
      _isRecording = true;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedFile == null) {
      setState(() {
        _error = 'Please choose or record an audio file first.';
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
      final request = http.MultipartRequest('POST', uri)..fields['lang'] = _languageController.text.trim();
      final audioFile = await _buildMultipartFile(_selectedFile!);
      request.files.add(audioFile);

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 400) {
        throw Exception(body['error'] ?? 'Transcription failed.');
      }

      final transcript = body['text'] as String? ?? '';
      final savedPath = body['saved_to'] as String?;

      setState(() {
        _transcript = transcript;
        _savedPath = savedPath;
        _history.insert(
          0,
          TranscriptEntry(
            title: _selectedFile!.name,
            transcript: transcript,
            language: _languageController.text.trim(),
            savedPath: savedPath,
            createdAt: DateTime.now(),
          ),
        );
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
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<http.MultipartFile> _buildMultipartFile(PlatformFile file) async {
    if (file.path != null && !kIsWeb) {
      return http.MultipartFile.fromPath(
        'audio',
        file.path!,
        filename: file.name,
      );
    }

    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Unable to read the selected file bytes on this platform.');
    }

    return http.MultipartFile.fromBytes(
      'audio',
      Uint8List.fromList(bytes),
      filename: file.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF0A0D14),
                    Color(0xFF141A26),
                    Color(0xFF23160F),
                  ]
                : const [
                    Color(0xFFFFF6EC),
                    Color(0xFFFCE7D7),
                    Color(0xFFF7D6C2),
                  ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ASR Mobile',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Smooth upload, record, transcribe, and review flow for your GPU backend.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: widget.onToggleTheme,
                            icon: Icon(_themeIcon(widget.themeMode)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _HeroPanel(
                        child: Column(
                          children: [
                            TextField(
                              controller: _serverController,
                              decoration: const InputDecoration(
                                labelText: 'Backend URL',
                                prefixIcon: Icon(Icons.router_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _languageController,
                              decoration: const InputDecoration(
                                labelText: 'Language code',
                                prefixIcon: Icon(Icons.language_outlined),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _isLoading ? null : _pickAudioFile,
                                    icon: const Icon(Icons.audio_file_outlined),
                                    label: const Text('Choose File'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: _isLoading ? null : _toggleRecording,
                                    icon: Icon(
                                      _isRecording ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
                                    ),
                                    label: Text(_isRecording ? 'Stop Recording' : 'Record Audio'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                              ),
                              child: Row(
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(
                                      _isRecording ? Icons.graphic_eq : Icons.music_note_rounded,
                                      key: ValueKey(_isRecording),
                                      color: _isRecording ? scheme.error : scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedFile == null
                                          ? (_isRecording
                                              ? 'Recording in progress...'
                                              : 'Choose a file or record new audio')
                                          : 'Selected: ${_selectedFile!.name}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: _isLoading
                                      ? Row(
                                          key: const ValueKey('loading'),
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2.5),
                                            ),
                                            SizedBox(width: 12),
                                            Text('Transcribing...'),
                                          ],
                                        )
                                      : const Text(
                                          'Upload and Transcribe',
                                          key: ValueKey('ready'),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: _buildResultSection(theme, scheme),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: _HeroPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history_rounded, color: scheme.primary),
                            const SizedBox(width: 10),
                            Text(
                              'Transcript History',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_history.isEmpty)
                          Text(
                            'Your latest transcripts will appear here.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Column(
                            children: _history
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _HistoryTile(entry: entry),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection(ThemeData theme, ColorScheme scheme) {
    if (_error != null) {
      return _HeroPanel(
        key: const ValueKey('error'),
        child: _StatusCard(
          title: 'Error',
          content: _error!,
          color: const Color(0xFFDC2626),
          icon: Icons.error_outline_rounded,
        ),
      );
    }

    if (_transcript != null) {
      return _HeroPanel(
        key: const ValueKey('transcript'),
        child: Column(
          children: [
            _StatusCard(
              title: 'Transcript',
              content: _transcript!,
              color: const Color(0xFF15803D),
              icon: Icons.subtitles_outlined,
            ),
            if (_savedPath != null) ...[
              const SizedBox(height: 12),
              _StatusCard(
                title: 'Saved On Server',
                content: _savedPath!,
                color: const Color(0xFF1D4ED8),
                icon: Icons.save_outlined,
              ),
            ],
          ],
        ),
      );
    }

    return _HeroPanel(
      key: const ValueKey('idle'),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pick a file or record audio to get started. The transcript will appear here with a smooth transition.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value.clamp(0, 1), child: child),
        );
      },
      child: Card(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: child,
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
    required this.icon,
  });

  final String title;
  final String content;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(content),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final TranscriptEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                entry.language.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.transcript,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text(
            '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}'
            '  •  ${entry.savedPath ?? 'Saved path unavailable'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class TranscriptEntry {
  TranscriptEntry({
    required this.title,
    required this.transcript,
    required this.language,
    required this.savedPath,
    required this.createdAt,
  });

  final String title;
  final String transcript;
  final String language;
  final String? savedPath;
  final DateTime createdAt;
}

IconData _themeIcon(ThemeMode themeMode) {
  return switch (themeMode) {
    ThemeMode.system => Icons.brightness_auto_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
    ThemeMode.light => Icons.light_mode_rounded,
  };
}
