import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/translation_service.dart';

class ProductOptionsScreen extends ConsumerWidget {
  const ProductOptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffUserAsync = ref.watch(staffUserProvider);

    return staffUserAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('エラー: $error')),
      ),
      data: (staffUser) {
        if (staffUser == null) {
          return const Scaffold(
            body: Center(child: Text('ログインしてください')),
          );
        }

        final optionsAsync = ref.watch(productOptionsProvider(staffUser.shopId));

        return Scaffold(
          appBar: AppBar(
            title: const Text('オプション管理'),
          ),
          body: optionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('エラー: $error')),
            data: (options) {
              if (options.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tune, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'オプションがありません',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return _OptionCard(
                    option: option,
                    shopId: staffUser.shopId,
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _OptionDialog(shopId: staffUser.shopId),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('オプション追加'),
          ),
        );
      },
    );
  }
}

class _OptionCard extends ConsumerWidget {
  final ProductOption option;
  final String shopId;

  const _OptionCard({
    required this.option,
    required this.shopId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          option.type == 'single' ? Icons.radio_button_checked : Icons.check_box,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(
          option.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${option.type == 'single' ? '単一選択' : '複数選択'} • ${option.required ? '必須' : '任意'} • ${option.choices.length}個の選択肢',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => _OptionDialog(
                    shopId: shopId,
                    option: option,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteOption(context, ref, option),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '選択肢:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...option.choices.map((choice) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            choice.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '+¥${choice.price.toInt()}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOption(BuildContext context, WidgetRef ref, ProductOption option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('オプション「${option.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final deleteOption = ref.read(deleteProductOptionProvider);
        await deleteOption(option.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('オプションを削除しました')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e')),
          );
        }
      }
    }
  }
}

class _OptionDialog extends ConsumerStatefulWidget {
  final String shopId;
  final ProductOption? option;

  const _OptionDialog({
    required this.shopId,
    this.option,
  });

  @override
  ConsumerState<_OptionDialog> createState() => _OptionDialogState();
}

class _OptionDialogState extends ConsumerState<_OptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _nameEnController;
  late TextEditingController _nameThController;
  late TextEditingController _nameZhTwController;
  late TextEditingController _nameKoController;
  late String _type;
  late bool _required;
  late List<ProductOptionChoice> _choices;
  bool _isTranslating = false;
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    final o = widget.option;
    _nameController = TextEditingController(text: o?.name ?? '');
    _nameEnController = TextEditingController(text: o?.nameEn ?? '');
    _nameThController = TextEditingController(text: o?.nameTh ?? '');
    _nameZhTwController = TextEditingController(text: o?.nameZhTw ?? '');
    _nameKoController = TextEditingController(text: o?.nameKo ?? '');
    _type = o?.type ?? 'single';
    _required = o?.required ?? false;
    _choices = o?.choices ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _nameThController.dispose();
    _nameZhTwController.dispose();
    _nameKoController.dispose();
    super.dispose();
  }

  void _addChoice() {
    showDialog(
      context: context,
      builder: (context) => _ChoiceDialog(
        onSave: (choice) {
          setState(() {
            _choices.add(choice);
          });
        },
      ),
    );
  }

  void _editChoice(int index) {
    showDialog(
      context: context,
      builder: (context) => _ChoiceDialog(
        choice: _choices[index],
        onSave: (choice) {
          setState(() {
            _choices[index] = choice;
          });
        },
      ),
    );
  }

  Future<void> _translateToAllLanguages() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('オプション名を入力してから翻訳してください')),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final results = await _translationService.translateSingleText(
        text: name,
        sourceLanguage: 'ja',
        targetLanguages: ['en', 'th', 'zh-TW', 'ko'],
      );

      setState(() {
        if (results['en'] != null) _nameEnController.text = results['en']!;
        if (results['th'] != null) _nameThController.text = results['th']!;
        if (results['zh-TW'] != null) _nameZhTwController.text = results['zh-TW']!;
        if (results['ko'] != null) _nameKoController.text = results['ko']!;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('翻訳が完了しました'), backgroundColor: Colors.green),
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

  Future<void> _saveOption() async {
    if (!_formKey.currentState!.validate()) return;
    if (_choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('選択肢を1つ以上追加してください')),
      );
      return;
    }

    try {
      final option = ProductOption(
        id: widget.option?.id ?? '',
        shopId: widget.shopId,
        name: _nameController.text,
        nameEn: _nameEnController.text.isEmpty ? null : _nameEnController.text,
        nameTh: _nameThController.text.isEmpty ? null : _nameThController.text,
        nameZhTw: _nameZhTwController.text.isEmpty ? null : _nameZhTwController.text,
        nameKo: _nameKoController.text.isEmpty ? null : _nameKoController.text,
        type: _type,
        required: _required,
        displayStatus: 'available',
        choices: _choices,
        isActive: true,
        createdAt: widget.option?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saveOption = ref.read(saveProductOptionProvider);
      await saveOption(option);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.option == null ? 'オプションを追加しました' : 'オプションを更新しました'),
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
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.option == null ? 'オプション追加' : 'オプション編集',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'オプション名 *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'オプション名を入力してください';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: '選択タイプ',
                              border: OutlineInputBorder(),
                            ),
                            value: _type,
                            items: const [
                              DropdownMenuItem(value: 'single', child: Text('単一選択')),
                              DropdownMenuItem(value: 'multiple', child: Text('複数選択')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _type = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('必須'),
                            value: _required,
                            onChanged: (value) {
                              setState(() {
                                _required = value ?? false;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    ExpansionTile(
                      title: const Text('多言語設定'),
                      children: [
                        // AI翻訳ボタン
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
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
                              minimumSize: const Size(double.infinity, 44),
                            ),
                          ),
                        ),
                        TextFormField(
                          controller: _nameEnController,
                          decoration: const InputDecoration(
                            labelText: 'オプション名（英語）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameThController,
                          decoration: const InputDecoration(
                            labelText: 'オプション名（タイ語）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameZhTwController,
                          decoration: const InputDecoration(
                            labelText: 'オプション名（繁体字中国語）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameKoController,
                          decoration: const InputDecoration(
                            labelText: 'オプション名（韓国語）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '選択肢',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addChoice,
                          icon: const Icon(Icons.add),
                          label: const Text('追加'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    ..._choices.asMap().entries.map((entry) {
                      final index = entry.key;
                      final choice = entry.value;
                      return Card(
                        child: ListTile(
                          title: Text(choice.name),
                          subtitle: Text('+¥${choice.price.toInt()}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editChoice(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _choices.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveOption,
                      child: Text(widget.option == null ? '追加' : '更新'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceDialog extends StatefulWidget {
  final ProductOptionChoice? choice;
  final Function(ProductOptionChoice) onSave;

  const _ChoiceDialog({
    this.choice,
    required this.onSave,
  });

  @override
  State<_ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends State<_ChoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _nameEnController;
  late TextEditingController _nameThController;
  late TextEditingController _nameZhTwController;
  late TextEditingController _nameKoController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    final c = widget.choice;
    _nameController = TextEditingController(text: c?.name ?? '');
    _nameEnController = TextEditingController(text: c?.nameEn ?? '');
    _nameThController = TextEditingController(text: c?.nameTh ?? '');
    _nameZhTwController = TextEditingController(text: c?.nameZhTw ?? '');
    _nameKoController = TextEditingController(text: c?.nameKo ?? '');
    _priceController = TextEditingController(text: c?.price.toString() ?? '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _nameThController.dispose();
    _nameZhTwController.dispose();
    _nameKoController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final choice = ProductOptionChoice(
      id: widget.choice?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      nameEn: _nameEnController.text.isEmpty ? null : _nameEnController.text,
      nameTh: _nameThController.text.isEmpty ? null : _nameThController.text,
      nameZhTw: _nameZhTwController.text.isEmpty ? null : _nameZhTwController.text,
      nameKo: _nameKoController.text.isEmpty ? null : _nameKoController.text,
      price: double.parse(_priceController.text),
    );

    widget.onSave(choice);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.choice == null ? '選択肢追加' : '選択肢編集',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '選択肢名 *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '選択肢名を入力してください';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: '追加料金 *',
                  border: OutlineInputBorder(),
                  prefixText: '¥',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '料金を入力してください';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              ExpansionTile(
                title: const Text('多言語設定'),
                children: [
                  TextFormField(
                    controller: _nameEnController,
                    decoration: const InputDecoration(
                      labelText: '選択肢名（英語）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameThController,
                    decoration: const InputDecoration(
                      labelText: '選択肢名（タイ語）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameZhTwController,
                    decoration: const InputDecoration(
                      labelText: '選択肢名（繁体字中国語）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameKoController,
                    decoration: const InputDecoration(
                      labelText: '選択肢名（韓国語）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(widget.choice == null ? '追加' : '更新'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
