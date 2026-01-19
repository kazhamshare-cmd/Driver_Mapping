/**
 * Invoice List - 請求書一覧・管理画面
 */

import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
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
    Chip,
    IconButton,
    TextField,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Grid,
    Card,
    CardContent,
    Tabs,
    Tab,
    CircularProgress,
    Alert,
    Tooltip,
    Menu,
    ListItemIcon,
    ListItemText
} from '@mui/material';
import {
    Add,
    Visibility,
    PictureAsPdf,
    Send,
    MoreVert,
    FilterList,
    Receipt,
    AccountBalance,
    TrendingUp,
    Warning,
    CheckCircle,
    Schedule,
    Cancel
} from '@mui/icons-material';

interface Invoice {
    id: number;
    invoice_number: string;
    invoice_date: string;
    due_date: string;
    shipper_name: string;
    subtotal: number;
    tax_amount: number;
    total_amount: number;
    paid_amount: number;
    status: string;
    item_count: number;
}

interface AccountReceivable {
    shipper_id: number;
    shipper_name: string;
    invoice_count: number;
    total_billed: number;
    total_paid: number;
    outstanding_balance: number;
    overdue_balance: number;
    earliest_due_date: string;
}

interface Shipper {
    id: number;
    name: string;
}

const statusConfig: Record<string, { label: string; color: 'default' | 'primary' | 'secondary' | 'error' | 'info' | 'success' | 'warning'; icon: any }> = {
    draft: { label: '下書き', color: 'default', icon: <Schedule fontSize="small" /> },
    issued: { label: '発行済', color: 'primary', icon: <Receipt fontSize="small" /> },
    sent: { label: '送付済', color: 'info', icon: <Send fontSize="small" /> },
    partial: { label: '一部入金', color: 'warning', icon: <AccountBalance fontSize="small" /> },
    paid: { label: '入金済', color: 'success', icon: <CheckCircle fontSize="small" /> },
    overdue: { label: '支払遅延', color: 'error', icon: <Warning fontSize="small" /> },
    cancelled: { label: 'キャンセル', color: 'default', icon: <Cancel fontSize="small" /> }
};

const InvoiceList = () => {
    const navigate = useNavigate();
    const [tab, setTab] = useState(0);
    const [invoices, setInvoices] = useState<Invoice[]>([]);
    const [accounts, setAccounts] = useState<AccountReceivable[]>([]);
    const [shippers, setShippers] = useState<Shipper[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    // フィルタ
    const [statusFilter, setStatusFilter] = useState<string>('');
    const [shipperFilter, setShipperFilter] = useState<string>('');
    const [dateFrom, setDateFrom] = useState<string>('');
    const [dateTo, setDateTo] = useState<string>('');

    // メニュー
    const [menuAnchor, setMenuAnchor] = useState<{ element: HTMLElement; invoiceId: number } | null>(null);

    // サマリー
    const [summary, setSummary] = useState({
        totalBilled: 0,
        totalPaid: 0,
        outstandingBalance: 0,
        overdueBalance: 0
    });

    const user = JSON.parse(localStorage.getItem('user') || '{}');

    useEffect(() => {
        fetchData();
    }, [statusFilter, shipperFilter, dateFrom, dateTo]);

    const fetchData = async () => {
        setLoading(true);
        try {
            // 請求書一覧
            let invoiceUrl = `/api/invoices?companyId=${user.companyId}`;
            if (statusFilter) invoiceUrl += `&status=${statusFilter}`;
            if (shipperFilter) invoiceUrl += `&shipperId=${shipperFilter}`;
            if (dateFrom) invoiceUrl += `&dateFrom=${dateFrom}`;
            if (dateTo) invoiceUrl += `&dateTo=${dateTo}`;

            const [invoicesRes, accountsRes, shippersRes] = await Promise.all([
                fetch(invoiceUrl, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }),
                fetch(`/api/invoices/accounts-receivable?companyId=${user.companyId}`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }),
                fetch(`/api/shippers?companyId=${user.companyId}`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                })
            ]);

            if (invoicesRes.ok) {
                const data = await invoicesRes.json();
                setInvoices(data.invoices || []);
            }

            if (accountsRes.ok) {
                const data = await accountsRes.json();
                setAccounts(data.accounts || []);
                setSummary(data.summary || {
                    totalBilled: 0,
                    totalPaid: 0,
                    outstandingBalance: 0,
                    overdueBalance: 0
                });
            }

            if (shippersRes.ok) {
                const data = await shippersRes.json();
                setShippers(data);
            }
        } catch (err) {
            setError('データの取得に失敗しました');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    const handleStatusChange = async (invoiceId: number, newStatus: string) => {
        try {
            const res = await fetch(`/api/invoices/${invoiceId}/status`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({ status: newStatus })
            });

            if (res.ok) {
                fetchData();
            }
        } catch (err) {
            console.error('Failed to update status:', err);
        }
        setMenuAnchor(null);
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
                    <Typography variant="h5" fontWeight="bold">請求書管理</Typography>
                    <Typography color="text.secondary">インボイス制度対応・請求書発行・入金管理</Typography>
                </Box>
                <Box display="flex" gap={2}>
                    <Button
                        variant="outlined"
                        onClick={() => navigate('/billing/fare-settings')}
                    >
                        運賃設定
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<Add />}
                        onClick={() => navigate('/billing/invoices/new')}
                    >
                        新規請求書
                    </Button>
                </Box>
            </Box>

            {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

            {/* サマリーカード */}
            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" gap={1}>
                                <Receipt color="primary" />
                                <Typography color="text.secondary" variant="body2">総請求額</Typography>
                            </Box>
                            <Typography variant="h5" fontWeight="bold" mt={1}>
                                {formatCurrency(summary.totalBilled)}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" gap={1}>
                                <CheckCircle color="success" />
                                <Typography color="text.secondary" variant="body2">入金済</Typography>
                            </Box>
                            <Typography variant="h5" fontWeight="bold" mt={1} color="success.main">
                                {formatCurrency(summary.totalPaid)}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Box display="flex" alignItems="center" gap={1}>
                                <AccountBalance color="warning" />
                                <Typography color="text.secondary" variant="body2">売掛残高</Typography>
                            </Box>
                            <Typography variant="h5" fontWeight="bold" mt={1} color="warning.main">
                                {formatCurrency(summary.outstandingBalance)}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card sx={{ bgcolor: summary.overdueBalance > 0 ? 'error.50' : 'inherit' }}>
                        <CardContent>
                            <Box display="flex" alignItems="center" gap={1}>
                                <Warning color="error" />
                                <Typography color="text.secondary" variant="body2">支払遅延</Typography>
                            </Box>
                            <Typography variant="h5" fontWeight="bold" mt={1} color="error.main">
                                {formatCurrency(summary.overdueBalance)}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            {/* タブ */}
            <Paper sx={{ mb: 3 }}>
                <Tabs value={tab} onChange={(_, v) => setTab(v)}>
                    <Tab label="請求書一覧" />
                    <Tab label="売掛金残高" />
                </Tabs>
            </Paper>

            {tab === 0 && (
                <>
                    {/* フィルタ */}
                    <Paper sx={{ p: 2, mb: 2 }}>
                        <Grid container spacing={2} alignItems="center">
                            <Grid size={{ xs: 12, sm: 6, md: 2 }}>
                                <FormControl fullWidth size="small">
                                    <InputLabel>ステータス</InputLabel>
                                    <Select
                                        value={statusFilter}
                                        label="ステータス"
                                        onChange={(e) => setStatusFilter(e.target.value)}
                                    >
                                        <MenuItem value="">すべて</MenuItem>
                                        {Object.entries(statusConfig).map(([key, config]) => (
                                            <MenuItem key={key} value={key}>{config.label}</MenuItem>
                                        ))}
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid size={{ xs: 12, sm: 6, md: 2 }}>
                                <FormControl fullWidth size="small">
                                    <InputLabel>荷主</InputLabel>
                                    <Select
                                        value={shipperFilter}
                                        label="荷主"
                                        onChange={(e) => setShipperFilter(e.target.value)}
                                    >
                                        <MenuItem value="">すべて</MenuItem>
                                        {shippers.map((s) => (
                                            <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>
                                        ))}
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid size={{ xs: 12, sm: 6, md: 2 }}>
                                <TextField
                                    type="date"
                                    label="発行日（From）"
                                    size="small"
                                    fullWidth
                                    value={dateFrom}
                                    onChange={(e) => setDateFrom(e.target.value)}
                                    InputLabelProps={{ shrink: true }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12, sm: 6, md: 2 }}>
                                <TextField
                                    type="date"
                                    label="発行日（To）"
                                    size="small"
                                    fullWidth
                                    value={dateTo}
                                    onChange={(e) => setDateTo(e.target.value)}
                                    InputLabelProps={{ shrink: true }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12, sm: 6, md: 2 }}>
                                <Button
                                    variant="outlined"
                                    startIcon={<FilterList />}
                                    onClick={() => {
                                        setStatusFilter('');
                                        setShipperFilter('');
                                        setDateFrom('');
                                        setDateTo('');
                                    }}
                                >
                                    クリア
                                </Button>
                            </Grid>
                        </Grid>
                    </Paper>

                    {/* 請求書テーブル */}
                    <TableContainer component={Paper}>
                        <Table>
                            <TableHead>
                                <TableRow sx={{ bgcolor: '#f5f5f5' }}>
                                    <TableCell>請求書番号</TableCell>
                                    <TableCell>荷主</TableCell>
                                    <TableCell>発行日</TableCell>
                                    <TableCell>支払期限</TableCell>
                                    <TableCell align="right">請求額</TableCell>
                                    <TableCell align="right">入金額</TableCell>
                                    <TableCell>ステータス</TableCell>
                                    <TableCell align="center">操作</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {invoices.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={8} align="center" sx={{ py: 4 }}>
                                            請求書がありません
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    invoices.map((invoice) => {
                                        const config = statusConfig[invoice.status] || statusConfig.draft;
                                        const isOverdue = new Date(invoice.due_date) < new Date() &&
                                            invoice.status !== 'paid' && invoice.status !== 'cancelled';

                                        return (
                                            <TableRow
                                                key={invoice.id}
                                                hover
                                                sx={{ bgcolor: isOverdue ? 'error.50' : 'inherit' }}
                                            >
                                                <TableCell>
                                                    <Typography fontWeight="bold">{invoice.invoice_number}</Typography>
                                                    <Typography variant="caption" color="text.secondary">
                                                        {invoice.item_count}件
                                                    </Typography>
                                                </TableCell>
                                                <TableCell>{invoice.shipper_name}</TableCell>
                                                <TableCell>{formatDate(invoice.invoice_date)}</TableCell>
                                                <TableCell>
                                                    <Typography color={isOverdue ? 'error' : 'inherit'}>
                                                        {formatDate(invoice.due_date)}
                                                    </Typography>
                                                </TableCell>
                                                <TableCell align="right">
                                                    <Typography fontWeight="bold">
                                                        {formatCurrency(invoice.total_amount)}
                                                    </Typography>
                                                </TableCell>
                                                <TableCell align="right">
                                                    {formatCurrency(invoice.paid_amount)}
                                                </TableCell>
                                                <TableCell>
                                                    <Chip
                                                        icon={config.icon}
                                                        label={config.label}
                                                        color={config.color}
                                                        size="small"
                                                    />
                                                </TableCell>
                                                <TableCell align="center">
                                                    <Tooltip title="詳細">
                                                        <IconButton
                                                            size="small"
                                                            onClick={() => navigate(`/billing/invoices/${invoice.id}`)}
                                                        >
                                                            <Visibility />
                                                        </IconButton>
                                                    </Tooltip>
                                                    <Tooltip title="PDF">
                                                        <IconButton size="small">
                                                            <PictureAsPdf />
                                                        </IconButton>
                                                    </Tooltip>
                                                    <IconButton
                                                        size="small"
                                                        onClick={(e) => setMenuAnchor({ element: e.currentTarget, invoiceId: invoice.id })}
                                                    >
                                                        <MoreVert />
                                                    </IconButton>
                                                </TableCell>
                                            </TableRow>
                                        );
                                    })
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                </>
            )}

            {tab === 1 && (
                <TableContainer component={Paper}>
                    <Table>
                        <TableHead>
                            <TableRow sx={{ bgcolor: '#f5f5f5' }}>
                                <TableCell>荷主</TableCell>
                                <TableCell align="right">請求件数</TableCell>
                                <TableCell align="right">総請求額</TableCell>
                                <TableCell align="right">入金済額</TableCell>
                                <TableCell align="right">売掛残高</TableCell>
                                <TableCell align="right">支払遅延額</TableCell>
                                <TableCell>最短支払期限</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {accounts.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={7} align="center" sx={{ py: 4 }}>
                                        データがありません
                                    </TableCell>
                                </TableRow>
                            ) : (
                                accounts.map((account) => (
                                    <TableRow
                                        key={account.shipper_id}
                                        hover
                                        sx={{
                                            bgcolor: account.overdue_balance > 0 ? 'error.50' : 'inherit',
                                            cursor: 'pointer'
                                        }}
                                        onClick={() => setShipperFilter(String(account.shipper_id))}
                                    >
                                        <TableCell>
                                            <Typography fontWeight="bold">{account.shipper_name}</Typography>
                                        </TableCell>
                                        <TableCell align="right">{account.invoice_count}件</TableCell>
                                        <TableCell align="right">{formatCurrency(account.total_billed)}</TableCell>
                                        <TableCell align="right" sx={{ color: 'success.main' }}>
                                            {formatCurrency(account.total_paid)}
                                        </TableCell>
                                        <TableCell align="right" sx={{ fontWeight: 'bold', color: 'warning.main' }}>
                                            {formatCurrency(account.outstanding_balance)}
                                        </TableCell>
                                        <TableCell align="right" sx={{ color: 'error.main' }}>
                                            {formatCurrency(account.overdue_balance)}
                                        </TableCell>
                                        <TableCell>
                                            {account.earliest_due_date ? formatDate(account.earliest_due_date) : '-'}
                                        </TableCell>
                                    </TableRow>
                                ))
                            )}
                        </TableBody>
                    </Table>
                </TableContainer>
            )}

            {/* アクションメニュー */}
            <Menu
                anchorEl={menuAnchor?.element}
                open={Boolean(menuAnchor)}
                onClose={() => setMenuAnchor(null)}
            >
                <MenuItem onClick={() => handleStatusChange(menuAnchor!.invoiceId, 'issued')}>
                    <ListItemIcon><Receipt fontSize="small" /></ListItemIcon>
                    <ListItemText>発行済にする</ListItemText>
                </MenuItem>
                <MenuItem onClick={() => handleStatusChange(menuAnchor!.invoiceId, 'sent')}>
                    <ListItemIcon><Send fontSize="small" /></ListItemIcon>
                    <ListItemText>送付済にする</ListItemText>
                </MenuItem>
                <MenuItem onClick={() => handleStatusChange(menuAnchor!.invoiceId, 'cancelled')}>
                    <ListItemIcon><Cancel fontSize="small" /></ListItemIcon>
                    <ListItemText>キャンセル</ListItemText>
                </MenuItem>
            </Menu>
        </Box>
    );
};

export default InvoiceList;
