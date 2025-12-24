class PrinterConfig {
  final String id;
  final String name;
  final PrinterConnectionType connectionType;
  final String? ipAddress;        // IP接続用
  final int port;                  // IP接続用
  final String? bluetoothAddress;  // Bluetooth接続用（MACアドレス）
  final String? bluetoothName;     // Bluetooth接続用（デバイス名）
  final String? starPortName;      // Star SDK用ポート名（BT:XX:XX:XX形式）
  final PrinterModel model;        // プリンターモデル（mPOP, SII等）
  final bool autoprint;

  // === 用途設定 ===
  final bool isReceiptPrinter;     // レジ（会計レシート）用プリンター
  final bool hasDrawer;            // キャッシュドロワー内蔵（レジのみ）
  final Set<String> categoryIds;   // 印刷対象カテゴリID（カテゴリープリンター用）
                                   // 空の場合は全カテゴリ対象

  PrinterConfig({
    required this.id,
    required this.name,
    required this.connectionType,
    this.ipAddress,
    this.port = 9100,
    this.bluetoothAddress,
    this.bluetoothName,
    this.starPortName,
    this.model = PrinterModel.generic,
    this.autoprint = true,
    this.isReceiptPrinter = false,
    this.hasDrawer = false,
    Set<String>? categoryIds,
  }) : categoryIds = categoryIds ?? {};

  factory PrinterConfig.fromMap(Map<String, dynamic> map, String id) {
    // カテゴリIDを読み込み
    Set<String> categoryIds = {};
    if (map['categoryIds'] != null && map['categoryIds'] is List) {
      categoryIds = (map['categoryIds'] as List).cast<String>().toSet();
    }

    return PrinterConfig(
      id: id,
      name: map['name'] ?? '',
      connectionType: PrinterConnectionType.values.firstWhere(
        (e) => e.toString() == 'PrinterConnectionType.${map['connectionType']}',
        orElse: () => PrinterConnectionType.network,
      ),
      ipAddress: map['ipAddress'],
      port: map['port'] ?? 9100,
      bluetoothAddress: map['bluetoothAddress'],
      bluetoothName: map['bluetoothName'],
      starPortName: map['starPortName'],
      model: PrinterModel.values.firstWhere(
        (e) => e.toString() == 'PrinterModel.${map['model']}',
        orElse: () => PrinterModel.generic,
      ),
      autoprint: map['autoprint'] ?? true,
      isReceiptPrinter: map['isReceiptPrinter'] ?? false,
      hasDrawer: map['hasDrawer'] ?? false,
      categoryIds: categoryIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'connectionType': connectionType.toString().split('.').last,
      'ipAddress': ipAddress,
      'port': port,
      'bluetoothAddress': bluetoothAddress,
      'bluetoothName': bluetoothName,
      'starPortName': starPortName,
      'model': model.toString().split('.').last,
      'autoprint': autoprint,
      'isReceiptPrinter': isReceiptPrinter,
      'hasDrawer': hasDrawer,
      'categoryIds': categoryIds.toList(),
    };
  }

  PrinterConfig copyWith({
    String? name,
    PrinterConnectionType? connectionType,
    String? ipAddress,
    int? port,
    String? bluetoothAddress,
    String? bluetoothName,
    String? starPortName,
    PrinterModel? model,
    bool? autoprint,
    bool? isReceiptPrinter,
    bool? hasDrawer,
    Set<String>? categoryIds,
  }) {
    return PrinterConfig(
      id: id,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
      bluetoothName: bluetoothName ?? this.bluetoothName,
      starPortName: starPortName ?? this.starPortName,
      model: model ?? this.model,
      autoprint: autoprint ?? this.autoprint,
      isReceiptPrinter: isReceiptPrinter ?? this.isReceiptPrinter,
      hasDrawer: hasDrawer ?? this.hasDrawer,
      categoryIds: categoryIds ?? this.categoryIds,
    );
  }

  /// 接続先の表示文字列
  String get connectionInfo {
    switch (connectionType) {
      case PrinterConnectionType.network:
        return '$ipAddress:$port';
      case PrinterConnectionType.bluetooth:
        return bluetoothName ?? bluetoothAddress ?? 'Unknown';
    }
  }

  /// 指定カテゴリの印刷対象かどうか
  /// categoryIdsが空の場合は全カテゴリ対象
  bool shouldPrintCategory(String? categoryId) {
    if (categoryIds.isEmpty) return true;
    if (categoryId == null) return true;
    return categoryIds.contains(categoryId);
  }

  /// カテゴリープリンターかどうか
  bool get isKitchenPrinter => !isReceiptPrinter || categoryIds.isNotEmpty;

  /// 用途の表示文字列
  String get usageLabel {
    final List<String> labels = [];
    if (isReceiptPrinter) {
      labels.add('レジ');
      if (hasDrawer) labels.add('ドロワー');
    }
    if (categoryIds.isNotEmpty) {
      labels.add('伝票(${categoryIds.length}カテゴリ)');
    } else if (!isReceiptPrinter) {
      labels.add('伝票(全カテゴリ)');
    }
    return labels.join(' / ');
  }
}

/// プリンターの接続方式
enum PrinterConnectionType {
  network,   // Wi-Fi/LAN（IP接続）
  bluetooth, // Bluetooth
}

/// プリンターのモデル/メーカー
enum PrinterModel {
  generic,     // 汎用ESC/POS（SII等）
  starMpop,    // Star mPOP（Bluetooth、ドロワー内蔵）
  starTsp100,  // Star TSP100シリーズ
  epsonTm,     // EPSON TM-T系
}
