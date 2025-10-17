import 'dart:async';
import 'dart:io';
import 'room_service.dart';

/// 楽観的UI更新のための状態管理クラス
/// ストリートファイターのようなリアルタイム性を実現
class OptimisticGameState {
  final String roomId;
  final String playerId;
  final int timeLimit;

  // 楽観的状態（ローカル）
  OnlineGameState? _optimisticState;

  // サーバー確定状態
  OnlineGameState? _authorizedState;

  // ペンディング中のアクション
  final List<PendingAction> _pendingActions = [];

  // 状態変更を通知するStreamController
  final StreamController<OnlineGameState?> _stateController = StreamController.broadcast();

  // エラー通知用StreamController
  final StreamController<OptimisticError> _errorController = StreamController.broadcast();

  // オフライン状態管理
  bool _isOffline = false;
  Timer? _retryTimer;
  final List<PendingAction> _offlineActions = [];

  OptimisticGameState({
    required this.roomId,
    required this.playerId,
    required this.timeLimit,
  });

  /// 現在の状態（楽観的状態またはサーバー状態）
  OnlineGameState? get currentState => _optimisticState ?? _authorizedState;

  /// 状態変更のStream
  Stream<OnlineGameState?> get stateStream => _stateController.stream;

  /// エラーのStream
  Stream<OptimisticError> get errorStream => _errorController.stream;

  /// サーバー状態の更新を受信
  void updateAuthorizedState(OnlineGameState? newState) {
    _authorizedState = newState;

    if (newState != null) {
      _reconcileStates(newState);
    }

    _emitCurrentState();
  }

  /// プレイヤーアクションを楽観的に実行
  Future<void> performOptimisticAction(String action) async {
    final currentState = this.currentState;
    if (currentState == null) return;

    // 自分のターンでない場合は無視
    if (currentState.currentPlayerId != playerId) {
      _errorController.add(OptimisticError(
        type: OptimisticErrorType.notYourTurn,
        message: 'あなたのターンではありません',
      ));
      return;
    }

    // アクションIDを生成
    final actionId = DateTime.now().millisecondsSinceEpoch.toString();

    // ペンディングアクションとして記録
    final pendingAction = PendingAction(
      id: actionId,
      playerId: playerId,
      action: action,
      timestamp: DateTime.now(),
      originalState: currentState,
    );

    _pendingActions.add(pendingAction);

    // 楽観的状態を即座に計算・更新
    final optimisticResult = _calculateOptimisticState(currentState, action);
    _optimisticState = optimisticResult;

    // UI即座更新
    _emitCurrentState();

    // サーバーにアクションを送信（非同期）
    try {
      await _sendActionToServer(actionId, action);
    } catch (e) {
      // サーバーエラー時は楽観的アクションをロールバック
      _rollbackAction(actionId);
      _errorController.add(OptimisticError(
        type: OptimisticErrorType.serverError,
        message: 'サーバーエラー: $e',
      ));
    }
  }

  /// 楽観的状態の計算（ローカル）
  OnlineGameState _calculateOptimisticState(OnlineGameState currentState, String action) {
    // 現在の状態をコピー
    var newBellState = currentState.bellState;
    var newScores = Map<String, int>.from(currentState.scores);
    var activePlayers = List<String>.from(currentState.activePlayers);
    String? nextPlayerId = currentState.currentPlayerId;
    String actionType = '';
    bool isSuccess = false;

    // アクション結果を計算
    switch (action) {
      case 'tap':
        if (currentState.bellState == BellState.safe) {
          isSuccess = true;
          actionType = 'correct_tap';
        } else {
          isSuccess = false;
          actionType = 'wrong_action';
        }
        break;

      case 'verticalSwipe':
        if (currentState.bellState == BellState.safe) {
          isSuccess = true;
          actionType = 'send_bell';
          newBellState = BellState.danger;
        } else {
          isSuccess = false;
          actionType = 'wrong_action';
        }
        break;

      case 'horizontalSwipe':
        if (currentState.bellState == BellState.danger) {
          isSuccess = true;
          actionType = 'return_to_safe';
          newBellState = BellState.safe;
        } else {
          // 何もしない
          return currentState;
        }
        break;
    }

    // スコア更新
    if (isSuccess) {
      newScores[playerId] = (newScores[playerId] ?? 0) + 1;
    } else {
      // 失敗時はプレイヤー除外
      activePlayers.remove(playerId);
    }

    // 次のプレイヤーを決定
    if (activePlayers.isNotEmpty) {
      final currentIndex = activePlayers.indexOf(currentState.currentPlayerId!);
      int nextIndex;
      if (currentIndex == -1) {
        // currentPlayerIdが見つからない場合は最初から開始
        nextIndex = 0;
      } else {
        nextIndex = (currentIndex + 1) % activePlayers.length;
      }
      nextPlayerId = activePlayers[nextIndex];
    }

    return OnlineGameState(
      phase: activePlayers.isEmpty ? GamePhase.gameEnd : GamePhase.playing,
      bellState: newBellState,
      currentPlayerId: nextPlayerId,
      currentTurn: currentState.currentTurn + 1,
      activePlayers: activePlayers,
      scores: newScores,
      lastAction: actionType,
      actionTime: DateTime.now(),
      timeRemaining: timeLimit,
    );
  }

  /// サーバーにアクションを送信（オフライン対応）
  Future<void> _sendActionToServer(String actionId, String action) async {
    try {
      // ネットワーク接続確認
      if (!await _checkNetworkConnection()) {
        _handleOfflineAction(actionId, action);
        return;
      }

      final roomService = RoomService();

      // タイムアウト付きでサーバーに送信
      await Future.any([
        roomService.performPlayerActionWithId(roomId, playerId, action, actionId),
        Future.delayed(const Duration(seconds: 5), () => throw TimeoutException('Action timeout')),
      ]);

      // 成功時はペンディングアクションから削除
      _pendingActions.removeWhere((action) => action.id == actionId);

      // オンラインに復旧した場合、オフラインアクションを送信
      if (_isOffline) {
        _isOffline = false;
        await _sendOfflineActions();
      }

    } on SocketException catch (_) {
      _handleOfflineAction(actionId, action);
    } on TimeoutException catch (_) {
      _handleOfflineAction(actionId, action);
    } catch (e) {
      rethrow;
    }
  }

  /// ネットワーク接続確認
  Future<bool> _checkNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('firebase.google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// オフライン時のアクション処理
  void _handleOfflineAction(String actionId, String action) {
    _isOffline = true;

    final pendingAction = _pendingActions.where((a) => a.id == actionId).firstOrNull;
    if (pendingAction != null) {
      _offlineActions.add(pendingAction);

      _errorController.add(OptimisticError(
        type: OptimisticErrorType.offline,
        message: 'オフラインモード: アクションはオンライン復旧時に送信されます',
      ));

      // 定期的な再接続試行
      _startRetryTimer();
    }
  }

  /// オフライン状態での定期的な再接続試行
  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (await _checkNetworkConnection()) {
        timer.cancel();
        _isOffline = false;
        await _sendOfflineActions();
      }
    });
  }

  /// オフラインアクションの送信
  Future<void> _sendOfflineActions() async {
    if (_offlineActions.isEmpty) return;

    final actions = List<PendingAction>.from(_offlineActions);
    _offlineActions.clear();

    final roomService = RoomService();

    for (final action in actions) {
      try {
        await roomService.performPlayerActionWithId(
          roomId,
          action.playerId,
          action.action,
          action.id,
        );
      } catch (e) {
        // 送信失敗したアクションは再度オフラインキューに追加
        _offlineActions.add(action);
      }
    }
  }

  /// 楽観的アクションのロールバック
  void _rollbackAction(String actionId) {
    final action = _pendingActions.where((a) => a.id == actionId).firstOrNull;
    if (action != null) {
      _pendingActions.remove(action);

      // 楽観的状態をリセット
      if (_pendingActions.isEmpty) {
        _optimisticState = null;
      } else {
        // 他のペンディングアクションから楽観的状態を再計算
        _recalculateOptimisticState();
      }

      _emitCurrentState();
    }
  }

  /// サーバー状態との調整
  void _reconcileStates(OnlineGameState authorizedState) {
    // サーバー状態に基づいてペンディングアクションを調整
    final reconciledActions = <PendingAction>[];

    for (final pendingAction in _pendingActions) {
      // サーバー状態がペンディングアクションより新しい場合は破棄
      if (authorizedState.actionTime != null &&
          pendingAction.timestamp.isBefore(authorizedState.actionTime!)) {
        // このアクションは既にサーバーで処理済み
        continue;
      }
      reconciledActions.add(pendingAction);
    }

    _pendingActions.clear();
    _pendingActions.addAll(reconciledActions);

    // 残りのペンディングアクションから楽観的状態を再計算
    if (_pendingActions.isEmpty) {
      _optimisticState = null;
    } else {
      _recalculateOptimisticState();
    }
  }

  /// 楽観的状態の再計算
  void _recalculateOptimisticState() {
    if (_authorizedState == null || _pendingActions.isEmpty) return;

    var state = _authorizedState!;

    for (final action in _pendingActions) {
      state = _calculateOptimisticState(state, action.action);
    }

    _optimisticState = state;
  }

  /// 現在の状態をStreamに送信
  void _emitCurrentState() {
    _stateController.add(currentState);
  }

  /// リソースのクリーンアップ
  void dispose() {
    _retryTimer?.cancel();
    _stateController.close();
    _errorController.close();
  }
}

/// ペンディング中のアクション
class PendingAction {
  final String id;
  final String playerId;
  final String action;
  final DateTime timestamp;
  final OnlineGameState originalState;

  PendingAction({
    required this.id,
    required this.playerId,
    required this.action,
    required this.timestamp,
    required this.originalState,
  });
}

/// 楽観的更新のエラー
class OptimisticError {
  final OptimisticErrorType type;
  final String message;

  OptimisticError({
    required this.type,
    required this.message,
  });
}

enum OptimisticErrorType {
  notYourTurn,
  serverError,
  timeout,
  conflict,
  offline,
}

/// タイムアウト例外
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

/// Listの拡張メソッド
extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}