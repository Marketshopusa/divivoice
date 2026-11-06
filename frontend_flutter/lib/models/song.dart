class Song {
  final String jobId;
  final String title;
  final String artist;
  final String genre;
  final String coverImage;
  final String difficulty;
  final String playsCount;
  final String? instrumentalUrl;
  final String? lyricsUrl;
  final String? srtUrl;
  final String? vttUrl;
  final String? videoUrl;

  Song({
    required this.jobId,
    required this.title,
    this.artist = 'Artista Destacado',
    this.genre = 'Pop / Balada',
    this.coverImage = 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300&auto=format&fit=crop&q=80',
    this.difficulty = 'Media',
    this.playsCount = '500K',
    this.instrumentalUrl,
    this.lyricsUrl,
    this.srtUrl,
    this.vttUrl,
    this.videoUrl,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      jobId: json['job_id'] ?? '',
      title: json['title'] ?? 'Canción sin título',
      artist: json['artist'] ?? 'Artista Destacado',
      genre: json['genre'] ?? 'Pop / Karaoke',
      coverImage: json['cover_image'] ?? 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300&auto=format&fit=crop&q=80',
      difficulty: json['difficulty'] ?? 'Media',
      playsCount: json['plays_count'] ?? '120K',
      instrumentalUrl: json['instrumental_url'],
      lyricsUrl: json['lyrics_url'],
      srtUrl: json['srt_url'],
      vttUrl: json['vtt_url'],
      videoUrl: json['video_url'],
    );
  }
}
