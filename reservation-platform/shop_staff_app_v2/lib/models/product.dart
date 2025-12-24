import 'package:cloud_firestore/cloud_firestore.dart';

class ProductCategory {
  final String id;
  final String shopId;
  final String? code;  // カテゴリコード（例: "001"）
  final String name;
  final String? nameEn;
  final String? nameTh;
  final String? nameZhTw;
  final String? nameKo;
  final String? description;
  final String? imageUrl;
  final String displayStatus; // 'available', 'hidden', 'soldout'
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductCategory({
    required this.id,
    required this.shopId,
    this.code,
    required this.name,
    this.nameEn,
    this.nameTh,
    this.nameZhTw,
    this.nameKo,
    this.description,
    this.imageUrl,
    required this.displayStatus,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// コード付き表示名を取得（例: "[001] ドリンク"）
  String getDisplayNameWithCode(String languageCode) {
    final localizedName = getLocalizedName(languageCode);
    if (code != null && code!.isNotEmpty) {
      return '[$code] $localizedName';
    }
    return localizedName;
  }

  factory ProductCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductCategory(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      code: data['code'],
      name: data['name'] ?? '',
      nameEn: data['nameEn'],
      nameTh: data['nameTh'],
      nameZhTw: data['nameZhTw'],
      nameKo: data['nameKo'],
      description: data['description'],
      imageUrl: data['imageUrl'],
      displayStatus: data['displayStatus'] ?? 'available',
      sortOrder: data['sortOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// 言語コードに応じたカテゴリ名を取得
  String getLocalizedName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return nameEn?.isNotEmpty == true ? nameEn! : name;
      case 'th':
        return nameTh?.isNotEmpty == true ? nameTh! : name;
      case 'zh_TW':
        return nameZhTw?.isNotEmpty == true ? nameZhTw! : name;
      case 'ko':
        return nameKo?.isNotEmpty == true ? nameKo! : name;
      default:
        return name;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'code': code,
      'name': name,
      'nameEn': nameEn,
      'nameTh': nameTh,
      'nameZhTw': nameZhTw,
      'nameKo': nameKo,
      'description': description,
      'imageUrl': imageUrl,
      'displayStatus': displayStatus,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class ProductOption {
  final String id;
  final String shopId;
  final String name;
  final String? nameEn;
  final String? nameTh;
  final String? nameZhTw;
  final String? nameKo;
  final String type; // 'single' or 'multiple'
  final bool required;
  final String displayStatus;
  final List<ProductOptionChoice> choices;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductOption({
    required this.id,
    required this.shopId,
    required this.name,
    this.nameEn,
    this.nameTh,
    this.nameZhTw,
    this.nameKo,
    required this.type,
    required this.required,
    required this.displayStatus,
    required this.choices,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductOption.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final choicesData = data['choices'] as List<dynamic>? ?? [];
    final choices = choicesData
        .map((c) => ProductOptionChoice.fromMap(c as Map<String, dynamic>))
        .toList();

    return ProductOption(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      name: data['name'] ?? '',
      nameEn: data['nameEn'],
      nameTh: data['nameTh'],
      nameZhTw: data['nameZhTw'],
      nameKo: data['nameKo'],
      type: data['type'] ?? 'single',
      required: data['required'] ?? false,
      displayStatus: data['displayStatus'] ?? 'available',
      choices: choices,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'name': name,
      'nameEn': nameEn,
      'nameTh': nameTh,
      'nameZhTw': nameZhTw,
      'nameKo': nameKo,
      'type': type,
      'required': required,
      'displayStatus': displayStatus,
      'choices': choices.map((c) => c.toMap()).toList(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class ProductOptionChoice {
  final String id;
  final String? code;  // オプション選択肢コード（例: "001"）
  final String name;
  final String? nameEn;
  final String? nameTh;
  final String? nameZhTw;
  final String? nameKo;
  final double price;
  final String? imageUrl;

  ProductOptionChoice({
    required this.id,
    this.code,
    required this.name,
    this.nameEn,
    this.nameTh,
    this.nameZhTw,
    this.nameKo,
    required this.price,
    this.imageUrl,
  });

  factory ProductOptionChoice.fromMap(Map<String, dynamic> data) {
    return ProductOptionChoice(
      id: data['id'] ?? '',
      code: data['code'],
      name: data['name'] ?? '',
      nameEn: data['nameEn'],
      nameTh: data['nameTh'],
      nameZhTw: data['nameZhTw'],
      nameKo: data['nameKo'],
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'nameEn': nameEn,
      'nameTh': nameTh,
      'nameZhTw': nameZhTw,
      'nameKo': nameKo,
      'price': price,
      'imageUrl': imageUrl,
    };
  }
}

/// 時間帯設定
class AvailableTimeSlot {
  final String type; // 'always' or 'specific_times'
  final List<TimeSlotRange>? timeSlots;

  AvailableTimeSlot({
    required this.type,
    this.timeSlots,
  });

  factory AvailableTimeSlot.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return AvailableTimeSlot(type: 'always');
    }
    final slotsData = data['timeSlots'] as List<dynamic>? ?? [];
    return AvailableTimeSlot(
      type: data['type'] ?? 'always',
      timeSlots: slotsData.map((s) => TimeSlotRange.fromMap(s as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (timeSlots != null) 'timeSlots': timeSlots!.map((s) => s.toMap()).toList(),
    };
  }
}

class TimeSlotRange {
  final String start;
  final String end;
  final String? name;

  TimeSlotRange({
    required this.start,
    required this.end,
    this.name,
  });

  factory TimeSlotRange.fromMap(Map<String, dynamic> data) {
    return TimeSlotRange(
      start: data['start'] ?? '00:00',
      end: data['end'] ?? '23:59',
      name: data['name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
      if (name != null) 'name': name,
    };
  }
}

/// 原価設定
class CostSettings {
  final bool hasCost;
  final double cost;
  final double backRate;
  final String backType; // 'performer'(施術者), 'referrer'(紹介者), 'both'(両方)

  CostSettings({
    this.hasCost = false,
    this.cost = 0,
    this.backRate = 0,
    this.backType = 'performer',
  });

  factory CostSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return CostSettings();
    }
    return CostSettings(
      hasCost: data['hasCost'] ?? false,
      cost: (data['cost'] ?? 0).toDouble(),
      backRate: (data['backRate'] ?? 0).toDouble(),
      backType: data['backType'] ?? 'performer',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hasCost': hasCost,
      'cost': cost,
      'backRate': backRate,
      'backType': backType,
    };
  }
}

/// 商品表示タグ
class ProductTags {
  final bool isNew;           // 新商品
  final bool isRecommended;   // おすすめ
  final bool isPopular;       // 大人気
  final bool isLimitedTime;   // 期間限定
  final bool isLimitedQty;    // 数量限定
  final bool isOrganic;       // オーガニック
  final bool isSpicy;         // 辛い
  final bool isVegetarian;    // ベジタリアン

  ProductTags({
    this.isNew = false,
    this.isRecommended = false,
    this.isPopular = false,
    this.isLimitedTime = false,
    this.isLimitedQty = false,
    this.isOrganic = false,
    this.isSpicy = false,
    this.isVegetarian = false,
  });

  factory ProductTags.fromMap(Map<String, dynamic>? data) {
    if (data == null) return ProductTags();
    return ProductTags(
      isNew: data['isNew'] ?? false,
      isRecommended: data['isRecommended'] ?? false,
      isPopular: data['isPopular'] ?? false,
      isLimitedTime: data['isLimitedTime'] ?? false,
      isLimitedQty: data['isLimitedQty'] ?? false,
      isOrganic: data['isOrganic'] ?? false,
      isSpicy: data['isSpicy'] ?? false,
      isVegetarian: data['isVegetarian'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isNew': isNew,
      'isRecommended': isRecommended,
      'isPopular': isPopular,
      'isLimitedTime': isLimitedTime,
      'isLimitedQty': isLimitedQty,
      'isOrganic': isOrganic,
      'isSpicy': isSpicy,
      'isVegetarian': isVegetarian,
    };
  }

  /// 有効なタグがあるかどうか
  bool get hasAnyTag => isNew || isRecommended || isPopular ||
      isLimitedTime || isLimitedQty || isOrganic || isSpicy || isVegetarian;

  /// タグのリストを取得（多言語対応）
  List<Map<String, String>> getTagList(String languageCode) {
    final tags = <Map<String, String>>[];
    if (isNew) tags.add(_getTagInfo('new', languageCode));
    if (isRecommended) tags.add(_getTagInfo('recommended', languageCode));
    if (isPopular) tags.add(_getTagInfo('popular', languageCode));
    if (isLimitedTime) tags.add(_getTagInfo('limitedTime', languageCode));
    if (isLimitedQty) tags.add(_getTagInfo('limitedQty', languageCode));
    if (isOrganic) tags.add(_getTagInfo('organic', languageCode));
    if (isSpicy) tags.add(_getTagInfo('spicy', languageCode));
    if (isVegetarian) tags.add(_getTagInfo('vegetarian', languageCode));
    return tags;
  }

  Map<String, String> _getTagInfo(String tag, String lang) {
    final labels = {
      'new': {'ja': '新商品', 'en': 'NEW', 'th': 'ใหม่', 'zh_TW': '新品', 'ko': '신상품'},
      'recommended': {'ja': 'おすすめ', 'en': 'Recommended', 'th': 'แนะนำ', 'zh_TW': '推薦', 'ko': '추천'},
      'popular': {'ja': '大人気', 'en': 'Popular', 'th': 'ยอดนิยม', 'zh_TW': '人氣', 'ko': '인기'},
      'limitedTime': {'ja': '期間限定', 'en': 'Limited Time', 'th': 'จำกัดเวลา', 'zh_TW': '限時', 'ko': '기간한정'},
      'limitedQty': {'ja': '数量限定', 'en': 'Limited Qty', 'th': 'จำนวนจำกัด', 'zh_TW': '限量', 'ko': '수량한정'},
      'organic': {'ja': 'オーガニック', 'en': 'Organic', 'th': 'ออร์แกนิก', 'zh_TW': '有機', 'ko': '유기농'},
      'spicy': {'ja': '辛い', 'en': 'Spicy', 'th': 'เผ็ด', 'zh_TW': '辣', 'ko': '매운'},
      'vegetarian': {'ja': 'ベジタリアン', 'en': 'Vegetarian', 'th': 'มังสวิรัติ', 'zh_TW': '素食', 'ko': '채식'},
    };
    final colors = {
      'new': '#FF6B6B',
      'recommended': '#4ECDC4',
      'popular': '#FFE66D',
      'limitedTime': '#FF8E53',
      'limitedQty': '#A855F7',
      'organic': '#22C55E',
      'spicy': '#EF4444',
      'vegetarian': '#10B981',
    };
    return {
      'label': labels[tag]?[lang] ?? labels[tag]?['ja'] ?? tag,
      'color': colors[tag] ?? '#6B7280',
    };
  }
}

/// 割引設定
class DiscountSettings {
  final bool hasDiscount;       // 割引を有効にするか
  final String discountType;    // 'amount' (金額) or 'percent' (パーセント)
  final double discountValue;   // 割引額またはパーセント
  final DateTime? startDate;    // 割引開始日（null=即時）
  final DateTime? endDate;      // 割引終了日（null=無期限）

  DiscountSettings({
    this.hasDiscount = false,
    this.discountType = 'amount',
    this.discountValue = 0,
    this.startDate,
    this.endDate,
  });

  factory DiscountSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return DiscountSettings();
    return DiscountSettings(
      hasDiscount: data['hasDiscount'] ?? false,
      discountType: data['discountType'] ?? 'amount',
      discountValue: (data['discountValue'] ?? 0).toDouble(),
      startDate: data['startDate'] != null
          ? (data['startDate'] as dynamic).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hasDiscount': hasDiscount,
      'discountType': discountType,
      'discountValue': discountValue,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
  }

  /// 現在割引が有効かどうか
  bool get isCurrentlyActive {
    if (!hasDiscount) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  /// 割引後の価格を計算
  double calculateDiscountedPrice(double originalPrice) {
    if (!isCurrentlyActive) return originalPrice;
    if (discountType == 'percent') {
      return originalPrice * (1 - discountValue / 100);
    } else {
      return (originalPrice - discountValue).clamp(0, originalPrice);
    }
  }

  /// 割引額を計算
  double calculateDiscountAmount(double originalPrice) {
    if (!isCurrentlyActive) return 0;
    if (discountType == 'percent') {
      return originalPrice * discountValue / 100;
    } else {
      return discountValue.clamp(0, originalPrice);
    }
  }

  /// 割引表示テキスト
  String getDiscountLabel() {
    if (!hasDiscount) return '';
    if (discountType == 'percent') {
      return '${discountValue.toInt()}%OFF';
    } else {
      return '¥${discountValue.toInt()}OFF';
    }
  }
}

/// 商品タイプ
enum ProductType {
  service,      // 施術、コース、席利用（時間を消費）
  goods,        // 物販、飲食メニュー
  subscription, // 月会費、回数券
}

/// 利用可能チャネル
class AvailableChannels {
  final bool reservation; // 予約時に選択可
  final bool order;       // モバイルオーダー/セルフ注文
  final bool pos;         // レジ/POS販売のみ

  AvailableChannels({
    this.reservation = false,
    this.order = false,
    this.pos = true,
  });

  factory AvailableChannels.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return AvailableChannels(pos: true);
    }
    return AvailableChannels(
      reservation: data['reservation'] ?? false,
      order: data['order'] ?? false,
      pos: data['pos'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reservation': reservation,
      'order': order,
      'pos': pos,
    };
  }

  /// 旧フィールドからの変換（後方互換性）
  factory AvailableChannels.fromLegacy({
    bool? showOnReservationMenu,
    bool isOrderable = true,
  }) {
    return AvailableChannels(
      reservation: showOnReservationMenu ?? false,
      order: isOrderable,
      pos: true,
    );
  }
}

class Product {
  final String id;
  final String shopId;
  final String categoryId;
  final String? code;  // 商品コード（例: "023"、カテゴリ内連番）
  final String name;
  final String? nameEn;
  final String? nameTh;
  final String? nameZhTw;
  final String? nameKo;
  final String? description;
  final String? descriptionEn;
  final String? descriptionTh;
  final String? descriptionZhTw;
  final String? descriptionKo;
  final double price;
  final String? imageUrl;
  final String? videoUrl;
  final String? mediaType; // 'image' or 'video'
  final List<String> optionIds;
  final String displayStatus; // 'available', 'hidden', 'soldout'
  final int sortOrder;
  final bool isActive;
  final bool isAskPrice;  // ASK商品（価格後入力）
  final AvailableTimeSlot? availableTimeSlots; // 時間帯設定
  final List<String>? allergens; // アレルゲン情報
  final bool isSpicy; // 辛さ
  final bool isVegetarian; // ベジタリアン
  final CostSettings? costSettings; // 原価設定
  final bool showOnReservationMenu; // 予約メニューに表示（後方互換）
  final List<String>? assignedStaffIds; // 担当スタッフ
  final DateTime createdAt;
  final DateTime updatedAt;

  // === 統合商品マスター用の新フィールド ===
  final String productType; // 'service', 'goods', 'subscription'
  final AvailableChannels? availableChannels; // 利用可能チャネル
  final int? duration; // 所要時間（分）- serviceの場合
  final bool requiresStaff; // 担当者必須か
  final double? nominationFee; // 指名料（serviceの場合）

  // === タグ・割引機能 ===
  final ProductTags? tags; // 表示タグ
  final DiscountSettings? discountSettings; // 割引設定

  Product({
    required this.id,
    required this.shopId,
    required this.categoryId,
    this.code,
    required this.name,
    this.nameEn,
    this.nameTh,
    this.nameZhTw,
    this.nameKo,
    this.description,
    this.descriptionEn,
    this.descriptionTh,
    this.descriptionZhTw,
    this.descriptionKo,
    required this.price,
    this.imageUrl,
    this.videoUrl,
    this.mediaType,
    required this.optionIds,
    required this.displayStatus,
    required this.sortOrder,
    required this.isActive,
    this.isAskPrice = false,
    this.availableTimeSlots,
    this.allergens,
    this.isSpicy = false,
    this.isVegetarian = false,
    this.costSettings,
    this.showOnReservationMenu = false,
    this.assignedStaffIds,
    required this.createdAt,
    required this.updatedAt,
    // 新フィールド
    this.productType = 'goods',
    this.availableChannels,
    this.duration,
    this.requiresStaff = false,
    this.nominationFee,
    // タグ・割引
    this.tags,
    this.discountSettings,
  });

  /// 完全な商品コードを生成（カテゴリコード-商品コード形式）
  String? getFullCode(String? categoryCode) {
    if (code == null || code!.isEmpty) return null;
    if (categoryCode == null || categoryCode.isEmpty) return code;
    return '$categoryCode-$code';
  }

  /// コード付き表示名を取得（例: "[001-023] ビール"）
  String getDisplayNameWithCode(String languageCode, String? categoryCode) {
    final localizedName = getLocalizedName(languageCode);
    final fullCode = getFullCode(categoryCode);
    if (fullCode != null) {
      return '[$fullCode] $localizedName';
    }
    return localizedName;
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final optionIds = (data['optionIds'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [];
    final allergens = (data['allergens'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    final assignedStaffIds = (data['assignedStaffIds'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    // 新フィールドのavailableChannels（後方互換性対応）
    AvailableChannels? availableChannels;
    if (data['availableChannels'] != null) {
      availableChannels = AvailableChannels.fromMap(
          data['availableChannels'] as Map<String, dynamic>);
    } else {
      // 旧フィールドから変換
      availableChannels = AvailableChannels.fromLegacy(
        showOnReservationMenu: data['showOnReservationMenu'] ?? false,
        isOrderable: true, // 既存商品はデフォルトでオーダー可能
      );
    }

    return Product(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      categoryId: data['categoryId'] ?? '',
      code: data['code'],
      name: data['name'] ?? '',
      nameEn: data['nameEn'],
      nameTh: data['nameTh'],
      nameZhTw: data['nameZhTw'] ?? data['nameZh'], // 互換性対応
      nameKo: data['nameKo'],
      description: data['description'],
      descriptionEn: data['descriptionEn'],
      descriptionTh: data['descriptionTh'],
      descriptionZhTw: data['descriptionZhTw'] ?? data['descriptionZh'], // 互換性対応
      descriptionKo: data['descriptionKo'],
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'],
      videoUrl: data['videoUrl'],
      mediaType: data['mediaType'],
      optionIds: optionIds,
      displayStatus: data['displayStatus'] ?? 'available',
      sortOrder: data['sortOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
      isAskPrice: data['isAskPrice'] ?? false,
      availableTimeSlots: data['availableTimeSlots'] != null
          ? AvailableTimeSlot.fromMap(data['availableTimeSlots'] as Map<String, dynamic>)
          : null,
      allergens: allergens,
      isSpicy: data['isSpicy'] ?? false,
      isVegetarian: data['isVegetarian'] ?? false,
      costSettings: data['costSettings'] != null
          ? CostSettings.fromMap(data['costSettings'] as Map<String, dynamic>)
          : null,
      showOnReservationMenu: data['showOnReservationMenu'] ?? false,
      assignedStaffIds: assignedStaffIds,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      // 新フィールド
      productType: data['productType'] ?? 'goods',
      availableChannels: availableChannels,
      duration: data['duration'],
      requiresStaff: data['requiresStaff'] ?? false,
      nominationFee: (data['nominationFee'] as num?)?.toDouble(),
      // タグ・割引
      tags: data['tags'] != null
          ? ProductTags.fromMap(data['tags'] as Map<String, dynamic>)
          : null,
      discountSettings: data['discountSettings'] != null
          ? DiscountSettings.fromMap(data['discountSettings'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'categoryId': categoryId,
      'code': code,
      'name': name,
      'nameEn': nameEn,
      'nameTh': nameTh,
      'nameZhTw': nameZhTw,
      'nameKo': nameKo,
      'description': description,
      'descriptionEn': descriptionEn,
      'descriptionTh': descriptionTh,
      'descriptionZhTw': descriptionZhTw,
      'descriptionKo': descriptionKo,
      'price': price,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'mediaType': mediaType,
      'optionIds': optionIds,
      'displayStatus': displayStatus,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'isAskPrice': isAskPrice,
      if (availableTimeSlots != null) 'availableTimeSlots': availableTimeSlots!.toMap(),
      if (allergens != null) 'allergens': allergens,
      'isSpicy': isSpicy,
      'isVegetarian': isVegetarian,
      if (costSettings != null) 'costSettings': costSettings!.toMap(),
      'showOnReservationMenu': showOnReservationMenu,
      if (assignedStaffIds != null) 'assignedStaffIds': assignedStaffIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // 新フィールド
      'productType': productType,
      if (availableChannels != null) 'availableChannels': availableChannels!.toMap(),
      if (duration != null) 'duration': duration,
      'requiresStaff': requiresStaff,
      if (nominationFee != null) 'nominationFee': nominationFee,
      // タグ・割引
      if (tags != null) 'tags': tags!.toMap(),
      if (discountSettings != null) 'discountSettings': discountSettings!.toMap(),
    };
  }

  // 売り切れかどうか
  bool get isSoldOut => displayStatus == 'soldout';

  /// 言語コードに応じた商品名を取得
  String getLocalizedName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return nameEn?.isNotEmpty == true ? nameEn! : name;
      case 'th':
        return nameTh?.isNotEmpty == true ? nameTh! : name;
      case 'zh_TW':
        return nameZhTw?.isNotEmpty == true ? nameZhTw! : name;
      case 'ko':
        return nameKo?.isNotEmpty == true ? nameKo! : name;
      default:
        return name;
    }
  }

  /// 言語コードに応じた商品説明を取得
  String? getLocalizedDescription(String languageCode) {
    switch (languageCode) {
      case 'en':
        return descriptionEn?.isNotEmpty == true ? descriptionEn : description;
      case 'th':
        return descriptionTh?.isNotEmpty == true ? descriptionTh : description;
      case 'zh_TW':
        return descriptionZhTw?.isNotEmpty == true ? descriptionZhTw : description;
      case 'ko':
        return descriptionKo?.isNotEmpty == true ? descriptionKo : description;
      default:
        return description;
    }
  }

  // コピーメソッド
  Product copyWith({
    String? id,
    String? shopId,
    String? categoryId,
    String? code,
    String? name,
    String? nameEn,
    String? nameTh,
    String? nameZhTw,
    String? nameKo,
    String? description,
    String? descriptionEn,
    String? descriptionTh,
    String? descriptionZhTw,
    String? descriptionKo,
    double? price,
    String? imageUrl,
    String? videoUrl,
    String? mediaType,
    List<String>? optionIds,
    String? displayStatus,
    int? sortOrder,
    bool? isActive,
    bool? isAskPrice,
    AvailableTimeSlot? availableTimeSlots,
    List<String>? allergens,
    bool? isSpicy,
    bool? isVegetarian,
    CostSettings? costSettings,
    bool? showOnReservationMenu,
    List<String>? assignedStaffIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    // 新フィールド
    String? productType,
    AvailableChannels? availableChannels,
    int? duration,
    bool? requiresStaff,
    double? nominationFee,
    // タグ・割引
    ProductTags? tags,
    DiscountSettings? discountSettings,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      categoryId: categoryId ?? this.categoryId,
      code: code ?? this.code,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      nameTh: nameTh ?? this.nameTh,
      nameZhTw: nameZhTw ?? this.nameZhTw,
      nameKo: nameKo ?? this.nameKo,
      description: description ?? this.description,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionTh: descriptionTh ?? this.descriptionTh,
      descriptionZhTw: descriptionZhTw ?? this.descriptionZhTw,
      descriptionKo: descriptionKo ?? this.descriptionKo,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      mediaType: mediaType ?? this.mediaType,
      optionIds: optionIds ?? this.optionIds,
      displayStatus: displayStatus ?? this.displayStatus,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      isAskPrice: isAskPrice ?? this.isAskPrice,
      availableTimeSlots: availableTimeSlots ?? this.availableTimeSlots,
      allergens: allergens ?? this.allergens,
      isSpicy: isSpicy ?? this.isSpicy,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      costSettings: costSettings ?? this.costSettings,
      showOnReservationMenu: showOnReservationMenu ?? this.showOnReservationMenu,
      assignedStaffIds: assignedStaffIds ?? this.assignedStaffIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // 新フィールド
      productType: productType ?? this.productType,
      availableChannels: availableChannels ?? this.availableChannels,
      duration: duration ?? this.duration,
      requiresStaff: requiresStaff ?? this.requiresStaff,
      nominationFee: nominationFee ?? this.nominationFee,
      // タグ・割引
      tags: tags ?? this.tags,
      discountSettings: discountSettings ?? this.discountSettings,
    );
  }

  // === ヘルパーメソッド ===

  /// サービス商品かどうか
  bool get isService => productType == 'service';

  /// 物販商品かどうか
  bool get isGoods => productType == 'goods';

  /// 定期購入/回数券かどうか
  bool get isSubscription => productType == 'subscription';

  /// 予約で使用可能か
  bool get isAvailableForReservation =>
      availableChannels?.reservation ?? showOnReservationMenu;

  /// オーダーで使用可能か
  bool get isAvailableForOrder => availableChannels?.order ?? true;

  /// POSで使用可能か
  bool get isAvailableForPos => availableChannels?.pos ?? true;

  // === タグ・割引ヘルパー ===

  /// 有効なタグがあるかどうか
  bool get hasAnyTag => tags?.hasAnyTag ?? false;

  /// 現在割引が適用されているかどうか
  bool get hasActiveDiscount => discountSettings?.isCurrentlyActive ?? false;

  /// 実効価格（割引適用後）を取得
  double get effectivePrice {
    if (discountSettings != null && discountSettings!.isCurrentlyActive) {
      return discountSettings!.calculateDiscountedPrice(price);
    }
    return price;
  }

  /// 割引額を取得
  double get discountAmount {
    if (discountSettings != null && discountSettings!.isCurrentlyActive) {
      return discountSettings!.calculateDiscountAmount(price);
    }
    return 0;
  }

  /// 割引ラベルを取得
  String get discountLabel => discountSettings?.getDiscountLabel() ?? '';

  /// タグリストを取得（多言語対応）
  List<Map<String, String>> getTagList(String languageCode) {
    return tags?.getTagList(languageCode) ?? [];
  }
}
