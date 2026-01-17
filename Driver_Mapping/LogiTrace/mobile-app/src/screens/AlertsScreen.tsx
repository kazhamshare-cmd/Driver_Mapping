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

interface Alert {
    id: string;
    type: 'license' | 'health_checkup' | 'aptitude_test' | 'training';
    title: string;
    message: string;
    expiry_date: string;
    days_remaining: number;
    urgency: 'warning' | 'critical' | 'expired';
}

interface ComplianceSummary {
    license_valid: boolean;
    health_checkup_valid: boolean;
    aptitude_test_valid: boolean;
    can_operate: boolean;
    alerts_count: number;
}

export default function AlertsScreen() {
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [alerts, setAlerts] = useState<Alert[]>([]);
    const [summary, setSummary] = useState<ComplianceSummary | null>(null);
    const [error, setError] = useState('');

    useEffect(() => {
        loadData();
    }, []);

    const loadData = async () => {
        try {
            setError('');
            const token = await authService.getToken();
            const user = await authService.getUser();
            if (!token || !user) return;

            const headers = {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json',
            };

            // アラート取得
            const alertsRes = await fetch(`${API_BASE_URL}/alerts`, { headers });
            if (alertsRes.ok) {
                const data = await alertsRes.json();
                setAlerts(data);
            }

            // コンプライアンスサマリー取得
            const summaryRes = await fetch(`${API_BASE_URL}/compliance/summary`, { headers });
            if (summaryRes.ok) {
                const data = await summaryRes.json();
                setSummary(data);
            }
        } catch (err: any) {
            setError('データの取得に失敗しました');
            console.error('Error loading alerts:', err);
        } finally {
            setLoading(false);
            setRefreshing(false);
        }
    };

    const onRefresh = () => {
        setRefreshing(true);
        loadData();
    };

    const formatDate = (dateStr: string) => {
        const date = new Date(dateStr);
        return `${date.getFullYear()}/${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getDate().toString().padStart(2, '0')}`;
    };

    const getAlertIcon = (type: string) => {
        switch (type) {
            case 'license': return '🪪';
            case 'health_checkup': return '🏥';
            case 'aptitude_test': return '📊';
            case 'training': return '📚';
            default: return '⚠️';
        }
    };

    const getAlertTypeName = (type: string) => {
        switch (type) {
            case 'license': return '免許';
            case 'health_checkup': return '健康診断';
            case 'aptitude_test': return '適性診断';
            case 'training': return '研修';
            default: return 'その他';
        }
    };

    const getUrgencyStyle = (urgency: string) => {
        switch (urgency) {
            case 'expired':
                return { bg: '#FFEBEE', border: '#F44336', text: '#F44336' };
            case 'critical':
                return { bg: '#FFF3E0', border: '#FF9800', text: '#FF9800' };
            case 'warning':
                return { bg: '#FFFDE7', border: '#FFC107', text: '#F57F17' };
            default:
                return { bg: '#E3F2FD', border: '#2196F3', text: '#2196F3' };
        }
    };

    const getUrgencyLabel = (urgency: string) => {
        switch (urgency) {
            case 'expired': return '期限切れ';
            case 'critical': return '緊急';
            case 'warning': return '注意';
            default: return '';
        }
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

                {/* 運行可否ステータス */}
                {summary && (
                    <View style={[
                        styles.statusCard,
                        { backgroundColor: summary.can_operate ? '#E8F5E9' : '#FFEBEE' }
                    ]}>
                        <View style={styles.statusHeader}>
                            <Text style={{ fontSize: 40 }}>
                                {summary.can_operate ? '✅' : '⛔'}
                            </Text>
                            <View style={styles.statusTextContainer}>
                                <Text style={[
                                    styles.statusTitle,
                                    { color: summary.can_operate ? '#2E7D32' : '#C62828' }
                                ]}>
                                    {summary.can_operate ? '運行可能' : '運行不可'}
                                </Text>
                                <Text style={styles.statusSubtitle}>
                                    {summary.can_operate
                                        ? 'すべての条件を満たしています'
                                        : '以下の項目を確認してください'}
                                </Text>
                            </View>
                        </View>
                        <View style={styles.statusChecklist}>
                            <View style={styles.checkItem}>
                                <Text style={{ fontSize: 18 }}>
                                    {summary.license_valid ? '✓' : '✗'}
                                </Text>
                                <Text style={[
                                    styles.checkText,
                                    { color: summary.license_valid ? '#4CAF50' : '#F44336' }
                                ]}>
                                    免許有効
                                </Text>
                            </View>
                            <View style={styles.checkItem}>
                                <Text style={{ fontSize: 18 }}>
                                    {summary.health_checkup_valid ? '✓' : '✗'}
                                </Text>
                                <Text style={[
                                    styles.checkText,
                                    { color: summary.health_checkup_valid ? '#4CAF50' : '#F44336' }
                                ]}>
                                    健康診断
                                </Text>
                            </View>
                            <View style={styles.checkItem}>
                                <Text style={{ fontSize: 18 }}>
                                    {summary.aptitude_test_valid ? '✓' : '✗'}
                                </Text>
                                <Text style={[
                                    styles.checkText,
                                    { color: summary.aptitude_test_valid ? '#4CAF50' : '#F44336' }
                                ]}>
                                    適性診断
                                </Text>
                            </View>
                        </View>
                    </View>
                )}

                {/* アラート一覧 */}
                <View style={styles.section}>
                    <View style={styles.sectionHeader}>
                        <Text style={styles.sectionTitle}>通知・アラート</Text>
                        {alerts.length > 0 && (
                            <View style={styles.alertBadge}>
                                <Text style={styles.alertBadgeText}>{alerts.length}</Text>
                            </View>
                        )}
                    </View>

                    {alerts.length > 0 ? (
                        alerts.map((alert, index) => {
                            const urgencyStyle = getUrgencyStyle(alert.urgency);
                            return (
                                <View
                                    key={alert.id || index}
                                    style={[
                                        styles.alertCard,
                                        {
                                            backgroundColor: urgencyStyle.bg,
                                            borderLeftColor: urgencyStyle.border,
                                        }
                                    ]}
                                >
                                    <View style={styles.alertHeader}>
                                        <View style={styles.alertTitleRow}>
                                            <Text style={{ fontSize: 24, marginRight: 8 }}>
                                                {getAlertIcon(alert.type)}
                                            </Text>
                                            <View>
                                                <Text style={styles.alertType}>
                                                    {getAlertTypeName(alert.type)}
                                                </Text>
                                                <Text style={[styles.alertTitle, { color: urgencyStyle.text }]}>
                                                    {alert.title}
                                                </Text>
                                            </View>
                                        </View>
                                        <View style={[styles.urgencyBadge, { backgroundColor: urgencyStyle.border }]}>
                                            <Text style={styles.urgencyText}>
                                                {getUrgencyLabel(alert.urgency)}
                                            </Text>
                                        </View>
                                    </View>
                                    <Text style={styles.alertMessage}>{alert.message}</Text>
                                    <View style={styles.alertFooter}>
                                        <Text style={styles.alertDate}>
                                            期限: {formatDate(alert.expiry_date)}
                                        </Text>
                                        <Text style={[styles.daysRemaining, { color: urgencyStyle.text }]}>
                                            {alert.days_remaining < 0
                                                ? `${Math.abs(alert.days_remaining)}日超過`
                                                : `残り${alert.days_remaining}日`}
                                        </Text>
                                    </View>
                                </View>
                            );
                        })
                    ) : (
                        <View style={styles.emptyCard}>
                            <Text style={{ fontSize: 48, marginBottom: 12 }}>🎉</Text>
                            <Text style={styles.emptyTitle}>アラートはありません</Text>
                            <Text style={styles.emptyText}>
                                すべての期限が正常です。
                            </Text>
                        </View>
                    )}
                </View>

                {/* 注意事項 */}
                <View style={styles.noteCard}>
                    <Text style={styles.noteTitle}>期限管理について</Text>
                    <Text style={styles.noteText}>
                        • 免許・健康診断・適性診断の期限が近づくと通知されます{'\n'}
                        • 期限切れの場合は運行ができなくなります{'\n'}
                        • 不明点は管理者にお問い合わせください
                    </Text>
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
    statusCard: {
        borderRadius: 16,
        padding: 20,
        marginBottom: 24,
    },
    statusHeader: {
        flexDirection: 'row',
        alignItems: 'center',
        marginBottom: 16,
    },
    statusTextContainer: {
        marginLeft: 16,
    },
    statusTitle: {
        fontSize: 24,
        fontWeight: 'bold',
    },
    statusSubtitle: {
        fontSize: 14,
        color: '#666',
        marginTop: 4,
    },
    statusChecklist: {
        flexDirection: 'row',
        justifyContent: 'space-around',
        paddingTop: 16,
        borderTopWidth: 1,
        borderTopColor: 'rgba(0,0,0,0.1)',
    },
    checkItem: {
        flexDirection: 'row',
        alignItems: 'center',
    },
    checkText: {
        marginLeft: 8,
        fontSize: 14,
        fontWeight: '600',
    },
    section: {
        marginBottom: 24,
    },
    sectionHeader: {
        flexDirection: 'row',
        alignItems: 'center',
        marginBottom: 12,
    },
    sectionTitle: {
        fontSize: 18,
        fontWeight: 'bold',
        color: '#333',
    },
    alertBadge: {
        marginLeft: 8,
        backgroundColor: '#F44336',
        borderRadius: 12,
        paddingHorizontal: 8,
        paddingVertical: 2,
    },
    alertBadgeText: {
        color: 'white',
        fontSize: 12,
        fontWeight: 'bold',
    },
    alertCard: {
        borderRadius: 12,
        padding: 16,
        marginBottom: 12,
        borderLeftWidth: 4,
    },
    alertHeader: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'flex-start',
        marginBottom: 8,
    },
    alertTitleRow: {
        flexDirection: 'row',
        alignItems: 'center',
        flex: 1,
    },
    alertType: {
        fontSize: 12,
        color: '#666',
    },
    alertTitle: {
        fontSize: 16,
        fontWeight: 'bold',
    },
    urgencyBadge: {
        paddingHorizontal: 10,
        paddingVertical: 4,
        borderRadius: 12,
    },
    urgencyText: {
        color: 'white',
        fontSize: 11,
        fontWeight: 'bold',
    },
    alertMessage: {
        fontSize: 14,
        color: '#666',
        marginBottom: 12,
    },
    alertFooter: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
    },
    alertDate: {
        fontSize: 13,
        color: '#666',
    },
    daysRemaining: {
        fontSize: 13,
        fontWeight: 'bold',
    },
    emptyCard: {
        backgroundColor: 'white',
        borderRadius: 16,
        padding: 32,
        alignItems: 'center',
    },
    emptyTitle: {
        fontSize: 18,
        fontWeight: 'bold',
        color: '#333',
        marginBottom: 8,
    },
    emptyText: {
        fontSize: 14,
        color: '#666',
        textAlign: 'center',
    },
    noteCard: {
        backgroundColor: '#E3F2FD',
        borderRadius: 12,
        padding: 16,
    },
    noteTitle: {
        fontSize: 14,
        fontWeight: 'bold',
        color: '#1976D2',
        marginBottom: 8,
    },
    noteText: {
        fontSize: 13,
        color: '#1976D2',
        lineHeight: 20,
    },
});
