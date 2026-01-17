import React, { useState, useEffect } from 'react';
import {
    View,
    Text,
    StyleSheet,
    SafeAreaView,
    ScrollView,
    ActivityIndicator,
    RefreshControl,
    TouchableOpacity,
} from 'react-native';
import { API_BASE_URL } from '../config/api';
import { authService } from '../services/authService';

interface DriverRegistry {
    id: number;
    full_name: string;
    full_name_kana: string;
    birth_date: string;
    hire_date: string;
    license_number: string;
    license_type: string;
    license_expiry_date: string;
    license_conditions: string | null;
    hazmat_license: boolean;
    hazmat_expiry_date: string | null;
    forklift_license: boolean;
    status: string;
}

interface HealthCheckup {
    id: number;
    checkup_type: string;
    checkup_date: string;
    next_checkup_date: string | null;
    overall_result: string;
    facility_name: string;
}

interface AptitudeTest {
    id: number;
    test_type: string;
    test_date: string;
    next_test_date: string | null;
    overall_score: number | null;
    facility_name: string;
}

interface TrainingRecord {
    id: number;
    training_type: string;
    training_name: string;
    training_date: string;
    duration_hours: number;
    completion_status: string;
}

export default function DriverProfileScreen() {
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [registry, setRegistry] = useState<DriverRegistry | null>(null);
    const [healthCheckups, setHealthCheckups] = useState<HealthCheckup[]>([]);
    const [aptitudeTests, setAptitudeTests] = useState<AptitudeTest[]>([]);
    const [trainings, setTrainings] = useState<TrainingRecord[]>([]);
    const [error, setError] = useState('');

    useEffect(() => {
        loadData();
    }, []);

    const loadData = async () => {
        try {
            setError('');
            const user = await authService.getUser();
            if (!user) return;

            const token = await authService.getToken();
            const headers = {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json',
            };

            // 運転者台帳取得
            const registryRes = await fetch(
                `${API_BASE_URL}/driver-registry/me`,
                { headers }
            );
            if (registryRes.ok) {
                const data = await registryRes.json();
                setRegistry(data);
            }

            // 健康診断履歴取得
            const healthRes = await fetch(
                `${API_BASE_URL}/health-checkups?driverId=${user.id}&limit=5`,
                { headers }
            );
            if (healthRes.ok) {
                const data = await healthRes.json();
                setHealthCheckups(data);
            }

            // 適性診断履歴取得
            const aptitudeRes = await fetch(
                `${API_BASE_URL}/aptitude-tests?driverId=${user.id}&limit=5`,
                { headers }
            );
            if (aptitudeRes.ok) {
                const data = await aptitudeRes.json();
                setAptitudeTests(data);
            }

            // 研修履歴取得
            const trainingRes = await fetch(
                `${API_BASE_URL}/training/driver/${user.id}`,
                { headers }
            );
            if (trainingRes.ok) {
                const data = await trainingRes.json();
                setTrainings(data.slice(0, 5));
            }
        } catch (err: any) {
            setError('データの取得に失敗しました');
            console.error('Error loading driver profile:', err);
        } finally {
            setLoading(false);
            setRefreshing(false);
        }
    };

    const onRefresh = () => {
        setRefreshing(true);
        loadData();
    };

    const formatDate = (dateStr: string | null) => {
        if (!dateStr) return '-';
        const date = new Date(dateStr);
        return `${date.getFullYear()}/${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getDate().toString().padStart(2, '0')}`;
    };

    const getDaysUntil = (dateStr: string | null) => {
        if (!dateStr) return null;
        const today = new Date();
        const target = new Date(dateStr);
        const diffTime = target.getTime() - today.getTime();
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        return diffDays;
    };

    const getExpiryStatus = (dateStr: string | null) => {
        const days = getDaysUntil(dateStr);
        if (days === null) return { color: '#999', text: '-' };
        if (days < 0) return { color: '#F44336', text: '期限切れ' };
        if (days <= 30) return { color: '#FF9800', text: `残り${days}日` };
        if (days <= 90) return { color: '#FFC107', text: `残り${days}日` };
        return { color: '#4CAF50', text: `残り${days}日` };
    };

    const getCheckupTypeName = (type: string) => {
        const types: Record<string, string> = {
            'regular': '定期健診',
            'special': '特殊健診',
            'pre_employment': '雇入時健診',
        };
        return types[type] || type;
    };

    const getAptitudeTypeName = (type: string) => {
        const types: Record<string, string> = {
            'initial': '初任診断',
            'age_based': '適齢診断',
            'specific': '特定診断',
            'voluntary': '一般診断',
        };
        return types[type] || type;
    };

    const getResultColor = (result: string) => {
        const colors: Record<string, string> = {
            'normal': '#4CAF50',
            'observation': '#FFC107',
            'treatment': '#FF9800',
            'work_restriction': '#F44336',
        };
        return colors[result] || '#666';
    };

    if (loading) {
        return (
            <SafeAreaView style={styles.container}>
                <View style={styles.loadingContainer}>
                    <ActivityIndicator size="large" color="#2196F3" />
                    <Text style={styles.loadingText}>読み込み中...</Text>
                </View>
            </SafeAreaView>
        );
    }

    return (
        <SafeAreaView style={styles.container}>
            <ScrollView
                contentContainerStyle={styles.content}
                refreshControl={
                    <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
                }
            >
                {error ? (
                    <View style={styles.errorContainer}>
                        <Text style={styles.errorText}>{error}</Text>
                        <TouchableOpacity style={styles.retryButton} onPress={loadData}>
                            <Text style={styles.retryText}>再試行</Text>
                        </TouchableOpacity>
                    </View>
                ) : null}

                {/* 基本情報 */}
                {registry && (
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>基本情報</Text>
                        <View style={styles.card}>
                            <View style={styles.row}>
                                <Text style={styles.label}>氏名</Text>
                                <Text style={styles.value}>{registry.full_name}</Text>
                            </View>
                            <View style={styles.row}>
                                <Text style={styles.label}>フリガナ</Text>
                                <Text style={styles.value}>{registry.full_name_kana || '-'}</Text>
                            </View>
                            <View style={styles.row}>
                                <Text style={styles.label}>入社日</Text>
                                <Text style={styles.value}>{formatDate(registry.hire_date)}</Text>
                            </View>
                            <View style={styles.row}>
                                <Text style={styles.label}>ステータス</Text>
                                <View style={[styles.statusBadge, { backgroundColor: registry.status === 'active' ? '#E8F5E9' : '#FFEBEE' }]}>
                                    <Text style={[styles.statusText, { color: registry.status === 'active' ? '#4CAF50' : '#F44336' }]}>
                                        {registry.status === 'active' ? '在籍中' : '退職'}
                                    </Text>
                                </View>
                            </View>
                        </View>
                    </View>
                )}

                {/* 免許情報 */}
                {registry && (
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>免許情報</Text>
                        <View style={styles.card}>
                            <View style={styles.row}>
                                <Text style={styles.label}>免許番号</Text>
                                <Text style={styles.value}>{registry.license_number}</Text>
                            </View>
                            <View style={styles.row}>
                                <Text style={styles.label}>免許種別</Text>
                                <Text style={styles.value}>{registry.license_type}</Text>
                            </View>
                            <View style={styles.row}>
                                <Text style={styles.label}>有効期限</Text>
                                <View style={styles.expiryContainer}>
                                    <Text style={styles.value}>{formatDate(registry.license_expiry_date)}</Text>
                                    <View style={[styles.expiryBadge, { backgroundColor: getExpiryStatus(registry.license_expiry_date).color }]}>
                                        <Text style={styles.expiryBadgeText}>
                                            {getExpiryStatus(registry.license_expiry_date).text}
                                        </Text>
                                    </View>
                                </View>
                            </View>
                            {registry.license_conditions && (
                                <View style={styles.row}>
                                    <Text style={styles.label}>条件</Text>
                                    <Text style={styles.value}>{registry.license_conditions}</Text>
                                </View>
                            )}
                            <View style={styles.divider} />
                            <View style={styles.row}>
                                <Text style={styles.label}>危険物取扱</Text>
                                <Text style={[styles.value, { color: registry.hazmat_license ? '#4CAF50' : '#999' }]}>
                                    {registry.hazmat_license ? '有り' : '無し'}
                                </Text>
                            </View>
                            <View style={styles.row}>
                                <Text style={styles.label}>フォークリフト</Text>
                                <Text style={[styles.value, { color: registry.forklift_license ? '#4CAF50' : '#999' }]}>
                                    {registry.forklift_license ? '有り' : '無し'}
                                </Text>
                            </View>
                        </View>
                    </View>
                )}

                {/* 健康診断履歴 */}
                <View style={styles.section}>
                    <Text style={styles.sectionTitle}>健康診断履歴</Text>
                    {healthCheckups.length > 0 ? (
                        healthCheckups.map((checkup) => (
                            <View key={checkup.id} style={styles.historyCard}>
                                <View style={styles.historyHeader}>
                                    <Text style={styles.historyType}>{getCheckupTypeName(checkup.checkup_type)}</Text>
                                    <Text style={styles.historyDate}>{formatDate(checkup.checkup_date)}</Text>
                                </View>
                                <View style={styles.historyBody}>
                                    <Text style={styles.historyFacility}>{checkup.facility_name}</Text>
                                    <View style={[styles.resultBadge, { backgroundColor: getResultColor(checkup.overall_result) + '20' }]}>
                                        <Text style={[styles.resultText, { color: getResultColor(checkup.overall_result) }]}>
                                            {checkup.overall_result === 'normal' ? '正常' :
                                             checkup.overall_result === 'observation' ? '経過観察' :
                                             checkup.overall_result === 'treatment' ? '要治療' : '就業制限'}
                                        </Text>
                                    </View>
                                </View>
                                {checkup.next_checkup_date && (
                                    <Text style={styles.nextDate}>次回: {formatDate(checkup.next_checkup_date)}</Text>
                                )}
                            </View>
                        ))
                    ) : (
                        <View style={styles.emptyCard}>
                            <Text style={styles.emptyText}>記録がありません</Text>
                        </View>
                    )}
                </View>

                {/* 適性診断履歴 */}
                <View style={styles.section}>
                    <Text style={styles.sectionTitle}>適性診断履歴</Text>
                    {aptitudeTests.length > 0 ? (
                        aptitudeTests.map((test) => (
                            <View key={test.id} style={styles.historyCard}>
                                <View style={styles.historyHeader}>
                                    <Text style={styles.historyType}>{getAptitudeTypeName(test.test_type)}</Text>
                                    <Text style={styles.historyDate}>{formatDate(test.test_date)}</Text>
                                </View>
                                <View style={styles.historyBody}>
                                    <Text style={styles.historyFacility}>{test.facility_name}</Text>
                                    {test.overall_score !== null && (
                                        <Text style={styles.scoreText}>スコア: {test.overall_score}点</Text>
                                    )}
                                </View>
                                {test.next_test_date && (
                                    <Text style={styles.nextDate}>次回: {formatDate(test.next_test_date)}</Text>
                                )}
                            </View>
                        ))
                    ) : (
                        <View style={styles.emptyCard}>
                            <Text style={styles.emptyText}>記録がありません</Text>
                        </View>
                    )}
                </View>

                {/* 研修履歴 */}
                <View style={styles.section}>
                    <Text style={styles.sectionTitle}>研修履歴</Text>
                    {trainings.length > 0 ? (
                        trainings.map((training) => (
                            <View key={training.id} style={styles.historyCard}>
                                <View style={styles.historyHeader}>
                                    <Text style={styles.historyType}>{training.training_name}</Text>
                                    <Text style={styles.historyDate}>{formatDate(training.training_date)}</Text>
                                </View>
                                <View style={styles.historyBody}>
                                    <Text style={styles.durationText}>{training.duration_hours}時間</Text>
                                    <View style={[styles.statusBadge, { backgroundColor: training.completion_status === 'completed' ? '#E8F5E9' : '#FFF3E0' }]}>
                                        <Text style={[styles.statusText, { color: training.completion_status === 'completed' ? '#4CAF50' : '#FF9800' }]}>
                                            {training.completion_status === 'completed' ? '修了' : '未完了'}
                                        </Text>
                                    </View>
                                </View>
                            </View>
                        ))
                    ) : (
                        <View style={styles.emptyCard}>
                            <Text style={styles.emptyText}>記録がありません</Text>
                        </View>
                    )}
                </View>
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
        padding: 16,
    },
    loadingContainer: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
    },
    loadingText: {
        marginTop: 12,
        color: '#666',
    },
    errorContainer: {
        backgroundColor: '#FFEBEE',
        padding: 16,
        borderRadius: 8,
        marginBottom: 16,
        alignItems: 'center',
    },
    errorText: {
        color: '#F44336',
        marginBottom: 8,
    },
    retryButton: {
        paddingHorizontal: 16,
        paddingVertical: 8,
        backgroundColor: '#F44336',
        borderRadius: 4,
    },
    retryText: {
        color: 'white',
        fontWeight: 'bold',
    },
    section: {
        marginBottom: 24,
    },
    sectionTitle: {
        fontSize: 18,
        fontWeight: 'bold',
        color: '#333',
        marginBottom: 12,
    },
    card: {
        backgroundColor: 'white',
        borderRadius: 12,
        padding: 16,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 1 },
        shadowOpacity: 0.05,
        shadowRadius: 4,
        elevation: 1,
    },
    row: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingVertical: 8,
    },
    label: {
        fontSize: 14,
        color: '#666',
    },
    value: {
        fontSize: 14,
        fontWeight: '600',
        color: '#333',
    },
    divider: {
        height: 1,
        backgroundColor: '#E0E0E0',
        marginVertical: 8,
    },
    statusBadge: {
        paddingHorizontal: 12,
        paddingVertical: 4,
        borderRadius: 12,
    },
    statusText: {
        fontSize: 12,
        fontWeight: '600',
    },
    expiryContainer: {
        flexDirection: 'row',
        alignItems: 'center',
    },
    expiryBadge: {
        marginLeft: 8,
        paddingHorizontal: 8,
        paddingVertical: 2,
        borderRadius: 4,
    },
    expiryBadgeText: {
        color: 'white',
        fontSize: 11,
        fontWeight: 'bold',
    },
    historyCard: {
        backgroundColor: 'white',
        borderRadius: 12,
        padding: 16,
        marginBottom: 8,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 1 },
        shadowOpacity: 0.05,
        shadowRadius: 4,
        elevation: 1,
    },
    historyHeader: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: 8,
    },
    historyType: {
        fontSize: 15,
        fontWeight: '600',
        color: '#333',
    },
    historyDate: {
        fontSize: 13,
        color: '#666',
    },
    historyBody: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
    },
    historyFacility: {
        fontSize: 13,
        color: '#666',
    },
    resultBadge: {
        paddingHorizontal: 10,
        paddingVertical: 4,
        borderRadius: 12,
    },
    resultText: {
        fontSize: 12,
        fontWeight: '600',
    },
    scoreText: {
        fontSize: 13,
        color: '#2196F3',
        fontWeight: '600',
    },
    durationText: {
        fontSize: 13,
        color: '#666',
    },
    nextDate: {
        marginTop: 8,
        fontSize: 12,
        color: '#999',
    },
    emptyCard: {
        backgroundColor: 'white',
        borderRadius: 12,
        padding: 24,
        alignItems: 'center',
    },
    emptyText: {
        color: '#999',
        fontSize: 14,
    },
});
