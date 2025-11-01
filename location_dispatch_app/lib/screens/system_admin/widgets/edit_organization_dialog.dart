import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/organization.dart';
import '../../../models/business_type.dart';
import '../../../models/subscription_plan.dart';

/// 組織編集ダイアログ
class EditOrganizationDialog extends StatefulWidget {
  final Organization organization;

  const EditOrganizationDialog({
    super.key,
    required this.organization,
  });

  @override
  State<EditOrganizationDialog> createState() => _EditOrganizationDialogState();
}

class _EditOrganizationDialogState extends State<EditOrganizationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  late TextEditingController _nameController;
  late TextEditingController _companyNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _maxUsersController;

  late BusinessType _selectedBusinessType;
  late SubscriptionPlan _selectedSubscriptionPlan;
  late bool _isActive;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.organization.name);
    _companyNameController = TextEditingController(text: widget.organization.companyName);
    _phoneController = TextEditingController(text: widget.organization.phone);
    _emailController = TextEditingController(text: widget.organization.email);
    _addressController = TextEditingController(text: widget.organization.address);
    _maxUsersController = TextEditingController(
      text: widget.organization.maxUsers?.toString() ?? '',
    );

    _selectedBusinessType = widget.organization.businessType;
    _selectedSubscriptionPlan = widget.organization.subscriptionPlan;
    _isActive = widget.organization.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _maxUsersController.dispose();
    super.dispose();
  }

  Future<void> _updateOrganization() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final maxUsers = _maxUsersController.text.trim().isEmpty
          ? null
          : int.tryParse(_maxUsersController.text.trim());

      await _firestore.collection('organizations').doc(widget.organization.id).update({
        'name': _nameController.text.trim(),
        'companyName': _companyNameController.text.trim().isEmpty
            ? null
            : _companyNameController.text.trim(),
        'businessType': _selectedBusinessType.toJson(),
        'subscriptionPlan': _selectedSubscriptionPlan.toJson(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'maxUsers': maxUsers,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('組織情報を更新しました'),
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
        constraints: const BoxConstraints(maxWidth: 600),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            title: const Text('組織編集'),
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
                // 組織名
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '組織名 *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '組織名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 会社名
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(
                    labelText: '会社名',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.apartment),
                  ),
                ),
                const SizedBox(height: 16),

                // 業種
                DropdownButtonFormField<BusinessType>(
                  value: _selectedBusinessType,
                  decoration: const InputDecoration(
                    labelText: '業種 *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: BusinessType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedBusinessType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // サブスクリプションプラン
                DropdownButtonFormField<SubscriptionPlan>(
                  value: _selectedSubscriptionPlan,
                  decoration: const InputDecoration(
                    labelText: 'サブスクリプションプラン *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  items: SubscriptionPlan.values.map((plan) {
                    return DropdownMenuItem(
                      value: plan,
                      child: Row(
                        children: [
                          Text(plan.displayName),
                          const SizedBox(width: 8),
                          Text(
                            '¥${plan.monthlyPrice}/月',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedSubscriptionPlan = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 最大ユーザー数
                TextFormField(
                  controller: _maxUsersController,
                  decoration: const InputDecoration(
                    labelText: '最大ユーザー数',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                    helperText: '空欄の場合は無制限',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final num = int.tryParse(value.trim());
                      if (num == null || num <= 0) {
                        return '1以上の数値を入力してください';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 電話番号
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: '電話番号',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // メールアドレス
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!value.contains('@')) {
                        return '有効なメールアドレスを入力してください';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 住所
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: '住所',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // アクティブステータス
                Card(
                  child: SwitchListTile(
                    title: const Text('アクティブステータス'),
                    subtitle: Text(_isActive ? '有効' : '無効'),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() => _isActive = value);
                    },
                    secondary: Icon(
                      _isActive ? Icons.check_circle : Icons.cancel,
                      color: _isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 現在の情報
                Card(
                  color: Colors.grey[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '現在の情報',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('組織ID: ${widget.organization.id}'),
                        Text('現在のユーザー数: ${widget.organization.activeUserCount}人'),
                        Text('オーナーID: ${widget.organization.ownerId}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 更新ボタン
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateOrganization,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
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
                      : const Text(
                          '更新',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
