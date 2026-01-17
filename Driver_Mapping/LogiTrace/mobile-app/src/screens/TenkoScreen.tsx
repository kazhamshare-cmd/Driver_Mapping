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
import { useNavigation, useRoute } from '@react-navigation/native';
import { authService, User } from '../services/authService';
import { API_BASE_URL } from '../config/api';

type TenkoType = 'pre' | 'post';

export default function TenkoScreen() {
    const navigation = useNavigation();
    const route = useRoute();
    const tenkoType: TenkoType = (route.params as any)?.tenkoType || 'pre';

    const [user, setUser] = useState<User | null>(null);
    const [loading, setLoading] = useState(false);

    // Form state
    const [healthStatus, setHealthStatus] = useState<'good' | 'fair' | 'poor'>('good');
    const [healthNotes, setHealthNotes] = useState('');
    const [alcoholLevel, setAlcoholLevel] = useState('0.000');
    const [fatigueLevel, setFatigueLevel] = useState(1);
    const [sleepHours, setSleepHours] = useState('');
    const [sleepSufficient, setSleepSufficient] = useState(true);
    const [notes, setNotes] = useState('');

    useEffect(() => {
        loadUser();
    }, []);

    const loadUser = async () => {
        const userData = await authService.getUser();
        setUser(userData);
    };

    const handleSubmit = async () => {
        if (!user) return;

        // Alcohol check validation
        if (parseFloat(alcoholLevel) > 0) {
            Alert.alert(
                'アルコール検出',
                'アルコールが検出されました。乗務を開始することはできません。',
                [{ text: '確認' }]
            );
            return;
        }

        setLoading(true);
        try {
            const token = await authService.getToken();
            const response = await fetch(`${API_BASE_URL}/tenko`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`,
                },
                body: JSON.stringify({
                    company_id: user.companyId,
                    driver_id: user.id,
                    tenko_type: tenkoType,
                    method: 'face_to_face',
                    health_status: healthStatus,
                    health_notes: healthNotes || null,
                    alcohol_level: parseFloat(alcoholLevel),
                    fatigue_level: fatigueLevel,
                    sleep_hours: sleepHours ? parseFloat(sleepHours) : null,
                    sleep_sufficient: sleepSufficient,
                    inspector_id: user.id, // Self-check mode
                    notes: notes || null,
                }),
            });

            if (!response.ok) {
                throw new Error('点呼の登録に失敗しました');
            }

            Alert.alert(
                '完了',
                tenkoType === 'pre' ? '乗務前点呼を記録しました' : '乗務後点呼を記録しました',
                [
                    {
                        text: 'OK',
                        onPress: () => {
                            if (tenkoType === 'pre') {
                                (navigation as any).navigate('Inspection');
                            } else {
                                (navigation as any).navigate('ModeSelection');
                            }
                        },
                    },
                ]
            );
        } catch (error: any) {
            Alert.alert('エラー', error.message);
        } finally {
            setLoading(false);
        }
    };

    const HealthButton = ({ status, label, color }: { status: 'good' | 'fair' | 'poor'; label: string; color: string }) => (
        <TouchableOpacity
            style={[
                styles.healthButton,
                healthStatus === status && { backgroundColor: color, borderColor: color },
            ]}
            onPress={() => setHealthStatus(status)}
        >
            <Text style={[styles.healthButtonText, healthStatus === status && { color: 'white' }]}>
                {label}
            </Text>
        </TouchableOpacity>
    );

    const FatigueButton = ({ level }: { level: number }) => (
        <TouchableOpacity
            style={[
                styles.fatigueButton,
                fatigueLevel === level && styles.fatigueButtonActive,
            ]}
            onPress={() => setFatigueLevel(level)}
        >
            <Text style={[styles.fatigueButtonText, fatigueLevel === level && styles.fatigueButtonTextActive]}>
                {level}
            </Text>
        </TouchableOpacity>
    );

    return (
        <SafeAreaView style={styles.container}>
            <ScrollView contentContainerStyle={styles.content}>
                <View style={styles.header}>
                    <Text style={styles.headerTitle}>
                        {tenkoType === 'pre' ? '乗務前点呼' : '乗務後点呼'}
                    </Text>
                    <Text style={styles.headerSubtitle}>
                        {tenkoType === 'pre'
                            ? '乗務を開始する前に点呼を実施してください'
                            : '乗務終了後の点呼を実施してください'}
                    </Text>
                </View>

                {/* 健康状態 */}
                <View style={styles.section}>
                    <Text style={styles.sectionTitle}>健康状態</Text>
                    <View style={styles.healthButtons}>
                        <HealthButton status="good" label="良好" color="#4CAF50" />
                        <HealthButton status="fair" label="普通" color="#FF9800" />
                        <HealthButton status="poor" label="不良" color="#F44336" />
                    </View>
                    {healthStatus !== 'good' && (
                        <TextInput
                            style={styles.textInput}
                            placeholder="詳細を入力してください"
                            value={healthNotes}
                            onChangeText={setHealthNotes}
                            multiline
                        />
                    )}
                </View>

                {/* アルコールチェック */}
                <View style={styles.section}>
                    <Text style={styles.sectionTitle}>アルコールチェック</Text>
                    <View style={styles.alcoholContainer}>
                        <TextInput
                            style={[
                                styles.alcoholInput,
                                parseFloat(alcoholLevel) > 0 && styles.alcoholInputError,
                            ]}
                            placeholder="0.000"
                            value={alcoholLevel}
                            onChangeText={setAlcoholLevel}
                            keyboardType="decimal-pad"
                        />
                        <Text style={styles.alcoholUnit}>mg/L</Text>
                    </View>
                    {parseFloat(alcoholLevel) > 0 && (
                        <Text style={styles.errorText}>アルコールが検出されています</Text>
                    )}
                    <Text style={styles.helperText}>0.000以外は不合格となります</Text>
                </View>

                {/* 疲労度 */}
                <View style={styles.section}>
                    <Text style={styles.sectionTitle}>疲労度</Text>
                    <View style={styles.fatigueContainer}>
                        <Text style={styles.fatigueLabel}>元気</Text>
                        <View style={styles.fatigueButtons}>
                            {[1, 2, 3, 4, 5].map((level) => (
                                <FatigueButton key={level} level={level} />
                            ))}
                        </View>
                        <Text style={styles.fatigueLabel}>疲労</Text>
                    </View>
                </View>

                {/* 睡眠時間（乗務前のみ） */}
                {tenkoType === 'pre' && (
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>睡眠時間</Text>
                        <View style={styles.sleepContainer}>
                            <TextInput
                                style={styles.sleepInput}
                                placeholder="6.0"
                                value={sleepHours}
                                onChangeText={setSleepHours}
                                keyboardType="decimal-pad"
                            />
                            <Text style={styles.sleepUnit}>時間</Text>
                        </View>
                        <View style={styles.sleepSufficientContainer}>
                            <Text style={styles.sleepSufficientLabel}>十分な睡眠がとれた</Text>
                            <View style={styles.sleepSufficientButtons}>
                                <TouchableOpacity
                                    style={[
                                        styles.sleepSufficientButton,
                                        sleepSufficient && styles.sleepSufficientButtonActive,
                                    ]}
                                    onPress={() => setSleepSufficient(true)}
                                >
                                    <Text style={[styles.sleepSufficientButtonText, sleepSufficient && { color: 'white' }]}>
                                        はい
                                    </Text>
                                </TouchableOpacity>
                                <TouchableOpacity
                                    style={[
                                        styles.sleepSufficientButton,
                                        !sleepSufficient && styles.sleepSufficientButtonActiveNo,
                                    ]}
                                    onPress={() => setSleepSufficient(false)}
                                >
                                    <Text style={[styles.sleepSufficientButtonText, !sleepSufficient && { color: 'white' }]}>
                                        いいえ
                                    </Text>
                                </TouchableOpacity>
                            </View>
                        </View>
                    </View>
                )}

                {/* 備考 */}
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

                {/* 送信ボタン */}
                <TouchableOpacity
                    style={[
                        styles.submitButton,
                        parseFloat(alcoholLevel) > 0 && styles.submitButtonDisabled,
                    ]}
                    onPress={handleSubmit}
                    disabled={loading || parseFloat(alcoholLevel) > 0}
                >
                    {loading ? (
                        <ActivityIndicator color="white" />
                    ) : (
                        <Text style={styles.submitButtonText}>
                            点呼を記録する
                        </Text>
                    )}
                </TouchableOpacity>

                {tenkoType === 'pre' && (
                    <Text style={styles.footerNote}>
                        ※ 点呼完了後、車両点検に進みます
                    </Text>
                )}
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
        marginBottom: 24,
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
    healthButtons: {
        flexDirection: 'row',
        gap: 8,
    },
    healthButton: {
        flex: 1,
        paddingVertical: 12,
        paddingHorizontal: 16,
        borderRadius: 8,
        borderWidth: 2,
        borderColor: '#E0E0E0',
        alignItems: 'center',
    },
    healthButtonText: {
        fontSize: 16,
        fontWeight: '600',
        color: '#666',
    },
    textInput: {
        borderWidth: 1,
        borderColor: '#E0E0E0',
        borderRadius: 8,
        padding: 12,
        marginTop: 12,
        fontSize: 16,
        minHeight: 44,
    },
    alcoholContainer: {
        flexDirection: 'row',
        alignItems: 'center',
    },
    alcoholInput: {
        flex: 1,
        borderWidth: 2,
        borderColor: '#E0E0E0',
        borderRadius: 8,
        padding: 12,
        fontSize: 24,
        fontWeight: 'bold',
        textAlign: 'center',
    },
    alcoholInputError: {
        borderColor: '#F44336',
        backgroundColor: '#FFEBEE',
    },
    alcoholUnit: {
        fontSize: 18,
        color: '#666',
        marginLeft: 12,
    },
    errorText: {
        color: '#F44336',
        fontSize: 14,
        marginTop: 8,
    },
    helperText: {
        color: '#999',
        fontSize: 12,
        marginTop: 8,
    },
    fatigueContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
    },
    fatigueLabel: {
        fontSize: 14,
        color: '#666',
    },
    fatigueButtons: {
        flexDirection: 'row',
        gap: 8,
    },
    fatigueButton: {
        width: 44,
        height: 44,
        borderRadius: 22,
        borderWidth: 2,
        borderColor: '#E0E0E0',
        alignItems: 'center',
        justifyContent: 'center',
    },
    fatigueButtonActive: {
        backgroundColor: '#2196F3',
        borderColor: '#2196F3',
    },
    fatigueButtonText: {
        fontSize: 18,
        fontWeight: '600',
        color: '#666',
    },
    fatigueButtonTextActive: {
        color: 'white',
    },
    sleepContainer: {
        flexDirection: 'row',
        alignItems: 'center',
    },
    sleepInput: {
        width: 100,
        borderWidth: 2,
        borderColor: '#E0E0E0',
        borderRadius: 8,
        padding: 12,
        fontSize: 20,
        fontWeight: 'bold',
        textAlign: 'center',
    },
    sleepUnit: {
        fontSize: 18,
        color: '#666',
        marginLeft: 12,
    },
    sleepSufficientContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginTop: 16,
    },
    sleepSufficientLabel: {
        fontSize: 14,
        color: '#666',
    },
    sleepSufficientButtons: {
        flexDirection: 'row',
        gap: 8,
    },
    sleepSufficientButton: {
        paddingVertical: 8,
        paddingHorizontal: 20,
        borderRadius: 20,
        borderWidth: 2,
        borderColor: '#E0E0E0',
    },
    sleepSufficientButtonActive: {
        backgroundColor: '#4CAF50',
        borderColor: '#4CAF50',
    },
    sleepSufficientButtonActiveNo: {
        backgroundColor: '#FF9800',
        borderColor: '#FF9800',
    },
    sleepSufficientButtonText: {
        fontSize: 14,
        fontWeight: '600',
        color: '#666',
    },
    submitButton: {
        backgroundColor: '#4CAF50',
        borderRadius: 12,
        padding: 16,
        alignItems: 'center',
        marginTop: 8,
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
    },
});
