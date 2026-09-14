import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ═══════════════════════════════════════════════════════════════════
// SERVIÇO DE ANÚNCIO RECOMPENSADO (Rewarded Ad)
// ═══════════════════════════════════════════════════════════════════
// Usado exclusivamente pela tela de Check-in para recuperar dias
// perdidos. Segue o mesmo padrão de inicialização já usado no resto
// do app (MobileAds.instance já é chamado em main.dart — aqui só
// carregamos o anúncio em si).
//
// ⚠️ IMPORTANTE sobre a recompensa:
// A recompensa (recuperar o dia + XP) só deve ser concedida dentro do
// callback onUserEarnedReward, chamado pelo SDK apenas quando o
// usuário efetivamente assiste ao anúncio até o fim. Se o usuário
// fechar o anúncio antes (onAdDismissedFullScreenContent sem ter
// passado por onUserEarnedReward), nada é concedido — isso é
// controlado pela própria Google, não por lógica nossa, então não tem
// como ser burlado fechando o anúncio na metade.
class RewardedAdService {
  static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();

  // ── IDs de teste oficiais do Google ──────────────────────────────
  // Troque pelos IDs reais de unidade de anúncio REWARDED (criados no
  // console do AdMob, distintos do ID de banner que já existe em
  // ad_config.dart) antes de publicar. Usar o de teste em produção
  // não gera receita nem viola política, mas também não paga nada.
  static const String _testAndroidId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosId = 'ca-app-pub-3940256099942544/1712485313';

  // TODO: substitua pelo ID real da unidade de anúncio Rewarded para
  // iOS quando publicar nessa plataforma (o Android já está
  // preenchido com o ID real criado no AdMob).
  static const String _prodAndroidId = 'ca-app-pub-5015489666829491/9364283841';
  static const String _prodIosId = 'SEU_AD_UNIT_ID_REWARDED_IOS_AQUI';

  // Verifica o ID real por PLATAFORMA (não os dois de uma vez): o
  // Android já tem o ID real preenchido acima, então em produção
  // Android usa o anúncio de verdade mesmo enquanto o ID de iOS
  // ainda não foi preenchido.
  static bool get _useTestAds {
    if (Platform.isIOS) return _prodIosId.startsWith('SEU_');
    return _prodAndroidId.startsWith('SEU_');
  }

  String get _adUnitId {
    if (_useTestAds) {
      return Platform.isIOS ? _testIosId : _testAndroidId;
    }
    return Platform.isIOS ? _prodIosId : _prodAndroidId;
  }

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  bool get isReady => _rewardedAd != null;

  // ── Pré-carrega o anúncio ────────────────────────────────────────
  // Chamar ao entrar na tela de Check-in, para que o anúncio já
  // esteja pronto quando o usuário tocar em "Assistir anúncio".
  Future<void> preload() async {
    if (_isLoading || _rewardedAd != null) return;
    _isLoading = true;

    await RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
        },
      ),
    );
  }

  // ── Exibe o anúncio já carregado ─────────────────────────────────
  // onRewardEarned é chamado SOMENTE quando o SDK confirma que o
  // usuário completou o anúncio (onUserEarnedReward do Google Mobile
  // Ads). onClosed é sempre chamado ao final, tenha ou não ganhado a
  // recompensa — útil para reesconder loading/fechar diálogos.
  Future<void> show({
    required void Function() onRewardEarned,
    required void Function() onClosed,
    void Function()? onFailedToShow,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      onFailedToShow?.call();
      return;
    }

    bool rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        onClosed();
        // Recarrega o próximo anúncio em segundo plano, para a
        // próxima recuperação de dia já estar pronta.
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        onFailedToShow?.call();
        preload();
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
        onRewardEarned();
      },
    );

    // rewardEarned fica disponível para debug/log se necessário; a
    // decisão real de conceder XP já aconteceu dentro do callback
    // onUserEarnedReward acima, síncrona com a confirmação do SDK.
    // ignore: unused_local_variable
    final _ = rewardEarned;
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}