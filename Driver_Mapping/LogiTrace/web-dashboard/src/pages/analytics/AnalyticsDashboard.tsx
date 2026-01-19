/**
 * AnalyticsDashboard - 経営ダッシュボード
 * 月次サマリー、損益分岐点分析、KPI可視化
 */

import React, { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Grid,
    Card,
    CardContent,
    LinearProgress,
    Divider,
    Button,
    Alert,
    Chip,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    CircularProgress
} from '@mui/material';
import {
    TrendingUp as TrendingUpIcon,
    TrendingDown as TrendingDownIcon,
    AccountBalance as AccountBalanceIcon,
    Speed as SpeedIcon,
    LocalShipping as VehicleIcon,
    Person as DriverIcon,
    Assessment as AssessmentIcon,
    Warning as WarningIcon,
    Refresh as RefreshIcon,
    CheckCircle as CheckCircleIcon
} from '@mui/icons-material';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDayjs } from '@mui/x-date-pickers/AdapterDayjs';
import dayjs, { Dayjs } from 'dayjs';
import 'dayjs/locale/ja';
import api from '../../services/api';

interface MonthlySummary {
    total_revenue: number;
    transport_revenue: number;
    other_revenue: number;
    total_variable_cost: number;
    fuel_cost: number;
    toll_cost: number;
    driver_variable_cost: number;
    total_fixed_cost: number;
    vehicle_fixed_cost: number;
    driver_fixed_cost: number;
    admin_fixed_cost: number;
    gross_profit: number;
    operating_profit: number;
    operating_profit_rate: number;
    vehicle_count: number;
    driver_count: number;
    dispatch_count: number;
    total_distance_km: number;
    average_revenue_per_vehicle: number;
    average_revenue_per_km: number;
    breakeven_revenue: number;
    safety_margin_rate: number;
}

interface BreakevenAnalysis {
    total_fixed_cost: number;
    variable_cost_rate: number;
    breakeven_revenue: number;
    current_revenue: number;
    safety_margin: number;
    safety_margin_rate: number;
    is_profitable: boolean;
}

interface DashboardData {
    monthly_summary: MonthlySummary | null;
    breakeven: BreakevenAnalysis | null;
    top_vehicles: Array<{
        vehicle_number: string;
        profit: number;
        profit_rate: number;
    }>;
    top_drivers: Array<{
        driver_name: string;
        profit: number;
        profit_rate: number;
    }>;
}

const AnalyticsDashboard: React.FC = () => {
    const [selectedMonth, setSelectedMonth] = useState<Dayjs>(dayjs().startOf('month'));
    const [data, setData] = useState<DashboardData | null>(null);
    const [loading, setLoading] = useState(false);
    const [recalculating, setRecalculating] = useState(false);

    useEffect(() => {
        loadDashboardData();
    }, [selectedMonth]);

    const loadDashboardData = async () => {
        setLoading(true);
        const monthStr = selectedMonth.format('YYYY-MM-01');
        try {
            const response = await api.get('/analytics/dashboard', {
                params: { month: monthStr }
            });
            setData(response.data);
        } catch (error) {
            console.error('Failed to load dashboard data:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleRecalculate = async () => {
        setRecalculating(true);
        const monthStr = selectedMonth.format('YYYY-MM-01');
        try {
            await api.post('/analytics/monthly-summary/recalculate', {
                month: monthStr
            });
            await loadDashboardData();
        } catch (error) {
            console.error('Failed to recalculate:', error);
        } finally {
            setRecalculating(false);
        }
    };

    const formatCurrency = (value: number) => {
        return new Intl.NumberFormat('ja-JP', {
            style: 'currency',
            currency: 'JPY',
            minimumFractionDigits: 0
        }).format(value);
    };

    const formatPercent = (value: number) => {
        return `${value.toFixed(1)}%`;
    };

    const summary = data?.monthly_summary;
    const breakeven = data?.breakeven;

    return (
        <LocalizationProvider dateAdapter={AdapterDayjs} adapterLocale="ja">
            <Box sx={{ p: 3 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4">
                        経営ダッシュボード
                    </Typography>
                    <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
                        <DatePicker
                            label="対象月"
                            value={selectedMonth}
                            onChange={(date) => date && setSelectedMonth(date.startOf('month'))}
                            views={['year', 'month']}
                            format="YYYY年MM月"
                            slotProps={{ textField: { size: 'small' } }}
                        />
                        <Button
                            variant="outlined"
                            startIcon={recalculating ? <CircularProgress size={16} /> : <RefreshIcon />}
                            onClick={handleRecalculate}
                            disabled={recalculating}
                        >
                            再計算
                        </Button>
                    </Box>
                </Box>

                {loading && <LinearProgress sx={{ mb: 2 }} />}

                {!loading && !summary && (
                    <Alert severity="info" sx={{ mb: 3 }}>
                        {selectedMonth.format('YYYY年MM月')}のデータがありません。
                        原価データを登録後、「再計算」ボタンをクリックしてください。
                    </Alert>
                )}

                {summary && (
                    <>
                        {/* Main KPI Cards */}
                        <Grid container spacing={3} sx={{ mb: 3 }}>
                            <Grid size={{ xs: 12, md: 3 }}>
                                <Card sx={{ height: '100%' }}>
                                    <CardContent>
                                        <Typography color="text.secondary" gutterBottom>
                                            売上高
                                        </Typography>
                                        <Typography variant="h4" component="div">
                                            {formatCurrency(summary.total_revenue)}
                                        </Typography>
                                        <Box sx={{ mt: 1 }}>
                                            <Typography variant="body2" color="text.secondary">
                                                運送収入: {formatCurrency(summary.transport_revenue)}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                その他: {formatCurrency(summary.other_revenue)}
                                            </Typography>
                                        </Box>
                                    </CardContent>
                                </Card>
                            </Grid>
                            <Grid size={{ xs: 12, md: 3 }}>
                                <Card sx={{ height: '100%' }}>
                                    <CardContent>
                                        <Typography color="text.secondary" gutterBottom>
                                            粗利益
                                        </Typography>
                                        <Typography
                                            variant="h4"
                                            component="div"
                                            color={summary.gross_profit >= 0 ? 'success.main' : 'error.main'}
                                        >
                                            {formatCurrency(summary.gross_profit)}
                                        </Typography>
                                        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                                            変動費: {formatCurrency(summary.total_variable_cost)}
                                        </Typography>
                                    </CardContent>
                                </Card>
                            </Grid>
                            <Grid size={{ xs: 12, md: 3 }}>
                                <Card sx={{
                                    height: '100%',
                                    bgcolor: summary.operating_profit >= 0 ? 'success.light' : 'error.light'
                                }}>
                                    <CardContent>
                                        <Typography color="text.secondary" gutterBottom>
                                            営業利益
                                        </Typography>
                                        <Typography variant="h4" component="div">
                                            {formatCurrency(summary.operating_profit)}
                                        </Typography>
                                        <Box sx={{ display: 'flex', alignItems: 'center', mt: 1 }}>
                                            {summary.operating_profit >= 0 ? (
                                                <TrendingUpIcon color="success" />
                                            ) : (
                                                <TrendingDownIcon color="error" />
                                            )}
                                            <Typography variant="h6" sx={{ ml: 1 }}>
                                                {formatPercent(summary.operating_profit_rate)}
                                            </Typography>
                                        </Box>
                                    </CardContent>
                                </Card>
                            </Grid>
                            <Grid size={{ xs: 12, md: 3 }}>
                                <Card sx={{ height: '100%' }}>
                                    <CardContent>
                                        <Typography color="text.secondary" gutterBottom>
                                            損益分岐点
                                        </Typography>
                                        <Typography variant="h4" component="div">
                                            {formatCurrency(summary.breakeven_revenue)}
                                        </Typography>
                                        <Box sx={{ display: 'flex', alignItems: 'center', mt: 1 }}>
                                            {summary.safety_margin_rate >= 0 ? (
                                                <CheckCircleIcon color="success" sx={{ mr: 1 }} />
                                            ) : (
                                                <WarningIcon color="error" sx={{ mr: 1 }} />
                                            )}
                                            <Typography variant="body2">
                                                安全余裕率: {formatPercent(summary.safety_margin_rate)}
                                            </Typography>
                                        </Box>
                                    </CardContent>
                                </Card>
                            </Grid>
                        </Grid>

                        {/* Cost Breakdown */}
                        <Grid container spacing={3} sx={{ mb: 3 }}>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="h6" gutterBottom>
                                        変動費内訳
                                    </Typography>
                                    <TableContainer>
                                        <Table size="small">
                                            <TableBody>
                                                <TableRow>
                                                    <TableCell>燃料費</TableCell>
                                                    <TableCell align="right">{formatCurrency(summary.fuel_cost)}</TableCell>
                                                    <TableCell align="right">
                                                        {summary.total_variable_cost > 0 && formatPercent((summary.fuel_cost / summary.total_variable_cost) * 100)}
                                                    </TableCell>
                                                </TableRow>
                                                <TableRow>
                                                    <TableCell>高速代</TableCell>
                                                    <TableCell align="right">{formatCurrency(summary.toll_cost)}</TableCell>
                                                    <TableCell align="right">
                                                        {summary.total_variable_cost > 0 && formatPercent((summary.toll_cost / summary.total_variable_cost) * 100)}
                                                    </TableCell>
                                                </TableRow>
                                                <TableRow>
                                                    <TableCell>人件費（変動分）</TableCell>
                                                    <TableCell align="right">{formatCurrency(summary.driver_variable_cost)}</TableCell>
                                                    <TableCell align="right">
                                                        {summary.total_variable_cost > 0 && formatPercent((summary.driver_variable_cost / summary.total_variable_cost) * 100)}
                                                    </TableCell>
                                                </TableRow>
                                                <TableRow sx={{ bgcolor: 'grey.100' }}>
                                                    <TableCell><strong>合計</strong></TableCell>
                                                    <TableCell align="right"><strong>{formatCurrency(summary.total_variable_cost)}</strong></TableCell>
                                                    <TableCell></TableCell>
                                                </TableRow>
                                            </TableBody>
                                        </Table>
                                    </TableContainer>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="h6" gutterBottom>
                                        固定費内訳
                                    </Typography>
                                    <TableContainer>
                                        <Table size="small">
                                            <TableBody>
                                                <TableRow>
                                                    <TableCell>車両固定費</TableCell>
                                                    <TableCell align="right">{formatCurrency(summary.vehicle_fixed_cost)}</TableCell>
                                                    <TableCell align="right">
                                                        {summary.total_fixed_cost > 0 && formatPercent((summary.vehicle_fixed_cost / summary.total_fixed_cost) * 100)}
                                                    </TableCell>
                                                </TableRow>
                                                <TableRow>
                                                    <TableCell>人件費（固定分）</TableCell>
                                                    <TableCell align="right">{formatCurrency(summary.driver_fixed_cost)}</TableCell>
                                                    <TableCell align="right">
                                                        {summary.total_fixed_cost > 0 && formatPercent((summary.driver_fixed_cost / summary.total_fixed_cost) * 100)}
                                                    </TableCell>
                                                </TableRow>
                                                <TableRow>
                                                    <TableCell>管理固定費</TableCell>
                                                    <TableCell align="right">{formatCurrency(summary.admin_fixed_cost)}</TableCell>
                                                    <TableCell align="right">
                                                        {summary.total_fixed_cost > 0 && formatPercent((summary.admin_fixed_cost / summary.total_fixed_cost) * 100)}
                                                    </TableCell>
                                                </TableRow>
                                                <TableRow sx={{ bgcolor: 'grey.100' }}>
                                                    <TableCell><strong>合計</strong></TableCell>
                                                    <TableCell align="right"><strong>{formatCurrency(summary.total_fixed_cost)}</strong></TableCell>
                                                    <TableCell></TableCell>
                                                </TableRow>
                                            </TableBody>
                                        </Table>
                                    </TableContainer>
                                </Paper>
                            </Grid>
                        </Grid>

                        {/* KPI Metrics */}
                        <Grid container spacing={3} sx={{ mb: 3 }}>
                            <Grid size={{ xs: 12, md: 3 }}>
                                <Paper sx={{ p: 2, textAlign: 'center' }}>
                                    <VehicleIcon sx={{ fontSize: 40, color: 'primary.main' }} />
                                    <Typography variant="h4">{summary.vehicle_count}</Typography>
                                    <Typography color="text.secondary">稼働車両数</Typography>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 3 }}>
                                <Paper sx={{ p: 2, textAlign: 'center' }}>
                                    <DriverIcon sx={{ fontSize: 40, color: 'secondary.main' }} />
                                    <Typography variant="h4">{summary.driver_count}</Typography>
                                    <Typography color="text.secondary">稼働ドライバー数</Typography>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 3 }}>
                                <Paper sx={{ p: 2, textAlign: 'center' }}>
                                    <AssessmentIcon sx={{ fontSize: 40, color: 'info.main' }} />
                                    <Typography variant="h4">{summary.dispatch_count}</Typography>
                                    <Typography color="text.secondary">運行回数</Typography>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 3 }}>
                                <Paper sx={{ p: 2, textAlign: 'center' }}>
                                    <SpeedIcon sx={{ fontSize: 40, color: 'warning.main' }} />
                                    <Typography variant="h4">{summary.total_distance_km.toLocaleString()}</Typography>
                                    <Typography color="text.secondary">総走行距離 (km)</Typography>
                                </Paper>
                            </Grid>
                        </Grid>

                        {/* Additional KPIs */}
                        <Grid container spacing={3} sx={{ mb: 3 }}>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="h6" gutterBottom>
                                        単位あたり指標
                                    </Typography>
                                    <Grid container spacing={2}>
                                        <Grid size={{ xs: 6 }}>
                                            <Card variant="outlined">
                                                <CardContent>
                                                    <Typography color="text.secondary" variant="body2">
                                                        車両あたり売上
                                                    </Typography>
                                                    <Typography variant="h6">
                                                        {formatCurrency(summary.average_revenue_per_vehicle)}
                                                    </Typography>
                                                </CardContent>
                                            </Card>
                                        </Grid>
                                        <Grid size={{ xs: 6 }}>
                                            <Card variant="outlined">
                                                <CardContent>
                                                    <Typography color="text.secondary" variant="body2">
                                                        kmあたり売上
                                                    </Typography>
                                                    <Typography variant="h6">
                                                        {formatCurrency(summary.average_revenue_per_km)}
                                                    </Typography>
                                                </CardContent>
                                            </Card>
                                        </Grid>
                                    </Grid>
                                </Paper>
                            </Grid>

                            {breakeven && (
                                <Grid size={{ xs: 12, md: 6 }}>
                                    <Paper sx={{ p: 2 }}>
                                        <Typography variant="h6" gutterBottom>
                                            損益分岐点分析
                                        </Typography>
                                        <Box sx={{ mb: 2 }}>
                                            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                                <Typography variant="body2">売上進捗</Typography>
                                                <Typography variant="body2">
                                                    {formatCurrency(breakeven.current_revenue)} / {formatCurrency(breakeven.breakeven_revenue)}
                                                </Typography>
                                            </Box>
                                            <LinearProgress
                                                variant="determinate"
                                                value={Math.min((breakeven.current_revenue / breakeven.breakeven_revenue) * 100, 100)}
                                                sx={{ height: 10, borderRadius: 5 }}
                                                color={breakeven.is_profitable ? 'success' : 'warning'}
                                            />
                                        </Box>
                                        <Grid container spacing={2}>
                                            <Grid size={{ xs: 6 }}>
                                                <Typography color="text.secondary" variant="body2">
                                                    変動費率
                                                </Typography>
                                                <Typography variant="h6">
                                                    {formatPercent(breakeven.variable_cost_rate * 100)}
                                                </Typography>
                                            </Grid>
                                            <Grid size={{ xs: 6 }}>
                                                <Typography color="text.secondary" variant="body2">
                                                    安全余裕額
                                                </Typography>
                                                <Typography
                                                    variant="h6"
                                                    color={breakeven.safety_margin >= 0 ? 'success.main' : 'error.main'}
                                                >
                                                    {formatCurrency(breakeven.safety_margin)}
                                                </Typography>
                                            </Grid>
                                        </Grid>
                                    </Paper>
                                </Grid>
                            )}
                        </Grid>

                        {/* Top Performers */}
                        <Grid container spacing={3}>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="h6" gutterBottom>
                                        車両別利益ランキング
                                    </Typography>
                                    <TableContainer>
                                        <Table size="small">
                                            <TableHead>
                                                <TableRow>
                                                    <TableCell>順位</TableCell>
                                                    <TableCell>車両番号</TableCell>
                                                    <TableCell align="right">利益</TableCell>
                                                    <TableCell align="right">利益率</TableCell>
                                                </TableRow>
                                            </TableHead>
                                            <TableBody>
                                                {data?.top_vehicles?.map((v, index) => (
                                                    <TableRow key={index}>
                                                        <TableCell>
                                                            <Chip
                                                                label={index + 1}
                                                                size="small"
                                                                color={index === 0 ? 'warning' : 'default'}
                                                            />
                                                        </TableCell>
                                                        <TableCell>{v.vehicle_number}</TableCell>
                                                        <TableCell align="right">
                                                            <Typography
                                                                color={v.profit >= 0 ? 'success.main' : 'error.main'}
                                                            >
                                                                {formatCurrency(v.profit)}
                                                            </Typography>
                                                        </TableCell>
                                                        <TableCell align="right">
                                                            {formatPercent(v.profit_rate)}
                                                        </TableCell>
                                                    </TableRow>
                                                ))}
                                                {(!data?.top_vehicles || data.top_vehicles.length === 0) && (
                                                    <TableRow>
                                                        <TableCell colSpan={4} align="center">
                                                            データがありません
                                                        </TableCell>
                                                    </TableRow>
                                                )}
                                            </TableBody>
                                        </Table>
                                    </TableContainer>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="h6" gutterBottom>
                                        ドライバー別利益ランキング
                                    </Typography>
                                    <TableContainer>
                                        <Table size="small">
                                            <TableHead>
                                                <TableRow>
                                                    <TableCell>順位</TableCell>
                                                    <TableCell>ドライバー名</TableCell>
                                                    <TableCell align="right">利益貢献</TableCell>
                                                    <TableCell align="right">利益率</TableCell>
                                                </TableRow>
                                            </TableHead>
                                            <TableBody>
                                                {data?.top_drivers?.map((d, index) => (
                                                    <TableRow key={index}>
                                                        <TableCell>
                                                            <Chip
                                                                label={index + 1}
                                                                size="small"
                                                                color={index === 0 ? 'warning' : 'default'}
                                                            />
                                                        </TableCell>
                                                        <TableCell>{d.driver_name}</TableCell>
                                                        <TableCell align="right">
                                                            <Typography
                                                                color={d.profit >= 0 ? 'success.main' : 'error.main'}
                                                            >
                                                                {formatCurrency(d.profit)}
                                                            </Typography>
                                                        </TableCell>
                                                        <TableCell align="right">
                                                            {formatPercent(d.profit_rate)}
                                                        </TableCell>
                                                    </TableRow>
                                                ))}
                                                {(!data?.top_drivers || data.top_drivers.length === 0) && (
                                                    <TableRow>
                                                        <TableCell colSpan={4} align="center">
                                                            データがありません
                                                        </TableCell>
                                                    </TableRow>
                                                )}
                                            </TableBody>
                                        </Table>
                                    </TableContainer>
                                </Paper>
                            </Grid>
                        </Grid>
                    </>
                )}
            </Box>
        </LocalizationProvider>
    );
};

export default AnalyticsDashboard;
