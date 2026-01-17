import React, { useState, useEffect } from 'react';
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
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { authService, User } from '../services/authService';
import { API_BASE_URL } from '../config/api';

interface InspectionItem {
    id: number;
    item_key: string;
    item_name_ja: string;
    category: string;
    is_required: boolean;
}

interface ItemResult {
    result: 'pass' | 'fail';
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
                result: prev[itemKey]?.result === 'pass' ? 'fail' : 'pass',
            },
        }));
    };

    const failCount = Object.values(itemResults).filter((r) => r.result === 'fail').length;
    const passCount = Object.values(itemResults).filter((r) => r.result === 'pass').length;

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

        setLoading(true);
        try {
            const token = await authService.getToken();
            const response = await fetch(`${API_BASE_URL}/inspections`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`,
                },
                body: JSON.stringify({
                    company_id: user.companyId,
                    vehicle_id: 1, // TODO: Get from vehicle selection
                    driver_id: user.id,
                    inspection_items: itemResults,
                    odometer_reading: odometerReading ? parseInt(odometerReading) : null,
                    notes: notes || null,
                    issues_found: issuesFound || null,
                    follow_up_required: failCount > 0,
                }),
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
                        {categoryItems.map((item) => (
                            <TouchableOpacity
                                key={item.item_key}
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
                                </View>
                                <View
                                    style={[
                                        styles.inspectionItemStatus,
                                        itemResults[item.item_key]?.result === 'pass'
                                            ? styles.statusPass
                                            : styles.statusFail,
                                    ]}
                                >
                                    <Text
                                        style={[
                                            styles.inspectionItemStatusText,
                                            itemResults[item.item_key]?.result === 'pass'
                                                ? { color: '#4CAF50' }
                                                : { color: '#F44336' },
                                        ]}
                                    >
                                        {itemResults[item.item_key]?.result === 'pass' ? '○' : '×'}
                                    </Text>
                                </View>
                            </TouchableOpacity>
                        ))}
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
                    ]}
                    onPress={handleSubmit}
                    disabled={loading}
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
                </Text>
            </ScrollView>
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
    inspectionItem: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingVertical: 12,
        borderBottomWidth: 1,
        borderBottomColor: '#F0F0F0',
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
    },
});
