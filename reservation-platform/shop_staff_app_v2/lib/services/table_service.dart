import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/table.dart';

class TableService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 店舗のテーブル一覧を取得（リアルタイム）
  Stream<List<TableModel>> getTables(String shopId) {
    return _firestore
        .collection('tables')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .orderBy('tableNumber')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TableModel.fromFirestore(doc))
          .toList();
    });
  }

  /// 店舗のテーブル一覧を取得（一度だけ）
  Future<List<TableModel>> getTablesOnce(String shopId) async {
    final snapshot = await _firestore
        .collection('tables')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .orderBy('tableNumber')
        .get();

    return snapshot.docs
        .map((doc) => TableModel.fromFirestore(doc))
        .toList();
  }

  /// 席種別でテーブルをフィルタリング
  Future<List<TableModel>> getTablesBySeatType(
      String shopId, String seatType) async {
    final snapshot = await _firestore
        .collection('tables')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .where('seatType', isEqualTo: seatType)
        .orderBy('sortOrder')
        .orderBy('tableNumber')
        .get();

    return snapshot.docs
        .map((doc) => TableModel.fromFirestore(doc))
        .toList();
  }

  /// 空席のテーブルを取得
  Future<List<TableModel>> getAvailableTables(String shopId) async {
    final snapshot = await _firestore
        .collection('tables')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'available')
        .orderBy('sortOrder')
        .orderBy('tableNumber')
        .get();

    return snapshot.docs
        .map((doc) => TableModel.fromFirestore(doc))
        .toList();
  }

  /// 人数と席種別に基づいて適切なテーブルを推奨
  Future<List<TableModel>> getRecommendedTables({
    required String shopId,
    required int numberOfPeople,
    String? seatType,
    List<String>? requestedFeatures,
  }) async {
    final allTables = await getTablesOnce(shopId);

    // フィルタリング
    var filtered = allTables.where((table) {
      // 人数チェック
      if (numberOfPeople < table.minCapacity ||
          numberOfPeople > table.maxCapacity) {
        return false;
      }

      // 席種別チェック
      if (seatType != null && seatType.isNotEmpty) {
        final tableSeatType = _seatTypeToString(table.seatType);
        if (tableSeatType != seatType) {
          return false;
        }
      }

      // 希望条件チェック（すべての条件を満たすテーブルを優先）
      if (requestedFeatures != null && requestedFeatures.isNotEmpty) {
        final matchCount =
            requestedFeatures.where((f) => table.features.contains(f)).length;
        // 少なくとも1つ以上の条件を満たすテーブルを返す
        if (matchCount == 0 && requestedFeatures.isNotEmpty) {
          return false;
        }
      }

      return true;
    }).toList();

    // 条件に完全にマッチするものを優先してソート
    if (requestedFeatures != null && requestedFeatures.isNotEmpty) {
      filtered.sort((a, b) {
        final aMatchCount =
            requestedFeatures.where((f) => a.features.contains(f)).length;
        final bMatchCount =
            requestedFeatures.where((f) => b.features.contains(f)).length;
        return bMatchCount.compareTo(aMatchCount);
      });
    }

    return filtered;
  }

  /// 結合可能なテーブルの組み合わせを取得
  Future<List<List<TableModel>>> getCombinableTableSets({
    required String shopId,
    required int numberOfPeople,
    String? seatType,
  }) async {
    final allTables = await getTablesOnce(shopId);
    final List<List<TableModel>> combinations = [];

    // 結合可能なテーブルを探す
    for (final table in allTables) {
      if (!table.canCombine || table.combinableWith.isEmpty) continue;

      // 席種別チェック
      if (seatType != null && seatType.isNotEmpty) {
        final tableSeatType = _seatTypeToString(table.seatType);
        if (tableSeatType != seatType) continue;
      }

      // 2テーブル結合
      if (table.combine2MaxCapacity != null &&
          table.combine2MinCapacity != null) {
        if (numberOfPeople >= table.combine2MinCapacity! &&
            numberOfPeople <= table.combine2MaxCapacity!) {
          // 結合相手を探す
          for (final partnerId in table.combinableWith) {
            final partner = allTables.firstWhere(
              (t) => t.id == partnerId,
              orElse: () => table,
            );
            if (partner.id != table.id) {
              // 重複を避ける
              final combination = [table, partner]
                ..sort((a, b) => a.id.compareTo(b.id));
              if (!combinations.any((c) =>
                  c.length == 2 &&
                  c[0].id == combination[0].id &&
                  c[1].id == combination[1].id)) {
                combinations.add(combination);
              }
            }
          }
        }
      }

      // 3テーブル以上の結合
      if (table.combine3PlusMaxCapacity != null &&
          table.combine3PlusMinCapacity != null) {
        if (numberOfPeople >= table.combine3PlusMinCapacity! &&
            numberOfPeople <= table.combine3PlusMaxCapacity!) {
          // 3テーブル以上の組み合わせを探す（シンプルな実装）
          if (table.combinableWith.length >= 2) {
            final combination = [table];
            for (final partnerId in table.combinableWith) {
              final partner = allTables.firstWhere(
                (t) => t.id == partnerId,
                orElse: () => table,
              );
              if (partner.id != table.id) {
                combination.add(partner);
              }
            }
            if (combination.length >= 3) {
              combination.sort((a, b) => a.id.compareTo(b.id));
              if (!combinations.any((c) =>
                  c.length == combination.length &&
                  c.every((t) => combination.any((ct) => ct.id == t.id)))) {
                combinations.add(combination);
              }
            }
          }
        }
      }
    }

    return combinations;
  }

  String _seatTypeToString(SeatType type) {
    switch (type) {
      case SeatType.counter:
        return 'counter';
      case SeatType.table:
        return 'table';
      case SeatType.privateRoom:
        return 'privateRoom';
      case SeatType.semiPrivate:
        return 'semiPrivate';
      case SeatType.tatami:
        return 'tatami';
      case SeatType.terrace:
        return 'terrace';
      case SeatType.other:
        return 'other';
    }
  }
}
