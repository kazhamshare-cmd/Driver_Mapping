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
    Alert,
    AlertTitle,
    LinearProgress,
    IconButton,
    Tooltip,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    TextField,
    Tabs,
    Tab,
    List,
    ListItem,
    ListItemText,
    ListItemIcon,
    Divider,
} from '@mui/material';
import {
    AccessTime,
    Warning,
    Error as ErrorIcon,
    CheckCircle,
    Refresh,
    ArrowBack,
    DirectionsCar,
    Person,
    TrendingUp,
    Visibility,
    Check,
    Close,
    Schedule,
    LocalCafe,
    DriveEta,
} from '@mui/icons-material';

interface DriverStatus {
    driver_id: number;
    driver_name: string;
    employee_number: string;
    work_record_id: number | null;
    start_time: string | null;
    end_time: string | null;
    current_binding_minutes: number;
    binding_time_minutes: number | null;
    driving_time_minutes: number | null;
    break_minutes: number;
    binding_limit: number;
    binding_extended_limit: number;
    binding_status: 'normal' | 'warning' | 'violation' | 'critical';
    is_working: boolean;
}

interface StatusSummary {
    total_drivers: number;
    working: number;
    warning: number;
    violation: number;
    critical: number;
}

interface LaborAlert {
    id: number;
    driver_id: number;
    driver_name: string;
    employee_number: string;
    alert_type: string;
    alert_level: 'warning' | 'violation' | 'critical';
    alert_date: string;
    threshold_value: number;
    actual_value: number;
    threshold_label: string;
    description: string;
    acknowledged: boolean;
    created_at: string;
}

interface MonthlyStats {
    year_month: string;
    active_drivers: number;
    total_binding_minutes: number;
    total_driving_minutes: number;
    total_extended_days: number;
    total_violation_days: number;
    avg_daily_binding: number;
    avg_daily_driving: number;
    alerts: {
        critical?: number;
        violation?: number;
        warning?: number;
    };
}

const LaborTimeMonitor = () => {
    const navigate = useNavigate();
    const [loading, setLoading] = useState(true);
    const [tabValue, setTabValue] = useState(0);
    const [drivers, setDrivers] = useState<DriverStatus[]>([]);
    const [summary, setSummary] = useState<StatusSummary | null>(null);
    const [alerts, setAlerts] = useState<LaborAlert[]>([]);
    const [alertsTotal, setAlertsTotal] = useState(0);
    const [monthlyStats, setMonthlyStats] = useState<MonthlyStats | null>(null);
    const [selectedDriver, setSelectedDriver] = useState<DriverStatus | null>(null);
    const [detailDialogOpen, setDetailDialogOpen] = useState(false);
    const [driverDetail, setDriverDetail] = useState<any>(null);
    const [alertFilter, setAlertFilter] = useState<'all' | 'unacknowledged'>('unacknowledged');
    const [selectedMonth, setSelectedMonth] = useState(
        new Date().toISOString().substring(0, 7)
    );

    const user = JSON.parse(localStorage.getItem('user') || '{}');

    const fetchData = useCallback(async () => {
        try {
            const headers = { 'Authorization': `Bearer ${user.token}` };

            const [driverStatusRes, alertsRes, statsRes] = await Promise.all([
                fetch('/api/labor-compliance/driver-status', { headers }),
                fetch(`/api/labor-compliance/alerts?acknowledged=${alertFilter === 'all' ? '' : 'false'}&limit=50`, { headers }),
                fetch(`/api/labor-compliance/company-stats?year_month=${selectedMonth}`, { headers }),
            ]);

            if (driverStatusRes.ok) {
                const data = await driverStatusRes.json();
                setDrivers(data.drivers);
                setSummary(data.summary);
            }

            if (alertsRes.ok) {
                const data = await alertsRes.json();
                setAlerts(data.alerts);
                setAlertsTotal(data.total);
            }

            if (statsRes.ok) {
                setMonthlyStats(await statsRes.json());
            }
        } catch (error) {
            console.error('Failed to fetch labor compliance data:', error);
        } finally {
            setLoading(false);
        }
    }, [user.token, alertFilter, selectedMonth]);

    useEffect(() => {
        fetchData();
        // 30秒ごとに自動更新
        const interval = setInterval(fetchData, 30000);
        return () => clearInterval(interval);
    }, [fetchData]);

    const fetchDriverDetail = async (driverId: number) => {
        try {
            const res = await fetch(`/api/labor-compliance/driver/${driverId}/detail`, {
                headers: { 'Authorization': `Bearer ${user.token}` },
            });
            if (res.ok) {
                setDriverDetail(await res.json());
            }
        } catch (error) {
            console.error('Failed to fetch driver detail:', error);
        }
    };

    const handleDriverClick = async (driver: DriverStatus) => {
        setSelectedDriver(driver);
        await fetchDriverDetail(driver.driver_id);
        setDetailDialogOpen(true);
    };

    const handleAcknowledgeAlert = async (alertId: number) => {
        try {
            const res = await fetch(`/api/labor-compliance/alerts/${alertId}/acknowledge`, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${user.token}` },
            });
            if (res.ok) {
                fetchData();
            }
        } catch (error) {
            console.error('Failed to acknowledge alert:', error);
        }
    };

    const handleBulkAcknowledge = async () => {
        const unacknowledgedIds = alerts.filter(a => !a.acknowledged).map(a => a.id);
        if (unacknowledgedIds.length === 0) return;

        try {
            const res = await fetch('/api/labor-compliance/alerts/bulk-acknowledge', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${user.token}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ alert_ids: unacknowledgedIds }),
            });
            if (res.ok) {
                fetchData();
            }
        } catch (error) {
            console.error('Failed to bulk acknowledge alerts:', error);
        }
    };

    const formatMinutes = (minutes: number) => {
        const hours = Math.floor(minutes / 60);
        const mins = minutes % 60;
        return `${hours}時間${mins}分`;
    };

    const getBindingProgress = (current: number, limit: number) => {
        return Math.min((current / limit) * 100, 100);
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'critical':
                return 'error';
            case 'violation':
                return 'warning';
            case 'warning':
                return 'info';
            default:
                return 'success';
        }
    };

    const getStatusIcon = (status: string) => {
        switch (status) {
            case 'critical':
                return <ErrorIcon color="error" />;
            case 'violation':
                return <Warning color="warning" />;
            case 'warning':
                return <Warning color="info" />;
            default:
                return <CheckCircle color="success" />;
        }
    };

    const getAlertTypeLabel = (type: string) => {
        const labels: Record<string, string> = {
            binding_time_daily: '1日拘束時間',
            binding_time_monthly: '月間拘束時間',
            driving_time_daily: '1日運転時間',
            driving_time_2day_avg: '2日平均運転時間',
            driving_time_2week_avg: '2週平均運転時間',
            rest_period: '休息期間',
            continuous_driving: '連続運転',
        };
        return labels[type] || type;
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
                        拘束時間モニター
                    </Typography>
                    <Chip
                        label="改善基準告示対応"
                        size="small"
                        color="primary"
                        variant="outlined"
                    />
                </Box>
                <Box display="flex" alignItems="center" gap={2}>
                    <Tooltip title="更新">
                        <IconButton onClick={fetchData}>
                            <Refresh />
                        </IconButton>
                    </Tooltip>
                    <Button
                        variant="outlined"
                        onClick={() => navigate('/compliance/labor-settings')}
                    >
                        設定
                    </Button>
                </Box>
            </Box>

            <Container maxWidth="xl" sx={{ mt: 4 }}>
                {/* Summary Cards */}
                <Grid container spacing={3} sx={{ mb: 4 }}>
                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <Card sx={{ borderRadius: 3, boxShadow: '0 2px 12px rgba(0,0,0,0.04)' }}>
                            <CardContent>
                                <Box display="flex" alignItems="center" justifyContent="space-between">
                                    <Box>
                                        <Typography color="text.secondary" variant="body2">業務中</Typography>
                                        <Typography variant="h4" fontWeight="bold" color="primary">
                                            {summary?.working || 0}
                                        </Typography>
                                    </Box>
                                    <Box sx={{ p: 2, bgcolor: 'primary.light', borderRadius: 2 }}>
                                        <Person sx={{ color: 'primary.main', fontSize: 32 }} />
                                    </Box>
                                </Box>
                                <Typography variant="caption" color="text.secondary">
                                    全{summary?.total_drivers || 0}名中
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <Card sx={{ borderRadius: 3, boxShadow: '0 2px 12px rgba(0,0,0,0.04)', borderLeft: '4px solid', borderLeftColor: 'info.main' }}>
                            <CardContent>
                                <Box display="flex" alignItems="center" justifyContent="space-between">
                                    <Box>
                                        <Typography color="text.secondary" variant="body2">注意</Typography>
                                        <Typography variant="h4" fontWeight="bold" color="info.main">
                                            {summary?.warning || 0}
                                        </Typography>
                                    </Box>
                                    <Warning sx={{ color: 'info.main', fontSize: 32 }} />
                                </Box>
                                <Typography variant="caption" color="text.secondary">
                                    拘束時間90%超過
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <Card sx={{ borderRadius: 3, boxShadow: '0 2px 12px rgba(0,0,0,0.04)', borderLeft: '4px solid', borderLeftColor: 'warning.main' }}>
                            <CardContent>
                                <Box display="flex" alignItems="center" justifyContent="space-between">
                                    <Box>
                                        <Typography color="text.secondary" variant="body2">上限超過</Typography>
                                        <Typography variant="h4" fontWeight="bold" color="warning.main">
                                            {summary?.violation || 0}
                                        </Typography>
                                    </Box>
                                    <Warning sx={{ color: 'warning.main', fontSize: 32 }} />
                                </Box>
                                <Typography variant="caption" color="text.secondary">
                                    13時間超過（延長日）
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <Card sx={{ borderRadius: 3, boxShadow: '0 2px 12px rgba(0,0,0,0.04)', borderLeft: '4px solid', borderLeftColor: 'error.main' }}>
                            <CardContent>
                                <Box display="flex" alignItems="center" justifyContent="space-between">
                                    <Box>
                                        <Typography color="text.secondary" variant="body2">重大違反</Typography>
                                        <Typography variant="h4" fontWeight="bold" color="error">
                                            {summary?.critical || 0}
                                        </Typography>
                                    </Box>
                                    <ErrorIcon sx={{ color: 'error.main', fontSize: 32 }} />
                                </Box>
                                <Typography variant="caption" color="text.secondary">
                                    16時間超過
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                </Grid>

                {/* Critical Alert Banner */}
                {(summary?.critical || 0) > 0 && (
                    <Alert severity="error" sx={{ mb: 3, borderRadius: 2 }} icon={<ErrorIcon />}>
                        <AlertTitle>緊急対応が必要です</AlertTitle>
                        拘束時間が16時間を超過しているドライバーがいます。直ちに業務終了を指示してください。
                    </Alert>
                )}

                {/* Tabs */}
                <Paper sx={{ mb: 3, borderRadius: 3 }}>
                    <Tabs
                        value={tabValue}
                        onChange={(_, newValue) => setTabValue(newValue)}
                        sx={{ borderBottom: '1px solid #eee', px: 2 }}
                    >
                        <Tab label="リアルタイム監視" icon={<AccessTime />} iconPosition="start" />
                        <Tab
                            label={
                                <Box display="flex" alignItems="center" gap={1}>
                                    アラート一覧
                                    {alertsTotal > 0 && (
                                        <Chip label={alertsTotal} size="small" color="error" />
                                    )}
                                </Box>
                            }
                            icon={<Warning />}
                            iconPosition="start"
                        />
                        <Tab label="月次統計" icon={<TrendingUp />} iconPosition="start" />
                    </Tabs>

                    {/* Tab 0: Real-time Monitoring */}
                    {tabValue === 0 && (
                        <Box sx={{ p: 3 }}>
                            <Typography variant="h6" fontWeight="bold" gutterBottom>
                                本日の拘束時間状況
                            </Typography>
                            <TableContainer>
                                <Table>
                                    <TableHead sx={{ bgcolor: '#f8f9fa' }}>
                                        <TableRow>
                                            <TableCell sx={{ fontWeight: 'bold' }}>状態</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>ドライバー</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>社員番号</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>業務開始</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>拘束時間</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>進捗</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>休憩</TableCell>
                                            <TableCell></TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {drivers.length === 0 ? (
                                            <TableRow>
                                                <TableCell colSpan={8} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                                                    本日の運行記録がありません
                                                </TableCell>
                                            </TableRow>
                                        ) : (
                                            drivers.map((driver) => (
                                                <TableRow
                                                    key={driver.driver_id}
                                                    hover
                                                    sx={{
                                                        bgcolor: driver.binding_status === 'critical' ? 'error.light' :
                                                            driver.binding_status === 'violation' ? 'warning.light' : 'inherit',
                                                        opacity: driver.is_working ? 1 : 0.7,
                                                    }}
                                                >
                                                    <TableCell>
                                                        <Box display="flex" alignItems="center" gap={1}>
                                                            {getStatusIcon(driver.binding_status)}
                                                            <Chip
                                                                label={driver.is_working ? '業務中' : '終了'}
                                                                color={driver.is_working ? 'success' : 'default'}
                                                                size="small"
                                                                variant="outlined"
                                                            />
                                                        </Box>
                                                    </TableCell>
                                                    <TableCell sx={{ fontWeight: 'bold' }}>{driver.driver_name}</TableCell>
                                                    <TableCell>{driver.employee_number || '-'}</TableCell>
                                                    <TableCell>
                                                        {driver.start_time
                                                            ? new Date(driver.start_time).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })
                                                            : '-'}
                                                    </TableCell>
                                                    <TableCell>
                                                        <Typography
                                                            fontWeight="bold"
                                                            color={getStatusColor(driver.binding_status) + '.main'}
                                                        >
                                                            {formatMinutes(driver.current_binding_minutes)}
                                                        </Typography>
                                                    </TableCell>
                                                    <TableCell sx={{ minWidth: 200 }}>
                                                        <Box>
                                                            <LinearProgress
                                                                variant="determinate"
                                                                value={getBindingProgress(driver.current_binding_minutes, driver.binding_limit)}
                                                                color={getStatusColor(driver.binding_status) as any}
                                                                sx={{ height: 8, borderRadius: 4, mb: 0.5 }}
                                                            />
                                                            <Typography variant="caption" color="text.secondary">
                                                                上限 {formatMinutes(driver.binding_limit)}
                                                            </Typography>
                                                        </Box>
                                                    </TableCell>
                                                    <TableCell>
                                                        <Box display="flex" alignItems="center" gap={0.5}>
                                                            <LocalCafe fontSize="small" color="action" />
                                                            <Typography variant="body2">
                                                                {driver.break_minutes}分
                                                            </Typography>
                                                        </Box>
                                                    </TableCell>
                                                    <TableCell>
                                                        <Tooltip title="詳細を表示">
                                                            <IconButton
                                                                size="small"
                                                                onClick={() => handleDriverClick(driver)}
                                                            >
                                                                <Visibility />
                                                            </IconButton>
                                                        </Tooltip>
                                                    </TableCell>
                                                </TableRow>
                                            ))
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </Box>
                    )}

                    {/* Tab 1: Alerts */}
                    {tabValue === 1 && (
                        <Box sx={{ p: 3 }}>
                            <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
                                <Typography variant="h6" fontWeight="bold">
                                    労務アラート
                                </Typography>
                                <Box display="flex" gap={2}>
                                    <FormControl size="small" sx={{ minWidth: 150 }}>
                                        <InputLabel>フィルター</InputLabel>
                                        <Select
                                            value={alertFilter}
                                            label="フィルター"
                                            onChange={(e) => setAlertFilter(e.target.value as any)}
                                        >
                                            <MenuItem value="unacknowledged">未確認のみ</MenuItem>
                                            <MenuItem value="all">すべて</MenuItem>
                                        </Select>
                                    </FormControl>
                                    <Button
                                        variant="outlined"
                                        startIcon={<Check />}
                                        onClick={handleBulkAcknowledge}
                                        disabled={alerts.filter(a => !a.acknowledged).length === 0}
                                    >
                                        一括確認
                                    </Button>
                                </Box>
                            </Box>
                            <TableContainer>
                                <Table>
                                    <TableHead sx={{ bgcolor: '#f8f9fa' }}>
                                        <TableRow>
                                            <TableCell sx={{ fontWeight: 'bold' }}>レベル</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>日付</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>ドライバー</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>種別</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>詳細</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold' }}>状態</TableCell>
                                            <TableCell></TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {alerts.length === 0 ? (
                                            <TableRow>
                                                <TableCell colSpan={7} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                                                    アラートはありません
                                                </TableCell>
                                            </TableRow>
                                        ) : (
                                            alerts.map((alert) => (
                                                <TableRow key={alert.id} hover>
                                                    <TableCell>
                                                        <Chip
                                                            label={alert.alert_level === 'critical' ? '重大' :
                                                                alert.alert_level === 'violation' ? '違反' : '注意'}
                                                            color={getStatusColor(alert.alert_level) as any}
                                                            size="small"
                                                        />
                                                    </TableCell>
                                                    <TableCell>{new Date(alert.alert_date).toLocaleDateString('ja-JP')}</TableCell>
                                                    <TableCell sx={{ fontWeight: 'bold' }}>{alert.driver_name}</TableCell>
                                                    <TableCell>{getAlertTypeLabel(alert.alert_type)}</TableCell>
                                                    <TableCell sx={{ maxWidth: 300 }}>
                                                        <Typography variant="body2" noWrap>
                                                            {alert.description}
                                                        </Typography>
                                                    </TableCell>
                                                    <TableCell>
                                                        {alert.acknowledged ? (
                                                            <Chip label="確認済" size="small" variant="outlined" />
                                                        ) : (
                                                            <Chip label="未確認" size="small" color="error" variant="outlined" />
                                                        )}
                                                    </TableCell>
                                                    <TableCell>
                                                        {!alert.acknowledged && (
                                                            <Tooltip title="確認済みにする">
                                                                <IconButton
                                                                    size="small"
                                                                    onClick={() => handleAcknowledgeAlert(alert.id)}
                                                                >
                                                                    <Check />
                                                                </IconButton>
                                                            </Tooltip>
                                                        )}
                                                    </TableCell>
                                                </TableRow>
                                            ))
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </Box>
                    )}

                    {/* Tab 2: Monthly Stats */}
                    {tabValue === 2 && (
                        <Box sx={{ p: 3 }}>
                            <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
                                <Typography variant="h6" fontWeight="bold">
                                    月次労務統計
                                </Typography>
                                <TextField
                                    type="month"
                                    value={selectedMonth}
                                    onChange={(e) => setSelectedMonth(e.target.value)}
                                    size="small"
                                    sx={{ width: 200 }}
                                />
                            </Box>

                            {monthlyStats && (
                                <Grid container spacing={3}>
                                    <Grid size={{ xs: 12, md: 6 }}>
                                        <Card sx={{ borderRadius: 2 }}>
                                            <CardContent>
                                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                                    稼働概要
                                                </Typography>
                                                <List>
                                                    <ListItem>
                                                        <ListItemIcon><Person /></ListItemIcon>
                                                        <ListItemText
                                                            primary="稼働ドライバー数"
                                                            secondary={`${monthlyStats.active_drivers}名`}
                                                        />
                                                    </ListItem>
                                                    <Divider />
                                                    <ListItem>
                                                        <ListItemIcon><Schedule /></ListItemIcon>
                                                        <ListItemText
                                                            primary="総拘束時間"
                                                            secondary={formatMinutes(monthlyStats.total_binding_minutes || 0)}
                                                        />
                                                    </ListItem>
                                                    <Divider />
                                                    <ListItem>
                                                        <ListItemIcon><DriveEta /></ListItemIcon>
                                                        <ListItemText
                                                            primary="総運転時間"
                                                            secondary={formatMinutes(monthlyStats.total_driving_minutes || 0)}
                                                        />
                                                    </ListItem>
                                                    <Divider />
                                                    <ListItem>
                                                        <ListItemIcon><AccessTime /></ListItemIcon>
                                                        <ListItemText
                                                            primary="平均日次拘束時間"
                                                            secondary={formatMinutes(Math.round(monthlyStats.avg_daily_binding || 0))}
                                                        />
                                                    </ListItem>
                                                </List>
                                            </CardContent>
                                        </Card>
                                    </Grid>
                                    <Grid size={{ xs: 12, md: 6 }}>
                                        <Card sx={{ borderRadius: 2 }}>
                                            <CardContent>
                                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                                    コンプライアンス状況
                                                </Typography>
                                                <List>
                                                    <ListItem>
                                                        <ListItemIcon><Warning color="warning" /></ListItemIcon>
                                                        <ListItemText
                                                            primary="延長日（13時間超）"
                                                            secondary={`${monthlyStats.total_extended_days || 0}日`}
                                                        />
                                                    </ListItem>
                                                    <Divider />
                                                    <ListItem>
                                                        <ListItemIcon><ErrorIcon color="error" /></ListItemIcon>
                                                        <ListItemText
                                                            primary="違反発生日"
                                                            secondary={`${monthlyStats.total_violation_days || 0}日`}
                                                        />
                                                    </ListItem>
                                                    <Divider />
                                                    <ListItem>
                                                        <ListItemIcon><ErrorIcon color="error" /></ListItemIcon>
                                                        <ListItemText
                                                            primary="重大アラート"
                                                            secondary={`${monthlyStats.alerts?.critical || 0}件`}
                                                        />
                                                    </ListItem>
                                                    <Divider />
                                                    <ListItem>
                                                        <ListItemIcon><Warning color="warning" /></ListItemIcon>
                                                        <ListItemText
                                                            primary="違反アラート"
                                                            secondary={`${monthlyStats.alerts?.violation || 0}件`}
                                                        />
                                                    </ListItem>
                                                </List>
                                            </CardContent>
                                        </Card>
                                    </Grid>
                                </Grid>
                            )}
                        </Box>
                    )}
                </Paper>
            </Container>

            {/* Driver Detail Dialog */}
            <Dialog
                open={detailDialogOpen}
                onClose={() => setDetailDialogOpen(false)}
                maxWidth="md"
                fullWidth
            >
                <DialogTitle>
                    <Box display="flex" alignItems="center" gap={2}>
                        <Person />
                        <Typography variant="h6">{selectedDriver?.driver_name} - 労務詳細</Typography>
                    </Box>
                </DialogTitle>
                <DialogContent dividers>
                    {driverDetail && (
                        <Grid container spacing={3}>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                    今月のサマリー
                                </Typography>
                                <Card variant="outlined" sx={{ p: 2 }}>
                                    <List dense>
                                        <ListItem>
                                            <ListItemText
                                                primary="総拘束時間"
                                                secondary={formatMinutes(driverDetail.monthly_summary?.total_binding_minutes || 0)}
                                            />
                                        </ListItem>
                                        <ListItem>
                                            <ListItemText
                                                primary="総運転時間"
                                                secondary={formatMinutes(driverDetail.monthly_summary?.total_driving_minutes || 0)}
                                            />
                                        </ListItem>
                                        <ListItem>
                                            <ListItemText
                                                primary="稼働日数"
                                                secondary={`${driverDetail.monthly_summary?.work_days || 0}日`}
                                            />
                                        </ListItem>
                                        <ListItem>
                                            <ListItemText
                                                primary="延長日数"
                                                secondary={`${driverDetail.monthly_summary?.extended_days || 0}日`}
                                            />
                                        </ListItem>
                                        <ListItem>
                                            <ListItemText
                                                primary="違反日数"
                                                secondary={`${driverDetail.monthly_summary?.violation_days || 0}日`}
                                            />
                                        </ListItem>
                                    </List>
                                </Card>
                            </Grid>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                    過去7日間の推移
                                </Typography>
                                <Card variant="outlined" sx={{ p: 2 }}>
                                    <List dense>
                                        {driverDetail.daily_summary?.map((day: any) => (
                                            <ListItem key={day.summary_date}>
                                                <ListItemText
                                                    primary={new Date(day.summary_date).toLocaleDateString('ja-JP', { month: 'short', day: 'numeric' })}
                                                    secondary={formatMinutes(day.total_binding_minutes)}
                                                />
                                                {day.has_violation && (
                                                    <Chip label="違反" size="small" color="error" />
                                                )}
                                                {day.is_extended_day && !day.has_violation && (
                                                    <Chip label="延長" size="small" color="warning" />
                                                )}
                                            </ListItem>
                                        ))}
                                    </List>
                                </Card>
                            </Grid>
                            <Grid size={12}>
                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                    最近のアラート
                                </Typography>
                                {driverDetail.recent_alerts?.length === 0 ? (
                                    <Typography color="text.secondary">アラートはありません</Typography>
                                ) : (
                                    <List>
                                        {driverDetail.recent_alerts?.slice(0, 5).map((alert: any) => (
                                            <ListItem key={alert.id}>
                                                <ListItemIcon>
                                                    {getStatusIcon(alert.alert_level)}
                                                </ListItemIcon>
                                                <ListItemText
                                                    primary={`${getAlertTypeLabel(alert.alert_type)} - ${new Date(alert.alert_date).toLocaleDateString('ja-JP')}`}
                                                    secondary={alert.description}
                                                />
                                                {!alert.acknowledged && (
                                                    <Chip label="未確認" size="small" color="error" variant="outlined" />
                                                )}
                                            </ListItem>
                                        ))}
                                    </List>
                                )}
                            </Grid>
                        </Grid>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDetailDialogOpen(false)}>閉じる</Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default LaborTimeMonitor;
