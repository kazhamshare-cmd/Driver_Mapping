/**
 * ProfitAnalysis - 損益分析画面
 * 車両別・ドライバー別・荷主別の損益分析
 */

import React, { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Tabs,
    Tab,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Grid,
    Card,
    CardContent,
    LinearProgress,
    Chip,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Alert
} from '@mui/material';
import {
    LocalShipping as VehicleIcon,
    Person as DriverIcon,
    Business as ShipperIcon,
    TrendingUp as ProfitIcon,
    TrendingDown as LossIcon,
    ShowChart as ChartIcon,
    Speed as UtilizationIcon
} from '@mui/icons-material';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDayjs } from '@mui/x-date-pickers/AdapterDayjs';
import dayjs, { Dayjs } from 'dayjs';
import 'dayjs/locale/ja';
import api from '../../services/api';

interface TabPanelProps {
    children?: React.ReactNode;
    index: number;
    value: number;
}

function TabPanel(props: TabPanelProps) {
    const { children, value, index, ...other } = props;
    return (
        <div role="tabpanel" hidden={value !== index} {...other}>
            {value === index && <Box sx={{ pt: 2 }}>{children}</Box>}
        </div>
    );
}

interface VehicleProfit {
    vehicle_id: number;
    vehicle_number: string;
    vehicle_type: string;
    revenue: number;
    cost: number;
    profit: number;
    profit_rate: number;
    operating_days: number;
    total_distance_km: number;
    cost_per_km: number;
}

interface DriverProfit {
    driver_id: number;
    driver_name: string;
    revenue: number;
    cost: number;
    profit: number;
    profit_rate: number;
    working_days: number;
    total_working_hours: number;
    revenue_per_day: number;
}

interface ShipperProfit {
    shipper_id: number;
    shipper_name: string;
    dispatch_count: number;
    total_revenue: number;
    total_cost: number;
    total_profit: number;
    profit_rate: number;
    total_distance_km: number;
}

interface UtilizationData {
    vehicle_id: number;
    vehicle_number: string;
    operating_days: number;
    business_days: number;
    utilization_rate: number;
    dispatch_count: number;
    total_distance_km: number;
    total_hours: number;
}

const ProfitAnalysis: React.FC = () => {
    const [tabValue, setTabValue] = useState(0);
    const [selectedMonth, setSelectedMonth] = useState<Dayjs>(dayjs().startOf('month'));
    const [vehicleProfits, setVehicleProfits] = useState<VehicleProfit[]>([]);
    const [driverProfits, setDriverProfits] = useState<DriverProfit[]>([]);
    const [shipperProfits, setShipperProfits] = useState<ShipperProfit[]>([]);
    const [utilization, setUtilization] = useState<UtilizationData[]>([]);
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        loadData();
    }, [selectedMonth]);

    const loadData = async () => {
        setLoading(true);
        const monthStr = selectedMonth.format('YYYY-MM-01');
        try {
            const [vehicleRes, driverRes, shipperRes, utilizationRes] = await Promise.all([
                api.get('/analytics/profit/vehicles', { params: { month: monthStr } }),
                api.get('/analytics/profit/drivers', { params: { month: monthStr } }),
                api.get('/analytics/profit/shippers', { params: { month: monthStr } }),
                api.get('/analytics/utilization', { params: { month: monthStr } })
            ]);
            setVehicleProfits(vehicleRes.data || []);
            setDriverProfits(driverRes.data || []);
            setShipperProfits(shipperRes.data || []);
            setUtilization(utilizationRes.data || []);
        } catch (error) {
            console.error('Failed to load profit data:', error);
        } finally {
            setLoading(false);
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

    const getProfitColor = (profit: number) => {
        if (profit > 0) return 'success';
        if (profit < 0) return 'error';
        return 'default';
    };

    const getProfitRateColor = (rate: number) => {
        if (rate >= 20) return 'success';
        if (rate >= 10) return 'warning';
        if (rate >= 0) return 'default';
        return 'error';
    };

    // Calculate summary
    const totalVehicleRevenue = vehicleProfits.reduce((sum, v) => sum + v.revenue, 0);
    const totalVehicleCost = vehicleProfits.reduce((sum, v) => sum + v.cost, 0);
    const totalVehicleProfit = vehicleProfits.reduce((sum, v) => sum + v.profit, 0);
    const avgVehicleProfitRate = totalVehicleRevenue > 0
        ? (totalVehicleProfit / totalVehicleRevenue) * 100
        : 0;

    const avgUtilization = utilization.length > 0
        ? utilization.reduce((sum, u) => sum + u.utilization_rate, 0) / utilization.length
        : 0;

    return (
        <LocalizationProvider dateAdapter={AdapterDayjs} adapterLocale="ja">
            <Box sx={{ p: 3 }}>
                <Typography variant="h4" gutterBottom>
                    損益分析
                </Typography>

                {/* Summary Cards */}
                <Grid container spacing={2} sx={{ mb: 3 }}>
                    <Grid size={{ xs: 12, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                    <ChartIcon color="primary" sx={{ mr: 1 }} />
                                    <Typography variant="subtitle2" color="text.secondary">
                                        総売上
                                    </Typography>
                                </Box>
                                <Typography variant="h5">
                                    {formatCurrency(totalVehicleRevenue)}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    <Grid size={{ xs: 12, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                    {totalVehicleProfit >= 0 ? (
                                        <ProfitIcon color="success" sx={{ mr: 1 }} />
                                    ) : (
                                        <LossIcon color="error" sx={{ mr: 1 }} />
                                    )}
                                    <Typography variant="subtitle2" color="text.secondary">
                                        総利益
                                    </Typography>
                                </Box>
                                <Typography
                                    variant="h5"
                                    color={totalVehicleProfit >= 0 ? 'success.main' : 'error.main'}
                                >
                                    {formatCurrency(totalVehicleProfit)}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    <Grid size={{ xs: 12, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                    <ChartIcon color="info" sx={{ mr: 1 }} />
                                    <Typography variant="subtitle2" color="text.secondary">
                                        平均利益率
                                    </Typography>
                                </Box>
                                <Typography variant="h5">
                                    {formatPercent(avgVehicleProfitRate)}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    <Grid size={{ xs: 12, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                    <UtilizationIcon color="warning" sx={{ mr: 1 }} />
                                    <Typography variant="subtitle2" color="text.secondary">
                                        平均稼働率
                                    </Typography>
                                </Box>
                                <Typography variant="h5">
                                    {formatPercent(avgUtilization)}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                </Grid>

                {/* Month Selector */}
                <Paper sx={{ p: 2, mb: 3 }}>
                    <DatePicker
                        label="対象月"
                        value={selectedMonth}
                        onChange={(date) => date && setSelectedMonth(date.startOf('month'))}
                        views={['year', 'month']}
                        format="YYYY年MM月"
                        slotProps={{ textField: { size: 'small' } }}
                    />
                </Paper>

                {loading && <LinearProgress sx={{ mb: 2 }} />}

                {/* Tabs */}
                <Paper>
                    <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)}>
                        <Tab icon={<VehicleIcon />} label="車両別損益" />
                        <Tab icon={<DriverIcon />} label="ドライバー別損益" />
                        <Tab icon={<ShipperIcon />} label="荷主別損益" />
                        <Tab icon={<UtilizationIcon />} label="稼働率" />
                    </Tabs>

                    {/* Vehicle Profit Tab */}
                    <TabPanel value={tabValue} index={0}>
                        <Box sx={{ p: 2 }}>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>車両番号</TableCell>
                                            <TableCell>車種</TableCell>
                                            <TableCell align="right">売上</TableCell>
                                            <TableCell align="right">コスト</TableCell>
                                            <TableCell align="right">利益</TableCell>
                                            <TableCell align="right">利益率</TableCell>
                                            <TableCell align="right">稼働日数</TableCell>
                                            <TableCell align="right">走行距離</TableCell>
                                            <TableCell align="right">km単価</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {vehicleProfits.map((v) => (
                                            <TableRow key={v.vehicle_id}>
                                                <TableCell>{v.vehicle_number}</TableCell>
                                                <TableCell>{v.vehicle_type}</TableCell>
                                                <TableCell align="right">{formatCurrency(v.revenue)}</TableCell>
                                                <TableCell align="right">{formatCurrency(v.cost)}</TableCell>
                                                <TableCell align="right">
                                                    <Chip
                                                        label={formatCurrency(v.profit)}
                                                        color={getProfitColor(v.profit)}
                                                        size="small"
                                                    />
                                                </TableCell>
                                                <TableCell align="right">
                                                    <Chip
                                                        label={formatPercent(v.profit_rate)}
                                                        color={getProfitRateColor(v.profit_rate)}
                                                        size="small"
                                                        variant="outlined"
                                                    />
                                                </TableCell>
                                                <TableCell align="right">{v.operating_days}日</TableCell>
                                                <TableCell align="right">{v.total_distance_km.toLocaleString()}km</TableCell>
                                                <TableCell align="right">{formatCurrency(v.cost_per_km)}/km</TableCell>
                                            </TableRow>
                                        ))}
                                        {vehicleProfits.length === 0 && (
                                            <TableRow>
                                                <TableCell colSpan={9} align="center">
                                                    データがありません
                                                </TableCell>
                                            </TableRow>
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </Box>
                    </TabPanel>

                    {/* Driver Profit Tab */}
                    <TabPanel value={tabValue} index={1}>
                        <Box sx={{ p: 2 }}>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>ドライバー名</TableCell>
                                            <TableCell align="right">売上</TableCell>
                                            <TableCell align="right">人件費</TableCell>
                                            <TableCell align="right">利益貢献</TableCell>
                                            <TableCell align="right">利益率</TableCell>
                                            <TableCell align="right">勤務日数</TableCell>
                                            <TableCell align="right">労働時間</TableCell>
                                            <TableCell align="right">日当たり売上</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {driverProfits.map((d) => (
                                            <TableRow key={d.driver_id}>
                                                <TableCell>{d.driver_name}</TableCell>
                                                <TableCell align="right">{formatCurrency(d.revenue)}</TableCell>
                                                <TableCell align="right">{formatCurrency(d.cost)}</TableCell>
                                                <TableCell align="right">
                                                    <Chip
                                                        label={formatCurrency(d.profit)}
                                                        color={getProfitColor(d.profit)}
                                                        size="small"
                                                    />
                                                </TableCell>
                                                <TableCell align="right">
                                                    <Chip
                                                        label={formatPercent(d.profit_rate)}
                                                        color={getProfitRateColor(d.profit_rate)}
                                                        size="small"
                                                        variant="outlined"
                                                    />
                                                </TableCell>
                                                <TableCell align="right">{d.working_days}日</TableCell>
                                                <TableCell align="right">{d.total_working_hours.toFixed(1)}h</TableCell>
                                                <TableCell align="right">{formatCurrency(d.revenue_per_day)}</TableCell>
                                            </TableRow>
                                        ))}
                                        {driverProfits.length === 0 && (
                                            <TableRow>
                                                <TableCell colSpan={8} align="center">
                                                    データがありません
                                                </TableCell>
                                            </TableRow>
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </Box>
                    </TabPanel>

                    {/* Shipper Profit Tab */}
                    <TabPanel value={tabValue} index={2}>
                        <Box sx={{ p: 2 }}>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>荷主名</TableCell>
                                            <TableCell align="right">運行回数</TableCell>
                                            <TableCell align="right">売上</TableCell>
                                            <TableCell align="right">直接費</TableCell>
                                            <TableCell align="right">粗利</TableCell>
                                            <TableCell align="right">粗利率</TableCell>
                                            <TableCell align="right">総走行距離</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {shipperProfits.map((s) => (
                                            <TableRow key={s.shipper_id}>
                                                <TableCell>{s.shipper_name}</TableCell>
                                                <TableCell align="right">{s.dispatch_count}件</TableCell>
                                                <TableCell align="right">{formatCurrency(s.total_revenue)}</TableCell>
                                                <TableCell align="right">{formatCurrency(s.total_cost)}</TableCell>
                                                <TableCell align="right">
                                                    <Chip
                                                        label={formatCurrency(s.total_profit)}
                                                        color={getProfitColor(s.total_profit)}
                                                        size="small"
                                                    />
                                                </TableCell>
                                                <TableCell align="right">
                                                    <Chip
                                                        label={formatPercent(s.profit_rate)}
                                                        color={getProfitRateColor(s.profit_rate)}
                                                        size="small"
                                                        variant="outlined"
                                                    />
                                                </TableCell>
                                                <TableCell align="right">{s.total_distance_km.toLocaleString()}km</TableCell>
                                            </TableRow>
                                        ))}
                                        {shipperProfits.length === 0 && (
                                            <TableRow>
                                                <TableCell colSpan={7} align="center">
                                                    データがありません
                                                </TableCell>
                                            </TableRow>
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </Box>
                    </TabPanel>

                    {/* Utilization Tab */}
                    <TabPanel value={tabValue} index={3}>
                        <Box sx={{ p: 2 }}>
                            <Alert severity="info" sx={{ mb: 2 }}>
                                稼働率 = 実稼働日数 / 営業日数（21日想定）× 100
                            </Alert>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>車両番号</TableCell>
                                            <TableCell align="right">稼働日数</TableCell>
                                            <TableCell align="right">営業日数</TableCell>
                                            <TableCell>稼働率</TableCell>
                                            <TableCell align="right">運行回数</TableCell>
                                            <TableCell align="right">走行距離</TableCell>
                                            <TableCell align="right">稼働時間</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {utilization.map((u) => (
                                            <TableRow key={u.vehicle_id}>
                                                <TableCell>{u.vehicle_number}</TableCell>
                                                <TableCell align="right">{u.operating_days}日</TableCell>
                                                <TableCell align="right">{u.business_days}日</TableCell>
                                                <TableCell>
                                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                        <LinearProgress
                                                            variant="determinate"
                                                            value={Math.min(u.utilization_rate, 100)}
                                                            sx={{ width: 100, height: 8, borderRadius: 4 }}
                                                            color={
                                                                u.utilization_rate >= 80 ? 'success' :
                                                                u.utilization_rate >= 60 ? 'warning' : 'error'
                                                            }
                                                        />
                                                        <Typography variant="body2">
                                                            {formatPercent(u.utilization_rate)}
                                                        </Typography>
                                                    </Box>
                                                </TableCell>
                                                <TableCell align="right">{u.dispatch_count}件</TableCell>
                                                <TableCell align="right">{u.total_distance_km.toLocaleString()}km</TableCell>
                                                <TableCell align="right">{u.total_hours.toFixed(1)}h</TableCell>
                                            </TableRow>
                                        ))}
                                        {utilization.length === 0 && (
                                            <TableRow>
                                                <TableCell colSpan={7} align="center">
                                                    データがありません
                                                </TableCell>
                                            </TableRow>
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </Box>
                    </TabPanel>
                </Paper>
            </Box>
        </LocalizationProvider>
    );
};

export default ProfitAnalysis;
