import React, { useState, useEffect, useRef } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, SafeAreaView, Alert, Platform, ActivityIndicator, ScrollView, TextInput, Modal } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import * as Location from 'expo-location';
import { authService } from '../services/authService';
import { API_ENDPOINTS } from '../config/api';
import { useIndustryFields } from '../hooks/useIndustryFields';
import { BreakRecord } from '../config/industryFields';
import BreakRecordInput from '../components/BreakRecordInput';

export default function GpsTrackingScreen({ navigation }: any) {
    const [duration, setDuration] = useState(0);
    const [distance, setDistance] = useState(0); // in meters
    const [status, setStatus] = useState('waiting'); // waiting, tracking, paused
    const [currentLocation, setCurrentLocation] = useState<Location.LocationObject | null>(null);
    const [routeCoordinates, setRouteCoordinates] = useState<Location.LocationObject[]>([]);
    const [workRecordId, setWorkRecordId] = useState<number | null>(null);
    const [submitting, setSubmitting] = useState(false);

    // Industry-specific fields
    const {
        isFieldVisible,
        getFieldLabel,
        operationTypes,
        coDrivers,
        isBusIndustry,
        isTaxiIndustry,
        loading: industryLoading
    } = useIndustryFields();

    // Industry-specific state
    const [numPassengers, setNumPassengers] = useState('');
    const [operationType, setOperationType] = useState('');
    const [coDriverId, setCoDriverId] = useState<number | null>(null);
    const [breakRecords, setBreakRecords] = useState<BreakRecord[]>([]);
    const [cargoWeight, setCargoWeight] = useState('');
    const [actualDistance, setActualDistance] = useState('');
    const [revenue, setRevenue] = useState('');
    const [showEndModal, setShowEndModal] = useState(false);

    const timerRef = useRef<NodeJS.Timeout | null>(null);
    const locationSubscription = useRef<Location.LocationSubscription | null>(null);

    // Manual Haversine to avoid dependency for MVP
    const calculateDistance = (lat1: number, lon1: number, lat2: number, lon2: number) => {
        const R = 6371e3; // metres
        const φ1 = lat1 * Math.PI / 180; // φ, λ in radians
        const φ2 = lat2 * Math.PI / 180;
        const Δφ = (lat2 - lat1) * Math.PI / 180;
        const Δλ = (lon2 - lon1) * Math.PI / 180;

        const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return R * c;
    }

    const startTracking = async () => {
        let { status: permStatus } = await Location.requestForegroundPermissionsAsync();
        if (permStatus !== 'granted') {
            Alert.alert('許可が必要です', 'GPS追跡を行うには位置情報の許可が必要です。');
            return;
        }

        // Create work record via API
        try {
            const response = await authService.authenticatedFetch(API_ENDPOINTS.START_WORK, {
                method: 'POST',
                body: JSON.stringify({
                    work_date: new Date().toISOString().split('T')[0],
                }),
            });

            if (response.ok) {
                const data = await response.json();
                setWorkRecordId(data.id);
            } else {
                console.warn('Failed to create work record, continuing offline');
            }
        } catch (error) {
            console.warn('API unavailable, continuing offline:', error);
        }

        setStatus('tracking');
        setDuration(0);
        setDistance(0);
        setRouteCoordinates([]);

        // Start Timer
        timerRef.current = setInterval(() => {
            setDuration(prev => prev + 1);
        }, 1000);

        // Start Location Updates
        locationSubscription.current = await Location.watchPositionAsync(
            {
                accuracy: Location.Accuracy.High,
                timeInterval: 5000,
                distanceInterval: 10,
            },
            (location) => {
                setCurrentLocation(location);
                setRouteCoordinates(prev => {
                    const lastLoc = prev[prev.length - 1];
                    let newDist = 0;
                    if (lastLoc) {
                        newDist = calculateDistance(
                            lastLoc.coords.latitude, lastLoc.coords.longitude,
                            location.coords.latitude, location.coords.longitude
                        );
                    }
                    if (newDist > 0) {
                        setDistance(d => d + newDist);
                    }
                    return [...prev, location];
                });

                // Send location update to server (non-blocking)
                if (workRecordId) {
                    authService.authenticatedFetch(API_ENDPOINTS.UPDATE_LOCATION, {
                        method: 'POST',
                        body: JSON.stringify({
                            work_record_id: workRecordId,
                            latitude: location.coords.latitude,
                            longitude: location.coords.longitude,
                            accuracy: location.coords.accuracy,
                            timestamp: location.timestamp,
                        }),
                    }).catch(() => {});
                }
            }
        );
    };

    const stopTracking = async () => {
        if (timerRef.current) clearInterval(timerRef.current);
        if (locationSubscription.current) locationSubscription.current.remove();
        setStatus('stopped');
        setShowEndModal(true);
    };

    const submitWorkRecord = async () => {
        setSubmitting(true);
        const distanceKm = distance / 1000;

        try {
            // Send work record to API with industry-specific data
            if (workRecordId) {
                const payload: any = {
                    work_record_id: workRecordId,
                    distance: distanceKm,
                    duration: duration,
                };

                // Add industry-specific fields
                if (isFieldVisible('num_passengers') && numPassengers) {
                    payload.num_passengers = parseInt(numPassengers, 10);
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
                if (isFieldVisible('cargo_weight') && cargoWeight) {
                    payload.cargo_weight = parseFloat(cargoWeight);
                }
                if (isFieldVisible('actual_distance') && actualDistance) {
                    payload.actual_distance = parseFloat(actualDistance);
                }
                if (isFieldVisible('revenue') && revenue) {
                    payload.revenue = parseFloat(revenue);
                }

                await authService.authenticatedFetch(API_ENDPOINTS.END_WORK, {
                    method: 'POST',
                    body: JSON.stringify(payload),
                });
            }
            setShowEndModal(false);
            navigation.navigate('ModeSelection');
        } catch (error) {
            console.error('Failed to submit work record:', error);
            Alert.alert(
                'エラー',
                'データの送信に失敗しました。後でもう一度お試しください。',
                [{ text: 'OK', onPress: () => navigation.navigate('ModeSelection') }]
            );
        } finally {
            setSubmitting(false);
        }
    };

    useEffect(() => {
        startTracking();
        return () => {
            if (timerRef.current) clearInterval(timerRef.current);
            if (locationSubscription.current) locationSubscription.current.remove();
        };
    }, []);

    const formatTime = (seconds: number) => {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    };

    const handleStop = () => {
        Alert.alert(
            '勤務終了',
            '勤務を終了してデータを送信しますか？',
            [
                { text: 'キャンセル', style: 'cancel' },
                {
                    text: '終了する',
                    style: 'destructive',
                    onPress: stopTracking
                }
            ]
        );
    };

    return (
        <SafeAreaView style={styles.container}>
            <View style={styles.content}>
                <View style={styles.statusContainer}>
                    <View style={[styles.blinkingDot, { opacity: status === 'tracking' ? 1 : 0.5 }]} />
                    <Text style={styles.statusText}>
                        {status === 'tracking' ? 'GPS記録中' : '待機中...'}
                    </Text>
                </View>

                <View style={styles.metricsContainer}>
                    <Text style={styles.metricLabel}>経過時間</Text>
                    <Text style={styles.metricValue}>{formatTime(duration)}</Text>

                    <Text style={styles.metricLabel}>走行距離（推定）</Text>
                    <Text style={styles.metricValue}>{(distance / 1000).toFixed(2)} km</Text>
                </View>

                <View style={styles.locationContainer}>
                    <Text style={styles.locationLabel}>現在地 (緯度/経度)</Text>
                    <Text style={styles.locationValue}>
                        {currentLocation
                            ? `${currentLocation.coords.latitude.toFixed(4)}, ${currentLocation.coords.longitude.toFixed(4)}`
                            : '位置情報取得中...'}
                    </Text>
                    <Text style={{ fontSize: 12, color: '#aaa', marginTop: 4 }}>
                        精度: {currentLocation ? `±${currentLocation.coords.accuracy?.toFixed(1)}m` : '-'}
                    </Text>
                </View>

                <TouchableOpacity style={styles.stopButton} onPress={handleStop}>
                    <Text style={styles.stopButtonText}>勤務終了</Text>
                </TouchableOpacity>
            </View>

            {/* End Work Modal with Industry-Specific Fields */}
            <Modal
                visible={showEndModal}
                animationType="slide"
                transparent={true}
                onRequestClose={() => setShowEndModal(false)}
            >
                <View style={styles.modalOverlay}>
                    <View style={styles.modalContent}>
                        <View style={styles.modalHeader}>
                            <Text style={styles.modalTitle}>勤務終了</Text>
                            <TouchableOpacity onPress={() => setShowEndModal(false)}>
                                <Text style={styles.modalCloseText}>×</Text>
                            </TouchableOpacity>
                        </View>

                        <ScrollView style={styles.modalBody}>
                            {/* Summary */}
                            <View style={styles.summarySection}>
                                <Text style={styles.summaryText}>
                                    走行距離: {(distance / 1000).toFixed(2)} km
                                </Text>
                                <Text style={styles.summaryText}>
                                    勤務時間: {formatTime(duration)}
                                </Text>
                            </View>

                            {/* Industry-Specific Fields */}
                            {isFieldVisible('num_passengers') && (
                                <View style={styles.inputGroup}>
                                    <Text style={styles.inputLabel}>{getFieldLabel('num_passengers')}</Text>
                                    <TextInput
                                        style={styles.input}
                                        value={numPassengers}
                                        onChangeText={setNumPassengers}
                                        keyboardType="numeric"
                                        placeholder="0"
                                    />
                                </View>
                            )}

                            {isFieldVisible('operation_type') && (
                                <View style={styles.inputGroup}>
                                    <Text style={styles.inputLabel}>{getFieldLabel('operation_type')}</Text>
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
                                <View style={styles.inputGroup}>
                                    <Text style={styles.inputLabel}>{getFieldLabel('co_driver_id')}</Text>
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

                            {isFieldVisible('cargo_weight') && (
                                <View style={styles.inputGroup}>
                                    <Text style={styles.inputLabel}>{getFieldLabel('cargo_weight')} (t)</Text>
                                    <TextInput
                                        style={styles.input}
                                        value={cargoWeight}
                                        onChangeText={setCargoWeight}
                                        keyboardType="decimal-pad"
                                        placeholder="0.0"
                                    />
                                </View>
                            )}

                            {isFieldVisible('actual_distance') && (
                                <View style={styles.inputGroup}>
                                    <Text style={styles.inputLabel}>{getFieldLabel('actual_distance')} (km)</Text>
                                    <TextInput
                                        style={styles.input}
                                        value={actualDistance}
                                        onChangeText={setActualDistance}
                                        keyboardType="decimal-pad"
                                        placeholder="0.0"
                                    />
                                </View>
                            )}

                            {isFieldVisible('revenue') && (
                                <View style={styles.inputGroup}>
                                    <Text style={styles.inputLabel}>{getFieldLabel('revenue')} (円)</Text>
                                    <TextInput
                                        style={styles.input}
                                        value={revenue}
                                        onChangeText={setRevenue}
                                        keyboardType="numeric"
                                        placeholder="0"
                                    />
                                </View>
                            )}

                            {isFieldVisible('break_records') && (
                                <View style={styles.inputGroup}>
                                    <BreakRecordInput
                                        value={breakRecords}
                                        onChange={setBreakRecords}
                                    />
                                </View>
                            )}
                        </ScrollView>

                        <View style={styles.modalFooter}>
                            <TouchableOpacity
                                style={styles.cancelModalButton}
                                onPress={() => setShowEndModal(false)}
                            >
                                <Text style={styles.cancelModalButtonText}>キャンセル</Text>
                            </TouchableOpacity>
                            <TouchableOpacity
                                style={[styles.submitButton, submitting && styles.submitButtonDisabled]}
                                onPress={submitWorkRecord}
                                disabled={submitting}
                            >
                                {submitting ? (
                                    <ActivityIndicator color="#FFF" />
                                ) : (
                                    <Text style={styles.submitButtonText}>送信して終了</Text>
                                )}
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
        backgroundColor: '#fff',
    },
    content: {
        flex: 1,
        padding: 24,
        alignItems: 'center',
        justifyContent: 'space-between',
    },
    statusContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        backgroundColor: '#E8F5E9',
        paddingHorizontal: 20,
        paddingVertical: 10,
        borderRadius: 999,
        marginTop: 20,
    },
    blinkingDot: {
        width: 12,
        height: 12,
        borderRadius: 6,
        backgroundColor: '#4CAF50',
        marginRight: 8,
    },
    statusText: {
        color: '#4CAF50',
        fontWeight: 'bold',
        fontSize: 16,
    },
    metricsContainer: {
        alignItems: 'center',
        width: '100%',
    },
    metricLabel: {
        fontSize: 14,
        color: '#666',
        marginBottom: 4,
        marginTop: 32,
    },
    metricValue: {
        fontSize: 48,
        fontWeight: 'bold',
        color: '#333',
        fontVariant: ['tabular-nums'],
    },
    locationContainer: {
        width: '100%',
        padding: 16,
        backgroundColor: '#F5F5F5',
        borderRadius: 12,
    },
    locationLabel: {
        fontSize: 12,
        color: '#888',
        marginBottom: 4,
    },
    locationValue: {
        fontSize: 16,
        color: '#333',
    },
    stopButton: {
        width: '100%',
        backgroundColor: '#F44336', // Warning Red
        padding: 24,
        borderRadius: 16,
        alignItems: 'center',
        marginBottom: 20,
        shadowColor: '#F44336',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.3,
        shadowRadius: 8,
        elevation: 5,
    },
    stopButtonText: {
        color: 'white',
        fontSize: 24,
        fontWeight: 'bold',
    },
    // Modal styles
    modalOverlay: {
        flex: 1,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        justifyContent: 'flex-end',
    },
    modalContent: {
        backgroundColor: '#FFF',
        borderTopLeftRadius: 20,
        borderTopRightRadius: 20,
        maxHeight: '85%',
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
    modalBody: {
        padding: 16,
    },
    modalFooter: {
        flexDirection: 'row',
        padding: 16,
        gap: 12,
        borderTopWidth: 1,
        borderTopColor: '#E0E0E0',
    },
    summarySection: {
        backgroundColor: '#F0F7FF',
        padding: 16,
        borderRadius: 12,
        marginBottom: 16,
    },
    summaryText: {
        fontSize: 16,
        color: '#333',
        marginBottom: 4,
    },
    inputGroup: {
        marginBottom: 16,
    },
    inputLabel: {
        fontSize: 14,
        fontWeight: '500',
        color: '#333',
        marginBottom: 8,
    },
    input: {
        borderWidth: 1,
        borderColor: '#DDD',
        borderRadius: 8,
        padding: 12,
        fontSize: 16,
        backgroundColor: '#FFF',
    },
    pickerContainer: {
        borderWidth: 1,
        borderColor: '#DDD',
        borderRadius: 8,
        overflow: 'hidden',
        backgroundColor: '#FFF',
    },
    picker: {
        height: 50,
    },
    cancelModalButton: {
        flex: 1,
        padding: 14,
        borderRadius: 8,
        backgroundColor: '#F5F5F5',
        alignItems: 'center',
    },
    cancelModalButtonText: {
        fontSize: 16,
        fontWeight: '500',
        color: '#666',
    },
    submitButton: {
        flex: 1,
        padding: 14,
        borderRadius: 8,
        backgroundColor: '#4CAF50',
        alignItems: 'center',
    },
    submitButtonDisabled: {
        backgroundColor: '#A5D6A7',
    },
    submitButtonText: {
        fontSize: 16,
        fontWeight: '600',
        color: '#FFF',
    },
});
