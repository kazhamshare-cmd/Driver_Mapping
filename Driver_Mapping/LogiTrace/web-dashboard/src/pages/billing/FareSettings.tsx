/**
 * Fare Settings - 運賃設定画面
 */

import { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Button,
    IconButton,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Grid,
    Chip,
    Switch,
    FormControlLabel,
    InputAdornment,
    Alert,
    CircularProgress,
    Accordion,
    AccordionSummary,
    AccordionDetails,
    Divider
} from '@mui/material';
import {
    Add,
    Edit,
    Delete,
    ExpandMore,
    LocalShipping,
    AccessTime,
    Route,
    Calculate
} from '@mui/icons-material';

interface FareMaster {
    id: number;
    shipper_id: number | null;
    shipper_name: string | null;
    name: string;
    fare_type: 'distance' | 'time' | 'fixed' | 'mixed';
    base_distance_km: number;
    base_rate: number;
    rate_per_km: number;
    base_time_hours: number;
    rate_per_hour: number;
    fixed_rate: number;
    night_surcharge_rate: number;
    early_morning_surcharge_rate: number;
    holiday_surcharge_rate: number;
    loading_fee: number;
    unloading_fee: number;
    waiting_fee_per_hour: number;
    vehicle_type_coefficients: Record<string, number>;
    effective_from: string;
    effective_to: string | null;
    is_active: boolean;
}

interface Shipper {
    id: number;
    name: string;
}

const fareTypeLabels: Record<string, { label: string; icon: any }> = {
    distance: { label: '距離制', icon: <Route /> },
    time: { label: '時間制', icon: <AccessTime /> },
    fixed: { label: '固定運賃', icon: <Calculate /> },
    mixed: { label: '複合制', icon: <LocalShipping /> }
};

const defaultFareMaster: Partial<FareMaster> = {
    name: '',
    fare_type: 'distance',
    base_distance_km: 50,
    base_rate: 30000,
    rate_per_km: 200,
    base_time_hours: 4,
    rate_per_hour: 5000,
    fixed_rate: 0,
    night_surcharge_rate: 25,
    early_morning_surcharge_rate: 25,
    holiday_surcharge_rate: 35,
    loading_fee: 0,
    unloading_fee: 0,
    waiting_fee_per_hour: 3000,
    vehicle_type_coefficients: {},
    effective_from: new Date().toISOString().split('T')[0],
    is_active: true
};

const FareSettings = () => {
    const [fareMasters, setFareMasters] = useState<FareMaster[]>([]);
    const [shippers, setShippers] = useState<Shipper[]>([]);
    const [loading, setLoading] = useState(true);
    const [dialogOpen, setDialogOpen] = useState(false);
    const [editingFare, setEditingFare] = useState<Partial<FareMaster> | null>(null);
    const [error, setError] = useState<string | null>(null);

    const user = JSON.parse(localStorage.getItem('user') || '{}');

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [faresRes, shippersRes] = await Promise.all([
                fetch(`/api/invoices/fare-masters?companyId=${user.companyId}`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }),
                fetch(`/api/shippers?companyId=${user.companyId}`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                })
            ]);

            if (faresRes.ok) setFareMasters(await faresRes.json());
            if (shippersRes.ok) setShippers(await shippersRes.json());
        } catch (err) {
            setError('データの取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const handleSave = async () => {
        if (!editingFare?.name) {
            setError('運賃名を入力してください');
            return;
        }

        try {
            const url = editingFare.id
                ? `/api/invoices/fare-masters/${editingFare.id}`
                : '/api/invoices/fare-masters';

            const res = await fetch(url, {
                method: editingFare.id ? 'PUT' : 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    companyId: user.companyId,
                    shipperId: editingFare.shipper_id,
                    name: editingFare.name,
                    fareType: editingFare.fare_type,
                    baseDistanceKm: editingFare.base_distance_km,
                    baseRate: editingFare.base_rate,
                    ratePerKm: editingFare.rate_per_km,
                    baseTimeHours: editingFare.base_time_hours,
                    ratePerHour: editingFare.rate_per_hour,
                    fixedRate: editingFare.fixed_rate,
                    nightSurchargeRate: editingFare.night_surcharge_rate,
                    earlyMorningSurchargeRate: editingFare.early_morning_surcharge_rate,
                    holidaySurchargeRate: editingFare.holiday_surcharge_rate,
                    loadingFee: editingFare.loading_fee,
                    unloadingFee: editingFare.unloading_fee,
                    waitingFeePerHour: editingFare.waiting_fee_per_hour,
                    vehicleTypeCoefficients: editingFare.vehicle_type_coefficients,
                    effectiveFrom: editingFare.effective_from,
                    effectiveTo: editingFare.effective_to,
                    isActive: editingFare.is_active
                })
            });

            if (res.ok) {
                setDialogOpen(false);
                setEditingFare(null);
                fetchData();
            } else {
                setError('保存に失敗しました');
            }
        } catch (err) {
            setError('保存に失敗しました');
        }
    };

    const formatCurrency = (amount: number) => {
        return new Intl.NumberFormat('ja-JP').format(amount);
    };

    if (loading) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
                <CircularProgress />
            </Box>
        );
    }

    return (
        <Box sx={{ p: 3 }}>
            {/* ヘッダー */}
            <Box sx={{ mb: 3, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                    <Typography variant="h5" fontWeight="bold">運賃設定</Typography>
                    <Typography color="text.secondary">距離制・時間制・割増料金の設定</Typography>
                </Box>
                <Button
                    variant="contained"
                    startIcon={<Add />}
                    onClick={() => {
                        setEditingFare({ ...defaultFareMaster });
                        setDialogOpen(true);
                    }}
                >
                    新規運賃マスタ
                </Button>
            </Box>

            {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

            {/* 運賃マスタ一覧 */}
            <TableContainer component={Paper}>
                <Table>
                    <TableHead>
                        <TableRow sx={{ bgcolor: '#f5f5f5' }}>
                            <TableCell>運賃名</TableCell>
                            <TableCell>荷主</TableCell>
                            <TableCell>タイプ</TableCell>
                            <TableCell align="right">基本料金</TableCell>
                            <TableCell align="right">距離単価</TableCell>
                            <TableCell align="right">時間単価</TableCell>
                            <TableCell>有効期間</TableCell>
                            <TableCell>状態</TableCell>
                            <TableCell align="center">操作</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {fareMasters.length === 0 ? (
                            <TableRow>
                                <TableCell colSpan={9} align="center" sx={{ py: 4 }}>
                                    運賃マスタがありません
                                </TableCell>
                            </TableRow>
                        ) : (
                            fareMasters.map((fare) => {
                                const typeConfig = fareTypeLabels[fare.fare_type] || fareTypeLabels.distance;

                                return (
                                    <TableRow key={fare.id} hover>
                                        <TableCell>
                                            <Typography fontWeight="bold">{fare.name}</Typography>
                                        </TableCell>
                                        <TableCell>
                                            {fare.shipper_name || <Chip label="共通" size="small" />}
                                        </TableCell>
                                        <TableCell>
                                            <Chip
                                                icon={typeConfig.icon}
                                                label={typeConfig.label}
                                                size="small"
                                                variant="outlined"
                                            />
                                        </TableCell>
                                        <TableCell align="right">
                                            ¥{formatCurrency(fare.base_rate)}
                                        </TableCell>
                                        <TableCell align="right">
                                            {fare.fare_type === 'distance' || fare.fare_type === 'mixed'
                                                ? `¥${formatCurrency(fare.rate_per_km)}/km`
                                                : '-'
                                            }
                                        </TableCell>
                                        <TableCell align="right">
                                            {fare.fare_type === 'time' || fare.fare_type === 'mixed'
                                                ? `¥${formatCurrency(fare.rate_per_hour)}/h`
                                                : '-'
                                            }
                                        </TableCell>
                                        <TableCell>
                                            {fare.effective_from}
                                            {fare.effective_to && ` ～ ${fare.effective_to}`}
                                        </TableCell>
                                        <TableCell>
                                            <Chip
                                                label={fare.is_active ? '有効' : '無効'}
                                                color={fare.is_active ? 'success' : 'default'}
                                                size="small"
                                            />
                                        </TableCell>
                                        <TableCell align="center">
                                            <IconButton
                                                size="small"
                                                onClick={() => {
                                                    setEditingFare(fare);
                                                    setDialogOpen(true);
                                                }}
                                            >
                                                <Edit />
                                            </IconButton>
                                        </TableCell>
                                    </TableRow>
                                );
                            })
                        )}
                    </TableBody>
                </Table>
            </TableContainer>

            {/* 編集ダイアログ */}
            <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="md" fullWidth>
                <DialogTitle>
                    {editingFare?.id ? '運賃マスタ編集' : '新規運賃マスタ'}
                </DialogTitle>
                <DialogContent>
                    <Grid container spacing={2} sx={{ mt: 1 }}>
                        {/* 基本情報 */}
                        <Grid size={12}>
                            <Typography variant="subtitle2" color="primary" gutterBottom>
                                基本情報
                            </Typography>
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                label="運賃名"
                                fullWidth
                                required
                                value={editingFare?.name || ''}
                                onChange={(e) => setEditingFare({ ...editingFare, name: e.target.value })}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <FormControl fullWidth>
                                <InputLabel>荷主（空欄で共通）</InputLabel>
                                <Select
                                    value={editingFare?.shipper_id || ''}
                                    label="荷主（空欄で共通）"
                                    onChange={(e) => setEditingFare({
                                        ...editingFare,
                                        shipper_id: e.target.value as number || null
                                    })}
                                >
                                    <MenuItem value="">共通</MenuItem>
                                    {shippers.map((s) => (
                                        <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>
                                    ))}
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <FormControl fullWidth>
                                <InputLabel>運賃タイプ</InputLabel>
                                <Select
                                    value={editingFare?.fare_type || 'distance'}
                                    label="運賃タイプ"
                                    onChange={(e) => setEditingFare({
                                        ...editingFare,
                                        fare_type: e.target.value as any
                                    })}
                                >
                                    {Object.entries(fareTypeLabels).map(([key, config]) => (
                                        <MenuItem key={key} value={key}>{config.label}</MenuItem>
                                    ))}
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <FormControlLabel
                                control={
                                    <Switch
                                        checked={editingFare?.is_active ?? true}
                                        onChange={(e) => setEditingFare({
                                            ...editingFare,
                                            is_active: e.target.checked
                                        })}
                                    />
                                }
                                label="有効"
                            />
                        </Grid>

                        {/* 運賃設定 */}
                        <Grid size={12}>
                            <Divider sx={{ my: 1 }} />
                            <Typography variant="subtitle2" color="primary" gutterBottom>
                                運賃設定
                            </Typography>
                        </Grid>

                        {(editingFare?.fare_type === 'distance' || editingFare?.fare_type === 'mixed') && (
                            <>
                                <Grid size={{ xs: 12, md: 4 }}>
                                    <TextField
                                        label="基本距離"
                                        type="number"
                                        fullWidth
                                        value={editingFare?.base_distance_km || 0}
                                        onChange={(e) => setEditingFare({
                                            ...editingFare,
                                            base_distance_km: Number(e.target.value)
                                        })}
                                        InputProps={{
                                            endAdornment: <InputAdornment position="end">km</InputAdornment>
                                        }}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, md: 4 }}>
                                    <TextField
                                        label="基本料金"
                                        type="number"
                                        fullWidth
                                        value={editingFare?.base_rate || 0}
                                        onChange={(e) => setEditingFare({
                                            ...editingFare,
                                            base_rate: Number(e.target.value)
                                        })}
                                        InputProps={{
                                            startAdornment: <InputAdornment position="start">¥</InputAdornment>
                                        }}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, md: 4 }}>
                                    <TextField
                                        label="距離単価"
                                        type="number"
                                        fullWidth
                                        value={editingFare?.rate_per_km || 0}
                                        onChange={(e) => setEditingFare({
                                            ...editingFare,
                                            rate_per_km: Number(e.target.value)
                                        })}
                                        InputProps={{
                                            startAdornment: <InputAdornment position="start">¥</InputAdornment>,
                                            endAdornment: <InputAdornment position="end">/km</InputAdornment>
                                        }}
                                    />
                                </Grid>
                            </>
                        )}

                        {(editingFare?.fare_type === 'time' || editingFare?.fare_type === 'mixed') && (
                            <>
                                <Grid size={{ xs: 12, md: 4 }}>
                                    <TextField
                                        label="基本時間"
                                        type="number"
                                        fullWidth
                                        value={editingFare?.base_time_hours || 0}
                                        onChange={(e) => setEditingFare({
                                            ...editingFare,
                                            base_time_hours: Number(e.target.value)
                                        })}
                                        InputProps={{
                                            endAdornment: <InputAdornment position="end">時間</InputAdornment>
                                        }}
                                    />
                                </Grid>
                                <Grid size={{ xs: 12, md: 4 }}>
                                    <TextField
                                        label="時間単価"
                                        type="number"
                                        fullWidth
                                        value={editingFare?.rate_per_hour || 0}
                                        onChange={(e) => setEditingFare({
                                            ...editingFare,
                                            rate_per_hour: Number(e.target.value)
                                        })}
                                        InputProps={{
                                            startAdornment: <InputAdornment position="start">¥</InputAdornment>,
                                            endAdornment: <InputAdornment position="end">/h</InputAdornment>
                                        }}
                                    />
                                </Grid>
                            </>
                        )}

                        {editingFare?.fare_type === 'fixed' && (
                            <Grid size={{ xs: 12, md: 4 }}>
                                <TextField
                                    label="固定運賃"
                                    type="number"
                                    fullWidth
                                    value={editingFare?.fixed_rate || 0}
                                    onChange={(e) => setEditingFare({
                                        ...editingFare,
                                        fixed_rate: Number(e.target.value)
                                    })}
                                    InputProps={{
                                        startAdornment: <InputAdornment position="start">¥</InputAdornment>
                                    }}
                                />
                            </Grid>
                        )}

                        {/* 割増料金 */}
                        <Grid size={12}>
                            <Divider sx={{ my: 1 }} />
                            <Typography variant="subtitle2" color="primary" gutterBottom>
                                割増料金
                            </Typography>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                label="深夜割増（22:00-05:00）"
                                type="number"
                                fullWidth
                                value={editingFare?.night_surcharge_rate || 25}
                                onChange={(e) => setEditingFare({
                                    ...editingFare,
                                    night_surcharge_rate: Number(e.target.value)
                                })}
                                InputProps={{
                                    endAdornment: <InputAdornment position="end">%</InputAdornment>
                                }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                label="早朝割増（05:00-07:00）"
                                type="number"
                                fullWidth
                                value={editingFare?.early_morning_surcharge_rate || 25}
                                onChange={(e) => setEditingFare({
                                    ...editingFare,
                                    early_morning_surcharge_rate: Number(e.target.value)
                                })}
                                InputProps={{
                                    endAdornment: <InputAdornment position="end">%</InputAdornment>
                                }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                label="休日割増"
                                type="number"
                                fullWidth
                                value={editingFare?.holiday_surcharge_rate || 35}
                                onChange={(e) => setEditingFare({
                                    ...editingFare,
                                    holiday_surcharge_rate: Number(e.target.value)
                                })}
                                InputProps={{
                                    endAdornment: <InputAdornment position="end">%</InputAdornment>
                                }}
                            />
                        </Grid>

                        {/* 附帯作業費 */}
                        <Grid size={12}>
                            <Divider sx={{ my: 1 }} />
                            <Typography variant="subtitle2" color="primary" gutterBottom>
                                附帯作業費
                            </Typography>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                label="積込作業料"
                                type="number"
                                fullWidth
                                value={editingFare?.loading_fee || 0}
                                onChange={(e) => setEditingFare({
                                    ...editingFare,
                                    loading_fee: Number(e.target.value)
                                })}
                                InputProps={{
                                    startAdornment: <InputAdornment position="start">¥</InputAdornment>
                                }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                label="荷卸作業料"
                                type="number"
                                fullWidth
                                value={editingFare?.unloading_fee || 0}
                                onChange={(e) => setEditingFare({
                                    ...editingFare,
                                    unloading_fee: Number(e.target.value)
                                })}
                                InputProps={{
                                    startAdornment: <InputAdornment position="start">¥</InputAdornment>
                                }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                label="待機料"
                                type="number"
                                fullWidth
                                value={editingFare?.waiting_fee_per_hour || 0}
                                onChange={(e) => setEditingFare({
                                    ...editingFare,
                                    waiting_fee_per_hour: Number(e.target.value)
                                })}
                                InputProps={{
                                    startAdornment: <InputAdornment position="start">¥</InputAdornment>,
                                    endAdornment: <InputAdornment position="end">/h</InputAdornment>
                                }}
                            />
                        </Grid>

                        {/* 有効期間 */}
                        <Grid size={12}>
                            <Divider sx={{ my: 1 }} />
                            <Typography variant="subtitle2" color="primary" gutterBottom>
                                有効期間
                            </Typography>
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                label="適用開始日"
                                type="date"
                                fullWidth
                                value={editingFare?.effective_from || ''}
                                onChange={(e) => setEditingFare({
                                    ...editingFare,
                                    effective_from: e.target.value
                                })}
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                label="適用終了日（空欄で無期限）"
                                type="date"
                                fullWidth
                                value={editingFare?.effective_to || ''}
                                onChange={(e) => setEditingFare({
                                    ...editingFare,
                                    effective_to: e.target.value || null
                                })}
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                    </Grid>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDialogOpen(false)}>キャンセル</Button>
                    <Button variant="contained" onClick={handleSave}>保存</Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default FareSettings;
