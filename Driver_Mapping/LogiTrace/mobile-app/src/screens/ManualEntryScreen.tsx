import React, { useState, useEffect } from 'react';
import {
    View,
    Text,
    TextInput,
    TouchableOpacity,
    StyleSheet,
    SafeAreaView,
    Alert,
    KeyboardAvoidingView,
    Platform,
    ScrollView,
    ActivityIndicator
} from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { authService } from '../services/authService';
import { API_ENDPOINTS } from '../config/api';
import { useIndustryFields } from '../hooks/useIndustryFields';
import { BreakRecord } from '../config/industryFields';
import BreakRecordInput from '../components/BreakRecordInput';

export default function ManualEntryScreen({ navigation }: any) {
    // Industry hook
    const {
        industryCode,
        isFieldVisible,
        isFieldRequired,
        getFieldLabel,
        getVisibleFields,
        operationTypes,
        coDrivers,
        isBusIndustry,
        loading: industryLoading
    } = useIndustryFields();

    // Form state - common fields
    const [distance, setDistance] = useState('');
    const [startTime, setStartTime] = useState('');
    const [endTime, setEndTime] = useState('');

    // Industry-specific fields
    const [cargoWeight, setCargoWeight] = useState('');
    const [actualDistance, setActualDistance] = useState('');
    const [numPassengers, setNumPassengers] = useState('');
    const [revenue, setRevenue] = useState('');
    const [operationType, setOperationType] = useState('');
    const [coDriverId, setCoDriverId] = useState<number | null>(null);
    const [breakRecords, setBreakRecords] = useState<BreakRecord[]>([]);
    const [notes, setNotes] = useState('');

    // UI state
    const [submitting, setSubmitting] = useState(false);

    // Set default times (current date)
    useEffect(() => {
        const now = new Date();
        const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
        if (!endTime) {
            setEndTime(currentTime);
        }
    }, []);

    const validateForm = (): boolean => {
        if (!distance || parseFloat(distance) <= 0) {
            Alert.alert('入力エラー', '走行距離を入力してください');
            return false;
        }

        if (isFieldRequired('operation_type') && !operationType) {
            Alert.alert('入力エラー', '運行種別を選択してください');
            return false;
        }

        return true;
    };

    const handleSubmit = async () => {
        if (!validateForm()) return;

        Alert.alert(
            '送信確認',
            '入力した内容で日報を送信しますか？',
            [
                { text: '修正する', style: 'cancel' },
                {
                    text: '送信する',
                    onPress: submitWorkRecord
                }
            ]
        );
    };

    const submitWorkRecord = async () => {
        setSubmitting(true);

        try {
            // Build payload with all fields
            const payload: any = {
                work_date: new Date().toISOString().split('T')[0],
                record_method: 'manual',
                distance: parseFloat(distance),
            };

            // Add time fields if provided
            if (startTime) {
                const today = new Date().toISOString().split('T')[0];
                payload.start_time = `${today}T${startTime}:00`;
            }
            if (endTime) {
                const today = new Date().toISOString().split('T')[0];
                payload.end_time = `${today}T${endTime}:00`;
            }

            // Add industry-specific fields
            if (isFieldVisible('cargo_weight') && cargoWeight) {
                payload.cargo_weight = parseFloat(cargoWeight);
            }
            if (isFieldVisible('actual_distance') && actualDistance) {
                payload.actual_distance = parseFloat(actualDistance);
            }
            if (isFieldVisible('num_passengers') && numPassengers) {
                payload.num_passengers = parseInt(numPassengers, 10);
            }
            if (isFieldVisible('revenue') && revenue) {
                payload.revenue = parseFloat(revenue);
            }
            if (isFieldVisible('operation_type') && operationType) {
                payload.operation_type = operationType;
            }
            if (isFieldVisible('co_driver_id') && coDriverId) {
                payload.co_driver_id = coDriverId;
            }
            if (isFieldVisible('break_records') && breakRecords.length > 0) {
                payload.break_records = breakRecords;
            }
            if (notes) {
                payload.notes = notes;
            }

            // Submit to API
            const response = await authService.authenticatedFetch('/work-records', {
                method: 'POST',
                body: JSON.stringify(payload),
            });

            if (!response.ok) {
                throw new Error('Failed to submit work record');
            }

            Alert.alert('完了', '日報が送信されました', [
                { text: 'OK', onPress: () => navigation.navigate('ModeSelection') }
            ]);
        } catch (error) {
            console.error('Failed to submit work record:', error);
            Alert.alert('エラー', 'データの送信に失敗しました。後でもう一度お試しください。');
        } finally {
            setSubmitting(false);
        }
    };

    if (industryLoading) {
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
            <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={{ flex: 1 }}>
                <ScrollView contentContainerStyle={styles.content}>
                    <Text style={styles.title}>手入力モード</Text>
                    <Text style={styles.subtitle}>本日の業務実績を入力してください</Text>

                    {/* Time Fields */}
                    <View style={styles.timeRow}>
                        <View style={[styles.formGroup, { flex: 1, marginRight: 8 }]}>
                            <Text style={styles.label}>開始時刻</Text>
                            <TextInput
                                style={styles.timeInput}
                                placeholder="09:00"
                                value={startTime}
                                onChangeText={setStartTime}
                            />
                        </View>
                        <View style={[styles.formGroup, { flex: 1, marginLeft: 8 }]}>
                            <Text style={styles.label}>終了時刻</Text>
                            <TextInput
                                style={styles.timeInput}
                                placeholder="18:00"
                                value={endTime}
                                onChangeText={setEndTime}
                            />
                        </View>
                    </View>

                    {/* Distance - Always shown */}
                    <View style={styles.formGroup}>
                        <Text style={styles.label}>{getFieldLabel('distance')} (km) *</Text>
                        <TextInput
                            style={styles.input}
                            placeholder="例: 120.5"
                            keyboardType="decimal-pad"
                            value={distance}
                            onChangeText={setDistance}
                        />
                        <Text style={styles.helper}>※ 車両のメーターを確認して入力</Text>
                    </View>

                    {/* Trucking specific fields */}
                    {isFieldVisible('cargo_weight') && (
                        <View style={styles.formGroup}>
                            <Text style={styles.label}>{getFieldLabel('cargo_weight')} (トン)</Text>
                            <TextInput
                                style={styles.input}
                                placeholder="例: 4.5"
                                keyboardType="decimal-pad"
                                value={cargoWeight}
                                onChangeText={setCargoWeight}
                            />
                        </View>
                    )}

                    {isFieldVisible('actual_distance') && (
                        <View style={styles.formGroup}>
                            <Text style={styles.label}>{getFieldLabel('actual_distance')} (km)</Text>
                            <TextInput
                                style={styles.input}
                                placeholder="例: 80.0"
                                keyboardType="decimal-pad"
                                value={actualDistance}
                                onChangeText={setActualDistance}
                            />
                            <Text style={styles.helper}>※ 積載状態での走行距離</Text>
                        </View>
                    )}

                    {/* Taxi/Bus specific fields */}
                    {isFieldVisible('num_passengers') && (
                        <View style={styles.formGroup}>
                            <Text style={styles.label}>{getFieldLabel('num_passengers')}</Text>
                            <TextInput
                                style={styles.input}
                                placeholder="例: 30"
                                keyboardType="number-pad"
                                value={numPassengers}
                                onChangeText={setNumPassengers}
                            />
                        </View>
                    )}

                    {/* Taxi specific */}
                    {isFieldVisible('revenue') && (
                        <View style={styles.formGroup}>
                            <Text style={styles.label}>{getFieldLabel('revenue')} (円)</Text>
                            <TextInput
                                style={styles.input}
                                placeholder="例: 25000"
                                keyboardType="number-pad"
                                value={revenue}
                                onChangeText={setRevenue}
                            />
                        </View>
                    )}

                    {/* Bus specific fields */}
                    {isFieldVisible('operation_type') && (
                        <View style={styles.formGroup}>
                            <Text style={styles.label}>
                                {getFieldLabel('operation_type')}
                                {isFieldRequired('operation_type') ? ' *' : ''}
                            </Text>
                            <View style={styles.pickerContainer}>
                                <Picker
                                    selectedValue={operationType}
                                    onValueChange={(value) => setOperationType(value)}
                                    style={styles.picker}
                                >
                                    <Picker.Item label="選択してください" value="" />
                                    {operationTypes.map((type) => (
                                        <Picker.Item
                                            key={type.code}
                                            label={type.nameJa}
                                            value={type.code}
                                        />
                                    ))}
                                </Picker>
                            </View>
                        </View>
                    )}

                    {isFieldVisible('co_driver_id') && (
                        <View style={styles.formGroup}>
                            <Text style={styles.label}>{getFieldLabel('co_driver_id')}</Text>
                            <View style={styles.pickerContainer}>
                                <Picker
                                    selectedValue={coDriverId}
                                    onValueChange={(value) => setCoDriverId(value)}
                                    style={styles.picker}
                                >
                                    <Picker.Item label="なし" value={null} />
                                    {coDrivers.map((driver) => (
                                        <Picker.Item
                                            key={driver.id}
                                            label={driver.name}
                                            value={driver.id}
                                        />
                                    ))}
                                </Picker>
                            </View>
                        </View>
                    )}

                    {isFieldVisible('break_records') && (
                        <View style={styles.formGroup}>
                            <BreakRecordInput
                                value={breakRecords}
                                onChange={setBreakRecords}
                            />
                        </View>
                    )}

                    {/* Notes */}
                    <View style={styles.formGroup}>
                        <Text style={styles.label}>備考</Text>
                        <TextInput
                            style={[styles.input, styles.textArea]}
                            placeholder="特記事項があれば入力"
                            multiline
                            numberOfLines={3}
                            value={notes}
                            onChangeText={setNotes}
                        />
                    </View>

                    <TouchableOpacity
                        style={[styles.submitButton, submitting && styles.submitButtonDisabled]}
                        onPress={handleSubmit}
                        disabled={submitting}
                    >
                        {submitting ? (
                            <ActivityIndicator color="#FFF" />
                        ) : (
                            <Text style={styles.submitButtonText}>確定して送信</Text>
                        )}
                    </TouchableOpacity>

                    <TouchableOpacity style={styles.cancelButton} onPress={() => navigation.goBack()}>
                        <Text style={styles.cancelButtonText}>戻る</Text>
                    </TouchableOpacity>
                </ScrollView>
            </KeyboardAvoidingView>
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
    content: {
        padding: 24,
    },
    title: {
        fontSize: 24,
        fontWeight: 'bold',
        color: '#333',
        marginBottom: 8,
        textAlign: 'center',
    },
    subtitle: {
        fontSize: 14,
        color: '#666',
        marginBottom: 32,
        textAlign: 'center',
    },
    timeRow: {
        flexDirection: 'row',
        marginBottom: 8,
    },
    formGroup: {
        marginBottom: 20,
    },
    label: {
        fontSize: 16,
        fontWeight: 'bold',
        color: '#333',
        marginBottom: 8,
    },
    input: {
        backgroundColor: 'white',
        borderRadius: 12,
        padding: 16,
        fontSize: 20,
        borderWidth: 1,
        borderColor: '#ddd',
        textAlign: 'center',
        fontWeight: 'bold',
    },
    timeInput: {
        backgroundColor: 'white',
        borderRadius: 12,
        padding: 14,
        fontSize: 18,
        borderWidth: 1,
        borderColor: '#ddd',
        textAlign: 'center',
    },
    textArea: {
        textAlign: 'left',
        minHeight: 80,
        textAlignVertical: 'top',
    },
    pickerContainer: {
        backgroundColor: 'white',
        borderRadius: 12,
        borderWidth: 1,
        borderColor: '#ddd',
        overflow: 'hidden',
    },
    picker: {
        height: 50,
    },
    helper: {
        fontSize: 12,
        color: '#888',
        marginTop: 4,
    },
    submitButton: {
        backgroundColor: '#2196F3',
        padding: 20,
        borderRadius: 999,
        alignItems: 'center',
        marginTop: 24,
        shadowColor: '#2196F3',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.3,
        shadowRadius: 8,
        elevation: 5,
    },
    submitButtonDisabled: {
        backgroundColor: '#90CAF9',
    },
    submitButtonText: {
        color: 'white',
        fontSize: 18,
        fontWeight: 'bold',
    },
    cancelButton: {
        padding: 16,
        alignItems: 'center',
        marginTop: 16,
    },
    cancelButtonText: {
        color: '#666',
        fontSize: 16,
    },
});
