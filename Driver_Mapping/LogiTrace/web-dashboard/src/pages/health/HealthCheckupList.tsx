import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box, Button, Card, CardContent, Chip, Container, FormControl, Grid,
    InputLabel, MenuItem, Paper, Select, Table, TableBody, TableCell,
    TableContainer, TableHead, TableRow, TextField, Typography,
    CircularProgress, Alert
} from '@mui/material';
import { Add as AddIcon, Refresh as RefreshIcon } from '@mui/icons-material';

interface HealthCheckup {
    id: number;
    driver_id: number;
    driver_name: string;
    employee_number: string;
    checkup_type: string;
    checkup_date: string;
    next_checkup_date: string;
    facility_name: string;
    overall_result: string;
}

export default function HealthCheckupList() {
    const navigate = useNavigate();
    const [records, setRecords] = useState<HealthCheckup[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [checkupType, setCheckupType] = useState('');
    const [dateFrom, setDateFrom] = useState('');
    const [dateTo, setDateTo] = useState('');

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchRecords();
    }, [checkupType, dateFrom, dateTo]);

    const fetchRecords = async () => {
        setLoading(true);
        try {
            let url = `/api/health-checkups?companyId=${companyId}`;
            if (checkupType) url += `&checkupType=${checkupType}`;
            if (dateFrom) url += `&dateFrom=${dateFrom}`;
            if (dateTo) url += `&dateTo=${dateTo}`;

            const response = await fetch(url, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (!response.ok) throw new Error('Failed to fetch');
            setRecords(await response.json());
        } catch (err) {
            setError('健康診断記録の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const getTypeLabel = (type: string) => {
        const types: { [key: string]: string } = {
            'regular': '定期健康診断',
            'special': '特殊健康診断',
            'pre_employment': '雇入時健康診断'
        };
        return types[type] || type;
    };

    const getResultColor = (result: string) => {
        switch (result) {
            case 'normal': return 'success';
            case 'observation': return 'warning';
            case 'treatment':
            case 'work_restriction': return 'error';
            default: return 'default';
        }
    };

    const getResultLabel = (result: string) => {
        const labels: { [key: string]: string } = {
            'normal': '異常なし',
            'observation': '要経過観察',
            'treatment': '要治療',
            'work_restriction': '就業制限'
        };
        return labels[result] || result;
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4">健康診断記録</Typography>
                    <Box>
                        <Button variant="outlined" startIcon={<RefreshIcon />} onClick={fetchRecords} sx={{ mr: 1 }}>更新</Button>
                        <Button variant="contained" startIcon={<AddIcon />} onClick={() => navigate('/health/new')}>新規登録</Button>
                    </Box>
                </Box>

                <Card sx={{ mb: 3 }}>
                    <CardContent>
                        <Grid container spacing={2}>
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <FormControl fullWidth>
                                    <InputLabel>種別</InputLabel>
                                    <Select value={checkupType} label="種別" onChange={(e) => setCheckupType(e.target.value)}>
                                        <MenuItem value="">すべて</MenuItem>
                                        <MenuItem value="regular">定期健康診断</MenuItem>
                                        <MenuItem value="special">特殊健康診断</MenuItem>
                                        <MenuItem value="pre_employment">雇入時健康診断</MenuItem>
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <TextField label="開始日" type="date" fullWidth InputLabelProps={{ shrink: true }}
                                    value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} />
                            </Grid>
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <TextField label="終了日" type="date" fullWidth InputLabelProps={{ shrink: true }}
                                    value={dateTo} onChange={(e) => setDateTo(e.target.value)} />
                            </Grid>
                        </Grid>
                    </CardContent>
                </Card>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

                {loading ? (
                    <Box display="flex" justifyContent="center" py={4}><CircularProgress /></Box>
                ) : (
                    <TableContainer component={Paper}>
                        <Table>
                            <TableHead>
                                <TableRow>
                                    <TableCell>受診日</TableCell>
                                    <TableCell>ドライバー</TableCell>
                                    <TableCell>種別</TableCell>
                                    <TableCell>結果</TableCell>
                                    <TableCell>実施機関</TableCell>
                                    <TableCell>次回予定</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {records.length === 0 ? (
                                    <TableRow><TableCell colSpan={6} align="center">記録がありません</TableCell></TableRow>
                                ) : (
                                    records.map((record) => (
                                        <TableRow key={record.id} hover>
                                            <TableCell>{new Date(record.checkup_date).toLocaleDateString('ja-JP')}</TableCell>
                                            <TableCell>{record.driver_name}</TableCell>
                                            <TableCell>{getTypeLabel(record.checkup_type)}</TableCell>
                                            <TableCell>
                                                <Chip label={getResultLabel(record.overall_result)} color={getResultColor(record.overall_result) as any} size="small" />
                                            </TableCell>
                                            <TableCell>{record.facility_name}</TableCell>
                                            <TableCell>{record.next_checkup_date ? new Date(record.next_checkup_date).toLocaleDateString('ja-JP') : '-'}</TableCell>
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
