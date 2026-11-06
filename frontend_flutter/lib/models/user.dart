class User {
  final int id;
  final String username;
  final String email;
  final String avatarUrl;
  final String bio;
  final int level;
  final int diamonds;
  final int followersCount;
  final int followingCount;
  final int rank;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.bio,
    this.level = 28,
    this.diamonds = 150,
    this.followersCount = 1340,
    this.followingCount = 381,
    this.rank = 178,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 1,
      username: json['username'] ?? 'Cantante',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
      bio: json['bio'] ?? 'Cantante Oficial DiviVoice 🎤',
      level: json['level'] ?? 28,
      diamonds: json['diamonds'] ?? 150,
      followersCount: json['followers_count'] ?? 1340,
      followingCount: json['following_count'] ?? 381,
      rank: json['rank'] ?? 178,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'bio': bio,
      'level': level,
      'diamonds': diamonds,
      'followers_count': followersCount,
      'following_count': followingCount,
      'rank': rank,
    };
  }
}
