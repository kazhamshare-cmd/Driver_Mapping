import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order.dart';
import '../../models/adjustment.dart';
import '../../models/shop.dart';
import '../../services/unified_printer_service.dart';
import '../../services/firebase_service.dart'; // updateOrderStatus用
import '../../providers/locale_provider.dart';

class RegisterPaymentDialog extends ConsumerStatefulWidget {
  final OrderModel order;
  final String? shopName;
  final FirebaseService firebaseService;
  // レシート印刷用の店舗情報
  final String? shopAddress;
  final String? shopPhone;
  final Map<String, dynamic>? receiptSettings;
  // 支払い方法マスタ
  final List<PaymentMethodSetting> paymentMethods;
  // 担当スタッフ情報
  final String? staffId;
  final String? staffName;
  // 直接会計フラグ（メニューから直接選んで会計する場合）
  final bool isDirectCheckout;

  const RegisterPaymentDialog({
    super.key,
    required this.order,
    this.shopName,
    required this.firebaseService,
    this.shopAddress,
    this.shopPhone,
    this.receiptSettings,
    this.paymentMethods = const [],
    this.staffId,
    this.staffName,
    this.isDirectCheckout = false,
  });

  @override
  ConsumerState<RegisterPaymentDialog> createState() => _RegisterPaymentDialogState();
}

class _RegisterPaymentDialogState extends ConsumerState<RegisterPaymentDialog> {
  final _printerService = UnifiedPrinterService();
  bool _isProcessing = false;

  // 適用する調整リスト
  List<AdjustmentModel> _adjustments = [];

  // 現金支払い時の預かり金額
  double? _receivedAmount;
  double get _changeAmount => (_receivedAmount ?? 0) - _finalDueAmount;

  // --- 計算プロパティ ---

  // 1. 商品小計 (税抜) ※簡易的に subtotal を税抜と仮定
  // (本来は商品マスタの税区分を見るべきですが、ここでは order.subtotal を使用)
  double get _productSubtotal => widget.order.subtotal;

  // 2. 調整後の課税対象額
  double get _taxableAmount {
    double amount = _productSubtotal;
    for (var adj in _adjustments) {
      if (adj.type == AdjustmentType.discountAmount) {
        amount -= adj.value;
      } else if (adj.type == AdjustmentType.discountPercent) {
        amount -= _productSubtotal * (adj.value / 100);
      } else if (adj.type == AdjustmentType.surchargeTaxExcluded) {
        amount += adj.value;
      }
    }
    return amount < 0 ? 0 : amount;
  }

  // 3. 消費税 (10%固定)
  double get _taxAmount => (_taxableAmount * 0.10).floorToDouble();

  // 4. 税込合計 (課税対象 + 税 + 税込加算)
  double get _grandTotal {
    double total = _taxableAmount + _taxAmount;
    for (var adj in _adjustments) {
      if (adj.type == AdjustmentType.surchargeTaxIncluded) {
        total += adj.value;
      }
    }
    return total;
  }

  // 5. 支払い充当額 (金券・予約金)
  double get _prepaidAmount {
    double total = 0;
    
    // Stripe等の事前決済があれば加算
    // (OrderModelに paymentAmount があればそれを使う想定)
    // total += widget.order.payment?.amount ?? 0;

    for (var adj in _adjustments) {
      if (adj.type == AdjustmentType.paymentVoucher) {
        total += adj.value;
      }
    }
    return total;
  }

  // 6. 最終請求額
  double get _finalDueAmount {
    double due = _grandTotal - _prepaidAmount;
    return due < 0 ? 0 : due;
  }

  // --- アクション ---

  void _addAdjustment() async {
    final t = ref.read(translationProvider);
    // マスタ選択または手入力ダイアログを表示
    final result = await showDialog<AdjustmentModel>(
      context: context,
      builder: (context) => _AdjustmentInputModal(t: t),
    );

    if (result != null) {
      setState(() {
        _adjustments.add(result);
      });
    }
  }

  void _removeAdjustment(int index) {
    setState(() {
      _adjustments.removeAt(index);
    });
  }

  /// 現金支払い処理（預かり金額入力ダイアログを表示）
  Future<void> _processCashPayment() async {
    final t = ref.read(translationProvider);
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CashInputDialog(
        dueAmount: _finalDueAmount,
        grandTotal: _grandTotal,
        t: t,
      ),
    );

    if (result != null) {
      setState(() {
        _receivedAmount = result;
      });
      await _processPayment('cash', receivedAmount: result, paymentMethodName: '現金');
    }
  }

  /// ドロワー操作ログを保存
  Future<void> _logDrawerOperation(String operationType, [String? orderId]) async {
    try {
      await FirebaseFirestore.instance.collection('drawerLogs').add({
        'shopId': widget.order.shopId,
        'operationType': operationType, // 'payment', 'exchange', 'check', 'close'
        'orderId': orderId,
        'staffId': widget.staffId,
        'staffName': widget.staffName ?? '不明',
        'operatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ドロワーログ保存エラー: $e');
    }
  }

  Future<void> _processPayment(String method, {double? receivedAmount, String? paymentMethodName}) async {
    setState(() => _isProcessing = true);

    try {
      // 直接会計の場合は新規注文を作成
      if (widget.isDirectCheckout) {
        final newOrderData = <String, dynamic>{
          'shopId': widget.order.shopId,
          'tableId': 'direct',
          'tableNumber': widget.order.tableNumber,
          'orderNumber': widget.order.orderNumber,
          'items': widget.order.items.map((item) => item.toFirestore()).toList(),
          'subtotal': widget.order.subtotal,
          'tax': widget.order.tax,
          'total': widget.order.total,
          'status': 'completed',
          'paymentStatus': 'paid',
          'paymentMethod': method,
          'paymentMethodName': paymentMethodName ?? method,
          'adjustments': _adjustments.map((a) => a.toFirestore()).toList(),
          'finalTotal': _grandTotal,
          'paidAmount': _finalDueAmount,
          'isDirectCheckout': true,
          'orderedAt': Timestamp.now(),
          'completedAt': Timestamp.now(),
          'paidAt': Timestamp.now(),
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        // 担当スタッフ情報を保存
        if (widget.staffId != null) {
          newOrderData['paidBy'] = {
            'staffId': widget.staffId,
            'staffName': widget.staffName,
          };
        }

        // 現金支払いの場合は預かり金額とお釣りも保存
        if (method == 'cash' && receivedAmount != null) {
          newOrderData['receivedAmount'] = receivedAmount;
          newOrderData['changeAmount'] = receivedAmount - _finalDueAmount;
        }

        await FirebaseFirestore.instance.collection('orders').add(newOrderData);
      } else {
        // 既存注文の更新（通常の会計フロー）
        // 1. Firestore更新
        // 調整内容も保存しておくと後で分析できます
        final updateData = <String, dynamic>{
          'status': 'completed',
          'paymentStatus': 'paid',
          'paymentMethod': method,
          'paymentMethodName': paymentMethodName ?? method,
          'adjustments': _adjustments.map((a) => a.toFirestore()).toList(),
          'finalTotal': _grandTotal,
          'paidAmount': _finalDueAmount,
          'paidAt': Timestamp.now(),
          'completedAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };

        // 担当スタッフ情報を保存
        if (widget.staffId != null) {
          updateData['paidBy'] = {
            'staffId': widget.staffId,
            'staffName': widget.staffName,
          };
        }

        // 現金支払いの場合は預かり金額とお釣りも保存
        if (method == 'cash' && receivedAmount != null) {
          updateData['receivedAmount'] = receivedAmount;
          updateData['changeAmount'] = receivedAmount - _finalDueAmount;
        }

        await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update(updateData);
      }

      // 2. レシート印刷（調整内容・預かり金・お釣り込み・店舗情報）
      await _printerService.printPaymentReceipt(
        order: widget.order,
        shopName: widget.shopName,
        adjustments: _adjustments,
        grandTotal: _grandTotal,
        paymentMethod: method,
        receivedAmount: method == 'cash' ? receivedAmount : null,
        changeAmount: method == 'cash' && receivedAmount != null ? receivedAmount - _finalDueAmount : null,
        receiptSettings: widget.receiptSettings,
        shopAddress: widget.shopAddress,
        shopPhone: widget.shopPhone,
      );

      // 3. 現金支払いの場合はキャッシュドロワーを開放
      if (method == 'cash') {
        await _printerService.openCashDrawer();
        // ドロワー操作ログを保存
        await _logDrawerOperation('payment', widget.order.id);
      }

      if (mounted) {
        final t = ref.read(translationProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.text('paymentCompleted')), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true); // 完了を通知して閉じる
      }
    } catch (e) {
      debugPrint('会計エラー: $e');
      if (mounted) {
        final t = ref.read(translationProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.text('error')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${t.text('checkout')}: ${t.text('table')} ${widget.order.tableNumber}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            
            // 明細エリア (スクロール可能)
            Expanded(
              child: ListView(
                children: [
                  // 商品明細
                  if (widget.order.items.isNotEmpty) ...[
                    Text('【${t.text('productDetails')}】', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ...widget.order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName} x${item.quantity}',
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('¥${item.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    )),
                    const Divider(),
                  ],
                  // 商品小計
                  _buildLineItem(t.text('productSubtotalTaxExcl'), _productSubtotal),
                  
                  // 調整項目リスト
                  ..._adjustments.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final adj = entry.value;
                    String prefix = '';
                    String valueStr = '';
                    Color color = Colors.black;

                    switch (adj.type) {
                      case AdjustmentType.discountAmount:
                        prefix = '▲';
                        valueStr = adj.value.toStringAsFixed(0);
                        color = Colors.red;
                        break;
                      case AdjustmentType.discountPercent:
                        prefix = '▲';
                        // 割引額を計算して表示
                        valueStr = '${(_productSubtotal * adj.value / 100).toStringAsFixed(0)} (${adj.value}%)';
                        color = Colors.red;
                        break;
                      case AdjustmentType.surchargeTaxExcluded:
                      case AdjustmentType.surchargeTaxIncluded:
                        prefix = '+';
                        valueStr = adj.value.toStringAsFixed(0);
                        break;
                      case AdjustmentType.paymentVoucher:
                        prefix = '内金/金券';
                        valueStr = adj.value.toStringAsFixed(0);
                        color = Colors.blue;
                        break;
                    }

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${adj.name} (${adj.label})'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$prefix ¥$valueStr', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                            onPressed: () => _removeAdjustment(idx),
                          ),
                        ],
                      ),
                    );
                  }),

                  // 調整追加ボタン
                  Center(
                    child: TextButton.icon(
                      onPressed: _addAdjustment,
                      icon: const Icon(Icons.add),
                      label: Text(t.text('addAdjustment')),
                    ),
                  ),

                  const Divider(),
                  _buildLineItem(t.text('taxableAmount'), _taxableAmount, isBold: false),
                  _buildLineItem(t.text('consumptionTax'), _taxAmount, isBold: false),
                  const Divider(),
                  _buildLineItem(t.text('grandTotalTaxIncl'), _grandTotal, isBold: true, size: 18),

                  if (_prepaidAmount > 0) ...[
                    const SizedBox(height: 8),
                    _buildLineItem(t.text('prepaidVoucher'), _prepaidAmount, color: Colors.blue),
                  ],

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t.text('billingAmount'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('¥${_finalDueAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 支払いボタン - 支払い方法マスタから動的に生成
            _buildPaymentButtons(t),
          ],
        ),
      ),
    );
  }

  /// 支払い方法ボタンを動的に生成
  Widget _buildPaymentButtons(AppTranslations t) {
    // 支払い方法が設定されていない場合はデフォルトのボタンを表示
    if (widget.paymentMethods.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processCashPayment,
              icon: const Icon(Icons.money, color: Colors.white),
              label: Text(t.text('cashPayment'), style: const TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _processPayment('card', paymentMethodName: 'クレジットカード'),
              icon: const Icon(Icons.credit_card, color: Colors.white),
              label: Text(t.text('cardOther'), style: const TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      );
    }

    // 支払い方法をグリッドで表示（2列）
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.paymentMethods.map((method) {
        // 色を解析
        Color buttonColor = Colors.grey;
        if (method.color != null && method.color!.startsWith('#')) {
          try {
            buttonColor = Color(int.parse(method.color!.substring(1), radix: 16) + 0xFF000000);
          } catch (_) {}
        }

        // タイプに応じたアイコン
        IconData icon;
        switch (method.type) {
          case 'cash':
            icon = Icons.money;
            break;
          case 'card':
            icon = Icons.credit_card;
            break;
          case 'qr':
            icon = Icons.qr_code;
            break;
          case 'transfer':
            icon = Icons.account_balance;
            break;
          default:
            icon = Icons.payment;
        }

        return SizedBox(
          width: (MediaQuery.of(context).size.width - 80) / 2 - 4,
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () {
                    if (method.type == 'cash') {
                      _processCashPayment();
                    } else {
                      _processPayment(method.code, paymentMethodName: method.name);
                    }
                  },
            icon: Icon(icon, color: Colors.white),
            label: Text(
              method.name,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLineItem(String label, double value, {bool isBold = false, double size = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('¥${value.toStringAsFixed(0)}', style: TextStyle(fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}

// 調整内容入力モーダル
class _AdjustmentInputModal extends StatefulWidget {
  final AppTranslations t;

  const _AdjustmentInputModal({required this.t});

  @override
  State<_AdjustmentInputModal> createState() => _AdjustmentInputModalState();
}

class _AdjustmentInputModalState extends State<_AdjustmentInputModal> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  AdjustmentType _selectedType = AdjustmentType.discountAmount;

  // よく使うマスタ（本来はFirestoreから取得）
  final List<AdjustmentModel> _masters = [
    AdjustmentModel(name: 'ホットペッパー', type: AdjustmentType.discountAmount, value: 500),
    AdjustmentModel(name: '10%OFFクーポン', type: AdjustmentType.discountPercent, value: 10),
    AdjustmentModel(name: 'タバコ', type: AdjustmentType.surchargeTaxIncluded, value: 580),
    AdjustmentModel(name: '予約金充当', type: AdjustmentType.paymentVoucher, value: 0), // 金額は都度入力
  ];

  @override
  Widget build(BuildContext context) {
    final t = widget.t;

    return AlertDialog(
      title: Text(t.text('addAdjustmentTitle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // マスタから選択
            Text(t.text('commonItems'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Wrap(
              spacing: 8,
              children: _masters.map((m) => ActionChip(
                label: Text(m.name),
                onPressed: () {
                  setState(() {
                    _nameController.text = m.name;
                    _selectedType = m.type;
                    if (m.value > 0) _valueController.text = m.value.toStringAsFixed(0);
                  });
                },
              )).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),

            // 手入力フォーム
            DropdownButtonFormField<AdjustmentType>(
              value: _selectedType,
              decoration: InputDecoration(labelText: t.text('type')),
              items: [
                DropdownMenuItem(value: AdjustmentType.discountAmount, child: Text(t.text('discountYenBeforeTax'))),
                DropdownMenuItem(value: AdjustmentType.discountPercent, child: Text(t.text('discountPercentBeforeTax'))),
                DropdownMenuItem(value: AdjustmentType.surchargeTaxExcluded, child: Text(t.text('surchargeYenTaxExcl'))),
                DropdownMenuItem(value: AdjustmentType.surchargeTaxIncluded, child: Text(t.text('surchargeYenTaxIncl'))),
                DropdownMenuItem(value: AdjustmentType.paymentVoucher, child: Text(t.text('voucherPayment'))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: t.text('nameLabel')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valueController,
              decoration: InputDecoration(labelText: t.text('valueLabel')),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.text('cancel')),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text;
            final value = double.tryParse(_valueController.text);
            if (name.isNotEmpty && value != null) {
              Navigator.pop(context, AdjustmentModel(
                name: name,
                type: _selectedType,
                value: value,
              ));
            }
          },
          child: Text(t.text('add')),
        ),
      ],
    );
  }
}

/// 現金預かり金額入力ダイアログ
class _CashInputDialog extends StatefulWidget {
  final double dueAmount;
  final double grandTotal;
  final AppTranslations t;

  const _CashInputDialog({
    required this.dueAmount,
    required this.grandTotal,
    required this.t,
  });

  @override
  State<_CashInputDialog> createState() => _CashInputDialogState();
}

class _CashInputDialogState extends State<_CashInputDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  double _receivedAmount = 0;
  bool _isFirstTap = true; // 最初のタップでクリアするためのフラグ

  double get _changeAmount => _receivedAmount - widget.dueAmount;

  @override
  void initState() {
    super.initState();
    // 初期値として請求金額を設定
    _receivedAmount = widget.dueAmount;
    _controller.text = widget.dueAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    setState(() {
      _receivedAmount = double.tryParse(value) ?? 0;
    });
  }

  void _onFieldTap() {
    // 最初のタップ時またはクイックボタン後の直接入力時にクリア
    if (_isFirstTap) {
      _controller.clear();
      setState(() {
        _receivedAmount = 0;
        _isFirstTap = false;
      });
    }
  }

  void _addQuickAmount(int amount) {
    setState(() {
      _receivedAmount += amount;
      _controller.text = _receivedAmount.toStringAsFixed(0);
      _isFirstTap = true; // クイックボタン後は次のタップでクリア
    });
  }

  void _setQuickAmount(int amount) {
    setState(() {
      _receivedAmount = amount.toDouble();
      _controller.text = amount.toString();
      _isFirstTap = true; // クイックボタン後は次のタップでクリア
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final isValid = _receivedAmount >= widget.dueAmount;

    return AlertDialog(
      title: Text(t.text('cashReceived')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 請求金額表示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.text('billingAmount'), style: const TextStyle(fontSize: 16)),
                  Text(
                    '¥${widget.dueAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 預かり金額入力
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: t.text('receivedAmountLabel'),
                prefixText: '¥ ',
                border: const OutlineInputBorder(),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onAmountChanged,
              onTap: _onFieldTap,
            ),
            const SizedBox(height: 12),

            // クイック入力ボタン
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickButton(label: '¥1,000', onPressed: () => _setQuickAmount(1000)),
                _QuickButton(label: '¥2,000', onPressed: () => _setQuickAmount(2000)),
                _QuickButton(label: '¥5,000', onPressed: () => _setQuickAmount(5000)),
                _QuickButton(label: '¥10,000', onPressed: () => _setQuickAmount(10000)),
                _QuickButton(label: '+¥1,000', onPressed: () => _addQuickAmount(1000)),
                _QuickButton(label: '+¥5,000', onPressed: () => _addQuickAmount(5000)),
                _QuickButton(label: t.text('exact'), onPressed: () => _setQuickAmount(widget.dueAmount.toInt())),
              ],
            ),
            const SizedBox(height: 16),

            // お釣り表示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isValid ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isValid ? Colors.green : Colors.red, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.text('changeLabel'),
                    style: TextStyle(fontSize: 18, color: isValid ? Colors.green.shade700 : Colors.red.shade700),
                  ),
                  Text(
                    isValid ? '¥${_changeAmount.toStringAsFixed(0)}' : t.text('shortage'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isValid ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.text('cancel')),
        ),
        FilledButton(
          onPressed: isValid ? () => Navigator.pop(context, _receivedAmount) : null,
          child: Text(t.text('completeCheckout')),
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _QuickButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label),
    );
  }
}