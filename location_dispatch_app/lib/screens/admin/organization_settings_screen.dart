import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/organization.dart';

/// 組織設定管理画面
class OrganizationSettingsScreen extends StatefulWidget {
  const OrganizationSettingsScreen({super.key});

  @override
  State<OrganizationSettingsScreen> createState() =>
      _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState
    extends State<OrganizationSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  Organization? _organization;
  bool _isLoading = true;
  bool _isSaving = false;

  // フォームフィールド
  final _nameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _maxUsersController = TextEditingController();
  final _mapSearchController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  double _selectedZoom = 12.0;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadOrganization();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _maxUsersController.dispose();
    _mapSearchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadOrganization() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final orgId = userDoc.data()?['organizationId'];

      if (orgId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final orgDoc = await _firestore.collection('organizations').doc(orgId).get();
      if (!orgDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final org = Organization.fromFirestore(orgDoc);

      setState(() {
        _organization = org;
        _nameController.text = org.name;
        _companyNameController.text = org.companyName ?? '';
        _phoneController.text = org.phone ?? '';
        _emailController.text = org.email ?? '';
        _addressController.text = org.address ?? '';
        _maxUsersController.text = org.maxUsers?.toString() ?? '';

        if (org.mapCenterLocation != null) {
          _selectedLocation = LatLng(
            org.mapCenterLocation!.latitude,
            org.mapCenterLocation!.longitude,
          );
          _selectedZoom = org.mapDefaultZoom ?? 12.0;
          _updateMarker(_selectedLocation!);
        }

        _isLoading = false;
      });
    } catch (e) {
      print('組織情報読み込みエラー: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('組織情報の読み込みに失敗しました: $e')),
        );
      }
    }
  }

  void _updateMarker(LatLng position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('center'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(
            title: '地図の中心位置',
            snippet: 'この位置を初期表示位置として使用します',
          ),
        ),
      );
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('場所が見つかりませんでした')),
          );
        }
        return;
      }

      final location = locations.first;
      final targetPosition = LatLng(location.latitude, location.longitude);

      setState(() {
        _selectedLocation = targetPosition;
        _updateMarker(targetPosition);
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: targetPosition,
            zoom: 14,
          ),
        ),
      );

      print('検索成功: $query -> ${location.latitude}, ${location.longitude}');
    } catch (e) {
      print('検索エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('検索に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    if (_organization == null) return;

    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'companyName': _companyNameController.text.trim().isEmpty
            ? null
            : _companyNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'maxUsers': _maxUsersController.text.trim().isEmpty
            ? null
            : int.tryParse(_maxUsersController.text.trim()),
        'mapCenterLocation': _selectedLocation != null
            ? GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude)
            : null,
        'mapDefaultZoom': _selectedZoom,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('organizations')
          .doc(_organization!.id)
          .update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('設定を保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('保存エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_organization == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('組織設定'),
        ),
        body: const Center(
          child: Text('組織情報が見つかりません'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('組織設定'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: '保存',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 基本情報
            const Text(
              '基本情報',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '組織名',
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
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: '会社名（任意）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.apartment),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '電話番号（任意）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス（任意）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: '住所（任意）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // ユーザー制限
            const Text(
              'ユーザー管理',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxUsersController,
              decoration: InputDecoration(
                labelText: '最大ユーザー数',
                hintText: '空欄で無制限',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.people),
                suffixText: '人',
                helperText:
                    '現在のユーザー数: ${_organization!.activeUserCount}人',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final num = int.tryParse(value.trim());
                  if (num == null || num < 1) {
                    return '1以上の数値を入力してください';
                  }
                  if (num < _organization!.activeUserCount) {
                    return '現在のユーザー数(${_organization!.activeUserCount})より多い値を設定してください';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // 地図設定
            const Text(
              '地図の初期表示設定',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'オペレーターがリアルタイムマップを開いた時の初期表示位置を設定します',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // 地図検索
            TextField(
              controller: _mapSearchController,
              decoration: InputDecoration(
                labelText: '住所・建物名で検索',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _mapSearchController.clear(),
                ),
              ),
              onSubmitted: _searchLocation,
            ),
            const SizedBox(height: 16),

            // 地図表示
            Container(
              height: 400,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation ?? const LatLng(35.6812, 139.7671),
                    zoom: _selectedZoom,
                  ),
                  markers: _markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onTap: (position) {
                    setState(() {
                      _selectedLocation = position;
                      _updateMarker(position);
                    });
                  },
                  onCameraMove: (position) {
                    _selectedZoom = position.zoom;
                  },
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedLocation != null
                  ? '選択位置: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)} (ズーム: ${_selectedZoom.toStringAsFixed(1)})'
                  : '地図をタップして位置を選択してください',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // 保存ボタン
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? '保存中...' : '設定を保存'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
