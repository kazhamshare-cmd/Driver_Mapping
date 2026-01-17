import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box, Button, Card, CardContent, Chip, Container, FormControl, Grid,
    InputLabel, MenuItem, Paper, Select, Table, TableBody, TableCell,
    TableContainer, TableHead, TableRow, TextField, Typography,
    CircularProgress, Alert
} from '@mui/material';
import { Add as AddIcon, Refresh as RefreshIcon } from '@mui/icons-material';

interface AccidentRecord {
    id: number;
    driver_id: number;
    driver_name: string;
    employee_number: string;
    record_type: 'accident' | 'violation';
    incident_date: string;
    location: string;
    description: string;
    severity: string;
    is_at_fault: boolean;
    points_deducted: number;
    fine_amount: number;
    damage_amount: number;
}

export default function AccidentList() {
    const navigate = useNavigate();
    const [records, setRecords] = useState<AccidentRecord[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [recordType, setRecordType] = useState('');
    const [dateFrom, setDateFrom] = useState('');
    const [dateTo, setDateTo] = useState('');

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchRecords();
    }, [recordType, dateFrom, dateTo]);

    const fetchRecords = async () => {
        setLoading(true);
        try {
            let url = `/api/accidents?companyId=${companyId}`;
            if (recordType) url += `&recordType=${recordType}`;
            if (dateFrom) url += `&dateFrom=${dateFrom}`;
            if (dateTo) url += `&dateTo=${dateTo}`;

            const response = await fetch(url, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (!response.ok) throw new Error('Failed to fetch');
            setRecords(await response.json());
        } catch (err) {
            setError('事故・違反記録の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const getSeverityColor = (severity: string) => {
        switch (severity) {
            case 'minor': return 'info';
            case 'moderate': return 'warning';
            case 'severe':
            case 'fatal': return 'error';
            default: return 'default';
        }
    };

    const getSeverityLabel = (severity: string) => {
        const labels: { [key: string]: string } = {
            'minor': '軽微',
            'moderate': '中程度',
            'severe': '重大',
            'fatal': '死亡'
        };
        return labels[severity] || severity || '-';
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4">事故・違反履歴</Typography>
                    <Box>
                        <Button variant="outlined" startIcon={<RefreshIcon />} onClick={fetchRecords} sx={{ mr: 1 }}>更新</Button>
                        <Button variant="contained" startIcon={<AddIcon />} onClick={() => navigate('/accidents/new')}>新規登録</Button>
                    </Box>
                </Box>

                <Card sx={{ mb: 3 }}>
                    <CardContent>
                        <Grid container spacing={2}>
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <FormControl fullWidth>
                                    <InputLabel>種別</InputLabel>
                                    <Select value={recordType} label="種別" onChange={(e) => setRecordType(e.target.value)}>
                                        <MenuItem value="">すべて</MenuItem>
                                        <MenuItem value="accident">事故</MenuItem>
                                        <MenuItem value="violation">違反</MenuItem>
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
                                    <TableCell>発生日</TableCell>
                                    <TableCell>ドライバー</TableCell>
                                    <TableCell>種別</TableCell>
                                    <TableCell>内容</TableCell>
                                    <TableCell>重大度</TableCell>
                                    <TableCell>過失</TableCell>
                                    <TableCell>損害/罰金</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {records.length === 0 ? (
                                    <TableRow><TableCell colSpan={7} align="center">記録がありません</TableCell></TableRow>
                                ) : (
                                    records.map((record) => (
                                        <TableRow key={record.id} hover>
                                            <TableCell>{new Date(record.incident_date).toLocaleDateString('ja-JP')}</TableCell>
                                            <TableCell>{record.driver_name}</TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={record.record_type === 'accident' ? '事故' : '違反'}
                                                    color={record.record_type === 'accident' ? 'error' : 'warning'}
                                                    size="small"
                                                />
                                            </TableCell>
                                            <TableCell sx={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                                {record.description}
                                            </TableCell>
                                            <TableCell>
                                                <Chip label={getSeverityLabel(record.severity)} color={getSeverityColor(record.severity) as any} size="small" />
                                            </TableCell>
                                            <TableCell>{record.is_at_fault ? '有' : '無'}</TableCell>
                                            <TableCell>
                                                {record.record_type === 'accident'
                                                    ? record.damage_amount ? `¥${record.damage_amount.toLocaleString()}` : '-'
                                                    : record.fine_amount ? `¥${record.fine_amount.toLocaleString()}` : '-'}
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
