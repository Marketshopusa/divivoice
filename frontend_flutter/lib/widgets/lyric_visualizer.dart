import 'package:flutter/material.dart';

class LyricVisualizer extends StatelessWidget {
  final List<dynamic> lyrics;
  final Duration currentPosition;
  final Color activeColor;
  final Color inactiveColor;

  const LyricVisualizer({
    super.key,
    required this.lyrics,
    required this.currentPosition,
    this.activeColor = const Color(0xFFFFD700), // Oro Brillante
    this.inactiveColor = Colors.white70,
  });

  // Agrupa palabras individuales en estrofas/frases legibles de karaoke
  List<Map<String, dynamic>> _groupLyricsIntoPhrases(List<dynamic> raw) {
    if (raw.isEmpty) return [];

    List<Map<String, dynamic>> phrases = [];
    List<String> currentWords = [];
    double phraseStart = 0.0;
    double phraseEnd = 0.0;

    for (int i = 0; i < raw.length; i++) {
      final item = raw[i];
      final text = (item['text'] ?? item['word'] ?? '').toString().trim();
      final start = (item['start'] ?? 0.0).toDouble();
      final end = (item['end'] ?? start + 0.5).toDouble();

      if (currentWords.isEmpty) {
        phraseStart = start;
      }
      currentWords.add(text);
      phraseEnd = end;

      // Cerrar frase si tiene 5 o más palabras, o si hay una pausa > 1.5s, o es el final
      bool isPunctuation = text.endsWith('.') || text.endsWith('!') || text.endsWith('?') || text.endsWith(',');
      bool isLongPause = (i + 1 < raw.length) && (((raw[i + 1]['start'] ?? 0.0).toDouble() - end) > 1.2);
      bool isMaxWords = currentWords.length >= 6;

      if (isPunctuation || isLongPause || isMaxWords || i == raw.length - 1) {
        phrases.add({
          'text': currentWords.join(' '),
          'start': phraseStart,
          'end': phraseEnd,
        });
        currentWords = [];
      }
    }
    return phrases;
  }

  @override
  Widget build(BuildContext context) {
    if (lyrics.isEmpty) {
      return const Center(
        child: Text(
          '🎵 Sigue el ritmo y comienza a cantar...',
          style: TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
        ),
      );
    }

    final phrases = _groupLyricsIntoPhrases(lyrics);
    final secs = currentPosition.inMilliseconds / 1000.0;

    // Encontrar índice de la frase activa
    int activeIndex = -1;
    for (int i = 0; i < phrases.length; i++) {
      final p = phrases[i];
      if (secs >= p['start'] && secs <= p['end'] + 0.5) {
        activeIndex = i;
        break;
      }
      if (secs < p['start'] && activeIndex == -1) {
        activeIndex = i > 0 ? i - 1 : 0;
        break;
      }
    }
    if (activeIndex == -1 && phrases.isNotEmpty) {
      activeIndex = secs >= phrases.last['end'] ? phrases.length - 1 : 0;
    }

    final prevPhrase = activeIndex > 0 ? phrases[activeIndex - 1]['text'] : '';
    final currentPhrase = phrases.isNotEmpty ? phrases[activeIndex]['text'] : '';
    final nextPhrase = activeIndex + 1 < phrases.length ? phrases[activeIndex + 1]['text'] : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Frase Anterior
          if (prevPhrase.isNotEmpty)
            Opacity(
              opacity: 0.4,
              child: Text(
                prevPhrase,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 6),

          // Frase Actual Iluminada
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              currentPhrase,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: activeColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: activeColor.withOpacity(0.8), blurRadius: 12),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),

          // Frase Siguiente
          if (nextPhrase.isNotEmpty)
            Opacity(
              opacity: 0.55,
              child: Text(
                nextPhrase,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
