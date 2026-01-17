import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box, Button, Card, CardContent, Container, FormControl, Grid,
    InputLabel, MenuItem, Select, TextField, Typography, Alert
} from '@mui/material';
import { Save as SaveIcon, ArrowBack as BackIcon } from '@mui/icons-material';

interface Driver {
    id: number;
    driver_id: number;
    full_name: string;
    employee_number: string;
}

export default function TrainingForm() {
    const navigate = useNavigate();
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [drivers, setDrivers] = useState<Driver[]>([]);

    const [formData, setFormData] = useState({
        driver_id: '',
        training_type: 'safety_basic',
        training_name: '',
        training_date: new Date().toISOString().split('T')[0],
        duration_hours: '',
        instructor_name: '',
        location: '',
        content_summary: '',
        completion_status: 'completed'
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
            const response = await fetch('/api/training', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    company_id: companyId,
                    ...formData,
                    duration_hours: formData.duration_hours ? parseFloat(formData.duration_hours) : null
                })
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || 'Failed to save');
            }

            setSuccess('登録しました');
            setTimeout(() => navigate('/training'), 1500);
        } catch (err: any) {
            setError(err.message);
        } finally {
            setSaving(false);
        }
    };

    const handleChange = (field: string) => (e: any) => {
        setFormData({ ...formData, [field]: e.target.value });
    };

    return (
        <Container maxWidth="md">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                    <Button startIcon={<BackIcon />} onClick={() => navigate('/training')} sx={{ mr: 2 }}>戻る</Button>
                    <Typography variant="h4">教育研修記録登録</Typography>
                </Box>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

                <form onSubmit={handleSubmit}>
                    <Card sx={{ mb: 3 }}>
                        <CardContent>
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
                                        <Select value={formData.training_type} label="種別" onChange={handleChange('training_type')}>
                                            <MenuItem value="safety_basic">安全運転基礎</MenuItem>
                                            <MenuItem value="cargo_handling">貨物取扱い</MenuItem>
                                            <MenuItem value="passenger_service">旅客接遇</MenuItem>
                                            <MenuItem value="emergency_response">緊急時対応</MenuItem>
                                            <MenuItem value="eco_driving">エコドライブ</MenuItem>
                                            <MenuItem value="legal_update">法令研修</MenuItem>
                                            <MenuItem value="other">その他</MenuItem>
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="研修名" fullWidth required value={formData.training_name} onChange={handleChange('training_name')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="実施日" type="date" fullWidth required InputLabelProps={{ shrink: true }}
                                        value={formData.training_date} onChange={handleChange('training_date')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="時間（時間）" type="number" fullWidth inputProps={{ step: 0.5 }}
                                        value={formData.duration_hours} onChange={handleChange('duration_hours')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="講師名" fullWidth value={formData.instructor_name} onChange={handleChange('instructor_name')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="場所" fullWidth value={formData.location} onChange={handleChange('location')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <FormControl fullWidth>
                                        <InputLabel>状況</InputLabel>
                                        <Select value={formData.completion_status} label="状況" onChange={handleChange('completion_status')}>
                                            <MenuItem value="completed">完了</MenuItem>
                                            <MenuItem value="scheduled">予定</MenuItem>
                                            <MenuItem value="incomplete">未完了</MenuItem>
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid size={{ xs: 12 }}>
                                    <TextField label="内容概要" fullWidth multiline rows={3}
                                        value={formData.content_summary} onChange={handleChange('content_summary')} />
                                </Grid>
                            </Grid>
                        </CardContent>
                    </Card>

                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2 }}>
                        <Button variant="outlined" onClick={() => navigate('/training')}>キャンセル</Button>
                        <Button type="submit" variant="contained" startIcon={<SaveIcon />} disabled={saving}>
                            {saving ? '保存中...' : '保存'}
                        </Button>
                    </Box>
                </form>
            </Box>
        </Container>
    );
}
