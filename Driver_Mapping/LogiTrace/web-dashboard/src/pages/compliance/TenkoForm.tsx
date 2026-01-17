import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    Container,
    FormControl,
    FormControlLabel,
    FormLabel,
    Grid,
    InputLabel,
    MenuItem,
    Radio,
    RadioGroup,
    Select,
    Slider,
    TextField,
    Typography,
    CircularProgress,
} from '@mui/material';
import { Save as SaveIcon, ArrowBack as ArrowBackIcon } from '@mui/icons-material';

interface Driver {
    id: number;
    name: string;
    email: string;
}

export default function TenkoForm() {
    const navigate = useNavigate();
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [drivers, setDrivers] = useState<Driver[]>([]);

    // フォームデータ
    const [driverId, setDriverId] = useState<number | ''>('');
    const [tenkoType, setTenkoType] = useState<'pre' | 'post'>('pre');
    const [method, setMethod] = useState<string>('face_to_face');
    const [healthStatus, setHealthStatus] = useState<string>('good');
    const [healthNotes, setHealthNotes] = useState('');
    const [alcoholLevel, setAlcoholLevel] = useState<string>('0.000');
    const [alcoholDeviceId, setAlcoholDeviceId] = useState('');
    const [fatigueLevel, setFatigueLevel] = useState<number>(1);
    const [sleepHours, setSleepHours] = useState<string>('');
    const [sleepSufficient, setSleepSufficient] = useState<boolean>(true);
    const [notes, setNotes] = useState('');

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchDrivers();
    }, []);

    const fetchDrivers = async () => {
        try {
            const response = await fetch(`/api/drivers?companyId=${companyId}`, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (response.ok) {
                const data = await response.json();
                setDrivers(data.filter((d: any) => d.status === 'active'));
            }
        } catch (err) {
            console.error('Error fetching drivers:', err);
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setSuccess('');
        setLoading(true);

        try {
            const response = await fetch('/api/tenko', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    company_id: companyId,
                    driver_id: driverId,
                    tenko_type: tenkoType,
                    method,
                    health_status: healthStatus,
                    health_notes: healthNotes || null,
                    alcohol_level: parseFloat(alcoholLevel),
                    alcohol_device_id: alcoholDeviceId || null,
                    fatigue_level: fatigueLevel,
                    sleep_hours: sleepHours ? parseFloat(sleepHours) : null,
                    sleep_sufficient: sleepSufficient,
                    inspector_id: user.id || 1,
                    notes: notes || null
                })
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || '点呼記録の保存に失敗しました');
            }

            setSuccess('点呼記録を保存しました');
            setTimeout(() => navigate('/compliance/tenko'), 1500);
        } catch (err: any) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    const fatigueMarks = [
        { value: 1, label: '1: 元気' },
        { value: 2, label: '2' },
        { value: 3, label: '3: 普通' },
        { value: 4, label: '4' },
        { value: 5, label: '5: 疲労' },
    ];

    return (
        <Container maxWidth="md">
            <Box sx={{ my: 4 }}>
                <Button
                    startIcon={<ArrowBackIcon />}
                    onClick={() => navigate('/compliance/tenko')}
                    sx={{ mb: 2 }}
                >
                    一覧に戻る
                </Button>

                <Typography variant="h4" component="h1" gutterBottom>
                    点呼記録入力
                </Typography>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

                <Card>
                    <CardContent>
                        <Box component="form" onSubmit={handleSubmit}>
                            <Grid container spacing={3}>
                                {/* ドライバー選択 */}
                                <Grid size={12}>
                                    <FormControl fullWidth required>
                                        <InputLabel>ドライバー</InputLabel>
                                        <Select
                                            value={driverId}
                                            label="ドライバー"
                                            onChange={(e) => setDriverId(e.target.value as number)}
                                        >
                                            {drivers.map((driver) => (
                                                <MenuItem key={driver.id} value={driver.id}>
                                                    {driver.name} ({driver.email})
                                                </MenuItem>
                                            ))}
                                        </Select>
                                    </FormControl>
                                </Grid>

                                {/* 点呼種別 */}
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <FormControl component="fieldset">
                                        <FormLabel component="legend">点呼種別</FormLabel>
                                        <RadioGroup
                                            row
                                            value={tenkoType}
                                            onChange={(e) => setTenkoType(e.target.value as 'pre' | 'post')}
                                        >
                                            <FormControlLabel value="pre" control={<Radio />} label="乗務前" />
                                            <FormControlLabel value="post" control={<Radio />} label="乗務後" />
                                        </RadioGroup>
                                    </FormControl>
                                </Grid>

                                {/* 点呼方法 */}
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <FormControl fullWidth>
                                        <InputLabel>点呼方法</InputLabel>
                                        <Select
                                            value={method}
                                            label="点呼方法"
                                            onChange={(e) => setMethod(e.target.value)}
                                        >
                                            <MenuItem value="face_to_face">対面</MenuItem>
                                            <MenuItem value="it_tenko">IT点呼</MenuItem>
                                            <MenuItem value="phone">電話</MenuItem>
                                        </Select>
                                    </FormControl>
                                </Grid>

                                {/* 健康状態 */}
                                <Grid size={12}>
                                    <FormControl component="fieldset">
                                        <FormLabel component="legend">健康状態</FormLabel>
                                        <RadioGroup
                                            row
                                            value={healthStatus}
                                            onChange={(e) => setHealthStatus(e.target.value)}
                                        >
                                            <FormControlLabel
                                                value="good"
                                                control={<Radio color="success" />}
                                                label="良好"
                                            />
                                            <FormControlLabel
                                                value="fair"
                                                control={<Radio color="warning" />}
                                                label="普通"
                                            />
                                            <FormControlLabel
                                                value="poor"
                                                control={<Radio color="error" />}
                                                label="不良"
                                            />
                                        </RadioGroup>
                                    </FormControl>
                                </Grid>

                                {healthStatus !== 'good' && (
                                    <Grid size={12}>
                                        <TextField
                                            label="健康状態の詳細"
                                            fullWidth
                                            multiline
                                            rows={2}
                                            value={healthNotes}
                                            onChange={(e) => setHealthNotes(e.target.value)}
                                        />
                                    </Grid>
                                )}

                                {/* アルコールチェック */}
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="アルコール濃度 (mg/L)"
                                        type="number"
                                        fullWidth
                                        required
                                        value={alcoholLevel}
                                        onChange={(e) => setAlcoholLevel(e.target.value)}
                                        inputProps={{ step: 0.001, min: 0 }}
                                        helperText="0.000 以外は不合格"
                                        error={parseFloat(alcoholLevel) > 0}
                                    />
                                </Grid>

                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="検知器ID（任意）"
                                        fullWidth
                                        value={alcoholDeviceId}
                                        onChange={(e) => setAlcoholDeviceId(e.target.value)}
                                    />
                                </Grid>

                                {/* 疲労度 */}
                                <Grid size={12}>
                                    <Typography gutterBottom>疲労度</Typography>
                                    <Slider
                                        value={fatigueLevel}
                                        onChange={(_, value) => setFatigueLevel(value as number)}
                                        step={1}
                                        marks={fatigueMarks}
                                        min={1}
                                        max={5}
                                        valueLabelDisplay="auto"
                                    />
                                </Grid>

                                {/* 睡眠時間（乗務前のみ） */}
                                {tenkoType === 'pre' && (
                                    <>
                                        <Grid size={{ xs: 12, sm: 6 }}>
                                            <TextField
                                                label="睡眠時間（時間）"
                                                type="number"
                                                fullWidth
                                                value={sleepHours}
                                                onChange={(e) => setSleepHours(e.target.value)}
                                                inputProps={{ step: 0.5, min: 0 }}
                                            />
                                        </Grid>
                                        <Grid size={{ xs: 12, sm: 6 }}>
                                            <FormControl component="fieldset">
                                                <FormLabel component="legend">睡眠は十分か</FormLabel>
                                                <RadioGroup
                                                    row
                                                    value={sleepSufficient ? 'yes' : 'no'}
                                                    onChange={(e) => setSleepSufficient(e.target.value === 'yes')}
                                                >
                                                    <FormControlLabel value="yes" control={<Radio />} label="はい" />
                                                    <FormControlLabel value="no" control={<Radio />} label="いいえ" />
                                                </RadioGroup>
                                            </FormControl>
                                        </Grid>
                                    </>
                                )}

                                {/* 備考 */}
                                <Grid size={12}>
                                    <TextField
                                        label="備考"
                                        fullWidth
                                        multiline
                                        rows={3}
                                        value={notes}
                                        onChange={(e) => setNotes(e.target.value)}
                                    />
                                </Grid>

                                {/* 送信ボタン */}
                                <Grid size={12}>
                                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2 }}>
                                        <Button
                                            variant="outlined"
                                            onClick={() => navigate('/compliance/tenko')}
                                        >
                                            キャンセル
                                        </Button>
                                        <Button
                                            type="submit"
                                            variant="contained"
                                            startIcon={loading ? <CircularProgress size={20} /> : <SaveIcon />}
                                            disabled={loading || !driverId}
                                        >
                                            保存
                                        </Button>
                                    </Box>
                                </Grid>
                            </Grid>
                        </Box>
                    </CardContent>
                </Card>
            </Box>
        </Container>
    );
}
