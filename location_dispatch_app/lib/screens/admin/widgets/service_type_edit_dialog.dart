import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/service_type_master.dart';

class ServiceTypeEditDialog extends StatefulWidget {
  final ServiceTypeMaster? serviceType;

  const ServiceTypeEditDialog({
    super.key,
    this.serviceType,
  });

  @override
  State<ServiceTypeEditDialog> createState() => _ServiceTypeEditDialogState();
}

class _ServiceTypeEditDialogState extends State<ServiceTypeEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _displayOrderController;

  String _selectedIcon = 'build';
  String _selectedColor = '#2196F3';
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.serviceType?.name ?? '');
    _descriptionController = TextEditingController(text: widget.serviceType?.description ?? '');
    _displayOrderController = TextEditingController(
      text: widget.serviceType?.displayOrder.toString() ?? '0',
    );
    _selectedIcon = widget.serviceType?.iconName ?? 'build';
    _selectedColor = widget.serviceType?.colorCode ?? '#2196F3';
    _isActive = widget.serviceType?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'iconName': _selectedIcon,
        'colorCode': _selectedColor,
        'displayOrder': int.tryParse(_displayOrderController.text) ?? 0,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.serviceType == null) {
        // 新規作成
        data['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('serviceTypes').add(data);
      } else {
        // 更新
        await _firestore.collection('serviceTypes').doc(widget.serviceType!.id).update(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.serviceType == null
                  ? 'サービスタイプを追加しました'
                  : 'サービスタイプを更新しました',
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
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            title: Text(
              widget.serviceType == null
                  ? 'サービスタイプ追加'
                  : 'サービスタイプ編集',
            ),
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
                    labelText: 'サービスタイプ名',
                    hintText: '例：鍵トラブル、水道トラブル',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'サービスタイプ名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '説明',
                    hintText: '例：鍵の開錠・交換・作成などのサービス',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '説明を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayOrderController,
                  decoration: const InputDecoration(
                    labelText: '表示順序',
                    hintText: '0',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sort),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 24),
                const Text(
                  'アイコン選択',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildIconSelector(),
                const SizedBox(height: 24),
                const Text(
                  'カラー選択',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildColorSelector(),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('有効'),
                  subtitle: const Text('無効にすると組織の選択肢に表示されません'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() => _isActive = value);
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
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
                          widget.serviceType == null ? '追加' : '更新',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ServiceTypeMaster.commonIcons.map((iconData) {
        final isSelected = iconData['name'] == _selectedIcon;
        return InkWell(
          onTap: () {
            setState(() => _selectedIcon = iconData['name']);
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.purple.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              border: Border.all(
                color: isSelected ? Colors.purple : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconData['icon'],
                  color: isSelected ? Colors.purple : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  iconData['label'],
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected ? Colors.purple : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ServiceTypeMaster.commonColors.map((colorData) {
        final isSelected = colorData['code'] == _selectedColor;
        return InkWell(
          onTap: () {
            setState(() => _selectedColor = colorData['code']);
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colorData['color'],
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey[300]!,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
