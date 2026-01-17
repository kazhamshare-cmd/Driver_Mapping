import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box, Button, Card, CardContent, Chip, Container, FormControl, Grid,
    InputLabel, MenuItem, Paper, Select, Table, TableBody, TableCell,
    TableContainer, TableHead, TableRow, TextField, Typography,
    CircularProgress, Alert
} from '@mui/material';
import { Add as AddIcon, Refresh as RefreshIcon } from '@mui/icons-material';

interface TrainingRecord {
    id: number;
    driver_id: number;
    driver_name: string;
    employee_number: string;
    training_type: string;
    training_type_name: string;
    training_name: string;
    training_date: string;
    duration_hours: number;
    instructor_name: string;
    completion_status: string;
}

export default function TrainingList() {
    const navigate = useNavigate();
    const [records, setRecords] = useState<TrainingRecord[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [status, setStatus] = useState('');
    const [dateFrom, setDateFrom] = useState('');
    const [dateTo, setDateTo] = useState('');

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchRecords();
    }, [status, dateFrom, dateTo]);

    const fetchRecords = async () => {
        setLoading(true);
        try {
            let url = `/api/training?companyId=${companyId}`;
            if (status) url += `&status=${status}`;
            if (dateFrom) url += `&dateFrom=${dateFrom}`;
            if (dateTo) url += `&dateTo=${dateTo}`;

            const response = await fetch(url, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (!response.ok) throw new Error('Failed to fetch');
            setRecords(await response.json());
        } catch (err) {
            setError('研修記録の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'completed': return 'success';
            case 'scheduled': return 'info';
            case 'incomplete': return 'warning';
            default: return 'default';
        }
    };

    const getStatusLabel = (status: string) => {
        const labels: { [key: string]: string } = {
            'completed': '完了',
            'scheduled': '予定',
            'incomplete': '未完了'
        };
        return labels[status] || status;
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4">教育研修記録</Typography>
                    <Box>
                        <Button variant="outlined" startIcon={<RefreshIcon />} onClick={fetchRecords} sx={{ mr: 1 }}>更新</Button>
                        <Button variant="contained" startIcon={<AddIcon />} onClick={() => navigate('/training/new')}>新規登録</Button>
                    </Box>
                </Box>

                <Card sx={{ mb: 3 }}>
                    <CardContent>
                        <Grid container spacing={2}>
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <FormControl fullWidth>
                                    <InputLabel>状況</InputLabel>
                                    <Select value={status} label="状況" onChange={(e) => setStatus(e.target.value)}>
                                        <MenuItem value="">すべて</MenuItem>
                                        <MenuItem value="completed">完了</MenuItem>
                                        <MenuItem value="scheduled">予定</MenuItem>
                                        <MenuItem value="incomplete">未完了</MenuItem>
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
                                    <TableCell>実施日</TableCell>
                                    <TableCell>ドライバー</TableCell>
                                    <TableCell>研修名</TableCell>
                                    <TableCell>種別</TableCell>
                                    <TableCell>時間</TableCell>
                                    <TableCell>講師</TableCell>
                                    <TableCell>状況</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {records.length === 0 ? (
                                    <TableRow><TableCell colSpan={7} align="center">記録がありません</TableCell></TableRow>
                                ) : (
                                    records.map((record) => (
                                        <TableRow key={record.id} hover>
                                            <TableCell>{new Date(record.training_date).toLocaleDateString('ja-JP')}</TableCell>
                                            <TableCell>{record.driver_name}</TableCell>
                                            <TableCell>{record.training_name}</TableCell>
                                            <TableCell>{record.training_type_name || record.training_type}</TableCell>
                                            <TableCell>{record.duration_hours ? `${record.duration_hours}時間` : '-'}</TableCell>
                                            <TableCell>{record.instructor_name || '-'}</TableCell>
                                            <TableCell>
                                                <Chip label={getStatusLabel(record.completion_status)} color={getStatusColor(record.completion_status) as any} size="small" />
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
