import 'user.dart';

class RoomSeat {
  final int seatIndex;
  final User? user;
  final bool isMuted;

  RoomSeat({
    required this.seatIndex,
    this.user,
    required this.isMuted,
  });

  factory RoomSeat.fromJson(Map<String, dynamic> json) {
    return RoomSeat(
      seatIndex: json['seat_index'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      isMuted: json['is_muted'] ?? false,
    );
  }
}

class QueueItem {
  final int id;
  final User user;
  final String songTitle;
  final String? jobId;
  final String status;

  QueueItem({
    required this.id,
    required this.user,
    required this.songTitle,
    this.jobId,
    required this.status,
  });

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'],
      user: User.fromJson(json['user']),
      songTitle: json['song_title'],
      jobId: json['job_id'],
      status: json['status'] ?? 'pending',
    );
  }
}

class Room {
  final int id;
  final String name;
  final User host;
  final bool isActive;
  final User? activeSinger;
  final String? currentSongTitle;
  final String? currentSongJobId;
  final List<RoomSeat> seats;
  final List<QueueItem> queue;

  Room({
    required this.id,
    required this.name,
    required this.host,
    required this.isActive,
    this.activeSinger,
    this.currentSongTitle,
    this.currentSongJobId,
    required this.seats,
    required this.queue,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    var seatsList = (json['seats'] as List?)
            ?.map((s) => RoomSeat.fromJson(s))
            .toList() ??
        [];
    var queueList = (json['queue'] as List?)
            ?.map((q) => QueueItem.fromJson(q))
            .toList() ??
        [];

    return Room(
      id: json['id'],
      name: json['name'],
      host: User.fromJson(json['host']),
      isActive: json['is_active'] ?? true,
      activeSinger: json['active_singer'] != null
          ? User.fromJson(json['active_singer'])
          : null,
      currentSongTitle: json['current_song_title'],
      currentSongJobId: json['current_song_job_id'],
      seats: seatsList,
      queue: queueList,
    );
  }
}
