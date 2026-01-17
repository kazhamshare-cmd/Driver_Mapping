import { useEffect, useState } from 'react';
import {
    Box,
    Button,
    Chip,
    Container,
    CircularProgress,
    InputAdornment,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TextField,
    Typography,
} from '@mui/material';
import { Search } from '@mui/icons-material';

// API URL
const API_URL = '/api';

export default function ReportsList() {
    const [reports, setReports] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchReports();
    }, []);

    const fetchReports = async () => {
        try {
            const response = await fetch(`${API_URL}/work-records`);
            if (response.ok) {
                const data = await response.json();
                setReports(data);
            }
        } catch (error) {
            console.error('Failed to fetch reports', error);
        } finally {
            setLoading(false);
        }
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4" component="h1">
                        日報一覧
                    </Typography>
                    <TextField
                        placeholder="ドライバー名や日付で検索..."
                        InputProps={{
                            startAdornment: (
                                <InputAdornment position="start">
                                    <Search />
                                </InputAdornment>
                            ),
                        }}
                        variant="outlined"
                        size="small"
                        sx={{ width: 300 }}
                    />
                </Box>

                <TableContainer component={Paper}>
                    <Table sx={{ minWidth: 650 }} aria-label="simple table">
                        <TableHead>
                            <TableRow>
                                <TableCell>日付</TableCell>
                                <TableCell>ドライバー</TableCell>
                                <TableCell>車両</TableCell>
                                <TableCell>開始・終了時刻</TableCell>
                                <TableCell>距離 (km)</TableCell>
                                <TableCell>記録方法</TableCell>
                                <TableCell>ステータス</TableCell>
                                <TableCell>操作</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? (
                                <TableRow>
                                    <TableCell colSpan={8} align="center">
                                        <CircularProgress />
                                    </TableCell>
                                </TableRow>
                            ) : reports.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={8} align="center">
                                        データがありません
                                    </TableCell>
                                </TableRow>
                            ) : (
                                reports.map((report) => (
                                    <TableRow
                                        key={report.id}
                                        sx={{ '&:last-child td, &:last-child th': { border: 0 } }}
                                    >
                                        <TableCell component="th" scope="row">
                                            {new Date(report.work_date).toLocaleDateString()}
                                        </TableCell>
                                        <TableCell>{report.driver_name || '未登録'}</TableCell>
                                        <TableCell>{report.vehicle_number || '-'}</TableCell>
                                        <TableCell>
                                            {new Date(report.start_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} -
                                            {report.end_time ? new Date(report.end_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ' 勤務中'}
                                        </TableCell>
                                        <TableCell>{report.distance ? Number(report.distance).toFixed(1) : '-'}</TableCell>
                                        <TableCell>
                                            <Chip
                                                label={report.record_method === 'gps' ? 'GPS' : '手動'}
                                                color={report.record_method === 'gps' ? 'primary' : 'warning'}
                                                size="small"
                                            />
                                        </TableCell>
                                        <TableCell>
                                            <Chip
                                                label={report.status === 'confirmed' ? '確定済' : '未確定'}
                                                color={report.status === 'confirmed' ? 'success' : 'default'}
                                                size="small"
                                                variant="outlined"
                                            />
                                        </TableCell>
                                        <TableCell>
                                            <Button variant="outlined" size="small">
                                                詳細
                                            </Button>
                                        </TableCell>
                                    </TableRow>
                                ))
                            )}
                        </TableBody>
                    </Table>
                </TableContainer>
            </Box>
        </Container>
    );
}
