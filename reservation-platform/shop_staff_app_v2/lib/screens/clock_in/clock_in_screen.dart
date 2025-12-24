import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' show cos, sqrt, asin;
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/fcm_service.dart';

class ClockInScreen extends ConsumerStatefulWidget {
  const ClockInScreen({super.key});

  @override
  ConsumerState<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends ConsumerState<ClockInScreen> {
  bool _isLoading = false;
  Position? _currentPosition;
  bool _isWithinRange = false;
  String? _errorMessage;
  double _distanceToShop = 0.0;

  // GPS範囲チェック（デフォルト100m）
  final double _gpsRange = 100.0;

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndFetch();
  }

  /// 位置情報権限を確認して取得
  Future<void> _checkLocationPermissionAndFetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('📍 GPS取得開始');

      // 位置情報サービスが有効か確認
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('📍 位置情報サービス: ${serviceEnabled ? "有効" : "無効"}');
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = '位置情報サービスが無効です。設定で有効にしてください。';
          _isLoading = false;
        });
        return;
      }

      // 位置情報権限を確認
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 現在の権限: $permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('📍 権限リクエスト後: $permission');
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = '位置情報の権限が拒否されました。';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = '位置情報の権限が永久に拒否されています。設定から許可してください。';
          _isLoading = false;
        });
        return;
      }

      debugPrint('📍 高精度GPS取得中...');
      // 現在位置を取得（最高精度）
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation, // 最高精度
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint('📍 GPS取得成功:');
      debugPrint('  緯度: ${position.latitude}');
      debugPrint('  経度: ${position.longitude}');
      debugPrint('  精度: ${position.accuracy}m');
      debugPrint('  高度: ${position.altitude}m');
      debugPrint('  速度: ${position.speed}m/s');
      debugPrint('  方角: ${position.heading}°');
      debugPrint('  取得時刻: ${position.timestamp}');

      setState(() {
        _currentPosition = position;
      });

      // 店舗との距離を計算
      await _calculateDistanceToShop();
    } catch (e) {
      debugPrint('❌ GPS取得エラー: $e');
      setState(() {
        _errorMessage = '位置情報の取得に失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  /// 店舗との距離を計算
  Future<void> _calculateDistanceToShop() async {
    final staffUser = await ref.read(staffUserProvider.future);
    final shop = await ref.read(shopProvider.future);

    if (staffUser == null || shop == null || _currentPosition == null) {
      debugPrint('❌ 距離計算スキップ: staffUser=$staffUser, shop=$shop, position=$_currentPosition');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // 店舗の位置情報を取得（Firestoreから）
    final shopLatitude = shop.latitude ?? 0.0;
    final shopLongitude = shop.longitude ?? 0.0;

    debugPrint('🏪 店舗位置情報:');
    debugPrint('  店舗名: ${shop.shopName}');
    debugPrint('  緯度: $shopLatitude');
    debugPrint('  経度: $shopLongitude');

    if (shopLatitude == 0.0 && shopLongitude == 0.0) {
      debugPrint('❌ 店舗の位置情報が未設定');
      setState(() {
        _errorMessage = '店舗の位置情報が設定されていません。管理者に連絡してください。';
        _isLoading = false;
      });
      return;
    }

    // Haversine formula で距離を計算（メートル単位）
    final distance = _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      shopLatitude,
      shopLongitude,
    );

    debugPrint('📏 距離計算結果:');
    debugPrint('  現在地 → 店舗: ${distance.toStringAsFixed(2)}m');
    debugPrint('  許容範囲: ${_gpsRange}m');
    debugPrint('  範囲内: ${distance <= _gpsRange ? "YES ✅" : "NO ❌"}');

    setState(() {
      _distanceToShop = distance;
      _isWithinRange = distance <= _gpsRange;
      _isLoading = false;
    });
  }

  /// Haversine formulaで2点間の距離を計算（メートル）
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // 2 * R(6371km) * 1000m
  }

  /// 出勤処理
  Future<void> _clockIn() async {
    final staffUser = await ref.read(staffUserProvider.future);
    final shop = await ref.read(shopProvider.future);

    if (staffUser == null || shop == null) {
      _showSnackBar('ユーザー情報または店舗情報が取得できません');
      return;
    }

    // GPS範囲チェック
    if (!_isWithinRange) {
      _showSnackBar('店舗の範囲内にいる必要があります（${_gpsRange}m以内）');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final db = FirebaseFirestore.instance;

      // 勤怠レコードを作成
      final attendanceRef = await db.collection('attendances').add({
        'shopId': shop.id,
        'employeeId': staffUser.id,
        'workDate': Timestamp.now(),
        'clockIn': {
          'timestamp': Timestamp.now(),
          'location': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                  'accuracy': _currentPosition!.accuracy,
                }
              : null,
          'deviceInfo': 'Flutter Staff App',
        },
        'status': 'working',
        'isLate': false,
        'lateMinutes': 0,
        'isEarlyLeave': false,
        'earlyLeaveMinutes': 0,
        'breaks': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // スタッフの勤務状態を更新
      await db.collection('employees').doc(staffUser.id).update({
        'currentWorkStatus': {
          'isWorking': true,
          'currentAttendanceId': attendanceRef.id,
          'clockInTime': Timestamp.now(),
          'location': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                }
              : null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // プロバイダーを無効化して再取得
      ref.invalidate(staffUserProvider);

      // FCMトピックを購読（出勤時に注文通知を受け取る）
      final fcmService = FcmService();
      await fcmService.subscribeToShop(shop.id);
      debugPrint('✅ 出勤時FCM購読: shop_${shop.id}');

      _showSnackBar('出勤しました');

      // ホーム画面に戻る
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      _showSnackBar('出勤処理に失敗しました: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 退勤処理
  Future<void> _clockOut() async {
    final staffUser = await ref.read(staffUserProvider.future);

    if (staffUser == null) {
      _showSnackBar('ユーザー情報が取得できません');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final db = FirebaseFirestore.instance;

      // currentWorkStatusから勤怠IDを取得
      final employeeDoc = await db.collection('employees').doc(staffUser.id).get();
      final currentWorkStatus = employeeDoc.data()?['currentWorkStatus'] as Map<String, dynamic>?;
      final attendanceId = currentWorkStatus?['currentAttendanceId'] as String?;

      if (attendanceId == null) {
        _showSnackBar('出勤記録が見つかりません');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 勤怠レコードを更新
      await db.collection('attendances').doc(attendanceId).update({
        'clockOut': {
          'timestamp': Timestamp.now(),
          'location': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                  'accuracy': _currentPosition!.accuracy,
                }
              : null,
          'deviceInfo': 'Flutter Staff App',
        },
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // スタッフの勤務状態を更新
      await db.collection('employees').doc(staffUser.id).update({
        'currentWorkStatus': {
          'isWorking': false,
          'currentAttendanceId': null,
          'clockInTime': null,
          'location': null,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // プロバイダーを無効化して再取得
      ref.invalidate(staffUserProvider);

      // FCMトピックの購読を解除（退勤時は注文通知を受け取らない）
      final fcmService = FcmService();
      await fcmService.unsubscribeFromShop(staffUser.shopId);
      debugPrint('✅ 退勤時FCM購読解除: shop_${staffUser.shopId}');

      _showSnackBar('退勤しました');

      // ホーム画面に戻る
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      _showSnackBar('退勤処理に失敗しました: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffUserAsync = ref.watch(staffUserProvider);
    final t = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/');
          },
        ),
        title: Text(t.text('clockInOut')),
      ),
      body: staffUserAsync.when(
        data: (staffUser) {
          if (staffUser == null) {
            return Center(child: Text(t.text('userInfoNotFound')));
          }

          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth > 600;
          final contentMaxWidth = isTablet ? 600.0 : double.infinity;
          final iconSize = isTablet ? 64.0 : 48.0;
          final titleFontSize = isTablet ? 24.0 : 20.0;
          final subtitleFontSize = isTablet ? 16.0 : 14.0;
          final cardPadding = isTablet ? 24.0 : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 現在の状態
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(cardPadding),
                    child: Row(
                      children: [
                        Icon(
                          staffUser.isWorking ? Icons.check_circle : Icons.cancel,
                          color: staffUser.isWorking ? Colors.green : Colors.grey,
                          size: iconSize,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staffUser.isWorking ? t.text('clockedIn') : t.text('clockedOut'),
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${staffUser.lastName} ${staffUser.firstName}',
                                style: TextStyle(fontSize: subtitleFontSize, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // GPS情報
                if (!staffUser.isWorking) ...[
                  Text(
                    t.text('locationInfo'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (_errorMessage != null)
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            )
                          else if (_currentPosition != null) ...[
                            _buildInfoRow(t.text('latitude'), _currentPosition!.latitude.toStringAsFixed(6)),
                            _buildInfoRow(t.text('longitude'), _currentPosition!.longitude.toStringAsFixed(6)),
                            _buildInfoRow(t.text('accuracy'), '${_currentPosition!.accuracy.toStringAsFixed(1)}m'),
                            _buildInfoRow(t.text('distanceToShop'), '${_distanceToShop.toStringAsFixed(1)}m'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isWithinRange ? Colors.green[50] : Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isWithinRange ? Icons.check_circle : Icons.error,
                                    color: _isWithinRange ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _isWithinRange
                                          ? t.text('withinShopRange')
                                          : '${t.text('outsideWorkArea')} (${_gpsRange}m)',
                                      style: TextStyle(
                                        color: _isWithinRange ? Colors.green[900] : Colors.red[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ボタン
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : staffUser.isWorking
                            ? _clockOut
                            : _isWithinRange
                                ? _clockIn
                                : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: staffUser.isWorking ? Colors.orange : Colors.green,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            staffUser.isWorking ? t.text('clockOutButton') : t.text('clockInButton'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('${t.text('error')}: $error'),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
