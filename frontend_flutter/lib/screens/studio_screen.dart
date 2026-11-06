import 'dart:async';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/audio_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/lyric_visualizer.dart';
import 'mixing_screen.dart';

class StudioScreen extends StatefulWidget {
  final Song song;

  const StudioScreen({super.key, required this.song});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _lyrics = [];
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = const Duration(minutes: 3, seconds: 30);
  StreamSubscription? _positionSubscription;
  bool _isPrepared = false;
  bool _isPlaying = false;
  String _selectedEffect = 'Estudio';
  int _score = 350;
  double _micVolume = 1.0;
  double _musicVolume = 0.8;

  static const List<dynamic> _fallbackLyrics = [
    {"text": "🎵", "start": 0.0, "end": 0.5},
    {"text": "¡Comienza", "start": 0.5, "end": 1.2},
    {"text": "a", "start": 1.2, "end": 1.5},
    {"text": "cantar!", "start": 1.5, "end": 2.2},
    {"text": "Sigue", "start": 2.8, "end": 3.2},
    {"text": "el", "start": 3.2, "end": 3.5},
    {"text": "ritmo", "start": 3.5, "end": 4.2},
    {"text": "de", "start": 4.2, "end": 4.5},
    {"text": "la", "start": 4.5, "end": 4.8},
    {"text": "música...", "start": 4.8, "end": 6.5},
    {"text": "¡Tu", "start": 7.0, "end": 7.4},
    {"text": "voz", "start": 7.4, "end": 7.8},
    {"text": "en", "start": 7.8, "end": 8.1},
    {"text": "Directo", "start": 8.1, "end": 9.0},
    {"text": "con", "start": 9.0, "end": 9.3},
    {"text": "DiviVoice! 🌟", "start": 9.3, "end": 11.5},
  ];

  @override
  void initState() {
    super.initState();
    _initStudio();
  }

  Future<void> _initStudio() async {
    final audioEngine = AudioEngine.instance;
    
    if (widget.song.lyricsUrl != null) {
      final lyricData = await ApiService.getLyricsJson(widget.song.lyricsUrl!);
      if (lyricData != null && lyricData.isNotEmpty) {
        _lyrics = lyricData;
      } else {
        _lyrics = _fallbackLyrics;
      }
    } else {
      _lyrics = _fallbackLyrics;
    }

    final url = (widget.song.instrumentalUrl != null && widget.song.instrumentalUrl!.isNotEmpty)
        ? (widget.song.instrumentalUrl!.startsWith('http') ? widget.song.instrumentalUrl! : '${ApiService.baseUrl}${widget.song.instrumentalUrl!}')
        : '${ApiService.baseUrl}/media/demo_song_latino_inst.mp3';

    try {
      await audioEngine.prepareSong(url);
    } catch (e) {
      try {
        await audioEngine.prepareSong('${ApiService.baseUrl}/media/demo_song_latino_inst.mp3');
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isPrepared = true;
        _totalDuration = audioEngine.musicPlayer.duration ?? const Duration(minutes: 3, seconds: 30);
      });
    }

    _positionSubscription = audioEngine.musicPlayer.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _score = (350 + (pos.inSeconds * 28)).clamp(350, 990);
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    final audioEngine = AudioEngine.instance;
    audioEngine.stopRecording();
    audioEngine.musicPlayer.stop();
    super.dispose();
  }

  void _togglePlayRecord() async {
    final audioEngine = AudioEngine.instance;
    if (_isPlaying) {
      await audioEngine.musicPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await audioEngine.musicPlayer.play();
      try {
        await audioEngine.startRecording();
      } catch (_) {}
      setState(() => _isPlaying = true);
    }
  }

  void _finishAndMix() async {
    final audioEngine = AudioEngine.instance;
    await audioEngine.musicPlayer.stop();
    await audioEngine.stopRecording();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MixingScreen(
          song: widget.song,
          voicePath: audioEngine.recordedVoicePath ?? '',
        ),
      ),
    );
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    String rank = 'A';
    if (_score > 550) rank = 'S';
    if (_score > 750) rank = 'SS';
    if (_score > 880) rank = 'SSS';

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
            child: Column(
              children: [
                // 1. Header Superior
                _buildTopAppBar(),

                // 2. Barra de Puntuación de Afinación (StarMaker Score)
                _buildScoreBanner(rank),

                // 3. Portada y Visualizador de Letras Teleprompter
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Portada con Aro Neón
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Color(0xFFFF1A4D), Color(0xFFFFB800)]),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFFF1A4D).withOpacity(0.4), blurRadius: 20),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundImage: NetworkImage(widget.song.coverImage),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Teleprompter de Letras Fluido
                      Container(
                        height: 120,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: LyricVisualizer(
                          lyrics: _lyrics,
                          currentPosition: _currentPosition,
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Barra de Progreso y Tiempo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: const Color(0xFFE51937),
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: _currentPosition.inSeconds.toDouble().clamp(0.0, _totalDuration.inSeconds.toDouble()),
                          max: _totalDuration.inSeconds.toDouble() > 0 ? _totalDuration.inSeconds.toDouble() : 210.0,
                          onChanged: (val) {
                            AudioEngine.instance.musicPlayer.seek(Duration(seconds: val.toInt()));
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatTime(_currentPosition), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(_formatTime(_totalDuration), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 5. Selector de Efectos DSP (Estudio, Pop, KTV, Concierto, Balada)
                Container(
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['Estudio', 'Pop', 'KTV', 'Concierto', 'Balada'].map((eff) {
                      final isSel = _selectedEffect == eff;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedEffect = eff),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFE51937) : Colors.white10,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSel ? const Color(0xFFE51937) : Colors.white12),
                            ),
                            child: Text(
                              eff,
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white70,
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Botonera Inferior de Grabación
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reiniciar
                      IconButton(
                        icon: const Icon(Icons.replay, color: Colors.white70, size: 24),
                        onPressed: () {
                          AudioEngine.instance.musicPlayer.seek(Duration.zero);
                        },
                      ),

                      // Botón Central Grabar / Pausa
                      GestureDetector(
                        onTap: _togglePlayRecord,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFFFF1A4D), Color(0xFFE51937)]),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFE51937).withOpacity(0.5), blurRadius: 18, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.mic,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),

                      // Terminar y Mezclar
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB800),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: _finishAndMix,
                        child: const Text('Terminar ✨', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.song.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.song.artist,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Color(0xFFFFD700), size: 20),
            onPressed: () {
              showModalBottomSheet(
                backgroundColor: const Color(0xFF1E1035),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setVolState) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Ajustes de Sonido & Micrófono 🎧', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.mic, color: Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                const Text('Voz:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Expanded(
                                  child: Slider(
                                    value: _micVolume,
                                    activeColor: const Color(0xFFE51937),
                                    onChanged: (v) => setVolState(() => _micVolume = v),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.music_note, color: Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                const Text('Pista:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Expanded(
                                  child: Slider(
                                    value: _musicVolume,
                                    activeColor: const Color(0xFFFFB800),
                                    onChanged: (v) {
                                      setVolState(() => _musicVolume = v);
                                      AudioEngine.instance.musicPlayer.setVolume(v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBanner(String rank) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF9800)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(rank, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PUNTUACIÓN EN VIVO', style: TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.bold)),
                  Text('$_score pts', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ],
          ),
          const Row(
            children: [
              Icon(Icons.graphic_eq, color: Color(0xFFE51937), size: 18),
              SizedBox(width: 4),
              Text('Afinación HD', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
