import React, { useState, useEffect, useCallback } from 'react';
import {
    View,
    Text,
    TouchableOpacity,
    StyleSheet,
    SafeAreaView,
    ScrollView,
    ActivityIndicator,
    RefreshControl,
    Alert
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { authService } from '../services/authService';

interface OperationInstruction {
    id: number;
    instruction_number: string;
    instruction_date: string;
    route_name: string;
    departure_location: string;
    arrival_location: string;
    via_points: Array<{ name: string; scheduled_time: string }>;
    scheduled_departure_time: string;
    scheduled_arrival_time: string;
    primary_driver_name: string;
    secondary_driver_name: string | null;
    vehicle_number: string;
    expected_passengers: number;
    group_name: string | null;
    contact_person: string | null;
    contact_phone: string | null;
    planned_breaks: Array<{ location: string; scheduled_time: string; duration_minutes: number }>;
    special_instructions: string | null;
    status: 'draft' | 'issued' | 'in_progress' | 'completed' | 'cancelled';
}

const STATUS_LABELS: Record<string, { label: string; color: string }> = {
    draft: { label: '下書き', color: '#9E9E9E' },
    issued: { label: '発行済', color: '#2196F3' },
    in_progress: { label: '運行中', color: '#4CAF50' },
    completed: { label: '完了', color: '#607D8B' },
    cancelled: { label: '中止', color: '#F44336' }
};

export default function OperationInstructionScreen({ navigation }: any) {
    const [instructions, setInstructions] = useState<OperationInstruction[]>([]);
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [selectedInstruction, setSelectedInstruction] = useState<OperationInstruction | null>(null);

    const fetchInstructions = useCallback(async () => {
        try {
            const user = await authService.getUser();
            if (!user?.id) return;

            const today = new Date().toISOString().split('T')[0];
            const response = await authService.authenticatedFetch(
                `/operation-instructions/driver/${user.id}?date=${today}`
            );

            if (response.ok) {
                const data = await response.json();
                setInstructions(data);
            }
        } catch (error) {
            console.error('Error fetching instructions:', error);
        } finally {
            setLoading(false);
            setRefreshing(false);
        }
    }, []);

    useEffect(() => {
        fetchInstructions();
    }, [fetchInstructions]);

    const onRefresh = useCallback(() => {
        setRefreshing(true);
        fetchInstructions();
    }, [fetchInstructions]);

    const handleStartOperation = async (instruction: OperationInstruction) => {
        Alert.alert(
            '運行開始確認',
            `${instruction.route_name || instruction.instruction_number}の運行を開始しますか？`,
            [
                { text: 'キャンセル', style: 'cancel' },
                {
                    text: '開始',
                    onPress: async () => {
                        try {
                            const response = await authService.authenticatedFetch(
                                `/operation-instructions/${instruction.id}/status`,
                                {
                                    method: 'PUT',
                                    body: JSON.stringify({ status: 'in_progress' })
                                }
                            );

                            if (response.ok) {
                                Alert.alert('成功', '運行を開始しました');
                                fetchInstructions();
                            } else {
                                throw new Error('Failed to update status');
                            }
                        } catch (error) {
                            console.error('Error starting operation:', error);
                            Alert.alert('エラー', '運行開始に失敗しました');
                        }
                    }
                }
            ]
        );
    };

    const handleCompleteOperation = async (instruction: OperationInstruction) => {
        Alert.alert(
            '運行完了確認',
            `${instruction.route_name || instruction.instruction_number}の運行を完了しますか？`,
            [
                { text: 'キャンセル', style: 'cancel' },
                {
                    text: '完了',
                    onPress: async () => {
                        try {
                            const response = await authService.authenticatedFetch(
                                `/operation-instructions/${instruction.id}/status`,
                                {
                                    method: 'PUT',
                                    body: JSON.stringify({
                                        status: 'completed',
                                        actual_arrival_time: new Date().toTimeString().slice(0, 5)
                                    })
                                }
                            );

                            if (response.ok) {
                                Alert.alert('成功', '運行を完了しました');
                                fetchInstructions();
                            } else {
                                throw new Error('Failed to update status');
                            }
                        } catch (error) {
                            console.error('Error completing operation:', error);
                            Alert.alert('エラー', '運行完了に失敗しました');
                        }
                    }
                }
            ]
        );
    };

    const formatTime = (time: string): string => {
        if (!time) return '-';
        return time.slice(0, 5);
    };

    const formatDate = (dateString: string): string => {
        const date = new Date(dateString);
        return `${date.getMonth() + 1}/${date.getDate()}`;
    };

    const renderInstructionCard = (instruction: OperationInstruction) => {
        const statusInfo = STATUS_LABELS[instruction.status] || STATUS_LABELS.draft;

        return (
            <TouchableOpacity
                key={instruction.id}
                style={styles.card}
                onPress={() => setSelectedInstruction(instruction)}
            >
                <View style={styles.cardHeader}>
                    <View style={styles.instructionNumber}>
                        <Text style={styles.instructionNumberText}>
                            {instruction.instruction_number}
                        </Text>
                    </View>
                    <View style={[styles.statusBadge, { backgroundColor: statusInfo.color }]}>
                        <Text style={styles.statusText}>{statusInfo.label}</Text>
                    </View>
                </View>

                <Text style={styles.routeName}>
                    {instruction.route_name || `${instruction.departure_location} → ${instruction.arrival_location}`}
                </Text>

                <View style={styles.timeRow}>
                    <View style={styles.timeItem}>
                        <Ionicons name="time-outline" size={16} color="#666" />
                        <Text style={styles.timeText}>
                            {formatTime(instruction.scheduled_departure_time)} - {formatTime(instruction.scheduled_arrival_time)}
                        </Text>
                    </View>
                    {instruction.expected_passengers && (
                        <View style={styles.timeItem}>
                            <Ionicons name="people-outline" size={16} color="#666" />
                            <Text style={styles.timeText}>{instruction.expected_passengers}名</Text>
                        </View>
                    )}
                </View>

                <View style={styles.locationRow}>
                    <Ionicons name="location-outline" size={16} color="#4CAF50" />
                    <Text style={styles.locationText} numberOfLines={1}>
                        {instruction.departure_location}
                    </Text>
                </View>
                <View style={styles.locationRow}>
                    <Ionicons name="flag-outline" size={16} color="#F44336" />
                    <Text style={styles.locationText} numberOfLines={1}>
                        {instruction.arrival_location}
                    </Text>
                </View>

                {instruction.status === 'issued' && (
                    <TouchableOpacity
                        style={styles.startButton}
                        onPress={() => handleStartOperation(instruction)}
                    >
                        <Ionicons name="play" size={18} color="#FFF" />
                        <Text style={styles.startButtonText}>運行開始</Text>
                    </TouchableOpacity>
                )}

                {instruction.status === 'in_progress' && (
                    <TouchableOpacity
                        style={[styles.startButton, { backgroundColor: '#4CAF50' }]}
                        onPress={() => handleCompleteOperation(instruction)}
                    >
                        <Ionicons name="checkmark" size={18} color="#FFF" />
                        <Text style={styles.startButtonText}>運行完了</Text>
                    </TouchableOpacity>
                )}
            </TouchableOpacity>
        );
    };

    const renderDetailModal = () => {
        if (!selectedInstruction) return null;
        const statusInfo = STATUS_LABELS[selectedInstruction.status] || STATUS_LABELS.draft;

        return (
            <View style={styles.modalOverlay}>
                <View style={styles.modalContent}>
                    <View style={styles.modalHeader}>
                        <Text style={styles.modalTitle}>運行指示書詳細</Text>
                        <TouchableOpacity onPress={() => setSelectedInstruction(null)}>
                            <Ionicons name="close" size={24} color="#333" />
                        </TouchableOpacity>
                    </View>

                    <ScrollView style={styles.modalBody}>
                        <View style={styles.detailSection}>
                            <View style={styles.detailRow}>
                                <Text style={styles.detailLabel}>指示書番号</Text>
                                <Text style={styles.detailValue}>{selectedInstruction.instruction_number}</Text>
                            </View>
                            <View style={styles.detailRow}>
                                <Text style={styles.detailLabel}>ステータス</Text>
                                <View style={[styles.statusBadge, { backgroundColor: statusInfo.color }]}>
                                    <Text style={styles.statusText}>{statusInfo.label}</Text>
                                </View>
                            </View>
                        </View>

                        <View style={styles.detailSection}>
                            <Text style={styles.sectionTitle}>運行情報</Text>
                            <View style={styles.detailRow}>
                                <Text style={styles.detailLabel}>出発地</Text>
                                <Text style={styles.detailValue}>{selectedInstruction.departure_location}</Text>
                            </View>
                            <View style={styles.detailRow}>
                                <Text style={styles.detailLabel}>到着地</Text>
                                <Text style={styles.detailValue}>{selectedInstruction.arrival_location}</Text>
                            </View>
                            {selectedInstruction.via_points && selectedInstruction.via_points.length > 0 && (
                                <View style={styles.detailRow}>
                                    <Text style={styles.detailLabel}>経由地</Text>
                                    <View>
                                        {selectedInstruction.via_points.map((point, index) => (
                                            <Text key={index} style={styles.detailValue}>
                                                {point.name} ({point.scheduled_time})
                                            </Text>
                                        ))}
                                    </View>
                                </View>
                            )}
                            <View style={styles.detailRow}>
                                <Text style={styles.detailLabel}>予定時刻</Text>
                                <Text style={styles.detailValue}>
                                    {formatTime(selectedInstruction.scheduled_departure_time)} - {formatTime(selectedInstruction.scheduled_arrival_time)}
                                </Text>
                            </View>
                        </View>

                        <View style={styles.detailSection}>
                            <Text style={styles.sectionTitle}>配車情報</Text>
                            <View style={styles.detailRow}>
                                <Text style={styles.detailLabel}>車両</Text>
                                <Text style={styles.detailValue}>{selectedInstruction.vehicle_number || '-'}</Text>
                            </View>
                            <View style={styles.detailRow}>
                                <Text style={styles.detailLabel}>運転者</Text>
                                <Text style={styles.detailValue}>{selectedInstruction.primary_driver_name}</Text>
                            </View>
                            {selectedInstruction.secondary_driver_name && (
                                <View style={styles.detailRow}>
                                    <Text style={styles.detailLabel}>交替運転者</Text>
                                    <Text style={styles.detailValue}>{selectedInstruction.secondary_driver_name}</Text>
                                </View>
                            )}
                            {selectedInstruction.expected_passengers && (
                                <View style={styles.detailRow}>
                                    <Text style={styles.detailLabel}>予定乗客数</Text>
                                    <Text style={styles.detailValue}>{selectedInstruction.expected_passengers}名</Text>
                                </View>
                            )}
                        </View>

                        {(selectedInstruction.group_name || selectedInstruction.contact_person) && (
                            <View style={styles.detailSection}>
                                <Text style={styles.sectionTitle}>顧客情報</Text>
                                {selectedInstruction.group_name && (
                                    <View style={styles.detailRow}>
                                        <Text style={styles.detailLabel}>団体名</Text>
                                        <Text style={styles.detailValue}>{selectedInstruction.group_name}</Text>
                                    </View>
                                )}
                                {selectedInstruction.contact_person && (
                                    <View style={styles.detailRow}>
                                        <Text style={styles.detailLabel}>担当者</Text>
                                        <Text style={styles.detailValue}>{selectedInstruction.contact_person}</Text>
                                    </View>
                                )}
                                {selectedInstruction.contact_phone && (
                                    <View style={styles.detailRow}>
                                        <Text style={styles.detailLabel}>連絡先</Text>
                                        <Text style={styles.detailValue}>{selectedInstruction.contact_phone}</Text>
                                    </View>
                                )}
                            </View>
                        )}

                        {selectedInstruction.planned_breaks && selectedInstruction.planned_breaks.length > 0 && (
                            <View style={styles.detailSection}>
                                <Text style={styles.sectionTitle}>休憩計画</Text>
                                {selectedInstruction.planned_breaks.map((breakItem, index) => (
                                    <View key={index} style={styles.breakItem}>
                                        <Text style={styles.breakTime}>
                                            {breakItem.scheduled_time} ({breakItem.duration_minutes}分)
                                        </Text>
                                        <Text style={styles.breakLocation}>{breakItem.location}</Text>
                                    </View>
                                ))}
                            </View>
                        )}

                        {selectedInstruction.special_instructions && (
                            <View style={styles.detailSection}>
                                <Text style={styles.sectionTitle}>特記事項</Text>
                                <Text style={styles.specialInstructions}>
                                    {selectedInstruction.special_instructions}
                                </Text>
                            </View>
                        )}
                    </ScrollView>

                    <View style={styles.modalFooter}>
                        <TouchableOpacity
                            style={styles.closeButton}
                            onPress={() => setSelectedInstruction(null)}
                        >
                            <Text style={styles.closeButtonText}>閉じる</Text>
                        </TouchableOpacity>
                    </View>
                </View>
            </View>
        );
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
            <View style={styles.header}>
                <TouchableOpacity onPress={() => navigation.goBack()}>
                    <Ionicons name="arrow-back" size={24} color="#333" />
                </TouchableOpacity>
                <Text style={styles.headerTitle}>運行指示書</Text>
                <TouchableOpacity onPress={onRefresh}>
                    <Ionicons name="refresh" size={24} color="#333" />
                </TouchableOpacity>
            </View>

            <ScrollView
                style={styles.content}
                refreshControl={
                    <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
                }
            >
                {instructions.length === 0 ? (
                    <View style={styles.emptyState}>
                        <Ionicons name="document-text-outline" size={64} color="#CCC" />
                        <Text style={styles.emptyTitle}>本日の運行指示書はありません</Text>
                        <Text style={styles.emptySubtitle}>新しい指示書が発行されると表示されます</Text>
                    </View>
                ) : (
                    instructions.map(renderInstructionCard)
                )}
            </ScrollView>

            {selectedInstruction && renderDetailModal()}
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#F5F7FA',
    },
    loadingContainer: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
    },
    loadingText: {
        marginTop: 12,
        fontSize: 16,
        color: '#666',
    },
    header: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: 16,
        backgroundColor: '#FFF',
        borderBottomWidth: 1,
        borderBottomColor: '#E0E0E0',
    },
    headerTitle: {
        fontSize: 18,
        fontWeight: '600',
        color: '#333',
    },
    content: {
        flex: 1,
        padding: 16,
    },
    emptyState: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
        paddingTop: 100,
    },
    emptyTitle: {
        fontSize: 18,
        fontWeight: '600',
        color: '#666',
        marginTop: 16,
    },
    emptySubtitle: {
        fontSize: 14,
        color: '#999',
        marginTop: 8,
    },
    card: {
        backgroundColor: '#FFF',
        borderRadius: 12,
        padding: 16,
        marginBottom: 12,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 4,
        elevation: 3,
    },
    cardHeader: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: 12,
    },
    instructionNumber: {
        backgroundColor: '#F5F5F5',
        paddingHorizontal: 8,
        paddingVertical: 4,
        borderRadius: 4,
    },
    instructionNumberText: {
        fontSize: 12,
        fontWeight: '600',
        color: '#666',
    },
    statusBadge: {
        paddingHorizontal: 10,
        paddingVertical: 4,
        borderRadius: 12,
    },
    statusText: {
        fontSize: 12,
        fontWeight: '600',
        color: '#FFF',
    },
    routeName: {
        fontSize: 16,
        fontWeight: '600',
        color: '#333',
        marginBottom: 8,
    },
    timeRow: {
        flexDirection: 'row',
        gap: 16,
        marginBottom: 12,
    },
    timeItem: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 4,
    },
    timeText: {
        fontSize: 14,
        color: '#666',
    },
    locationRow: {
        flexDirection: 'row',
        alignItems: 'center',
        gap: 8,
        marginBottom: 4,
    },
    locationText: {
        fontSize: 14,
        color: '#333',
        flex: 1,
    },
    startButton: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: '#2196F3',
        borderRadius: 8,
        padding: 12,
        marginTop: 12,
        gap: 8,
    },
    startButtonText: {
        color: '#FFF',
        fontSize: 14,
        fontWeight: '600',
    },
    // Modal styles
    modalOverlay: {
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        justifyContent: 'flex-end',
    },
    modalContent: {
        backgroundColor: '#FFF',
        borderTopLeftRadius: 20,
        borderTopRightRadius: 20,
        maxHeight: '90%',
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
    modalBody: {
        padding: 16,
    },
    modalFooter: {
        padding: 16,
        borderTopWidth: 1,
        borderTopColor: '#E0E0E0',
    },
    closeButton: {
        backgroundColor: '#F5F5F5',
        borderRadius: 8,
        padding: 14,
        alignItems: 'center',
    },
    closeButtonText: {
        fontSize: 16,
        fontWeight: '500',
        color: '#666',
    },
    detailSection: {
        marginBottom: 20,
    },
    sectionTitle: {
        fontSize: 14,
        fontWeight: '600',
        color: '#666',
        marginBottom: 12,
        paddingBottom: 8,
        borderBottomWidth: 1,
        borderBottomColor: '#E0E0E0',
    },
    detailRow: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'flex-start',
        marginBottom: 8,
    },
    detailLabel: {
        fontSize: 14,
        color: '#666',
        width: 100,
    },
    detailValue: {
        fontSize: 14,
        color: '#333',
        flex: 1,
        textAlign: 'right',
    },
    breakItem: {
        backgroundColor: '#F5F5F5',
        padding: 12,
        borderRadius: 8,
        marginBottom: 8,
    },
    breakTime: {
        fontSize: 14,
        fontWeight: '500',
        color: '#333',
    },
    breakLocation: {
        fontSize: 13,
        color: '#666',
        marginTop: 4,
    },
    specialInstructions: {
        fontSize: 14,
        color: '#333',
        lineHeight: 22,
        backgroundColor: '#FFF9C4',
        padding: 12,
        borderRadius: 8,
    },
});
