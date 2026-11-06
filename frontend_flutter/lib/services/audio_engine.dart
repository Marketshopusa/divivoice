import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioEngine {
  static final AudioEngine instance = AudioEngine();
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioRecorder _voiceRecorder = AudioRecorder();
  
  bool _isRecording = false;
  String? _recordedVoicePath;
  String? _currentInstrumentalUrl;

  AudioPlayer get musicPlayer => _musicPlayer;
  bool get isRecording => _isRecording;
  String? get recordedVoicePath => _recordedVoicePath;

  // Inicializar reproductor de música y preparar archivo instrumental
  Future<void> prepareSong(String instrumentalUrl) async {
    _currentInstrumentalUrl = instrumentalUrl;
    await _musicPlayer.setUrl(instrumentalUrl);
  }

  // Iniciar la grabación (reproduce instrumental y graba micrófono de forma simultánea)
  Future<bool> startRecording() async {
    if (_isRecording) return false;

    // Solicitar permisos de micrófono
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return false;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final voiceFilePath = '${tempDir.path}/vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordedVoicePath = voiceFilePath;

      // Configurar grabación de audio en alta calidad
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      );

      // Iniciar grabación de voz
      await _voiceRecorder.start(config, path: voiceFilePath);

      // Iniciar reproducción instrumental desde el inicio
      await _musicPlayer.seek(Duration.zero);
      await _musicPlayer.play();
      
      _isRecording = true;
      return true;
    } catch (e) {
      await stopRecording();
      return false;
    }
  }

  // Detener la grabación
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      await _musicPlayer.stop();
      await _voiceRecorder.stop();
    } catch (e) {
      // Ignorar errores al detener
    } finally {
      _isRecording = false;
    }
  }

  // Pausar grabación/reproducción
  Future<void> pauseRecording() async {
    if (!_isRecording) return;
    await _musicPlayer.pause();
    await _voiceRecorder.pause();
  }

  // Reanudar grabación/reproducción
  Future<void> resumeRecording() async {
    if (!_isRecording) return;
    await _musicPlayer.play();
    await _voiceRecorder.resume();
  }

  // Reproducir la grabación local para vista previa
  final AudioPlayer _previewVocalPlayer = AudioPlayer();
  final AudioPlayer _previewInstrumentalPlayer = AudioPlayer();

  Future<void> startPreview({double vocalVolume = 1.0, double instrumentalVolume = 1.0}) async {
    if (_recordedVoicePath == null || _currentInstrumentalUrl == null) return;

    await _previewVocalPlayer.setFilePath(_recordedVoicePath!);
    await _previewInstrumentalPlayer.setUrl(_currentInstrumentalUrl!);

    await _previewVocalPlayer.setVolume(vocalVolume);
    await _previewInstrumentalPlayer.setVolume(instrumentalVolume);

    // Reproducir ambos en sincronía
    _previewVocalPlayer.play();
    _previewInstrumentalPlayer.play();
  }

  Future<void> stopPreview() async {
    await _previewVocalPlayer.stop();
    await _previewInstrumentalPlayer.stop();
  }

  Future<void> setPreviewVolumes(double vocalVolume, double instrumentalVolume) async {
    await _previewVocalPlayer.setVolume(vocalVolume);
    await _previewInstrumentalPlayer.setVolume(instrumentalVolume);
  }

  void dispose() {
    _musicPlayer.dispose();
    _voiceRecorder.dispose();
    _previewVocalPlayer.dispose();
    _previewInstrumentalPlayer.dispose();
  }
}
