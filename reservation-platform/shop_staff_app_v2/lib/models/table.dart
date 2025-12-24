import 'package:cloud_firestore/cloud_firestore.dart';

enum TableStatus {
  available,  // 空席
  occupied,   // 使用中
  reserved,   // 予約済
  cleaning,   // 清掃中
}

/// 席種別
enum SeatType {
  counter,     // カウンター
  table,       // テーブル席
  privateRoom, // 個室
  semiPrivate, // 半個室
  tatami,      // 座敷
  terrace,     // テラス
  other,       // その他
}

class TableModel {
  final String id;
  final String shopId;
  final String tableNumber;
  final String? tableName;           // 表示名（任意）
  final SeatType seatType;           // 席種別
  final int minCapacity;             // 最小人数
  final int maxCapacity;             // 最大人数（旧: capacity）
  final int capacity;                // 後方互換性のため残す（maxCapacityと同じ値）
  final List<String> features;       // 特徴: ['smoking', 'window', 'kids', 'wheelchair']
  final bool isActive;
  final TableStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? currentSessionId;
  final DateTime? sessionStartedAt;
  final String? groupId;             // テーブル結合用グループID（使用中の結合グループ）

  // 結合設定
  final bool canCombine;             // 結合可能か
  final List<String> combinableWith; // 結合可能なテーブルID
  final int? combine2MaxCapacity;    // 2結合時の最大人数
  final int? combine2MinCapacity;    // 2結合時の最小人数
  final int? combine3PlusMaxCapacity; // 3結合以上時の最大人数
  final int? combine3PlusMinCapacity; // 3結合以上時の最小人数

  // カウンター用（連続席管理）
  final int? totalSeats;             // カウンターの総席数
  final int? seatNumber;             // カウンター内の席番号

  // 並び順
  final int sortOrder;

  TableModel({
    required this.id,
    required this.shopId,
    required this.tableNumber,
    this.tableName,
    this.seatType = SeatType.table,
    this.minCapacity = 1,
    required this.maxCapacity,
    required this.capacity,
    this.features = const [],
    required this.isActive,
    this.status = TableStatus.available,
    required this.createdAt,
    required this.updatedAt,
    this.currentSessionId,
    this.sessionStartedAt,
    this.groupId,
    this.canCombine = false,
    this.combinableWith = const [],
    this.combine2MaxCapacity,
    this.combine2MinCapacity,
    this.combine3PlusMaxCapacity,
    this.combine3PlusMinCapacity,
    this.totalSeats,
    this.seatNumber,
    this.sortOrder = 0,
  });

  factory TableModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    TableStatus parseStatus(String? status) {
      switch (status) {
        case 'occupied':
          return TableStatus.occupied;
        case 'reserved':
          return TableStatus.reserved;
        case 'cleaning':
          return TableStatus.cleaning;
        default:
          return TableStatus.available;
      }
    }

    SeatType parseSeatType(String? type) {
      switch (type) {
        case 'counter':
          return SeatType.counter;
        case 'table':
          return SeatType.table;
        case 'privateRoom':
        case 'private':
          return SeatType.privateRoom;
        case 'semiPrivate':
          return SeatType.semiPrivate;
        case 'tatami':
          return SeatType.tatami;
        case 'terrace':
          return SeatType.terrace;
        default:
          return SeatType.table;
      }
    }

    // capacityはintまたはnullで保存されている可能性があるため対応
    final rawMaxCap = data['maxCapacity'] ?? data['capacity'];
    final maxCap = rawMaxCap is int ? rawMaxCap : (rawMaxCap != null ? int.tryParse(rawMaxCap.toString()) ?? 0 : 0);

    // tableNumberはintまたはStringで保存されている可能性があるため、両方に対応
    final rawTableNumber = data['tableNumber'];
    final tableNumber = rawTableNumber is int
        ? rawTableNumber.toString()
        : (rawTableNumber ?? '').toString();

    return TableModel(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      tableNumber: tableNumber,
      tableName: data['tableName'],
      seatType: parseSeatType(data['seatType']),
      minCapacity: data['minCapacity'] ?? 1,
      maxCapacity: maxCap,
      capacity: maxCap, // 後方互換性
      features: List<String>.from(data['features'] ?? []),
      isActive: data['isActive'] ?? true,
      status: parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentSessionId: data['currentSessionId'],
      sessionStartedAt: (data['sessionStartedAt'] as Timestamp?)?.toDate(),
      groupId: data['groupId'],
      canCombine: data['canCombine'] ?? false,
      combinableWith: List<String>.from(data['combinableWith'] ?? []),
      combine2MaxCapacity: data['combine2MaxCapacity'],
      combine2MinCapacity: data['combine2MinCapacity'],
      combine3PlusMaxCapacity: data['combine3PlusMaxCapacity'],
      combine3PlusMinCapacity: data['combine3PlusMinCapacity'],
      totalSeats: data['totalSeats'],
      seatNumber: data['seatNumber'],
      sortOrder: data['sortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    String statusToString(TableStatus status) {
      switch (status) {
        case TableStatus.available:
          return 'available';
        case TableStatus.occupied:
          return 'occupied';
        case TableStatus.reserved:
          return 'reserved';
        case TableStatus.cleaning:
          return 'cleaning';
      }
    }

    String seatTypeToString(SeatType type) {
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

    return {
      'shopId': shopId,
      'tableNumber': tableNumber,
      'tableName': tableName,
      'seatType': seatTypeToString(seatType),
      'minCapacity': minCapacity,
      'maxCapacity': maxCapacity,
      'capacity': maxCapacity, // 後方互換性のため両方保存
      'features': features,
      'isActive': isActive,
      'status': statusToString(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'canCombine': canCombine,
      'combinableWith': combinableWith,
      if (combine2MaxCapacity != null) 'combine2MaxCapacity': combine2MaxCapacity,
      if (combine2MinCapacity != null) 'combine2MinCapacity': combine2MinCapacity,
      if (combine3PlusMaxCapacity != null) 'combine3PlusMaxCapacity': combine3PlusMaxCapacity,
      if (combine3PlusMinCapacity != null) 'combine3PlusMinCapacity': combine3PlusMinCapacity,
      if (totalSeats != null) 'totalSeats': totalSeats,
      if (seatNumber != null) 'seatNumber': seatNumber,
      'sortOrder': sortOrder,
    };
  }

  /// 席種別の表示名を取得
  String get seatTypeName {
    switch (seatType) {
      case SeatType.counter:
        return 'カウンター';
      case SeatType.table:
        return 'テーブル席';
      case SeatType.privateRoom:
        return '個室';
      case SeatType.semiPrivate:
        return '半個室';
      case SeatType.tatami:
        return '座敷';
      case SeatType.terrace:
        return 'テラス';
      case SeatType.other:
        return 'その他';
    }
  }

  /// 表示用の名前を取得（tableName があればそれを、なければ tableNumber）
  String get displayName => tableName ?? tableNumber;

  /// 特徴の表示名リストを取得
  List<String> get featureNames {
    return features.map((f) {
      switch (f) {
        case 'smoking':
          return '喫煙可';
        case 'window':
          return '窓際';
        case 'kids':
          return '子連れOK';
        case 'wheelchair':
          return '車椅子対応';
        case 'horigotatsu':
          return '掘りごたつ';
        default:
          return f;
      }
    }).toList();
  }

  /// copyWithメソッド
  TableModel copyWith({
    String? id,
    String? shopId,
    String? tableNumber,
    String? tableName,
    SeatType? seatType,
    int? minCapacity,
    int? maxCapacity,
    int? capacity,
    List<String>? features,
    bool? isActive,
    TableStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? currentSessionId,
    DateTime? sessionStartedAt,
    String? groupId,
    bool? canCombine,
    List<String>? combinableWith,
    int? combine2MaxCapacity,
    int? combine2MinCapacity,
    int? combine3PlusMaxCapacity,
    int? combine3PlusMinCapacity,
    int? totalSeats,
    int? seatNumber,
    int? sortOrder,
  }) {
    return TableModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      tableNumber: tableNumber ?? this.tableNumber,
      tableName: tableName ?? this.tableName,
      seatType: seatType ?? this.seatType,
      minCapacity: minCapacity ?? this.minCapacity,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      capacity: capacity ?? this.capacity,
      features: features ?? this.features,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
      groupId: groupId ?? this.groupId,
      canCombine: canCombine ?? this.canCombine,
      combinableWith: combinableWith ?? this.combinableWith,
      combine2MaxCapacity: combine2MaxCapacity ?? this.combine2MaxCapacity,
      combine2MinCapacity: combine2MinCapacity ?? this.combine2MinCapacity,
      combine3PlusMaxCapacity: combine3PlusMaxCapacity ?? this.combine3PlusMaxCapacity,
      combine3PlusMinCapacity: combine3PlusMinCapacity ?? this.combine3PlusMinCapacity,
      totalSeats: totalSeats ?? this.totalSeats,
      seatNumber: seatNumber ?? this.seatNumber,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
