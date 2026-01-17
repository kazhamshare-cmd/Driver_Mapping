import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box, Button, Card, CardContent, Chip, Container, FormControl, Grid,
    InputLabel, MenuItem, Paper, Select, Table, TableBody, TableCell,
    TableContainer, TableHead, TableRow, Typography,
    CircularProgress, Alert
} from '@mui/material';
import { Add as AddIcon, Refresh as RefreshIcon } from '@mui/icons-material';

interface AptitudeTest {
    id: number;
    driver_id: number;
    driver_name: string;
    employee_number: string;
    test_type: string;
    test_date: string;
    next_test_date: string;
    facility_name: string;
    overall_score: number;
    driver_age: number;
}

export default function AptitudeTestList() {
    const navigate = useNavigate();
    const [records, setRecords] = useState<AptitudeTest[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [testType, setTestType] = useState('');

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchRecords();
    }, [testType]);

    const fetchRecords = async () => {
        setLoading(true);
        try {
            let url = `/api/aptitude-tests?companyId=${companyId}`;
            if (testType) url += `&testType=${testType}`;

            const response = await fetch(url, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (!response.ok) throw new Error('Failed to fetch');
            setRecords(await response.json());
        } catch (err) {
            setError('適性診断記録の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const getTypeLabel = (type: string) => {
        const types: { [key: string]: string } = {
            'initial': '初任診断',
            'age_based': '適齢診断',
            'specific': '特定診断',
            'voluntary': '一般診断'
        };
        return types[type] || type;
    };

    const getTypeColor = (type: string) => {
        switch (type) {
            case 'initial': return 'primary';
            case 'age_based': return 'warning';
            case 'specific': return 'error';
            default: return 'default';
        }
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4">適性診断記録</Typography>
                    <Box>
                        <Button variant="outlined" startIcon={<RefreshIcon />} onClick={fetchRecords} sx={{ mr: 1 }}>更新</Button>
                        <Button variant="contained" startIcon={<AddIcon />} onClick={() => navigate('/aptitude/new')}>新規登録</Button>
                    </Box>
                </Box>

                <Card sx={{ mb: 3 }}>
                    <CardContent>
                        <Grid container spacing={2}>
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <FormControl fullWidth>
                                    <InputLabel>種別</InputLabel>
                                    <Select value={testType} label="種別" onChange={(e) => setTestType(e.target.value)}>
                                        <MenuItem value="">すべて</MenuItem>
                                        <MenuItem value="initial">初任診断</MenuItem>
                                        <MenuItem value="age_based">適齢診断</MenuItem>
                                        <MenuItem value="specific">特定診断</MenuItem>
                                        <MenuItem value="voluntary">一般診断</MenuItem>
                                    </Select>
                                </FormControl>
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
                                    <TableCell>年齢</TableCell>
                                    <TableCell>種別</TableCell>
                                    <TableCell>スコア</TableCell>
                                    <TableCell>実施機関</TableCell>
                                    <TableCell>次回予定</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {records.length === 0 ? (
                                    <TableRow><TableCell colSpan={7} align="center">記録がありません</TableCell></TableRow>
                                ) : (
                                    records.map((record) => (
                                        <TableRow key={record.id} hover>
                                            <TableCell>{new Date(record.test_date).toLocaleDateString('ja-JP')}</TableCell>
                                            <TableCell>{record.driver_name}</TableCell>
                                            <TableCell>
                                                {record.driver_age}歳
                                                {record.driver_age >= 65 && <Chip label="65+" size="small" color="warning" sx={{ ml: 1 }} />}
                                            </TableCell>
                                            <TableCell>
                                                <Chip label={getTypeLabel(record.test_type)} color={getTypeColor(record.test_type) as any} size="small" />
                                            </TableCell>
                                            <TableCell>{record.overall_score || '-'}</TableCell>
                                            <TableCell>{record.facility_name}</TableCell>
                                            <TableCell>{record.next_test_date ? new Date(record.next_test_date).toLocaleDateString('ja-JP') : '-'}</TableCell>
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
