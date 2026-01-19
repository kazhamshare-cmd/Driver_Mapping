import { useState, useEffect, useCallback } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
    Box,
    Button,
    Card,
    CardContent,
    Container,
    Grid,
    Typography,
    CircularProgress,
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
    Alert,
    AlertTitle,
    List,
    ListItem,
    ListItemText,
    ListItemIcon,
    Divider,
    Tabs,
    Tab,
    LinearProgress,
} from '@mui/material';
import {
    ArrowBack,
    Refresh,
    Today,
    ChevronLeft,
    ChevronRight,
    LocalShipping,
    Person,
    Warning,
    CheckCircle,
    Schedule,
    Assignment,
    PlayArrow,
    Stop,
    Cancel,
    AutoAwesome,
} from '@mui/icons-material';

interface DriverSchedule {
    driver_id: number;
    driver_name: string;
    employee_number: string;
    dispatches: Dispatch[];
}

interface VehicleSchedule {
    vehicle_id: number;
    vehicle_number: string;
    vehicle_type: string;
    dispatches: Dispatch[];
}

interface Dispatch {
    dispatch_id: number;
    order_number: string;
    shipper_name: string;
    scheduled_start: string;
    scheduled_end: string;
    status: string;
    pickup_location: string;
    delivery_location: string;
    cargo_name: string;
    binding_warning: boolean;
    vehicle_number?: string;
    driver_name?: string;
}

interface UnassignedOrder {
    id: number;
    order_number: string;
    shipper_name: string;
    pickup_datetime: string;
    pickup_location_name: string;
    delivery_location_name: string;
    cargo_name: string;
    cargo_weight: number;
    priority: number;
}

interface Suggestion {
    vehicle: {
        id: number;
        vehicle_number: string;
        availability_score: number;
    };
    driver: {
        id: number;
        name: string;
        projected_binding_minutes: number;
        binding_status: string;
        availability_score: number;
    };
    score: number;
    warnings: string[];
}

interface DispatchSummary {
    total_dispatches: string;
    assigned_count: string;
    in_progress_count: string;
    completed_count: string;
    vehicles_used: string;
    drivers_assigned: string;
    drivers_with_warning: string;
    unassigned_orders: string;
}

const DispatchBoard = () => {
    const navigate = useNavigate();
    const [searchParams] = useSearchParams();
    const [loading, setLoading] = useState(true);
    const [tabValue, setTabValue] = useState(0);
    const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);
    const [driverSchedules, setDriverSchedules] = useState<DriverSchedule[]>([]);
    const [vehicleSchedules, setVehicleSchedules] = useState<VehicleSchedule[]>([]);
    const [unassignedOrders, setUnassignedOrders] = useState<UnassignedOrder[]>([]);
    const [summary, setSummary] = useState<DispatchSummary | null>(null);

    // 配車ダイアログ
    const [assignDialogOpen, setAssignDialogOpen] = useState(false);
    const [selectedOrder, setSelectedOrder] = useState<UnassignedOrder | null>(null);
    const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
    const [selectedSuggestion, setSelectedSuggestion] = useState<Suggestion | null>(null);
    const [loadingSuggestions, setLoadingSuggestions] = useState(false);

    const user = JSON.parse(localStorage.getItem('user') || '{}');

    const fetchData = useCallback(async () => {
        try {
            const headers = { 'Authorization': `Bearer ${user.token}` };

            const [driverRes, vehicleRes, unassignedRes, summaryRes] = await Promise.all([
                fetch(`/api/dispatch/schedule/drivers?date=${selectedDate}`, { headers }),
                fetch(`/api/dispatch/schedule/vehicles?date=${selectedDate}`, { headers }),
                fetch(`/api/orders/unassigned?date=${selectedDate}`, { headers }),
                fetch('/api/dispatch/summary/today', { headers }),
            ]);

            if (driverRes.ok) {
                const data = await driverRes.json();
                setDriverSchedules(data.drivers);
            }
            if (vehicleRes.ok) {
                const data = await vehicleRes.json();
                setVehicleSchedules(data.vehicles);
            }
            if (unassignedRes.ok) setUnassignedOrders(await unassignedRes.json());
            if (summaryRes.ok) setSummary(await summaryRes.json());
        } catch (error) {
            console.error('Error fetching data:', error);
        } finally {
            setLoading(false);
        }
    }, [user.token, selectedDate]);

    useEffect(() => {
        fetchData();
    }, [fetchData]);

    // URLパラメータから受注IDを取得して自動で配車ダイアログを開く
    useEffect(() => {
        const orderId = searchParams.get('order');
        if (orderId && unassignedOrders.length > 0) {
            const order = unassignedOrders.find(o => o.id === parseInt(orderId));
            if (order) {
                handleOpenAssignDialog(order);
            }
        }
    }, [searchParams, unassignedOrders]);

    const handleOpenAssignDialog = async (order: UnassignedOrder) => {
        setSelectedOrder(order);
        setAssignDialogOpen(true);
        setLoadingSuggestions(true);
        setSuggestions([]);
        setSelectedSuggestion(null);

        try {
            const res = await fetch(`/api/dispatch/suggestions?order_id=${order.id}`, {
                headers: { 'Authorization': `Bearer ${user.token}` },
            });
            if (res.ok) {
                const data = await res.json();
                setSuggestions(data.suggestions);
                if (data.suggestions.length > 0) {
                    setSelectedSuggestion(data.suggestions[0]);
                }
            }
        } catch (error) {
            console.error('Error fetching suggestions:', error);
        } finally {
            setLoadingSuggestions(false);
        }
    };

    const handleCreateDispatch = async () => {
        if (!selectedOrder || !selectedSuggestion) return;

        try {
            const scheduledEnd = selectedOrder.pickup_datetime
                ? new Date(new Date(selectedOrder.pickup_datetime).getTime() + 4 * 60 * 60 * 1000).toISOString()
                : null;

            const res = await fetch('/api/dispatch', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${user.token}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    order_id: selectedOrder.id,
                    vehicle_id: selectedSuggestion.vehicle.id,
                    driver_id: selectedSuggestion.driver.id,
                    scheduled_start: selectedOrder.pickup_datetime,
                    scheduled_end: scheduledEnd,
                }),
            });

            if (res.ok) {
                setAssignDialogOpen(false);
                setSelectedOrder(null);
                setSuggestions([]);
                fetchData();
            } else {
                const error = await res.json();
                alert(error.error || '配車に失敗しました');
            }
        } catch (error) {
            console.error('Error creating dispatch:', error);
        }
    };

    const handleDispatchAction = async (dispatchId: number, action: 'start' | 'complete' | 'cancel') => {
        try {
            const res = await fetch(`/api/dispatch/${dispatchId}/${action}`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${user.token}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({}),
            });

            if (res.ok) {
                fetchData();
            }
        } catch (error) {
            console.error(`Error ${action} dispatch:`, error);
        }
    };

    const changeDate = (delta: number) => {
        const date = new Date(selectedDate);
        date.setDate(date.getDate() + delta);
        setSelectedDate(date.toISOString().split('T')[0]);
    };

    const formatTime = (dateStr: string) => {
        if (!dateStr) return '-';
        return new Date(dateStr).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'assigned': return '#2196f3';
            case 'started': return '#4caf50';
            case 'completed': return '#9e9e9e';
            case 'cancelled': return '#f44336';
            default: return '#757575';
        }
    };

    const getPriorityLabel = (priority: number) => {
        const labels: Record<number, string> = { 1: '緊急', 2: '高', 3: '通常', 4: '低' };
        return labels[priority] || '通常';
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
                        配車ボード
                    </Typography>
                </Box>
                <Box display="flex" alignItems="center" gap={2}>
                    <IconButton onClick={() => changeDate(-1)}>
                        <ChevronLeft />
                    </IconButton>
                    <TextField
                        type="date"
                        value={selectedDate}
                        onChange={(e) => setSelectedDate(e.target.value)}
                        size="small"
                        sx={{ width: 150 }}
                    />
                    <IconButton onClick={() => changeDate(1)}>
                        <ChevronRight />
                    </IconButton>
                    <Button
                        variant="outlined"
                        startIcon={<Today />}
                        onClick={() => setSelectedDate(new Date().toISOString().split('T')[0])}
                    >
                        今日
                    </Button>
                    <Button variant="outlined" startIcon={<Refresh />} onClick={fetchData}>
                        更新
                    </Button>
                </Box>
            </Box>

            <Container maxWidth="xl" sx={{ mt: 4 }}>
                {/* Summary Cards */}
                {summary && (
                    <Grid container spacing={2} sx={{ mb: 3 }}>
                        <Grid size={{ xs: 6, sm: 3, md: 1.5 }}>
                            <Card sx={{ bgcolor: 'warning.light', borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h5" fontWeight="bold" color="warning.dark">
                                        {summary.unassigned_orders}
                                    </Typography>
                                    <Typography variant="caption" color="warning.dark">未割当</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 3, md: 1.5 }}>
                            <Card sx={{ bgcolor: 'info.light', borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h5" fontWeight="bold" color="info.dark">
                                        {summary.assigned_count}
                                    </Typography>
                                    <Typography variant="caption" color="info.dark">割当済</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 3, md: 1.5 }}>
                            <Card sx={{ bgcolor: 'success.light', borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h5" fontWeight="bold" color="success.dark">
                                        {summary.in_progress_count}
                                    </Typography>
                                    <Typography variant="caption" color="success.dark">運行中</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 3, md: 1.5 }}>
                            <Card sx={{ bgcolor: 'grey.200', borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h5" fontWeight="bold">
                                        {summary.completed_count}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">完了</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 3, md: 1.5 }}>
                            <Card sx={{ borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h5" fontWeight="bold" color="primary">
                                        {summary.vehicles_used}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">稼働車両</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 3, md: 1.5 }}>
                            <Card sx={{ borderRadius: 2 }}>
                                <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                    <Typography variant="h5" fontWeight="bold" color="primary">
                                        {summary.drivers_assigned}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">稼働ドライバー</Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                        {parseInt(summary.drivers_with_warning) > 0 && (
                            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                                <Card sx={{ bgcolor: 'error.light', borderRadius: 2 }}>
                                    <CardContent sx={{ py: 1.5, textAlign: 'center' }}>
                                        <Box display="flex" alignItems="center" justifyContent="center" gap={1}>
                                            <Warning color="error" />
                                            <Typography variant="h5" fontWeight="bold" color="error.dark">
                                                {summary.drivers_with_warning}
                                            </Typography>
                                        </Box>
                                        <Typography variant="caption" color="error.dark">拘束時間警告</Typography>
                                    </CardContent>
                                </Card>
                            </Grid>
                        )}
                    </Grid>
                )}

                <Grid container spacing={3}>
                    {/* Left: Unassigned Orders */}
                    <Grid size={{ xs: 12, md: 4 }}>
                        <Paper sx={{ borderRadius: 2, overflow: 'hidden', height: 'calc(100vh - 300px)' }}>
                            <Box sx={{ bgcolor: 'warning.main', color: 'white', px: 2, py: 1.5 }}>
                                <Typography variant="subtitle1" fontWeight="bold">
                                    未割当受注 ({unassignedOrders.length})
                                </Typography>
                            </Box>
                            <Box sx={{ overflow: 'auto', height: 'calc(100% - 48px)' }}>
                                {unassignedOrders.length === 0 ? (
                                    <Box sx={{ p: 4, textAlign: 'center', color: 'text.secondary' }}>
                                        未割当の受注はありません
                                    </Box>
                                ) : (
                                    <List disablePadding>
                                        {unassignedOrders.map((order, index) => (
                                            <Box key={order.id}>
                                                {index > 0 && <Divider />}
                                                <ListItem
                                                    sx={{
                                                        cursor: 'pointer',
                                                        '&:hover': { bgcolor: 'action.hover' },
                                                        borderLeft: order.priority <= 2 ? '4px solid' : 'none',
                                                        borderLeftColor: order.priority === 1 ? 'error.main' : 'warning.main',
                                                    }}
                                                    onClick={() => handleOpenAssignDialog(order)}
                                                >
                                                    <ListItemText
                                                        primary={
                                                            <Box display="flex" alignItems="center" gap={1}>
                                                                <Typography fontWeight="bold">{order.order_number}</Typography>
                                                                {order.priority <= 2 && (
                                                                    <Chip
                                                                        label={getPriorityLabel(order.priority)}
                                                                        size="small"
                                                                        color={order.priority === 1 ? 'error' : 'warning'}
                                                                    />
                                                                )}
                                                            </Box>
                                                        }
                                                        secondary={
                                                            <Box>
                                                                <Typography variant="body2">{order.shipper_name}</Typography>
                                                                <Typography variant="caption" color="text.secondary">
                                                                    {formatTime(order.pickup_datetime)} {order.pickup_location_name}
                                                                </Typography>
                                                                <br />
                                                                <Typography variant="caption" color="text.secondary">
                                                                    → {order.delivery_location_name}
                                                                </Typography>
                                                            </Box>
                                                        }
                                                    />
                                                    <Button size="small" variant="contained" color="primary">
                                                        配車
                                                    </Button>
                                                </ListItem>
                                            </Box>
                                        ))}
                                    </List>
                                )}
                            </Box>
                        </Paper>
                    </Grid>

                    {/* Right: Schedule */}
                    <Grid size={{ xs: 12, md: 8 }}>
                        <Paper sx={{ borderRadius: 2, overflow: 'hidden' }}>
                            <Tabs
                                value={tabValue}
                                onChange={(_, v) => setTabValue(v)}
                                sx={{ borderBottom: '1px solid #eee', px: 2 }}
                            >
                                <Tab label="ドライバー別" icon={<Person />} iconPosition="start" />
                                <Tab label="車両別" icon={<LocalShipping />} iconPosition="start" />
                            </Tabs>

                            <Box sx={{ overflow: 'auto', height: 'calc(100vh - 350px)' }}>
                                {tabValue === 0 ? (
                                    // Driver Schedule
                                    driverSchedules.length === 0 ? (
                                        <Box sx={{ p: 4, textAlign: 'center', color: 'text.secondary' }}>
                                            この日の配車はありません
                                        </Box>
                                    ) : (
                                        driverSchedules.map(driver => (
                                            <Box key={driver.driver_id} sx={{ borderBottom: '1px solid #eee' }}>
                                                <Box sx={{ bgcolor: '#f5f5f5', px: 2, py: 1, display: 'flex', alignItems: 'center', gap: 1 }}>
                                                    <Person fontSize="small" />
                                                    <Typography fontWeight="bold">{driver.driver_name}</Typography>
                                                    <Typography variant="caption" color="text.secondary">
                                                        ({driver.employee_number || '-'})
                                                    </Typography>
                                                    <Chip
                                                        label={`${driver.dispatches.length}件`}
                                                        size="small"
                                                        sx={{ ml: 'auto' }}
                                                    />
                                                </Box>
                                                {driver.dispatches.length === 0 ? (
                                                    <Box sx={{ px: 2, py: 1.5, color: 'text.secondary', fontSize: '0.875rem' }}>
                                                        配車なし
                                                    </Box>
                                                ) : (
                                                    driver.dispatches.map(dispatch => (
                                                        <Box
                                                            key={dispatch.dispatch_id}
                                                            sx={{
                                                                px: 2,
                                                                py: 1,
                                                                display: 'flex',
                                                                alignItems: 'center',
                                                                gap: 2,
                                                                borderLeft: dispatch.binding_warning ? '4px solid' : 'none',
                                                                borderLeftColor: 'warning.main',
                                                                bgcolor: dispatch.binding_warning ? 'warning.light' : 'white',
                                                            }}
                                                        >
                                                            <Box sx={{
                                                                width: 80,
                                                                textAlign: 'center',
                                                                borderRadius: 1,
                                                                bgcolor: getStatusColor(dispatch.status),
                                                                color: 'white',
                                                                py: 0.5,
                                                                fontSize: '0.75rem',
                                                            }}>
                                                                {formatTime(dispatch.scheduled_start)}<br />
                                                                {formatTime(dispatch.scheduled_end)}
                                                            </Box>
                                                            <Box sx={{ flex: 1 }}>
                                                                <Typography variant="body2" fontWeight="bold">
                                                                    {dispatch.order_number} - {dispatch.shipper_name}
                                                                </Typography>
                                                                <Typography variant="caption" color="text.secondary">
                                                                    {dispatch.pickup_location} → {dispatch.delivery_location}
                                                                </Typography>
                                                            </Box>
                                                            <Typography variant="body2" color="text.secondary">
                                                                {dispatch.vehicle_number}
                                                            </Typography>
                                                            <Box display="flex" gap={0.5}>
                                                                {dispatch.status === 'assigned' && (
                                                                    <Tooltip title="開始">
                                                                        <IconButton
                                                                            size="small"
                                                                            color="success"
                                                                            onClick={() => handleDispatchAction(dispatch.dispatch_id, 'start')}
                                                                        >
                                                                            <PlayArrow fontSize="small" />
                                                                        </IconButton>
                                                                    </Tooltip>
                                                                )}
                                                                {dispatch.status === 'started' && (
                                                                    <Tooltip title="完了">
                                                                        <IconButton
                                                                            size="small"
                                                                            color="primary"
                                                                            onClick={() => handleDispatchAction(dispatch.dispatch_id, 'complete')}
                                                                        >
                                                                            <CheckCircle fontSize="small" />
                                                                        </IconButton>
                                                                    </Tooltip>
                                                                )}
                                                                {['assigned', 'started'].includes(dispatch.status) && (
                                                                    <Tooltip title="キャンセル">
                                                                        <IconButton
                                                                            size="small"
                                                                            color="error"
                                                                            onClick={() => handleDispatchAction(dispatch.dispatch_id, 'cancel')}
                                                                        >
                                                                            <Cancel fontSize="small" />
                                                                        </IconButton>
                                                                    </Tooltip>
                                                                )}
                                                            </Box>
                                                        </Box>
                                                    ))
                                                )}
                                            </Box>
                                        ))
                                    )
                                ) : (
                                    // Vehicle Schedule
                                    vehicleSchedules.length === 0 ? (
                                        <Box sx={{ p: 4, textAlign: 'center', color: 'text.secondary' }}>
                                            この日の配車はありません
                                        </Box>
                                    ) : (
                                        vehicleSchedules.map(vehicle => (
                                            <Box key={vehicle.vehicle_id} sx={{ borderBottom: '1px solid #eee' }}>
                                                <Box sx={{ bgcolor: '#f5f5f5', px: 2, py: 1, display: 'flex', alignItems: 'center', gap: 1 }}>
                                                    <LocalShipping fontSize="small" />
                                                    <Typography fontWeight="bold">{vehicle.vehicle_number}</Typography>
                                                    <Chip label={vehicle.vehicle_type} size="small" variant="outlined" />
                                                    <Chip
                                                        label={`${vehicle.dispatches.length}件`}
                                                        size="small"
                                                        sx={{ ml: 'auto' }}
                                                    />
                                                </Box>
                                                {vehicle.dispatches.length === 0 ? (
                                                    <Box sx={{ px: 2, py: 1.5, color: 'text.secondary', fontSize: '0.875rem' }}>
                                                        配車なし
                                                    </Box>
                                                ) : (
                                                    vehicle.dispatches.map(dispatch => (
                                                        <Box
                                                            key={dispatch.dispatch_id}
                                                            sx={{
                                                                px: 2,
                                                                py: 1,
                                                                display: 'flex',
                                                                alignItems: 'center',
                                                                gap: 2,
                                                            }}
                                                        >
                                                            <Box sx={{
                                                                width: 80,
                                                                textAlign: 'center',
                                                                borderRadius: 1,
                                                                bgcolor: getStatusColor(dispatch.status),
                                                                color: 'white',
                                                                py: 0.5,
                                                                fontSize: '0.75rem',
                                                            }}>
                                                                {formatTime(dispatch.scheduled_start)}<br />
                                                                {formatTime(dispatch.scheduled_end)}
                                                            </Box>
                                                            <Box sx={{ flex: 1 }}>
                                                                <Typography variant="body2" fontWeight="bold">
                                                                    {dispatch.order_number}
                                                                </Typography>
                                                                <Typography variant="caption" color="text.secondary">
                                                                    {dispatch.pickup_location} → {dispatch.delivery_location}
                                                                </Typography>
                                                            </Box>
                                                            <Typography variant="body2" color="text.secondary">
                                                                {dispatch.driver_name}
                                                            </Typography>
                                                        </Box>
                                                    ))
                                                )}
                                            </Box>
                                        ))
                                    )
                                )}
                            </Box>
                        </Paper>
                    </Grid>
                </Grid>
            </Container>

            {/* Assign Dialog */}
            <Dialog open={assignDialogOpen} onClose={() => setAssignDialogOpen(false)} maxWidth="sm" fullWidth>
                <DialogTitle>
                    <Box display="flex" alignItems="center" gap={1}>
                        <AutoAwesome color="primary" />
                        <Typography variant="h6">配車割当</Typography>
                    </Box>
                </DialogTitle>
                <DialogContent dividers>
                    {selectedOrder && (
                        <Box sx={{ mb: 3 }}>
                            <Typography variant="subtitle2" color="text.secondary">受注情報</Typography>
                            <Card variant="outlined" sx={{ mt: 1, p: 2 }}>
                                <Typography fontWeight="bold">{selectedOrder.order_number}</Typography>
                                <Typography variant="body2">{selectedOrder.shipper_name}</Typography>
                                <Typography variant="caption" color="text.secondary">
                                    {formatTime(selectedOrder.pickup_datetime)} {selectedOrder.pickup_location_name}
                                    → {selectedOrder.delivery_location_name}
                                </Typography>
                            </Card>
                        </Box>
                    )}

                    <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                        割当候補（スコア順）
                    </Typography>

                    {loadingSuggestions ? (
                        <Box sx={{ textAlign: 'center', py: 4 }}>
                            <CircularProgress size={32} />
                            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                                最適な組み合わせを検索中...
                            </Typography>
                        </Box>
                    ) : suggestions.length === 0 ? (
                        <Alert severity="warning">
                            空いている車両・ドライバーが見つかりません
                        </Alert>
                    ) : (
                        <List>
                            {suggestions.slice(0, 5).map((suggestion, index) => (
                                <ListItem
                                    key={index}
                                    sx={{
                                        border: '1px solid',
                                        borderColor: selectedSuggestion === suggestion ? 'primary.main' : 'divider',
                                        borderRadius: 1,
                                        mb: 1,
                                        cursor: 'pointer',
                                        bgcolor: selectedSuggestion === suggestion ? 'primary.light' : 'white',
                                    }}
                                    onClick={() => setSelectedSuggestion(suggestion)}
                                >
                                    <ListItemText
                                        primary={
                                            <Box display="flex" alignItems="center" gap={1}>
                                                <LocalShipping fontSize="small" />
                                                <Typography fontWeight="bold">
                                                    {suggestion.vehicle.vehicle_number}
                                                </Typography>
                                                <Typography>+</Typography>
                                                <Person fontSize="small" />
                                                <Typography fontWeight="bold">
                                                    {suggestion.driver.name}
                                                </Typography>
                                                <Chip
                                                    label={`スコア: ${Math.round(suggestion.score)}`}
                                                    size="small"
                                                    color={suggestion.score >= 80 ? 'success' : suggestion.score >= 50 ? 'warning' : 'error'}
                                                    sx={{ ml: 'auto' }}
                                                />
                                            </Box>
                                        }
                                        secondary={
                                            <Box>
                                                <Typography variant="caption">
                                                    予想拘束時間: {Math.floor(suggestion.driver.projected_binding_minutes / 60)}時間{suggestion.driver.projected_binding_minutes % 60}分
                                                </Typography>
                                                {suggestion.warnings.length > 0 && (
                                                    <Box sx={{ mt: 0.5 }}>
                                                        {suggestion.warnings.map((w, i) => (
                                                            <Chip
                                                                key={i}
                                                                label={w}
                                                                size="small"
                                                                color="warning"
                                                                icon={<Warning />}
                                                                sx={{ mr: 0.5 }}
                                                            />
                                                        ))}
                                                    </Box>
                                                )}
                                            </Box>
                                        }
                                    />
                                </ListItem>
                            ))}
                        </List>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setAssignDialogOpen(false)}>キャンセル</Button>
                    <Button
                        variant="contained"
                        onClick={handleCreateDispatch}
                        disabled={!selectedSuggestion}
                        startIcon={<CheckCircle />}
                    >
                        配車確定
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default DispatchBoard;
