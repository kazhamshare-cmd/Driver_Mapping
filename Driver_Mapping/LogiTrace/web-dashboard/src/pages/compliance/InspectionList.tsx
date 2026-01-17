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
import { Add as AddIcon, Refresh as RefreshIcon, Warning as WarningIcon } from '@mui/icons-material';

interface InspectionRecord {
    id: number;
    vehicle_id: number;
    vehicle_number: string;
    driver_id: number;
    driver_name: string;
    inspection_date: string;
    inspection_time: string;
    overall_result: 'pass' | 'fail' | 'conditional';
    follow_up_required: boolean;
    issues_found: string | null;
}

export default function InspectionList() {
    const navigate = useNavigate();
    const [records, setRecords] = useState<InspectionRecord[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    // フィルター
    const [dateFrom, setDateFrom] = useState(new Date().toISOString().split('T')[0]);
    const [dateTo, setDateTo] = useState(new Date().toISOString().split('T')[0]);
    const [resultFilter, setResultFilter] = useState<string>('');

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchRecords();
    }, [dateFrom, dateTo, resultFilter]);

    const fetchRecords = async () => {
        setLoading(true);
        try {
            let url = `/api/inspections?companyId=${companyId}&dateFrom=${dateFrom}&dateTo=${dateTo}`;
            if (resultFilter) url += `&result=${resultFilter}`;

            const response = await fetch(url, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });

            if (!response.ok) throw new Error('Failed to fetch records');
            const data = await response.json();
            setRecords(data);
        } catch (err) {
            setError('点検記録の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const getResultColor = (result: string) => {
        switch (result) {
            case 'pass': return 'success';
            case 'fail': return 'error';
            case 'conditional': return 'warning';
            default: return 'default';
        }
    };

    const getResultLabel = (result: string) => {
        switch (result) {
            case 'pass': return '合格';
            case 'fail': return '不合格';
            case 'conditional': return '条件付き';
            default: return result;
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
                        日常点検記録簿
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
                            onClick={() => navigate('/compliance/inspections/new')}
                        >
                            新規点検
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
                                    <InputLabel>判定結果</InputLabel>
                                    <Select
                                        value={resultFilter}
                                        label="判定結果"
                                        onChange={(e) => setResultFilter(e.target.value)}
                                    >
                                        <MenuItem value="">すべて</MenuItem>
                                        <MenuItem value="pass">合格</MenuItem>
                                        <MenuItem value="conditional">条件付き</MenuItem>
                                        <MenuItem value="fail">不合格</MenuItem>
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
                                    <TableCell>車両番号</TableCell>
                                    <TableCell>点検者</TableCell>
                                    <TableCell>判定</TableCell>
                                    <TableCell>要フォローアップ</TableCell>
                                    <TableCell>問題点</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {records.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={7} align="center">
                                            点検記録がありません
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    records.map((record) => (
                                        <TableRow
                                            key={record.id}
                                            hover
                                            sx={{
                                                backgroundColor: record.follow_up_required ? 'rgba(255, 152, 0, 0.1)' : 'inherit'
                                            }}
                                        >
                                            <TableCell>
                                                {new Date(record.inspection_date).toLocaleDateString('ja-JP')}
                                            </TableCell>
                                            <TableCell>{formatTime(record.inspection_time)}</TableCell>
                                            <TableCell>{record.vehicle_number}</TableCell>
                                            <TableCell>{record.driver_name}</TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={getResultLabel(record.overall_result)}
                                                    color={getResultColor(record.overall_result) as any}
                                                    size="small"
                                                />
                                            </TableCell>
                                            <TableCell>
                                                {record.follow_up_required && (
                                                    <Chip
                                                        icon={<WarningIcon />}
                                                        label="要対応"
                                                        color="warning"
                                                        size="small"
                                                    />
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                {record.issues_found ? (
                                                    <Typography variant="body2" color="error">
                                                        {record.issues_found.substring(0, 30)}
                                                        {record.issues_found.length > 30 ? '...' : ''}
                                                    </Typography>
                                                ) : (
                                                    '-'
                                                )}
                                            </TableCell>
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
