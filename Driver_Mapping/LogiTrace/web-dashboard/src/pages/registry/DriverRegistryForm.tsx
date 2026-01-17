import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
    Box,
    Button,
    Card,
    CardContent,
    Container,
    FormControl,
    FormControlLabel,
    Grid,
    InputLabel,
    MenuItem,
    Select,
    Switch,
    TextField,
    Typography,
    CircularProgress,
    Alert,
    Divider
} from '@mui/material';
import { Save as SaveIcon, ArrowBack as BackIcon } from '@mui/icons-material';

interface Driver {
    id: number;
    name: string;
    email: string;
    employee_number: string;
}

interface FormData {
    driver_id: number | '';
    full_name: string;
    full_name_kana: string;
    birth_date: string;
    address: string;
    phone: string;
    emergency_contact: string;
    emergency_phone: string;
    hire_date: string;
    termination_date: string;
    license_number: string;
    license_type: string;
    license_expiry_date: string;
    license_conditions: string;
    hazmat_license: boolean;
    hazmat_expiry_date: string;
    forklift_license: boolean;
    second_class_license: boolean;
    status: string;
    notes: string;
}

export default function DriverRegistryForm() {
    const navigate = useNavigate();
    const { id } = useParams<{ id: string }>();
    const isEdit = Boolean(id);

    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [drivers, setDrivers] = useState<Driver[]>([]);

    const [formData, setFormData] = useState<FormData>({
        driver_id: '',
        full_name: '',
        full_name_kana: '',
        birth_date: '',
        address: '',
        phone: '',
        emergency_contact: '',
        emergency_phone: '',
        hire_date: '',
        termination_date: '',
        license_number: '',
        license_type: 'ordinary',
        license_expiry_date: '',
        license_conditions: '',
        hazmat_license: false,
        hazmat_expiry_date: '',
        forklift_license: false,
        second_class_license: false,
        status: 'active',
        notes: ''
    });

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchDrivers();
        if (isEdit) {
            fetchRegistry();
        }
    }, [id]);

    const fetchDrivers = async () => {
        try {
            const response = await fetch(`/api/drivers?companyId=${companyId}`, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (response.ok) {
                const data = await response.json();
                setDrivers(data);
            }
        } catch (err) {
            console.error('Failed to fetch drivers');
        }
    };

    const fetchRegistry = async () => {
        setLoading(true);
        try {
            const response = await fetch(`/api/driver-registry/${id}`, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (!response.ok) throw new Error('Failed to fetch registry');
            const data = await response.json();
            setFormData({
                driver_id: data.driver_id,
                full_name: data.full_name || '',
                full_name_kana: data.full_name_kana || '',
                birth_date: data.birth_date?.split('T')[0] || '',
                address: data.address || '',
                phone: data.phone || '',
                emergency_contact: data.emergency_contact || '',
                emergency_phone: data.emergency_phone || '',
                hire_date: data.hire_date?.split('T')[0] || '',
                termination_date: data.termination_date?.split('T')[0] || '',
                license_number: data.license_number || '',
                license_type: data.license_type || 'ordinary',
                license_expiry_date: data.license_expiry_date?.split('T')[0] || '',
                license_conditions: data.license_conditions || '',
                hazmat_license: data.hazmat_license || false,
                hazmat_expiry_date: data.hazmat_expiry_date?.split('T')[0] || '',
                forklift_license: data.forklift_license || false,
                second_class_license: data.second_class_license || false,
                status: data.status || 'active',
                notes: data.notes || ''
            });
        } catch (err) {
            setError('運転者台帳の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setSaving(true);
        setError('');

        try {
            const url = isEdit ? `/api/driver-registry/${id}` : '/api/driver-registry';
            const method = isEdit ? 'PUT' : 'POST';

            const response = await fetch(url, {
                method,
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    company_id: companyId,
                    ...formData,
                    termination_date: formData.termination_date || null,
                    hazmat_expiry_date: formData.hazmat_expiry_date || null
                })
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || 'Failed to save');
            }

            setSuccess(isEdit ? '更新しました' : '登録しました');
            setTimeout(() => navigate('/registry'), 1500);
        } catch (err: any) {
            setError(err.message);
        } finally {
            setSaving(false);
        }
    };

    const handleChange = (field: keyof FormData) => (e: any) => {
        const value = e.target.type === 'checkbox' ? e.target.checked : e.target.value;
        setFormData({ ...formData, [field]: value });
    };

    if (loading) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
                <CircularProgress />
            </Box>
        );
    }

    return (
        <Container maxWidth="md">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                    <Button startIcon={<BackIcon />} onClick={() => navigate('/registry')} sx={{ mr: 2 }}>
                        戻る
                    </Button>
                    <Typography variant="h4" component="h1">
                        {isEdit ? '運転者台帳編集' : '運転者台帳新規登録'}
                    </Typography>
                </Box>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

                <form onSubmit={handleSubmit}>
                    {/* 基本情報 */}
                    <Card sx={{ mb: 3 }}>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>基本情報</Typography>
                            <Grid container spacing={2}>
                                {!isEdit && (
                                    <Grid size={{ xs: 12 }}>
                                        <FormControl fullWidth required>
                                            <InputLabel>ドライバー</InputLabel>
                                            <Select
                                                value={formData.driver_id}
                                                label="ドライバー"
                                                onChange={handleChange('driver_id')}
                                            >
                                                {drivers.map((driver) => (
                                                    <MenuItem key={driver.id} value={driver.id}>
                                                        {driver.name} ({driver.email})
                                                    </MenuItem>
                                                ))}
                                            </Select>
                                        </FormControl>
                                    </Grid>
                                )}
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="氏名"
                                        fullWidth
                                        required
                                        value={formData.full_name}
                                        onChange={handleChange('full_name')}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="フリガナ"
                                        fullWidth
                                        value={formData.full_name_kana}
                                        onChange={handleChange('full_name_kana')}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="生年月日"
                                        type="date"
                                        fullWidth
                                        InputLabelProps={{ shrink: true }}
                                        value={formData.birth_date}
                                        onChange={handleChange('birth_date')}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="電話番号"
                                        fullWidth
                                        value={formData.phone}
                                        onChange={handleChange('phone')}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12 }}>
                                    <TextField
                                        label="住所"
                                        fullWidth
                                        multiline
                                        rows={2}
                                        value={formData.address}
                                        onChange={handleChange('address')}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="緊急連絡先（氏名）"
                                        fullWidth
                                        value={formData.emergency_contact}
                                        onChange={handleChange('emergency_contact')}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="緊急連絡先（電話番号）"
                                        fullWidth
                                        value={formData.emergency_phone}
                                        onChange={handleChange('emergency_phone')}
                                    />
                                </Grid>
                            </Grid>
                        </CardContent>
                    </Card>

                    {/* 雇用情報 */}
                    <Card sx={{ mb: 3 }}>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>雇用情報</Typography>
                            <Grid container spacing={2}>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="入社日"
                                        type="date"
                                        fullWidth
                                        required
                                        InputLabelProps={{ shrink: true }}
                                        value={formData.hire_date}
                                        onChange={handleChange('hire_date')}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="退職日"
                                        type="date"
                                        fullWidth
                                        InputLabelProps={{ shrink: true }}
                                        value={formData.termination_date}
                                        onChange={handleChange('termination_date')}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <FormControl fullWidth>
                                        <InputLabel>ステータス</InputLabel>
                                        <Select
                                            value={formData.status}
                                            label="ステータス"
                                            onChange={handleChange('status')}
                                        >
                                            <MenuItem value="active">在籍</MenuItem>
                                            <MenuItem value="inactive">退職</MenuItem>
                                            <MenuItem value="suspended">休止</MenuItem>
                                        </Select>
                                    </FormControl>
                                </Grid>
                            </Grid>
                        </CardContent>
                    </Card>

                    {/* 免許情報 */}
                    <Card sx={{ mb: 3 }}>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>免許情報</Typography>
                            <Grid container spacing={2}>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="免許証番号"
                                        fullWidth
                                        required
                                        value={formData.license_number}
                                        onChange={handleChange('license_number')}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <FormControl fullWidth required>
                                        <InputLabel>免許種類</InputLabel>
                                        <Select
                                            value={formData.license_type}
                                            label="免許種類"
                                            onChange={handleChange('license_type')}
                                        >
                                            <MenuItem value="ordinary">普通</MenuItem>
                                            <MenuItem value="medium">中型</MenuItem>
                                            <MenuItem value="large">大型</MenuItem>
                                            <MenuItem value="large_special">大型特殊</MenuItem>
                                            <MenuItem value="second_class_ordinary">普通二種</MenuItem>
                                            <MenuItem value="second_class_medium">中型二種</MenuItem>
                                            <MenuItem value="second_class_large">大型二種</MenuItem>
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="免許有効期限"
                                        type="date"
                                        fullWidth
                                        required
                                        InputLabelProps={{ shrink: true }}
                                        value={formData.license_expiry_date}
                                        onChange={handleChange('license_expiry_date')}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="免許条件等"
                                        fullWidth
                                        value={formData.license_conditions}
                                        onChange={handleChange('license_conditions')}
                                        placeholder="例: 眼鏡等"
                                    />
                                </Grid>
                            </Grid>

                            <Divider sx={{ my: 2 }} />
                            <Typography variant="subtitle2" gutterBottom>その他資格</Typography>
                            <Grid container spacing={2}>
                                <Grid size={{ xs: 12, sm: 4 }}>
                                    <FormControlLabel
                                        control={
                                            <Switch
                                                checked={formData.hazmat_license}
                                                onChange={handleChange('hazmat_license')}
                                            />
                                        }
                                        label="危険物取扱者"
                                    />
                                </Grid>
                                {formData.hazmat_license && (
                                    <Grid size={{ xs: 12, sm: 4 }}>
                                        <TextField
                                            label="危険物有効期限"
                                            type="date"
                                            fullWidth
                                            InputLabelProps={{ shrink: true }}
                                            value={formData.hazmat_expiry_date}
                                            onChange={handleChange('hazmat_expiry_date')}
                                        />
                                    </Grid>
                                )}
                                <Grid size={{ xs: 12, sm: 4 }}>
                                    <FormControlLabel
                                        control={
                                            <Switch
                                                checked={formData.forklift_license}
                                                onChange={handleChange('forklift_license')}
                                            />
                                        }
                                        label="フォークリフト運転技能"
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, sm: 4 }}>
                                    <FormControlLabel
                                        control={
                                            <Switch
                                                checked={formData.second_class_license}
                                                onChange={handleChange('second_class_license')}
                                            />
                                        }
                                        label="第二種免許"
                                    />
                                </Grid>
                            </Grid>
                        </CardContent>
                    </Card>

                    {/* 備考 */}
                    <Card sx={{ mb: 3 }}>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>備考</Typography>
                            <TextField
                                fullWidth
                                multiline
                                rows={4}
                                value={formData.notes}
                                onChange={handleChange('notes')}
                                placeholder="その他の情報を入力してください"
                            />
                        </CardContent>
                    </Card>

                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2 }}>
                        <Button variant="outlined" onClick={() => navigate('/registry')}>
                            キャンセル
                        </Button>
                        <Button
                            type="submit"
                            variant="contained"
                            startIcon={<SaveIcon />}
                            disabled={saving}
                        >
                            {saving ? '保存中...' : '保存'}
                        </Button>
                    </Box>
                </form>
            </Box>
        </Container>
    );
}
