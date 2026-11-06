import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../models/user.dart';
import '../models/song.dart';
import '../models/cover.dart';
import '../models/room.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/download_helper.dart';
import '../widgets/starmaker_ui.dart';
import '../widgets/starmaker_modals.dart';
import 'studio_screen.dart';
import 'room_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // 0: Salas, 1: Momentos, 2: Cantar, 3: Mensajes, 4: Yo
  String _selectedFiestaSubTab = 'Fiesta';
  String _selectedGenreFilter = '🔥 Todo';
  String _selectedCantarSubTab = 'Recomendaciones';
  String _searchQuery = '';

  List<Room> _rooms = [];
  List<Song> _songs = [];
  List<Song> _onlineSearchResults = [];
  List<Cover> _covers = [];
  User? _currentUser;
  bool _isLoading = true;
  bool _isSearchingOnline = false;
  Timer? _searchDebounce;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _youtubeUrlController = TextEditingController();

  // Reproductor de Audio para el Feed de Momentos
  final AudioPlayer _feedPlayer = AudioPlayer();
  int? _playingCoverIndex;
  bool _isPlayingCover = false;
  Duration _feedPosition = Duration.zero;
  Duration _feedDuration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _initAudioListeners();
    _loadAllData();
  }

  void _initAudioListeners() {
    _posSub = _feedPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _feedPosition = pos);
    });
    _stateSub = _feedPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlayingCover = state.playing);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _searchDebounce?.cancel();
    _feedPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    _currentUser = await ApiService.getCurrentUser();
    if (_currentUser == null) {
      _currentUser = User(
        id: 1,
        username: 'El_Cantante',
        email: 'cantante@divivoice.com',
        avatarUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300&auto=format&fit=crop&q=80',
        bio: 'Cantante Oficial DiviVoice 🎤 Lv. 28 VIP💎',
        level: 28,
        diamonds: 150,
      );
    }

    final roomsFuture = ApiService.getRooms();
    final songsFuture = ApiService.getSongs();
    final coversFuture = ApiService.getCovers();

    final results = await Future.wait([roomsFuture, songsFuture, coversFuture]);

    setState(() {
      _rooms = results[0] as List<Room>;
      _songs = results[1] as List<Song>;
      _covers = results[2] as List<Cover>;
      _isLoading = false;
    });
  }

  void _addDiamonds(int amount) {
    if (_currentUser != null) {
      setState(() {
        _currentUser = User(
          id: _currentUser!.id,
          username: _currentUser!.username,
          email: _currentUser!.email,
          avatarUrl: _currentUser!.avatarUrl,
          bio: _currentUser!.bio,
          level: _currentUser!.level,
          diamonds: _currentUser!.diamonds + amount,
          followersCount: _currentUser!.followersCount,
          followingCount: _currentUser!.followingCount,
          rank: _currentUser!.rank,
        );
      });
    }
  }

  // --- BÚSQUEDA AUTOMÁTICA EN TIEMPO REAL (CATÁLOGO + YOUTUBE) ---
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _onlineSearchResults = [];
        _isSearchingOnline = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearchingOnline = true);
      try {
        final res = await http.get(Uri.parse('${ApiService.baseUrl}/api/social/search_youtube?q=${Uri.encodeComponent(query)}'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final List results = data['results'] ?? [];
          setState(() {
            _onlineSearchResults = results.map<Song>((item) {
              return Song(
                jobId: item['id']?.toString() ?? 'yt_${UniqueKey().toString()}',
                title: item['title'] ?? 'Canción',
                artist: item['artist'] ?? query,
                coverImage: item['thumbnail'] ?? 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
                difficulty: 'Oficial',
                playsCount: '${(100 + (item['title']?.toString().length ?? 10) * 37)}K',
                instrumentalUrl: '/media/demo_song_latino_inst.mp3',
                lyricsUrl: '/media/demo_song_latino_lyrics.json',
              );
            }).toList();
            _isSearchingOnline = false;
          });
        }
      } catch (e) {
        setState(() => _isSearchingOnline = false);
      }
    });
  }

  // --- REPRODUCCIÓN DE AUDIO EN EL FEED DE MOMENTOS ---
  void _togglePlayCover(int index, String? audioUrl) async {
    try {
      if (_playingCoverIndex == index && _isPlayingCover) {
        await _feedPlayer.pause();
      } else {
        _playingCoverIndex = index;
        final url = (audioUrl != null && audioUrl.isNotEmpty)
            ? (audioUrl.startsWith('http') ? audioUrl : '${ApiService.baseUrl}$audioUrl')
            : '${ApiService.baseUrl}/media/demo_song_latino_inst.mp3';

        await _feedPlayer.setUrl(url);
        _feedDuration = _feedPlayer.duration ?? const Duration(minutes: 3, seconds: 18);
        await _feedPlayer.play();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reproduciendo audio HD en vivo')),
      );
    }
  }

  // --- MODAL DE CREACIÓN CON IA CON 3 DESCARGAS (VOZ, INSTRUMENTAL Y MIDI) ---
  void _handleOpenAiSeparationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFE51937), size: 24),
                  SizedBox(width: 8),
                  Text('Estudio de Creación IA DiviVoice', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Convierte canciones en Karaoke, extrae la Voz, el Instrumental y descarga el archivo MIDI (.mid) con la melodía.', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: _youtubeUrlController,
                decoration: InputDecoration(
                  hintText: 'https://www.youtube.com/watch?v=...',
                  hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.link, color: Color(0xFFE51937)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_fix_high, color: Colors.white, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE51937),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final url = _youtubeUrlController.text.trim();
                    if (url.isNotEmpty) {
                      Navigator.pop(context);
                      _startSeparationWithProgress(url);
                    }
                  },
                  label: const Text('Separar Voz, Instrumental y Crear MIDI 🪄', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.0),
                    child: Text('O sube tu archivo directo', style: TextStyle(color: Colors.black45, fontSize: 11)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file, color: Color(0xFF0288D1), size: 20),
                label: const Text('Subir Archivo de Audio (MP3 / WAV / M4A)', style: TextStyle(color: Color(0xFF0288D1), fontWeight: FontWeight.bold, fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  side: const BorderSide(color: Color(0xFF0288D1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final picked = await pickAudioFileWeb();
                  if (picked != null) {
                    Navigator.pop(context);
                    _startSeparationWithFile(picked.bytes, picked.name);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSeparationProgressDialog({
    required Function(void Function()) onDialogInit,
    required VoidCallback onDismiss,
  }) {
    // Helper para diálogo común
  }

  void _startSeparationWithFile(Uint8List bytes, String filename) async {
    int progress = 15;
    String statusMessage = '📤 Subiendo audio al servidor...';
    Song? completedSong;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(20),
              content: _buildSeparationDialogContent(
                progress: progress,
                statusMessage: statusMessage,
                completedSong: completedSong,
                onSingNow: () {
                  Navigator.pop(dialogContext);
                  if (completedSong != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => StudioScreen(song: completedSong!)));
                  }
                },
              ),
            );
          },
        );
      },
    );

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/separate');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      request.fields['create_video'] = 'false';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final jobId = data['job_id'];
        final songTitle = filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        await _pollSeparationStatus(jobId, songTitle, (p, msg, song) {
          progress = p;
          statusMessage = msg;
          completedSong = song;
        });
      }
    } catch (e) {
      statusMessage = 'Error al subir y procesar el archivo.';
    }
  }

  void _startSeparationWithProgress(String url) async {
    int progress = 15;
    String statusMessage = '📥 Descargando audio de YouTube...';
    Song? completedSong;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(20),
              content: _buildSeparationDialogContent(
                progress: progress,
                statusMessage: statusMessage,
                completedSong: completedSong,
                onSingNow: () {
                  Navigator.pop(dialogContext);
                  if (completedSong != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => StudioScreen(song: completedSong!)));
                  }
                },
              ),
            );
          },
        );
      },
    );

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/separate'),
        body: {'youtube_url': url, 'create_video': 'false'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final jobId = data['job_id'];
        final songTitle = data['original_filename']?.replaceAll('.mp3', '') ?? 'Canción de YouTube';
        await _pollSeparationStatus(jobId, songTitle, (p, msg, song) {
          progress = p;
          statusMessage = msg;
          completedSong = song;
        });
      }
    } catch (e) {
      statusMessage = 'Error de conexión con el motor de IA.';
    }
  }

  Future<void> _pollSeparationStatus(
    String jobId,
    String songTitle,
    Function(int progress, String statusMessage, Song? song) onUpdate,
  ) async {
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      try {
        final statusRes = await http.get(Uri.parse('${ApiService.baseUrl}/api/status/$jobId'));
        if (statusRes.statusCode == 200) {
          final statusData = jsonDecode(statusRes.body);
          final p = statusData['progress'] ?? 0;
          final isDone = statusData['status'] == 'completed';

          String msg = 'Procesando...';
          if (p < 30) {
            msg = '📥 Descargando audio en alta definición...';
          } else if (p < 65) {
            msg = '🧠 Separando voz e instrumentos con IA...';
          } else if (p < 85) {
            msg = '🎹 Transcribiendo notas y melodía a formato MIDI (.mid)...';
          } else if (p < 100) {
            msg = '📝 Sincronizando letras de karaoke...';
          } else {
            msg = '🎉 ¡Separación y archivo MIDI listos!';
          }

          Song? song;
          if (isDone) {
            song = Song(
              jobId: jobId,
              title: songTitle,
              artist: 'IA Studio',
              instrumentalUrl: '/media/${jobId}_(Instrumental).mp3',
              lyricsUrl: '/media/${jobId}_lyrics.json',
            );
            _youtubeUrlController.clear();
            await _loadAllData();
          }

          onUpdate(p, msg, song);
          if (isDone) break;
        }
      } catch (_) {}
    }
  }

  Widget _buildSeparationDialogContent({
    required int progress,
    required String statusMessage,
    required Song? completedSong,
    required VoidCallback onSingNow,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome, color: Color(0xFFE51937), size: 40),
        const SizedBox(height: 12),
        const Text('Creación de Pistas & MIDI con IA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 6),
        Text(statusMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: progress / 100.0,
          backgroundColor: const Color(0xFFF5F6FA),
          color: const Color(0xFFE51937),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 6),
        Text('$progress%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE51937), fontSize: 13)),

        // 3 DESCARGAS OFICIALES (VOZ, INSTRUMENTAL, MIDI)
        if (progress >= 100 && completedSong != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.download_for_offline, color: Color(0xFFE51937), size: 16),
                    SizedBox(width: 6),
                    Text('Descargas Disponibles (Audio, MIDI y LRC):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark)),
                  ],
                ),
                const SizedBox(height: 8),

                // 1. Descarga Voz
                _buildDownloadTile(
                  icon: Icons.record_voice_over,
                  title: '1. Voz Aislada (A capella)',
                  format: 'MP3 • Audio HD',
                  color: const Color(0xFFE51937),
                  onTap: () {
                    downloadFileFromUrl(
                      '${ApiService.baseUrl}/api/download/${completedSong.jobId}/vocals',
                      '${completedSong.title}_Voz.mp3',
                    );
                  },
                ),
                const SizedBox(height: 6),

                // 2. Descarga Instrumental
                _buildDownloadTile(
                  icon: Icons.music_note,
                  title: '2. Pista Instrumental',
                  format: 'MP3 • Karaoke HD',
                  color: const Color(0xFF0288D1),
                  onTap: () {
                    downloadFileFromUrl(
                      '${ApiService.baseUrl}/api/download/${completedSong.jobId}/instrumental',
                      '${completedSong.title}_Instrumental.mp3',
                    );
                  },
                ),
                const SizedBox(height: 6),

                // 3. Descarga MIDI
                _buildDownloadTile(
                  icon: Icons.piano,
                  title: '3. Archivo MIDI (.mid)',
                  format: 'MID • Partitura / DAW',
                  color: const Color(0xFF6B46C1),
                  onTap: () {
                    downloadFileFromUrl(
                      '${ApiService.baseUrl}/api/download/${completedSong.jobId}/midi',
                      '${completedSong.title}_Melodia.mid',
                    );
                  },
                ),
                const SizedBox(height: 6),

                // 4. Descarga LRC
                _buildDownloadTile(
                  icon: Icons.description,
                  title: '4. Letras Sincronizadas (.lrc)',
                  format: 'LRC • Reproductores / Spotify',
                  color: const Color(0xFF00897B),
                  onTap: () {
                    downloadFileFromUrl(
                      '${ApiService.baseUrl}/api/download/${completedSong.jobId}/lrc',
                      '${completedSong.title}_Letras.lrc',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.mic, color: Colors.white, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE51937),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onSingNow,
              label: const Text('¡CANTAR AHORA 🎤!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDownloadTile({
    required IconData icon,
    required String title,
    required String format,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: color)),
                  Text(format, style: const TextStyle(fontSize: 9.5, color: AppTheme.textGrey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download, color: Colors.white, size: 12),
                  SizedBox(width: 2),
                  Text('Bajar', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreateRoom() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.mic, color: Color(0xFFE51937)),
              SizedBox(width: 8),
              Text('Crear Mi Sala de Fiesta', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            ],
          ),
          content: TextField(
            controller: titleController,
            decoration: InputDecoration(
              hintText: 'Nombre de la sala (Ej. Noche de Baladas)',
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE51937), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final name = titleController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  _enterRoomByIndex(0, defaultName: name);
                }
              },
              child: const Text('Lanzar Sala 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _enterRoomByIndex(int index, {String? defaultName}) {
    final user = _currentUser ?? User(
      id: 1,
      username: 'El_Cantante',
      email: 'cantante@divivoice.com',
      avatarUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300',
      bio: 'Cantante Oficial DiviVoice 🎤 Lv. 28 VIP💎',
      level: 28,
      diamonds: 150,
    );

    final room = (_rooms.isNotEmpty && index < _rooms.length)
        ? _rooms[index]
        : Room(
            id: index + 1,
            name: defaultName ?? 'Sala de Show en Vivo #${index + 1}',
            host: user,
            isActive: true,
            seats: List.generate(8, (i) => RoomSeat(seatIndex: i, user: null, isMuted: false)),
            queue: [],
          );

    Navigator.push(context, MaterialPageRoute(builder: (_) => RoomScreen(room: room, currentUser: user))).then((_) => _loadAllData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECF5),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE51937)))
                      : _buildCurrentTabContent(),
                ),
                _buildBottomNavBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentIndex) {
      case 0:
        return _buildSalasTab();
      case 1:
        return _buildMomentosTab();
      case 2:
        return _buildCantarTab();
      case 3:
        return _buildMensajesTab();
      case 4:
        return _currentUser != null ? ProfileScreen(user: _currentUser!) : const Center(child: Text('Cargando perfil...'));
      default:
        return _buildSalasTab();
    }
  }

  // ==========================================
  // PESTAÑA 1: SALAS / FIESTA (100% FUNCIONAL)
  // ==========================================
  Widget _buildSalasTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 1. Header Superior
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _buildTopFiestaTab('Fiesta', isSelected: _selectedFiestaSubTab == 'Fiesta'),
              const SizedBox(width: 18),
              _buildTopFiestaTab('En vivo', isSelected: _selectedFiestaSubTab == 'En vivo'),
              const SizedBox(width: 18),
              _buildTopFiestaTab('Copa Mundial', isSelected: _selectedFiestaSubTab == 'Copa Mundial'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search, color: AppTheme.textDark, size: 22),
                onPressed: () => setState(() => _currentIndex = 2),
              ),
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => DailyTasksModal(onDiamondsAdded: _addDiamonds),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFFE0B2), borderRadius: BorderRadius.circular(10)),
                  child: const Text('AD 💰', style: TextStyle(color: Color(0xFFE65100), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFFE51937), size: 22),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => DailyTasksModal(onDiamondsAdded: _addDiamonds),
                ),
              ),
            ],
          ),
        ),

        // 2. Ticker Marquee Rojo
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            builder: (_) => DailyTasksModal(onDiamondsAdded: _addDiamonds),
          ),
          child: const StarMakerTickerBar(),
        ),
        const SizedBox(height: 8),

        // 3. Fila de Historias / Salas en Vivo
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: StarMakerStoriesRow(onMyRoomTap: _handleCreateRoom),
        ),
        const SizedBox(height: 8),

        // 4. Trío de Tarjetas Pastel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => FamilyModal(user: _currentUser!)),
                  child: _buildPastelTile('Familia', '👤 33.0k', AppTheme.pastelPeach, const Color(0xFFE65100), Icons.groups),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 12,
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = 2),
                  child: _buildPastelTile('ıll Cantar', '96.9k Canto en', AppTheme.pastelPink, const Color(0xFFE51937), Icons.graphic_eq, badge: 'Visitas de amigos'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = 3),
                  child: _buildPastelTile('Chat', '👤 41.4k', AppTheme.pastelPeach, const Color(0xFFE65100), Icons.chat_bubble),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 5. Filtros Secundarios
        Container(
          color: Colors.white,
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              '🔥 Todo',
              '🎤 Karaoke',
              '💬 Chat',
              '🏆 Torneo',
              '🎸 Rock',
              '💃 Latino',
              '🎶 Baladas',
            ].map((f) => _buildGenreFilter(f, isSelected: _selectedGenreFilter == f)).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // 6. Cuadrícula de Salas con Posters (Tapping ALWAYS ENTERS THE ROOM)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [
              StarMakerPartyRoomCard(
                title: '⭐ STARZ OF THE SHOW ⭐',
                tag: '🎤 Cantar juntos',
                hostName: 'Bark At The Moon',
                posterUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400',
                listeners: 5,
                level: 8,
                onTap: () => _enterRoomByIndex(0, defaultName: 'STARZ OF THE SHOW'),
              ),
              StarMakerPartyRoomCard(
                title: 'SHINE LIKE A STAR 4.0 ✨',
                tag: '🔴 En vivo',
                hostName: 'RyanMC (Official US Creator)',
                posterUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400',
                listeners: 100,
                level: 100,
                onTap: () => _enterRoomByIndex(1, defaultName: 'SHINE LIKE A STAR 4.0'),
              ),
              StarMakerPartyRoomCard(
                title: '° 𝓥𝓸𝓲𝓬𝓮𝓼 💜 Hacer amigos',
                tag: 'Chat',
                hostName: 'Luna_Melody',
                posterUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400',
                listeners: 12,
                level: 5,
                onTap: () => _enterRoomByIndex(2, defaultName: 'Voices Violet Gala'),
              ),
              StarMakerPartyRoomCard(
                title: '🎲 Lucky Dice Mega Sala 165',
                tag: 'Mega Sala',
                hostName: 'Supernova X30 Host',
                posterUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400',
                listeners: 45,
                level: 30,
                onTap: () => _enterRoomByIndex(3, defaultName: 'Lucky Dice Vegas Show'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Banner Global Star Supernova
        GestureDetector(
          onTap: () => showModalBottomSheet(context: context, builder: (_) => const VocalRangeModal()),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [Color(0xFF2E0854), Color(0xFFE51937)]),
            ),
            alignment: Alignment.center,
            child: const Text('👑 GRAN TORNEO VOCAL SUPERNOVA 2026 👑', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ==========================================
  // PESTAÑA 2: CANTAR (BÚSQUEDA AUTOMÁTICA EN VIVO)
  // ==========================================
  Widget _buildCantarTab() {
    // Si el usuario escribió en el buscador, combinamos catálogo local + resultados de búsqueda online
    List<Song> displayedSongs = [];
    if (_searchQuery.isNotEmpty) {
      final localMatches = _songs.where((s) {
        final q = _searchQuery.toLowerCase();
        return s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q);
      }).toList();

      displayedSongs = [...localMatches, ..._onlineSearchResults];
    } else {
      displayedSongs = _songs;
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 1. Buscador Dinámico Automático
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppTheme.textGrey, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: 'Buscar artista o canción (Ej. Ricardo Arjona, Shakira)...',
                            hintStyle: TextStyle(color: AppTheme.textGrey, fontSize: 11.5),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          child: const Icon(Icons.close, color: AppTheme.textGrey, size: 16),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.flag_outlined, color: Color(0xFFFF9800), size: 22),
                onPressed: () => showModalBottomSheet(context: context, builder: (_) => const VocalRangeModal()),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFFE51937), size: 22),
                onPressed: () => showModalBottomSheet(context: context, builder: (_) => DailyTasksModal(onDiamondsAdded: _addDiamonds)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 2. Pasteles de Acciones Rápidas
        SizedBox(
          height: 124,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              GestureDetector(
                onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => FamilyModal(user: _currentUser!)),
                child: _buildTilePill('Grupo\nSeleccion...', Icons.public, AppTheme.pastelLavender, const Color(0xFF6B46C1), 100),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = 'Popular'),
                    child: _buildSmallPill('💌 Mis Canciones', AppTheme.pastelPeach, const Color(0xFFE65100)),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => showModalBottomSheet(context: context, builder: (_) => const VocalRangeModal()),
                    child: _buildSmallPill('🎧 Prueba de Rango', AppTheme.pastelYellow, const Color(0xFFF57F17)),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = 'Dueto'),
                    child: _buildSmallPill('👥 Colaboración', AppTheme.pastelMint, const Color(0xFF2E7D32)),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _handleOpenAiSeparationModal,
                    child: _buildSmallPill('🎼 Creación IA ✨', AppTheme.pastelPink, const Color(0xFFE51937)),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = 'Pop'),
                    child: _buildSmallPill('🎵 Estilos', AppTheme.pastelLavender, const Color(0xFF6B46C1)),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      if (_songs.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => StudioScreen(song: _songs.first)));
                      }
                    },
                    child: _buildSmallPill('🎤 Canto Pro', AppTheme.pastelCyan, const Color(0xFF0288D1)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. Subpestañas de Género
        Container(
          color: Colors.white,
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              _buildCantarSubTab('Recomendaciones'),
              _buildCantarSubTab('Popular'),
              _buildCantarSubTab('Pro'),
              _buildCantarSubTab('Oficial'),
              _buildCantarSubTab('Billboard'),
            ],
          ),
        ),

        // Indicador de Búsqueda Online en progreso
        if (_isSearchingOnline)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(color: Color(0xFFE51937))),
          ),

        // 4. Lista de Canciones Interactivas (Locales + Online de la Búsqueda)
        ...displayedSongs.map((s) => StarMakerSongItem(
          title: s.title,
          artist: s.artist,
          coverUrl: s.coverImage,
          recordingsCount: s.playsCount,
          onSingTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => StudioScreen(song: s)));
          },
        )),

        // 5. Banner "THE DOGGY VOICE - Supernova 2026"
        GestureDetector(
          onTap: () => showModalBottomSheet(context: context, builder: (_) => const VocalRangeModal()),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [Color(0xFFFF007F), Color(0xFF00E5FF)]),
            ),
            padding: const EdgeInsets.all(14),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('THE DOGGY VOICE', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                    Text('Supernova 2026 Talent Show 🎤', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('🐶🎧', style: TextStyle(fontSize: 36)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCantarSubTab(String title) {
    final isSelected = _selectedCantarSubTab == title;
    return Padding(
      padding: const EdgeInsets.only(right: 14.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCantarSubTab = title;
            if (title == 'Popular') _searchQuery = 'Popular';
            else if (title == 'Pro') _searchQuery = 'Rock';
            else if (title == 'Oficial') _searchQuery = 'Latino';
            else _searchQuery = '';
          });
        },
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFFE51937) : AppTheme.textGrey,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PESTAÑA 3: MOMENTOS (FEED CON AUDIO REAL)
  // ==========================================
  Widget _buildMomentosTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: const Text('Momentos de la Comunidad 🌟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        ),
        ..._covers.asMap().entries.map((entry) {
          final idx = entry.key;
          final c = entry.value;
          final isPlayingThis = _playingCoverIndex == idx && _isPlayingCover;

          final posSec = isPlayingThis ? _feedPosition.inSeconds : 0;
          final durSec = isPlayingThis ? _feedDuration.inSeconds : c.duration;
          final posText = '${posSec ~/ 60}:${(posSec % 60).toString().padLeft(2, '0')}';
          final durText = '${durSec ~/ 60}:${(durSec % 60).toString().padLeft(2, '0')}';

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isPlayingThis ? const Color(0xFFE51937) : AppTheme.borderLight, width: isPlayingThis ? 1.5 : 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 18, backgroundImage: NetworkImage(c.user.avatarUrl)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const Text('Publicó un nuevo cover 🎵', style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE51937)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('¡Ahora sigues a ${c.user.username}!')),
                        );
                      },
                      child: const Text('+ Seguir', style: TextStyle(color: Color(0xFFE51937), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (c.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(c.description, style: const TextStyle(color: Colors.black87, fontSize: 11)),
                ],
                const SizedBox(height: 8),

                // BARRA DE AUDIO REAL Y FUNCIONAL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPlayingThis ? const Color(0xFFFFEBEE) : const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _togglePlayCover(idx, c.audioUrl),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFE51937),
                          child: Icon(
                            isPlayingThis ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$posText / $durText • Audio HD',
                              style: const TextStyle(color: AppTheme.textDark, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: (durSec > 0) ? (posSec / durSec).clamp(0.0, 1.0) : 0.0,
                              backgroundColor: Colors.black12,
                              color: const Color(0xFFE51937),
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.card_giftcard, color: Color(0xFFE51937), size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('¡Enviaste una Rosa de Regalo 🌹!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // PESTAÑA 4: MENSAJES (99+)
  // ==========================================
  Widget _buildMensajesTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text('Mensajes & Notificaciones', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 12),
        _buildMessageTile('🎁 Regalo Oficial DiviVoice', '¡Has recibido 50 Diamantes por iniciar sesión hoy!', 'Hace 5m', Icons.card_giftcard, const Color(0xFFE51937)),
        _buildMessageTile('🎤 Invitación a Sala de RyanMC', '¡Ven a cantar a la sala SHINE LIKE A STAR!', 'Hace 1h', Icons.mic, const Color(0xFFFF9800)),
        _buildMessageTile('👑 Familia DiviVoice Stars', 'Nuevo desafío grupal de covers activo.', 'Hace 3h', Icons.group, const Color(0xFF6B46C1)),
      ],
    );
  }

  Widget _buildMessageTile(String title, String subtitle, String time, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderLight)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
        trailing: Text(time, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
      ),
    );
  }

  // --- COMPONENTES AUXILIARES ---
  Widget _buildTopFiestaTab(String title, {required bool isSelected}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFiestaSubTab = title),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.textDark : AppTheme.textGrey,
            ),
          ),
          if (isSelected)
            Container(margin: const EdgeInsets.only(top: 4), height: 2.5, width: 20, color: const Color(0xFFE51937)),
        ],
      ),
    );
  }

  Widget _buildGenreFilter(String title, {required bool isSelected}) {
    return Padding(
      padding: const EdgeInsets.only(right: 14.0),
      child: GestureDetector(
        onTap: () => setState(() => _selectedGenreFilter = title),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFFE51937) : AppTheme.textGrey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPastelTile(String title, String subtitle, Color color, Color iconColor, IconData icon, {String? badge}) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          if (badge != null)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFE51937), borderRadius: BorderRadius.circular(6)),
                child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.bold)),
              ),
            ),
          Positioned(right: 0, bottom: 0, child: Icon(icon, color: iconColor.withOpacity(0.25), size: 24)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (badge != null) const SizedBox(height: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: iconColor)),
              Text(subtitle, style: const TextStyle(fontSize: 8.5, color: AppTheme.textGrey, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTilePill(String title, IconData icon, Color color, Color iconColor, double width) {
    return Container(
      width: width,
      height: 116,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: iconColor, size: 30),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: iconColor)),
        ],
      ),
    );
  }

  Widget _buildSmallPill(String title, Color bg, Color textCol) {
    return Container(
      height: 54,
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.centerLeft,
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: textCol)),
    );
  }

  // --- BARRA INFERIOR OFICIAL (5 ICONOS) ---
  Widget _buildBottomNavBar() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEF0F6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.festival_outlined, Icons.festival, 'Salas'),
          _buildNavItem(1, Icons.public, Icons.public, 'Momentos', hasRedDot: true),
          // Botón Central Cantar Rojo Elevado
          GestureDetector(
            onTap: () => setState(() => _currentIndex = 2),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFE51937),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x66E51937), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 22),
            ),
          ),
          _buildNavItem(3, Icons.chat_bubble_outline, Icons.chat_bubble, 'Mensajes', badgeText: '99+'),
          _buildNavItem(4, Icons.person_outline, Icons.person, 'Yo'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label, {bool hasRedDot = false, String? badgeText}) {
    final isSel = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isSel ? filledIcon : outlineIcon, color: isSel ? const Color(0xFFE51937) : AppTheme.textGrey, size: 20),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 9.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? const Color(0xFFE51937) : AppTheme.textGrey)),
              ],
            ),
            if (hasRedDot)
              Positioned(
                top: 6,
                right: 12,
                child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFE51937), shape: BoxShape.circle)),
              ),
            if (badgeText != null)
              Positioned(
                top: 2,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFE51937), borderRadius: BorderRadius.circular(8)),
                  child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
