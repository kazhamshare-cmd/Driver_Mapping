import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../models/game_settings.dart';
import '../services/i18n_service.dart';
import '../services/sound_service.dart';
import '../widgets/language_selector.dart';
import '../widgets/banner_ad_widget.dart';
import 'tutorial_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(GameSettings) onStartGame;
  final Function(Locale) onLanguageChanged;
  final Function(GameSettings) onStartOnlineGame;
  final VoidCallback? onStartSimpleOnlineGame;

  const SettingsScreen({
    super.key,
    required this.onStartGame,
    required this.onLanguageChanged,
    required this.onStartOnlineGame,
    this.onStartSimpleOnlineGame,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late GameSettings _settings;
  final SoundService _soundService = SoundService();
  bool _showTutorial = false;
  bool _showAdvancedSettings = false;
  Locale _locale = const Locale('en');

  // プラットフォーム機能チェック
  bool get _isVibrationSupported => Platform.isAndroid || Platform.isIOS;

  // オーディオ設定
  bool _bgmEnabled = true;
  bool _sfxEnabled = true;
  bool _vibrationEnabled = true;
  double _bgmVolume = 0.3;
  double _sfxVolume = 0.8;

  @override
  void initState() {
    super.initState();
    _settings = GameSettings.defaultSettings;
    _loadSettingsAsync();
  }

  void _loadSettingsAsync() async {
    try {
      _locale = await I18nService.getCurrentLocale();

      // SoundService初期化完了を待つ
      await SoundService.initialize();

      // SoundServiceから設定を読み込み
      if (mounted) {
        setState(() {
          _bgmEnabled = _soundService.bgmEnabled;
          _sfxEnabled = _soundService.seEnabled;
          _vibrationEnabled = _soundService.vibrationEnabled;
          _bgmVolume = _soundService.bgmVolume;
          _sfxVolume = _soundService.seVolume;
        });

        // メニューBGMを確実に再生
        await _soundService.ensureMenuBgm();
      }
    } catch (e) {
      print('設定読み込みエラー: $e');
      // エラー時はデフォルト値を使用
      if (mounted) {
        setState(() {
          _bgmEnabled = true;
          _sfxEnabled = true;
          _vibrationEnabled = true;
          _bgmVolume = 0.3;
          _sfxVolume = 0.8;
        });
      }
    }
  }

  void _onDifficultyChanged(DifficultyLevel difficulty) {
    setState(() {
      _settings = _settings.copyWith(
        selectedDifficulty: difficulty,
        timeLimit: difficulty.timeLimit,
      );
    });
  }

  void _onMaxWinsChanged(int maxWins) {
    setState(() {
      _settings = _settings.copyWith(maxWins: maxWins);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showTutorial) {
      return TutorialScreen(
        onComplete: () => setState(() => _showTutorial = false),
        onSkip: () => setState(() => _showTutorial = false),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ヘッダー
                    Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  t('app.title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // 言語切り替え（国旗のみ）
              _buildLanguageFlags(),

              const SizedBox(height: 30),

              // チュートリアルボタン
              _buildTutorialButton(),

              const SizedBox(height: 20),

              // オンライン対戦ボタン（シンプル版ベース）
              if (widget.onStartSimpleOnlineGame != null)
                _buildMainOnlineGameButton(),

              const SizedBox(height: 16),

              // ゲーム開始ボタン
              _buildStartGameButton(),

              const SizedBox(height: 30),

              // 詳細設定トグル
              _buildAdvancedSettingsToggle(),

              // 詳細設定（折りたたみ式）
              if (_showAdvancedSettings) ..._buildAdvancedSettings(),
            ],
          ),
        ),
      ),
      _buildBottomBannerAd(),
    ],
        ),
      ),
    );
  }

  Widget _buildLanguageFlags() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLanguageFlag('🇺🇸', const Locale('en')),
        const SizedBox(width: 20),
        _buildLanguageFlag('🇯🇵', const Locale('ja')),
      ],
    );
  }

  Widget _buildLanguageFlag(String flag, Locale locale) {
    final isSelected = _locale == locale;
    return GestureDetector(
      onTap: () async {
        _soundService.playButtonClick();

        // I18nServiceの言語を変更
        await I18nService.setLanguage(locale.languageCode);

        setState(() {
          _locale = locale;
        });
        widget.onLanguageChanged(locale);
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.green : Colors.white.withOpacity(0.3),
            width: 3,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: Center(
          child: Text(
            flag,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          _soundService.playButtonClick();
          setState(() {
            _showTutorial = true;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          t('tutorial.title'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }


  Widget _buildStartGameButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          _soundService.playButtonClick();
          _showDifficultySelectionDialog(isOnlineMode: false);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          children: [
            Text(
              t('settings.cpuMode'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t('settings.wins', params: {'count': _settings.maxWins}),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettingsToggle() {
    return GestureDetector(
      onTap: () {
        _soundService.playButtonClick();
        setState(() {
          _showAdvancedSettings = !_showAdvancedSettings;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('settings.advancedSettings'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              _showAdvancedSettings ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAdvancedSettings() {
    return [
      const SizedBox(height: 20),
      // 勝利条件
      _buildSection(
        title: t('settings.winCondition'),
        child: Row(
          children: [1, 3, 5, 7].map((wins) {
            final isSelected = _settings.maxWins == wins;
            return Expanded(
              child: GestureDetector(
                onTap: () => _onMaxWinsChanged(wins),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    t('settings.wins', params: {'count': wins}),
                    style: TextStyle(
                      color: isSelected ? Colors.green : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      // オーディオ設定
      _buildSection(
        title: t('settings.audio'),
        child: Column(
          children: [
            // BGM設定
            _buildAudioOption(
              title: t('settings.bgm'),
              enabled: _bgmEnabled,
              volume: _bgmVolume,
              onToggle: (value) async {
                await _soundService.setBgmEnabled(value);
                setState(() {
                  _bgmEnabled = value;
                });
              },
              onVolumeChanged: (value) async {
                await _soundService.setBgmVolume(value);
                setState(() {
                  _bgmVolume = value;
                });
              },
            ),
            const SizedBox(height: 16),
            // SFX設定
            _buildAudioOption(
              title: t('settings.soundEffects'),
              enabled: _sfxEnabled,
              volume: _sfxVolume,
              onToggle: (value) async {
                await _soundService.setSeEnabled(value);
                setState(() {
                  _sfxEnabled = value;
                });
              },
              onVolumeChanged: (value) async {
                await _soundService.setSeVolume(value);
                setState(() {
                  _sfxVolume = value;
                });
              },
            ),
            const SizedBox(height: 16),
            // バイブレーション設定
            _buildVibrationOption(),
          ],
        ),
      ),
    ];
  }

  Widget _buildSection({
    required String title,
    String? description,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _buildAudioOption({
    required String title,
    required bool enabled,
    required double volume,
    required Future<void> Function(bool) onToggle,
    required Future<void> Function(double) onVolumeChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeColor: Colors.green,
                inactiveTrackColor: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.volume_down,
                  color: Colors.white,
                  size: 20,
                ),
                Expanded(
                  child: Slider(
                    value: volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    activeColor: Colors.green,
                    inactiveColor: Colors.white.withOpacity(0.3),
                    thumbColor: Colors.green,
                    onChanged: onVolumeChanged,
                  ),
                ),
                const Icon(
                  Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
            Center(
              child: Text(
                '${(volume * 100).round()}%',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVibrationOption() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.vibration,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('settings.vibration'),
                    style: TextStyle(
                      color: _isVibrationSupported ? Colors.white : Colors.white.withOpacity(0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!_isVibrationSupported)
                    Text(
                      '(${Platform.operatingSystem} not supported)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Switch(
            value: _vibrationEnabled && _isVibrationSupported,
            onChanged: _isVibrationSupported ? (value) async {
              await _soundService.setVibrationEnabled(value);
              setState(() {
                _vibrationEnabled = value;
              });
            } : null,
            activeColor: Colors.green,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Future<void> _showDifficultySelectionDialog({required bool isOnlineMode}) async {
    final selectedDifficulty = await showDialog<DifficultyLevel>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isOnlineMode ? t('settings.onlineMode') + ' ' + t('settings.timeLimitSetting') : t('settings.cpuMode') + ' ' + t('settings.timeLimitSetting'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Text(
                  t('settings.difficultyDescription'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ...DifficultyLevel.levels.map((difficulty) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _soundService.playButtonClick();
                          Navigator.of(context).pop(difficulty);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                difficulty.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t('difficulty.${difficulty.id}.name'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      t('settings.timeLimitSeconds', params: {'time': difficulty.timeLimit}),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      t('difficulty.${difficulty.id}.description'),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _soundService.playButtonClick();
                Navigator.of(context).pop();
              },
              child: Text(
                t('common.cancel'),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (selectedDifficulty != null) {
      // 選択された難易度でゲーム設定を更新
      final gameSettingsWithNewDifficulty = _settings.copyWith(
        selectedDifficulty: selectedDifficulty,
        timeLimit: selectedDifficulty.timeLimit,
        hapticFeedback: _vibrationEnabled,
        bgmEnabled: _bgmEnabled,
        soundEffects: _sfxEnabled,
        bgmVolume: _bgmVolume,
        seVolume: _sfxVolume,
      );

      if (isOnlineMode) {
        // オンラインモードの場合、選択された設定でオンラインロビーに遷移
        widget.onStartOnlineGame(gameSettingsWithNewDifficulty);
      } else {
        // オフラインモードの場合、ゲーム開始
        widget.onStartGame(gameSettingsWithNewDifficulty);
      }
    }
  }

  Widget _buildMainOnlineGameButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: ElevatedButton.icon(
        onPressed: () {
          _soundService.playButtonClick();
          widget.onStartSimpleOnlineGame?.call();
        },
        icon: const Icon(Icons.wifi),
        label: Text(
          t('settings.onlineMode'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildBottomBannerAd() {
    // iOSとAndroidでのみバナー広告を表示
    if (Platform.isIOS || Platform.isAndroid) {
      return const BannerAdWidget();
    }
    return const SizedBox.shrink();
  }
}