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
import { useNavigation, useRoute } from '@react-navigation/native';
import * as ImagePicker from 'expo-image-picker';
import { authService, User } from '../services/authService';
import { API_BASE_URL } from '../config/api';
import { useDriverAppSettings } from '../contexts/DriverAppSettingsContext';
import { bleAlcoholService, BleDevice, AlcoholReading } from '../services/bleAlcoholService';

type TenkoType = 'pre' | 'post';

export default function TenkoScreen() {
    const navigation = useNavigation();
    const route = useRoute();
    const tenkoType: TenkoType = (route.params as any)?.tenkoType || 'pre';

    // Driver App Settings
    const { settings, isFeatureEnabled, loading: settingsLoading } = useDriverAppSettings();

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

    // Photo capture state
    const [facePhoto, setFacePhoto] = useState<string | null>(null);
    const [photoTaken, setPhotoTaken] = useState(false);

    // BLE Alcohol Checker state
    const [bleModalVisible, setBleModalVisible] = useState(false);
    const [bleScanning, setBleScanning] = useState(false);
    const [bleDevices, setBleDevices] = useState<BleDevice[]>([]);
    const [bleConnected, setBleConnected] = useState(false);
    const [bleReading, setBleReading] = useState<AlcoholReading | null>(null);
    const [bleConnecting, setBleConnecting] = useState(false);

    useEffect(() => {
        loadUser();
    }, []);

    const loadUser = async () => {
        const userData = await authService.getUser();
        setUser(userData);
    };

    // BLE Alcohol Checker Functions
    const startBleScan = useCallback(async () => {
        setBleScanning(true);
        setBleDevices([]);

        await bleAlcoholService.startScan(
            (device) => {
                setBleDevices((prev) => {
                    if (prev.find((d) => d.id === device.id)) return prev;
                    return [...prev, device];
                });
            },
            (error) => {
                console.error('BLE Scan error:', error);
                Alert.alert('エラー', 'デバイスのスキャンに失敗しました');
                setBleScanning(false);
            }
        );

        // 30秒でスキャン停止
        setTimeout(() => {
            setBleScanning(false);
            bleAlcoholService.stopScan();
        }, 30000);
    }, []);

    const connectToDevice = useCallback(async (device: BleDevice) => {
        setBleConnecting(true);
        try {
            await bleAlcoholService.connect(device.id);
            setBleConnected(true);

            // 計測値の監視開始
            await bleAlcoholService.startReadingMonitor(
                (reading) => {
                    setBleReading(reading);
                    if (reading.isValid) {
                        setAlcoholLevel(reading.value.toFixed(3));
                    }
                },
                (error) => {
                    console.error('BLE Reading error:', error);
                }
            );

            setBleModalVisible(false);
            Alert.alert('接続完了', `${device.name}に接続しました。測定を開始してください。`);
        } catch (error: any) {
            Alert.alert('接続エラー', error.message);
        } finally {
            setBleConnecting(false);
        }
    }, []);

    const disconnectBle = useCallback(async () => {
        await bleAlcoholService.disconnect();
        setBleConnected(false);
        setBleReading(null);
    }, []);

    // Photo Capture Function
    const takePhoto = useCallback(async () => {
        const { status } = await ImagePicker.requestCameraPermissionsAsync();
        if (status !== 'granted') {
            Alert.alert('権限が必要です', 'カメラを使用するには権限の許可が必要です。');
            return;
        }

        const result = await ImagePicker.launchCameraAsync({
            mediaTypes: ImagePicker.MediaTypeOptions.Images,
            allowsEditing: false,
            quality: 0.8,
            cameraType: ImagePicker.CameraType.front, // フロントカメラ（自撮り）
            aspect: [1, 1],
        });

        if (!result.canceled && result.assets[0]) {
            setFacePhoto(result.assets[0].uri);
            setPhotoTaken(true);
        }
    }, []);

    const handleSubmit = async () => {
        if (!user) return;

        // Photo requirement check
        if (settings.requirePhotoOnTenko && !photoTaken) {
            Alert.alert(
                '顔写真が必要です',
                '点呼を記録するには顔写真の撮影が必要です。',
                [{ text: '確認' }]
            );
            return;
        }

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

            // Prepare form data for photo upload
            const formData = new FormData();
            formData.append('company_id', String(user.companyId));
            formData.append('driver_id', String(user.id));
            formData.append('tenko_type', tenkoType);
            formData.append('method', 'face_to_face');
            formData.append('health_status', healthStatus);
            formData.append('health_notes', healthNotes || '');
            formData.append('alcohol_level', alcoholLevel);
            formData.append('fatigue_level', String(fatigueLevel));
            formData.append('sleep_hours', sleepHours || '');
            formData.append('sleep_sufficient', String(sleepSufficient));
            formData.append('inspector_id', String(user.id));
            formData.append('notes', notes || '');

            // BLE device info if connected
            if (bleConnected && bleReading) {
                formData.append('alcohol_device_id', bleReading.deviceId);
                formData.append('alcohol_device_name', bleReading.deviceName);
                formData.append('alcohol_measurement_method', 'ble');
            } else {
                formData.append('alcohol_measurement_method', 'manual');
            }

            // Add photo if taken
            if (facePhoto) {
                const filename = `tenko_${user.id}_${Date.now()}.jpg`;
                formData.append('face_photo', {
                    uri: facePhoto,
                    type: 'image/jpeg',
                    name: filename,
                } as any);
            }

            const response = await fetch(`${API_BASE_URL}/tenko`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'multipart/form-data',
                },
                body: formData,
            });

            if (!response.ok) {
                throw new Error('点呼の登録に失敗しました');
            }

            // Disconnect BLE if connected
            if (bleConnected) {
                await disconnectBle();
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

    // Check if BLE feature is enabled
    const showBleOption = isFeatureEnabled('bleAlcoholChecker') &&
        (settings.alcoholCheckMode === 'ble' || settings.alcoholCheckMode === 'both');

    // Check if photo capture is enabled
    const showPhotoCapture = isFeatureEnabled('photoCapture') &&
        settings.identityVerificationMode !== 'none';

    if (settingsLoading) {
        return (
            <SafeAreaView style={styles.container}>
                <View style={styles.loadingContainer}>
                    <ActivityIndicator size="large" color="#2196F3" />
                    <Text style={styles.loadingText}>設定を読み込み中...</Text>
                </View>
            </SafeAreaView>
        );
    }

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

                {/* 顔写真撮影（オプション） */}
                {showPhotoCapture && (
                    <View style={styles.section}>
                        <Text style={styles.sectionTitle}>
                            本人確認写真
                            {settings.requirePhotoOnTenko && <Text style={styles.requiredMark}> *必須</Text>}
                        </Text>
                        {facePhoto ? (
                            <View style={styles.photoContainer}>
                                <Image source={{ uri: facePhoto }} style={styles.photoPreview} />
                                <TouchableOpacity
                                    style={styles.retakeButton}
                                    onPress={takePhoto}
                                >
                                    <Text style={styles.retakeButtonText}>撮り直す</Text>
                                </TouchableOpacity>
                            </View>
                        ) : (
                            <TouchableOpacity style={styles.photoButton} onPress={takePhoto}>
                                <Text style={styles.photoButtonIcon}>📷</Text>
                                <Text style={styles.photoButtonText}>顔写真を撮影</Text>
                            </TouchableOpacity>
                        )}
                    </View>
                )}

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

                    {/* BLE接続ボタン（オプション） */}
                    {showBleOption && (
                        <View style={styles.bleContainer}>
                            {bleConnected ? (
                                <View style={styles.bleConnectedInfo}>
                                    <Text style={styles.bleConnectedText}>
                                        ✓ {bleAlcoholService.getConnectedDevice()?.name} 接続中
                                    </Text>
                                    <TouchableOpacity onPress={disconnectBle}>
                                        <Text style={styles.bleDisconnectText}>切断</Text>
                                    </TouchableOpacity>
                                </View>
                            ) : (
                                <TouchableOpacity
                                    style={styles.bleConnectButton}
                                    onPress={() => setBleModalVisible(true)}
                                >
                                    <Text style={styles.bleConnectButtonText}>
                                        🔗 アルコールチェッカーに接続
                                    </Text>
                                </TouchableOpacity>
                            )}
                        </View>
                    )}

                    <View style={styles.alcoholContainer}>
                        <TextInput
                            style={[
                                styles.alcoholInput,
                                parseFloat(alcoholLevel) > 0 && styles.alcoholInputError,
                                bleConnected && styles.alcoholInputBle,
                            ]}
                            placeholder="0.000"
                            value={alcoholLevel}
                            onChangeText={setAlcoholLevel}
                            keyboardType="decimal-pad"
                            editable={!bleConnected || settings.alcoholCheckMode === 'both'}
                        />
                        <Text style={styles.alcoholUnit}>mg/L</Text>
                    </View>
                    {parseFloat(alcoholLevel) > 0 && (
                        <Text style={styles.errorText}>アルコールが検出されています</Text>
                    )}
                    {bleConnected && (
                        <Text style={styles.bleHelperText}>
                            BLE機器から自動取得されます
                        </Text>
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
                        (parseFloat(alcoholLevel) > 0 || (settings.requirePhotoOnTenko && !photoTaken)) && styles.submitButtonDisabled,
                    ]}
                    onPress={handleSubmit}
                    disabled={loading || parseFloat(alcoholLevel) > 0 || (settings.requirePhotoOnTenko && !photoTaken)}
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

            {/* BLE Device Selection Modal */}
            <Modal
                visible={bleModalVisible}
                animationType="slide"
                transparent={true}
                onRequestClose={() => setBleModalVisible(false)}
            >
                <View style={styles.modalOverlay}>
                    <View style={styles.modalContent}>
                        <View style={styles.modalHeader}>
                            <Text style={styles.modalTitle}>アルコールチェッカー選択</Text>
                            <TouchableOpacity onPress={() => setBleModalVisible(false)}>
                                <Text style={styles.modalCloseText}>×</Text>
                            </TouchableOpacity>
                        </View>

                        <View style={styles.modalBody}>
                            {!bleScanning && bleDevices.length === 0 && (
                                <TouchableOpacity
                                    style={styles.scanButton}
                                    onPress={startBleScan}
                                >
                                    <Text style={styles.scanButtonText}>デバイスをスキャン</Text>
                                </TouchableOpacity>
                            )}

                            {bleScanning && (
                                <View style={styles.scanningContainer}>
                                    <ActivityIndicator size="small" color="#2196F3" />
                                    <Text style={styles.scanningText}>スキャン中...</Text>
                                </View>
                            )}

                            {bleDevices.map((device) => (
                                <TouchableOpacity
                                    key={device.id}
                                    style={styles.deviceItem}
                                    onPress={() => connectToDevice(device)}
                                    disabled={bleConnecting}
                                >
                                    <View>
                                        <Text style={styles.deviceName}>{device.name}</Text>
                                        <Text style={styles.deviceSignal}>信号強度: {device.rssi} dBm</Text>
                                    </View>
                                    {bleConnecting ? (
                                        <ActivityIndicator size="small" color="#2196F3" />
                                    ) : (
                                        <Text style={styles.connectText}>接続</Text>
                                    )}
                                </TouchableOpacity>
                            ))}

                            {bleDevices.length === 0 && !bleScanning && (
                                <Text style={styles.noDeviceText}>
                                    対応デバイスが見つかりません。{'\n'}
                                    デバイスの電源が入っていることを確認してください。
                                </Text>
                            )}
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
    loadingContainer: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
    },
    loadingText: {
        marginTop: 12,
        fontSize: 14,
        color: '#666',
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
    requiredMark: {
        color: '#F44336',
        fontSize: 12,
    },
    // Photo styles
    photoContainer: {
        alignItems: 'center',
    },
    photoPreview: {
        width: 150,
        height: 150,
        borderRadius: 75,
        marginBottom: 12,
    },
    photoButton: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: '#E3F2FD',
        borderRadius: 12,
        padding: 20,
        borderWidth: 2,
        borderColor: '#2196F3',
        borderStyle: 'dashed',
    },
    photoButtonIcon: {
        fontSize: 24,
        marginRight: 8,
    },
    photoButtonText: {
        fontSize: 16,
        fontWeight: '600',
        color: '#2196F3',
    },
    retakeButton: {
        backgroundColor: '#E0E0E0',
        paddingHorizontal: 20,
        paddingVertical: 8,
        borderRadius: 20,
    },
    retakeButtonText: {
        fontSize: 14,
        color: '#666',
    },
    // BLE styles
    bleContainer: {
        marginBottom: 16,
    },
    bleConnectButton: {
        backgroundColor: '#E8F5E9',
        borderRadius: 8,
        padding: 12,
        alignItems: 'center',
        borderWidth: 1,
        borderColor: '#4CAF50',
    },
    bleConnectButtonText: {
        fontSize: 14,
        fontWeight: '600',
        color: '#4CAF50',
    },
    bleConnectedInfo: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        backgroundColor: '#E8F5E9',
        borderRadius: 8,
        padding: 12,
    },
    bleConnectedText: {
        fontSize: 14,
        fontWeight: '600',
        color: '#4CAF50',
    },
    bleDisconnectText: {
        fontSize: 14,
        color: '#F44336',
    },
    bleHelperText: {
        color: '#4CAF50',
        fontSize: 12,
        marginTop: 8,
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
    alcoholInputBle: {
        backgroundColor: '#E8F5E9',
        borderColor: '#4CAF50',
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
        maxHeight: '70%',
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
        minHeight: 200,
    },
    scanButton: {
        backgroundColor: '#2196F3',
        borderRadius: 8,
        padding: 16,
        alignItems: 'center',
    },
    scanButtonText: {
        color: 'white',
        fontSize: 16,
        fontWeight: '600',
    },
    scanningContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 20,
    },
    scanningText: {
        marginLeft: 12,
        fontSize: 16,
        color: '#666',
    },
    deviceItem: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: 16,
        borderBottomWidth: 1,
        borderBottomColor: '#E0E0E0',
    },
    deviceName: {
        fontSize: 16,
        fontWeight: '600',
        color: '#333',
    },
    deviceSignal: {
        fontSize: 12,
        color: '#999',
        marginTop: 4,
    },
    connectText: {
        fontSize: 14,
        fontWeight: '600',
        color: '#2196F3',
    },
    noDeviceText: {
        textAlign: 'center',
        color: '#999',
        fontSize: 14,
        marginTop: 20,
        lineHeight: 22,
    },
});
