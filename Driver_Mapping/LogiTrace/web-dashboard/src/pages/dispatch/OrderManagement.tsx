import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box,
    Button,
    Card,
    CardContent,
    Container,
    Grid,
    Typography,
    CircularProgress,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Paper,
    Chip,
    IconButton,
    Tooltip,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Tabs,
    Tab,
    Alert,
    Autocomplete,
} from '@mui/material';
import {
    Add,
    Edit,
    Delete,
    ArrowBack,
    Refresh,
    Search,
    LocalShipping,
    Assignment,
    Cancel,
    CheckCircle,
    Schedule,
    Warning,
} from '@mui/icons-material';

interface Order {
    id: number;
    order_number: string;
    shipper_id: number;
    shipper_name: string;
    pickup_location_name: string;
    pickup_address: string;
    pickup_datetime: string;
    delivery_location_name: string;
    delivery_address: string;
    delivery_datetime: string;
    cargo_name: string;
    cargo_weight: number;
    total_fare: number;
    status: string;
    priority: number;
    dispatch_id: number | null;
    dispatch_status: string | null;
    vehicle_number: string | null;
    driver_name: string | null;
}

interface Shipper {
    id: number;
    name: string;
    shipper_code: string;
}

interface Location {
    id: number;
    name: string;
    address: string;
    location_type: string;
}

interface OrderStats {
    total_orders: string;
    pending_count: string;
    assigned_count: string;
    in_progress_count: string;
    completed_count: string;
    cancelled_count: string;
}

const OrderManagement = () => {
    const navigate = useNavigate();
    const [loading, setLoading] = useState(true);
    const [tabValue, setTabValue] = useState(0);
    const [orders, setOrders] = useState<Order[]>([]);
    const [stats, setStats] = useState<OrderStats | null>(null);
    const [shippers, setShippers] = useState<Shipper[]>([]);
    const [locations, setLocations] = useState<Location[]>([]);
    const [dialogOpen, setDialogOpen] = useState(false);
    const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
    const [searchQuery, setSearchQuery] = useState('');
    const [filterStatus, setFilterStatus] = useState('');
    const [filterShipper, setFilterShipper] = useState<number | null>(null);

    // 新規受注用のフォームデータ
    const [formData, setFormData] = useState({
        shipper_id: null as number | null,
        pickup_location_id: null as number | null,
        pickup_address: '',
        pickup_datetime: '',
        delivery_location_id: null as number | null,
        delivery_address: '',
        delivery_datetime: '',
        cargo_name: '',
        cargo_weight: '',
        cargo_quantity: '',
        required_vehicle_type: '',
        base_fare: '',
        priority: 3,
        customer_notes: '',
        internal_notes: '',
    });

    const user = JSON.parse(localStorage.getItem('user') || '{}');

    const fetchData = useCallback(async () => {
        try {
            const headers = { 'Authorization': `Bearer ${user.token}` };

            const statusFilter = tabValue === 0 ? '' : ['', 'pending', 'assigned', 'in_progress', 'completed', 'cancelled'][tabValue];

            const [ordersRes, statsRes, shippersRes, locationsRes] = await Promise.all([
                fetch(`/api/orders?status=${filterStatus || statusFilter}&search=${searchQuery}${filterShipper ? `&shipper_id=${filterShipper}` : ''}`, { headers }),
                fetch('/api/orders/stats', { headers }),
                fetch('/api/shippers?is_active=true', { headers }),
                fetch('/api/locations?is_active=true', { headers }),
            ]);

            if (ordersRes.ok) {
                const data = await ordersRes.json();
                setOrders(data.orders);
            }
            if (statsRes.ok) setStats(await statsRes.json());
            if (shippersRes.ok) setShippers(await shippersRes.json());
            if (locationsRes.ok) setLocations(await locationsRes.json());
        } catch (error) {
            console.error('Error fetching data:', error);
        } finally {
            setLoading(false);
        }
    }, [user.token, tabValue, searchQuery, filterStatus, filterShipper]);

    useEffect(() => {
        fetchData();
    }, [fetchData]);

    const handleCreateOrder = async () => {
        try {
            const res = await fetch('/api/orders', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${user.token}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    ...formData,
                    cargo_weight: formData.cargo_weight ? parseFloat(formData.cargo_weight) : null,
                    cargo_quantity: formData.cargo_quantity ? parseInt(formData.cargo_quantity) : null,
                    base_fare: formData.base_fare ? parseFloat(formData.base_fare) : null,
                }),
            });

            if (res.ok) {
                setDialogOpen(false);
                resetForm();
                fetchData();
            } else {
                const error = await res.json();
                alert(error.error || 'Failed to create order');
            }
        } catch (error) {
            console.error('Error creating order:', error);
        }
    };

    const handleCancelOrder = async (orderId: number) => {
        if (!confirm('この受注をキャンセルしますか？')) return;

        try {
            const res = await fetch(`/api/orders/${orderId}/cancel`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${user.token}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ reason: 'キャンセル' }),
            });

            if (res.ok) {
                fetchData();
            }
        } catch (error) {
            console.error('Error cancelling order:', error);
        }
    };

    const resetForm = () => {
        setFormData({
            shipper_id: null,
            pickup_location_id: null,
            pickup_address: '',
            pickup_datetime: '',
            delivery_location_id: null,
            delivery_address: '',
            delivery_datetime: '',
            cargo_name: '',
            cargo_weight: '',
            cargo_quantity: '',
            required_vehicle_type: '',
            base_fare: '',
            priority: 3,
            customer_notes: '',
            internal_notes: '',
        });
    };

    const getStatusChip = (status: string) => {
        const config: Record<string, { label: string; color: 'default' | 'primary' | 'success' | 'warning' | 'error' | 'info' }> = {
            pending: { label: '未割当', color: 'warning' },
            assigned: { label: '割当済', color: 'info' },
            in_progress: { label: '運行中', color: 'primary' },
            completed: { label: '完了', color: 'success' },
            cancelled: { label: 'キャンセル', color: 'error' },
        };
        const { label, color } = config[status] || { label: status, color: 'default' };
        return <Chip label={label} color={color} size="small" />;
    };

    const getPriorityChip = (priority: number) => {
        const config: Record<number, { label: string; color: 'default' | 'error' | 'warning' | 'info' }> = {
            1: { label: '緊急', color: 'error' },
            2: { label: '高', color: 'warning' },
            3: { label: '通常', color: 'default' },
            4: { label: '低', color: 'info' },
        };
        const { label, color } = config[priority] || { label: '通常', color: 'default' };
        return <Chip label={label} color={color} size="small" variant="outlined" />;
    };

    const formatDateTime = (dateStr: string) => {
        if (!dateStr) return '-';
        return new Date(dateStr).toLocaleString('ja-JP', {
            month: 'numeric',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
        });
    };

    if (loading) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="100vh" bgcolor="#f5f7fa">
                <CircularProgress />
            </Box>
        );
    }

    return (
        <Box sx={{ minHeight: '100vh', bgcolor: '#f5f7fa', pb: 8 }}>
            {/* Header */}
            <Box sx={{
                bgcolor: 'white',
                borderBottom: '1px solid #e0e0e0',
                px: 4,
                py: 2,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
            }}>
                <Box display="flex" alignItems="center" gap={2}>
                    <IconButton onClick={() => navigate('/dashboard')}>
                        <ArrowBack />
                    </IconButton>
                    <Typography variant="h5" fontWeight="800" color="primary">
                        受注管理
                    </Typography>
                </Box>
                <Box display="flex" alignItems="center" gap={2}>
                    <Button
                        variant="outlined"
                        startIcon={<Refresh />}
                        onClick={fetchData}
                    >
                        更新
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<Add />}
                        onClick={() => setDialogOpen(true)}
                    >
                        新規受注
                    </Button>
                </Box>
            </Box>

            <Container maxWidth="xl" sx={{ mt: 4 }}>
                {/* Stats Cards */}
                {stats && (
                    <Grid container spacing={2} sx={{ mb: 3 }}>
                        <Grid size={{ xs: 6, sm: 4, md: 2 }}>
                            <Card sx={{ bgcolor: 'white', borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h4" fontWeight="bold" color="primary">
                                        {stats.total_orders}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">総受注</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 4, md: 2 }}>
                            <Card sx={{ bgcolor: 'warning.light', borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h4" fontWeight="bold" color="warning.dark">
                                        {stats.pending_count}
                                    </Typography>
                                    <Typography variant="caption" color="warning.dark">未割当</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 4, md: 2 }}>
                            <Card sx={{ bgcolor: 'info.light', borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h4" fontWeight="bold" color="info.dark">
                                        {stats.assigned_count}
                                    </Typography>
                                    <Typography variant="caption" color="info.dark">割当済</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 4, md: 2 }}>
                            <Card sx={{ bgcolor: 'primary.light', borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h4" fontWeight="bold" color="primary.dark">
                                        {stats.in_progress_count}
                                    </Typography>
                                    <Typography variant="caption" color="primary.dark">運行中</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 4, md: 2 }}>
                            <Card sx={{ bgcolor: 'success.light', borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h4" fontWeight="bold" color="success.dark">
                                        {stats.completed_count}
                                    </Typography>
                                    <Typography variant="caption" color="success.dark">完了</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 4, md: 2 }}>
                            <Card sx={{ bgcolor: 'grey.200', borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h4" fontWeight="bold" color="text.secondary">
                                        {stats.cancelled_count}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">キャンセル</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                    </Grid>
                )}

                {/* Filters */}
                <Paper sx={{ p: 2, mb: 2, borderRadius: 2 }}>
                    <Grid container spacing={2} alignItems="center">
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                fullWidth
                                size="small"
                                placeholder="受注番号・品名・荷主名で検索"
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                                InputProps={{
                                    startAdornment: <Search sx={{ mr: 1, color: 'text.secondary' }} />,
                                }}
                            />
                        </Grid>
                        <Grid size={{ xs: 6, md: 3 }}>
                            <FormControl fullWidth size="small">
                                <InputLabel>荷主</InputLabel>
                                <Select
                                    value={filterShipper || ''}
                                    label="荷主"
                                    onChange={(e) => setFilterShipper(e.target.value ? Number(e.target.value) : null)}
                                >
                                    <MenuItem value="">すべて</MenuItem>
                                    {shippers.map(s => (
                                        <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>
                                    ))}
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid size={{ xs: 6, md: 3 }}>
                            <FormControl fullWidth size="small">
                                <InputLabel>ステータス</InputLabel>
                                <Select
                                    value={filterStatus}
                                    label="ステータス"
                                    onChange={(e) => setFilterStatus(e.target.value)}
                                >
                                    <MenuItem value="">すべて</MenuItem>
                                    <MenuItem value="pending">未割当</MenuItem>
                                    <MenuItem value="assigned">割当済</MenuItem>
                                    <MenuItem value="in_progress">運行中</MenuItem>
                                    <MenuItem value="completed">完了</MenuItem>
                                    <MenuItem value="cancelled">キャンセル</MenuItem>
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid size={{ xs: 12, md: 2 }}>
                            <Button
                                fullWidth
                                variant="outlined"
                                onClick={() => {
                                    setSearchQuery('');
                                    setFilterStatus('');
                                    setFilterShipper(null);
                                }}
                            >
                                クリア
                            </Button>
                        </Grid>
                    </Grid>
                </Paper>

                {/* Orders Table */}
                <Paper sx={{ borderRadius: 2, overflow: 'hidden' }}>
                    <TableContainer>
                        <Table>
                            <TableHead sx={{ bgcolor: '#f8f9fa' }}>
                                <TableRow>
                                    <TableCell sx={{ fontWeight: 'bold' }}>受注番号</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>優先度</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>荷主</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>集荷日時</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>配達日時</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>品名</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>ステータス</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>配車</TableCell>
                                    <TableCell></TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {orders.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={9} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                                            受注データがありません
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    orders.map((order) => (
                                        <TableRow key={order.id} hover>
                                            <TableCell>
                                                <Typography fontWeight="bold">{order.order_number}</Typography>
                                            </TableCell>
                                            <TableCell>{getPriorityChip(order.priority)}</TableCell>
                                            <TableCell>{order.shipper_name || '-'}</TableCell>
                                            <TableCell>
                                                <Typography variant="body2">
                                                    {formatDateTime(order.pickup_datetime)}
                                                </Typography>
                                                <Typography variant="caption" color="text.secondary">
                                                    {order.pickup_location_name || order.pickup_address?.substring(0, 15) || '-'}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2">
                                                    {formatDateTime(order.delivery_datetime)}
                                                </Typography>
                                                <Typography variant="caption" color="text.secondary">
                                                    {order.delivery_location_name || order.delivery_address?.substring(0, 15) || '-'}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2">{order.cargo_name || '-'}</Typography>
                                                {order.cargo_weight && (
                                                    <Typography variant="caption" color="text.secondary">
                                                        {order.cargo_weight}kg
                                                    </Typography>
                                                )}
                                            </TableCell>
                                            <TableCell>{getStatusChip(order.status)}</TableCell>
                                            <TableCell>
                                                {order.dispatch_id ? (
                                                    <Box>
                                                        <Typography variant="body2">{order.vehicle_number}</Typography>
                                                        <Typography variant="caption" color="text.secondary">
                                                            {order.driver_name}
                                                        </Typography>
                                                    </Box>
                                                ) : order.status === 'pending' ? (
                                                    <Button
                                                        size="small"
                                                        variant="outlined"
                                                        color="primary"
                                                        onClick={() => navigate(`/dispatch/board?order=${order.id}`)}
                                                    >
                                                        配車
                                                    </Button>
                                                ) : (
                                                    '-'
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <Box display="flex" gap={0.5}>
                                                    <Tooltip title="詳細">
                                                        <IconButton size="small">
                                                            <Assignment fontSize="small" />
                                                        </IconButton>
                                                    </Tooltip>
                                                    {order.status === 'pending' && (
                                                        <Tooltip title="キャンセル">
                                                            <IconButton
                                                                size="small"
                                                                color="error"
                                                                onClick={() => handleCancelOrder(order.id)}
                                                            >
                                                                <Cancel fontSize="small" />
                                                            </IconButton>
                                                        </Tooltip>
                                                    )}
                                                </Box>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                </Paper>
            </Container>

            {/* Create Order Dialog */}
            <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="md" fullWidth>
                <DialogTitle>
                    <Box display="flex" alignItems="center" gap={1}>
                        <Add />
                        <Typography variant="h6">新規受注登録</Typography>
                    </Box>
                </DialogTitle>
                <DialogContent dividers>
                    <Grid container spacing={2}>
                        {/* 荷主 */}
                        <Grid size={12}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom>荷主情報</Typography>
                        </Grid>
                        <Grid size={12}>
                            <Autocomplete
                                options={shippers}
                                getOptionLabel={(option) => option.name}
                                onChange={(_, value) => setFormData({ ...formData, shipper_id: value?.id || null })}
                                renderInput={(params) => <TextField {...params} label="荷主" size="small" />}
                            />
                        </Grid>

                        {/* 集荷情報 */}
                        <Grid size={12}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom sx={{ mt: 1 }}>集荷情報</Typography>
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <Autocomplete
                                options={locations.filter(l => l.location_type !== 'delivery')}
                                getOptionLabel={(option) => option.name}
                                onChange={(_, value) => setFormData({ ...formData, pickup_location_id: value?.id || null })}
                                renderInput={(params) => <TextField {...params} label="集荷地" size="small" />}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                size="small"
                                label="集荷日時"
                                type="datetime-local"
                                value={formData.pickup_datetime}
                                onChange={(e) => setFormData({ ...formData, pickup_datetime: e.target.value })}
                                InputLabelProps={{ shrink: true }}
                                required
                            />
                        </Grid>
                        <Grid size={12}>
                            <TextField
                                fullWidth
                                size="small"
                                label="集荷住所（マスタ未登録の場合）"
                                value={formData.pickup_address}
                                onChange={(e) => setFormData({ ...formData, pickup_address: e.target.value })}
                            />
                        </Grid>

                        {/* 配達情報 */}
                        <Grid size={12}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom sx={{ mt: 1 }}>配達情報</Typography>
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <Autocomplete
                                options={locations.filter(l => l.location_type !== 'pickup')}
                                getOptionLabel={(option) => option.name}
                                onChange={(_, value) => setFormData({ ...formData, delivery_location_id: value?.id || null })}
                                renderInput={(params) => <TextField {...params} label="配達地" size="small" />}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                size="small"
                                label="配達日時"
                                type="datetime-local"
                                value={formData.delivery_datetime}
                                onChange={(e) => setFormData({ ...formData, delivery_datetime: e.target.value })}
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid size={12}>
                            <TextField
                                fullWidth
                                size="small"
                                label="配達住所（マスタ未登録の場合）"
                                value={formData.delivery_address}
                                onChange={(e) => setFormData({ ...formData, delivery_address: e.target.value })}
                            />
                        </Grid>

                        {/* 貨物情報 */}
                        <Grid size={12}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom sx={{ mt: 1 }}>貨物情報</Typography>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                fullWidth
                                size="small"
                                label="品名"
                                value={formData.cargo_name}
                                onChange={(e) => setFormData({ ...formData, cargo_name: e.target.value })}
                            />
                        </Grid>
                        <Grid size={{ xs: 6, md: 4 }}>
                            <TextField
                                fullWidth
                                size="small"
                                label="重量 (kg)"
                                type="number"
                                value={formData.cargo_weight}
                                onChange={(e) => setFormData({ ...formData, cargo_weight: e.target.value })}
                            />
                        </Grid>
                        <Grid size={{ xs: 6, md: 4 }}>
                            <TextField
                                fullWidth
                                size="small"
                                label="数量"
                                type="number"
                                value={formData.cargo_quantity}
                                onChange={(e) => setFormData({ ...formData, cargo_quantity: e.target.value })}
                            />
                        </Grid>

                        {/* 運賃・優先度 */}
                        <Grid size={12}>
                            <Typography variant="subtitle2" color="text.secondary" gutterBottom sx={{ mt: 1 }}>運賃・優先度</Typography>
                        </Grid>
                        <Grid size={{ xs: 6, md: 4 }}>
                            <TextField
                                fullWidth
                                size="small"
                                label="基本運賃 (円)"
                                type="number"
                                value={formData.base_fare}
                                onChange={(e) => setFormData({ ...formData, base_fare: e.target.value })}
                            />
                        </Grid>
                        <Grid size={{ xs: 6, md: 4 }}>
                            <FormControl fullWidth size="small">
                                <InputLabel>優先度</InputLabel>
                                <Select
                                    value={formData.priority}
                                    label="優先度"
                                    onChange={(e) => setFormData({ ...formData, priority: Number(e.target.value) })}
                                >
                                    <MenuItem value={1}>緊急</MenuItem>
                                    <MenuItem value={2}>高</MenuItem>
                                    <MenuItem value={3}>通常</MenuItem>
                                    <MenuItem value={4}>低</MenuItem>
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <FormControl fullWidth size="small">
                                <InputLabel>必要車種</InputLabel>
                                <Select
                                    value={formData.required_vehicle_type}
                                    label="必要車種"
                                    onChange={(e) => setFormData({ ...formData, required_vehicle_type: e.target.value })}
                                >
                                    <MenuItem value="">指定なし</MenuItem>
                                    <MenuItem value="小型">小型</MenuItem>
                                    <MenuItem value="中型">中型</MenuItem>
                                    <MenuItem value="大型">大型</MenuItem>
                                    <MenuItem value="トレーラー">トレーラー</MenuItem>
                                </Select>
                            </FormControl>
                        </Grid>

                        {/* 備考 */}
                        <Grid size={12}>
                            <TextField
                                fullWidth
                                size="small"
                                label="荷主備考"
                                multiline
                                rows={2}
                                value={formData.customer_notes}
                                onChange={(e) => setFormData({ ...formData, customer_notes: e.target.value })}
                            />
                        </Grid>
                        <Grid size={12}>
                            <TextField
                                fullWidth
                                size="small"
                                label="社内備考"
                                multiline
                                rows={2}
                                value={formData.internal_notes}
                                onChange={(e) => setFormData({ ...formData, internal_notes: e.target.value })}
                            />
                        </Grid>
                    </Grid>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => { setDialogOpen(false); resetForm(); }}>キャンセル</Button>
                    <Button
                        variant="contained"
                        onClick={handleCreateOrder}
                        disabled={!formData.pickup_datetime}
                    >
                        登録
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default OrderManagement;
