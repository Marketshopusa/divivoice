import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static final WebSocketService instance = WebSocketService();
  static String get wsUrl => kIsWeb ? 'ws://localhost:8005/api/rooms/ws' : 'ws://10.0.2.2:8005/api/rooms/ws';
  
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<void> connect(int roomId, int userId) async {
    if (_isConnected) return;

    try {
      final uri = Uri.parse('$wsUrl/$roomId/$userId');
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> event = jsonDecode(data);
            _eventStreamController.add(event);
          } catch (e) {
            // Error parsing message
          }
        },
        onError: (error) {
          _isConnected = false;
        },
        onDone: () {
          _isConnected = false;
        },
      );
    } catch (e) {
      _isConnected = false;
    }
  }

  void disconnect(int roomId) {
    if (_channel != null) {
      _channel!.sink.close();
      _isConnected = false;
    }
  }

  void sendAction(String action, Map<String, dynamic> payload) {
    if (_channel != null && _isConnected) {
      final message = {
        'action': action,
        ...payload,
      };
      _channel!.sink.add(jsonEncode(message));
    }
  }

  // Helper actions
  void sendChatMessage(String content) {
    sendAction('chat_message', {'content': content});
  }

  void occupySeat(int seatIndex) {
    sendAction('occupy_seat', {'seat_index': seatIndex});
  }

  void vacateSeat() {
    sendAction('vacate_seat', {});
  }

  void toggleMute(bool isMuted) {
    sendAction('mute_seat', {'is_muted': isMuted});
  }

  void addToQueue(String songTitle, String? jobId) {
    sendAction('add_to_queue', {
      'song_title': songTitle,
      'job_id': jobId,
    });
  }

  void removeFromQueue(int queueId) {
    sendAction('remove_from_queue', {'queue_id': queueId});
  }

  void singNextSong() {
    sendAction('sing_next_song', {});
  }

  void finishSinging() {
    sendAction('finish_singing', {});
  }

  void sendGift(String giftName, int targetUserId) {
    sendAction('gift', {
      'gift_name': giftName,
      'target_user_id': targetUserId,
    });
  }

  void sendHeartReaction(String color) {
    sendAction('heart_reaction', {'color': color});
  }

  void toggleCamera(bool isActive) {
    sendAction('camera_toggle', {'is_active': isActive});
  }

  void sendWebRTCSignal(int targetUserId, dynamic data) {
    sendAction('webrtc_signal', {
      'target_user_id': targetUserId,
      'data': data,
    });
  }
}
