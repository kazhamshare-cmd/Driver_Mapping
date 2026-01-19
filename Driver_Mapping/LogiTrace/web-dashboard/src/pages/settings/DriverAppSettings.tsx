import { useState, useEffect } from 'react';
import {
    Box,
    Card,
    CardContent,
    Container,
    Typography,
    Switch,
    FormControlLabel,
    FormControl,
    FormLabel,
    RadioGroup,
    Radio,
    Alert,
    Button,
    Divider,
    Chip,
    Grid,
    Paper,
    CircularProgress,
    Tooltip,
    IconButton
} from '@mui/material';
import {
    Bluetooth as BluetoothIcon,
    CameraAlt as CameraIcon,
    LocationOn as LocationIcon,
    PhotoCamera as PhotoCameraIcon,
    Speed as SpeedIcon,
    Save as SaveIcon,
    Info as InfoIcon,
    Lock as LockIcon
} from '@mui/icons-material';

type AlcoholCheckMode = 'manual' | 'ble' | 'both';
type IdentityVerificationMode = 'none' | 'photo' | 'face_recognition';
type LocationDisplayMode = 'coordinates' | 'address';

interface DriverAppSettings {
    alcoholCheckMode: AlcoholCheckMode;
    identityVerificationMode: IdentityVerificationMode;
    requirePhotoOnTenko: boolean;
    locationDisplayMode: LocationDisplayMode;
    enableAddressLookup: boolean;
    enableInspectionPhotos: boolean;
    requirePhotoOnFailure: boolean;
    gpsUpdateInterval: number;
    gpsDistanceThreshold: number;
    enableContinuousDrivingAlert: boolean;
    continuousDrivingAlertMinutes: number;
    enableRestPeriodAlert: boolean;
}

interface PlanFeatures {
    bleAlcoholChecker: boolean;
    photoCapture: boolean;
    faceRecognition: boolean;
    addressLookup: boolean;
    inspectionPhotos: boolean;
}

const PLAN_FEATURES: Record<string, PlanFeatures> = {
    starter: {
        bleAlcoholChecker: false,
        photoCapture: false,
        faceRecognition: false,
        addressLookup: false,
        inspectionPhotos: false,
    },
    standard: {
        bleAlcoholChecker: true,
        photoCapture: true,
        faceRecognition: false,
        addressLookup: true,
        inspectionPhotos: true,
    },
    pro: {
        bleAlcoholChecker: true,
        photoCapture: true,
        faceRecognition: true,
        addressLookup: true,
        inspectionPhotos: true,
    },
};

const DEFAULT_SETTINGS: DriverAppSettings = {
    alcoholCheckMode: 'manual',
    identityVerificationMode: 'none',
    requirePhotoOnTenko: false,
    locationDisplayMode: 'coordinates',
    enableAddressLookup: false,
    enableInspectionPhotos: false,
    requirePhotoOnFailure: false,
    gpsUpdateInterval: 15000,
    gpsDistanceThreshold: 10,
    enableContinuousDrivingAlert: true,
    continuousDrivingAlertMinutes: 210,
    enableRestPeriodAlert: true,
};

export default function DriverAppSettings() {
    const [settings, setSettings] = useState<DriverAppSettings>(DEFAULT_SETTINGS);
    const [planFeatures, setPlanFeatures] = useState<PlanFeatures>(PLAN_FEATURES.starter);
    const [currentPlan, setCurrentPlan] = useState<string>('starter');
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');

    const user = JSON.parse(localStorage.getItem('user') || '{}');

    useEffect(() => {
        fetchSettings();
    }, []);

    const fetchSettings = async () => {
        try {
            const response = await fetch('/api/driver-app/settings', {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (response.ok) {
                const data = await response.json();
                setSettings({ ...DEFAULT_SETTINGS, ...data.settings });
                setCurrentPlan(data.plan || 'starter');
                setPlanFeatures(PLAN_FEATURES[data.plan] || PLAN_FEATURES.starter);
            }
        } catch (err) {
            setError('設定の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const handleSave = async () => {
        setSaving(true);
        setError('');
        setSuccess('');

        try {
            const response = await fetch('/api/driver-app/settings', {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify(settings)
            });

            if (!response.ok) {
                throw new Error('設定の保存に失敗しました');
            }

            setSuccess('設定を保存しました');
        } catch (err) {
            setError(err instanceof Error ? err.message : '設定の保存に失敗しました');
        } finally {
            setSaving(false);
        }
    };

    const isFeatureAvailable = (feature: keyof PlanFeatures): boolean => {
        return planFeatures[feature];
    };

    const FeatureLock = ({ feature }: { feature: keyof PlanFeatures }) => {
        if (isFeatureAvailable(feature)) return null;
        return (
            <Tooltip title="この機能はスタンダードプラン以上でご利用いただけます">
                <IconButton size="small" sx={{ ml: 1 }}>
                    <LockIcon fontSize="small" color="disabled" />
                </IconButton>
            </Tooltip>
        );
    };

    if (loading) {
        return (
            <Container maxWidth="lg" sx={{ py: 4 }}>
                <Box display="flex" justifyContent="center" alignItems="center" minHeight={400}>
                    <CircularProgress />
                </Box>
            </Container>
        );
    }

    return (
        <Container maxWidth="lg" sx={{ py: 4 }}>
            <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
                <Box>
                    <Typography variant="h4" fontWeight="bold">
                        ドライバーアプリ設定
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        モバイルアプリのオプション機能を設定します
                    </Typography>
                </Box>
                <Chip
                    label={currentPlan === 'pro' ? 'プロプラン' : currentPlan === 'standard' ? 'スタンダードプラン' : 'スタータープラン'}
                    color={currentPlan === 'pro' ? 'secondary' : currentPlan === 'standard' ? 'primary' : 'default'}
                />
            </Box>

            {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
            {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

            <Grid container spacing={3}>
                {/* アルコールチェック設定 */}
                <Grid size={{ xs: 12, md: 6 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" mb={2}>
                                <BluetoothIcon color="primary" sx={{ mr: 1 }} />
                                <Typography variant="h6">アルコールチェック</Typography>
                                <FeatureLock feature="bleAlcoholChecker" />
                            </Box>
                            <FormControl component="fieldset" fullWidth>
                                <RadioGroup
                                    value={settings.alcoholCheckMode}
                                    onChange={(e) => setSettings(s => ({
                                        ...s,
                                        alcoholCheckMode: e.target.value as AlcoholCheckMode
                                    }))}
                                >
                                    <FormControlLabel
                                        value="manual"
                                        control={<Radio />}
                                        label="手入力のみ（標準）"
                                    />
                                    <FormControlLabel
                                        value="ble"
                                        control={<Radio />}
                                        label="BLE機器連携のみ"
                                        disabled={!isFeatureAvailable('bleAlcoholChecker')}
                                    />
                                    <FormControlLabel
                                        value="both"
                                        control={<Radio />}
                                        label="両方（機器優先、手入力可）"
                                        disabled={!isFeatureAvailable('bleAlcoholChecker')}
                                    />
                                </RadioGroup>
                            </FormControl>
                            {isFeatureAvailable('bleAlcoholChecker') && (
                                <Alert severity="info" sx={{ mt: 2 }}>
                                    対応機器: タニタ EA-100/FC-1000, 東海電子 ALC-Mobile, JVCケンウッド CAX-AD100
                                </Alert>
                            )}
                        </CardContent>
                    </Card>
                </Grid>

                {/* 本人確認設定 */}
                <Grid size={{ xs: 12, md: 6 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" mb={2}>
                                <CameraIcon color="primary" sx={{ mr: 1 }} />
                                <Typography variant="h6">点呼時の本人確認</Typography>
                                <FeatureLock feature="photoCapture" />
                            </Box>
                            <FormControl component="fieldset" fullWidth>
                                <RadioGroup
                                    value={settings.identityVerificationMode}
                                    onChange={(e) => setSettings(s => ({
                                        ...s,
                                        identityVerificationMode: e.target.value as IdentityVerificationMode
                                    }))}
                                >
                                    <FormControlLabel
                                        value="none"
                                        control={<Radio />}
                                        label="なし（標準）"
                                    />
                                    <FormControlLabel
                                        value="photo"
                                        control={<Radio />}
                                        label="顔写真撮影"
                                        disabled={!isFeatureAvailable('photoCapture')}
                                    />
                                    <FormControlLabel
                                        value="face_recognition"
                                        control={<Radio />}
                                        label="顔認証（AI照合）"
                                        disabled={!isFeatureAvailable('faceRecognition')}
                                    />
                                </RadioGroup>
                            </FormControl>
                            {settings.identityVerificationMode !== 'none' && isFeatureAvailable('photoCapture') && (
                                <Box mt={2}>
                                    <FormControlLabel
                                        control={
                                            <Switch
                                                checked={settings.requirePhotoOnTenko}
                                                onChange={(e) => setSettings(s => ({
                                                    ...s,
                                                    requirePhotoOnTenko: e.target.checked
                                                }))}
                                            />
                                        }
                                        label="点呼時の写真撮影を必須にする"
                                    />
                                </Box>
                            )}
                        </CardContent>
                    </Card>
                </Grid>

                {/* 位置情報設定 */}
                <Grid size={{ xs: 12, md: 6 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" mb={2}>
                                <LocationIcon color="primary" sx={{ mr: 1 }} />
                                <Typography variant="h6">位置情報の表示</Typography>
                                <FeatureLock feature="addressLookup" />
                            </Box>
                            <FormControl component="fieldset" fullWidth>
                                <RadioGroup
                                    value={settings.locationDisplayMode}
                                    onChange={(e) => setSettings(s => ({
                                        ...s,
                                        locationDisplayMode: e.target.value as LocationDisplayMode
                                    }))}
                                >
                                    <FormControlLabel
                                        value="coordinates"
                                        control={<Radio />}
                                        label="緯度経度のみ（標準）"
                                    />
                                    <FormControlLabel
                                        value="address"
                                        control={<Radio />}
                                        label="住所自動取得（API利用）"
                                        disabled={!isFeatureAvailable('addressLookup')}
                                    />
                                </RadioGroup>
                            </FormControl>
                            {settings.locationDisplayMode === 'address' && isFeatureAvailable('addressLookup') && (
                                <Box mt={2}>
                                    <FormControlLabel
                                        control={
                                            <Switch
                                                checked={settings.enableAddressLookup}
                                                onChange={(e) => setSettings(s => ({
                                                    ...s,
                                                    enableAddressLookup: e.target.checked
                                                }))}
                                            />
                                        }
                                        label="住所自動取得を有効にする"
                                    />
                                </Box>
                            )}
                        </CardContent>
                    </Card>
                </Grid>

                {/* 点検記録設定 */}
                <Grid size={{ xs: 12, md: 6 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" mb={2}>
                                <PhotoCameraIcon color="primary" sx={{ mr: 1 }} />
                                <Typography variant="h6">点検記録</Typography>
                                <FeatureLock feature="inspectionPhotos" />
                            </Box>
                            <FormControlLabel
                                control={
                                    <Switch
                                        checked={settings.enableInspectionPhotos}
                                        onChange={(e) => setSettings(s => ({
                                            ...s,
                                            enableInspectionPhotos: e.target.checked
                                        }))}
                                        disabled={!isFeatureAvailable('inspectionPhotos')}
                                    />
                                }
                                label="点検時の写真添付を許可"
                            />
                            {settings.enableInspectionPhotos && isFeatureAvailable('inspectionPhotos') && (
                                <Box mt={2}>
                                    <FormControlLabel
                                        control={
                                            <Switch
                                                checked={settings.requirePhotoOnFailure}
                                                onChange={(e) => setSettings(s => ({
                                                    ...s,
                                                    requirePhotoOnFailure: e.target.checked
                                                }))}
                                            />
                                        }
                                        label="不合格項目は写真必須"
                                    />
                                </Box>
                            )}
                        </CardContent>
                    </Card>
                </Grid>

                {/* GPS設定 */}
                <Grid size={{ xs: 12 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" mb={2}>
                                <SpeedIcon color="primary" sx={{ mr: 1 }} />
                                <Typography variant="h6">GPS・アラート設定</Typography>
                            </Box>
                            <Grid container spacing={3}>
                                <Grid size={{ xs: 12, md: 4 }}>
                                    <Paper variant="outlined" sx={{ p: 2 }}>
                                        <Typography variant="subtitle2" color="text.secondary">
                                            GPS更新間隔
                                        </Typography>
                                        <Typography variant="h5" fontWeight="bold">
                                            {settings.gpsUpdateInterval / 1000}秒
                                        </Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            バッテリー消費を抑えつつ十分な精度を確保
                                        </Typography>
                                    </Paper>
                                </Grid>
                                <Grid size={{ xs: 12, md: 4 }}>
                                    <Paper variant="outlined" sx={{ p: 2 }}>
                                        <FormControlLabel
                                            control={
                                                <Switch
                                                    checked={settings.enableContinuousDrivingAlert}
                                                    onChange={(e) => setSettings(s => ({
                                                        ...s,
                                                        enableContinuousDrivingAlert: e.target.checked
                                                    }))}
                                                />
                                            }
                                            label="連続運転アラート"
                                        />
                                        <Typography variant="caption" color="text.secondary" display="block">
                                            4時間連続運転の30分前に警告
                                        </Typography>
                                    </Paper>
                                </Grid>
                                <Grid size={{ xs: 12, md: 4 }}>
                                    <Paper variant="outlined" sx={{ p: 2 }}>
                                        <FormControlLabel
                                            control={
                                                <Switch
                                                    checked={settings.enableRestPeriodAlert}
                                                    onChange={(e) => setSettings(s => ({
                                                        ...s,
                                                        enableRestPeriodAlert: e.target.checked
                                                    }))}
                                                />
                                            }
                                            label="休息期間アラート"
                                        />
                                        <Typography variant="caption" color="text.secondary" display="block">
                                            休息期間不足時に警告
                                        </Typography>
                                    </Paper>
                                </Grid>
                            </Grid>
                        </CardContent>
                    </Card>
                </Grid>

                {/* プラン別機能一覧 */}
                <Grid size={{ xs: 12 }}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" mb={2}>
                                プラン別機能一覧
                            </Typography>
                            <Paper variant="outlined">
                                <Box sx={{ overflowX: 'auto' }}>
                                    <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                                        <thead>
                                            <tr style={{ backgroundColor: '#f5f5f5' }}>
                                                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #ddd' }}>機能</th>
                                                <th style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #ddd' }}>スターター<br/>(¥7,000)</th>
                                                <th style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #ddd' }}>スタンダード<br/>(¥9,000)</th>
                                                <th style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #ddd' }}>プロ<br/>(¥12,000)</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <tr>
                                                <td style={{ padding: '12px', borderBottom: '1px solid #eee' }}>手入力アルコールチェック</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: 'green' }}>○</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: 'green' }}>○</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: 'green' }}>○</td>
                                            </tr>
                                            <tr>
                                                <td style={{ padding: '12px', borderBottom: '1px solid #eee' }}>BLEアルコールチェッカー連携</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: '#ccc' }}>—</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: 'green' }}>○</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: 'green' }}>○</td>
                                            </tr>
                                            <tr>
                                                <td style={{ padding: '12px', borderBottom: '1px solid #eee' }}>顔写真撮影</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: '#ccc' }}>—</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: 'green' }}>○</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: 'green' }}>○</td>
                                            </tr>
                                            <tr>
                                                <td style={{ padding: '12px', borderBottom: '1px solid #eee' }}>顔認証（AI）</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: '#ccc' }}>—</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: '#ccc' }}>—</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: 'green' }}>○</td>
                                            </tr>
                                            <tr>
                                                <td style={{ padding: '12px', borderBottom: '1px solid #eee' }}>住所自動取得</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: '#ccc' }}>—</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: 'green' }}>○</td>
                                                <td style={{ padding: '12px', textAlign: 'center', borderBottom: '1px solid #eee', color: 'green' }}>○</td>
                                            </tr>
                                            <tr>
                                                <td style={{ padding: '12px' }}>点検写真添付</td>
                                                <td style={{ padding: '12px', textAlign: 'center', color: '#ccc' }}>—</td>
                                                <td style={{ padding: '12px', textAlign: 'center', color: 'green' }}>○</td>
                                                <td style={{ padding: '12px', textAlign: 'center', color: 'green' }}>○</td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </Box>
                            </Paper>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            {/* 保存ボタン */}
            <Box display="flex" justifyContent="flex-end" mt={3}>
                <Button
                    variant="contained"
                    size="large"
                    startIcon={saving ? <CircularProgress size={20} color="inherit" /> : <SaveIcon />}
                    onClick={handleSave}
                    disabled={saving}
                >
                    {saving ? '保存中...' : '設定を保存'}
                </Button>
            </Box>
        </Container>
    );
}
