import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/service_menu.dart';
import '../../../models/service_option.dart';

class OptionEditDialog extends StatefulWidget {
  final ServiceMenu menu;
  final String organizationId;
  final ServiceOption? option;

  const OptionEditDialog({
    super.key,
    required this.menu,
    required this.organizationId,
    this.option,
  });

  @override
  State<OptionEditDialog> createState() => _OptionEditDialogState();
}

class _OptionEditDialogState extends State<OptionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  OptionType _selectedType = OptionType.singleChoice;
  bool _isRequired = false;
  bool _isLoading = false;

  final List<_OptionItemData> _items = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.option?.name ?? '');
    _descriptionController = TextEditingController(text: widget.option?.description ?? '');
    _selectedType = widget.option?.optionType ?? OptionType.singleChoice;
    _isRequired = widget.option?.isRequired ?? false;

    if (widget.option != null) {
      for (final item in widget.option!.items) {
        _items.add(_OptionItemData(
          name: item.name,
          additionalPrice: item.additionalPrice,
          description: item.description,
          isDefault: item.isDefault,
        ));
      }
    } else {
      // デフォルトで2つの選択肢を追加
      _items.add(_OptionItemData(name: '', additionalPrice: 0, isDefault: true));
      _items.add(_OptionItemData(name: '', additionalPrice: 0));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_OptionItemData(name: '', additionalPrice: 0));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  Future<void> _saveOption() async {
    if (!_formKey.currentState!.validate()) return;

    // 少なくとも1つの選択肢が必要
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('少なくとも1つの選択肢を追加してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 選択肢の名前が空でないかチェック
    for (final item in _items) {
      if (item.name.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('すべての選択肢に名前を入力してください'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'organizationId': widget.organizationId,
        'serviceMenuId': widget.menu.id,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'optionType': _selectedType.name,
        'isRequired': _isRequired,
        'isActive': true,
        'displayOrder': widget.option?.displayOrder ?? 0,
        'items': _items.map((item) => item.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.option == null) {
        // 新規作成
        data['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('serviceOptions').add(data);
      } else {
        // 更新
        await _firestore.collection('serviceOptions').doc(widget.option!.id).update(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.option == null ? 'オプションを追加しました' : 'オプションを更新しました',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            title: Text(widget.option == null ? 'オプション追加' : 'オプション編集'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'オプション名',
                    hintText: '例：鍵の種類、追加作業',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'オプション名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '説明（任意）',
                    hintText: '例：鍵の種類を選択してください',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<OptionType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: '選択タイプ',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tune),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: OptionType.singleChoice,
                      child: Text('単一選択'),
                    ),
                    DropdownMenuItem(
                      value: OptionType.multipleChoice,
                      child: Text('複数選択'),
                    ),
                    DropdownMenuItem(
                      value: OptionType.quantity,
                      child: Text('数量入力'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('必須オプション'),
                  subtitle: const Text('顧客は必ず選択する必要があります'),
                  value: _isRequired,
                  onChanged: (value) {
                    setState(() => _isRequired = value);
                  },
                ),
                const SizedBox(height: 24),
                // 数量入力タイプの場合は選択肢不要
                if (_selectedType != OptionType.quantity) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '選択肢',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('追加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _buildItemField(index, item);
                  }).toList(),
                  const SizedBox(height: 24),
                ],
                // 数量入力タイプの説明
                if (_selectedType == OptionType.quantity) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '数量入力タイプは選択肢不要です。\n顧客が数量を入力し、基本料金に追加されます。',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveOption,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                          widget.option == null ? '追加' : '更新',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemField(int index, _OptionItemData item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item.name,
                    decoration: const InputDecoration(
                      labelText: '選択肢名',
                      hintText: '例：ディンプルキー',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      item.name = value;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.additionalPrice.toString(),
                    decoration: const InputDecoration(
                      labelText: '追加料金',
                      hintText: '0',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixText: '円',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      item.additionalPrice = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _items.length > 1 ? () => _removeItem(index) : null,
                ),
              ],
            ),
            if (_selectedType == OptionType.singleChoice) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('デフォルト選択', style: TextStyle(fontSize: 14)),
                value: item.isDefault,
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() {
                    // 他のアイテムのデフォルトをfalseにする
                    for (var i = 0; i < _items.length; i++) {
                      _items[i].isDefault = i == index && (value ?? false);
                    }
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionItemData {
  String name;
  int additionalPrice;
  String? description;
  bool isDefault;

  _OptionItemData({
    required this.name,
    required this.additionalPrice,
    this.description,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'additionalPrice': additionalPrice,
      'description': description,
      'isDefault': isDefault,
    };
  }
}
