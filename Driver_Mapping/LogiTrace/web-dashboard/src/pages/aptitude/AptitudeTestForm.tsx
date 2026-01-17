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

export default function AptitudeTestForm() {
    const navigate = useNavigate();
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [drivers, setDrivers] = useState<Driver[]>([]);

    const [formData, setFormData] = useState({
        driver_id: '',
        test_type: 'initial',
        test_date: new Date().toISOString().split('T')[0],
        next_test_date: '',
        facility_name: '',
        overall_score: '',
        result_summary: '',
        recommendations: ''
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
            const response = await fetch('/api/aptitude-tests', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    company_id: companyId,
                    ...formData,
                    overall_score: formData.overall_score ? parseInt(formData.overall_score) : null
                })
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || 'Failed to save');
            }

            setSuccess('登録しました');
            setTimeout(() => navigate('/aptitude'), 1500);
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
                    <Button startIcon={<BackIcon />} onClick={() => navigate('/aptitude')} sx={{ mr: 2 }}>戻る</Button>
                    <Typography variant="h4">適性診断記録登録</Typography>
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
                                        <Select value={formData.test_type} label="種別" onChange={handleChange('test_type')}>
                                            <MenuItem value="initial">初任診断（新規採用時）</MenuItem>
                                            <MenuItem value="age_based">適齢診断（65歳以上）</MenuItem>
                                            <MenuItem value="specific">特定診断（事故後）</MenuItem>
                                            <MenuItem value="voluntary">一般診断（任意）</MenuItem>
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="受診日" type="date" fullWidth required InputLabelProps={{ shrink: true }}
                                        value={formData.test_date} onChange={handleChange('test_date')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="次回予定日" type="date" fullWidth InputLabelProps={{ shrink: true }}
                                        value={formData.next_test_date} onChange={handleChange('next_test_date')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="実施機関" fullWidth value={formData.facility_name} onChange={handleChange('facility_name')} />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField label="スコア" type="number" fullWidth value={formData.overall_score} onChange={handleChange('overall_score')} />
                                </Grid>
                                <Grid size={{ xs: 12 }}>
                                    <TextField label="結果概要" fullWidth multiline rows={2}
                                        value={formData.result_summary} onChange={handleChange('result_summary')} />
                                </Grid>
                                <Grid size={{ xs: 12 }}>
                                    <TextField label="指導事項" fullWidth multiline rows={2}
                                        value={formData.recommendations} onChange={handleChange('recommendations')} />
                                </Grid>
                            </Grid>
                        </CardContent>
                    </Card>

                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2 }}>
                        <Button variant="outlined" onClick={() => navigate('/aptitude')}>キャンセル</Button>
                        <Button type="submit" variant="contained" startIcon={<SaveIcon />} disabled={saving}>
                            {saving ? '保存中...' : '保存'}
                        </Button>
                    </Box>
                </form>
            </Box>
        </Container>
    );
}
