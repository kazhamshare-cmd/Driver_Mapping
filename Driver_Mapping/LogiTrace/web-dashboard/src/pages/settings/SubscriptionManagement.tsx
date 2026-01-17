import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    Container,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Grid,
    Paper,
    Typography,
    CircularProgress,
    Alert,
    LinearProgress,
    List,
    ListItem,
    ListItemIcon,
    ListItemText
} from '@mui/material';
import {
    CreditCard as CardIcon,
    CalendarMonth as CalendarIcon,
    Warning as WarningIcon,
    Check as CheckIcon,
    Info as InfoIcon
} from '@mui/icons-material';
import { getPlanById } from '../../config/pricing-plans';

interface Subscription {
    id: number;
    plan_id: string;
    status: string;
    current_driver_count: number;
    trial_ends_at: string | null;
    current_period_end: string | null;
    stripe_subscription_id: string;
    created_at: string;
}

export default function SubscriptionManagement() {
    const navigate = useNavigate();
    const [subscription, setSubscription] = useState<Subscription | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [cancelDialogOpen, setCancelDialogOpen] = useState(false);
    const [cancelling, setCancelling] = useState(false);

    const user = JSON.parse(localStorage.getItem('user') || '{}');

    useEffect(() => {
        fetchSubscription();
    }, []);

    const fetchSubscription = async () => {
        try {
            const response = await fetch('/api/billing/subscription', {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (!response.ok) throw new Error('Failed to fetch subscription');
            const data = await response.json();
            setSubscription(data);
        } catch (err) {
            setError('サブスクリプション情報の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const handleCancelSubscription = async () => {
        setCancelling(true);
        try {
            const response = await fetch('/api/billing/cancel-subscription', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                }
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || 'キャンセルに失敗しました');
            }

            setSuccess('サブスクリプションのキャンセルが完了しました。現在の請求期間終了まで引き続きご利用いただけます。');
            setCancelDialogOpen(false);
            fetchSubscription();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'キャンセルに失敗しました');
        } finally {
            setCancelling(false);
        }
    };

    const getStatusInfo = () => {
        if (!subscription) return { label: '不明', color: 'default' as const };

        switch (subscription.status) {
            case 'trialing':
                return { label: 'トライアル中', color: 'info' as const };
            case 'active':
                return { label: '有効', color: 'success' as const };
            case 'canceled':
                return { label: 'キャンセル済み', color: 'error' as const };
            case 'past_due':
                return { label: '支払い遅延', color: 'warning' as const };
            default:
                return { label: subscription.status, color: 'default' as const };
        }
    };

    const getTrialDaysRemaining = () => {
        if (!subscription?.trial_ends_at) return null;
        const trialEnd = new Date(subscription.trial_ends_at);
        const now = new Date();
        const diffTime = trialEnd.getTime() - now.getTime();
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        return diffDays > 0 ? diffDays : 0;
    };

    const plan = subscription ? getPlanById(subscription.plan_id) : null;
    const statusInfo = getStatusInfo();
    const trialDaysRemaining = getTrialDaysRemaining();
    const isInTrial = subscription?.status === 'trialing';

    if (loading) {
        return (
            <Container maxWidth="md">
                <Box display="flex" justifyContent="center" py={8}>
                    <CircularProgress />
                </Box>
            </Container>
        );
    }

    return (
        <Container maxWidth="md">
            <Box sx={{ my: 4 }}>
                <Typography variant="h4" component="h1" gutterBottom>
                    サブスクリプション管理
                </Typography>

                {error && <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>{error}</Alert>}
                {success && <Alert severity="success" sx={{ mb: 3 }} onClose={() => setSuccess('')}>{success}</Alert>}

                {!subscription ? (
                    <Alert severity="info">
                        現在有効なサブスクリプションがありません。
                        <Button onClick={() => navigate('/register')}>プランを選択する</Button>
                    </Alert>
                ) : (
                    <Grid container spacing={3}>
                        {/* トライアル情報 */}
                        {isInTrial && trialDaysRemaining !== null && (
                            <Grid size={12}>
                                <Paper
                                    sx={{
                                        p: 3,
                                        backgroundColor: trialDaysRemaining <= 3 ? '#fff3e0' : '#e3f2fd',
                                        border: `1px solid ${trialDaysRemaining <= 3 ? '#ff9800' : '#1976d2'}`
                                    }}
                                >
                                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                        {trialDaysRemaining <= 3 ? (
                                            <WarningIcon color="warning" sx={{ mr: 1 }} />
                                        ) : (
                                            <InfoIcon color="primary" sx={{ mr: 1 }} />
                                        )}
                                        <Typography variant="h6" fontWeight="bold">
                                            トライアル期間: 残り{trialDaysRemaining}日
                                        </Typography>
                                    </Box>
                                    <LinearProgress
                                        variant="determinate"
                                        value={((14 - trialDaysRemaining) / 14) * 100}
                                        sx={{ mb: 2, height: 8, borderRadius: 4 }}
                                    />
                                    <Typography variant="body2" color="text.secondary">
                                        トライアル終了日: {new Date(subscription.trial_ends_at!).toLocaleDateString('ja-JP')}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                                        {trialDaysRemaining > 0 ? (
                                            <>トライアル終了後、自動的に¥{plan?.price.toLocaleString()}/月が課金されます。</>
                                        ) : (
                                            <>本日でトライアルが終了します。課金が開始されます。</>
                                        )}
                                    </Typography>
                                </Paper>
                            </Grid>
                        )}

                        {/* 現在のプラン */}
                        <Grid size={{ xs: 12, md: 6 }}>
                            <Card>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>
                                        現在のプラン
                                    </Typography>
                                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                        <Typography variant="h4" fontWeight="bold" color="primary">
                                            {plan?.name || subscription.plan_id}
                                        </Typography>
                                        <Chip
                                            label={statusInfo.label}
                                            color={statusInfo.color}
                                            size="small"
                                            sx={{ ml: 2 }}
                                        />
                                    </Box>
                                    <Typography variant="h5" sx={{ mb: 2 }}>
                                        ¥{plan?.price.toLocaleString()}<Typography component="span" variant="body2" color="text.secondary">/月</Typography>
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        ドライバー数: {subscription.current_driver_count}名
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>

                        {/* 請求情報 */}
                        <Grid size={{ xs: 12, md: 6 }}>
                            <Card>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>
                                        請求情報
                                    </Typography>
                                    <List dense>
                                        <ListItem>
                                            <ListItemIcon><CalendarIcon /></ListItemIcon>
                                            <ListItemText
                                                primary="次回請求日"
                                                secondary={
                                                    subscription.current_period_end
                                                        ? new Date(subscription.current_period_end).toLocaleDateString('ja-JP')
                                                        : isInTrial
                                                            ? `トライアル終了後 (${new Date(subscription.trial_ends_at!).toLocaleDateString('ja-JP')})`
                                                            : '-'
                                                }
                                            />
                                        </ListItem>
                                        <ListItem>
                                            <ListItemIcon><CardIcon /></ListItemIcon>
                                            <ListItemText
                                                primary="支払い方法"
                                                secondary="クレジットカード"
                                            />
                                        </ListItem>
                                    </List>
                                </CardContent>
                            </Card>
                        </Grid>

                        {/* キャンセル案内 */}
                        <Grid size={12}>
                            <Card sx={{ backgroundColor: '#fafafa' }}>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>
                                        サブスクリプションのキャンセル
                                    </Typography>
                                    {isInTrial ? (
                                        <>
                                            <Alert severity="info" sx={{ mb: 2 }}>
                                                トライアル期間中にキャンセルすると、課金されることなくサービスを停止できます。
                                            </Alert>
                                            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                                                キャンセル後も、トライアル終了日（{new Date(subscription.trial_ends_at!).toLocaleDateString('ja-JP')}）まではサービスをご利用いただけます。
                                            </Typography>
                                        </>
                                    ) : (
                                        <>
                                            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                                                キャンセルしても、現在の請求期間終了まではサービスをご利用いただけます。
                                                キャンセル後の再開も可能です。
                                            </Typography>
                                        </>
                                    )}
                                    <Button
                                        variant="outlined"
                                        color="error"
                                        onClick={() => setCancelDialogOpen(true)}
                                        disabled={subscription.status === 'canceled'}
                                    >
                                        {subscription.status === 'canceled' ? 'キャンセル済み' : 'サブスクリプションをキャンセル'}
                                    </Button>
                                </CardContent>
                            </Card>
                        </Grid>

                        {/* プラン変更 */}
                        <Grid size={12}>
                            <Card>
                                <CardContent>
                                    <Typography variant="h6" gutterBottom>
                                        プランの変更
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                                        より多くのドライバーを管理する場合や、追加機能が必要な場合はプランをアップグレードしてください。
                                    </Typography>
                                    <Button variant="outlined" onClick={() => navigate('/')}>
                                        プランを確認する
                                    </Button>
                                </CardContent>
                            </Card>
                        </Grid>
                    </Grid>
                )}

                {/* キャンセル確認ダイアログ */}
                <Dialog open={cancelDialogOpen} onClose={() => setCancelDialogOpen(false)} maxWidth="sm" fullWidth>
                    <DialogTitle>サブスクリプションのキャンセル</DialogTitle>
                    <DialogContent>
                        <Alert severity="warning" sx={{ mb: 2 }}>
                            本当にサブスクリプションをキャンセルしますか？
                        </Alert>
                        {isInTrial ? (
                            <Typography variant="body2" color="text.secondary">
                                トライアル期間中のため、キャンセルしても課金されません。
                                キャンセル後も{new Date(subscription?.trial_ends_at || '').toLocaleDateString('ja-JP')}までご利用いただけます。
                            </Typography>
                        ) : (
                            <Typography variant="body2" color="text.secondary">
                                キャンセル後も、現在の請求期間終了
                                （{new Date(subscription?.current_period_end || '').toLocaleDateString('ja-JP')}）
                                まではサービスをご利用いただけます。
                            </Typography>
                        )}
                        <Box sx={{ mt: 2 }}>
                            <Typography variant="subtitle2" gutterBottom>
                                キャンセルすると:
                            </Typography>
                            <List dense>
                                <ListItem>
                                    <ListItemIcon><CheckIcon color="success" /></ListItemIcon>
                                    <ListItemText primary="今後の請求が停止されます" />
                                </ListItem>
                                <ListItem>
                                    <ListItemIcon><CheckIcon color="success" /></ListItemIcon>
                                    <ListItemText primary="期間終了までサービスは継続利用可能" />
                                </ListItem>
                                <ListItem>
                                    <ListItemIcon><CheckIcon color="success" /></ListItemIcon>
                                    <ListItemText primary="いつでも再開可能" />
                                </ListItem>
                            </List>
                        </Box>
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => setCancelDialogOpen(false)}>
                            キャンセルしない
                        </Button>
                        <Button
                            onClick={handleCancelSubscription}
                            color="error"
                            variant="contained"
                            disabled={cancelling}
                        >
                            {cancelling ? '処理中...' : 'キャンセルする'}
                        </Button>
                    </DialogActions>
                </Dialog>
            </Box>
        </Container>
    );
}
