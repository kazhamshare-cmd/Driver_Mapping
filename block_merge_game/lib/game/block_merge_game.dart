import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'components/game_block.dart';
import 'components/game_grid.dart';
import 'utils/block_color.dart';

class BlockMergeGame extends Forge2DGame with TapCallbacks, DragCallbacks, ContactCallbacks {
  static const int gridColumns = 7;  // 8 → 7に変更
  static const int gridRows = 12;    // 13 → 12に変更（上部に移動ボールエリア、下部にアイテムエリア確保）

  // 画面サイズに合わせて動的に計算
  late double blockSize;
  late Vector2 gridOffset;

  late GameGrid gameGrid;
  final List<List<GameBlock?>> grid = List.generate(
    gridRows,
    (_) => List.generate(gridColumns, (_) => null),
  );

  // ゲーム状態
  int score = 0;
  int level = 1;
  bool isGameOver = false;

  // コンボシステム
  int combo = 0;
  double comboTimer = 0;
  static const double comboResetTime = 3.0;

  // 消去アニメーション
  List<GameBlock> blocksToRemove = [];
  double blinkDuration = 0;
  static const double totalBlinkDuration = 1.0;

  // ドラッグ中のブロック
  GameBlock? draggedBlock;
  Vector2? dragStartPosition;

  // ゲームタイマー
  double gameStartTimer = 0; // ゲーム開始からの経過時間（初期配置の安定待機用）
  bool initialMatchCheckDone = false; // 初期配置後の接続判定完了フラグ

  // ドラッグ速度計算用（履歴を保持）
  final List<({double time, Vector2 position})> dragHistory = [];

  // ゲームモード
  bool isBilliardMode = false; // ビリヤードモードかどうか

  // ビリヤードモード用
  int totalBalls = 0; // 総ボール数
  int remainingBalls = 0; // 残りボール数
  int targetBalls = 10; // 目標ボール数（これ以下でクリア）
  int currentStage = 1; // 現在のステージ
  double allStoppedTimer = 0; // 全ボール停止時間
  bool isGravityBoostActive = false; // 重力ブースト中か
  bool isStageClear = false; // ステージクリアフラグ

  // 下部スポーンシステム
  List<GameBlock> bottomSpawnBalls = [];

  // 衝突検出用タイマー
  double collisionCheckTimer = 0;
  static const double collisionCheckDelay = 0.15; // 衝突後0.15秒で判定
  bool collisionDetected = false; // 衝突が発生したかのフラグ

  // 定期的な接続判定用タイマー
  double periodicCheckTimer = 0;
  static const double periodicCheckInterval = 1.0; // 1秒ごとに判定

  // スポーンボールは常に1個のみ
  int get maxSpawnBalls => 1;
  int get minSpawnBalls => 1;

  // UIコンポーネント
  late TextComponent scoreText;
  late TextComponent levelText;
  late TextComponent comboText;
  late RectangleComponent background;

  // ビリヤードモード専用UI
  TextComponent? remainingBallsText;
  TextComponent? stageText;

  BlockMergeGame() : super(
    gravity: Vector2(0, -50), // 逆重力（上向き）- バランス調整済み
  );

  // ビリヤードモード用のコンストラクタ
  BlockMergeGame.billiardMode() : super(
    gravity: Vector2(0, 0), // 重力なし
  ) {
    isBilliardMode = true;
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    // 画面サイズを取得してブロックサイズを計算
    final screenWidth = camera.viewport.size.x;
    final screenHeight = camera.viewport.size.y;

    // 画面幅いっぱいにグリッドを表示（左右に少し余白）
    const padding = 20.0;
    const topSafeArea = 60.0; // セーフエリア（時計やノッチを考慮）
    const uiHeight = 80.0; // UI表示エリア
    const bottomSpawnArea = 80.0; // 下部スポーンエリア

    blockSize = (screenWidth - padding * 2) / gridColumns;
    // 下部にスポーンエリアを確保するため、グリッドを上に配置
    gridOffset = Vector2(padding, topSafeArea + uiHeight);

    // 背景色を設定（一番後ろに描画）
    background = RectangleComponent(
      size: Vector2(screenWidth, screenHeight),
      paint: Paint()..color = const Color(0xFF1A1A2E),
      priority: -100, // 最背面に描画
    );
    add(background);

    gameGrid = GameGrid(
      columns: gridColumns,
      rows: gridRows,
      blockSize: blockSize,
    );
    gameGrid.position = gridOffset;
    add(gameGrid);

    // UIを上部に横並びで配置（セーフエリアを考慮）
    const uiTop = topSafeArea + 10;

    scoreText = TextComponent(
      text: 'Score: $score',
      position: Vector2(20, uiTop),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(scoreText);

    levelText = TextComponent(
      text: 'Level: $level',
      position: Vector2(20, uiTop + 30),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(levelText);

    comboText = TextComponent(
      text: '',
      position: Vector2(screenWidth - 150, uiTop + 15),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFA500),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(comboText);

    // ビリヤードモード専用UI
    if (isBilliardMode) {
      stageText = TextComponent(
        text: 'Stage: $currentStage',
        position: Vector2(screenWidth / 2 - 60, uiTop),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF00FF00),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      add(stageText!);

      remainingBallsText = TextComponent(
        text: 'Balls: $remainingBalls / $targetBalls',
        position: Vector2(screenWidth / 2 - 80, uiTop + 30),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      add(remainingBallsText!);
    }

    _createGround();
    _createSpawnArea(screenHeight); // 下部にスポーンエリアを作成
    _createInitialBlocks(); // 初期ボール配置
    _spawnInitialBalls(); // 初期スポーンボールを生成

    // ビリヤードモード：初期ボール数を設定
    if (isBilliardMode) {
      _updateBallCount();
    }
  }

  // 下部にスポーンエリアを作成
  void _createSpawnArea(double screenHeight) {
    final spawnAreaHeight = 100.0;
    final spawnAreaY = gridOffset.y + gridRows * blockSize + 10; // グリッドの下に配置

    final spawnAreaBackground = RectangleComponent(
      position: Vector2(gridOffset.x, spawnAreaY),
      size: Vector2(gridColumns * blockSize, spawnAreaHeight),
      paint: Paint()..color = const Color(0xFF34495e).withValues(alpha: 0.9),
    );
    add(spawnAreaBackground);
  }

  // 初期スポーンボールを生成（1個のみ）
  void _spawnInitialBalls() {
    _spawnNewBall();
  }

  // 最小数のスポーンボールを維持
  void _maintainMinimumSpawnBalls() {
    while (bottomSpawnBalls.length < minSpawnBalls && bottomSpawnBalls.length < maxSpawnBalls) {
      _spawnNewBall();
    }
  }

  // 新しいボールをスポーン
  void _spawnNewBall() {
    if (bottomSpawnBalls.length >= maxSpawnBalls) return;

    final random = Random();
    final ballColors = BlockColor.getAvailableColors(level);

    // ランダムな位置を決定（下部スポーンエリア内）
    final spawnX = random.nextInt(gridColumns);
    final spawnY = gridRows; // グリッドの下

    // 色の抽選（優先度順）
    BlockColor color;
    if (random.nextInt(200) == 0) {
      // 1/200の確率で虹色
      color = BlockColor.rainbow;
      print('🌈 虹色ボールがスポーン！');
    } else if (random.nextInt(50) == 0) {
      // 1/50の確率で黒（障害物）
      color = BlockColor.black;
      print('⚫ 黒ボールがスポーン！');
    } else if (random.nextInt(20) == 0) {
      // 1/20の確率で灰色（障害物）
      color = BlockColor.grey;
      print('⚫ 灰色ボールがスポーン！');
    } else {
      // 通常の色
      color = BlockColor.randomFromList(ballColors);
    }

    final ball = GameBlock(
      blockColor: color,
      gridX: spawnX,
      gridY: spawnY,
      gridOffset: gridOffset,
      blockSize: blockSize,
      bodyType: BodyType.static, // 固定
    );

    ball.isSpawnBall = true;

    add(ball);
    bottomSpawnBalls.add(ball);

    print('⚡ ボールスポーン: ${color.name} at ($spawnX, $spawnY)');
  }

  // ボールを自動発射（カウントダウンが0になった時）
  void _autoFireBall(GameBlock ball) {
    if (!ball.isMounted) return;

    final random = Random();

    // ランダムな方向に発射（上向きのみ：1度〜179度）
    // Forge2Dの座標系では 0度=右、90度=上、180度=左
    // 1〜179度に限定（真横を除外）
    final angle = (1 + random.nextDouble() * 178) * (pi / 180); // 1〜179度をラジアンに変換

    // 基本速度（80〜350の広い範囲でメリハリをつける）
    final baseSpeed = 80.0 + random.nextDouble() * 270.0;

    // 色ごとの速度倍率
    double speedMultiplier = 1.0;
    if (ball.blockColor == BlockColor.yellow) {
      // 黄色（小さい）は速い
      speedMultiplier = 1.3 + random.nextDouble() * 0.2; // 1.3〜1.5倍
    } else if (ball.blockColor == BlockColor.white) {
      // 白（大きい）は遅い
      speedMultiplier = 0.7 + random.nextDouble() * 0.1; // 0.7〜0.8倍
    }

    final speed = baseSpeed * speedMultiplier;

    final velocity = Vector2(
      speed * cos(angle),
      speed * sin(angle), // 1〜179度なので常に正の値（上向き）
    );

    // Dynamicに変更して速度を適用
    ball.body.setType(BodyType.dynamic);
    ball.body.linearVelocity = velocity;
    ball.isSpawnBall = false; // スポーンボールフラグを解除

    // リストから削除
    bottomSpawnBalls.remove(ball);

    print('🚀 ボール自動発射: ${ball.blockColor.name}, 角度: ${(angle * 180 / pi).toStringAsFixed(1)}度, 速度: ${speed.toStringAsFixed(1)} (倍率: ${speedMultiplier.toStringAsFixed(2)}x)');

    // 発射後、即座に新しいボールを補充（最小数を維持）
    _maintainMinimumSpawnBalls();
  }

  // ボールをフリック発射（ユーザーがスワイプした時）
  void _flickFireBall(GameBlock ball, Vector2 velocity) {
    if (!ball.isMounted) return;

    // 色ごとの速度倍率を適用
    double speedMultiplier = 1.0;
    if (ball.blockColor == BlockColor.yellow) {
      // 黄色（小さい）は速い
      speedMultiplier = 1.4;
    } else if (ball.blockColor == BlockColor.white) {
      // 白（大きい）は遅い
      speedMultiplier = 0.75;
    }

    // 速度に倍率を適用
    final adjustedVelocity = velocity * speedMultiplier;

    // Dynamicに変更して速度を適用
    ball.body.setType(BodyType.dynamic);
    ball.body.linearVelocity = adjustedVelocity;
    ball.isSpawnBall = false; // スポーンボールフラグを解除

    // リストから削除
    bottomSpawnBalls.remove(ball);

    print('💨 ボールフリック発射: ${ball.blockColor.name}, 速度: ${adjustedVelocity.length.toStringAsFixed(1)} (倍率: ${speedMultiplier.toStringAsFixed(2)}x)');

    // 発射後、即座に新しいボールを補充（最小数を維持）
    _maintainMinimumSpawnBalls();
  }

  // 初期状態で20個のボールをランダムに配置
  void _createInitialBlocks() {
    final ballColors = BlockColor.getAvailableColors(level);
    final random = Random();

    print('🎮 ゲーム開始: 初期ブロック20個を生成');
    print('   グリッドサイズ: $gridColumns列 x $gridRows行');

    for (int i = 0; i < 20; i++) {
      // ランダムな列を選択
      final x = random.nextInt(gridColumns);
      // 下半分に配置（ゲームオーバー判定を避けるため）
      final y = (gridRows ~/ 2) + random.nextInt(gridRows ~/ 2);

      if (i == 0) {
        print('   配置範囲: 行${gridRows ~/ 2}〜${gridRows - 1}');
      }

      final block = GameBlock(
        blockColor: BlockColor.randomFromList(ballColors),
        gridX: x,
        gridY: y,
        gridOffset: gridOffset,
        blockSize: blockSize,
      );
      add(block);

      // 少し遅延してから追加することで、自然に落下する
      Future.delayed(Duration(milliseconds: i * 50), () {
        // ブロックは既に追加されているので、物理エンジンが自動的に処理
      });
    }

    print('✅ 初期ブロック生成完了');
  }

  void _createGround() {
    final ceilingY = gridOffset.y;
    final spawnAreaHeight = 100.0; // スポーンエリアの高さ
    final groundY = gridOffset.y + gridRows * blockSize + spawnAreaHeight; // スポーンエリアの底

    // 地面（スポーンエリアの底）
    final groundBody = world.createBody(BodyDef(position: Vector2(gridOffset.x, groundY)));
    final groundShape = EdgeShape()..set(Vector2(0, 0), Vector2(gridColumns * blockSize, 0));
    groundBody.createFixture(FixtureDef(groundShape, friction: 0.4, restitution: 0.3));

    // 天井（上部）- ボールが上面を超えないように
    final ceilingBody = world.createBody(BodyDef(position: Vector2(gridOffset.x, ceilingY)));
    final ceilingShape = EdgeShape()..set(Vector2(0, 0), Vector2(gridColumns * blockSize, 0));
    ceilingBody.createFixture(FixtureDef(ceilingShape, friction: 0.4, restitution: 0.3));

    // 左壁（スポーンエリアまで延長）
    final totalHeight = gridRows * blockSize + spawnAreaHeight;
    final leftWall = world.createBody(BodyDef(position: Vector2(gridOffset.x, ceilingY)));
    final leftWallShape = EdgeShape()..set(Vector2(0, 0), Vector2(0, totalHeight));
    leftWall.createFixture(FixtureDef(leftWallShape, friction: 0.4, restitution: 0.3));

    // 右壁（スポーンエリアまで延長）
    final rightWall = world.createBody(BodyDef(position: Vector2(gridOffset.x + gridColumns * blockSize, ceilingY)));
    final rightWallShape = EdgeShape()..set(Vector2(0, 0), Vector2(0, totalHeight));
    rightWall.createFixture(FixtureDef(rightWallShape, friction: 0.4, restitution: 0.3));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) return;

    // ゲーム開始からの経過時間を更新
    gameStartTimer += dt;

    // 初期配置後の接続判定（ゲーム開始3秒後に1回だけ強制実行）
    if (!initialMatchCheckDone && gameStartTimer >= 3.0) {
      print('🔍 初期配置の接続判定を実行');
      _checkForMatches();
      initialMatchCheckDone = true;
    }

    // ビリヤードモードの場合
    if (isBilliardMode) {
      _updateBilliardMode(dt);
    } else {
      // 通常モード：スポーンボールが0個になったら即座に補充
      if (bottomSpawnBalls.isEmpty) {
        _spawnNewBall();
      }
    }

    // コンボタイマー
    if (combo > 0) {
      comboTimer += dt;
      if (comboTimer >= comboResetTime) {
        combo = 0;
        comboText.text = '';
      }
    }

    // 点滅アニメーション
    if (blocksToRemove.isNotEmpty) {
      blinkDuration += dt;
      if (blinkDuration >= totalBlinkDuration) {
        _executeRemoval();
        blinkDuration = 0;
      }
      return; // アニメーション中は他の処理をスキップ
    }

    // ブロックをグリッドに同期
    _syncBlocksToGrid();

    // 灰色ブロックの固定チェック
    _checkGreyBlocksFixing();

    // 衝突検出後の接続チェック
    if (collisionDetected) {
      collisionCheckTimer += dt;
      // 衝突後0.15秒経過したら接続判定
      if (collisionCheckTimer >= collisionCheckDelay) {
        _checkForMatches();
        collisionCheckTimer = 0; // タイマーリセット
        collisionDetected = false; // フラグリセット
      }
    }

    // 定期的な接続判定（1秒ごと）
    periodicCheckTimer += dt;
    if (periodicCheckTimer >= periodicCheckInterval) {
      _checkForMatches();
      periodicCheckTimer = 0;
    }

    // 移動可能ブロックの更新
    _updateMovableBlocks();

    // ゲームオーバーチェック
    _checkGameOver();
  }

  // 衝突検出（ContactCallbacks mixin）
  @override
  void beginContact(Object other, Contact contact) {
    super.beginContact(other, contact);

    // ゲーム開始直後（3秒間）は衝突検出をスキップ
    if (gameStartTimer < 3.0) return;

    // GameBlock同士の衝突を検出
    final fixtureA = contact.fixtureA;
    final fixtureB = contact.fixtureB;

    final bodyA = fixtureA.body.userData;
    final bodyB = fixtureB.body.userData;

    if (bodyA is GameBlock && bodyB is GameBlock) {
      // スポーンボールの衝突は除外
      if (bodyA.isSpawnBall || bodyB.isSpawnBall) return;

      // 衝突を検出したのでフラグを立てる
      if (!collisionDetected) {
        collisionDetected = true;
        collisionCheckTimer = 0; // タイマーリセット
        print('💥 ボール衝突検出: ${bodyA.blockColor.name} + ${bodyB.blockColor.name}');
      }
    }
  }

  // 黒・灰色ブロックの衝突判定と固定
  void _checkGreyBlocksFixing() {
    // ゲーム開始直後（3秒間）は黒・灰色ボールの固定処理をスキップ
    if (gameStartTimer < 3.0) return;

    for (var block in children.whereType<GameBlock>()) {
      if (block.blockColor != BlockColor.grey && block.blockColor != BlockColor.black) continue;
      if (block.isFixed) continue;
      if (!block.isMounted) continue;
      if (block.isSpawnBall) continue; // スポーンボールは除外

      final worldPos = block.body.position;
      final localY = worldPos.y - gridOffset.y;
      final velocity = block.body.linearVelocity;

      // 天井付近（グリッドの上端）にいて、かつ下向きの速度がある場合
      // = 天井に衝突して跳ね返った直後
      if (localY < blockSize * 1.5 && velocity.y > 10.0) {
        // 天井に衝突したので即座に固定
        block.isFixed = true;
        block.body.setType(BodyType.static);
        print('🔒 灰色ボール固定: 天井衝突 at Y=${localY.toStringAsFixed(1)}');
        continue;
      }

      // または、他のブロックに衝突して静止した場合も固定
      if (velocity.length < 2.0) {
        // 他のブロックに接触しているかチェック
        bool isTouching = false;
        for (var otherBlock in children.whereType<GameBlock>()) {
          if (otherBlock == block) continue;
          if (!otherBlock.isMounted) continue;
          if (otherBlock.isSpawnBall) continue; // スポーンボールは除外

          final distance = block.body.position.distanceTo(otherBlock.body.position);
          if (distance < blockSize * 1.5) {
            isTouching = true;
            break;
          }
        }

        if (isTouching) {
          // 固定する
          block.isFixed = true;
          block.body.setType(BodyType.static);
          print('🔒 灰色ボール固定: ブロック衝突');
        }
      }
    }
  }

  void _syncBlocksToGrid() {
    for (var block in children.whereType<GameBlock>()) {
      // ドラッグ中のブロックとスポーンボールはスキップ
      if (block == draggedBlock || block.isSpawnBall) continue;

      // まだワールドに追加されていない場合はスキップ
      if (!block.isMounted) continue;

      final worldPos = block.body.position;
      final gridPos = _worldToGrid(worldPos - gridOffset);

      if (gridPos != null) {
        int gx = gridPos.x.toInt();
        int gy = gridPos.y.toInt();

        if (gx >= 0 && gx < gridColumns && gy >= 0 && gy < gridRows) {
          if (grid[gy][gx] != block) {
            // 古い位置をクリア
            for (int y = 0; y < gridRows; y++) {
              for (int x = 0; x < gridColumns; x++) {
                if (grid[y][x] == block) {
                  grid[y][x] = null;
                }
              }
            }
            // 新しい位置に配置
            if (grid[gy][gx] == null) {
              grid[gy][gx] = block;
            }
          }
        }
      }
    }
  }

  Vector2? _worldToGrid(Vector2 worldPos) {
    if (worldPos.x < 0 || worldPos.y < 0) return null;
    return Vector2(worldPos.x / blockSize, worldPos.y / blockSize);
  }

  void _checkForMatches() {
    final List<Set<GameBlock>> matchedGroups = [];
    final Set<GameBlock> visited = {};

    // すべてのブロックに対して接続チェック
    for (int y = 0; y < gridRows; y++) {
      for (int x = 0; x < gridColumns; x++) {
        final block = grid[y][x];
        if (block == null) continue;
        if (visited.contains(block)) continue;

        // 接続されたブロックのグループを取得（flood-fill）
        final group = _findConnectedBlocks(block, x, y, visited);

        // グループに虹色が含まれている場合は2個以上で消える
        // 通常の色のみの場合は3個以上で消える
        final hasRainbow = group.any((b) => b.blockColor == BlockColor.rainbow);
        final minSize = hasRainbow ? 2 : 3;

        // 4倍紫がグループに含まれているかチェック
        final hasMegaPurple = group.any((b) =>
          b.blockColor == BlockColor.purple && b.sizeMultiplier == 4
        );

        // 4倍紫は虹色がグループに含まれている場合のみ消える
        if (hasMegaPurple && !hasRainbow) {
          print('⚡ 4倍紫は虹色でしか消せません！グループをスキップ');
          continue; // このグループはスキップ
        }

        if (group.length >= minSize) {
          matchedGroups.add(group);
        }
      }
    }

    // デバッグ: 検出されたグループを出力
    if (matchedGroups.isNotEmpty) {
      print('🔍 検出されたグループ数: ${matchedGroups.length}');
      for (int i = 0; i < matchedGroups.length; i++) {
        final group = matchedGroups[i];
        final colors = group.map((b) => b.blockColor.name).toSet().join('+');
        final hasMega = group.any((b) => b.blockColor == BlockColor.purple && b.sizeMultiplier == 4);
        print('   グループ${i + 1}: $colors × ${group.length}個${hasMega ? " (4倍紫含む)" : ""}');
      }
    }

    // 全てのグループを同時に消去
    if (matchedGroups.isNotEmpty) {
      final allBlocksToRemove = <GameBlock>{};
      for (var group in matchedGroups) {
        allBlocksToRemove.addAll(group);
      }
      _startRemovalAnimation(allBlocksToRemove.toList());
    }
  }

  // Flood-fillで接続されたボールを検出
  Set<GameBlock> _findConnectedBlocks(GameBlock startBlock, int startX, int startY, Set<GameBlock> visited) {
    final Set<GameBlock> group = {};
    final List<Vector2> toCheck = [Vector2(startX.toDouble(), startY.toDouble())];
    final targetColor = startBlock.blockColor;

    while (toCheck.isNotEmpty) {
      final pos = toCheck.removeLast();
      final x = pos.x.toInt();
      final y = pos.y.toInt();

      if (x < 0 || x >= gridColumns || y < 0 || y >= gridRows) continue;

      final block = grid[y][x];
      if (block == null || group.contains(block)) continue;
      if (visited.contains(block)) continue;

      // 色が一致するか（虹色も考慮）
      if (!block.blockColor.canMergeWith(targetColor)) continue;

      // 物理的な接触をチェック
      if (group.isNotEmpty && !_isPhysicallyTouching(block, group)) continue;

      group.add(block);
      visited.add(block); // すべてのブロックをvisitedに追加

      // 周囲8方向をチェック（対角線も含む）
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          toCheck.add(Vector2((x + dx).toDouble(), (y + dy).toDouble()));
        }
      }
    }

    return group;
  }

  // 2つのボールが物理的に接触しているかチェック
  bool _isPhysicallyTouching(GameBlock block, Set<GameBlock> group) {
    // ブロックがまだワールドに追加されていない場合はスキップ
    if (!block.isMounted) return false;

    final blockPos = block.body.position;

    for (var otherBlock in group) {
      if (!otherBlock.isMounted) continue;

      final otherPos = otherBlock.body.position;
      final distance = blockPos.distanceTo(otherPos);

      // サイズ倍率を考慮した半径計算
      double blockMultiplier = block.sizeMultiplier.toDouble();
      if (block.blockColor == BlockColor.white) {
        blockMultiplier = 1.2;
      } else if (block.blockColor == BlockColor.yellow) {
        blockMultiplier = 0.8;
      }

      double otherMultiplier = otherBlock.sizeMultiplier.toDouble();
      if (otherBlock.blockColor == BlockColor.white) {
        otherMultiplier = 1.2;
      } else if (otherBlock.blockColor == BlockColor.yellow) {
        otherMultiplier = 0.8;
      }

      final blockRadius = (blockSize * blockMultiplier) / 2;
      final otherRadius = (blockSize * otherMultiplier) / 2;

      // 2つのボールの半径の合計 + 余裕（15%増加 = 1.15倍）
      // 物理演算で少し離れていても視覚的に接触して見える場合を考慮
      final touchDistance = (blockRadius + otherRadius) * 1.15;

      // 物理的な距離で判定
      if (distance <= touchDistance) {
        return true;
      }

      // グリッドベースの補助判定（物理的に離れていてもグリッド上で隣接していれば接続）
      final blockGridPos = _worldToGrid(blockPos - gridOffset);
      final otherGridPos = _worldToGrid(otherPos - gridOffset);

      if (blockGridPos != null && otherGridPos != null) {
        final gridDx = (blockGridPos.x - otherGridPos.x).abs();
        final gridDy = (blockGridPos.y - otherGridPos.y).abs();

        // グリッド上で隣接している（8方向）
        if (gridDx <= 1 && gridDy <= 1 && (gridDx + gridDy) > 0) {
          return true;
        }
      }
    }
    return false;
  }

  void _startRemovalAnimation(List<GameBlock> blocks) {
    // 虹色ボールが含まれているかチェック
    bool hasRainbow = blocks.any((b) => b.blockColor == BlockColor.rainbow);

    // 紫色の場合は合体処理（虹色が含まれていない場合のみ）
    if (blocks.isNotEmpty && blocks.first.blockColor == BlockColor.purple && !hasRainbow) {
      _mergePurpleBlocks(blocks);
      return;
    }

    blocksToRemove = blocks;

    // デバッグ: 消去対象のブロックを出力
    print('💥 消去対象: ${blocks.length}個の${blocks.first.blockColor.name}ブロック');
    for (var block in blocks) {
      if (block.isMounted) {
        final pos = block.body.position;
        final gridPos = _worldToGrid(pos - gridOffset);
        print('   - 色: ${block.blockColor.name}, 位置: (${gridPos?.x.toInt()}, ${gridPos?.y.toInt()})');
      }
    }

    // まず全てのブロックの点滅を停止
    for (var block in children.whereType<GameBlock>()) {
      if (block.isSpawnBall) continue;
      block.isBlinking = false;
      block.isVisible = true;
    }

    // 消去対象のブロックのみ点滅させる
    for (var block in blocks) {
      block.isBlinking = true;
    }
  }

  // 紫の合体処理
  void _mergePurpleBlocks(List<GameBlock> blocks) {
    if (blocks.length < 3) return;

    // サイズ倍率が同じブロックのみをグループ化
    final Map<int, List<GameBlock>> sizeGroups = {};
    for (var block in blocks) {
      sizeGroups.putIfAbsent(block.sizeMultiplier, () => []).add(block);
    }

    // 各サイズグループごとに処理
    for (var entry in sizeGroups.entries) {
      final size = entry.key;
      final group = entry.value;

      // 3個以上で合体可能
      if (group.length >= 3) {
        // 合体個数（3個単位）
        final mergeCount = group.length ~/ 3;

        for (int i = 0; i < mergeCount; i++) {
          // 3個を取り出す
          final mergeBlocks = group.sublist(i * 3, (i + 1) * 3);

          // 中心位置を計算
          final centerPos = mergeBlocks.fold(
            Vector2.zero(),
            (sum, block) => sum + block.body.position,
          ) / mergeBlocks.length.toDouble();

          // 新しいサイズ倍率
          final newSize = size == 1 ? 2 : 4; // 1→2, 2→4

          // 3つのブロックを削除
          for (var block in mergeBlocks) {
            // グリッドから削除
            for (int y = 0; y < gridRows; y++) {
              for (int x = 0; x < gridColumns; x++) {
                if (grid[y][x] == block) {
                  grid[y][x] = null;
                }
              }
            }
            remove(block);
            world.destroyBody(block.body);
          }

          // 新しい大きいブロックを生成
          final gridPos = _worldToGrid(centerPos - gridOffset);
          if (gridPos != null) {
            final newBlock = GameBlock(
              blockColor: BlockColor.purple,
              gridX: gridPos.x.toInt(),
              gridY: gridPos.y.toInt(),
              gridOffset: gridOffset,
              blockSize: blockSize,
              sizeMultiplier: newSize,
            );
            add(newBlock);

            // 少し遅延してから位置を設定（物理演算が始まってから）
            Future.delayed(const Duration(milliseconds: 50), () {
              if (newBlock.isMounted) {
                newBlock.body.setTransform(centerPos, 0);
              }
            });
          }
        }

        // コンボ処理
        combo++;
        comboTimer = 0;
        if (combo > 1) {
          comboText.text = 'COMBO x$combo!';
        }

        // スコア加算（合体数 × 30 × サイズ倍率 × コンボ）
        int baseScore = mergeCount * 30 * size;
        int totalScore = baseScore * combo;
        score += totalScore;
        scoreText.text = 'Score: $score';

        // レベルアップチェック
        int newLevel = (score ~/ 500) + 1;
        if (newLevel > level) {
          level = newLevel;
          levelText.text = 'Level: $level';
        }
      }
    }
  }

  void _executeRemoval() {
    if (blocksToRemove.isEmpty) return;

    // 周辺の灰色ブロックにヒビを入れる
    _damageNearbyGreyBlocks(blocksToRemove);

    // コンボ処理
    combo++;
    comboTimer = 0;
    if (combo > 1) {
      comboText.text = 'COMBO x$combo!';
    }

    // スコア計算（ブロック数 x 10 x コンボ倍率）
    int baseScore = blocksToRemove.length * 10;
    int totalScore = baseScore * combo;
    score += totalScore;
    scoreText.text = 'Score: $score';

    // レベルアップチェック（500点ごと）
    int newLevel = (score ~/ 500) + 1;
    if (newLevel > level) {
      level = newLevel;
      levelText.text = 'Level: $level';
      print('⭐ レベルアップ: Level $level');
    }

    // 虹色ブロック生成（5個以上消した場合）
    bool shouldCreateRainbow = blocksToRemove.length >= 5;
    Vector2? rainbowPos;
    if (shouldCreateRainbow && blocksToRemove.isNotEmpty) {
      final firstBlock = blocksToRemove.first;
      rainbowPos = _findBlockPosition(firstBlock);
    }

    // ブロック削除
    for (var block in blocksToRemove) {
      for (int y = 0; y < gridRows; y++) {
        for (int x = 0; x < gridColumns; x++) {
          if (grid[y][x] == block) {
            grid[y][x] = null;
          }
        }
      }
      remove(block);
      world.destroyBody(block.body);
    }

    // 虹色ブロック生成
    if (shouldCreateRainbow && rainbowPos != null) {
      final rainbowBlock = GameBlock(
        blockColor: BlockColor.rainbow,
        gridX: rainbowPos.x.toInt(),
        gridY: rainbowPos.y.toInt(),
        gridOffset: gridOffset,
        blockSize: blockSize,
      );
      add(rainbowBlock);
      grid[rainbowPos.y.toInt()][rainbowPos.x.toInt()] = rainbowBlock;
    }

    blocksToRemove.clear();
  }

  // 周辺の黒・灰色ブロックに影響を与える
  void _damageNearbyGreyBlocks(List<GameBlock> removedBlocks) {
    final greyBlocksToRemove = <GameBlock>[];
    final blackBlocksToConvert = <GameBlock>[];

    for (var removedBlock in removedBlocks) {
      if (!removedBlock.isMounted) continue;

      final removedPos = removedBlock.body.position;

      // 周辺の黒・灰色ブロックを探す
      for (var block in children.whereType<GameBlock>()) {
        if (block.blockColor != BlockColor.grey && block.blockColor != BlockColor.black) continue;
        if (!block.isMounted) continue;

        final distance = block.body.position.distanceTo(removedPos);
        if (distance < blockSize * 2.5) {
          if (block.blockColor == BlockColor.black) {
            // 黒ブロックは灰色に変化
            if (!blackBlocksToConvert.contains(block)) {
              blackBlocksToConvert.add(block);
            }
          } else if (block.blockColor == BlockColor.grey) {
            // 灰色ブロックは1回で削除
            if (!greyBlocksToRemove.contains(block)) {
              greyBlocksToRemove.add(block);
            }
          }
        }
      }
    }

    // 黒ブロックを灰色に変換
    for (var block in blackBlocksToConvert) {
      final oldPos = block.body.position;
      final gridPos = _worldToGrid(oldPos - gridOffset);

      if (gridPos != null) {
        // 古い黒ブロックを削除
        for (int y = 0; y < gridRows; y++) {
          for (int x = 0; x < gridColumns; x++) {
            if (grid[y][x] == block) {
              grid[y][x] = null;
            }
          }
        }
        remove(block);
        world.destroyBody(block.body);

        // 新しい灰色ブロックを生成
        final newBlock = GameBlock(
          blockColor: BlockColor.grey,
          gridX: gridPos.x.toInt(),
          gridY: gridPos.y.toInt(),
          gridOffset: gridOffset,
          blockSize: blockSize,
          bodyType: BodyType.static, // 固定状態で生成
        );
        newBlock.isFixed = true;
        add(newBlock);

        // 少し遅延してから位置を設定
        Future.delayed(const Duration(milliseconds: 50), () {
          if (newBlock.isMounted) {
            newBlock.body.setTransform(oldPos, 0);
          }
        });

        print('⚫→⚪ 黒ボールが灰色に変化！');
      }
    }

    // 灰色ブロックを削除
    for (var block in greyBlocksToRemove) {
      for (int y = 0; y < gridRows; y++) {
        for (int x = 0; x < gridColumns; x++) {
          if (grid[y][x] == block) {
            grid[y][x] = null;
          }
        }
      }
      remove(block);
      world.destroyBody(block.body);
      print('💥 灰色ボール削除！');
    }
  }

  Vector2? _findBlockPosition(GameBlock block) {
    for (int y = 0; y < gridRows; y++) {
      for (int x = 0; x < gridColumns; x++) {
        if (grid[y][x] == block) {
          return Vector2(x.toDouble(), y.toDouble());
        }
      }
    }
    return null;
  }

  void _updateMovableBlocks() {
    // スポーンボールのみをフリックで発射する仕様のため、
    // 通常ブロックの移動可能フラグ・点滅は不要（空メソッド）

    // 消去アニメーション中のブロックのみ点滅を継続
    for (var block in children.whereType<GameBlock>()) {
      if (block.isSpawnBall) continue;
      block.isMovable = false;
      // 消去対象でなければ点滅を停止
      if (!blocksToRemove.contains(block)) {
        block.isBlinking = false;
        block.isVisible = true;
      }
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);

    // ドラッグ履歴をクリア
    dragHistory.clear();

    final touchPos = event.localPosition;

    // スポーンボールのみをチェック（フリック発射用）
    for (var ball in bottomSpawnBalls) {
      if (!ball.isMounted) continue;
      final distance = ball.body.position.distanceTo(touchPos);
      final ballRadius = blockSize / 2 * (ball.blockColor == BlockColor.white ? 1.2 :
                                          ball.blockColor == BlockColor.yellow ? 0.8 : 1.0);

      if (distance < ballRadius * 1.5) {
        // スポーンボールをタップした
        draggedBlock = ball;
        dragStartPosition = ball.body.position.clone();

        // 初期位置を記録
        final currentTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
        dragHistory.add((time: currentTime, position: ball.body.position.clone()));

        print('✋ スポーンボールをタップ: ${ball.blockColor.name}');
        return;
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);

    // スポーンボールのフリック検出用にドラッグ位置のみを記録
    if (draggedBlock != null && draggedBlock!.isSpawnBall) {
      // 前回の位置 + デルタで現在位置を計算
      final currentTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final lastPos = dragHistory.isNotEmpty ? dragHistory.last.position : dragStartPosition!;
      final newPos = lastPos + event.localDelta;

      dragHistory.add((time: currentTime, position: newPos));

      if (dragHistory.length > 10) {
        dragHistory.removeAt(0);
      }
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (draggedBlock != null) {
      // スポーンボールの場合はフリック発射
      if (draggedBlock!.isSpawnBall) {
        Vector2 velocity = Vector2.zero();

        // ドラッグ履歴から速度を計算
        if (dragHistory.length >= 2) {
          final count = dragHistory.length >= 5 ? 5 : dragHistory.length;
          final recentHistory = dragHistory.sublist(dragHistory.length - count);

          final first = recentHistory.first;
          final last = recentHistory.last;
          final deltaTime = last.time - first.time;

          if (deltaTime > 0.001) {
            final deltaPos = last.position - first.position;
            velocity = deltaPos / deltaTime;

            // 速度を増幅（フリック感を強くする）
            velocity = velocity * 2.5;

            // 速度を制限（最大300）
            final speed = velocity.length;
            if (speed > 300) {
              velocity = velocity.normalized() * 300;
            }

            // 最小速度（遅すぎる場合は上向きに自動発射）
            if (speed < 50) {
              velocity = Vector2(0, 150); // 真上に発射（Y軸正の方向）
            }
          } else {
            // 時間が短すぎる場合は上向きに発射
            velocity = Vector2(0, 150);
          }
        } else {
          // 履歴がない場合は上向きに発射
          velocity = Vector2(0, 150);
        }

        _flickFireBall(draggedBlock!, velocity);
      }

      draggedBlock = null;
      dragStartPosition = null;
      dragHistory.clear();
    }
  }

  // ビリヤードモードの更新処理
  void _updateBilliardMode(double dt) {
    // ステージクリア中は処理をスキップ
    if (isStageClear) return;

    // ボール数を更新
    _updateBallCount();

    // ステージクリア判定
    if (remainingBalls <= targetBalls && !isStageClear) {
      _showStageClear();
      return;
    }

    // 全ボールが停止しているかチェック
    bool allStopped = _areAllBallsStopped();

    if (allStopped) {
      allStoppedTimer += dt;

      // 5秒間停止したら上向き重力トリガー
      if (allStoppedTimer >= 5.0 && !isGravityBoostActive) {
        _triggerGravityBoost();
      }

      // 停止していて、スポーンボールがなければ新しいボールをスポーン
      if (bottomSpawnBalls.isEmpty && !isGravityBoostActive) {
        _spawnNewBall();
      }
    } else {
      // 動いているボールがある場合はタイマーをリセット
      allStoppedTimer = 0;
      isGravityBoostActive = false;
    }

    // 移動中の接合判定（ビリヤードモード専用）
    _checkMovingMatches();
  }

  // ボール数を更新
  void _updateBallCount() {
    final currentCount = children.whereType<GameBlock>()
      .where((b) => !b.isSpawnBall && b.isMounted && b.body.bodyType == BodyType.dynamic)
      .length;

    if (currentCount != remainingBalls) {
      remainingBalls = currentCount;
      remainingBallsText?.text = 'Balls: $remainingBalls / $targetBalls';
      print('📊 残球数更新: $remainingBalls / $targetBalls');
    }
  }

  // ステージクリア表示
  void _showStageClear() {
    isStageClear = true;
    print('🎉 ステージ $currentStage クリア！');

    final centerX = gridOffset.x + (gridColumns * blockSize) / 2;
    final centerY = gridOffset.y + (gridRows * blockSize) / 2;

    final clearText = TextComponent(
      text: 'STAGE $currentStage CLEAR!',
      position: Vector2(centerX - 180, centerY - 50),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF00FF00),
          fontSize: 42,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(clearText);

    final nextStageText = TextComponent(
      text: 'Tap to Next Stage',
      position: Vector2(centerX - 100, centerY + 20),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(nextStageText);
  }

  // 次のステージへ進む
  void _nextStage() {
    print('➡️ 次のステージへ: ${currentStage + 1}');

    // クリアテキストを削除
    final textsToRemoveList = children.whereType<TextComponent>().where((t) =>
      t.text.contains('STAGE') && t.text.contains('CLEAR') || t.text == 'Tap to Next Stage'
    ).toList();
    for (var text in textsToRemoveList) {
      remove(text);
    }

    // 全ボールを削除
    final blocksToRemoveList = children.whereType<GameBlock>().toList();
    for (var block in blocksToRemoveList) {
      remove(block);
      world.destroyBody(block.body);
    }

    // グリッドをクリア
    for (int y = 0; y < gridRows; y++) {
      for (int x = 0; x < gridColumns; x++) {
        grid[y][x] = null;
      }
    }

    // ステージを進める
    currentStage++;
    targetBalls = 10 - currentStage; // ステージが上がるごとに目標が厳しくなる
    if (targetBalls < 3) targetBalls = 3; // 最低3個
    isStageClear = false;
    bottomSpawnBalls.clear();

    // UIを更新
    stageText?.text = 'Stage: $currentStage';
    remainingBallsText?.text = 'Balls: 0 / $targetBalls';

    // 新しいボールを配置
    _createInitialBlocks();
    _spawnInitialBalls();
  }

  // 全ボールが停止しているかチェック
  bool _areAllBallsStopped() {
    const double stoppedThreshold = 5.0; // 速度5以下を停止とみなす

    for (var block in children.whereType<GameBlock>()) {
      if (block.isSpawnBall) continue; // スポーンボールは除外
      if (!block.isMounted) continue;
      if (block.body.bodyType != BodyType.dynamic) continue; // Staticは除外

      final velocity = block.body.linearVelocity.length;
      if (velocity > stoppedThreshold) {
        return false; // 動いているボールがある
      }
    }

    return true; // 全ボール停止
  }

  // 上向き重力トリガー
  void _triggerGravityBoost() {
    print('⬆️ 重力ブースト発動！（5秒間停止）');
    isGravityBoostActive = true;

    // 全ボールに一時的な上向きの力を加える
    for (var block in children.whereType<GameBlock>()) {
      if (block.isSpawnBall) continue;
      if (!block.isMounted) continue;
      if (block.body.bodyType != BodyType.dynamic) continue;

      // 上向きの力を加える（Y軸負の方向）
      block.body.applyLinearImpulse(Vector2(0, -block.body.mass * 30));
    }

    // 3秒後にブースト終了
    Future.delayed(const Duration(seconds: 3), () {
      isGravityBoostActive = false;
      allStoppedTimer = 0;
    });
  }

  // 移動中の接合判定（ビリヤードモード専用）
  void _checkMovingMatches() {
    final List<Set<GameBlock>> matchedGroups = [];
    final Set<GameBlock> visited = {};

    // 全てのDynamicボールをチェック（スポーンボールは除外）
    final dynamicBlocks = children.whereType<GameBlock>()
      .where((b) => !b.isSpawnBall && b.isMounted && b.body.bodyType == BodyType.dynamic)
      .toList();

    for (var block in dynamicBlocks) {
      if (visited.contains(block)) continue;

      // 物理的に接続されたボールのグループを検出
      final group = _findConnectedBlocksByProximity(block, visited);

      // グループに虹色が含まれている場合は2個以上で消える
      final hasRainbow = group.any((b) => b.blockColor == BlockColor.rainbow);
      final minSize = hasRainbow ? 2 : 3;

      // 4倍紫がグループに含まれているかチェック
      final hasMegaPurple = group.any((b) =>
        b.blockColor == BlockColor.purple && b.sizeMultiplier == 4
      );

      // 4倍紫は虹色がグループに含まれている場合のみ消える
      if (hasMegaPurple && !hasRainbow) {
        continue;
      }

      if (group.length >= minSize) {
        matchedGroups.add(group);
      }
    }

    // マッチしたグループがあれば削除
    if (matchedGroups.isNotEmpty) {
      print('🎯 移動中の接合検出: ${matchedGroups.length}グループ');
      final allBlocksToRemove = <GameBlock>{};
      for (var group in matchedGroups) {
        allBlocksToRemove.addAll(group);
      }
      _startRemovalAnimation(allBlocksToRemove.toList());
    }
  }

  // 物理的距離による接続ブロック検出（グリッド不要）
  Set<GameBlock> _findConnectedBlocksByProximity(GameBlock startBlock, Set<GameBlock> visited) {
    final Set<GameBlock> group = {startBlock};
    final List<GameBlock> toCheck = [startBlock];
    final targetColor = startBlock.blockColor;

    visited.add(startBlock);

    while (toCheck.isNotEmpty) {
      final currentBlock = toCheck.removeLast();

      // 全てのDynamicボールをチェック
      for (var otherBlock in children.whereType<GameBlock>()) {
        if (otherBlock.isSpawnBall) continue;
        if (!otherBlock.isMounted) continue;
        if (otherBlock.body.bodyType != BodyType.dynamic) continue;
        if (group.contains(otherBlock)) continue;
        if (visited.contains(otherBlock)) continue;

        // 色が一致するか（虹色も考慮）
        if (!otherBlock.blockColor.canMergeWith(targetColor)) continue;

        // 物理的に接触しているかチェック
        final distance = currentBlock.body.position.distanceTo(otherBlock.body.position);

        // サイズ倍率を考慮した半径計算
        double currentMultiplier = currentBlock.sizeMultiplier.toDouble();
        if (currentBlock.blockColor == BlockColor.white) {
          currentMultiplier = 1.2;
        } else if (currentBlock.blockColor == BlockColor.yellow) {
          currentMultiplier = 0.8;
        }

        double otherMultiplier = otherBlock.sizeMultiplier.toDouble();
        if (otherBlock.blockColor == BlockColor.white) {
          otherMultiplier = 1.2;
        } else if (otherBlock.blockColor == BlockColor.yellow) {
          otherMultiplier = 0.8;
        }

        final currentRadius = (blockSize * currentMultiplier) / 2;
        final otherRadius = (blockSize * otherMultiplier) / 2;

        // 接触判定距離（半径の合計 × 1.15）
        final touchDistance = (currentRadius + otherRadius) * 1.15;

        if (distance <= touchDistance) {
          group.add(otherBlock);
          visited.add(otherBlock);
          toCheck.add(otherBlock);
        }
      }
    }

    return group;
  }

  void _checkGameOver() {
    // ゲーム開始から3秒以内はゲームオーバー判定をスキップ（初期配置の安定待機）
    if (gameStartTimer < 3.0) {
      return;
    }

    // グリッドエリアの最下部より下にスポーンボール以外のボールがあったらゲームオーバー
    int totalBlocks = 0;
    int spawnBallsCount = 0;

    // グリッドエリアの最下部のY座標（localY基準）
    final gridBottomY = gridRows * blockSize;

    for (var block in children.whereType<GameBlock>()) {
      totalBlocks++;

      // スポーンボールは除外
      if (block.isSpawnBall) {
        spawnBallsCount++;
        continue;
      }

      // ボールがマウントされている場合
      if (block.isMounted) {
        final worldPos = block.body.position;
        final localY = worldPos.y - gridOffset.y;
        final velocity = block.body.linearVelocity;

        // グリッドエリアの最下部より下にボールがあり、かつ停止している場合はゲームオーバー
        // 発射直後で速く動いているボール（上向きでも下向きでも）は除外
        final isMovingFast = velocity.length > 30; // 速く動いているボールは除外
        final isRecentlyFired = block.timeSinceFired < 1.0; // 発射から1秒以内は除外

        if (localY > gridBottomY && !isMovingFast && !isRecentlyFired) {
          print('🔴 GAME OVER TRIGGERED!');
          print('   理由: グリッドエリアの最下部より下にボールが停止しています');
          print('   ブロック色: ${block.blockColor.name}');
          print('   グリッド相対Y: ${localY.toStringAsFixed(1)}');
          print('   グリッド最下部Y: ${gridBottomY.toStringAsFixed(1)}');
          print('   速度: ${velocity.length.toStringAsFixed(1)}');
          print('   発射からの時間: ${block.timeSinceFired.toStringAsFixed(2)}秒');
          print('   総ブロック数: $totalBlocks (スポーンボール: $spawnBallsCount, ゲーム内: ${totalBlocks - spawnBallsCount})');
          print('   現在のスコア: $score, レベル: $level');

          isGameOver = true;
          _showGameOver();
          return;
        }
      }
    }
  }

  void _showGameOver() {
    final centerX = gridOffset.x + (gridColumns * blockSize) / 2;
    final centerY = gridOffset.y + (gridRows * blockSize) / 2;

    final gameOverText = TextComponent(
      text: 'GAME OVER',
      position: Vector2(centerX - 150, centerY - 50),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.red,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(gameOverText);

    final restartText = TextComponent(
      text: 'Tap to Restart',
      position: Vector2(centerX - 80, centerY + 20),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(restartText);
  }

  void _restartGame() {
    print('🔄 ゲームをリスタート');

    final blocksToRemoveList = children.whereType<GameBlock>().toList();
    for (var block in blocksToRemoveList) {
      remove(block);
      world.destroyBody(block.body);
    }

    for (int y = 0; y < gridRows; y++) {
      for (int x = 0; x < gridColumns; x++) {
        grid[y][x] = null;
      }
    }

    score = 0;
    level = 1;
    isGameOver = false;
    combo = 0;
    comboTimer = 0;
    draggedBlock = null;
    dragStartPosition = null;
    blocksToRemove.clear();
    blinkDuration = 0;
    bottomSpawnBalls.clear();
    collisionCheckTimer = 0; // 衝突検出タイマーをリセット
    collisionDetected = false; // 衝突検出フラグをリセット
    periodicCheckTimer = 0; // 定期的な接続判定タイマーをリセット
    dragHistory.clear();
    gameStartTimer = 0; // ゲーム開始タイマーをリセット
    initialMatchCheckDone = false; // 初期接続判定フラグをリセット

    // ビリヤードモード変数をリセット
    if (isBilliardMode) {
      currentStage = 1;
      targetBalls = 10;
      remainingBalls = 0;
      isStageClear = false;
      allStoppedTimer = 0;
      isGravityBoostActive = false;
      stageText?.text = 'Stage: $currentStage';
      remainingBallsText?.text = 'Balls: 0 / $targetBalls';
    }

    scoreText.text = 'Score: $score';
    levelText.text = 'Level: $level';
    comboText.text = '';

    final textsToRemoveList = children.whereType<TextComponent>().where((t) =>
      t.text == 'GAME OVER' || t.text == 'Tap to Restart'
    ).toList();
    for (var text in textsToRemoveList) {
      remove(text);
    }

    _createInitialBlocks();
    _spawnInitialBalls();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    if (isGameOver) {
      _restartGame();
      return;
    }

    // ビリヤードモード：ステージクリア時に次のステージへ
    if (isBilliardMode && isStageClear) {
      _nextStage();
      return;
    }
  }
}
