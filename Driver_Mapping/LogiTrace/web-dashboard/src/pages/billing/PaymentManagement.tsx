/**
 * Payment Management - 入金管理画面
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
    Card,
    CardContent,
    Tabs,
    Tab,
    Alert,
    CircularProgress,
    Tooltip,
    List,
    ListItem,
    ListItemText,
    ListItemSecondaryAction,
    InputAdornment
} from '@mui/material';
import {
    Add,
    Link as LinkIcon,
    LinkOff,
    Delete,
    CheckCircle,
    Warning,
    AccountBalance,
    Receipt,
    TrendingUp
} from '@mui/icons-material';

interface Payment {
    id: number;
    payment_date: string;
    amount: number;
    payment_method: string;
    bank_name: string;
    branch_name: string;
    transfer_name: string;
    invoice_id: number | null;
    invoice_number: string | null;
    invoice_total: number | null;
    shipper_id: number | null;
    shipper_name: string | null;
    is_matched: boolean;
    notes: string;
}

interface MatchingSuggestion {
    id: number;
    invoice_number: string;
    shipper_name: string;
    total_amount: number;
    paid_amount: number;
    amount_diff: number;
    match_score: number;
}

interface Shipper {
    id: number;
    name: string;
}

const paymentMethodLabels: Record<string, string> = {
    bank_transfer: '銀行振込',
    cash: '現金',
    check: '小切手',
    credit_card: 'クレジットカード',
    offset: '相殺',
    other: 'その他'
};

const PaymentManagement = () => {
    const [tab, setTab] = useState(0);
    const [payments, setPayments] = useState<Payment[]>([]);
    const [unmatchedPayments, setUnmatchedPayments] = useState<Payment[]>([]);
    const [shippers, setShippers] = useState<Shipper[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    // ダイアログ
    const [addDialogOpen, setAddDialogOpen] = useState(false);
    const [matchDialogOpen, setMatchDialogOpen] = useState(false);
    const [selectedPayment, setSelectedPayment] = useState<Payment | null>(null);
    const [matchingSuggestions, setMatchingSuggestions] = useState<MatchingSuggestion[]>([]);

    // フォーム
    const [newPayment, setNewPayment] = useState({
        paymentDate: new Date().toISOString().split('T')[0],
        amount: 0,
        paymentMethod: 'bank_transfer',
        bankName: '',
        branchName: '',
        transferName: '',
        shipperId: '',
        notes: ''
    });

    // サマリー
    const [summary, setSummary] = useState({
        totalPayments: 0,
        matchedAmount: 0,
        unmatchedAmount: 0,
        monthlyTotal: 0
    });

    const user = JSON.parse(localStorage.getItem('user') || '{}');

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [paymentsRes, unmatchedRes, shippersRes, summaryRes] = await Promise.all([
                fetch(`/api/payments?companyId=${user.companyId}`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }),
                fetch(`/api/payments/unmatched?companyId=${user.companyId}`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }),
                fetch(`/api/shippers?companyId=${user.companyId}`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }),
                fetch(`/api/payments/summary?companyId=${user.companyId}&year=${new Date().getFullYear()}`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                })
            ]);

            if (paymentsRes.ok) {
                const data = await paymentsRes.json();
                setPayments(data.payments || []);
            }

            if (unmatchedRes.ok) {
                setUnmatchedPayments(await unmatchedRes.json());
            }

            if (shippersRes.ok) {
                setShippers(await shippersRes.json());
            }

            if (summaryRes.ok) {
                const data = await summaryRes.json();
                // 月別サマリーから今月のデータを計算
                const thisMonth = data.find((d: any) =>
                    new Date(d.month).getMonth() === new Date().getMonth()
                );
                setSummary({
                    totalPayments: payments.length,
                    matchedAmount: data.reduce((sum: number, d: any) => sum + parseFloat(d.matched_amount || 0), 0),
                    unmatchedAmount: data.reduce((sum: number, d: any) => sum + parseFloat(d.unmatched_amount || 0), 0),
                    monthlyTotal: thisMonth ? parseFloat(thisMonth.total_amount) : 0
                });
            }
        } catch (err) {
            setError('データの取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const handleAddPayment = async () => {
        try {
            const res = await fetch('/api/payments', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    companyId: user.companyId,
                    ...newPayment,
                    shipperId: newPayment.shipperId || null
                })
            });

            if (res.ok) {
                setAddDialogOpen(false);
                setNewPayment({
                    paymentDate: new Date().toISOString().split('T')[0],
                    amount: 0,
                    paymentMethod: 'bank_transfer',
                    bankName: '',
                    branchName: '',
                    transferName: '',
                    shipperId: '',
                    notes: ''
                });
                fetchData();
            } else {
                setError('入金登録に失敗しました');
            }
        } catch (err) {
            setError('入金登録に失敗しました');
        }
    };

    const handleOpenMatchDialog = async (payment: Payment) => {
        setSelectedPayment(payment);
        setMatchDialogOpen(true);

        try {
            const res = await fetch(`/api/payments/${payment.id}/suggestions?companyId=${user.companyId}`, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });

            if (res.ok) {
                setMatchingSuggestions(await res.json());
            }
        } catch (err) {
            console.error('Failed to get suggestions:', err);
        }
    };

    const handleMatch = async (invoiceId: number) => {
        if (!selectedPayment) return;

        try {
            const res = await fetch(`/api/payments/${selectedPayment.id}/match`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({ invoiceId })
            });

            if (res.ok) {
                setMatchDialogOpen(false);
                fetchData();
            }
        } catch (err) {
            setError('消込に失敗しました');
        }
    };

    const handleUnmatch = async (paymentId: number) => {
        try {
            const res = await fetch(`/api/payments/${paymentId}/unmatch`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                }
            });

            if (res.ok) {
                fetchData();
            }
        } catch (err) {
            setError('消込解除に失敗しました');
        }
    };

    const formatCurrency = (amount: number) => {
        return new Intl.NumberFormat('ja-JP', {
            style: 'currency',
            currency: 'JPY'
        }).format(amount);
    };

    const formatDate = (dateStr: string) => {
        return new Date(dateStr).toLocaleDateString('ja-JP');
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
                    <Typography variant="h5" fontWeight="bold">入金管理</Typography>
                    <Typography color="text.secondary">入金登録・消込管理</Typography>
                </Box>
                <Button
                    variant="contained"
                    startIcon={<Add />}
                    onClick={() => setAddDialogOpen(true)}
                >
                    入金登録
                </Button>
            </Box>

            {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

            {/* サマリーカード */}
            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" gap={1}>
                                <AccountBalance color="primary" />
                                <Typography color="text.secondary" variant="body2">今月の入金</Typography>
                            </Box>
                            <Typography variant="h5" fontWeight="bold" mt={1}>
                                {formatCurrency(summary.monthlyTotal)}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" gap={1}>
                                <CheckCircle color="success" />
                                <Typography color="text.secondary" variant="body2">消込済</Typography>
                            </Box>
                            <Typography variant="h5" fontWeight="bold" mt={1} color="success.main">
                                {formatCurrency(summary.matchedAmount)}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card sx={{ bgcolor: unmatchedPayments.length > 0 ? 'warning.50' : 'inherit' }}>
                        <CardContent>
                            <Box display="flex" alignItems="center" gap={1}>
                                <Warning color="warning" />
                                <Typography color="text.secondary" variant="body2">未消込</Typography>
                            </Box>
                            <Typography variant="h5" fontWeight="bold" mt={1} color="warning.main">
                                {formatCurrency(summary.unmatchedAmount)}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                                {unmatchedPayments.length}件
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" gap={1}>
                                <TrendingUp color="info" />
                                <Typography color="text.secondary" variant="body2">総入金件数</Typography>
                            </Box>
                            <Typography variant="h5" fontWeight="bold" mt={1}>
                                {payments.length}件
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            {/* タブ */}
            <Paper sx={{ mb: 3 }}>
                <Tabs value={tab} onChange={(_, v) => setTab(v)}>
                    <Tab label="入金一覧" />
                    <Tab label={`未消込入金 (${unmatchedPayments.length})`} />
                </Tabs>
            </Paper>

            {tab === 0 && (
                <TableContainer component={Paper}>
                    <Table>
                        <TableHead>
                            <TableRow sx={{ bgcolor: '#f5f5f5' }}>
                                <TableCell>入金日</TableCell>
                                <TableCell>荷主</TableCell>
                                <TableCell>振込人名義</TableCell>
                                <TableCell>入金方法</TableCell>
                                <TableCell align="right">金額</TableCell>
                                <TableCell>請求書</TableCell>
                                <TableCell>消込状態</TableCell>
                                <TableCell align="center">操作</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {payments.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={8} align="center" sx={{ py: 4 }}>
                                        入金データがありません
                                    </TableCell>
                                </TableRow>
                            ) : (
                                payments.map((payment) => (
                                    <TableRow key={payment.id} hover>
                                        <TableCell>{formatDate(payment.payment_date)}</TableCell>
                                        <TableCell>{payment.shipper_name || '-'}</TableCell>
                                        <TableCell>{payment.transfer_name || '-'}</TableCell>
                                        <TableCell>
                                            {paymentMethodLabels[payment.payment_method] || payment.payment_method}
                                        </TableCell>
                                        <TableCell align="right">
                                            <Typography fontWeight="bold">
                                                {formatCurrency(payment.amount)}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            {payment.invoice_number || '-'}
                                        </TableCell>
                                        <TableCell>
                                            <Chip
                                                icon={payment.is_matched ? <CheckCircle /> : <Warning />}
                                                label={payment.is_matched ? '消込済' : '未消込'}
                                                color={payment.is_matched ? 'success' : 'warning'}
                                                size="small"
                                            />
                                        </TableCell>
                                        <TableCell align="center">
                                            {!payment.is_matched ? (
                                                <Tooltip title="消込">
                                                    <IconButton
                                                        size="small"
                                                        color="primary"
                                                        onClick={() => handleOpenMatchDialog(payment)}
                                                    >
                                                        <LinkIcon />
                                                    </IconButton>
                                                </Tooltip>
                                            ) : (
                                                <Tooltip title="消込解除">
                                                    <IconButton
                                                        size="small"
                                                        color="warning"
                                                        onClick={() => handleUnmatch(payment.id)}
                                                    >
                                                        <LinkOff />
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
            )}

            {tab === 1 && (
                <TableContainer component={Paper}>
                    <Table>
                        <TableHead>
                            <TableRow sx={{ bgcolor: '#f5f5f5' }}>
                                <TableCell>入金日</TableCell>
                                <TableCell>振込人名義</TableCell>
                                <TableCell>銀行</TableCell>
                                <TableCell align="right">金額</TableCell>
                                <TableCell>備考</TableCell>
                                <TableCell align="center">操作</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {unmatchedPayments.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={6} align="center" sx={{ py: 4 }}>
                                        未消込の入金はありません
                                    </TableCell>
                                </TableRow>
                            ) : (
                                unmatchedPayments.map((payment) => (
                                    <TableRow key={payment.id} hover sx={{ bgcolor: 'warning.50' }}>
                                        <TableCell>{formatDate(payment.payment_date)}</TableCell>
                                        <TableCell>
                                            <Typography fontWeight="bold">{payment.transfer_name || '不明'}</Typography>
                                        </TableCell>
                                        <TableCell>
                                            {payment.bank_name && `${payment.bank_name} ${payment.branch_name || ''}`}
                                        </TableCell>
                                        <TableCell align="right">
                                            <Typography fontWeight="bold" color="warning.main">
                                                {formatCurrency(payment.amount)}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>{payment.notes || '-'}</TableCell>
                                        <TableCell align="center">
                                            <Button
                                                variant="contained"
                                                size="small"
                                                startIcon={<LinkIcon />}
                                                onClick={() => handleOpenMatchDialog(payment)}
                                            >
                                                消込
                                            </Button>
                                        </TableCell>
                                    </TableRow>
                                ))
                            )}
                        </TableBody>
                    </Table>
                </TableContainer>
            )}

            {/* 入金登録ダイアログ */}
            <Dialog open={addDialogOpen} onClose={() => setAddDialogOpen(false)} maxWidth="sm" fullWidth>
                <DialogTitle>入金登録</DialogTitle>
                <DialogContent>
                    <Grid container spacing={2} sx={{ mt: 1 }}>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                label="入金日"
                                type="date"
                                fullWidth
                                required
                                value={newPayment.paymentDate}
                                onChange={(e) => setNewPayment({ ...newPayment, paymentDate: e.target.value })}
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                label="金額"
                                type="number"
                                fullWidth
                                required
                                value={newPayment.amount}
                                onChange={(e) => setNewPayment({ ...newPayment, amount: Number(e.target.value) })}
                                InputProps={{
                                    startAdornment: <InputAdornment position="start">¥</InputAdornment>
                                }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <FormControl fullWidth>
                                <InputLabel>入金方法</InputLabel>
                                <Select
                                    value={newPayment.paymentMethod}
                                    label="入金方法"
                                    onChange={(e) => setNewPayment({ ...newPayment, paymentMethod: e.target.value })}
                                >
                                    {Object.entries(paymentMethodLabels).map(([key, label]) => (
                                        <MenuItem key={key} value={key}>{label}</MenuItem>
                                    ))}
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <FormControl fullWidth>
                                <InputLabel>荷主</InputLabel>
                                <Select
                                    value={newPayment.shipperId}
                                    label="荷主"
                                    onChange={(e) => setNewPayment({ ...newPayment, shipperId: e.target.value as string })}
                                >
                                    <MenuItem value="">不明</MenuItem>
                                    {shippers.map((s) => (
                                        <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>
                                    ))}
                                </Select>
                            </FormControl>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                label="銀行名"
                                fullWidth
                                value={newPayment.bankName}
                                onChange={(e) => setNewPayment({ ...newPayment, bankName: e.target.value })}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                label="支店名"
                                fullWidth
                                value={newPayment.branchName}
                                onChange={(e) => setNewPayment({ ...newPayment, branchName: e.target.value })}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                label="振込人名義"
                                fullWidth
                                value={newPayment.transferName}
                                onChange={(e) => setNewPayment({ ...newPayment, transferName: e.target.value })}
                            />
                        </Grid>
                        <Grid size={12}>
                            <TextField
                                label="備考"
                                fullWidth
                                multiline
                                rows={2}
                                value={newPayment.notes}
                                onChange={(e) => setNewPayment({ ...newPayment, notes: e.target.value })}
                            />
                        </Grid>
                    </Grid>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setAddDialogOpen(false)}>キャンセル</Button>
                    <Button variant="contained" onClick={handleAddPayment}>登録</Button>
                </DialogActions>
            </Dialog>

            {/* 消込ダイアログ */}
            <Dialog open={matchDialogOpen} onClose={() => setMatchDialogOpen(false)} maxWidth="md" fullWidth>
                <DialogTitle>請求書との消込</DialogTitle>
                <DialogContent>
                    {selectedPayment && (
                        <Alert severity="info" sx={{ mb: 2 }}>
                            入金: {formatDate(selectedPayment.payment_date)} / {formatCurrency(selectedPayment.amount)}
                            {selectedPayment.transfer_name && ` / ${selectedPayment.transfer_name}`}
                        </Alert>
                    )}

                    <Typography variant="subtitle2" gutterBottom>消込候補（マッチング順）</Typography>
                    <List>
                        {matchingSuggestions.length === 0 ? (
                            <ListItem>
                                <ListItemText primary="該当する請求書がありません" />
                            </ListItem>
                        ) : (
                            matchingSuggestions.map((suggestion) => (
                                <ListItem
                                    key={suggestion.id}
                                    sx={{
                                        border: '1px solid #e0e0e0',
                                        borderRadius: 1,
                                        mb: 1,
                                        bgcolor: suggestion.match_score >= 80 ? 'success.50' : 'inherit'
                                    }}
                                >
                                    <ListItemText
                                        primary={
                                            <Box display="flex" alignItems="center" gap={1}>
                                                <Typography fontWeight="bold">{suggestion.invoice_number}</Typography>
                                                <Chip
                                                    label={`${suggestion.match_score}%`}
                                                    size="small"
                                                    color={suggestion.match_score >= 80 ? 'success' : 'default'}
                                                />
                                            </Box>
                                        }
                                        secondary={
                                            <>
                                                {suggestion.shipper_name} / 請求額: {formatCurrency(suggestion.total_amount)}
                                                {' '}/ 残高: {formatCurrency(suggestion.total_amount - suggestion.paid_amount)}
                                                {suggestion.amount_diff !== 0 && (
                                                    <Typography component="span" color="warning.main" sx={{ ml: 1 }}>
                                                        (差額: {formatCurrency(suggestion.amount_diff)})
                                                    </Typography>
                                                )}
                                            </>
                                        }
                                    />
                                    <ListItemSecondaryAction>
                                        <Button
                                            variant="contained"
                                            size="small"
                                            onClick={() => handleMatch(suggestion.id)}
                                        >
                                            消込
                                        </Button>
                                    </ListItemSecondaryAction>
                                </ListItem>
                            ))
                        )}
                    </List>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setMatchDialogOpen(false)}>閉じる</Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default PaymentManagement;
