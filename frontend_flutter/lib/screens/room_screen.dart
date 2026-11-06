import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/room.dart';
import '../models/user.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/lyric_visualizer.dart';
import '../widgets/starmaker_ui.dart';
import 'package:just_audio/just_audio.dart';

class RoomScreen extends StatefulWidget {
  final Room room;
  final User currentUser;

  const RoomScreen({super.key, required this.room, required this.currentUser});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with TickerProviderStateMixin {
  late WebSocketService _wsService;
  StreamSubscription? _wsSubscription;

  late List<RoomSeat> _seats;
  List<Map<String, dynamic>> _messages = [];
  List<Song> _availableSongs = [];
  
  User? _activeSinger;
  String? _currentSongTitle;
  List<dynamic> _lyrics = [];
  
  final AudioPlayer _backingPlayer = AudioPlayer();
  Duration _currentPosition = Duration.zero;
  StreamSubscription? _playerSubscription;

  final _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  
  int? _mySeatIndex;
  bool _isCameraOn = false;
  bool _isMicMuted = false;
  bool _isFrontCamera = true;
  int _roomDiamonds = 1240;
  int _viewerCount = 148;

  String? _flyingGiftAnimation;
  final List<_FloatingHeart> _hearts = [];
  final Random _random = Random();

  static const List<dynamic> _demoRoomLyrics = [
    {"text": "¡Escenario", "start": 0.0, "end": 0.8},
    {"text": "en", "start": 0.8, "end": 1.1},
    {"text": "Vivo!", "start": 1.1, "end": 1.8},
    {"text": "Sigue", "start": 2.2, "end": 2.6},
    {"text": "el", "start": 2.6, "end": 2.9},
    {"text": "ritmo", "start": 2.9, "end": 3.6},
    {"text": "y", "start": 3.6, "end": 3.9},
    {"text": "canta...", "start": 3.9, "end": 5.0},
    {"text": "¡Pide", "start": 5.5, "end": 6.0},
    {"text": "tu", "start": 6.0, "end": 6.3},
    {"text": "canción", "start": 6.3, "end": 7.0},
    {"text": "favorita! 🎤✨", "start": 7.0, "end": 8.5},
  ];

  String _getRoomBackground() {
    final name = widget.room.name.toLowerCase();
    if (name.contains('rock') || name.contains('shine')) {
      return 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=1200&auto=format&fit=crop&q=80';
    } else if (name.contains('dice') || name.contains('torneo') || name.contains('batalla') || name.contains('vegas')) {
      return 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=1200&auto=format&fit=crop&q=80';
    } else if (name.contains('balada') || name.contains('voices') || name.contains('gala')) {
      return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=1200&auto=format&fit=crop&q=80';
    }
    return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=1200&auto=format&fit=crop&q=80';
  }

  @override
  void initState() {
    super.initState();
    _wsService = WebSocketService.instance;
    _seats = List.generate(8, (i) => RoomSeat(seatIndex: i, user: null, isMuted: false));
    _initRoom();
  }

  Future<void> _initRoom() async {
    setState(() {
      for (var s in widget.room.seats) {
        if (s.seatIndex < 8) _seats[s.seatIndex] = s;
        if (s.user?.id == widget.currentUser.id) _mySeatIndex = s.seatIndex;
      }
      _activeSinger = widget.room.activeSinger ?? widget.room.host;
      _currentSongTitle = widget.room.currentSongTitle ?? '🎤 Canto & Video en Directo';
      _lyrics = _demoRoomLyrics;
    });

    _messages.add({
      'username': 'Sistema StarMaker',
      'content': '🎉 ¡Bienvenidos al show en vivo! Toca "Pedir Canción 🎵" para subir al escenario.',
      'isSystem': true
    });

    await _wsService.connect(widget.room.id, widget.currentUser.id);
    _availableSongs = await ApiService.getSongs();

    _wsSubscription = _wsService.eventStream.listen((event) {
      _handleWsEvent(event);
    });

    _playerSubscription = _backingPlayer.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _playerSubscription?.cancel();
    _backingPlayer.dispose();
    _wsService.disconnect(widget.room.id);
    super.dispose();
  }

  void _handleWsEvent(Map<String, dynamic> event) async {
    final type = event['event'];

    if (type == 'chat_message') {
      setState(() {
        _messages.add({
          'username': event['user']['username'],
          'content': event['content'],
        });
      });
      _scrollToBottom();
      
    } else if (type == 'user_joined') {
      setState(() {
        _viewerCount += 1;
        _messages.add({
          'username': 'Sistema',
          'content': '👋 ${event['user']['username']} entró al live',
          'isSystem': true
        });
      });
      _scrollToBottom();
      
    } else if (type == 'heart_reaction') {
      _spawnHeart();
      
    } else if (type == 'seat_updated') {
      final idx = event['seat_index'] as int;
      final seatUser = event['user'] != null ? User.fromJson(event['user']) : null;
      final muted = event['is_muted'] as bool;
      setState(() {
        _seats[idx] = RoomSeat(seatIndex: idx, user: seatUser, isMuted: muted);
        if (seatUser?.id == widget.currentUser.id) {
          _mySeatIndex = idx;
        } else if (_mySeatIndex == idx && seatUser == null) {
          _mySeatIndex = null;
        }
      });

    } else if (type == 'camera_stream_updated') {
      setState(() {
        _messages.add({
          'username': 'Cámara',
          'content': '📹 ${event['user']['username']} ${event['is_active'] ? "encendió" : "apagó"} su cámara',
          'isSystem': true,
        });
      });
      _scrollToBottom();

    } else if (type == 'gift_sent') {
      final senderName = event['user']['username'];
      final gift = event['gift_name'];
      final target = event['target_username'];
      
      _triggerGiftAnimation(gift);
      setState(() {
        _roomDiamonds += 50;
        _messages.add({
          'username': '🎁 Regalo',
          'content': '🌟 $senderName envió $gift a $target',
          'isSystem': true
        });
      });
      _scrollToBottom();
    }
  }

  void _spawnHeart() {
    final colors = [
      const Color(0xFFFF1A4D),
      const Color(0xFFFF9800),
      const Color(0xFFFFD700),
      const Color(0xFF00E676),
      const Color(0xFF00B0FF),
      const Color(0xFFD500F9),
      const Color(0xFFFF4081),
    ];
    final color = colors[_random.nextInt(colors.length)];
    final heart = _FloatingHeart(
      id: UniqueKey().toString(),
      color: color,
      startX: 20.0 + _random.nextDouble() * 30.0,
    );

    setState(() {
      _hearts.add(heart);
    });

    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _hearts.removeWhere((h) => h.id == heart.id);
        });
      }
    });
  }

  void _onScreenTap() {
    _spawnHeart();
    _wsService.sendHeartReaction('red');
  }

  void _triggerGiftAnimation(String gift) {
    setState(() {
      _flyingGiftAnimation = gift;
    });
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _flyingGiftAnimation = null;
        });
      }
    });
  }

  void _triggerSfx(String name) {
    setState(() {
      _messages.add({
        'username': 'Efecto de Sonido',
        'content': '🔊 ${widget.currentUser.username} activó $name',
        'isSystem': true,
      });
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      _wsService.sendChatMessage(text);
      _chatController.clear();
    }
  }

  void _toggleSeat(int index) {
    if (_seats[index].user == null) {
      setState(() {
        _seats[index] = RoomSeat(seatIndex: index, user: widget.currentUser, isMuted: false);
        _mySeatIndex = index;
        _messages.add({
          'username': 'Sistema',
          'content': '🎤 Te has sentado en el micrófono #${index + 1}',
          'isSystem': true,
        });
      });
      _wsService.occupySeat(index);
      _scrollToBottom();
    } else if (_seats[index].user!.id == widget.currentUser.id) {
      setState(() {
        _seats[index] = RoomSeat(seatIndex: index, user: null, isMuted: false);
        _mySeatIndex = null;
        _messages.add({
          'username': 'Sistema',
          'content': '👋 Has bajado del micrófono',
          'isSystem': true,
        });
      });
      _wsService.vacateSeat();
      _scrollToBottom();
    }
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    _wsService.toggleCamera(_isCameraOn);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isCameraOn ? Colors.green : Colors.black87,
        content: Text(_isCameraOn ? '📹 Cámara en vivo encendida' : '📹 Cámara apagada'),
      ),
    );
  }

  void _toggleMic() {
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
    _wsService.toggleMute(_isMicMuted);
  }

  // --- MODAL PARA PEDIR CANCIÓN Y CANTAR EN LA SALA ---
  void _openSongPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1035),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.queue_music, color: Color(0xFFE51937), size: 24),
                  SizedBox(width: 8),
                  Text('Pedir Canción para Cantar en Vivo 🎤', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _availableSongs.length,
                  itemBuilder: (context, index) {
                    final song = _availableSongs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(song.coverImage, width: 44, height: 44, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(song.artist, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE51937),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              setState(() {
                                _activeSinger = widget.currentUser;
                                _currentSongTitle = song.title;
                                _messages.add({
                                  'username': '🎤 Escenario',
                                  'content': '🌟 ${widget.currentUser.username} está cantando "${song.title}"',
                                  'isSystem': true,
                                });
                              });

                              final url = (song.instrumentalUrl != null && song.instrumentalUrl!.isNotEmpty)
                                  ? (song.instrumentalUrl!.startsWith('http') ? song.instrumentalUrl! : '${ApiService.baseUrl}${song.instrumentalUrl!}')
                                  : '${ApiService.baseUrl}/media/demo_song_latino_inst.mp3';

                              try {
                                await _backingPlayer.setUrl(url);
                                await _backingPlayer.play();
                              } catch (_) {}
                              _scrollToBottom();
                            },
                            child: const Text('Cantar 🎵', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GestureDetector(
            onTap: _onScreenTap,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // 1. FONDO DE ESCENARIO TEMÁTICO
                Positioned.fill(
                  child: _isCameraOn
                      ? _buildLiveCameraView()
                      : Image.network(
                          _getRoomBackground(),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF140824)),
                        ),
                ),

                // 2. DEGRADADO OSCURO FLOTANTE
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.55),
                          Colors.transparent,
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // 3. CORAZONES FLOTANTES TIKTOK
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      children: _hearts.map((h) => _buildAnimatedHeart(h)).toList(),
                    ),
                  ),
                ),

                // 4. INTERFAZ EN VIVO COMPLETA
                SafeArea(
                  child: Column(
                    children: [
                      // Header Superior (🔴 EN VIVO, Host, Diamantes, Espectadores, Salir)
                      _buildLiveTopHeader(),

                      // Escenario del Cantante Activo
                      _buildActiveSingerStage(),

                      // Teleprompter de Letras Sincronizadas
                      _buildLyricsGlassPanel(),

                      const Spacer(),

                      // 8 Asientos VIP
                      _buildSeatsSection(),
                      const SizedBox(height: 6),

                      // Fila Inferior: Chat + Botones TikTok
                      SizedBox(
                        height: 200,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: _buildChatOverlay()),
                            _buildSideActionsColumn(),
                          ],
                        ),
                      ),

                      // Barra Inferior de Entrada & Botón Pedir Canción
                      _buildBottomControls(),
                    ],
                  ),
                ),

                // 5. ANIMACIÓN FLOTANTE DE REGALO
                if (_flyingGiftAnimation != null)
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.2, end: 1.3),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.85),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFFD700), width: 3),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.6), blurRadius: 30),
                              ],
                            ),
                            child: Text(_flyingGiftAnimation!, style: const TextStyle(fontSize: 70)),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ESCENARIO DEL CANTANTE ACTIVO ---
  Widget _buildActiveSingerStage() {
    final singer = _activeSinger ?? widget.room.host;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(singer.avatarUrl),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎤 ${singer.username} (En Escenario)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  _currentSongTitle ?? 'Canto Libre',
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const LiveAudioWave(color: Color(0xFFFF1A4D)),
        ],
      ),
    );
  }

  // --- CÁMARA EN DIRECTO / ESCENARIO ---
  Widget _buildLiveCameraView() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=1200&auto=format&fit=crop&q=80',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Positioned(
            top: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent, width: 1.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.videocam, color: Colors.greenAccent, size: 16),
                  SizedBox(width: 6),
                  Text('Cámara en Vivo Activa • 1080p 60fps', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CORAZONES FLOTANTES ANIMADOS TIKTOK ---
  Widget _buildAnimatedHeart(_FloatingHeart heart) {
    return Positioned(
      bottom: 60,
      right: heart.startX,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1800),
        builder: (context, val, child) {
          final dy = -val * 240.0;
          final dx = sin(val * pi * 3) * 20.0;
          final opacity = (1.0 - val).clamp(0.0, 1.0);
          final scale = 0.6 + sin(val * pi) * 0.6;

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Icon(Icons.favorite, color: heart.color, size: 32),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- HEADER SUPERIOR ---
  Widget _buildLiveTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(widget.room.host.avatarUrl),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(widget.room.host.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Color(0xFFFFD700), size: 12),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: const Color(0xFFE51937), borderRadius: BorderRadius.circular(6)),
                          child: const Text('EN VIVO', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        Text('💎 $_roomDiamonds', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE51937),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: const Size(40, 24),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('¡Ahora sigues a ${widget.room.host.username}!')),
                    );
                  },
                  child: const Text('+ Seguir', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const Spacer(),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text('$_viewerCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 6),

          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // --- PANEL DE LETRAS FLOTANTE ---
  Widget _buildLyricsGlassPanel() {
    return Container(
      height: 75,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: LyricVisualizer(
        lyrics: _lyrics,
        currentPosition: _currentPosition,
      ),
    );
  }

  // --- 8 ASIENTOS VIP ---
  Widget _buildSeatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final seat = _seats[index];
          final isMe = seat.user?.id == widget.currentUser.id;

          return GestureDetector(
            onTap: () => _toggleSeat(index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFFFD700) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.black45,
                    backgroundImage: seat.user != null ? NetworkImage(seat.user!.avatarUrl) : null,
                    child: seat.user == null ? const Icon(Icons.add, size: 12, color: Colors.white54) : null,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  seat.user != null ? (isMe ? 'Yo' : seat.user!.username) : '${index + 1}',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: seat.user != null ? FontWeight.bold : FontWeight.normal,
                    color: seat.user != null ? Colors.white : Colors.white54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- CHAT FLOTANTE ---
  Widget _buildChatOverlay() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.transparent, Colors.white],
        stops: [0.0, 0.25],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _chatScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          final isSystem = msg['isSystem'] ?? false;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSystem ? const Color(0xFFE51937).withOpacity(0.4) : Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${msg['username']}: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isSystem ? const Color(0xFFFFD700) : const Color(0xFF64B5F6),
                    ),
                  ),
                  TextSpan(
                    text: msg['content'],
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- BOTONES LATERALES ---
  Widget _buildSideActionsColumn() {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0, bottom: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildTikTokButton(
            _isCameraOn ? Icons.videocam : Icons.videocam_off,
            _isCameraOn ? 'Cámara' : 'Off',
            _isCameraOn ? Colors.greenAccent : Colors.white,
            _toggleCamera,
          ),
          const SizedBox(height: 8),

          _buildTikTokButton(
            _isMicMuted ? Icons.mic_off : Icons.mic,
            _isMicMuted ? 'Mudo' : 'Mic',
            _isMicMuted ? Colors.redAccent : Colors.white,
            _toggleMic,
          ),
          const SizedBox(height: 8),

          _buildTikTokButton(Icons.queue_music, 'Cantar', const Color(0xFFFFD700), _openSongPickerModal),
          const SizedBox(height: 8),

          _buildTikTokButton(Icons.favorite, 'Me Gusta', const Color(0xFFE51937), _onScreenTap),
        ],
      ),
    );
  }

  Widget _buildTikTokButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- CONTROLES INFERIORES ---
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Botón Pedir Canción
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE51937),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(36, 32),
            ),
            onPressed: _openSongPickerModal,
            icon: const Icon(Icons.music_note, color: Colors.white, size: 14),
            label: const Text('Pedir', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),

          // Caja de Chat
          Expanded(
            child: TextField(
              controller: _chatController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Comentar en vivo...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 4),

          // Regalos
          IconButton(
            icon: const Text('🎁', style: TextStyle(fontSize: 18)),
            onPressed: () {
              showModalBottomSheet(
                backgroundColor: const Color(0xFF1E1E28),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(16),
                  height: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildGiftTile('🌹', 'Rosa'),
                      _buildGiftTile('⭐', 'Estrella'),
                      _buildGiftTile('👑', 'Corona'),
                      _buildGiftTile('🚀', 'Cohete'),
                    ],
                  ),
                ),
              );
            },
          ),

          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE51937),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 14),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftTile(String emoji, String title) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _triggerGiftAnimation(emoji);
        _wsService.sendGift(emoji, widget.room.host.id);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _FloatingHeart {
  final String id;
  final Color color;
  final double startX;

  _FloatingHeart({required this.id, required this.color, required this.startX});
}
