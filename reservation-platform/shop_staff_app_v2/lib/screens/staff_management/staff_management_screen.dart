import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/staff_management_service.dart';
import '../../providers/auth_provider.dart';

/// スタッフ管理画面（オーナー専用）
class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  final StaffManagementService _staffService = StaffManagementService();
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final staffUser = ref.watch(staffUserProvider).value;
    final shopId = staffUser?.shopId;

    if (shopId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('スタッフ管理'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('スタッフ管理'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // 無効スタッフ表示切替
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility_off : Icons.visibility),
            tooltip: _showInactive ? '無効スタッフを非表示' : '無効スタッフを表示',
            onPressed: () {
              setState(() {
                _showInactive = !_showInactive;
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _staffService.watchEmployees(shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('エラー: ${snapshot.error}'),
                ],
              ),
            );
          }

          final allEmployees = snapshot.data ?? [];
          final employees = _showInactive
              ? allEmployees
              : allEmployees.where((e) => e['isActive'] != false).toList();

          if (employees.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 24),
                  Text(
                    'スタッフがいません',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text('右下のボタンからスタッフを追加してください'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employee = employees[index];
              return _buildEmployeeCard(context, employee);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmployeeDialog(context, shopId),
        icon: const Icon(Icons.person_add),
        label: const Text('スタッフ追加'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmployeeCard(
      BuildContext context, Map<String, dynamic> employee) {
    final isActive = employee['isActive'] != false;
    final role = employee['role'] ?? 'staff';
    final firstName = employee['firstName'] ?? '';
    final lastName = employee['lastName'] ?? '';
    final email = employee['email'] ?? '';
    final hourlyWage = (employee['hourlyWage'] ?? 1000).toDouble();
    final phone = employee['phone'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 2 : 0,
      color: isActive ? null : Colors.grey[200],
      child: InkWell(
        onTap: () => _showEmployeeDetailDialog(context, employee),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // アバター
              CircleAvatar(
                radius: 28,
                backgroundColor: _getRoleColor(role).withOpacity(0.2),
                child: Text(
                  firstName.isNotEmpty ? firstName[0] : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(role),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$lastName $firstName',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isActive ? null : Colors.grey,
                            ),
                          ),
                        ),
                        _buildRoleBadge(role),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.payments,
                            size: 16, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Text(
                          '¥${hourlyWage.toInt()}/時',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                    if (!isActive) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '無効',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String label;

    switch (role) {
      case 'owner':
        color = Colors.purple;
        label = 'オーナー';
        break;
      case 'manager':
        color = Colors.blue;
        label = '店長';
        break;
      default:
        color = Colors.green;
        label = 'スタッフ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  void _showAddEmployeeDialog(BuildContext context, String shopId) {
    final formKey = GlobalKey<FormState>();
    final lastNameController = TextEditingController();
    final firstNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final hourlyWageController = TextEditingController(text: '1000');
    String selectedRole = 'staff';
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.person_add, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('新規スタッフ追加'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: lastNameController,
                                decoration: const InputDecoration(
                                  labelText: '姓 *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value?.isEmpty == true ? '必須項目です' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: firstNameController,
                                decoration: const InputDecoration(
                                  labelText: '名 *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value?.isEmpty == true ? '必須項目です' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'メールアドレス *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value?.isEmpty == true) return '必須項目です';
                            if (!value!.contains('@')) {
                              return '有効なメールアドレスを入力してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: '初期パスワード *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                            helperText: '6文字以上',
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value?.isEmpty == true) return '必須項目です';
                            if (value!.length < 6) {
                              return '6文字以上で入力してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: '電話番号',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: '役割 *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'staff',
                              child: Text('スタッフ'),
                            ),
                            DropdownMenuItem(
                              value: 'manager',
                              child: Text('店長'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedRole = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: hourlyWageController,
                          decoration: const InputDecoration(
                            labelText: '時給 (円) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payments),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty == true) return '必須項目です';
                            if (int.tryParse(value!) == null) {
                              return '数値を入力してください';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setState(() => isLoading = true);

                          final result = await _staffService.createEmployee(
                            shopId: shopId,
                            email: emailController.text.trim(),
                            password: passwordController.text,
                            firstName: firstNameController.text.trim(),
                            lastName: lastNameController.text.trim(),
                            role: selectedRole,
                            hourlyWage:
                                double.parse(hourlyWageController.text),
                            phone: phoneController.text.trim().isEmpty
                                ? null
                                : phoneController.text.trim(),
                          );

                          setState(() => isLoading = false);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['success']
                                    ? 'スタッフを追加しました'
                                    : 'エラー: ${result['error']}'),
                                backgroundColor: result['success']
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('追加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEmployeeDetailDialog(
      BuildContext context, Map<String, dynamic> employee) {
    final employeeId = employee['id'];
    final isActive = employee['isActive'] != false;
    final role = employee['role'] ?? 'staff';

    // オーナーは編集不可（自分自身の可能性があるため）
    if (role == 'owner') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('オーナー情報'),
          content: const Text('オーナーの情報はこの画面からは編集できません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('情報を編集'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditEmployeeDialog(context, employee);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset, color: Colors.orange),
                title: const Text('パスワードをリセット'),
                onTap: () {
                  Navigator.pop(context);
                  _showPasswordResetDialog(context, employeeId);
                },
              ),
              if (isActive)
                ListTile(
                  leading: const Icon(Icons.person_off, color: Colors.red),
                  title: const Text('無効にする'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeactivate(context, employeeId);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.green),
                  title: const Text('有効にする'),
                  onTap: () {
                    Navigator.pop(context);
                    _activateEmployee(context, employeeId);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showEditEmployeeDialog(
      BuildContext context, Map<String, dynamic> employee) {
    final formKey = GlobalKey<FormState>();
    final employeeId = employee['id'];
    final lastNameController =
        TextEditingController(text: employee['lastName'] ?? '');
    final firstNameController =
        TextEditingController(text: employee['firstName'] ?? '');
    final phoneController =
        TextEditingController(text: employee['phone'] ?? '');
    final hourlyWageController = TextEditingController(
        text: (employee['hourlyWage'] ?? 1000).toString());
    String selectedRole = employee['role'] ?? 'staff';
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('スタッフ情報編集'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: lastNameController,
                                decoration: const InputDecoration(
                                  labelText: '姓 *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value?.isEmpty == true ? '必須項目です' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: firstNameController,
                                decoration: const InputDecoration(
                                  labelText: '名 *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value?.isEmpty == true ? '必須項目です' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: '電話番号',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: '役割 *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'staff',
                              child: Text('スタッフ'),
                            ),
                            DropdownMenuItem(
                              value: 'manager',
                              child: Text('店長'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedRole = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: hourlyWageController,
                          decoration: const InputDecoration(
                            labelText: '時給 (円) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payments),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty == true) return '必須項目です';
                            if (int.tryParse(value!) == null) {
                              return '数値を入力してください';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setState(() => isLoading = true);

                          final result = await _staffService.updateEmployee(
                            employeeId: employeeId,
                            firstName: firstNameController.text.trim(),
                            lastName: lastNameController.text.trim(),
                            role: selectedRole,
                            hourlyWage:
                                double.parse(hourlyWageController.text),
                            phone: phoneController.text.trim().isEmpty
                                ? null
                                : phoneController.text.trim(),
                          );

                          setState(() => isLoading = false);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['success']
                                    ? '情報を更新しました'
                                    : 'エラー: ${result['error']}'),
                                backgroundColor: result['success']
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPasswordResetDialog(BuildContext context, String employeeId) {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.lock_reset, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('パスワードリセット'),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: '新しいパスワード *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        helperText: '6文字以上',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value?.isEmpty == true) return '必須項目です';
                        if (value!.length < 6) {
                          return '6文字以上で入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmController,
                      decoration: const InputDecoration(
                        labelText: 'パスワード確認 *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value != passwordController.text) {
                          return 'パスワードが一致しません';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setState(() => isLoading = true);

                          final result =
                              await _staffService.changeEmployeePassword(
                            employeeId: employeeId,
                            newPassword: passwordController.text,
                          );

                          setState(() => isLoading = false);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['success']
                                    ? 'パスワードを変更しました'
                                    : 'エラー: ${result['error']}'),
                                backgroundColor: result['success']
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('変更'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeactivate(BuildContext context, String employeeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('確認'),
          ],
        ),
        content: const Text(
          'このスタッフを無効にしますか？\n無効にしたスタッフはログインできなくなります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await _staffService.deactivateEmployee(employeeId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['success']
                        ? 'スタッフを無効にしました'
                        : 'エラー: ${result['error']}'),
                    backgroundColor:
                        result['success'] ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('無効にする'),
          ),
        ],
      ),
    );
  }

  void _activateEmployee(BuildContext context, String employeeId) async {
    final result = await _staffService.activateEmployee(employeeId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              result['success'] ? 'スタッフを有効にしました' : 'エラー: ${result['error']}'),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
