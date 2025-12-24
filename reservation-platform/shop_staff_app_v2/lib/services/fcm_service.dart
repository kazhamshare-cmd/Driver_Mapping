import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

// ▼ バックグラウンドメッセージハンドラー（必ずクラスの外、トップレベルに定義）
// 注意: バックグラウンドでは印刷はできません（アプリがアクティブでないため）
// 通知音とバイブはOSの通知システムが処理します
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("📩 バックグラウンド通知を受信: ${message.messageId}");
  debugPrint("   タイトル: ${message.notification?.title}");
  debugPrint("   本文: ${message.notification?.body}");
  debugPrint("   データ: ${message.data}");

  // バックグラウンドではOSが自動で通知を表示します
  // 音とバイブはCloud Functionsで設定した通知設定に基づいてOSが処理します
  // 印刷はアプリがフォアグラウンドに戻ってから行う必要があります
}

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final NotificationService _soundService = NotificationService(); // 自作の通知音サービス

  /// 初期化処理
  Future<void> initialize() async {
    // 1. バックグラウンドハンドラーの登録
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. 通知権限のリクエスト
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('🔔 通知許可: OK');
    } else {
      debugPrint('🔕 通知許可: NG');
      return;
    }

    // 2.5. iOS: APNSトークンを取得（これが無いとsubscribeToTopicが失敗する）
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('✅ APNSトークン取得成功');
        } else {
          debugPrint('⏳ APNSトークン取得待機中...');
          // APNSトークンが取得できるまで待つ（最大10秒）
          int attempts = 0;
          while (apnsToken == null && attempts < 10) {
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await _messaging.getAPNSToken();
            attempts++;
          }
          if (apnsToken != null) {
            debugPrint('✅ APNSトークン取得成功（リトライ後）');
          } else {
            debugPrint('❌ APNSトークン取得失敗');
          }
        }
      } catch (e) {
        debugPrint('❌ APNSトークン取得エラー: $e');
      }
    }

    // 3. iOS: フォアグラウンドでの通知表示設定
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, // 通知バナーを出す
      badge: true,
      sound: true, // システム音を鳴らす
    );

    // 4. Android: 通知チャンネルの設定（音が鳴るように重要度をMAXに）
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // Cloud Functionsで指定したIDと一致させる
      '重要なお知らせ', // ユーザーに見える名前
      description: '注文受信などの重要な通知を行います',
      importance: Importance.max, // 最大重要度（音・バイブあり）
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 5. フォアグラウンドでメッセージを受信した時の処理
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 フォアグラウンド通知受信: ${message.notification?.title}');
      
      // 自作の通知音＆バイブレーションを実行
      _soundService.notifyNewOrder();

      // 必要ならローカル通知（バナー）も出す
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: 'launch_background', // アイコン設定（適宜変更）
            ),
          ),
        );
      }
    });
  }

  /// 店舗のトピックを購読
  Future<void> subscribeToShop(String shopId) async {
    try {
      // iOS: APNSトークンが設定されていない場合はスキップ
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken == null) {
        debugPrint('⚠️ APNSトークンが未設定のため、購読をスキップ');
        return;
      }
      await _messaging.subscribeToTopic('shop_$shopId');
      debugPrint('✅ FCM購読成功: shop_$shopId');
    } catch (e) {
      debugPrint('❌ FCM購読失敗: $e');
    }
  }

  /// 購読解除
  Future<void> unsubscribeFromShop(String shopId) async {
    try {
      // iOS: APNSトークンが設定されていない場合はスキップ
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken == null) {
        debugPrint('⚠️ APNSトークンが未設定のため、購読解除をスキップ');
        return;
      }
      await _messaging.unsubscribeFromTopic('shop_$shopId');
      debugPrint('✅ FCM購読解除成功: shop_$shopId');
    } catch (e) {
      debugPrint('❌ FCM購読解除失敗: $e');
      // エラーが発生しても処理を続行（ログアウトをブロックしない）
    }
  }

  /// FCMトークンを取得
  Future<String?> getToken() async {
    try {
      // iOS: APNSトークンが設定されていない場合は待機
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('⏳ APNSトークン待機中...');
          // 少し待ってから再試行
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken == null) {
            debugPrint('⚠️ APNSトークンがまだ取得できません');
            return null;
          }
        }
      }

      final token = await _messaging.getToken();
      if (token != null && token.length > 20) {
        debugPrint('📱 FCMトークン取得: ${token.substring(0, 20)}...');
      } else {
        debugPrint('📱 FCMトークン取得: $token');
      }
      return token;
    } catch (e) {
      debugPrint('❌ FCMトークン取得失敗: $e');
      return null;
    }
  }

  /// FCMトークンをemployeesコレクションに保存
  /// これにより、Cloud Functionsから個別にプッシュ通知を送信できる
  Future<void> saveTokenToEmployee(String employeeId) async {
    try {
      final token = await getToken();
      if (token == null) {
        debugPrint('⚠️ FCMトークンがnullのため、保存をスキップ');
        return;
      }

      final db = FirebaseFirestore.instance;
      await db.collection('employees').doc(employeeId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ FCMトークンをemployeesに保存: $employeeId');

      // トークンの更新を監視
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCMトークンが更新されました');
        await db.collection('employees').doc(employeeId).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ 新しいFCMトークンを保存しました');
      });
    } catch (e) {
      debugPrint('❌ FCMトークン保存失敗: $e');
    }
  }

  /// FCMトークンをemployeesコレクションから削除（ログアウト時）
  Future<void> removeTokenFromEmployee(String employeeId) async {
    try {
      final db = FirebaseFirestore.instance;
      await db.collection('employees').doc(employeeId).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ FCMトークンを削除: $employeeId');
    } catch (e) {
      debugPrint('❌ FCMトークン削除失敗: $e');
    }
  }
}