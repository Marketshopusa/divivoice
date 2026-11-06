import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';

// --- MODAL DE FAMILIAS / CLANES ---
class FamilyModal extends StatefulWidget {
  final User user;
  const FamilyModal({super.key, required this.user});

  @override
  State<FamilyModal> createState() => _FamilyModalState();
}

class _FamilyModalState extends State<FamilyModal> {
  final List<Map<String, dynamic>> _families = [
    {
      'name': 'DiviVoice Stars 👑',
      'captain': 'StarSinger_VIP',
      'members': 48,
      'level': 12,
      'slogan': 'Familia oficial de talentos y torneos semanales',
      'joined': true,
    },
    {
      'name': 'Baladas del Alma 💖',
      'captain': 'Luna_Melody',
      'members': 35,
      'level': 8,
      'slogan': 'Para los amantes del pop romántico y duetos',
      'joined': false,
    },
    {
      'name': 'Rockeros & Clásicos 🎸',
      'captain': 'Sofia_Rock',
      'members': 62,
      'level': 15,
      'slogan': 'Rock en español e internacional sin límites',
      'joined': false,
    },
    {
      'name': 'Voz de Oro Latino 🌟',
      'captain': 'Carlos_Voz',
      'members': 29,
      'level': 6,
      'slogan': 'Comunidad de canto libre y apoyo mutuo',
      'joined': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.groups, color: Color(0xFFE51937), size: 24),
                  SizedBox(width: 8),
                  Text('Familias & Clubes de Canto', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Text('Únete a una familia para competir en guerras de clanes, recibir regalos y ganar medallas exclusivas.', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _families.length,
              itemBuilder: (context, index) {
                final fam = _families[index];
                final isJoined = fam['joined'] as bool;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFFFF0F2),
                        child: Text('${fam['level']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE51937))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fam['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('Capitán: ${fam['captain']} • 👤 ${fam['members']} miembros', style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(fam['slogan'], style: const TextStyle(color: Colors.black87, fontSize: 10)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isJoined ? Colors.grey[300] : const Color(0xFFE51937),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                        onPressed: () {
                          setState(() {
                            fam['joined'] = !isJoined;
                            if (!isJoined) {
                              fam['members'] = (fam['members'] as int) + 1;
                            } else {
                              fam['members'] = (fam['members'] as int) - 1;
                            }
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(!isJoined ? '¡Te has unido a ${fam['name']}!' : 'Has salido de ${fam['name']}')),
                          );
                        },
                        child: Text(
                          isJoined ? 'Miembro' : 'Unirse',
                          style: TextStyle(color: isJoined ? Colors.black87 : Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
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
  }
}

// --- MODAL DE TAREAS DIARIAS Y RECOMPENSAS ---
class DailyTasksModal extends StatefulWidget {
  final Function(int) onDiamondsAdded;
  const DailyTasksModal({super.key, required this.onDiamondsAdded});

  @override
  State<DailyTasksModal> createState() => _DailyTasksModalState();
}

class _DailyTasksModalState extends State<DailyTasksModal> {
  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Iniciar sesión en DiviVoice', 'reward': 20, 'claimed': false, 'desc': 'Recompensa de asistencia diaria'},
    {'title': 'Cantar 1 canción en el Estudio', 'reward': 30, 'claimed': false, 'desc': 'Graba y guarda tu voz'},
    {'title': 'Entrar a una Sala de Fiesta', 'reward': 15, 'claimed': false, 'desc': 'Escucha a cantantes en vivo'},
    {'title': 'Enviar una Rosa de regalo 🌹', 'reward': 25, 'claimed': false, 'desc': 'Apoya a tu artista favorito'},
    {'title': 'Publicar un Cover en Momentos', 'reward': 50, 'claimed': false, 'desc': 'Comparte tu talento con la comunidad'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 480,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_month, color: Color(0xFFE51937)),
                  SizedBox(width: 8),
                  Text('Tareas Diarias & Diamantes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final t = _tasks[index];
                final claimed = t['claimed'] as bool;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFFFF0E5), borderRadius: BorderRadius.circular(10)),
                        child: const Text('💎', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(t['desc'], style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: claimed ? Colors.grey[300] : const Color(0xFFE51937),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: claimed
                            ? null
                            : () {
                                setState(() => t['claimed'] = true);
                                widget.onDiamondsAdded(t['reward'] as int);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(backgroundColor: Colors.green, content: Text('¡+${t['reward']} Diamantes añadidos a tu cuenta! 💎')),
                                );
                              },
                        child: Text(
                          claimed ? 'Reclamado' : '+${t['reward']} 💎',
                          style: TextStyle(color: claimed ? Colors.black45 : Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
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
  }
}

// --- MODAL DE PRUEBA DE RANGO VOCAL INTERACTIVO ---
class VocalRangeModal extends StatefulWidget {
  const VocalRangeModal({super.key});

  @override
  State<VocalRangeModal> createState() => _VocalRangeModalState();
}

class _VocalRangeModalState extends State<VocalRangeModal> {
  String _currentStep = 'Listo';
  String _detectedRange = 'Tenor / Soprano Ligera (C3 - G5)';
  bool _isTesting = false;

  void _runTest() async {
    setState(() {
      _isTesting = true;
      _currentStep = 'Escuchando nota más grave... (Canta un tono bajo)';
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _currentStep = 'Escuchando nota más aguda... (Canta tu nota más alta)');

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _currentStep = '¡Prueba Completada!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 400,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.graphic_eq, color: Color(0xFFE51937)),
                  SizedBox(width: 8),
                  Text('Prueba de Rango Vocal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Descubre tu tesitura vocal exacta y las canciones que mejor se adaptan a tu voz.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(_currentStep, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE51937))),
                const SizedBox(height: 10),
                Text('Rango Estimado: $_detectedRange', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE51937),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isTesting ? null : _runTest,
              icon: Icon(_isTesting ? Icons.hourglass_top : Icons.mic, color: Colors.white),
              label: Text(_isTesting ? 'Analizando tu Voz...' : 'Comenzar Test Vocal 🎙️', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
