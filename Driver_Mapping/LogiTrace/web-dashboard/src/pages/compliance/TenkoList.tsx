import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    Container,
    FormControl,
    Grid,
    InputLabel,
    MenuItem,
    Paper,
    Select,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TextField,
    Typography,
    CircularProgress,
    Alert,
} from '@mui/material';
import { Add as AddIcon, Refresh as RefreshIcon } from '@mui/icons-material';

interface TenkoRecord {
    id: number;
    driver_id: number;
    driver_name: string;
    driver_email: string;
    tenko_type: 'pre' | 'post';
    tenko_date: string;
    tenko_time: string;
    method: string;
    health_status: string;
    alcohol_level: number;
    alcohol_check_passed: boolean;
    fatigue_level: number;
    inspector_name: string;
}

export default function TenkoList() {
    const navigate = useNavigate();
    const [records, setRecords] = useState<TenkoRecord[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    // フィルター
    const [dateFrom, setDateFrom] = useState(new Date().toISOString().split('T')[0]);
    const [dateTo, setDateTo] = useState(new Date().toISOString().split('T')[0]);
    const [tenkoType, setTenkoType] = useState<string>('');

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchRecords();
    }, [dateFrom, dateTo, tenkoType]);

    const fetchRecords = async () => {
        setLoading(true);
        try {
            let url = `/api/tenko?companyId=${companyId}&dateFrom=${dateFrom}&dateTo=${dateTo}`;
            if (tenkoType) url += `&tenkoType=${tenkoType}`;

            const response = await fetch(url, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });

            if (!response.ok) throw new Error('Failed to fetch records');
            const data = await response.json();
            setRecords(data);
        } catch (err) {
            setError('点呼記録の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const getHealthStatusColor = (status: string) => {
        switch (status) {
            case 'good': return 'success';
            case 'fair': return 'warning';
            case 'poor': return 'error';
            default: return 'default';
        }
    };

    const getHealthStatusLabel = (status: string) => {
        switch (status) {
            case 'good': return '良好';
            case 'fair': return '普通';
            case 'poor': return '不良';
            default: return status;
        }
    };

    const getTenkoTypeLabel = (type: string) => {
        return type === 'pre' ? '乗務前' : '乗務後';
    };

    const getMethodLabel = (method: string) => {
        switch (method) {
            case 'face_to_face': return '対面';
            case 'it_tenko': return 'IT点呼';
            case 'phone': return '電話';
            default: return method;
        }
    };

    const formatTime = (timeStr: string) => {
        return new Date(timeStr).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4" component="h1">
                        点呼記録簿
                    </Typography>
                    <Box>
                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={fetchRecords}
                            sx={{ mr: 1 }}
                        >
                            更新
                        </Button>
                        <Button
                            variant="contained"
                            startIcon={<AddIcon />}
                            onClick={() => navigate('/compliance/tenko/new')}
                        >
                            新規点呼
                        </Button>
                    </Box>
                </Box>

                {/* フィルター */}
                <Card sx={{ mb: 3 }}>
                    <CardContent>
                        <Grid container spacing={2} alignItems="center">
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <TextField
                                    label="開始日"
                                    type="date"
                                    fullWidth
                                    value={dateFrom}
                                    onChange={(e) => setDateFrom(e.target.value)}
                                    InputLabelProps={{ shrink: true }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <TextField
                                    label="終了日"
                                    type="date"
                                    fullWidth
                                    value={dateTo}
                                    onChange={(e) => setDateTo(e.target.value)}
                                    InputLabelProps={{ shrink: true }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <FormControl fullWidth>
                                    <InputLabel>点呼種別</InputLabel>
                                    <Select
                                        value={tenkoType}
                                        label="点呼種別"
                                        onChange={(e) => setTenkoType(e.target.value)}
                                    >
                                        <MenuItem value="">すべて</MenuItem>
                                        <MenuItem value="pre">乗務前</MenuItem>
                                        <MenuItem value="post">乗務後</MenuItem>
                                    </Select>
                                </FormControl>
                            </Grid>
                        </Grid>
                    </CardContent>
                </Card>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

                {loading ? (
                    <Box display="flex" justifyContent="center" py={4}>
                        <CircularProgress />
                    </Box>
                ) : (
                    <TableContainer component={Paper}>
                        <Table>
                            <TableHead>
                                <TableRow>
                                    <TableCell>日付</TableCell>
                                    <TableCell>時刻</TableCell>
                                    <TableCell>ドライバー</TableCell>
                                    <TableCell>種別</TableCell>
                                    <TableCell>方法</TableCell>
                                    <TableCell>健康状態</TableCell>
                                    <TableCell>アルコール</TableCell>
                                    <TableCell>疲労度</TableCell>
                                    <TableCell>点呼執行者</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {records.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={9} align="center">
                                            点呼記録がありません
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    records.map((record) => (
                                        <TableRow key={record.id} hover>
                                            <TableCell>
                                                {new Date(record.tenko_date).toLocaleDateString('ja-JP')}
                                            </TableCell>
                                            <TableCell>{formatTime(record.tenko_time)}</TableCell>
                                            <TableCell>{record.driver_name}</TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={getTenkoTypeLabel(record.tenko_type)}
                                                    color={record.tenko_type === 'pre' ? 'primary' : 'secondary'}
                                                    size="small"
                                                />
                                            </TableCell>
                                            <TableCell>{getMethodLabel(record.method)}</TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={getHealthStatusLabel(record.health_status)}
                                                    color={getHealthStatusColor(record.health_status) as any}
                                                    size="small"
                                                />
                                            </TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={record.alcohol_check_passed ? '合格 (0.00)' : `不合格 (${record.alcohol_level})`}
                                                    color={record.alcohol_check_passed ? 'success' : 'error'}
                                                    size="small"
                                                />
                                            </TableCell>
                                            <TableCell>{record.fatigue_level}/5</TableCell>
                                            <TableCell>{record.inspector_name}</TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                )}
            </Box>
        </Container>
    );
}
