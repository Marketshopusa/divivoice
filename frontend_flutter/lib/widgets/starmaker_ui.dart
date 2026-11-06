import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// --- BARRA SUPERIOR DE MARQUEE / TICKER ROJO DE RECOMPENSAS ---
class StarMakerTickerBar extends StatelessWidget {
  const StarMakerTickerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: const Color(0xFFE51937),
      child: const Row(
        children: [
          Text('🌻SF🕊️', style: TextStyle(fontSize: 12)),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'por ganar 300 Monedas en el Banquete Dorado de DiviVoice...',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// --- FILA DE HISTORIAS Y SALAS EN VIVO DE AMIGOS ---
class StarMakerStoriesRow extends StatelessWidget {
  final VoidCallback onMyRoomTap;

  const StarMakerStoriesRow({super.key, required this.onMyRoomTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        children: [
          // 1. Mi Sala (Botón Púrpura)
          GestureDetector(
            onTap: onMyRoomTap,
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD6C8FB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.home_filled, color: Color(0xFF6B46C1), size: 28),
                ),
                const SizedBox(height: 4),
                const Text('Mi sala', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // 2. RyanMC (En vivo)
          _buildStoryAvatar(
            name: 'RyanMC...',
            tag: 'En vivo',
            subtag: 'Popular',
            avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
            isLive: true,
          ),
          const SizedBox(width: 14),

          // 3. Amistad / Mutuo
          _buildStoryAvatar(
            name: '✨ Luna ✨',
            tag: 'Chat',
            subtag: 'Mutuo',
            avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
            isLive: false,
          ),
          const SizedBox(width: 14),

          // 4. Draven
          _buildStoryAvatar(
            name: 'Draven...',
            tag: 'En vivo',
            subtag: 'Popular',
            avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
            isLive: true,
          ),
          const SizedBox(width: 14),

          // 5. Sofia
          _buildStoryAvatar(
            name: 'Sofia_Rock',
            tag: 'En vivo',
            subtag: 'Talento',
            avatarUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200',
            isLive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStoryAvatar({
    required String name,
    required String tag,
    required String subtag,
    required String avatarUrl,
    required bool isLive,
  }) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isLive
                    ? const LinearGradient(colors: [Color(0xFFFF1A4D), Color(0xFFFF9800)])
                    : null,
                color: isLive ? null : const Color(0xFFD6C8FB),
              ),
              child: CircleAvatar(
                radius: 23,
                backgroundImage: NetworkImage(avatarUrl),
              ),
            ),
            Positioned(
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isLive ? AppTheme.primaryRed : const Color(0xFF9C27B0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        Text(subtag, style: const TextStyle(fontSize: 9, color: AppTheme.textGrey)),
      ],
    );
  }
}

// --- TRIO DE TARJETAS PASTEL (FAMILIA, CANTAR, CHAT) ---
class StarMakerPastelTrio extends StatelessWidget {
  final VoidCallback onSingTap;

  const StarMakerPastelTrio({super.key, required this.onSingTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      child: Row(
        children: [
          // Familia
          Expanded(
            child: _buildPastelCard(
              title: 'Familia',
              subtitle: '👤 33.0k',
              color: AppTheme.pastelPeach,
              iconColor: const Color(0xFFFF9800),
              icon: Icons.groups,
              badge: null,
            ),
          ),
          const SizedBox(width: 8),

          // Cantar
          Expanded(
            flex: 12,
            child: GestureDetector(
              onTap: onSingTap,
              child: _buildPastelCard(
                title: 'ıll Cantar',
                subtitle: '96.9k Canto en',
                color: AppTheme.pastelPink,
                iconColor: AppTheme.primaryRed,
                icon: Icons.graphic_eq,
                badge: 'Visitas de amigos',
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Chat
          Expanded(
            child: _buildPastelCard(
              title: 'Chat',
              subtitle: '👤 41.4k',
              color: AppTheme.pastelPeach,
              iconColor: const Color(0xFFFF9800),
              icon: Icons.chat_bubble,
              badge: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastelCard({
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
    required IconData icon,
    String? badge,
  }) {
    return Container(
      height: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          if (badge != null)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(icon, color: iconColor.withOpacity(0.3), size: 28),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (badge != null) const SizedBox(height: 10),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: iconColor)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 9, color: AppTheme.textGrey, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

// --- PASTEL QUICK PILLS DE LA PANTALLA DE CANTAR (IMAGE 5) ---
class StarMakerSingPills extends StatelessWidget {
  final VoidCallback onAiCreateTap;

  const StarMakerSingPills({super.key, required this.onAiCreateTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          // Fila 1 & 2 combinada en bloques
          _buildPillTile(
            title: 'Grupo\nSeleccion...',
            icon: Icons.public,
            color: AppTheme.pastelLavender,
            iconColor: const Color(0xFF6B46C1),
            width: 105,
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _buildSmallPill('💌 Mis Canciones', AppTheme.pastelPeach, const Color(0xFFE65100)),
              const SizedBox(height: 8),
              _buildSmallPill('🎧 Prueba de Rango', AppTheme.pastelYellow, const Color(0xFFF57F17)),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _buildSmallPill('👥 Colaboración', AppTheme.pastelMint, const Color(0xFF2E7D32)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onAiCreateTap,
                child: _buildSmallPill('🎼 Creación IA ✨', AppTheme.pastelPink, AppTheme.primaryRed),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _buildSmallPill('🎵 Estilos', AppTheme.pastelLavender, const Color(0xFF6B46C1)),
              const SizedBox(height: 8),
              _buildSmallPill('🎤 Canto Pro', AppTheme.pastelCyan, const Color(0xFF0288D1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillTile({
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required double width,
  }) {
    return Container(
      width: width,
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: iconColor, size: 36),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: iconColor)),
        ],
      ),
    );
  }

  Widget _buildSmallPill(String title, Color bg, Color textCol) {
    return Container(
      height: 56,
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerLeft,
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textCol)),
    );
  }
}

// --- FILA DE CANCIÓN DEL CATÁLOGO DE CANTAR (IMAGE 5) ---
class StarMakerSongItem extends StatelessWidget {
  final String title;
  final String artist;
  final String coverUrl;
  final String recordingsCount;
  final VoidCallback onSingTap;

  const StarMakerSongItem({
    super.key,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.recordingsCount,
    required this.onSingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          // Portada del Álbum
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              coverUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 52,
                height: 52,
                color: const Color(0xFF1E1E28),
                child: const Icon(Icons.music_note, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info de la Canción
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFFF9800), width: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Points', style: TextStyle(color: Color(0xFFFF9800), fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        artist,
                        style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: AppTheme.primaryRed, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      'Popular · $recordingsCount grabaciones',
                      style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botón Canta Rojo Redondeado Oficial
          GestureDetector(
            onTap: onSingTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFCDD2), width: 0.8),
              ),
              child: const Text(
                'Canta',
                style: TextStyle(
                  color: Color(0xFFE51937),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- TARJETA DE SALA DE FIESTA EN 2 COLUMNAS (IMAGE 4) ---
class StarMakerPartyRoomCard extends StatelessWidget {
  final String title;
  final String tag;
  final String hostName;
  final String posterUrl;
  final int listeners;
  final int level;
  final VoidCallback onTap;

  const StarMakerPartyRoomCard({
    super.key,
    required this.title,
    required this.tag,
    required this.hostName,
    required this.posterUrl,
    required this.listeners,
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          image: DecorationImage(
            image: NetworkImage(posterUrl),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.75)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header con Tag y Nivel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tag.contains('vivo') ? AppTheme.primaryRed : const Color(0xFF9C27B0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB800),
                      shape: BoxShape.circle,
                    ),
                    child: Text('$level', style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              // Título de Sala y Oyentes en Vivo
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(hostName, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      Row(
                        children: [
                          const Icon(Icons.equalizer, color: Colors.white70, size: 12),
                          const SizedBox(width: 2),
                          Text('$listeners', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Insignia VIP de nivel de usuario estilo StarMaker
class VipBadge extends StatelessWidget {
  final int level;
  final bool isVip;

  const VipBadge({super.key, this.level = 18, this.isVip = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: isVip ? AppTheme.goldGradient : AppTheme.purpleGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVip) ...[
            const Icon(Icons.stars, color: Colors.white, size: 10),
            const SizedBox(width: 2),
          ],
          Text(
            isVip ? 'VIP Lv.$level' : 'Lv.$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Onda de ecualizador de audio animada
class LiveAudioWave extends StatelessWidget {
  final Color color;

  const LiveAudioWave({super.key, this.color = AppTheme.primaryRed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBar(14, 0.4),
        const SizedBox(width: 2),
        _buildBar(22, 0.9),
        const SizedBox(width: 2),
        _buildBar(10, 0.3),
        const SizedBox(width: 2),
        _buildBar(18, 0.7),
      ],
    );
  }

  Widget _buildBar(double height, double opacity) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
