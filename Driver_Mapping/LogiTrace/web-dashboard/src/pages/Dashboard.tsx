import { useState, useEffect } from 'react';
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
    List,
    ListItem,
    ListItemIcon,
    ListItemText,
    IconButton,
    Tooltip,
    Badge as MuiBadge // Import Badge component as MuiBadge to avoid conflict
} from '@mui/material';
import {
    People,
    LocalShipping,
    FactCheck,
    Speed,
    Warning,
    LocalHospital,
    Psychology,
    Badge as BadgeIcon, // Import Badge icon as BadgeIcon
    ReportProblem,
    ArrowForward,
    Notifications,
    PersonAdd,
    CarCrash,
    PictureAsPdf,
    CalendarMonth,
    DirectionsBus,
} from '@mui/icons-material';
import { useIndustry } from '../contexts/IndustryContext';
import LogoutIcon from '@mui/icons-material/Logout';
import AssessmentIcon from '@mui/icons-material/Assessment';
import {
    BarChart,
    Bar,
    XAxis,
    YAxis,
    CartesianGrid,
    Tooltip as RechartsTooltip,
    ResponsiveContainer,
    Legend
} from 'recharts';

interface DashboardSummary {
    drivers: { active: number; total: number };
    vehicles: { active: number; total: number };
    todayReports: { confirmed: number; pending: number; total: number };
    monthlyDistance: number;
}

interface Activity {
    id: number;
    work_date: string;
    start_time: string;
    end_time: string | null;
    distance: number;
    status: string;
    driver_name: string;
    vehicle_number: string | null;
}

interface ExpirationAlert {
    type: 'license' | 'health_checkup' | 'aptitude_test';
    driver_id: number;
    driver_name: string;
    expiry_date: string;
    days_remaining: number;
    urgency: 'warning' | 'critical' | 'expired';
}

interface ComplianceSummary {
    totalDrivers: number;
    activeDrivers: number;
    expiringLicenses: number;
    expiredLicenses: number;
    healthCheckupsDue: number;
    healthCheckupsOverdue: number;
    aptitudeTestsRequired: number;
    aptitudeTestsOverdue: number;
    driversWithIssues: number;
}

// Mock data for the chart if no API data exists for it yet
const mockWeeklyData = [
    { name: '月', distance: 4000, reports: 24 },
    { name: '火', distance: 3000, reports: 18 },
    { name: '水', distance: 2000, reports: 22 },
    { name: '木', distance: 2780, reports: 20 },
    { name: '金', distance: 1890, reports: 15 },
    { name: '土', distance: 2390, reports: 10 },
    { name: '日', distance: 3490, reports: 12 },
];

const Dashboard = () => {
    const navigate = useNavigate();
    const { isBusIndustry } = useIndustry();
    const [summary, setSummary] = useState<DashboardSummary | null>(null);
    const [activities, setActivities] = useState<Activity[]>([]);
    const [alerts, setAlerts] = useState<ExpirationAlert[]>([]);
    const [complianceSummary, setComplianceSummary] = useState<ComplianceSummary | null>(null);
    const [loading, setLoading] = useState(true);

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchDashboardData();
    }, []);

    const fetchDashboardData = async () => {
        try {
            const [summaryRes, activitiesRes, alertsRes, complianceRes] = await Promise.all([
                fetch(`/api/dashboard/summary?companyId=${companyId}`, { headers: { 'Authorization': `Bearer ${user.token}` } }),
                fetch(`/api/dashboard/recent-activities?companyId=${companyId}&limit=5`, { headers: { 'Authorization': `Bearer ${user.token}` } }),
                fetch(`/api/alerts?companyId=${companyId}`, { headers: { 'Authorization': `Bearer ${user.token}` } }),
                fetch(`/api/compliance/summary?companyId=${companyId}`, { headers: { 'Authorization': `Bearer ${user.token}` } })
            ]);

            if (summaryRes.ok) setSummary(await summaryRes.json());
            if (activitiesRes.ok) setActivities(await activitiesRes.json());
            if (alertsRes.ok) setAlerts(await alertsRes.json());
            if (complianceRes.ok) setComplianceSummary(await complianceRes.json());
        } catch (error) {
            console.error('Failed to fetch dashboard data:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleLogout = () => {
        localStorage.removeItem('user');
        window.location.reload();
    };

    const formatDistance = (distance: number) => distance.toLocaleString('ja-JP') + ' km';

    const formatTime = (timeStr: string | null) => {
        if (!timeStr) return '-';
        return new Date(timeStr).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
    };

    const getAlertIcon = (type: string) => {
        switch (type) {
            case 'license': return <BadgeIcon color="error" />;
            case 'health_checkup': return <LocalHospital color="warning" />;
            case 'aptitude_test': return <Psychology color="info" />;
            default: return <Warning />;
        }
    };

    const getAlertTypeLabel = (type: string) => {
        switch (type) {
            case 'license': return '免許';
            case 'health_checkup': return '健康診断';
            case 'aptitude_test': return '適性診断';
            default: return type;
        }
    };

    if (loading) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="100vh" bgcolor="#f5f7fa">
                <CircularProgress />
            </Box>
        );
    }

    const criticalAlerts = alerts.filter(a => a.urgency === 'expired' || a.urgency === 'critical');

    return (
        <Box sx={{ minHeight: '100vh', bgcolor: '#f5f7fa', pb: 8 }}>
            {/* Header / Navbar */}
            <Box sx={{
                bgcolor: 'white',
                borderBottom: '1px solid #e0e0e0',
                px: 4,
                py: 2,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                position: 'sticky',
                top: 0,
                zIndex: 1000,
                boxShadow: '0 2px 4px rgba(0,0,0,0.02)'
            }}>
                <Box display="flex" alignItems="center" gap={2}>
                    <Typography variant="h5" component="h1" fontWeight="800" color="primary" sx={{ letterSpacing: '-0.5px' }}>
                        LogiTrace
                    </Typography>
                    <Chip label="管理者モード" size="small" color="default" sx={{ bgcolor: '#f5f5f5', fontWeight: 600 }} />
                </Box>
                <Box display="flex" alignItems="center" gap={2}>
                    <Tooltip title="通知">
                        <IconButton size="small">
                            <MuiBadge badgeContent={alerts.length} color="error">
                                <Notifications color="action" />
                            </MuiBadge>
                        </IconButton>
                    </Tooltip>
                    <Button
                        variant="outlined"
                        startIcon={<LogoutIcon />}
                        onClick={handleLogout}
                        size="small"
                        sx={{ borderRadius: 2 }}
                    >
                        ログアウト
                    </Button>
                </Box>
            </Box>

            <Container maxWidth="xl" sx={{ mt: 4 }}>
                {/* Welcome Section */}
                <Box sx={{ mb: 4, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
                    <Box>
                        <Typography variant="h4" fontWeight="bold" gutterBottom sx={{ color: '#1a237e' }}>
                            ダッシュボード
                        </Typography>
                        <Typography color="text.secondary">
                            {new Date().toLocaleDateString('ja-JP', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })} の稼働状況
                        </Typography>
                    </Box>
                    <Box display="flex" gap={2}>
                        <Button
                            variant="contained"
                            startIcon={<PersonAdd />}
                            onClick={() => navigate('/drivers')}
                            sx={{
                                bgcolor: '#1a237e',
                                px: 3,
                                boxShadow: '0 4px 12px rgba(26, 35, 126, 0.2)',
                                '&:hover': { bgcolor: '#0d47a1' }
                            }}
                        >
                            ドライバー追加
                        </Button>
                        <Button
                            variant="outlined"
                            startIcon={<AssessmentIcon />}
                            onClick={() => navigate('/reports')}
                            sx={{ bgcolor: 'white' }}
                        >
                            日報一覧
                        </Button>
                    </Box>
                </Box>

                {/* Alerts Section */}
                {criticalAlerts.length > 0 && (
                    <Alert severity="error" sx={{ mb: 4, borderRadius: 2, boxShadow: '0 2px 8px rgba(211, 47, 47, 0.1)' }} icon={<ReportProblem />}>
                        <AlertTitle sx={{ fontWeight: 'bold' }}>緊急: 対応が必要な項目があります</AlertTitle>
                        <Box display="flex" flexWrap="wrap" gap={1} mt={1}>
                            {criticalAlerts.slice(0, 5).map((alert, index) => (
                                <Chip
                                    key={index}
                                    icon={getAlertIcon(alert.type)}
                                    label={`${alert.driver_name}: ${getAlertTypeLabel(alert.type)} ${alert.days_remaining < 0 ? '期限切れ' : `残り${alert.days_remaining}日`}`}
                                    color="error"
                                    size="small"
                                    variant="filled"
                                />
                            ))}
                        </Box>
                    </Alert>
                )}

                {/* Stats Cards */}
                <Grid container spacing={3} sx={{ mb: 4 }}>
                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <StatCard
                            title="稼働車両"
                            value={summary ? `${summary.vehicles.active}` : '-'}
                            total={`/ ${summary?.vehicles.total || '-'}`}
                            icon={<LocalShipping sx={{ fontSize: 32, color: 'white' }} />}
                            color="linear-gradient(135deg, #2196F3 0%, #1976D2 100%)"
                            trend="稼働率"
                            trendValue={summary?.vehicles.total ? `${Math.round((summary.vehicles.active / summary.vehicles.total) * 100)}%` : '-'}
                        />
                    </Grid>
                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <StatCard
                            title="業務中ドライバー"
                            value={summary ? `${summary.drivers.active}` : '-'}
                            total={`/ ${summary?.drivers.total || '-'}`}
                            icon={<People sx={{ fontSize: 32, color: 'white' }} />}
                            color="linear-gradient(135deg, #66BB6A 0%, #43A047 100%)"
                            trend="出勤率"
                            trendValue={summary?.drivers.total ? `${Math.round((summary.drivers.active / summary.drivers.total) * 100)}%` : '-'}
                        />
                    </Grid>
                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <StatCard
                            title="本日の日報"
                            value={summary ? `${summary.todayReports.confirmed}` : '-'}
                            icon={<FactCheck sx={{ fontSize: 32, color: 'white' }} />}
                            color="linear-gradient(135deg, #FFA726 0%, #F57C00 100%)"
                            trend="未提出"
                            trendValue={summary ? `${summary.todayReports.pending}件` : '-'}
                        />
                    </Grid>
                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <StatCard
                            title="月間総走行距離"
                            value={summary ? formatDistance(summary.monthlyDistance).replace(' km', '') : '-'}
                            unit="km"
                            icon={<Speed sx={{ fontSize: 32, color: 'white' }} />}
                            color="linear-gradient(135deg, #7E57C2 0%, #5E35B1 100%)"
                            trend="前月比"
                            trendValue="+12.5%" // Mock trend
                        />
                    </Grid>
                </Grid>

                {/* Main Content Area */}
                <Grid container spacing={3}>
                    {/* Left Column: Charts & Activity */}
                    <Grid size={{ xs: 12, lg: 8 }}>
                        {/* Weekly Activity Chart */}
                        <Paper sx={{ p: 3, mb: 3, borderRadius: 3, boxShadow: '0 2px 12px rgba(0,0,0,0.04)' }}>
                            <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
                                <Typography variant="h6" fontWeight="bold">週間稼働実績</Typography>
                                <Button size="small" endIcon={<ArrowForward />}>詳細レポート</Button>
                            </Box>
                            <Box height={300}>
                                <ResponsiveContainer width="100%" height="100%">
                                    <BarChart data={mockWeeklyData}>
                                        <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#eee" />
                                        <XAxis dataKey="name" axisLine={false} tickLine={false} />
                                        <YAxis axisLine={false} tickLine={false} />
                                        <RechartsTooltip
                                            contentStyle={{ borderRadius: 8, border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }}
                                            cursor={{ fill: 'rgba(0,0,0,0.04)' }}
                                        />
                                        <Legend />
                                        <Bar dataKey="distance" name="走行距離 (km)" fill="#1976d2" radius={[4, 4, 0, 0]} barSize={32} />
                                        <Bar dataKey="reports" name="日報数" fill="#42a5f5" radius={[4, 4, 0, 0]} barSize={32} />
                                    </BarChart>
                                </ResponsiveContainer>
                            </Box>
                        </Paper>

                        {/* Recent Activity Table */}
                        <Paper sx={{ p: 0, borderRadius: 3, boxShadow: '0 2px 12px rgba(0,0,0,0.04)', overflow: 'hidden' }}>
                            <Box p={3} borderBottom="1px solid #eee">
                                <Typography variant="h6" fontWeight="bold">リアルタイム活動状況</Typography>
                            </Box>
                            <TableContainer>
                                <Table>
                                    <TableHead sx={{ bgcolor: '#f8f9fa' }}>
                                        <TableRow>
                                            <TableCell sx={{ fontWeight: 'bold', color: 'text.secondary' }}>ステータス</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold', color: 'text.secondary' }}>ドライバー</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold', color: 'text.secondary' }}>車両</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold', color: 'text.secondary' }}>時間</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold', color: 'text.secondary' }}>距離</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {activities.length === 0 ? (
                                            <TableRow>
                                                <TableCell colSpan={5} align="center" sx={{ py: 6, color: 'text.secondary' }}>
                                                    活動記録がありません
                                                </TableCell>
                                            </TableRow>
                                        ) : (
                                            activities.map((activity) => (
                                                <TableRow key={activity.id} hover>
                                                    <TableCell>
                                                        <Chip
                                                            label={activity.status === 'confirmed' ? '運転終了' : '運転中'}
                                                            color={activity.status === 'confirmed' ? 'default' : 'success'}
                                                            size="small"
                                                            variant="outlined"
                                                            sx={{ fontWeight: 'bold', minWidth: 80 }}
                                                        />
                                                    </TableCell>
                                                    <TableCell sx={{ fontWeight: 'bold' }}>{activity.driver_name}</TableCell>
                                                    <TableCell>{activity.vehicle_number || '-'}</TableCell>
                                                    <TableCell>
                                                        {formatTime(activity.start_time)}
                                                        {activity.end_time && ` - ${formatTime(activity.end_time)}`}
                                                    </TableCell>
                                                    <TableCell>{activity.distance} km</TableCell>
                                                </TableRow>
                                            ))
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </Paper>
                    </Grid>

                    {/* Right Column: Compliance & Quick Actions */}
                    <Grid size={{ xs: 12, lg: 4 }}>
                        {/* Compliance Score */}
                        <Paper sx={{ p: 3, mb: 3, borderRadius: 3, boxShadow: '0 2px 12px rgba(0,0,0,0.04)', background: 'linear-gradient(to bottom right, #ffffff, #f8fbff)' }}>
                            <Typography variant="h6" fontWeight="bold" gutterBottom>コンプライアンス状況</Typography>

                            {complianceSummary && (
                                <Box sx={{ mt: 2 }}>
                                    <Box display="flex" alignItems="center" mb={2} p={2} borderRadius={2} bgcolor={complianceSummary.driversWithIssues > 0 ? '#fff3e0' : '#e8f5e9'}>
                                        <Box mr={2}>
                                            <CircularProgress
                                                variant="determinate"
                                                value={100 - (complianceSummary.driversWithIssues * 10)} // Mock calculation
                                                color={complianceSummary.driversWithIssues > 0 ? 'warning' : 'success'}
                                                size={50}
                                                thickness={4}
                                            />
                                        </Box>
                                        <Box>
                                            <Typography variant="h5" fontWeight="bold">
                                                {complianceSummary.driversWithIssues === 0 ? '健全' : '要確認'}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                {complianceSummary.driversWithIssues} 名の対応が必要です
                                            </Typography>
                                        </Box>
                                    </Box>

                                    <List>
                                        <ListItem disablePadding sx={{ py: 1, borderBottom: '1px solid #f0f0f0' }}>
                                            <ListItemIcon><BadgeIcon color={complianceSummary.expiredLicenses > 0 ? 'error' : 'action'} /></ListItemIcon>
                                            <ListItemText primary="免許証有効期限" secondary={complianceSummary.expiredLicenses > 0 ? `${complianceSummary.expiredLicenses}件 期限切れ` : '問題なし'} />
                                            {complianceSummary.expiredLicenses > 0 && <Button size="small" color="error">確認</Button>}
                                        </ListItem>
                                        <ListItem disablePadding sx={{ py: 1, borderBottom: '1px solid #f0f0f0' }}>
                                            <ListItemIcon><LocalHospital color={complianceSummary.healthCheckupsOverdue > 0 ? 'error' : 'action'} /></ListItemIcon>
                                            <ListItemText primary="健康診断" secondary={complianceSummary.healthCheckupsOverdue > 0 ? `${complianceSummary.healthCheckupsOverdue}件 未受診` : '受診済み'} />
                                            {complianceSummary.healthCheckupsOverdue > 0 && <Button size="small" color="error">確認</Button>}
                                        </ListItem>
                                        <ListItem disablePadding sx={{ py: 1 }}>
                                            <ListItemIcon><Psychology color={complianceSummary.aptitudeTestsOverdue > 0 ? 'error' : 'action'} /></ListItemIcon>
                                            <ListItemText primary="適性診断" secondary={complianceSummary.aptitudeTestsOverdue > 0 ? `${complianceSummary.aptitudeTestsOverdue}件 未受診` : '受診済み'} />
                                            {complianceSummary.aptitudeTestsOverdue > 0 && <Button size="small" color="error">確認</Button>}
                                        </ListItem>
                                    </List>
                                </Box>
                            )}
                        </Paper>

                        {/* Quick Access Grid */}
                        <Typography variant="subtitle2" color="text.secondary" fontWeight="bold" sx={{ mb: 2, ml: 1 }}>管理メニュー</Typography>
                        <Grid container spacing={2}>
                            {/* Bus Industry: Operation Instructions Card */}
                            {isBusIndustry && (
                                <Grid size={12}>
                                    <Card
                                        sx={{
                                            cursor: 'pointer',
                                            borderRadius: 3,
                                            transition: 'all 0.2s',
                                            background: 'linear-gradient(135deg, #1565c0 0%, #0d47a1 100%)',
                                            color: 'white',
                                            '&:hover': { transform: 'translateY(-2px)', boxShadow: '0 4px 12px rgba(13, 71, 161, 0.3)' }
                                        }}
                                        onClick={() => navigate('/bus/operation-instructions')}
                                    >
                                        <CardContent sx={{ p: 2, display: 'flex', alignItems: 'center' }}>
                                            <DirectionsBus sx={{ fontSize: 32, mr: 2 }} />
                                            <Box>
                                                <Typography variant="body1" fontWeight="bold">運行指示書</Typography>
                                                <Typography variant="caption" sx={{ opacity: 0.9 }}>バス運行指示書の管理</Typography>
                                            </Box>
                                            <ArrowForward sx={{ ml: 'auto' }} />
                                        </CardContent>
                                    </Card>
                                </Grid>
                            )}
                            <Grid size={6}>
                                <QuickActionCard
                                    icon={<FactCheck color="primary" sx={{ fontSize: 28 }} />}
                                    title="点呼記録"
                                    onClick={() => navigate('/compliance/tenko')}
                                />
                            </Grid>
                            <Grid size={6}>
                                <QuickActionCard
                                    icon={<CarCrash color="warning" sx={{ fontSize: 28 }} />}
                                    title="日常点検"
                                    onClick={() => navigate('/compliance/inspections')}
                                />
                            </Grid>
                            <Grid size={6}>
                                <QuickActionCard
                                    icon={<PictureAsPdf color="error" sx={{ fontSize: 28 }} />}
                                    title="監査出力"
                                    onClick={() => navigate('/compliance/audit')}
                                />
                            </Grid>
                            <Grid size={6}>
                                <QuickActionCard
                                    icon={<CalendarMonth color="info" sx={{ fontSize: 28 }} />}
                                    title="月次報告"
                                    onClick={() => navigate('/reports/monthly-yearly')}
                                />
                            </Grid>
                        </Grid>
                    </Grid>
                </Grid>
            </Container>
        </Box>
    );
};

// Sub-components
const StatCard = ({ icon, title, value, total, unit, color, trend, trendValue }: any) => (
    <Card sx={{ height: '100%', borderRadius: 3, boxShadow: '0 4px 12px rgba(0,0,0,0.05)', position: 'relative', overflow: 'hidden' }}>
        <Box sx={{
            position: 'absolute',
            top: 0,
            right: 0,
            width: '100px',
            height: '100px',
            background: color,
            opacity: 0.1,
            borderRadius: '0 0 0 100%'
        }} />
        <CardContent>
            <Box display="flex" alignItems="center" mb={2}>
                <Box sx={{
                    width: 48,
                    height: 48,
                    borderRadius: 3,
                    background: color,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    mr: 2,
                    boxShadow: '0 4px 8px rgba(0,0,0,0.1)'
                }}>
                    {icon}
                </Box>
                <Typography variant="subtitle2" color="text.secondary" fontWeight="bold">{title}</Typography>
            </Box>
            <Box display="flex" alignItems="baseline">
                <Typography variant="h4" fontWeight="800" sx={{ color: '#263238' }}>{value}</Typography>
                {total && <Typography variant="h6" color="text.secondary" sx={{ ml: 1 }}>{total}</Typography>}
                {unit && <Typography variant="body1" color="text.secondary" sx={{ ml: 1 }}>{unit}</Typography>}
            </Box>
            <Box display="flex" alignItems="center" mt={1}>
                <Typography variant="caption" color="text.secondary">{trend}: </Typography>
                <Typography variant="caption" color="success.main" fontWeight="bold" sx={{ ml: 0.5 }}>{trendValue}</Typography>
            </Box>
        </CardContent>
    </Card>
);

const QuickActionCard = ({ icon, title, onClick }: any) => (
    <Card
        sx={{
            cursor: 'pointer',
            borderRadius: 3,
            transition: 'all 0.2s',
            '&:hover': { transform: 'translateY(-2px)', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }
        }}
        onClick={onClick}
    >
        <CardContent sx={{ p: 2, display: 'flex', alignItems: 'center', flexDirection: 'column', textAlign: 'center' }}>
            <Box sx={{ mb: 1.5 }}>{icon}</Box>
            <Typography variant="body2" fontWeight="bold">{title}</Typography>
        </CardContent>
    </Card>
);

export default Dashboard;
