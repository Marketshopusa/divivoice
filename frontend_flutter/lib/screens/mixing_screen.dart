import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/audio_engine.dart';
import 'home_screen.dart';

class MixingScreen extends StatefulWidget {
  final Song song;
  final String voicePath;

  const MixingScreen({super.key, required this.song, required this.voicePath});

  @override
  State<MixingScreen> createState() => _MixingScreenState();
}

class _MixingScreenState extends State<MixingScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  double _vocalVolume = 1.0;
  double _instrumentalVolume = 0.8;
  double _reverbValue = 0.2;
  
  bool _isPlayingPreview = false;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Cover de ${widget.song.title}';
    _descriptionController.text = 'Grabado en HD en DiviVoice 🎤✨';
  }

  @override
  void dispose() {
    final audioEngine = AudioEngine.instance;
    audioEngine.stopPreview();
    super.dispose();
  }

  void _togglePreview() async {
    final audioEngine = AudioEngine.instance;
    if (_isPlayingPreview) {
      await audioEngine.stopPreview();
      setState(() {
        _isPlayingPreview = false;
      });
    } else {
      setState(() {
        _isPlayingPreview = true;
      });
      await audioEngine.startPreview(
        vocalVolume: _vocalVolume,
        instrumentalVolume: _instrumentalVolume,
      );
    }
  }

  void _updatePreviewVolumes() {
    final audioEngine = AudioEngine.instance;
    if (_isPlayingPreview) {
      audioEngine.setPreviewVolumes(_vocalVolume, _instrumentalVolume);
    }
  }

  Future<void> _publishCover() async {
    setState(() {
      _isPublishing = true;
    });

    final cover = await ApiService.publishCover(
      title: _titleController.text,
      description: _descriptionController.text,
      duration: 180,
      jobId: widget.song.jobId,
      vocalsFilePath: widget.voicePath,
      vocalVolume: _vocalVolume,
      instrumentalVolume: _instrumentalVolume,
      reverb: _reverbValue,
    );

    setState(() {
      _isPublishing = false;
    });

    if (cover != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text('¡Tu cover ha sido publicado en Momentos exitosamente! 🎉')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cover guardado y publicado en la comunidad.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E1035), Color(0xFF0F0C20)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: _isPublishing
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFE51937)),
                        SizedBox(height: 16),
                        Text('Mezclando voz con pista por IA...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 6),
                        Text('Publicando en el feed de la comunidad...', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          const Text('Estudio de Mezcla HD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tarjeta de Información
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _titleController,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Título del Cover',
                                labelStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _descriptionController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Dedicatoria / Descripción',
                                labelStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Consola de Efectos
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Niveles de Audio & Efectos DSP', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 16),

                            // Volumen de Voz
                            Row(
                              children: [
                                const Icon(Icons.mic, color: Color(0xFFE51937), size: 20),
                                const SizedBox(width: 10),
                                const SizedBox(width: 90, child: Text('Volumen Voz', style: TextStyle(color: Colors.white70, fontSize: 12))),
                                Expanded(
                                  child: Slider(
                                    value: _vocalVolume,
                                    min: 0.0,
                                    max: 2.0,
                                    activeColor: const Color(0xFFE51937),
                                    onChanged: (val) {
                                      setState(() => _vocalVolume = val);
                                      _updatePreviewVolumes();
                                    },
                                  ),
                                ),
                                Text('${(_vocalVolume * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),

                            // Volumen de Pista
                            Row(
                              children: [
                                const Icon(Icons.music_note, color: Color(0xFFFFB800), size: 20),
                                const SizedBox(width: 10),
                                const SizedBox(width: 90, child: Text('Volumen Pista', style: TextStyle(color: Colors.white70, fontSize: 12))),
                                Expanded(
                                  child: Slider(
                                    value: _instrumentalVolume,
                                    min: 0.0,
                                    max: 2.0,
                                    activeColor: const Color(0xFFFFB800),
                                    onChanged: (val) {
                                      setState(() => _instrumentalVolume = val);
                                      _updatePreviewVolumes();
                                    },
                                  ),
                                ),
                                Text('${(_instrumentalVolume * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),

                            // Reverb
                            Row(
                              children: [
                                const Icon(Icons.graphic_eq, color: Colors.deepPurpleAccent, size: 20),
                                const SizedBox(width: 10),
                                const SizedBox(width: 90, child: Text('Reverberación', style: TextStyle(color: Colors.white70, fontSize: 12))),
                                Expanded(
                                  child: Slider(
                                    value: _reverbValue,
                                    min: 0.0,
                                    max: 1.0,
                                    activeColor: Colors.deepPurpleAccent,
                                    onChanged: (val) => setState(() => _reverbValue = val),
                                  ),
                                ),
                                Text('${(_reverbValue * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botón Escuchar Vista Previa
                      OutlinedButton.icon(
                        onPressed: _togglePreview,
                        icon: Icon(_isPlayingPreview ? Icons.pause : Icons.play_arrow, color: Colors.white),
                        label: Text(_isPlayingPreview ? 'Pausar Vista Previa' : 'Escuchar Vista Previa', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Botón Publicar Cover
                      ElevatedButton.icon(
                        onPressed: _publishCover,
                        icon: const Icon(Icons.send, color: Colors.white),
                        label: const Text('Publicar en Momentos 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE51937),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
