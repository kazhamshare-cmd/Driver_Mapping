import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box, Button, Card, CardContent, Container, FormControl, FormControlLabel,
    Grid, InputLabel, MenuItem, Select, Switch, TextField, Typography, Alert
} from '@mui/material';
import { Save as SaveIcon, ArrowBack as BackIcon } from '@mui/icons-material';

interface Driver {
    id: number;
    driver_id: number;
    full_name: string;
    employee_number: string;
}

export default function AccidentForm() {
    const navigate = useNavigate();
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [drivers, setDrivers] = useState<Driver[]>([]);

    const [formData, setFormData] = useState({
        driver_id: '',
        record_type: 'accident',
        incident_date: new Date().toISOString().split('T')[0],
        incident_time: '',
        location: '',
        description: '',
        severity: 'minor',
        is_at_fault: false,
        // 違反
        violation_type: '',
        points_deducted: '',
        fine_amount: '',
        // 事故
        damage_amount: '',
        injury_count: '',
        police_report_number: '',
        // 対応
        corrective_action: '',
        follow_up_training_required: false
    });

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchDrivers();
    }, []);

    const fetchDrivers = async () => {
        try {
            const response = await fetch(`/api/driver-registry?companyId=${companyId}&status=active`, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (response.ok) setDrivers(await response.json());
        } catch (err) {
            console.error('Failed to fetch drivers');
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setSaving(true);
        setError('');

        try {
            const response = await fetch('/api/accidents', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    company_id: companyId,
                    ...formData,
                    points_deducted: formData.points_deducted ? parseInt(formData.points_deducted) : null,
                    fine_amount: formData.fine_amount ? parseInt(formData.fine_amount) : null,
                    damage_amount: formData.damage_amount ? parseInt(formData.damage_amount) : null,
                    injury_count: formData.injury_count ? parseInt(formData.injury_count) : null
                })
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || 'Failed to save');
            }

            setSuccess('登録しました');
            setTimeout(() => navigate('/accidents'), 1500);
        } catch (err: any) {
            setError(err.message);
        } finally {
            setSaving(false);
        }
    };

    const handleChange = (field: string) => (e: any) => {
        const value = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
        setFormData({ ...formData, [field]: value });
    };

    return (
        <Container maxWidth="md">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                    <Button startIcon={<BackIcon />} onClick={() => navigate('/accidents')} sx={{ mr: 2 }}>戻る</Button>
                    <Typography variant="h4">事故・違反記録登録</Typography>
                </Box>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

                <form onSubmit={handleSubmit}>
                    <Card sx={{ mb: 3 }}>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>基本情報</Typography>
                            <Grid container spacing={2}>
                                <Grid size={{ xs: 12 }}>
                                    <FormControl fullWidth required>
                                        <InputLabel>ドライバー</InputLabel>
                                        <Select value={formData.driver_id} label="ドライバー" onChange={handleChange('driver_id')}>
                                            {drivers.map((d) => (
                                                <MenuItem key={d.driver_id} value={d.driver_id}>{d.full_name}</MenuItem>
                                            ))}
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <FormControl fullWidth required>
                                        <InputLabel>種別</InputLabel>
                                        <Select value={formData.record_type} label="種別" onChange={handleChange('record_type')}>
                                            <MenuItem value="accident">事故</MenuItem>
                                            <MenuItem value="violation">違反</MenuItem>
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="発生日" type="date" fullWidth required InputLabelProps={{ shrink: true }}
                                        value={formData.incident_date} onChange={handleChange('incident_date')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="発生時刻" type="time" fullWidth InputLabelProps={{ shrink: true }}
                                        value={formData.incident_time} onChange={handleChange('incident_time')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="発生場所" fullWidth value={formData.location} onChange={handleChange('location')} />
                                </Grid>
                                <Grid size={{ xs: 12 }}>
                                    <TextField label="内容" fullWidth required multiline rows={3}
                                        value={formData.description} onChange={handleChange('description')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <FormControl fullWidth>
                                        <InputLabel>重大度</InputLabel>
                                        <Select value={formData.severity} label="重大度" onChange={handleChange('severity')}>
                                            <MenuItem value="minor">軽微</MenuItem>
                                            <MenuItem value="moderate">中程度</MenuItem>
                                            <MenuItem value="severe">重大</MenuItem>
                                            <MenuItem value="fatal">死亡</MenuItem>
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <FormControlLabel
                                        control={<Switch checked={formData.is_at_fault} onChange={handleChange('is_at_fault')} />}
                                        label="自社過失あり"
                                    />
                                </Grid>
                            </Grid>
                        </CardContent>
                    </Card>

                    {/* 違反の場合 */}
                    {formData.record_type === 'violation' && (
                        <Card sx={{ mb: 3 }}>
                            <CardContent>
                                <Typography variant="h6" gutterBottom>違反詳細</Typography>
                                <Grid container spacing={2}>
                                    <Grid size={{ xs: 12, sm: 6 }}>
                                        <TextField label="違反種別" fullWidth value={formData.violation_type} onChange={handleChange('violation_type')}
                                            placeholder="例: 速度超過、一時停止違反" />
                                    </Grid>
                                    <Grid size={{ xs: 12, sm: 6 }}>
                                        <TextField label="減点" type="number" fullWidth value={formData.points_deducted} onChange={handleChange('points_deducted')} />
                                    </Grid>
                                    <Grid size={{ xs: 12, sm: 6 }}>
                                        <TextField label="反則金（円）" type="number" fullWidth value={formData.fine_amount} onChange={handleChange('fine_amount')} />
                                    </Grid>
                                </Grid>
                            </CardContent>
                        </Card>
                    )}

                    {/* 事故の場合 */}
                    {formData.record_type === 'accident' && (
                        <Card sx={{ mb: 3 }}>
                            <CardContent>
                                <Typography variant="h6" gutterBottom>事故詳細</Typography>
                                <Grid container spacing={2}>
                                    <Grid size={{ xs: 12, sm: 6 }}>
                                        <TextField label="損害額（円）" type="number" fullWidth value={formData.damage_amount} onChange={handleChange('damage_amount')} />
                                    </Grid>
                                    <Grid size={{ xs: 12, sm: 6 }}>
                                        <TextField label="負傷者数" type="number" fullWidth value={formData.injury_count} onChange={handleChange('injury_count')} />
                                    </Grid>
                                    <Grid size={{ xs: 12, sm: 6 }}>
                                        <TextField label="警察届出番号" fullWidth value={formData.police_report_number} onChange={handleChange('police_report_number')} />
                                    </Grid>
                                </Grid>
                            </CardContent>
                        </Card>
                    )}

                    <Card sx={{ mb: 3 }}>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>対応</Typography>
                            <Grid container spacing={2}>
                                <Grid size={{ xs: 12 }}>
                                    <TextField label="是正措置" fullWidth multiline rows={2}
                                        value={formData.corrective_action} onChange={handleChange('corrective_action')} />
                                </Grid>
                                <Grid size={{ xs: 12 }}>
                                    <FormControlLabel
                                        control={<Switch checked={formData.follow_up_training_required} onChange={handleChange('follow_up_training_required')} />}
                                        label="フォローアップ研修が必要"
                                    />
                                </Grid>
                            </Grid>
                        </CardContent>
                    </Card>

                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2 }}>
                        <Button variant="outlined" onClick={() => navigate('/accidents')}>キャンセル</Button>
                        <Button type="submit" variant="contained" startIcon={<SaveIcon />} disabled={saving}>
                            {saving ? '保存中...' : '保存'}
                        </Button>
                    </Box>
                </form>
            </Box>
        </Container>
    );
}
