import { useState } from 'react';
import {
    Box,
    Button,
    Card,
    CardContent,
    Container,
    FormControl,
    Grid,
    InputLabel,
    MenuItem,
    Select,
    Typography,
    CircularProgress,
    Alert,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Paper,
    Tabs,
    Tab,
    Chip,
} from '@mui/material';
import {
    CalendarMonth,
    CalendarToday,
    PictureAsPdf,
    TrendingUp,
    LocalShipping,
    People,
    FactCheck,
    Speed,
} from '@mui/icons-material';

interface ReportSummary {
    period: string;
    totalWorkDays: number;
    totalDistance: number;
    totalDrivers: number;
    totalVehicles: number;
    tenkoCount: number;
    tenkoPassRate: number;
    inspectionCount: number;
    inspectionPassRate: number;
    accidentCount: number;
    violationCount: number;
    avgDistancePerDay: number;
    avgDistancePerDriver: number;
}

interface MonthlyData {
    month: string;
    workDays: number;
    distance: number;
    tenkoCount: number;
    inspectionCount: number;
    accidents: number;
}

export default function MonthlyYearlyReports() {
    const [tabValue, setTabValue] = useState(0);
    const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
    const [selectedMonth, setSelectedMonth] = useState(new Date().getMonth() + 1);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [reportData, setReportData] = useState<ReportSummary | null>(null);
    const [yearlyData, setYearlyData] = useState<MonthlyData[]>([]);
    const [generating, setGenerating] = useState(false);

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const currentYear = new Date().getFullYear();
    const years = Array.from({ length: 5 }, (_, i) => currentYear - i);
    const months = Array.from({ length: 12 }, (_, i) => i + 1);

    const fetchMonthlyReport = async () => {
        setLoading(true);
        setError('');
        try {
            const startDate = `${selectedYear}-${String(selectedMonth).padStart(2, '0')}-01`;
            const endDate = new Date(selectedYear, selectedMonth, 0).toISOString().split('T')[0];

            const response = await fetch(
                `/api/reports/summary?startDate=${startDate}&endDate=${endDate}`,
                {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }
            );

            if (!response.ok) throw new Error('レポートの取得に失敗しました');
            const data = await response.json();
            setReportData(data);
        } catch (err) {
            setError(err instanceof Error ? err.message : 'エラーが発生しました');
        } finally {
            setLoading(false);
        }
    };

    const fetchYearlyReport = async () => {
        setLoading(true);
        setError('');
        try {
            const response = await fetch(
                `/api/reports/yearly?year=${selectedYear}`,
                {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }
            );

            if (!response.ok) throw new Error('年次レポートの取得に失敗しました');
            const data = await response.json();
            setReportData(data.summary);
            setYearlyData(data.monthlyBreakdown);
        } catch (err) {
            setError(err instanceof Error ? err.message : 'エラーが発生しました');
        } finally {
            setLoading(false);
        }
    };

    const downloadPDF = async (type: 'monthly' | 'yearly') => {
        setGenerating(true);
        try {
            let url = '';
            let filename = '';

            if (type === 'monthly') {
                const startDate = `${selectedYear}-${String(selectedMonth).padStart(2, '0')}-01`;
                const endDate = new Date(selectedYear, selectedMonth, 0).toISOString().split('T')[0];
                url = `/api/reports/pdf?type=monthly&startDate=${startDate}&endDate=${endDate}`;
                filename = `月次レポート_${selectedYear}年${selectedMonth}月.pdf`;
            } else {
                url = `/api/reports/pdf?type=yearly&year=${selectedYear}`;
                filename = `年次レポート_${selectedYear}年.pdf`;
            }

            const response = await fetch(url, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });

            if (!response.ok) throw new Error('PDF生成に失敗しました');

            const blob = await response.blob();
            const downloadUrl = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = downloadUrl;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(downloadUrl);
            a.remove();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'PDF生成に失敗しました');
        } finally {
            setGenerating(false);
        }
    };

    const handleTabChange = (_: React.SyntheticEvent, newValue: number) => {
        setTabValue(newValue);
        setReportData(null);
        setYearlyData([]);
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Typography variant="h4" component="h1" gutterBottom>
                    月次・年次レポート
                </Typography>
                <Typography color="text.secondary" sx={{ mb: 4 }}>
                    期間ごとの業務実績とコンプライアンス状況をレポート形式で確認できます
                </Typography>

                {error && <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>{error}</Alert>}

                <Tabs value={tabValue} onChange={handleTabChange} sx={{ mb: 3 }}>
                    <Tab icon={<CalendarToday />} label="月次レポート" iconPosition="start" />
                    <Tab icon={<CalendarMonth />} label="年次レポート" iconPosition="start" />
                </Tabs>

                {/* 月次レポート */}
                {tabValue === 0 && (
                    <Box>
                        <Card sx={{ mb: 3 }}>
                            <CardContent>
                                <Grid container spacing={2} alignItems="center">
                                    <Grid size={{ xs: 12, sm: 3 }}>
                                        <FormControl fullWidth>
                                            <InputLabel>年</InputLabel>
                                            <Select
                                                value={selectedYear}
                                                label="年"
                                                onChange={(e) => setSelectedYear(e.target.value as number)}
                                            >
                                                {years.map((year) => (
                                                    <MenuItem key={year} value={year}>{year}年</MenuItem>
                                                ))}
                                            </Select>
                                        </FormControl>
                                    </Grid>
                                    <Grid size={{ xs: 12, sm: 3 }}>
                                        <FormControl fullWidth>
                                            <InputLabel>月</InputLabel>
                                            <Select
                                                value={selectedMonth}
                                                label="月"
                                                onChange={(e) => setSelectedMonth(e.target.value as number)}
                                            >
                                                {months.map((month) => (
                                                    <MenuItem key={month} value={month}>{month}月</MenuItem>
                                                ))}
                                            </Select>
                                        </FormControl>
                                    </Grid>
                                    <Grid size={{ xs: 12, sm: 3 }}>
                                        <Button
                                            variant="contained"
                                            onClick={fetchMonthlyReport}
                                            disabled={loading}
                                            fullWidth
                                        >
                                            {loading ? <CircularProgress size={24} /> : 'レポート生成'}
                                        </Button>
                                    </Grid>
                                    <Grid size={{ xs: 12, sm: 3 }}>
                                        <Button
                                            variant="outlined"
                                            startIcon={<PictureAsPdf />}
                                            onClick={() => downloadPDF('monthly')}
                                            disabled={generating || !reportData}
                                            fullWidth
                                        >
                                            {generating ? <CircularProgress size={24} /> : 'PDF出力'}
                                        </Button>
                                    </Grid>
                                </Grid>
                            </CardContent>
                        </Card>

                        {reportData && (
                            <ReportSummaryCards data={reportData} period={`${selectedYear}年${selectedMonth}月`} />
                        )}
                    </Box>
                )}

                {/* 年次レポート */}
                {tabValue === 1 && (
                    <Box>
                        <Card sx={{ mb: 3 }}>
                            <CardContent>
                                <Grid container spacing={2} alignItems="center">
                                    <Grid size={{ xs: 12, sm: 4 }}>
                                        <FormControl fullWidth>
                                            <InputLabel>年</InputLabel>
                                            <Select
                                                value={selectedYear}
                                                label="年"
                                                onChange={(e) => setSelectedYear(e.target.value as number)}
                                            >
                                                {years.map((year) => (
                                                    <MenuItem key={year} value={year}>{year}年</MenuItem>
                                                ))}
                                            </Select>
                                        </FormControl>
                                    </Grid>
                                    <Grid size={{ xs: 12, sm: 4 }}>
                                        <Button
                                            variant="contained"
                                            onClick={fetchYearlyReport}
                                            disabled={loading}
                                            fullWidth
                                        >
                                            {loading ? <CircularProgress size={24} /> : '年次レポート生成'}
                                        </Button>
                                    </Grid>
                                    <Grid size={{ xs: 12, sm: 4 }}>
                                        <Button
                                            variant="outlined"
                                            startIcon={<PictureAsPdf />}
                                            onClick={() => downloadPDF('yearly')}
                                            disabled={generating || !reportData}
                                            fullWidth
                                        >
                                            {generating ? <CircularProgress size={24} /> : 'PDF出力'}
                                        </Button>
                                    </Grid>
                                </Grid>
                            </CardContent>
                        </Card>

                        {reportData && (
                            <>
                                <ReportSummaryCards data={reportData} period={`${selectedYear}年`} />

                                {/* 月別推移 */}
                                {yearlyData.length > 0 && (
                                    <Card sx={{ mt: 3 }}>
                                        <CardContent>
                                            <Typography variant="h6" gutterBottom>
                                                月別推移
                                            </Typography>
                                            <TableContainer component={Paper} variant="outlined">
                                                <Table size="small">
                                                    <TableHead>
                                                        <TableRow>
                                                            <TableCell>月</TableCell>
                                                            <TableCell align="right">稼働日数</TableCell>
                                                            <TableCell align="right">走行距離</TableCell>
                                                            <TableCell align="right">点呼件数</TableCell>
                                                            <TableCell align="right">点検件数</TableCell>
                                                            <TableCell align="right">事故件数</TableCell>
                                                        </TableRow>
                                                    </TableHead>
                                                    <TableBody>
                                                        {yearlyData.map((row) => (
                                                            <TableRow key={row.month}>
                                                                <TableCell>{row.month}</TableCell>
                                                                <TableCell align="right">{row.workDays}日</TableCell>
                                                                <TableCell align="right">{row.distance.toLocaleString()} km</TableCell>
                                                                <TableCell align="right">{row.tenkoCount}件</TableCell>
                                                                <TableCell align="right">{row.inspectionCount}件</TableCell>
                                                                <TableCell align="right">
                                                                    {row.accidents > 0 ? (
                                                                        <Chip label={`${row.accidents}件`} color="error" size="small" />
                                                                    ) : (
                                                                        '0件'
                                                                    )}
                                                                </TableCell>
                                                            </TableRow>
                                                        ))}
                                                    </TableBody>
                                                </Table>
                                            </TableContainer>
                                        </CardContent>
                                    </Card>
                                )}
                            </>
                        )}
                    </Box>
                )}
            </Box>
        </Container>
    );
}

function ReportSummaryCards({ data, period }: { data: ReportSummary; period: string }) {
    return (
        <>
            <Typography variant="h5" sx={{ mb: 2 }}>
                {period} 実績サマリー
            </Typography>

            <Grid container spacing={3}>
                {/* 基本指標 */}
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                <TrendingUp color="primary" sx={{ mr: 1 }} />
                                <Typography color="text.secondary">総走行距離</Typography>
                            </Box>
                            <Typography variant="h4">{data.totalDistance.toLocaleString()}</Typography>
                            <Typography variant="body2" color="text.secondary">km</Typography>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                <LocalShipping color="success" sx={{ mr: 1 }} />
                                <Typography color="text.secondary">稼働日数</Typography>
                            </Box>
                            <Typography variant="h4">{data.totalWorkDays}</Typography>
                            <Typography variant="body2" color="text.secondary">日</Typography>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                <People color="info" sx={{ mr: 1 }} />
                                <Typography color="text.secondary">稼働ドライバー</Typography>
                            </Box>
                            <Typography variant="h4">{data.totalDrivers}</Typography>
                            <Typography variant="body2" color="text.secondary">名</Typography>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                <Speed color="warning" sx={{ mr: 1 }} />
                                <Typography color="text.secondary">平均日走行距離</Typography>
                            </Box>
                            <Typography variant="h4">{Math.round(data.avgDistancePerDay).toLocaleString()}</Typography>
                            <Typography variant="body2" color="text.secondary">km/日</Typography>
                        </CardContent>
                    </Card>
                </Grid>

                {/* コンプライアンス指標 */}
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card sx={{ bgcolor: data.tenkoPassRate >= 100 ? '#e8f5e9' : '#fff3e0' }}>
                        <CardContent>
                            <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                <FactCheck color={data.tenkoPassRate >= 100 ? 'success' : 'warning'} sx={{ mr: 1 }} />
                                <Typography color="text.secondary">点呼実施率</Typography>
                            </Box>
                            <Typography variant="h4">{data.tenkoPassRate}%</Typography>
                            <Typography variant="body2" color="text.secondary">{data.tenkoCount}件実施</Typography>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card sx={{ bgcolor: data.inspectionPassRate >= 100 ? '#e8f5e9' : '#fff3e0' }}>
                        <CardContent>
                            <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                <FactCheck color={data.inspectionPassRate >= 100 ? 'success' : 'warning'} sx={{ mr: 1 }} />
                                <Typography color="text.secondary">点検合格率</Typography>
                            </Box>
                            <Typography variant="h4">{data.inspectionPassRate}%</Typography>
                            <Typography variant="body2" color="text.secondary">{data.inspectionCount}件実施</Typography>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card sx={{ bgcolor: data.accidentCount === 0 ? '#e8f5e9' : '#ffebee' }}>
                        <CardContent>
                            <Typography color="text.secondary" gutterBottom>事故件数</Typography>
                            <Typography variant="h4" color={data.accidentCount === 0 ? 'success.main' : 'error.main'}>
                                {data.accidentCount}
                            </Typography>
                            <Typography variant="body2" color="text.secondary">件</Typography>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card sx={{ bgcolor: data.violationCount === 0 ? '#e8f5e9' : '#fff3e0' }}>
                        <CardContent>
                            <Typography color="text.secondary" gutterBottom>違反件数</Typography>
                            <Typography variant="h4" color={data.violationCount === 0 ? 'success.main' : 'warning.main'}>
                                {data.violationCount}
                            </Typography>
                            <Typography variant="body2" color="text.secondary">件</Typography>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>
        </>
    );
}
