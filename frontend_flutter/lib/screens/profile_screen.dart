import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/cover.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starmaker_modals.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Cover> _myCovers = [];
  bool _isLoading = false;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final covers = await ApiService.getCovers(userId: widget.user.id);
    setState(() {
      _myCovers = covers;
      _isLoading = false;
    });
  }

  void _addDiamonds(int amount) {
    setState(() {
      _currentUser = User(
        id: _currentUser.id,
        username: _currentUser.username,
        email: _currentUser.email,
        avatarUrl: _currentUser.avatarUrl,
        bio: _currentUser.bio,
        level: _currentUser.level,
        diamonds: _currentUser.diamonds + amount,
        followersCount: _currentUser.followersCount,
        followingCount: _currentUser.followingCount,
        rank: _currentUser.rank,
      );
    });
  }

  void _openEditProfileDialog() {
    final nameController = TextEditingController(text: _currentUser.username);
    final bioController = TextEditingController(text: _currentUser.bio);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Editar Perfil de Artista', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre de usuario / Artista'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(labelText: 'Biografía / Estado'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE51937)),
              onPressed: () {
                setState(() {
                  _currentUser = User(
                    id: _currentUser.id,
                    username: nameController.text.trim(),
                    email: _currentUser.email,
                    avatarUrl: _currentUser.avatarUrl,
                    bio: bioController.text.trim(),
                    level: _currentUser.level,
                    diamonds: _currentUser.diamonds,
                  );
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Colors.green, content: Text('¡Perfil actualizado con éxito!')),
                );
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 1. BANNER SUPERIOR INMERSIVO CON FOTO DE ESCENARIO
        Stack(
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.85)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botones Superiores
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('1:04 🔔', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                              onPressed: _openEditProfileDialog,
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                              onPressed: _openEditProfileDialog,
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Avatar y Datos del Usuario
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundImage: NetworkImage(_currentUser.avatarUrl),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('🇺🇸 🇻🇪 ', style: TextStyle(fontSize: 12)),
                                      Text(
                                        _currentUser.username,
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const Text(' 🇻🇪 🇺🇸', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: ${_currentUser.id}8471920 • ${_currentUser.bio}',
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Fila de Insignias y Diamantes
                        Row(
                          children: [
                            _buildPillBadge('💎 ${_currentUser.diamonds}', const Color(0xFF00C0FF)),
                            const SizedBox(width: 5),
                            _buildPillBadge('👑 Lv.${_currentUser.level}', const Color(0xFFFFB800)),
                            const SizedBox(width: 5),
                            _buildPillBadge('DiviVoice ⭐', const Color(0xFFFF9800)),
                            const SizedBox(width: 5),
                            _buildPillBadge('VIP 💖', const Color(0xFFE91E63)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // 2. TARJETA BLANCA DE ESTADÍSTICAS
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn('${_currentUser.followersCount}', 'Seguidores'),
              _buildStatDivider(),
              _buildStatColumn('${_currentUser.followingCount}', 'Seguidos'),
              _buildStatDivider(),
              _buildStatColumn('${_currentUser.rank}⁺⁴', 'Clasificación'),
              _buildStatDivider(),
              _buildStatColumn('${_currentUser.diamonds * 12}', 'Regalos'),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. BANNER MORADO INTERACTIVO
        GestureDetector(
          onTap: () => showModalBottomSheet(context: context, builder: (_) => const VocalRangeModal()),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE1BEE7), Color(0xFFF3E5F5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Color(0xFF9C27B0),
                  child: Icon(Icons.music_note, color: Colors.white, size: 14),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Desafío de Covers Grupales Curados',
                    style: TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Icon(Icons.chevron_right, color: Color(0xFF6A1B9A), size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 4. TARJETA DE FAMILIA INTERACTIVA
        GestureDetector(
          onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => FamilyModal(user: _currentUser)),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 38,
                    height: 38,
                    color: const Color(0xFF1E1E28),
                    child: const Icon(Icons.headset, color: Colors.pinkAccent, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DiviVoice Stars 👑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
                      SizedBox(height: 2),
                      Text('Capitán 👑 • Familia Oficial Activa', style: TextStyle(color: Colors.pinkAccent, fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black38, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 5. CUADRÍCULA DE HERRAMIENTAS INTERACTIVAS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildToolItem(Icons.mic_none, 'Borradores', const Color(0xFFE51937), () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tienes 2 grabaciones guardadas en tus borradores locales.')),
                );
              }),
              _buildToolItem(Icons.library_music_outlined, 'Mis Canciones', const Color(0xFFE51937), () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cargando historial de canciones grabadas...')),
                );
              }),
              _buildToolItem(Icons.calendar_today_outlined, 'Tarea Diaria', const Color(0xFFE51937), () {
                showModalBottomSheet(context: context, builder: (_) => DailyTasksModal(onDiamondsAdded: _addDiamonds));
              }),
              _buildToolItem(Icons.stars_outlined, 'VIP', const Color(0xFFE51937), () {
                showModalBottomSheet(context: context, builder: (_) => const VocalRangeModal());
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 6. LISTA DE MIS COVERS
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mis Grabaciones & Covers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 10),
              if (_myCovers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: Text('Aún no has publicado canciones. ¡Graba tu primer éxito en el estudio!', style: TextStyle(color: AppTheme.textGrey, fontSize: 11.5))),
                )
              else
                ..._myCovers.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(radius: 16, backgroundColor: Color(0xFFFFEBEE), child: Icon(Icons.play_arrow, color: Color(0xFFE51937), size: 18)),
                  title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${c.duration}s • Grabación HD • ❤️ ${c.likesCount}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 10.5)),
                  trailing: const Icon(Icons.more_vert, color: AppTheme.textGrey, size: 18),
                )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String number, String label) {
    return Column(
      children: [
        Text(number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 18, width: 0.8, color: const Color(0xFFE0E0E0));
  }

  Widget _buildPillBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildToolItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textDark, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
