import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'components/game_block.dart';
import 'components/game_grid.dart';
import 'components/roulette_display.dart';
import 'utils/block_color.dart';

class BlockMergeGame extends Forge2DGame with TapCallbacks, DragCallbacks {
  static const int gridColumns = 10;
  static const int gridRows = 19; // 最上段をなくして19行に変更

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

  // 次に落とすボール群（レベルに応じて増える）
  List<GameBlock> topBalls = [];
  double ballsMoveSpeed = 1.0; // 1秒で1マス移動
  int ballsDirection = 1; // 1: 右, -1: 左

  // レベルに応じたボール数（2個から開始、最大10個）
  int get ballCount => min(2 + level - 1, gridColumns);

  // ドラッグ速度計算用（履歴を保持）
  final List<({double time, Vector2 position})> dragHistory = [];

  // ルーレットシステム
  late RouletteDisplay rouletteDisplay;
  BlockColor rouletteLeftColor = BlockColor.red;
  BlockColor rouletteRightColor = BlockColor.blue;
  double rouletteSpinTimer = 0;    // 色変更用タイマー
  double rouletteStopTimer = 0;    // 停止判定用タイマー
  double rouletteSpinSpeed = 0.05; // 回転速度（秒）
  bool isRouletteSpinning = true;
  static const double rouletteStopInterval = 2.0; // 2秒に1回停止

  // UIコンポーネント
  late TextComponent scoreText;
  late TextComponent levelText;
  late TextComponent comboText;
  late RectangleComponent background;

  BlockMergeGame() : super(gravity: Vector2(0, 40)); // 重力を4倍に（さらに2倍）

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

    blockSize = (screenWidth - padding * 2) / gridColumns;
    gridOffset = Vector2(padding, topSafeArea + uiHeight); // セーフエリア + UI分下げる

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

    // ルーレット表示（スコアの右側）
    final rouletteSize = 30.0;
    rouletteDisplay = RouletteDisplay(
      slotSize: rouletteSize,
      leftColor: rouletteLeftColor,
      rightColor: rouletteRightColor,
      position: Vector2(screenWidth - 100, uiTop),
    );
    add(rouletteDisplay);

    _createGround();
    _createTopBalls();
  }

  void _createGround() {
    final groundY = gridOffset.y + gridRows * blockSize;

    // 地面
    final groundBody = world.createBody(BodyDef(position: Vector2(gridOffset.x, groundY)));
    final groundShape = EdgeShape()..set(Vector2(0, 0), Vector2(gridColumns * blockSize, 0));
    groundBody.createFixture(FixtureDef(groundShape, friction: 0.4, restitution: 0.3));

    // 左壁（上部まで延長してボールが外に出ないように）
    final leftWall = world.createBody(BodyDef(position: Vector2(gridOffset.x, gridOffset.y - blockSize * 2)));
    final leftWallShape = EdgeShape()..set(Vector2(0, 0), Vector2(0, (gridRows + 2) * blockSize));
    leftWall.createFixture(FixtureDef(leftWallShape, friction: 0.4, restitution: 0.3));

    // 右壁（上部まで延長してボールが外に出ないように）
    final rightWall = world.createBody(BodyDef(position: Vector2(gridOffset.x + gridColumns * blockSize, gridOffset.y - blockSize * 2)));
    final rightWallShape = EdgeShape()..set(Vector2(0, 0), Vector2(0, (gridRows + 2) * blockSize));
    rightWall.createFixture(FixtureDef(rightWallShape, friction: 0.4, restitution: 0.3));
  }

  void _createTopBalls() {
    // 既存のボールをクリア
    for (var ball in topBalls) {
      if (ball.isMounted) {
        remove(ball);
        world.destroyBody(ball.body);
      }
    }
    topBalls.clear();

    // 落下ボール用の色（白と灰色を除く）
    final ballColors = BlockColor.getAvailableColors(level);
    final count = ballCount;

    // 中央から左右に配置
    final startX = (gridColumns - count) / 2;

    for (int i = 0; i < count; i++) {
      final ball = GameBlock(
        blockColor: BlockColor.randomFromList(ballColors),
        gridX: (startX + i).toInt(),
        gridY: -1, // グリッドの上
        gridOffset: gridOffset,
        blockSize: blockSize,
        bodyType: BodyType.kinematic, // 物理演算を無効化
      );
      add(ball);
      topBalls.add(ball);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) return;

    // ルーレットの回転と停止
    if (isRouletteSpinning) {
      // 高速で色を変更
      rouletteSpinTimer += dt;
      if (rouletteSpinTimer >= rouletteSpinSpeed) {
        final rouletteColors = BlockColor.getRouletteColors();
        final random = Random();
        rouletteLeftColor = rouletteColors[random.nextInt(rouletteColors.length)];
        rouletteRightColor = rouletteColors[random.nextInt(rouletteColors.length)];
        rouletteDisplay.setColors(rouletteLeftColor, rouletteRightColor);
        rouletteSpinTimer = 0;
      }
    }

    // 停止判定用のタイマー（常に増加）
    rouletteStopTimer += dt;

    // 2秒経過で停止→判定→再開
    if (rouletteStopTimer >= rouletteStopInterval) {
      if (isRouletteSpinning) {
        // 停止して判定
        isRouletteSpinning = false;
        _checkRouletteMatch();
        rouletteStopTimer = 0;
      } else {
        // 再開
        isRouletteSpinning = true;
        rouletteStopTimer = 0;
      }
    }

    // ボールの左右移動（レベルに応じた数）
    if (topBalls.isNotEmpty && topBalls.every((ball) => ball.isMounted)) {
      // 画面いっぱいまで移動するように
      // 左端から右端まで移動（ボール数に応じて間隔を調整）
      for (int i = 0; i < topBalls.length; i++) {
        final ball = topBalls[i];

        // 往復運動（左端0 → 右端gridColumns - 1）
        final phase = (rouletteStopTimer * 0.5 + i * 0.2) % 2.0; // 0.0 ~ 2.0
        double positionX;

        if (phase < 1.0) {
          // 左→右
          positionX = phase * (gridColumns - 1);
        } else {
          // 右→左
          positionX = (2.0 - phase) * (gridColumns - 1);
        }

        ball.body.setTransform(
          Vector2(
            gridOffset.x + positionX * blockSize + blockSize / 2,
            gridOffset.y - blockSize / 2,
          ),
          0,
        );
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

    // 4つ揃いをチェック
    _checkForMatches();

    // 移動可能ブロックの更新
    _updateMovableBlocks();

    // ゲームオーバーチェック
    _checkGameOver();
  }

  void _checkRouletteMatch() {
    // ルーレットで同色が揃った場合は全部落下（どんな色でも）
    if (rouletteLeftColor == rouletteRightColor) {
      _dropAllTopBalls();
      return;
    }

    // 白と灰色はセグ専用の色なので、落下ボールには存在しない
    // そのため、白や灰色が出ても一致するボールがない
    final isLeftLose = rouletteLeftColor == BlockColor.white || rouletteLeftColor == BlockColor.grey;
    final isRightLose = rouletteRightColor == BlockColor.white || rouletteRightColor == BlockColor.grey;

    // 両方がセグ専用色の場合は何も落下しない
    if (isLeftLose && isRightLose) {
      return;
    }

    // それぞれの色に一致するボールを落下
    List<GameBlock> ballsToDrop = [];

    for (var ball in topBalls) {
      bool shouldDrop = false;

      // セグ専用色でない場合のみマッチング
      if (!isLeftLose && ball.blockColor == rouletteLeftColor) {
        shouldDrop = true;
      }
      if (!isRightLose && ball.blockColor == rouletteRightColor) {
        shouldDrop = true;
      }

      if (shouldDrop) {
        ballsToDrop.add(ball);
      }
    }

    if (ballsToDrop.isNotEmpty) {
      _dropSpecificBalls(ballsToDrop);
    }
  }

  void _dropAllTopBalls() {
    for (var ball in topBalls) {
      if (ball.isMounted) {
        ball.body.setType(BodyType.dynamic);
        ball.body.linearVelocity = Vector2(0, 40); // 初速を4倍に（さらに2倍）
      }
    }
    topBalls.clear();

    // 新しいボールセットを生成
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!isGameOver) {
        _createTopBalls();
      }
    });
  }

  void _dropSpecificBalls(List<GameBlock> ballsToDrop) {
    for (var ball in ballsToDrop) {
      if (ball.isMounted) {
        ball.body.setType(BodyType.dynamic);
        ball.body.linearVelocity = Vector2(0, 40); // 初速を4倍に（さらに2倍）
        topBalls.remove(ball);
      }
    }

    // 少し遅延してから補充と再配置
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!isGameOver) {
        _refillTopBalls();
      }
    });
  }

  void _refillTopBalls() {
    final targetCount = ballCount;
    final currentCount = topBalls.length;

    if (currentCount >= targetCount) {
      // 既に十分な数がある場合は再配置のみ
      _repositionTopBalls();
      return;
    }

    // 不足分のボールを補充
    final needCount = targetCount - currentCount;
    // 落下ボール用の色（白と灰色を除く）
    final ballColors = BlockColor.getAvailableColors(level);

    for (int i = 0; i < needCount; i++) {
      final ball = GameBlock(
        blockColor: BlockColor.randomFromList(ballColors),
        gridX: 0, // 仮の位置
        gridY: -1,
        gridOffset: gridOffset,
        blockSize: blockSize,
        bodyType: BodyType.kinematic,
      );
      add(ball);
      topBalls.add(ball);
    }

    // 全ボールを再配置
    _repositionTopBalls();
  }

  void _repositionTopBalls() {
    final count = topBalls.length;
    final startX = (gridColumns - count) / 2;

    for (int i = 0; i < topBalls.length; i++) {
      final ball = topBalls[i];
      final baseX = startX + i;

      ball.body.setTransform(
        Vector2(
          gridOffset.x + baseX * blockSize + blockSize / 2,
          gridOffset.y - blockSize / 2,
        ),
        0,
      );
    }
  }

  void _syncBlocksToGrid() {
    for (var block in children.whereType<GameBlock>()) {
      // ドラッグ中のブロックと上部のボールはスキップ
      if (block == draggedBlock || topBalls.contains(block)) continue;

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
    final Set<GameBlock> allMatchedBlocks = {};
    final Set<GameBlock> visited = {};

    // すべてのブロックに対して接続チェック
    for (int y = 0; y < gridRows; y++) {
      for (int x = 0; x < gridColumns; x++) {
        final block = grid[y][x];
        if (block == null || visited.contains(block)) continue;

        // 接続されたブロックのグループを取得（flood-fill）
        final group = _findConnectedBlocks(block, x, y, visited);

        // 3つ以上接続していれば削除対象
        if (group.length >= 3) {
          allMatchedBlocks.addAll(group);
        }
      }
    }

    if (allMatchedBlocks.isNotEmpty) {
      _startRemovalAnimation(allMatchedBlocks.toList());
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
      if (block == null || visited.contains(block) || group.contains(block)) continue;

      // 色が一致するか（虹色も考慮）
      if (!block.blockColor.canMergeWith(targetColor)) continue;

      // 物理的な接触をチェック
      if (group.isNotEmpty && !_isPhysicallyTouching(block, group)) continue;

      group.add(block);
      visited.add(block);

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
    final radius = blockSize / 2;
    final touchDistance = radius * 2.2; // 少し余裕を持たせる

    for (var otherBlock in group) {
      if (!otherBlock.isMounted) continue;

      final otherPos = otherBlock.body.position;
      final distance = blockPos.distanceTo(otherPos);
      if (distance <= touchDistance) {
        return true;
      }
    }
    return false;
  }

  void _startRemovalAnimation(List<GameBlock> blocks) {
    blocksToRemove = blocks;
    for (var block in blocks) {
      block.isBlinking = true;
    }
  }

  void _executeRemoval() {
    if (blocksToRemove.isEmpty) return;

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
      // レベルアップ時にボール数を増やす
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!isGameOver) {
          _refillTopBalls();
        }
      });
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
    // まず全てのボールの移動可能フラグと点滅をリセット
    for (var block in children.whereType<GameBlock>()) {
      // 上部のボールは除外
      if (topBalls.contains(block)) continue;
      block.isMovable = false;
      // 消去アニメーション中のブロック以外は点滅を停止
      if (!blocksToRemove.contains(block)) {
        block.isBlinking = false;
        block.isVisible = true;
      }
    }

    // 各列の一番上のブロックは移動可能で点滅
    for (int x = 0; x < gridColumns; x++) {
      for (int y = 0; y < gridRows; y++) {
        if (grid[y][x] != null && grid[y][x]!.isMounted) {
          grid[y][x]!.isMovable = true;
          // ドラッグ中でなければ点滅させる
          if (grid[y][x] != draggedBlock) {
            grid[y][x]!.isBlinking = true;
          }
          break; // 一番上のみ
        }
      }
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);

    // ドラッグ履歴をクリア
    dragHistory.clear();

    final localPos = event.localPosition - gridOffset;
    final gridPos = _worldToGrid(localPos);

    if (gridPos != null) {
      int gx = gridPos.x.toInt();
      int gy = gridPos.y.toInt();

      if (gx >= 0 && gx < gridColumns && gy >= 0 && gy < gridRows) {
        final block = grid[gy][gx];
        if (block != null && block.isMovable) {
          draggedBlock = block;
          dragStartPosition = Vector2(gx.toDouble(), gy.toDouble());
          // 点滅を停止
          block.isBlinking = false;
          block.isVisible = true;
          // kinematicにすることで他のボールと衝突しながら移動
          block.body.setType(BodyType.kinematic);

          // 初期位置を記録
          final currentTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
          dragHistory.add((time: currentTime, position: block.body.position.clone()));
        }
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);

    if (draggedBlock != null) {
      final currentPos = draggedBlock!.body.position;
      final newPos = currentPos + event.localDelta;

      draggedBlock!.body.setTransform(newPos, 0);

      // ドラッグ履歴に追加（最新10フレームのみ保持）
      final currentTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
      dragHistory.add((time: currentTime, position: newPos.clone()));

      if (dragHistory.length > 10) {
        dragHistory.removeAt(0);
      }
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (draggedBlock != null) {
      // ドロップ位置がグリッド内かチェック
      final dropPos = draggedBlock!.body.position;
      final localX = dropPos.x - gridOffset.x;
      final localY = dropPos.y - gridOffset.y;

      // グリッドの範囲内かチェック
      final isInsideGrid = localX >= 0 &&
                          localX <= gridColumns * blockSize &&
                          localY >= 0 &&
                          localY <= gridRows * blockSize;

      if (!isInsideGrid) {
        // グリッド外の場合は元の位置に戻す
        if (dragStartPosition != null) {
          draggedBlock!.body.setTransform(
            Vector2(
              gridOffset.x + dragStartPosition!.x * blockSize + blockSize / 2,
              gridOffset.y + dragStartPosition!.y * blockSize + blockSize / 2,
            ),
            0,
          );
          draggedBlock!.body.setType(BodyType.dynamic);
          draggedBlock!.body.linearVelocity = Vector2.zero();
        }
      } else {
        // グリッド内の場合は速度を計算して適用
        Vector2 velocity = Vector2.zero();

        // ドラッグ履歴から速度を計算
        if (dragHistory.length >= 2) {
          // 最後の数点から速度を計算
          final count = dragHistory.length >= 5 ? 5 : dragHistory.length;
          final recentHistory = dragHistory.sublist(dragHistory.length - count);

          final first = recentHistory.first;
          final last = recentHistory.last;
          final deltaTime = last.time - first.time;

          if (deltaTime > 0.001) { // 1ms以上あれば計算
            final deltaPos = last.position - first.position;
            velocity = deltaPos / deltaTime;

            // 速度を増幅（投げる感覚を強くする）
            velocity = velocity * 1.5;

            // 速度を制限（最大150）
            final speed = velocity.length;
            if (speed > 150) {
              velocity = velocity.normalized() * 150;
            }

            // 最小速度を設定（あまりにも遅い場合は0にする）
            if (speed < 3) {
              velocity = Vector2.zero();
            }
          }
        }

        // dynamicに戻して速度を適用
        draggedBlock!.body.setType(BodyType.dynamic);
        draggedBlock!.body.linearVelocity = velocity;
      }

      draggedBlock = null;
      dragStartPosition = null;
      dragHistory.clear();
    }
  }

  void _checkGameOver() {
    // 上部のボールを除外して、グリッドの上端を超えて積み上がっているかチェック
    for (var block in children.whereType<GameBlock>()) {
      // 上部のボールは除外
      if (topBalls.contains(block)) continue;

      // ボールがマウントされている場合
      if (block.isMounted) {
        final worldPos = block.body.position;
        final localY = worldPos.y - gridOffset.y;

        // ボールの中心がグリッドより上にあり、かつ速度が小さい（停止している）場合
        // バウンス中や落下中は除外するため、速度チェックを追加
        final velocity = block.body.linearVelocity;
        final isMoving = velocity.length > 5.0; // 速度が5以上なら移動中

        // グリッドより上にあり、かつほぼ停止している場合はゲームオーバー
        if (localY < blockSize * 0.5 && !isMoving) {
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
    topBalls.clear();
    dragHistory.clear();
    rouletteSpinTimer = 0;
    rouletteStopTimer = 0;
    isRouletteSpinning = true;

    scoreText.text = 'Score: $score';
    levelText.text = 'Level: $level';
    comboText.text = '';

    final textsToRemoveList = children.whereType<TextComponent>().where((t) =>
      t.text == 'GAME OVER' || t.text == 'Tap to Restart'
    ).toList();
    for (var text in textsToRemoveList) {
      remove(text);
    }

    _createTopBalls();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    if (isGameOver) {
      _restartGame();
      return;
    }
  }
}
