import 'package:cloud_firestore/cloud_firestore.dart';

/// テーブル呼び出しのステータス
enum TableCallStatus {
  pending,    // 未対応
  inProgress, // 対応中
  resolved,   // 対応済み
}

/// テーブル呼び出しの種類
enum TableCallType {
  waiter,     // スタッフ呼び出し
  order,      // 注文
  bill,       // お会計
  water,      // お水
  other,      // その他
}

/// テーブルからの呼び出しを管理するモデル
class TableCall {
  final String id;
  final String shopId;
  final String tableId;
  final String tableNumber;       // テーブル番号（表示用）
  final String? tableName;        // テーブル名（オプション）
  final TableCallType type;       // 呼び出し種類
  final TableCallStatus status;   // 呼び出しステータス
  final String? message;          // 顧客からのメッセージ（オプション）
  final String? assignedStaffId;  // 対応中のスタッフID
  final String? assignedStaffName;// 対応中のスタッフ名
  final DateTime createdAt;
  final DateTime? respondedAt;    // 対応開始時刻
  final DateTime? resolvedAt;     // 対応完了時刻

  TableCall({
    required this.id,
    required this.shopId,
    required this.tableId,
    required this.tableNumber,
    this.tableName,
    required this.type,
    required this.status,
    this.message,
    this.assignedStaffId,
    this.assignedStaffName,
    required this.createdAt,
    this.respondedAt,
    this.resolvedAt,
  });

  factory TableCall.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    TableCallStatus parseStatus(String? status) {
      switch (status) {
        case 'inProgress':
          return TableCallStatus.inProgress;
        case 'resolved':
          return TableCallStatus.resolved;
        default:
          return TableCallStatus.pending;
      }
    }

    TableCallType parseType(String? type) {
      switch (type) {
        case 'order':
          return TableCallType.order;
        case 'bill':
          return TableCallType.bill;
        case 'water':
          return TableCallType.water;
        case 'other':
          return TableCallType.other;
        default:
          return TableCallType.waiter;
      }
    }

    return TableCall(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      tableId: data['tableId'] ?? '',
      tableNumber: (data['tableNumber'] ?? '').toString(),
      tableName: data['tableName'],
      type: parseType(data['type']),
      status: parseStatus(data['status']),
      message: data['message'],
      assignedStaffId: data['assignedStaffId'],
      assignedStaffName: data['assignedStaffName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    String statusToString(TableCallStatus status) {
      switch (status) {
        case TableCallStatus.pending:
          return 'pending';
        case TableCallStatus.inProgress:
          return 'inProgress';
        case TableCallStatus.resolved:
          return 'resolved';
      }
    }

    String typeToString(TableCallType type) {
      switch (type) {
        case TableCallType.waiter:
          return 'waiter';
        case TableCallType.order:
          return 'order';
        case TableCallType.bill:
          return 'bill';
        case TableCallType.water:
          return 'water';
        case TableCallType.other:
          return 'other';
      }
    }

    return {
      'shopId': shopId,
      'tableId': tableId,
      'tableNumber': tableNumber,
      if (tableName != null) 'tableName': tableName,
      'type': typeToString(type),
      'status': statusToString(status),
      if (message != null) 'message': message,
      if (assignedStaffId != null) 'assignedStaffId': assignedStaffId,
      if (assignedStaffName != null) 'assignedStaffName': assignedStaffName,
      'createdAt': Timestamp.fromDate(createdAt),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
    };
  }

  /// 呼び出し種類の表示名を取得
  String get typeDisplayName {
    switch (type) {
      case TableCallType.waiter:
        return 'スタッフ呼出';
      case TableCallType.order:
        return '注文';
      case TableCallType.bill:
        return 'お会計';
      case TableCallType.water:
        return 'お水';
      case TableCallType.other:
        return 'その他';
    }
  }

  /// ステータスの表示名を取得
  String get statusDisplayName {
    switch (status) {
      case TableCallStatus.pending:
        return '未対応';
      case TableCallStatus.inProgress:
        return '対応中';
      case TableCallStatus.resolved:
        return '対応済';
    }
  }

  /// 表示用のテーブル名を取得
  String get displayTableName => tableName ?? tableNumber;

  /// 呼び出しからの経過時間を取得
  Duration get elapsedTime => DateTime.now().difference(createdAt);

  /// 経過時間の表示文字列を取得
  String get elapsedTimeString {
    final elapsed = elapsedTime;
    if (elapsed.inMinutes < 1) {
      return '${elapsed.inSeconds}秒前';
    } else if (elapsed.inHours < 1) {
      return '${elapsed.inMinutes}分前';
    } else {
      return '${elapsed.inHours}時間${elapsed.inMinutes % 60}分前';
    }
  }

  TableCall copyWith({
    String? id,
    String? shopId,
    String? tableId,
    String? tableNumber,
    String? tableName,
    TableCallType? type,
    TableCallStatus? status,
    String? message,
    String? assignedStaffId,
    String? assignedStaffName,
    DateTime? createdAt,
    DateTime? respondedAt,
    DateTime? resolvedAt,
  }) {
    return TableCall(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      tableId: tableId ?? this.tableId,
      tableNumber: tableNumber ?? this.tableNumber,
      tableName: tableName ?? this.tableName,
      type: type ?? this.type,
      status: status ?? this.status,
      message: message ?? this.message,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
