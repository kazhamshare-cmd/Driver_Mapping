import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    Checkbox,
    Container,
    Divider,
    FormControl,
    FormControlLabel,
    Grid,
    InputLabel,
    MenuItem,
    Select,
    TextField,
    Typography,
    CircularProgress,
    Accordion,
    AccordionSummary,
    AccordionDetails,
    Chip,
} from '@mui/material';
import {
    Save as SaveIcon,
    ArrowBack as ArrowBackIcon,
    ExpandMore as ExpandMoreIcon,
    CheckCircle as CheckIcon,
    Cancel as FailIcon,
    PhotoCamera as PhotoIcon,
    Delete as DeleteIcon,
} from '@mui/icons-material';

interface Vehicle {
    id: number;
    vehicle_number: string;
    vehicle_type: string;
}

interface InspectionItem {
    id: number;
    item_key: string;
    item_name_ja: string;
    category: string;
    is_required: boolean;
}

interface ItemResult {
    result: 'pass' | 'fail';
    notes: string;
}

export default function InspectionForm() {
    const navigate = useNavigate();
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [vehicles, setVehicles] = useState<Vehicle[]>([]);
    const [inspectionItems, setInspectionItems] = useState<InspectionItem[]>([]);

    // フォームデータ
    const [vehicleId, setVehicleId] = useState<number | ''>('');
    const [odometerReading, setOdometerReading] = useState<string>('');
    const [itemResults, setItemResults] = useState<Record<string, ItemResult>>({});
    const [notes, setNotes] = useState('');
    const [issuesFound, setIssuesFound] = useState('');
    const [followUpRequired, setFollowUpRequired] = useState(false);
    const [photos, setPhotos] = useState<{ url: string; filename: string }[]>([]);
    const [uploadingPhoto, setUploadingPhoto] = useState(false);

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchVehicles();
        fetchInspectionItems();
    }, []);

    const fetchVehicles = async () => {
        try {
            // TODO: 会社別車両取得APIを実装後に置き換え
            // 仮のデータを設定
            setVehicles([
                { id: 1, vehicle_number: '品川 100 あ 1234', vehicle_type: '4t' },
                { id: 2, vehicle_number: '品川 100 あ 5678', vehicle_type: '10t' },
            ]);
        } catch (err) {
            console.error('Error fetching vehicles:', err);
        }
    };

    const fetchInspectionItems = async () => {
        try {
            const response = await fetch('/api/inspections/items', {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (response.ok) {
                const data = await response.json();
                setInspectionItems(data);
                // 初期値として全項目を「合格」に設定
                const initialResults: Record<string, ItemResult> = {};
                data.forEach((item: InspectionItem) => {
                    initialResults[item.item_key] = { result: 'pass', notes: '' };
                });
                setItemResults(initialResults);
            }
        } catch (err) {
            console.error('Error fetching inspection items:', err);
        }
    };

    const handleItemResultChange = (itemKey: string, result: 'pass' | 'fail') => {
        setItemResults(prev => ({
            ...prev,
            [itemKey]: { ...prev[itemKey], result }
        }));
    };

    const handlePhotoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const files = e.target.files;
        if (!files || files.length === 0) return;

        setUploadingPhoto(true);
        try {
            const formData = new FormData();
            formData.append('image', files[0]);

            const response = await fetch('/api/upload/image', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${user.token}`
                },
                body: formData
            });

            if (!response.ok) throw new Error('写真のアップロードに失敗しました');

            const data = await response.json();
            setPhotos(prev => [...prev, { url: data.url, filename: data.filename }]);
        } catch (err: any) {
            setError(err.message);
        } finally {
            setUploadingPhoto(false);
            // Reset file input
            e.target.value = '';
        }
    };

    const handleDeletePhoto = async (filename: string) => {
        try {
            await fetch(`/api/upload/image/${filename}`, {
                method: 'DELETE',
                headers: {
                    'Authorization': `Bearer ${user.token}`
                }
            });
            setPhotos(prev => prev.filter(p => p.filename !== filename));
        } catch (err: any) {
            setError('写真の削除に失敗しました');
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setSuccess('');
        setLoading(true);

        try {
            const response = await fetch('/api/inspections', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    company_id: companyId,
                    vehicle_id: vehicleId,
                    driver_id: user.id || 1,
                    inspection_items: itemResults,
                    odometer_reading: odometerReading ? parseInt(odometerReading) : null,
                    notes: notes || null,
                    issues_found: issuesFound || null,
                    follow_up_required: followUpRequired,
                    photos: photos.map(p => p.url)
                })
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || '点検記録の保存に失敗しました');
            }

            setSuccess('点検記録を保存しました');
            setTimeout(() => navigate('/compliance/inspections'), 1500);
        } catch (err: any) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    // カテゴリ別にアイテムをグループ化
    const groupedItems = inspectionItems.reduce((acc, item) => {
        if (!acc[item.category]) acc[item.category] = [];
        acc[item.category].push(item);
        return acc;
    }, {} as Record<string, InspectionItem[]>);

    const categoryLabels: Record<string, string> = {
        exterior: '外装',
        engine: 'エンジン',
        cabin: '車内',
        lights: '灯火類',
        safety: '安全装置'
    };

    // 不合格項目の数をカウント
    const failCount = Object.values(itemResults).filter(r => r.result === 'fail').length;

    return (
        <Container maxWidth="md">
            <Box sx={{ my: 4 }}>
                <Button
                    startIcon={<ArrowBackIcon />}
                    onClick={() => navigate('/compliance/inspections')}
                    sx={{ mb: 2 }}
                >
                    一覧に戻る
                </Button>

                <Typography variant="h4" component="h1" gutterBottom>
                    日常点検入力
                </Typography>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

                <Card>
                    <CardContent>
                        <Box component="form" onSubmit={handleSubmit}>
                            <Grid container spacing={3}>
                                {/* 車両選択 */}
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <FormControl fullWidth required>
                                        <InputLabel>車両</InputLabel>
                                        <Select
                                            value={vehicleId}
                                            label="車両"
                                            onChange={(e) => setVehicleId(e.target.value as number)}
                                        >
                                            {vehicles.map((vehicle) => (
                                                <MenuItem key={vehicle.id} value={vehicle.id}>
                                                    {vehicle.vehicle_number} ({vehicle.vehicle_type})
                                                </MenuItem>
                                            ))}
                                        </Select>
                                    </FormControl>
                                </Grid>

                                {/* 走行距離 */}
                                <Grid size={{ xs: 12, sm: 6 }}>
                                    <TextField
                                        label="走行距離計 (km)"
                                        type="number"
                                        fullWidth
                                        value={odometerReading}
                                        onChange={(e) => setOdometerReading(e.target.value)}
                                    />
                                </Grid>

                                {/* 現在の判定状況 */}
                                <Grid size={12}>
                                    <Box sx={{ display: 'flex', gap: 2, mb: 2 }}>
                                        <Chip
                                            icon={<CheckIcon />}
                                            label={`合格: ${Object.values(itemResults).filter(r => r.result === 'pass').length}`}
                                            color="success"
                                        />
                                        <Chip
                                            icon={<FailIcon />}
                                            label={`不合格: ${failCount}`}
                                            color={failCount > 0 ? 'error' : 'default'}
                                        />
                                    </Box>
                                </Grid>

                                {/* 点検項目 */}
                                <Grid size={12}>
                                    <Typography variant="h6" gutterBottom>
                                        点検項目
                                    </Typography>
                                    {Object.entries(groupedItems).map(([category, items]) => (
                                        <Accordion key={category} defaultExpanded>
                                            <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                                                <Typography fontWeight="bold">
                                                    {categoryLabels[category] || category}
                                                </Typography>
                                                <Box sx={{ ml: 2 }}>
                                                    <Chip
                                                        size="small"
                                                        label={`${items.filter(i => itemResults[i.item_key]?.result === 'pass').length}/${items.length}`}
                                                        color="primary"
                                                    />
                                                </Box>
                                            </AccordionSummary>
                                            <AccordionDetails>
                                                {items.map((item) => (
                                                    <Box
                                                        key={item.item_key}
                                                        sx={{
                                                            display: 'flex',
                                                            alignItems: 'center',
                                                            justifyContent: 'space-between',
                                                            py: 1,
                                                            borderBottom: '1px solid #eee'
                                                        }}
                                                    >
                                                        <Typography>
                                                            {item.item_name_ja}
                                                            {item.is_required && (
                                                                <Typography component="span" color="error" sx={{ ml: 0.5 }}>
                                                                    *
                                                                </Typography>
                                                            )}
                                                        </Typography>
                                                        <Box sx={{ display: 'flex', gap: 1 }}>
                                                            <Button
                                                                variant={itemResults[item.item_key]?.result === 'pass' ? 'contained' : 'outlined'}
                                                                color="success"
                                                                size="small"
                                                                onClick={() => handleItemResultChange(item.item_key, 'pass')}
                                                            >
                                                                合格
                                                            </Button>
                                                            <Button
                                                                variant={itemResults[item.item_key]?.result === 'fail' ? 'contained' : 'outlined'}
                                                                color="error"
                                                                size="small"
                                                                onClick={() => handleItemResultChange(item.item_key, 'fail')}
                                                            >
                                                                不合格
                                                            </Button>
                                                        </Box>
                                                    </Box>
                                                ))}
                                            </AccordionDetails>
                                        </Accordion>
                                    ))}
                                </Grid>

                                <Grid size={12}>
                                    <Divider sx={{ my: 2 }} />
                                </Grid>

                                {/* 問題点・備考 */}
                                <Grid size={12}>
                                    <TextField
                                        label="発見した問題点"
                                        fullWidth
                                        multiline
                                        rows={3}
                                        value={issuesFound}
                                        onChange={(e) => setIssuesFound(e.target.value)}
                                        error={failCount > 0 && !issuesFound}
                                        helperText={failCount > 0 && !issuesFound ? '不合格項目がある場合は問題点を記載してください' : ''}
                                    />
                                </Grid>

                                <Grid size={12}>
                                    <FormControlLabel
                                        control={
                                            <Checkbox
                                                checked={followUpRequired}
                                                onChange={(e) => setFollowUpRequired(e.target.checked)}
                                                color="warning"
                                            />
                                        }
                                        label="フォローアップが必要"
                                    />
                                </Grid>

                                <Grid size={12}>
                                    <TextField
                                        label="備考"
                                        fullWidth
                                        multiline
                                        rows={2}
                                        value={notes}
                                        onChange={(e) => setNotes(e.target.value)}
                                    />
                                </Grid>

                                {/* 写真添付 */}
                                <Grid size={12}>
                                    <Typography variant="subtitle1" gutterBottom>
                                        写真添付
                                    </Typography>
                                    <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 2, mb: 2 }}>
                                        {photos.map((photo) => (
                                            <Box
                                                key={photo.filename}
                                                sx={{
                                                    position: 'relative',
                                                    width: 120,
                                                    height: 120,
                                                    borderRadius: 1,
                                                    overflow: 'hidden',
                                                    border: '1px solid #ddd'
                                                }}
                                            >
                                                <img
                                                    src={photo.url}
                                                    alt="点検写真"
                                                    style={{
                                                        width: '100%',
                                                        height: '100%',
                                                        objectFit: 'cover'
                                                    }}
                                                />
                                                <Button
                                                    size="small"
                                                    color="error"
                                                    onClick={() => handleDeletePhoto(photo.filename)}
                                                    sx={{
                                                        position: 'absolute',
                                                        top: 2,
                                                        right: 2,
                                                        minWidth: 'auto',
                                                        p: 0.5,
                                                        bgcolor: 'rgba(255,255,255,0.8)',
                                                        '&:hover': { bgcolor: 'rgba(255,255,255,0.95)' }
                                                    }}
                                                >
                                                    <DeleteIcon fontSize="small" />
                                                </Button>
                                            </Box>
                                        ))}
                                        <Button
                                            component="label"
                                            variant="outlined"
                                            startIcon={uploadingPhoto ? <CircularProgress size={20} /> : <PhotoIcon />}
                                            disabled={uploadingPhoto || photos.length >= 5}
                                            sx={{
                                                width: 120,
                                                height: 120,
                                                flexDirection: 'column',
                                                gap: 1
                                            }}
                                        >
                                            {uploadingPhoto ? '...' : '写真追加'}
                                            <input
                                                type="file"
                                                accept="image/*"
                                                hidden
                                                onChange={handlePhotoUpload}
                                            />
                                        </Button>
                                    </Box>
                                    <Typography variant="caption" color="text.secondary">
                                        最大5枚まで添付可能（JPEG, PNG, GIF, WebP）
                                    </Typography>
                                </Grid>

                                {/* 送信ボタン */}
                                <Grid size={12}>
                                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2 }}>
                                        <Button
                                            variant="outlined"
                                            onClick={() => navigate('/compliance/inspections')}
                                        >
                                            キャンセル
                                        </Button>
                                        <Button
                                            type="submit"
                                            variant="contained"
                                            startIcon={loading ? <CircularProgress size={20} /> : <SaveIcon />}
                                            disabled={loading || !vehicleId}
                                            color={failCount > 0 ? 'warning' : 'primary'}
                                        >
                                            {failCount > 0 ? '条件付きで保存' : '保存'}
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
