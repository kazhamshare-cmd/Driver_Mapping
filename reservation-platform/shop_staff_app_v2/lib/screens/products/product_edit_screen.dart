import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../services/translation_service.dart';

class ProductEditScreen extends ConsumerStatefulWidget {
  final Product? product;
  final String shopId;

  const ProductEditScreen({
    super.key,
    this.product,
    required this.shopId,
  });

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _nameEnController;
  late TextEditingController _nameThController;
  late TextEditingController _nameZhTwController;
  late TextEditingController _nameKoController;
  late TextEditingController _descriptionController;
  late TextEditingController _descriptionEnController;
  late TextEditingController _descriptionThController;
  late TextEditingController _descriptionZhTwController;
  late TextEditingController _descriptionKoController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _backRateController;

  String? _selectedCategoryId;
  List<String> _selectedOptionIds = [];
  String _displayStatus = 'available';
  String? _imageUrl;
  File? _imageFile;
  String? _videoUrl;
  File? _videoFile;
  String _mediaType = 'image'; // 'image' or 'video'
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  bool _isCompressing = false;
  double _compressionProgress = 0.0;

  // 新しいフィールド
  bool _isAskPrice = false;
  bool _isSpicy = false;
  bool _isVegetarian = false;
  bool _showOnReservationMenu = false;
  bool _hasCostSettings = false;

  // タグ設定
  bool _tagNew = false;
  bool _tagRecommended = false;
  bool _tagPopular = false;
  bool _tagLimitedTime = false;
  bool _tagLimitedQty = false;
  bool _tagOrganic = false;

  // 割引設定
  bool _hasDiscount = false;
  String _discountType = 'percent'; // 'amount' or 'percent'
  late TextEditingController _discountValueController;

  // 時間帯設定
  String _timeSlotType = 'always'; // 'always' or 'specific_times'
  List<Map<String, String>> _timeSlots = [];

  // 翻訳関連
  bool _isTranslating = false;
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _nameEnController = TextEditingController(text: p?.nameEn ?? '');
    _nameThController = TextEditingController(text: p?.nameTh ?? '');
    _nameZhTwController = TextEditingController(text: p?.nameZhTw ?? '');
    _nameKoController = TextEditingController(text: p?.nameKo ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _descriptionEnController = TextEditingController(text: p?.descriptionEn ?? '');
    _descriptionThController = TextEditingController(text: p?.descriptionTh ?? '');
    _descriptionZhTwController = TextEditingController(text: p?.descriptionZhTw ?? '');
    _descriptionKoController = TextEditingController(text: p?.descriptionKo ?? '');
    _priceController = TextEditingController(text: p?.price.toString() ?? '');
    _costController = TextEditingController(
        text: p?.costSettings?.cost.toString() ?? '0');
    _backRateController = TextEditingController(
        text: ((p?.costSettings?.backRate ?? 0.5) * 100).toString());
    _selectedCategoryId = p?.categoryId;
    _selectedOptionIds = p?.optionIds ?? [];
    _displayStatus = p?.displayStatus ?? 'available';
    _imageUrl = p?.imageUrl;
    _videoUrl = p?.videoUrl;
    _mediaType = p?.mediaType ?? 'image';

    // 既存の動画URLがある場合はコントローラーを初期化
    if (_videoUrl != null && _mediaType == 'video') {
      _initVideoController(_videoUrl!);
    }

    // 新しいフィールドの初期化
    _isAskPrice = p?.isAskPrice ?? false;
    _isSpicy = p?.isSpicy ?? false;
    _isVegetarian = p?.isVegetarian ?? false;
    _showOnReservationMenu = p?.showOnReservationMenu ?? false;
    _hasCostSettings = p?.costSettings?.hasCost ?? false;

    // 時間帯設定の初期化
    _timeSlotType = p?.availableTimeSlots?.type ?? 'always';
    _timeSlots = p?.availableTimeSlots?.timeSlots
            ?.map((s) => {
                  'start': s.start,
                  'end': s.end,
                  'name': s.name ?? '',
                })
            .toList() ??
        [];

    // タグ設定の初期化
    _tagNew = p?.tags?.isNew ?? false;
    _tagRecommended = p?.tags?.isRecommended ?? false;
    _tagPopular = p?.tags?.isPopular ?? false;
    _tagLimitedTime = p?.tags?.isLimitedTime ?? false;
    _tagLimitedQty = p?.tags?.isLimitedQty ?? false;
    _tagOrganic = p?.tags?.isOrganic ?? false;

    // 割引設定の初期化
    _hasDiscount = p?.discountSettings?.hasDiscount ?? false;
    _discountType = p?.discountSettings?.discountType ?? 'percent';
    _discountValueController = TextEditingController(
      text: (p?.discountSettings?.discountValue ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _nameThController.dispose();
    _nameZhTwController.dispose();
    _nameKoController.dispose();
    _descriptionController.dispose();
    _descriptionEnController.dispose();
    _descriptionThController.dispose();
    _descriptionZhTwController.dispose();
    _descriptionKoController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _backRateController.dispose();
    _discountValueController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _initVideoController(String url) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.setLooping(true);
        }
      });
  }

  void _initVideoControllerFromFile(File file) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.setLooping(true);
        }
      });
  }

  bool get _hasNoMedia =>
      _imageFile == null && _imageUrl == null && _videoFile == null && _videoUrl == null;

  bool get _shouldShowImage =>
      _mediaType == 'image' && (_imageFile != null || _imageUrl != null);

  void _clearMedia() {
    setState(() {
      _imageFile = null;
      _imageUrl = null;
      _videoFile = null;
      _videoUrl = null;
      _mediaType = 'image';
      _videoController?.dispose();
      _videoController = null;
    });
  }

  Widget _buildMediaContent() {
    // 圧縮中の場合
    if (_isCompressing) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_compressionProgress > 0)
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: _compressionProgress,
                    strokeWidth: 4,
                    backgroundColor: Colors.grey[300],
                  ),
                ),
                Text(
                  '${(_compressionProgress * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            )
          else
            const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            '圧縮中...',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'しばらくお待ちください',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    // メディアがない場合：追加プロンプト
    if (_hasNoMedia) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_photo_alternate,
              size: 40,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '写真/動画を追加',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'タップして選択',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    // 動画の場合
    if (_mediaType == 'video') {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
              // 動画アイコン表示
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('動画', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // 動画読み込み中
        return const Center(
          child: CircularProgressIndicator(),
        );
      }
    }

    // 画像の場合: タップで変更オーバーレイ
    return Stack(
      children: [
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('タップで変更', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// AI翻訳を実行
  Future<void> _translateToAllLanguages() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品名を入力してから翻訳してください')),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final results = await _translationService.translateNameAndDescription(
        name: name,
        description: description,
        sourceLanguage: 'ja',
        targetLanguages: ['en', 'th', 'zh-TW', 'ko'],
      );

      setState(() {
        // 名前の翻訳を適用
        if (results['name']?['en'] != null) {
          _nameEnController.text = results['name']!['en']!;
        }
        if (results['name']?['th'] != null) {
          _nameThController.text = results['name']!['th']!;
        }
        if (results['name']?['zh-TW'] != null) {
          _nameZhTwController.text = results['name']!['zh-TW']!;
        }
        if (results['name']?['ko'] != null) {
          _nameKoController.text = results['name']!['ko']!;
        }

        // 説明の翻訳を適用
        if (results['description']?['en'] != null) {
          _descriptionEnController.text = results['description']!['en']!;
        }
        if (results['description']?['th'] != null) {
          _descriptionThController.text = results['description']!['th']!;
        }
        if (results['description']?['zh-TW'] != null) {
          _descriptionZhTwController.text = results['description']!['zh-TW']!;
        }
        if (results['description']?['ko'] != null) {
          _descriptionKoController.text = results['description']!['ko']!;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('翻訳が完了しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('翻訳エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  // ファイルサイズ制限
  static const int _maxImageSizeBytes = 500 * 1024; // 500KB
  static const int _maxVideoSizeBytes = 10 * 1024 * 1024; // 10MB

  /// 画像を圧縮（ファイルサイズに応じて品質を自動調整）
  Future<File?> _compressImage(File file) async {
    try {
      final originalSize = await file.length();
      debugPrint('元画像サイズ: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB');

      final dir = await getTemporaryDirectory();

      // ファイルサイズに応じて圧縮設定を決定
      int quality;
      int maxWidth;
      int maxHeight;

      if (originalSize > 10 * 1024 * 1024) {
        // 10MB超: 超高圧縮
        quality = 40;
        maxWidth = 600;
        maxHeight = 600;
        debugPrint('10MB超 → 超高圧縮モード (品質40%, 600px)');
      } else if (originalSize > 5 * 1024 * 1024) {
        // 5-10MB: 高圧縮
        quality = 50;
        maxWidth = 700;
        maxHeight = 700;
        debugPrint('5-10MB → 高圧縮モード (品質50%, 700px)');
      } else if (originalSize > 2 * 1024 * 1024) {
        // 2-5MB: 中圧縮
        quality = 55;
        maxWidth = 800;
        maxHeight = 800;
        debugPrint('2-5MB → 中圧縮モード (品質55%, 800px)');
      } else if (originalSize > 1 * 1024 * 1024) {
        // 1-2MB: 軽圧縮
        quality = 60;
        maxWidth = 800;
        maxHeight = 800;
        debugPrint('1-2MB → 軽圧縮モード (品質60%, 800px)');
      } else {
        // 1MB以下: 最小圧縮
        quality = 70;
        maxWidth = 800;
        maxHeight = 800;
        debugPrint('1MB以下 → 最小圧縮モード (品質70%, 800px)');
      }

      // 1回目の圧縮
      var targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result == null) return file;

      var compressedSize = await result.length();
      debugPrint('1回目圧縮: ${(compressedSize / 1024).toStringAsFixed(1)}KB');

      // まだ大きい場合は再圧縮
      int attempts = 0;
      while (compressedSize > _maxImageSizeBytes && attempts < 3) {
        attempts++;
        quality = (quality * 0.7).toInt().clamp(20, 100);
        maxWidth = (maxWidth * 0.8).toInt().clamp(400, 1200);
        maxHeight = (maxHeight * 0.8).toInt().clamp(400, 1200);

        debugPrint('再圧縮 $attempts回目 (品質$quality%, ${maxWidth}px)');

        targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_$attempts.jpg';
        final recompressed = await FlutterImageCompress.compressAndGetFile(
          result!.path,
          targetPath,
          quality: quality,
          minWidth: maxWidth,
          minHeight: maxHeight,
          format: CompressFormat.jpeg,
        );

        if (recompressed != null) {
          result = recompressed;
          compressedSize = await result!.length();
          debugPrint('再圧縮後: ${(compressedSize / 1024).toStringAsFixed(1)}KB');
        }
      }

      debugPrint('画像圧縮完了: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB → ${(compressedSize / 1024).toStringAsFixed(1)}KB (${((1 - compressedSize / originalSize) * 100).toStringAsFixed(0)}%削減)');
      return File(result!.path);
    } catch (e) {
      debugPrint('画像圧縮エラー: $e');
      return file;
    }
  }

  /// 動画を圧縮（ファイルサイズに応じて品質を自動調整）
  Future<File?> _compressVideo(File file) async {
    try {
      final originalSize = await file.length();
      debugPrint('元動画サイズ: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB');

      // 動画が大きすぎる場合は警告
      if (originalSize > 500 * 1024 * 1024) {
        // 500MB超
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('動画が非常に大きいため、圧縮に時間がかかります'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      setState(() {
        _isCompressing = true;
        _compressionProgress = 0.0;
      });

      // 圧縮進捗をリッスン
      VideoCompress.compressProgress$.subscribe((progress) {
        if (mounted) {
          setState(() {
            _compressionProgress = progress / 100;
          });
        }
      });

      // ファイルサイズに応じて圧縮品質を決定
      VideoQuality quality;
      if (originalSize > 100 * 1024 * 1024) {
        // 100MB超: 最低品質（360p相当）
        quality = VideoQuality.Res640x480Quality;
        debugPrint('100MB超 → 最低品質モード (640x480)');
      } else if (originalSize > 50 * 1024 * 1024) {
        // 50-100MB: 低品質
        quality = VideoQuality.LowQuality;
        debugPrint('50-100MB → 低品質モード');
      } else if (originalSize > 20 * 1024 * 1024) {
        // 20-50MB: 中品質
        quality = VideoQuality.MediumQuality;
        debugPrint('20-50MB → 中品質モード');
      } else {
        // 20MB以下: 中品質で十分
        quality = VideoQuality.MediumQuality;
        debugPrint('20MB以下 → 中品質モード');
      }

      // 1回目の圧縮
      var info = await VideoCompress.compressVideo(
        file.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (info?.file == null) return file;

      var compressedSize = await info!.file!.length();
      debugPrint('1回目圧縮: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB');

      // まだ10MBを超える場合は再圧縮
      if (compressedSize > _maxVideoSizeBytes && quality != VideoQuality.Res640x480Quality) {
        debugPrint('10MB超のため再圧縮...');

        // より低い品質で再圧縮
        final recompressInfo = await VideoCompress.compressVideo(
          info.file!.path,
          quality: VideoQuality.Res640x480Quality,
          deleteOrigin: false,
          includeAudio: true,
        );

        if (recompressInfo?.file != null) {
          info = recompressInfo;
          compressedSize = await info!.file!.length();
          debugPrint('再圧縮後: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB');
        }
      }

      // それでもまだ大きい場合は警告
      if (compressedSize > _maxVideoSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('動画サイズ: ${(compressedSize / 1024 / 1024).toStringAsFixed(1)}MB（推奨: 10MB以下）'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      debugPrint('動画圧縮完了: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB → ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB (${((1 - compressedSize / originalSize) * 100).toStringAsFixed(0)}%削減)');
      return info.file;
    } catch (e) {
      debugPrint('動画圧縮エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('動画圧縮に失敗しました: $e')),
        );
      }
      return file;
    } finally {
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _compressionProgress = 0.0;
        });
      }
      // 一時ファイルをクリーンアップ
      await VideoCompress.deleteAllCache();
    }
  }

  Future<void> _pickMedia() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'メディアを選択',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt, color: Colors.blue.shade700),
                ),
                title: const Text('写真を撮影'),
                subtitle: const Text('新しい写真を撮影します'),
                onTap: () => Navigator.pop(context, {'type': 'image', 'source': ImageSource.camera}),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library, color: Colors.green.shade700),
                ),
                title: const Text('ギャラリーから写真を選択'),
                subtitle: const Text('保存済みの写真から選びます'),
                onTap: () => Navigator.pop(context, {'type': 'image', 'source': ImageSource.gallery}),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.videocam, color: Colors.purple.shade700),
                ),
                title: const Text('動画を撮影'),
                subtitle: const Text('新しい動画を撮影します'),
                onTap: () => Navigator.pop(context, {'type': 'video', 'source': ImageSource.camera}),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.video_library, color: Colors.orange.shade700),
                ),
                title: const Text('ギャラリーから動画を選択'),
                subtitle: const Text('保存済みの動画から選びます'),
                onTap: () => Navigator.pop(context, {'type': 'video', 'source': ImageSource.gallery}),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    final picker = ImagePicker();
    final type = result['type'] as String;
    final source = result['source'] as ImageSource;

    if (type == 'image') {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        // 画像を圧縮
        setState(() {
          _isCompressing = true;
        });
        final compressedFile = await _compressImage(File(pickedFile.path));
        setState(() {
          _imageFile = compressedFile;
          _videoFile = null;
          _videoUrl = null;
          _mediaType = 'image';
          _videoController?.dispose();
          _videoController = null;
          _isCompressing = false;
        });
      }
    } else {
      final pickedFile = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30), // 30秒に制限
      );
      if (pickedFile != null) {
        // 動画を圧縮
        final compressedFile = await _compressVideo(File(pickedFile.path));
        setState(() {
          _videoFile = compressedFile;
          _imageFile = null;
          _imageUrl = null;
          _mediaType = 'video';
        });
        if (_videoFile != null) {
          _initVideoControllerFromFile(_videoFile!);
        }
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('products')
        .child(widget.shopId)
        .child(fileName);

    await ref.putFile(_imageFile!);
    final url = await ref.getDownloadURL();
    return url;
  }

  Future<String?> _uploadVideo() async {
    if (_videoFile == null) return _videoUrl;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ref = FirebaseStorage.instance
        .ref()
        .child('products')
        .child(widget.shopId)
        .child('videos')
        .child(fileName);

    // メタデータを設定（動画用）
    final metadata = SettableMetadata(
      contentType: 'video/mp4',
    );

    await ref.putFile(_videoFile!, metadata);
    final url = await ref.getDownloadURL();
    return url;
  }

  Future<Map<String, String?>> _uploadMedia() async {
    setState(() {
      _isUploading = true;
    });

    try {
      if (_mediaType == 'video' && _videoFile != null) {
        final videoUrl = await _uploadVideo();
        return {'videoUrl': videoUrl, 'imageUrl': null};
      } else if (_imageFile != null) {
        final imageUrl = await _uploadImage();
        return {'imageUrl': imageUrl, 'videoUrl': null};
      }
      return {'imageUrl': _imageUrl, 'videoUrl': _videoUrl};
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カテゴリーを選択してください')),
      );
      return;
    }

    try {
      final uploadedMedia = await _uploadMedia();
      final uploadedImageUrl = uploadedMedia['imageUrl'];
      final uploadedVideoUrl = uploadedMedia['videoUrl'];

      // 時間帯設定の構築
      AvailableTimeSlot? availableTimeSlots;
      if (_timeSlotType == 'specific_times' && _timeSlots.isNotEmpty) {
        availableTimeSlots = AvailableTimeSlot(
          type: 'specific_times',
          timeSlots: _timeSlots
              .where((s) => s['start']!.isNotEmpty && s['end']!.isNotEmpty)
              .map((s) => TimeSlotRange(
                    start: s['start']!,
                    end: s['end']!,
                    name: s['name']?.isNotEmpty == true ? s['name'] : null,
                  ))
              .toList(),
        );
      } else {
        availableTimeSlots = AvailableTimeSlot(type: 'always');
      }

      // 原価設定の構築
      CostSettings? costSettings;
      if (_hasCostSettings) {
        costSettings = CostSettings(
          hasCost: true,
          cost: double.tryParse(_costController.text) ?? 0,
          backRate: (double.tryParse(_backRateController.text) ?? 50) / 100,
        );
      }

      // タグ設定の構築
      ProductTags? tags;
      if (_tagNew || _tagRecommended || _tagPopular || _tagLimitedTime ||
          _tagLimitedQty || _tagOrganic || _isSpicy || _isVegetarian) {
        tags = ProductTags(
          isNew: _tagNew,
          isRecommended: _tagRecommended,
          isPopular: _tagPopular,
          isLimitedTime: _tagLimitedTime,
          isLimitedQty: _tagLimitedQty,
          isOrganic: _tagOrganic,
          isSpicy: _isSpicy,
          isVegetarian: _isVegetarian,
        );
      }

      // 割引設定の構築
      DiscountSettings? discountSettings;
      if (_hasDiscount) {
        discountSettings = DiscountSettings(
          hasDiscount: true,
          discountType: _discountType,
          discountValue: double.tryParse(_discountValueController.text) ?? 0,
        );
      }

      final product = Product(
        id: widget.product?.id ?? '',
        shopId: widget.shopId,
        categoryId: _selectedCategoryId!,
        name: _nameController.text,
        nameEn: _nameEnController.text.isEmpty ? null : _nameEnController.text,
        nameTh: _nameThController.text.isEmpty ? null : _nameThController.text,
        nameZhTw: _nameZhTwController.text.isEmpty ? null : _nameZhTwController.text,
        nameKo: _nameKoController.text.isEmpty ? null : _nameKoController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        descriptionEn: _descriptionEnController.text.isEmpty ? null : _descriptionEnController.text,
        descriptionTh: _descriptionThController.text.isEmpty ? null : _descriptionThController.text,
        descriptionZhTw: _descriptionZhTwController.text.isEmpty ? null : _descriptionZhTwController.text,
        descriptionKo: _descriptionKoController.text.isEmpty ? null : _descriptionKoController.text,
        price: _isAskPrice ? 0 : double.parse(_priceController.text),
        imageUrl: uploadedImageUrl,
        videoUrl: uploadedVideoUrl,
        mediaType: _mediaType,
        optionIds: _selectedOptionIds,
        displayStatus: _displayStatus,
        sortOrder: widget.product?.sortOrder ?? 0,
        isActive: true,
        isAskPrice: _isAskPrice,
        availableTimeSlots: availableTimeSlots,
        isSpicy: _isSpicy,
        isVegetarian: _isVegetarian,
        costSettings: costSettings,
        showOnReservationMenu: _showOnReservationMenu,
        tags: tags,
        discountSettings: discountSettings,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saveProduct = ref.read(saveProductProvider);
      await saveProduct(product);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.product == null ? '商品を追加しました' : '商品を更新しました'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(productCategoriesProvider(widget.shopId));
    final optionsAsync = ref.watch(productOptionsProvider(widget.shopId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? '商品追加' : '商品編集'),
        actions: [
          if (widget.product != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteProduct,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // メディア（画像/動画）
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickMedia,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 2,
                          style: _hasNoMedia ? BorderStyle.solid : BorderStyle.none,
                        ),
                        image: _shouldShowImage
                            ? DecorationImage(
                                image: _imageFile != null
                                    ? FileImage(_imageFile!) as ImageProvider
                                    : NetworkImage(_imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _buildMediaContent(),
                    ),
                  ),
                  // 削除ボタン
                  if (!_hasNoMedia)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: GestureDetector(
                        onTap: _clearMedia,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  // 動画再生/停止ボタン
                  if (_mediaType == 'video' && _videoController != null && _videoController!.value.isInitialized)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_videoController!.value.isPlaying) {
                              _videoController!.pause();
                            } else {
                              _videoController!.play();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // カテゴリー
            categoriesAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('エラー: $error'),
              data: (categories) {
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'カテゴリー *',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCategoryId,
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'カテゴリーを選択してください';
                    }
                    return null;
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // 商品名（日本語）
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '商品名 *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '商品名を入力してください';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 価格
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: '価格 *',
                border: OutlineInputBorder(),
                prefixText: '¥',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '価格を入力してください';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 説明（日本語）
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '説明',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // 多言語入力セクション
            ExpansionTile(
              title: const Text('多言語設定（オプション）'),
              children: [
                const SizedBox(height: 8),
                // AI翻訳ボタン
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: _isTranslating ? null : _translateToAllLanguages,
                    icon: _isTranslating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.translate),
                    label: Text(_isTranslating ? '翻訳中...' : 'AIで自動翻訳'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
                TextFormField(
                  controller: _nameEnController,
                  decoration: const InputDecoration(
                    labelText: '商品名（英語）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionEnController,
                  decoration: const InputDecoration(
                    labelText: '説明（英語）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameThController,
                  decoration: const InputDecoration(
                    labelText: '商品名（タイ語）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionThController,
                  decoration: const InputDecoration(
                    labelText: '説明（タイ語）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameZhTwController,
                  decoration: const InputDecoration(
                    labelText: '商品名（繁体字中国語）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionZhTwController,
                  decoration: const InputDecoration(
                    labelText: '説明（繁体字中国語）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameKoController,
                  decoration: const InputDecoration(
                    labelText: '商品名（韓国語）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionKoController,
                  decoration: const InputDecoration(
                    labelText: '説明（韓国語）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // オプション選択
            optionsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('エラー: $error'),
              data: (options) {
                if (options.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'オプション',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: options.map((option) {
                        final isSelected = _selectedOptionIds.contains(option.id);
                        return FilterChip(
                          label: Text(option.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedOptionIds.add(option.id);
                              } else {
                                _selectedOptionIds.remove(option.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // 表示ステータス
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '表示ステータス',
                border: OutlineInputBorder(),
              ),
              value: _displayStatus,
              items: const [
                DropdownMenuItem(value: 'available', child: Text('販売中')),
                DropdownMenuItem(value: 'hidden', child: Text('非表示')),
                DropdownMenuItem(value: 'soldout', child: Text('売り切れ')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _displayStatus = value;
                  });
                }
              },
            ),

            const SizedBox(height: 24),

            // ASK商品セクション
            ExpansionTile(
              title: const Text('ASK商品（価格後入力）'),
              initiallyExpanded: _isAskPrice,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '注文時または会計時に価格を入力する商品の場合にONにしてください。',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('ASK商品（価格後入力）'),
                        value: _isAskPrice,
                        onChanged: (value) {
                          setState(() {
                            _isAskPrice = value;
                            if (value) {
                              _priceController.text = '0';
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 原価・コミッション設定セクション
            ExpansionTile(
              title: const Text('原価・コミッション設定'),
              initiallyExpanded: _hasCostSettings,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'この商品の原価とスタッフへのバック率を設定します。\nバック金額 = (販売価格 - 原価) × バック率',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('原価管理対象'),
                        value: _hasCostSettings,
                        onChanged: (value) {
                          setState(() {
                            _hasCostSettings = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_hasCostSettings) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _costController,
                                decoration: const InputDecoration(
                                  labelText: '商品原価',
                                  border: OutlineInputBorder(),
                                  prefixText: '¥',
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _backRateController,
                                decoration: const InputDecoration(
                                  labelText: 'バック率',
                                  border: OutlineInputBorder(),
                                  suffixText: '%',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final price =
                                double.tryParse(_priceController.text) ?? 0;
                            final cost =
                                double.tryParse(_costController.text) ?? 0;
                            final rate =
                                (double.tryParse(_backRateController.text) ??
                                        0) /
                                    100;
                            final backAmount = (price - cost) * rate;
                            return Text(
                              '予想バック金額: ¥${backAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // 時間帯設定セクション
            ExpansionTile(
              title: const Text('時間帯設定'),
              initiallyExpanded: _timeSlotType == 'specific_times',
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'この商品を特定の時間帯のみ表示したい場合に設定してください。',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: '表示タイプ',
                          border: OutlineInputBorder(),
                        ),
                        value: _timeSlotType,
                        items: const [
                          DropdownMenuItem(
                              value: 'always', child: Text('常時表示')),
                          DropdownMenuItem(
                              value: 'specific_times',
                              child: Text('特定時間のみ表示')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _timeSlotType = value;
                            });
                          }
                        },
                      ),
                      if (_timeSlotType == 'specific_times') ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('時間帯'),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _timeSlots.add({
                                    'start': '11:00',
                                    'end': '14:00',
                                    'name': '',
                                  });
                                });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('追加'),
                            ),
                          ],
                        ),
                        ..._timeSlots.asMap().entries.map((entry) {
                          final index = entry.key;
                          final slot = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: slot['name'],
                                    decoration: const InputDecoration(
                                      labelText: '名前',
                                      hintText: 'ランチ',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      _timeSlots[index]['name'] = value;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: slot['start'],
                                    decoration: const InputDecoration(
                                      labelText: '開始',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      _timeSlots[index]['start'] = value;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: slot['end'],
                                    decoration: const InputDecoration(
                                      labelText: '終了',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      _timeSlots[index]['end'] = value;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _timeSlots.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        if (_timeSlots.isEmpty)
                          Text(
                            '「追加」ボタンから時間帯を設定してください',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 表示タグ設定セクション
            ExpansionTile(
              title: const Text('表示タグ設定'),
              subtitle: Text(
                _getActiveTagsText(),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              initiallyExpanded: _tagNew || _tagRecommended || _tagPopular ||
                  _tagLimitedTime || _tagLimitedQty || _tagOrganic,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'メニュー表示時に商品に付けるタグを選択してください。',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTagChip('新商品', _tagNew, const Color(0xFFFF6B6B), (v) {
                            setState(() => _tagNew = v);
                          }),
                          _buildTagChip('おすすめ', _tagRecommended, const Color(0xFF4ECDC4), (v) {
                            setState(() => _tagRecommended = v);
                          }),
                          _buildTagChip('大人気', _tagPopular, const Color(0xFFFFE66D), (v) {
                            setState(() => _tagPopular = v);
                          }),
                          _buildTagChip('期間限定', _tagLimitedTime, const Color(0xFFFF8E53), (v) {
                            setState(() => _tagLimitedTime = v);
                          }),
                          _buildTagChip('数量限定', _tagLimitedQty, const Color(0xFFA855F7), (v) {
                            setState(() => _tagLimitedQty = v);
                          }),
                          _buildTagChip('オーガニック', _tagOrganic, const Color(0xFF22C55E), (v) {
                            setState(() => _tagOrganic = v);
                          }),
                          _buildTagChip('辛い 🌶️', _isSpicy, const Color(0xFFEF4444), (v) {
                            setState(() => _isSpicy = v);
                          }),
                          _buildTagChip('ベジタリアン 🥗', _isVegetarian, const Color(0xFF10B981), (v) {
                            setState(() => _isVegetarian = v);
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 割引設定セクション
            ExpansionTile(
              title: const Text('割引設定'),
              subtitle: _hasDiscount
                  ? Text(
                      _getDiscountLabel(),
                      style: TextStyle(color: Colors.red[600], fontSize: 12, fontWeight: FontWeight.bold),
                    )
                  : null,
              initiallyExpanded: _hasDiscount,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'この商品に割引を適用します。割引価格がメニューや会計に反映されます。',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('割引を有効にする'),
                        value: _hasDiscount,
                        onChanged: (value) {
                          setState(() {
                            _hasDiscount = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_hasDiscount) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: '割引タイプ',
                                  border: OutlineInputBorder(),
                                ),
                                value: _discountType,
                                items: const [
                                  DropdownMenuItem(value: 'percent', child: Text('パーセント（%OFF）')),
                                  DropdownMenuItem(value: 'amount', child: Text('金額（¥OFF）')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _discountType = value;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _discountValueController,
                                decoration: InputDecoration(
                                  labelText: '割引値',
                                  border: const OutlineInputBorder(),
                                  suffixText: _discountType == 'percent' ? '%' : '¥',
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                ],
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 割引プレビュー
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_offer, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '割引プレビュー',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Builder(builder: (context) {
                                      final price = double.tryParse(_priceController.text) ?? 0;
                                      final discountValue = double.tryParse(_discountValueController.text) ?? 0;
                                      double discountedPrice;
                                      if (_discountType == 'percent') {
                                        discountedPrice = price * (1 - discountValue / 100);
                                      } else {
                                        discountedPrice = (price - discountValue).clamp(0, price);
                                      }
                                      return Row(
                                        children: [
                                          Text(
                                            '¥${price.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              decoration: TextDecoration.lineThrough,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward, size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            '¥${discountedPrice.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _getDiscountLabel(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // その他の設定
            const Text(
              'その他の設定',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              title: const Text('予約メニューに表示'),
              subtitle: const Text('ONにすると、お客様が予約時にこの商品を選択できます'),
              value: _showOnReservationMenu,
              onChanged: (value) {
                setState(() {
                  _showOnReservationMenu = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 32),

            // 保存ボタン
            ElevatedButton(
              onPressed: _isUploading ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : Text(widget.product == null ? '追加' : '更新'),
            ),
          ],
        ),
      ),
    );
  }

  // タグチップウィジェット
  Widget _buildTagChip(String label, bool isSelected, Color color, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      onSelected: onChanged,
      selectedColor: color,
      backgroundColor: color.withOpacity(0.1),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 1),
      ),
    );
  }

  // 有効なタグのテキストを取得
  String _getActiveTagsText() {
    final tags = <String>[];
    if (_tagNew) tags.add('新商品');
    if (_tagRecommended) tags.add('おすすめ');
    if (_tagPopular) tags.add('大人気');
    if (_tagLimitedTime) tags.add('期間限定');
    if (_tagLimitedQty) tags.add('数量限定');
    if (_tagOrganic) tags.add('オーガニック');
    if (_isSpicy) tags.add('辛い');
    if (_isVegetarian) tags.add('ベジタリアン');
    if (tags.isEmpty) return 'タグなし';
    return tags.join(', ');
  }

  // 割引ラベルを取得
  String _getDiscountLabel() {
    if (!_hasDiscount) return '';
    final value = double.tryParse(_discountValueController.text) ?? 0;
    if (_discountType == 'percent') {
      return '${value.toInt()}%OFF';
    } else {
      return '¥${value.toInt()}OFF';
    }
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('この商品を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final deleteProduct = ref.read(deleteProductProvider);
        await deleteProduct(widget.product!.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('商品を削除しました')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e')),
          );
        }
      }
    }
  }
}
