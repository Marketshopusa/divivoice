import 'user.dart';

class Cover {
  final int id;
  final String title;
  final String description;
  final User user;
  final String? instrumentalPath;
  final String? vocalPath;
  final String? mixPath;
  final String? videoPath;
  final String? lyricsPath;
  final int duration;
  final int likesCount;
  final bool hasLiked;
  final DateTime createdAt;

  Cover({
    required this.id,
    required this.title,
    required this.description,
    required this.user,
    this.instrumentalPath,
    this.vocalPath,
    this.mixPath,
    this.videoPath,
    this.lyricsPath,
    required this.duration,
    required this.likesCount,
    required this.hasLiked,
    required this.createdAt,
  });

  String? get audioUrl => mixPath ?? instrumentalPath ?? vocalPath;

  factory Cover.fromJson(Map<String, dynamic> json) {
    return Cover(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      user: User.fromJson(json['user']),
      instrumentalPath: json['instrumental_path'],
      vocalPath: json['vocal_path'],
      mixPath: json['mix_path'],
      videoPath: json['video_path'],
      lyricsPath: json['lyrics_path'],
      duration: json['duration'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
      hasLiked: json['has_liked'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
}
