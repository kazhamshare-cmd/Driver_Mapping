import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

/// 未読通知数を監視するプロバイダー
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final authState = ref.watch(authStateProvider);
  final firebaseService = ref.watch(firebaseServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(0);
      }
      // Firebase Serviceから未読通知数を取得
      return firebaseService.watchUnreadNotificationCount(user.uid);
    },
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});
