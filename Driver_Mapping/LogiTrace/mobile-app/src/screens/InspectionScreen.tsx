import React, { useState, useEffect, useCallback } from 'react';
import {
    View,
    Text,
    TouchableOpacity,
    StyleSheet,
    SafeAreaView,
    ScrollView,
    TextInput,
    Alert,
    ActivityIndicator,
    Image,
    Modal,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import * as ImagePicker from 'expo-image-picker';
import { authService, User } from '../services/authService';
import { API_BASE_URL } from '../config/api';
import { useDriverAppSettings } from '../contexts/DriverAppSettingsContext';

interface InspectionItem {
    id: number;
    item_key: string;
    item_name_ja: string;
    category: string;
    is_required: boolean;
}

interface ItemResult {
    result: 'pass' | 'fail';
    photoUri?: string;
}

const CATEGORIES: Record<string, string> = {
    exterior: '外装',
    engine: 'エンジン',
    cabin: '車内',
    lights: '灯火類',
    safety: '安全装置',
};

// Default inspection items (used when API is not available)
const DEFAULT_ITEMS: InspectionItem[] = [
    { id: 1, item_key: 'tires', item_name_ja: 'タイヤ', category: 'exterior', is_required: true },
    { id: 2, item_key: 'tires_air_pressure', item_name_ja: 'タイヤ空気圧', category: 'exterior', is_required: true },
    { id: 3, item_key: 'brakes', item_name_ja: 'ブレーキ', category: 'safety', is_required: true },
    { id: 4, item_key: 'lights_headlights', item_name_ja: 'ヘッドライト', category: 'lights', is_required: true },
    { id: 5, item_key: 'lights_tail', item_name_ja: 'テールランプ', category: 'lights', is_required: true },
    { id: 6, item_key: 'lights_turn_signals', item_name_ja: 'ウインカー', category: 'lights', is_required: true },
    { id: 7, item_key: 'mirrors', item_name_ja: 'ミラー', category: 'exterior', is_required: true },
    { id: 8, item_key: 'wipers', item_name_ja: 'ワイパー', category: 'cabin', is_required: true },
    { id: 9, item_key: 'horn', item_name_ja: 'ホーン', category: 'safety', is_required: true },
    { id: 10, item_key: 'fuel', item_name_ja: '燃料', category: 'engine', is_required: true },
    { id: 11, item_key: 'engine_oil', item_name_ja: 'エンジンオイル', category: 'engine', is_required: true },
    { id: 12, item_key: 'cooling_water', item_name_ja: '冷却水', category: 'engine', is_required: true },
    { id: 13, item_key: 'battery', item_name_ja: 'バッテリー', category: 'engine', is_required: true },
    { id: 14, item_key: 'emergency_equipment', item_name_ja: '非常用機材', category: 'safety', is_required: true },
    { id: 15, item_key: 'fire_extinguisher', item_name_ja: '消火器', category: 'safety', is_required: true },
];

export default function InspectionScreen() {
    const navigation = useNavigation();
    const [user, setUser] = useState<User | null>(null);
    const [loading, setLoading] = useState(false);
    const [items, setItems] = useState<InspectionItem[]>(DEFAULT_ITEMS);
    const [itemResults, setItemResults] = useState<Record<string, ItemResult>>({});
    const [odometerReading, setOdometerReading] = useState('');
    const [issuesFound, setIssuesFound] = useState('');
    const [notes, setNotes] = useState('');

    // Photo preview modal
    const [photoPreviewVisible, setPhotoPreviewVisible] = useState(false);
    const [selectedPhotoUri, setSelectedPhotoUri] = useState<string | null>(null);
    const [selectedItemKey, setSelectedItemKey] = useState<string | null>(null);

    // Driver App Settings
    const { settings, isFeatureEnabled } = useDriverAppSettings();
    const showPhotoOption = isFeatureEnabled('inspectionPhotos') && settings.enableInspectionPhotos;

    useEffect(() => {
        loadUser();
        fetchInspectionItems();
    }, []);

    useEffect(() => {
        // Initialize all items as 'pass'
        const initialResults: Record<string, ItemResult> = {};
        items.forEach((item) => {
            initialResults[item.item_key] = { result: 'pass' };
        });
        setItemResults(initialResults);
    }, [items]);

    const loadUser = async () => {
        const userData = await authService.getUser();
        setUser(userData);
    };

    const fetchInspectionItems = async () => {
        try {
            const token = await authService.getToken();
            if (!token) return;

            const response = await fetch(`${API_BASE_URL}/inspections/items`, {
                headers: { 'Authorization': `Bearer ${token}` },
            });
            if (response.ok) {
                const data = await response.json();
                if (data.length > 0) {
                    setItems(data);
                }
            }
        } catch (error) {
            console.log('Using default inspection items');
        }
    };

    const handleItemToggle = (itemKey: string) => {
        setItemResults((prev) => ({
            ...prev,
            [itemKey]: {
                ...prev[itemKey],
                result: prev[itemKey]?.result === 'pass' ? 'fail' : 'pass',
            },
        }));
    };

    // Take photo for inspection item
    const takePhoto = useCallback(async (itemKey: string) => {
        const { status } = await ImagePicker.requestCameraPermissionsAsync();
        if (status !== 'granted') {
            Alert.alert('権限が必要です', 'カメラを使用するには権限の許可が必要です。');
            return;
        }

        const result = await ImagePicker.launchCameraAsync({
            mediaTypes: ImagePicker.MediaTypeOptions.Images,
            allowsEditing: false,
            quality: 0.7,
            aspect: [4, 3],
        });

        if (!result.canceled && result.assets[0]) {
            setItemResults((prev) => ({
                ...prev,
                [itemKey]: {
                    ...prev[itemKey],
                    photoUri: result.assets[0].uri,
                },
            }));
        }
    }, []);

    // View photo
    const viewPhoto = useCallback((itemKey: string, photoUri: string) => {
        setSelectedItemKey(itemKey);
        setSelectedPhotoUri(photoUri);
        setPhotoPreviewVisible(true);
    }, []);

    // Delete photo
    const deletePhoto = useCallback((itemKey: string) => {
        Alert.alert(
            '写真を削除',
            'この写真を削除しますか？',
            [
                { text: 'キャンセル', style: 'cancel' },
                {
                    text: '削除',
                    style: 'destructive',
                    onPress: () => {
                        setItemResults((prev) => ({
                            ...prev,
                            [itemKey]: {
                                ...prev[itemKey],
                                photoUri: undefined,
                            },
                        }));
                        setPhotoPreviewVisible(false);
                    },
                },
            ]
        );
    }, []);

    const failCount = Object.values(itemResults).filter((r) => r.result === 'fail').length;
    const passCount = Object.values(itemResults).filter((r) => r.result === 'pass').length;
    const photoCount = Object.values(itemResults).filter((r) => r.photoUri).length;

    // Check if photo is required for failed items
    const failedItemsWithoutPhoto = settings.requirePhotoOnFailure
        ? Object.entries(itemResults).filter(([_, r]) => r.result === 'fail' && !r.photoUri)
        : [];

    const handleSubmit = async () => {
        if (!user) return;

        if (failCount > 0 && !issuesFound.trim()) {
            Alert.alert(
                '入力エラー',
                '不合格項目がある場合は、発見した問題点を入力してください。',
                [{ text: 'OK' }]
            );
            return;
        }

        // Check photo requirement for failed items
        if (settings.requirePhotoOnFailure && failedItemsWithoutPhoto.length > 0) {
            Alert.alert(
                '写真が必要です',
                '不合格項目には写真の添付が必要です。',
                [{ text: 'OK' }]
            );
            return;
        }

        setLoading(true);
        try {
            const token = await authService.getToken();

            // Prepare form data for photo uploads
            const formData = new FormData();
            formData.append('company_id', String(user.companyId));
            formData.append('vehicle_id', '1'); // TODO: Get from vehicle selection
            formData.append('driver_id', String(user.id));
            formData.append('odometer_reading', odometerReading || '');
            formData.append('notes', notes || '');
            formData.append('issues_found', issuesFound || '');
            formData.append('follow_up_required', String(failCount > 0));

            // Add inspection items results
            const itemResultsForApi: Record<string, { result: string; has_photo: boolean }> = {};
            Object.entries(itemResults).forEach(([key, value]) => {
                itemResultsForApi[key] = {
                    result: value.result,
                    has_photo: !!value.photoUri,
                };
            });
            formData.append('inspection_items', JSON.stringify(itemResultsForApi));

            // Add photos
            let photoIndex = 0;
            Object.entries(itemResults).forEach(([key, value]) => {
                if (value.photoUri) {
                    const filename = `inspection_${key}_${Date.now()}.jpg`;
                    formData.append(`photo_${photoIndex}`, {
                        uri: value.photoUri,
                        type: 'image/jpeg',
                        name: filename,
                    } as any);
                    formData.append(`photo_${photoIndex}_item_key`, key);
                    photoIndex++;
                }
            });
            formData.append('photo_count', String(photoIndex));

            const response = await fetch(`${API_BASE_URL}/inspections`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'multipart/form-data',
                },
                body: formData,
            });

            if (!response.ok) {
                throw new Error('点検の登録に失敗しました');
            }

            Alert.alert('完了', '日常点検を記録しました', [
                {
                    text: 'OK',
                    onPress: () => (navigation as any).navigate('ModeSelection'),
                },
            ]);
        } catch (error: any) {
            Alert.alert('エラー', error.message);
        } finally {
            setLoading(false);
        }
    };

    // Group items by category
    const groupedItems = items.reduce((acc, item) => {
        if (!acc[item.category]) acc[item.category] = [];
        acc[item.category].push(item);
        return acc;
    }, {} as Record<string, InspectionItem[]>);

    return (
        <SafeAreaView style={styles.container}>
            <ScrollView contentContainerStyle={styles.content}>
                <View style={styles.header}>
                    <Text style={styles.headerTitle}>日常点検</Text>
                    <Text style={styles.headerSubtitle}>
                        乗務前に車両の点検を実施してください
                    </Text>
                </View>

                {/* Summary */}
                <View style={styles.summary}>
                    <View style={styles.summaryItem}>
                        <Text style={styles.summaryValue}>{passCount}</Text>
                        <Text style={[styles.summaryLabel, { color: '#4CAF50' }]}>合格</Text>
                    </View>
                    <View style={styles.summaryDivider} />
                    <View style={styles.summaryItem}>
                        <Text style={[styles.summaryValue, failCount > 0 && { color: '#F44336' }]}>
                            {failCount}
                        </Text>
                        <Text style={[styles.summaryLabel, failCount > 0 && { color: '#F44336' }]}>
                            不合格
                        </Text>
                    </View>
                    {showPhotoOption && (
                        <>
                            <View style={styles.summaryDivider} />
                            <View style={styles.summaryItem}>
                                <Text style={[styles.summaryValue, { color: '#2196F3' }]}>
                                    {photoCount}
                                </Text>
                                <Text style={[styles.summaryLabel, { color: '#2196F3' }]}>
                                    写真
                                </Text>
                            </View>
                        </>
                    )}
                </View>

                {/* Odometer */}
                <View style={styles.section}>
                    <Text style={styles.sectionTitle}>走行距離計</Text>
                    <View style={styles.odometerContainer}>
                        <TextInput
                            style={styles.odometerInput}
                            placeholder="123456"
                            value={odometerReading}
                            onChangeText={setOdometerReading}
                            keyboardType="number-pad"
                        />
                        <Text style={styles.odometerUnit}>km</Text>
                    </View>
                </View>

                {/* Inspection Items by Category */}
                {Object.entries(groupedItems).map(([category, categoryItems]) => (
                    <View key={category} style={styles.section}>
                        <Text style={styles.sectionTitle}>
                            {CATEGORIES[category] || category}
                        </Text>
                        {categoryItems.map((item) => {
                            const result = itemResults[item.item_key];
                            const isFail = result?.result === 'fail';
                            const hasPhoto = !!result?.photoUri;
                            const needsPhoto = settings.requirePhotoOnFailure && isFail && !hasPhoto;

                            return (
                                <View key={item.item_key} style={styles.inspectionItemContainer}>
                                    <TouchableOpacity
                                        style={styles.inspectionItem}
                                        onPress={() => handleItemToggle(item.item_key)}
                                    >
                                        <View style={styles.inspectionItemLeft}>
                                            <Text style={styles.inspectionItemName}>
                                                {item.item_name_ja}
                                                {item.is_required && (
                                                    <Text style={styles.requiredMark}> *</Text>
                                                )}
                                            </Text>
                                            {needsPhoto && (
                                                <Text style={styles.photoRequiredText}>
                                                    写真が必要です
                                                </Text>
                                            )}
                                        </View>
                                        <View
                                            style={[
                                                styles.inspectionItemStatus,
                                                isFail ? styles.statusFail : styles.statusPass,
                                            ]}
                                        >
                                            <Text
                                                style={[
                                                    styles.inspectionItemStatusText,
                                                    isFail ? { color: '#F44336' } : { color: '#4CAF50' },
                                                ]}
                                            >
                                                {isFail ? '×' : '○'}
                                            </Text>
                                        </View>
                                    </TouchableOpacity>

                                    {/* Photo Options (when enabled) */}
                                    {showPhotoOption && (
                                        <View style={styles.photoActions}>
                                            {hasPhoto ? (
                                                <TouchableOpacity
                                                    style={styles.photoPreviewButton}
                                                    onPress={() => viewPhoto(item.item_key, result.photoUri!)}
                                                >
                                                    <Image
                                                        source={{ uri: result.photoUri }}
                                                        style={styles.photoThumbnail}
                                                    />
                                                    <Text style={styles.photoPreviewText}>写真を確認</Text>
                                                </TouchableOpacity>
                                            ) : (
                                                <TouchableOpacity
                                                    style={[
                                                        styles.addPhotoButton,
                                                        needsPhoto && styles.addPhotoButtonRequired,
                                                    ]}
                                                    onPress={() => takePhoto(item.item_key)}
                                                >
                                                    <Text style={styles.addPhotoButtonText}>
                                                        📷 写真を追加
                                                    </Text>
                                                </TouchableOpacity>
                                            )}
                                        </View>
                                    )}
                                </View>
                            );
                        })}
                    </View>
                ))}

                {/* Issues Found */}
                {failCount > 0 && (
                    <View style={styles.section}>
                        <Text style={[styles.sectionTitle, { color: '#F44336' }]}>
                            発見した問題点 *
                        </Text>
                        <TextInput
                            style={[styles.textInput, { minHeight: 100 }]}
                            placeholder="不合格項目の詳細を入力してください"
                            value={issuesFound}
                            onChangeText={setIssuesFound}
                            multiline
                        />
                    </View>
                )}

                {/* Notes */}
                <View style={styles.section}>
                    <Text style={styles.sectionTitle}>備考</Text>
                    <TextInput
                        style={[styles.textInput, { minHeight: 80 }]}
                        placeholder="特記事項があれば入力してください"
                        value={notes}
                        onChangeText={setNotes}
                        multiline
                    />
                </View>

                {/* Submit Button */}
                <TouchableOpacity
                    style={[
                        styles.submitButton,
                        failCount > 0 && styles.submitButtonWarning,
                        (settings.requirePhotoOnFailure && failedItemsWithoutPhoto.length > 0) && styles.submitButtonDisabled,
                    ]}
                    onPress={handleSubmit}
                    disabled={loading || (settings.requirePhotoOnFailure && failedItemsWithoutPhoto.length > 0)}
                >
                    {loading ? (
                        <ActivityIndicator color="white" />
                    ) : (
                        <Text style={styles.submitButtonText}>
                            {failCount > 0 ? '条件付きで記録する' : '点検を記録する'}
                        </Text>
                    )}
                </TouchableOpacity>

                <Text style={styles.footerNote}>
                    ※ タップで合格/不合格を切り替えられます
                    {showPhotoOption && '\n※ 写真を追加して証跡を残すことができます'}
                </Text>
            </ScrollView>

            {/* Photo Preview Modal */}
            <Modal
                visible={photoPreviewVisible}
                animationType="fade"
                transparent={true}
                onRequestClose={() => setPhotoPreviewVisible(false)}
            >
                <View style={styles.modalOverlay}>
                    <View style={styles.photoModalContent}>
                        <View style={styles.modalHeader}>
                            <Text style={styles.modalTitle}>写真プレビュー</Text>
                            <TouchableOpacity onPress={() => setPhotoPreviewVisible(false)}>
                                <Text style={styles.modalCloseText}>×</Text>
                            </TouchableOpacity>
                        </View>
                        {selectedPhotoUri && (
                            <Image
                                source={{ uri: selectedPhotoUri }}
                                style={styles.photoPreviewImage}
                                resizeMode="contain"
                            />
                        )}
                        <View style={styles.photoModalActions}>
                            <TouchableOpacity
                                style={styles.retakeButton}
                                onPress={() => {
                                    setPhotoPreviewVisible(false);
                                    if (selectedItemKey) takePhoto(selectedItemKey);
                                }}
                            >
                                <Text style={styles.retakeButtonText}>撮り直す</Text>
                            </TouchableOpacity>
                            <TouchableOpacity
                                style={styles.deletePhotoButton}
                                onPress={() => selectedItemKey && deletePhoto(selectedItemKey)}
                            >
                                <Text style={styles.deletePhotoButtonText}>削除</Text>
                            </TouchableOpacity>
                        </View>
                    </View>
                </View>
            </Modal>
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#F5F7FA',
    },
    content: {
        padding: 20,
    },
    header: {
        marginBottom: 16,
    },
    headerTitle: {
        fontSize: 24,
        fontWeight: 'bold',
        color: '#333',
        marginBottom: 8,
    },
    headerSubtitle: {
        fontSize: 14,
        color: '#666',
    },
    summary: {
        flexDirection: 'row',
        backgroundColor: 'white',
        borderRadius: 12,
        padding: 16,
        marginBottom: 16,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 1 },
        shadowOpacity: 0.05,
        shadowRadius: 4,
        elevation: 1,
    },
    summaryItem: {
        flex: 1,
        alignItems: 'center',
    },
    summaryValue: {
        fontSize: 32,
        fontWeight: 'bold',
        color: '#333',
    },
    summaryLabel: {
        fontSize: 14,
        color: '#666',
        marginTop: 4,
    },
    summaryDivider: {
        width: 1,
        backgroundColor: '#E0E0E0',
        marginHorizontal: 16,
    },
    section: {
        backgroundColor: 'white',
        borderRadius: 12,
        padding: 16,
        marginBottom: 16,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 1 },
        shadowOpacity: 0.05,
        shadowRadius: 4,
        elevation: 1,
    },
    sectionTitle: {
        fontSize: 16,
        fontWeight: '600',
        color: '#333',
        marginBottom: 12,
    },
    odometerContainer: {
        flexDirection: 'row',
        alignItems: 'center',
    },
    odometerInput: {
        flex: 1,
        borderWidth: 2,
        borderColor: '#E0E0E0',
        borderRadius: 8,
        padding: 12,
        fontSize: 20,
        fontWeight: 'bold',
        textAlign: 'center',
    },
    odometerUnit: {
        fontSize: 18,
        color: '#666',
        marginLeft: 12,
    },
    inspectionItemContainer: {
        borderBottomWidth: 1,
        borderBottomColor: '#F0F0F0',
        paddingBottom: 8,
        marginBottom: 8,
    },
    inspectionItem: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingVertical: 8,
    },
    inspectionItemLeft: {
        flex: 1,
    },
    inspectionItemName: {
        fontSize: 16,
        color: '#333',
    },
    requiredMark: {
        color: '#F44336',
    },
    photoRequiredText: {
        fontSize: 12,
        color: '#F44336',
        marginTop: 4,
    },
    inspectionItemStatus: {
        width: 44,
        height: 44,
        borderRadius: 22,
        alignItems: 'center',
        justifyContent: 'center',
    },
    statusPass: {
        backgroundColor: '#E8F5E9',
    },
    statusFail: {
        backgroundColor: '#FFEBEE',
    },
    inspectionItemStatusText: {
        fontSize: 24,
        fontWeight: 'bold',
    },
    photoActions: {
        marginTop: 8,
    },
    addPhotoButton: {
        backgroundColor: '#E3F2FD',
        borderRadius: 8,
        paddingVertical: 8,
        paddingHorizontal: 12,
        alignSelf: 'flex-start',
    },
    addPhotoButtonRequired: {
        backgroundColor: '#FFEBEE',
        borderWidth: 1,
        borderColor: '#F44336',
    },
    addPhotoButtonText: {
        fontSize: 14,
        color: '#2196F3',
    },
    photoPreviewButton: {
        flexDirection: 'row',
        alignItems: 'center',
        backgroundColor: '#F5F5F5',
        borderRadius: 8,
        padding: 8,
        alignSelf: 'flex-start',
    },
    photoThumbnail: {
        width: 40,
        height: 40,
        borderRadius: 4,
        marginRight: 8,
    },
    photoPreviewText: {
        fontSize: 14,
        color: '#666',
    },
    textInput: {
        borderWidth: 1,
        borderColor: '#E0E0E0',
        borderRadius: 8,
        padding: 12,
        fontSize: 16,
        minHeight: 44,
    },
    submitButton: {
        backgroundColor: '#4CAF50',
        borderRadius: 12,
        padding: 16,
        alignItems: 'center',
        marginTop: 8,
    },
    submitButtonWarning: {
        backgroundColor: '#FF9800',
    },
    submitButtonDisabled: {
        backgroundColor: '#BDBDBD',
    },
    submitButtonText: {
        color: 'white',
        fontSize: 18,
        fontWeight: 'bold',
    },
    footerNote: {
        textAlign: 'center',
        color: '#999',
        fontSize: 12,
        marginTop: 16,
        lineHeight: 18,
    },
    // Modal styles
    modalOverlay: {
        flex: 1,
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        justifyContent: 'center',
        alignItems: 'center',
    },
    photoModalContent: {
        backgroundColor: '#FFF',
        borderRadius: 12,
        width: '90%',
        maxHeight: '80%',
    },
    modalHeader: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: 16,
        borderBottomWidth: 1,
        borderBottomColor: '#E0E0E0',
    },
    modalTitle: {
        fontSize: 18,
        fontWeight: '600',
        color: '#333',
    },
    modalCloseText: {
        fontSize: 28,
        color: '#666',
        lineHeight: 28,
    },
    photoPreviewImage: {
        width: '100%',
        height: 300,
        backgroundColor: '#F5F5F5',
    },
    photoModalActions: {
        flexDirection: 'row',
        justifyContent: 'space-around',
        padding: 16,
        gap: 12,
    },
    retakeButton: {
        flex: 1,
        backgroundColor: '#E0E0E0',
        borderRadius: 8,
        padding: 12,
        alignItems: 'center',
    },
    retakeButtonText: {
        fontSize: 16,
        fontWeight: '600',
        color: '#666',
    },
    deletePhotoButton: {
        flex: 1,
        backgroundColor: '#FFEBEE',
        borderRadius: 8,
        padding: 12,
        alignItems: 'center',
    },
    deletePhotoButtonText: {
        fontSize: 16,
        fontWeight: '600',
        color: '#F44336',
    },
});
