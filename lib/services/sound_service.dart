import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sons de interaÃ§Ã£o disponÃ­veis no app.
///
/// IMPORTANTE: hoje sÃ³ existem dois arquivos reais em assets/sounds/:
/// ambient.mp3 e ranking.mp3. Para cliques/toques comuns, usamos o som
/// de sistema do celular (SystemSound.click), que nÃ£o depende de arquivo.
///
/// Quando vocÃª adicionar novos arquivos .mp3 em assets/sounds/, basta:
/// 1) colocar o arquivo na pasta
/// 2) adicionar uma entrada aqui no enum
/// 3) trocar a chamada correspondente de playSystemClick() para play(AppSound.xxx)
enum AppSound {
  ranking('ranking.mp3'),
  ambient('ambient.mp3');

  final String fileName;
  const AppSound(this.fileName);
}

/// ServiÃ§o central de sons do app.
///
/// Uso para som de sistema (clique simples, sem precisar de arquivo):
///   SoundService.instance.playSystemClick();
///
/// Uso para som de arquivo especÃ­fico:
///   SoundService.instance.play(AppSound.ranking);
///
/// Controle:
///   SoundService.instance.setEnabled(false);
///   SoundService.instance.setVolume(0.5);
class SoundService {
  SoundService._internal();
  static final SoundService instance = SoundService._internal();

  static const String _enabledKey = 'sound_enabled';
  static const String _volumeKey = 'sound_volume';

  bool _enabled = true;
  double _volume = 0.5;
  bool _initialized = false;

  // Pool de players para permitir sons sobrepostos sem cortar um ao outro.
  final List<AudioPlayer> _pool = [];
  int _poolIndex = 0;
  static const int _poolSize = 4;

  bool get isEnabled => _enabled;
  double get volume => _volume;

  /// Deve ser chamado uma vez, no main.dart, antes do runApp.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? true;
      _volume = prefs.getDouble(_volumeKey) ?? 0.5;
    } catch (e) {
      debugPrint('SoundService: erro ao carregar preferÃªncias: $e');
    }

    for (int i = 0; i < _poolSize; i++) {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.stop);
      _pool.add(player);
    }
  }

  /// Toca o som de clique padrÃ£o do sistema operacional.
  /// Ideal para botÃµes, abas, menus â€” nÃ£o depende de nenhum arquivo
  /// de Ã¡udio, entÃ£o nunca falha por arquivo ausente.
  void playSystemClick() {
    if (!_enabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('SoundService: erro ao tocar som de sistema: $e');
    }
  }

  /// Toca um som de interaÃ§Ã£o a partir de um arquivo em assets/sounds/.
  /// Silenciosamente ignora se os sons estiverem desativados ou se o
  /// arquivo nÃ£o existir (nunca deve quebrar a experiÃªncia do usuÃ¡rio).
  Future<void> play(AppSound sound) async {
    if (!_enabled || !_initialized) return;

    try {
      final player = _pool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _pool.length;

      await player.stop();
      await player.setVolume(_volume);
      await player.play(AssetSource('sounds/${sound.fileName}'));
    } catch (e) {
      debugPrint('SoundService: nÃ£o foi possÃ­vel tocar ${sound.fileName}: $e');
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
