import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sons de interação disponíveis no app.
/// Para adicionar um novo som: 1) coloque o arquivo em assets/sounds/
/// 2) adicione uma entrada aqui.
enum AppSound {
  tap('tap.mp3'),
  toggleOn('toggle_on.mp3'),
  toggleOff('toggle_off.mp3'),
  like('like.mp3'),
  favorite('favorite.mp3'),
  share('share.mp3'),
  navigate('navigate.mp3'),
  success('success.mp3'),
  error('error.mp3');

  final String fileName;
  const AppSound(this.fileName);
}

/// Serviço central de sons do app.
class SoundService {
  SoundService._internal();
  static final SoundService instance = SoundService._internal();

  static const String _enabledKey = 'sound_enabled';
  static const String _volumeKey = 'sound_volume';

  bool _enabled = true;
  double _volume = 0.5;
  bool _initialized = false;

  final List<AudioPlayer> _pool = [];
  int _poolIndex = 0;
  static const int _poolSize = 4;

  bool get isEnabled => _enabled;
  double get volume => _volume;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? true;
      _volume = prefs.getDouble(_volumeKey) ?? 0.5;
    } catch (e) {
      debugPrint('SoundService: erro ao carregar preferências: $e');
    }

    for (int i = 0; i < _poolSize; i++) {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.stop);
      _pool.add(player);
    }
  }

  Future<void> play(AppSound sound) async {
    if (!_enabled || !_initialized) return;

    try {
      final player = _pool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _pool.length;

      await player.stop();
      await player.setVolume(_volume);
      await player.play(AssetSource('sounds/${sound.fileName}'));
    } catch (e) {
      debugPrint('SoundService: não foi possível tocar ${sound.fileName}: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, _volume);
    } catch (_) {}
  }

  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
    _pool.clear();
  }
}
