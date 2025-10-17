import 'package:flutter/material.dart';
import '../services/i18n_service.dart';
import '../services/sound_service.dart';

class TutorialScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const TutorialScreen({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4;
  late AnimationController _iconAnimationController;
  late Animation<double> _iconScaleAnimation;
  final SoundService _soundService = SoundService();

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _iconScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _iconAnimationController,
      curve: Curves.easeInOut,
    ));
    _iconAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            // ヘッダー
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      _soundService.playButtonClick();
                      widget.onSkip();
                    },
                    child: Text(
                      t('tutorial.skip'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '${_currentPage + 1} / $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _soundService.playButtonClick();
                      widget.onSkip();
                    },
                    child: Text(
                      t('tutorial.skip'),
                      style: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // チュートリアルコンテンツ
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildTutorialPage(
                    title: t('tutorial.page1.title'),
                    description: t('tutorial.page1.description'),
                    icon: Icons.sports_esports,
                    color: Colors.blue,
                  ),
                  _buildTutorialPage(
                    title: t('tutorial.page2.title'),
                    description: t('tutorial.page2.description'),
                    showImage: 'assets/images/cage.png',
                    color: Colors.green,
                    animated: true,
                  ),
                  _buildTutorialPage(
                    title: t('tutorial.page3.title'),
                    description: t('tutorial.page3.description'),
                    showImage: 'assets/images/bell.png',
                    color: Colors.red,
                    animated: true,
                  ),
                  _buildTutorialPage(
                    title: t('tutorial.page4.title'),
                    description: t('tutorial.page4.description'),
                    icon: Icons.emoji_events,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),

            // ページインジケーター
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.green
                          : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // ナビゲーションボタン
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 戻るボタン
                  SizedBox(
                    width: 100,
                    child: _currentPage > 0
                        ? ElevatedButton(
                            onPressed: () {
                              _soundService.playButtonClick();
                              _previousPage();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              t('tutorial.back'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : const SizedBox(),
                  ),

                  // 次へ/完了ボタン
                  ElevatedButton(
                    onPressed: () {
                      _soundService.playButtonClick();
                      _nextPage();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _currentPage == _totalPages - 1
                          ? t('tutorial.complete')
                          : t('tutorial.next'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialPage({
    required String title,
    required String description,
    IconData? icon,
    required Color color,
    bool animated = false,
    String? emoji,
    bool showBox = false,
    String? showImage,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // アイコン
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
              border: Border.all(color: color, width: 3),
            ),
            child: showImage != null
                ? Center(
                    child: animated
                        ? AnimatedBuilder(
                            animation: _iconScaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _iconScaleAnimation.value,
                                child: Image.asset(
                                  showImage,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                              );
                            },
                          )
                        : Image.asset(
                            showImage,
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                  )
                : emoji != null
                ? Center(
                    child: showBox
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 45,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                              Text(
                                emoji,
                                style: const TextStyle(fontSize: 30),
                              ),
                            ],
                          )
                        : animated
                            ? AnimatedBuilder(
                                animation: _iconScaleAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _iconScaleAnimation.value,
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 60),
                                    ),
                                  );
                                },
                              )
                            : Text(
                                emoji,
                                style: const TextStyle(fontSize: 60),
                              ),
                  )
                : animated
                    ? AnimatedBuilder(
                        animation: _iconScaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _iconScaleAnimation.value,
                            child: Icon(
                              icon!,
                              size: 60,
                              color: color,
                            ),
                          );
                        },
                      )
                    : Icon(
                        icon!,
                        size: 60,
                        color: color,
                      ),
          ),

          const SizedBox(height: 40),

          // タイトル
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // 説明
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}