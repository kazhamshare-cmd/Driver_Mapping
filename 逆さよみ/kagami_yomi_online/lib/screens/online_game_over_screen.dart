import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/game_room.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';

class OnlineGameOverScreen extends StatefulWidget {
  final String roomId;
  final String playerId;
  final bool isHost;

  const OnlineGameOverScreen({
    super.key,
    required this.roomId,
    required this.playerId,
    required this.isHost,
  });

  @override
  State<OnlineGameOverScreen> createState() => _OnlineGameOverScreenState();
}

class _OnlineGameOverScreenState extends State<OnlineGameOverScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isAdShown = false;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdService().interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  Future<void> _showInterstitialAdIfNeeded(bool shouldShow) async {
    if (shouldShow && _isAdLoaded && !_isAdShown && _interstitialAd != null) {
      setState(() {
        _isAdShown = true;
      });

      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('Failed to show interstitial ad: $error');
          ad.dispose();
        },
      );

      await _interstitialAd!.show();
    }
  }

  Future<void> _playAgain() async {
    SoundService().playClick();
    await _firebaseService.restartGame(widget.roomId);
  }

  Future<void> _leaveRoom() async {
    SoundService().playClick();

    if (widget.isHost) {
      await _firebaseService.deleteRoom(widget.roomId);
    } else {
      await _firebaseService.leaveRoom(
        roomId: widget.roomId,
        playerId: widget.playerId,
      );
    }

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ゲーム結果',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            // BGM切り替えボタン
            IconButton(
              icon: Icon(
                SoundService().bgmEnabled ? Icons.music_note : Icons.music_off,
              ),
              onPressed: () {
                setState(() {
                  SoundService().toggleBgm();
                });
              },
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) {
              // ルームが削除された
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              });
              return const Center(child: Text('ルームが削除されました'));
            }

            final room = GameRoom.fromMap(data);

            // プレイヤーが1人しかいない場合（ホストのみ）
            if (room.players.length < 2) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.deepPurple.shade300,
                      Colors.deepPurple.shade700,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person_off,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '対戦相手がいません',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '他のプレイヤーが退出しました',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () async {
                          SoundService().playClick();
                          if (widget.isHost) {
                            await _firebaseService.deleteRoom(widget.roomId);
                          }
                          if (mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          'メニューに戻る',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 広告を表示（初回のみ、全員で同期）
            if (room.showInterstitialAd && !_isAdShown) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showInterstitialAdIfNeeded(true);
              });
            }

            // ゲームが再開された場合
            if (room.status == RoomStatus.playing) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              });
            }

            // スコアでソート（降順）
            final sortedPlayers = List.from(room.players)
              ..sort((a, b) => b.score.compareTo(a.score));

            final winner = sortedPlayers.first;
            final isWinner = winner.id == widget.playerId;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isWinner ? Colors.amber.shade300 : Colors.deepPurple.shade300,
                    isWinner ? Colors.amber.shade700 : Colors.deepPurple.shade700,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const SizedBox(height: 32),

                            // 優勝者
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.emoji_events,
                                    size: 64,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '優勝',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    winner.name,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${winner.score}点',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 最終結果
                            const Text(
                              '最終結果',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),

                            ...sortedPlayers.asMap().entries.map((entry) {
                              final index = entry.key;
                              final player = entry.value;
                              final isCurrentPlayer =
                                  player.id == widget.playerId;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isCurrentPlayer
                                      ? Colors.deepPurple.shade100
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrentPlayer
                                        ? Colors.deepPurple
                                        : Colors.grey.shade300,
                                    width: isCurrentPlayer ? 3 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: index == 0
                                            ? Colors.amber
                                            : index == 1
                                                ? Colors.grey.shade400
                                                : Colors.brown.shade300,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        player.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${player.score}点',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    // ボタンエリア
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            offset: const Offset(0, -2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: widget.isHost
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.green,
                                          Color.fromARGB(255, 56, 142, 60)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.3),
                                          offset: const Offset(0, 4),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _playAgain,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        minimumSize:
                                            const Size(double.infinity, 0),
                                      ),
                                      child: const Text(
                                        'もう一度遊ぶ',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: _leaveRoom,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(
                                          color: Colors.red, width: 2),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      minimumSize: const Size(double.infinity, 0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '終了',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.orange,
                                          Color.fromARGB(255, 239, 108, 0)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withOpacity(0.3),
                                          offset: const Offset(0, 4),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _leaveRoom,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        minimumSize:
                                            const Size(double.infinity, 0),
                                      ),
                                      child: const Text(
                                        'ルームから退出',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
