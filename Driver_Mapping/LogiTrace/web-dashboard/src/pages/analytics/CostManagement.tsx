/**
 * CostManagement - 原価管理画面
 * 車両別・ドライバー別・会社固定費の月次コスト管理
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
    Button,
    TextField,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Grid,
    Card,
    CardContent,
    IconButton,
    Tooltip,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    InputAdornment,
    Alert,
    Chip
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    LocalShipping as VehicleIcon,
    Person as DriverIcon,
    Business as CompanyIcon,
    Calculate as CalculateIcon,
    Info as InfoIcon
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

interface VehicleCost {
    id?: number;
    vehicle_id: number;
    vehicle_number?: string;
    cost_month: string;
    fuel_cost: number;
    fuel_volume_liters: number;
    fuel_unit_price: number;
    toll_cost: number;
    maintenance_cost: number;
    tire_cost: number;
    insurance_cost: number;
    tax_cost: number;
    inspection_cost: number;
    depreciation_cost: number;
    lease_cost: number;
    parking_cost: number;
    other_cost: number;
    operating_days: number;
    total_distance_km: number;
    total_cost?: number;
}

interface DriverCost {
    id?: number;
    driver_id: number;
    driver_name?: string;
    cost_month: string;
    base_salary: number;
    overtime_pay: number;
    allowances: number;
    bonus: number;
    health_insurance: number;
    pension: number;
    employment_insurance: number;
    workers_comp: number;
    uniform_cost: number;
    training_cost: number;
    other_cost: number;
    working_days: number;
    total_working_hours: number;
    overtime_hours: number;
    total_labor_cost?: number;
}

interface FixedCost {
    id?: number;
    cost_month: string;
    rent_cost: number;
    utilities_cost: number;
    communication_cost: number;
    admin_salary: number;
    office_supplies: number;
    system_cost: number;
    liability_insurance: number;
    corporate_tax: number;
    professional_fees: number;
    other_fixed_cost: number;
    total_fixed_cost?: number;
}

interface Vehicle {
    id: number;
    vehicle_number: string;
}

interface Driver {
    id: number;
    name: string;
}

const CostManagement: React.FC = () => {
    const [tabValue, setTabValue] = useState(0);
    const [selectedMonth, setSelectedMonth] = useState<Dayjs>(dayjs().startOf('month'));
    const [vehicleCosts, setVehicleCosts] = useState<VehicleCost[]>([]);
    const [driverCosts, setDriverCosts] = useState<DriverCost[]>([]);
    const [fixedCost, setFixedCost] = useState<FixedCost | null>(null);
    const [vehicles, setVehicles] = useState<Vehicle[]>([]);
    const [drivers, setDrivers] = useState<Driver[]>([]);
    const [loading, setLoading] = useState(false);

    // Dialog states
    const [vehicleDialogOpen, setVehicleDialogOpen] = useState(false);
    const [driverDialogOpen, setDriverDialogOpen] = useState(false);
    const [fixedDialogOpen, setFixedDialogOpen] = useState(false);
    const [editingVehicleCost, setEditingVehicleCost] = useState<VehicleCost | null>(null);
    const [editingDriverCost, setEditingDriverCost] = useState<DriverCost | null>(null);

    useEffect(() => {
        loadMasterData();
    }, []);

    useEffect(() => {
        loadCostData();
    }, [selectedMonth]);

    const loadMasterData = async () => {
        try {
            // Load vehicles and drivers for dropdowns
            // These would come from existing endpoints
            const [vehicleRes, driverRes] = await Promise.all([
                api.get('/dashboard/vehicles'),
                api.get('/drivers')
            ]);
            setVehicles(vehicleRes.data || []);
            setDrivers(driverRes.data || []);
        } catch (error) {
            console.error('Failed to load master data:', error);
        }
    };

    const loadCostData = async () => {
        setLoading(true);
        const monthStr = selectedMonth.format('YYYY-MM-01');
        try {
            const [vehicleRes, driverRes, fixedRes] = await Promise.all([
                api.get('/analytics/costs/vehicles', { params: { month: monthStr } }),
                api.get('/analytics/costs/drivers', { params: { month: monthStr } }),
                api.get('/analytics/costs/fixed', { params: { month: monthStr } })
            ]);
            setVehicleCosts(vehicleRes.data || []);
            setDriverCosts(driverRes.data || []);
            setFixedCost(fixedRes.data || null);
        } catch (error) {
            console.error('Failed to load cost data:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleSaveVehicleCost = async () => {
        if (!editingVehicleCost) return;
        try {
            await api.post('/analytics/costs/vehicles', {
                ...editingVehicleCost,
                cost_month: selectedMonth.format('YYYY-MM-01')
            });
            setVehicleDialogOpen(false);
            setEditingVehicleCost(null);
            loadCostData();
        } catch (error) {
            console.error('Failed to save vehicle cost:', error);
        }
    };

    const handleSaveDriverCost = async () => {
        if (!editingDriverCost) return;
        try {
            await api.post('/analytics/costs/drivers', {
                ...editingDriverCost,
                cost_month: selectedMonth.format('YYYY-MM-01')
            });
            setDriverDialogOpen(false);
            setEditingDriverCost(null);
            loadCostData();
        } catch (error) {
            console.error('Failed to save driver cost:', error);
        }
    };

    const handleSaveFixedCost = async () => {
        if (!fixedCost) return;
        try {
            await api.post('/analytics/costs/fixed', {
                ...fixedCost,
                cost_month: selectedMonth.format('YYYY-MM-01')
            });
            setFixedDialogOpen(false);
            loadCostData();
        } catch (error) {
            console.error('Failed to save fixed cost:', error);
        }
    };

    const openVehicleCostDialog = (cost?: VehicleCost) => {
        if (cost) {
            setEditingVehicleCost(cost);
        } else {
            setEditingVehicleCost({
                vehicle_id: 0,
                cost_month: selectedMonth.format('YYYY-MM-01'),
                fuel_cost: 0,
                fuel_volume_liters: 0,
                fuel_unit_price: 0,
                toll_cost: 0,
                maintenance_cost: 0,
                tire_cost: 0,
                insurance_cost: 0,
                tax_cost: 0,
                inspection_cost: 0,
                depreciation_cost: 0,
                lease_cost: 0,
                parking_cost: 0,
                other_cost: 0,
                operating_days: 0,
                total_distance_km: 0
            });
        }
        setVehicleDialogOpen(true);
    };

    const openDriverCostDialog = (cost?: DriverCost) => {
        if (cost) {
            setEditingDriverCost(cost);
        } else {
            setEditingDriverCost({
                driver_id: 0,
                cost_month: selectedMonth.format('YYYY-MM-01'),
                base_salary: 0,
                overtime_pay: 0,
                allowances: 0,
                bonus: 0,
                health_insurance: 0,
                pension: 0,
                employment_insurance: 0,
                workers_comp: 0,
                uniform_cost: 0,
                training_cost: 0,
                other_cost: 0,
                working_days: 0,
                total_working_hours: 0,
                overtime_hours: 0
            });
        }
        setDriverDialogOpen(true);
    };

    const formatCurrency = (value: number) => {
        return new Intl.NumberFormat('ja-JP', {
            style: 'currency',
            currency: 'JPY',
            minimumFractionDigits: 0
        }).format(value);
    };

    // Calculate totals
    const totalVehicleCost = vehicleCosts.reduce((sum, v) => sum + (v.total_cost || 0), 0);
    const totalDriverCost = driverCosts.reduce((sum, d) => sum + (d.total_labor_cost || 0), 0);
    const totalFixedCost = fixedCost?.total_fixed_cost || 0;
    const grandTotal = totalVehicleCost + totalDriverCost + totalFixedCost;

    return (
        <LocalizationProvider dateAdapter={AdapterDayjs} adapterLocale="ja">
            <Box sx={{ p: 3 }}>
                <Typography variant="h4" gutterBottom>
                    原価管理
                </Typography>

                {/* Summary Cards */}
                <Grid container spacing={2} sx={{ mb: 3 }}>
                    <Grid size={{ xs: 12, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                    <VehicleIcon color="primary" sx={{ mr: 1 }} />
                                    <Typography variant="subtitle2" color="text.secondary">
                                        車両コスト合計
                                    </Typography>
                                </Box>
                                <Typography variant="h5">
                                    {formatCurrency(totalVehicleCost)}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    <Grid size={{ xs: 12, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                    <DriverIcon color="secondary" sx={{ mr: 1 }} />
                                    <Typography variant="subtitle2" color="text.secondary">
                                        人件費合計
                                    </Typography>
                                </Box>
                                <Typography variant="h5">
                                    {formatCurrency(totalDriverCost)}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    <Grid size={{ xs: 12, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                    <CompanyIcon color="info" sx={{ mr: 1 }} />
                                    <Typography variant="subtitle2" color="text.secondary">
                                        固定費合計
                                    </Typography>
                                </Box>
                                <Typography variant="h5">
                                    {formatCurrency(totalFixedCost)}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    <Grid size={{ xs: 12, md: 3 }}>
                        <Card sx={{ bgcolor: 'primary.main', color: 'white' }}>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                                    <CalculateIcon sx={{ mr: 1 }} />
                                    <Typography variant="subtitle2">
                                        総コスト
                                    </Typography>
                                </Box>
                                <Typography variant="h5">
                                    {formatCurrency(grandTotal)}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                </Grid>

                {/* Month Selector */}
                <Paper sx={{ p: 2, mb: 3 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                        <DatePicker
                            label="対象月"
                            value={selectedMonth}
                            onChange={(date) => date && setSelectedMonth(date.startOf('month'))}
                            views={['year', 'month']}
                            format="YYYY年MM月"
                            slotProps={{ textField: { size: 'small' } }}
                        />
                        <Chip
                            icon={<InfoIcon />}
                            label="国土交通省「トラック運送業の標準的運賃」指針準拠"
                            variant="outlined"
                            color="info"
                        />
                    </Box>
                </Paper>

                {/* Tabs */}
                <Paper sx={{ mb: 3 }}>
                    <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)}>
                        <Tab icon={<VehicleIcon />} label="車両別コスト" />
                        <Tab icon={<DriverIcon />} label="ドライバー別コスト" />
                        <Tab icon={<CompanyIcon />} label="会社固定費" />
                    </Tabs>

                    {/* Vehicle Costs Tab */}
                    <TabPanel value={tabValue} index={0}>
                        <Box sx={{ p: 2 }}>
                            <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
                                <Button
                                    variant="contained"
                                    startIcon={<AddIcon />}
                                    onClick={() => openVehicleCostDialog()}
                                >
                                    車両コスト追加
                                </Button>
                            </Box>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>車両番号</TableCell>
                                            <TableCell align="right">燃料費</TableCell>
                                            <TableCell align="right">高速代</TableCell>
                                            <TableCell align="right">整備費</TableCell>
                                            <TableCell align="right">保険料</TableCell>
                                            <TableCell align="right">減価償却</TableCell>
                                            <TableCell align="right">その他</TableCell>
                                            <TableCell align="right">合計</TableCell>
                                            <TableCell align="right">稼働日数</TableCell>
                                            <TableCell align="center">操作</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {vehicleCosts.map((cost) => (
                                            <TableRow key={cost.id || cost.vehicle_id}>
                                                <TableCell>{cost.vehicle_number || `車両ID: ${cost.vehicle_id}`}</TableCell>
                                                <TableCell align="right">{formatCurrency(cost.fuel_cost)}</TableCell>
                                                <TableCell align="right">{formatCurrency(cost.toll_cost)}</TableCell>
                                                <TableCell align="right">{formatCurrency(cost.maintenance_cost)}</TableCell>
                                                <TableCell align="right">{formatCurrency(cost.insurance_cost)}</TableCell>
                                                <TableCell align="right">{formatCurrency(cost.depreciation_cost)}</TableCell>
                                                <TableCell align="right">{formatCurrency(cost.other_cost)}</TableCell>
                                                <TableCell align="right" sx={{ fontWeight: 'bold' }}>
                                                    {formatCurrency(cost.total_cost || 0)}
                                                </TableCell>
                                                <TableCell align="right">{cost.operating_days}日</TableCell>
                                                <TableCell align="center">
                                                    <IconButton
                                                        size="small"
                                                        onClick={() => openVehicleCostDialog(cost)}
                                                    >
                                                        <EditIcon />
                                                    </IconButton>
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                        {vehicleCosts.length === 0 && (
                                            <TableRow>
                                                <TableCell colSpan={10} align="center">
                                                    データがありません
                                                </TableCell>
                                            </TableRow>
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </Box>
                    </TabPanel>

                    {/* Driver Costs Tab */}
                    <TabPanel value={tabValue} index={1}>
                        <Box sx={{ p: 2 }}>
                            <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
                                <Button
                                    variant="contained"
                                    startIcon={<AddIcon />}
                                    onClick={() => openDriverCostDialog()}
                                >
                                    ドライバーコスト追加
                                </Button>
                            </Box>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>ドライバー名</TableCell>
                                            <TableCell align="right">基本給</TableCell>
                                            <TableCell align="right">時間外手当</TableCell>
                                            <TableCell align="right">各種手当</TableCell>
                                            <TableCell align="right">法定福利費</TableCell>
                                            <TableCell align="right">その他</TableCell>
                                            <TableCell align="right">合計</TableCell>
                                            <TableCell align="right">勤務日数</TableCell>
                                            <TableCell align="center">操作</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {driverCosts.map((cost) => {
                                            const socialInsurance = cost.health_insurance + cost.pension +
                                                cost.employment_insurance + cost.workers_comp;
                                            return (
                                                <TableRow key={cost.id || cost.driver_id}>
                                                    <TableCell>{cost.driver_name || `ドライバーID: ${cost.driver_id}`}</TableCell>
                                                    <TableCell align="right">{formatCurrency(cost.base_salary)}</TableCell>
                                                    <TableCell align="right">{formatCurrency(cost.overtime_pay)}</TableCell>
                                                    <TableCell align="right">{formatCurrency(cost.allowances)}</TableCell>
                                                    <TableCell align="right">{formatCurrency(socialInsurance)}</TableCell>
                                                    <TableCell align="right">{formatCurrency(cost.other_cost)}</TableCell>
                                                    <TableCell align="right" sx={{ fontWeight: 'bold' }}>
                                                        {formatCurrency(cost.total_labor_cost || 0)}
                                                    </TableCell>
                                                    <TableCell align="right">{cost.working_days}日</TableCell>
                                                    <TableCell align="center">
                                                        <IconButton
                                                            size="small"
                                                            onClick={() => openDriverCostDialog(cost)}
                                                        >
                                                            <EditIcon />
                                                        </IconButton>
                                                    </TableCell>
                                                </TableRow>
                                            );
                                        })}
                                        {driverCosts.length === 0 && (
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

                    {/* Fixed Costs Tab */}
                    <TabPanel value={tabValue} index={2}>
                        <Box sx={{ p: 2 }}>
                            <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
                                <Button
                                    variant="contained"
                                    startIcon={fixedCost ? <EditIcon /> : <AddIcon />}
                                    onClick={() => {
                                        if (!fixedCost) {
                                            setFixedCost({
                                                cost_month: selectedMonth.format('YYYY-MM-01'),
                                                rent_cost: 0,
                                                utilities_cost: 0,
                                                communication_cost: 0,
                                                admin_salary: 0,
                                                office_supplies: 0,
                                                system_cost: 0,
                                                liability_insurance: 0,
                                                corporate_tax: 0,
                                                professional_fees: 0,
                                                other_fixed_cost: 0
                                            });
                                        }
                                        setFixedDialogOpen(true);
                                    }}
                                >
                                    {fixedCost ? '固定費編集' : '固定費登録'}
                                </Button>
                            </Box>
                            {fixedCost ? (
                                <Grid container spacing={2}>
                                    <Grid size={{ xs: 12, md: 4 }}>
                                        <Card variant="outlined">
                                            <CardContent>
                                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                                    施設費
                                                </Typography>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                                    <Typography>事務所・車庫賃料</Typography>
                                                    <Typography>{formatCurrency(fixedCost.rent_cost)}</Typography>
                                                </Box>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                                    <Typography>光熱費</Typography>
                                                    <Typography>{formatCurrency(fixedCost.utilities_cost)}</Typography>
                                                </Box>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                                                    <Typography>通信費</Typography>
                                                    <Typography>{formatCurrency(fixedCost.communication_cost)}</Typography>
                                                </Box>
                                            </CardContent>
                                        </Card>
                                    </Grid>
                                    <Grid size={{ xs: 12, md: 4 }}>
                                        <Card variant="outlined">
                                            <CardContent>
                                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                                    管理費
                                                </Typography>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                                    <Typography>管理部門人件費</Typography>
                                                    <Typography>{formatCurrency(fixedCost.admin_salary)}</Typography>
                                                </Box>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                                    <Typography>事務用品費</Typography>
                                                    <Typography>{formatCurrency(fixedCost.office_supplies)}</Typography>
                                                </Box>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                                                    <Typography>システム費</Typography>
                                                    <Typography>{formatCurrency(fixedCost.system_cost)}</Typography>
                                                </Box>
                                            </CardContent>
                                        </Card>
                                    </Grid>
                                    <Grid size={{ xs: 12, md: 4 }}>
                                        <Card variant="outlined">
                                            <CardContent>
                                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                                    保険・税金・その他
                                                </Typography>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                                    <Typography>賠償責任保険</Typography>
                                                    <Typography>{formatCurrency(fixedCost.liability_insurance)}</Typography>
                                                </Box>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                                    <Typography>法人税等</Typography>
                                                    <Typography>{formatCurrency(fixedCost.corporate_tax)}</Typography>
                                                </Box>
                                                <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                                                    <Typography>顧問料</Typography>
                                                    <Typography>{formatCurrency(fixedCost.professional_fees)}</Typography>
                                                </Box>
                                            </CardContent>
                                        </Card>
                                    </Grid>
                                </Grid>
                            ) : (
                                <Alert severity="info">
                                    {selectedMonth.format('YYYY年MM月')}の固定費が未登録です。
                                </Alert>
                            )}
                        </Box>
                    </TabPanel>
                </Paper>

                {/* Vehicle Cost Dialog */}
                <Dialog open={vehicleDialogOpen} onClose={() => setVehicleDialogOpen(false)} maxWidth="md" fullWidth>
                    <DialogTitle>車両別コスト登録</DialogTitle>
                    <DialogContent>
                        <Grid container spacing={2} sx={{ mt: 1 }}>
                            <Grid size={{ xs: 12 }}>
                                <FormControl fullWidth>
                                    <InputLabel>車両</InputLabel>
                                    <Select
                                        value={editingVehicleCost?.vehicle_id || 0}
                                        label="車両"
                                        onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, vehicle_id: e.target.value as number} : null)}
                                    >
                                        {vehicles.map(v => (
                                            <MenuItem key={v.id} value={v.id}>{v.vehicle_number}</MenuItem>
                                        ))}
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">燃料費</Typography>
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="燃料費"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.fuel_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, fuel_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="給油量"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.fuel_volume_liters || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, fuel_volume_liters: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">L</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="単価"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.fuel_unit_price || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, fuel_unit_price: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円/L</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">道路・維持費</Typography>
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="高速代"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.toll_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, toll_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="整備・修理費"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.maintenance_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, maintenance_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="タイヤ費"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.tire_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, tire_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">保険・税金</Typography>
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="保険料（月割）"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.insurance_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, insurance_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="自動車税・重量税（月割）"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.tax_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, tax_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="車検費用（月割）"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.inspection_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, inspection_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">減価償却・リース</Typography>
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="減価償却費"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.depreciation_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, depreciation_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="リース費用"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.lease_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, lease_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="駐車場代"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.parking_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, parking_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">稼働データ</Typography>
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="稼働日数"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.operating_days || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, operating_days: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">日</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="走行距離"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.total_distance_km || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, total_distance_km: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">km</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="その他費用"
                                    type="number"
                                    fullWidth
                                    value={editingVehicleCost?.other_cost || 0}
                                    onChange={(e) => setEditingVehicleCost(prev => prev ? {...prev, other_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                        </Grid>
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => setVehicleDialogOpen(false)}>キャンセル</Button>
                        <Button variant="contained" onClick={handleSaveVehicleCost}>保存</Button>
                    </DialogActions>
                </Dialog>

                {/* Driver Cost Dialog */}
                <Dialog open={driverDialogOpen} onClose={() => setDriverDialogOpen(false)} maxWidth="md" fullWidth>
                    <DialogTitle>ドライバー別コスト登録</DialogTitle>
                    <DialogContent>
                        <Grid container spacing={2} sx={{ mt: 1 }}>
                            <Grid size={{ xs: 12 }}>
                                <FormControl fullWidth>
                                    <InputLabel>ドライバー</InputLabel>
                                    <Select
                                        value={editingDriverCost?.driver_id || 0}
                                        label="ドライバー"
                                        onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, driver_id: e.target.value as number} : null)}
                                    >
                                        {drivers.map(d => (
                                            <MenuItem key={d.id} value={d.id}>{d.name}</MenuItem>
                                        ))}
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">給与</Typography>
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="基本給"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.base_salary || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, base_salary: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="時間外手当"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.overtime_pay || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, overtime_pay: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="各種手当"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.allowances || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, allowances: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="賞与（月割）"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.bonus || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, bonus: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">法定福利費</Typography>
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="健康保険"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.health_insurance || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, health_insurance: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="厚生年金"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.pension || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, pension: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="雇用保険"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.employment_insurance || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, employment_insurance: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="労災保険"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.workers_comp || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, workers_comp: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">勤務データ</Typography>
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="勤務日数"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.working_days || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, working_days: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">日</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="総労働時間"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.total_working_hours || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, total_working_hours: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">時間</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="時間外労働"
                                    type="number"
                                    fullWidth
                                    value={editingDriverCost?.overtime_hours || 0}
                                    onChange={(e) => setEditingDriverCost(prev => prev ? {...prev, overtime_hours: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">時間</InputAdornment> }}
                                />
                            </Grid>
                        </Grid>
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => setDriverDialogOpen(false)}>キャンセル</Button>
                        <Button variant="contained" onClick={handleSaveDriverCost}>保存</Button>
                    </DialogActions>
                </Dialog>

                {/* Fixed Cost Dialog */}
                <Dialog open={fixedDialogOpen} onClose={() => setFixedDialogOpen(false)} maxWidth="md" fullWidth>
                    <DialogTitle>会社固定費登録</DialogTitle>
                    <DialogContent>
                        <Grid container spacing={2} sx={{ mt: 1 }}>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">施設費</Typography>
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="事務所・車庫賃料"
                                    type="number"
                                    fullWidth
                                    value={fixedCost?.rent_cost || 0}
                                    onChange={(e) => setFixedCost(prev => prev ? {...prev, rent_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="光熱費"
                                    type="number"
                                    fullWidth
                                    value={fixedCost?.utilities_cost || 0}
                                    onChange={(e) => setFixedCost(prev => prev ? {...prev, utilities_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="通信費"
                                    type="number"
                                    fullWidth
                                    value={fixedCost?.communication_cost || 0}
                                    onChange={(e) => setFixedCost(prev => prev ? {...prev, communication_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">管理費</Typography>
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="管理部門人件費"
                                    type="number"
                                    fullWidth
                                    value={fixedCost?.admin_salary || 0}
                                    onChange={(e) => setFixedCost(prev => prev ? {...prev, admin_salary: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="事務用品費"
                                    type="number"
                                    fullWidth
                                    value={fixedCost?.office_supplies || 0}
                                    onChange={(e) => setFixedCost(prev => prev ? {...prev, office_supplies: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 4 }}>
                                <TextField
                                    label="システム費（LogiTrace等）"
                                    type="number"
                                    fullWidth
                                    value={fixedCost?.system_cost || 0}
                                    onChange={(e) => setFixedCost(prev => prev ? {...prev, system_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12 }}>
                                <Typography variant="subtitle2" color="text.secondary">保険・税金・その他</Typography>
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="賠償責任保険"
                                    type="number"
                                    fullWidth
                                    value={fixedCost?.liability_insurance || 0}
                                    onChange={(e) => setFixedCost(prev => prev ? {...prev, liability_insurance: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="法人税等（月割）"
                                    type="number"
                                    fullWidth
                                    value={fixedCost?.corporate_tax || 0}
                                    onChange={(e) => setFixedCost(prev => prev ? {...prev, corporate_tax: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="顧問料（税理士等）"
                                    type="number"
                                    fullWidth
                                    value={fixedCost?.professional_fees || 0}
                                    onChange={(e) => setFixedCost(prev => prev ? {...prev, professional_fees: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                            <Grid size={{ xs: 3 }}>
                                <TextField
                                    label="その他固定費"
                                    type="number"
                                    fullWidth
                                    value={fixedCost?.other_fixed_cost || 0}
                                    onChange={(e) => setFixedCost(prev => prev ? {...prev, other_fixed_cost: Number(e.target.value)} : null)}
                                    InputProps={{ endAdornment: <InputAdornment position="end">円</InputAdornment> }}
                                />
                            </Grid>
                        </Grid>
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => setFixedDialogOpen(false)}>キャンセル</Button>
                        <Button variant="contained" onClick={handleSaveFixedCost}>保存</Button>
                    </DialogActions>
                </Dialog>
            </Box>
        </LocalizationProvider>
    );
};

export default CostManagement;
