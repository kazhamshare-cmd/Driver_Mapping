import { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Button,
    Chip,
    IconButton,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Alert,
    Snackbar,
    CircularProgress,
    Card,
    CardContent
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    ContentCopy as CopyIcon,
    Link as LinkIcon
} from '@mui/icons-material';

interface Driver {
    id: number;
    email: string;
    name: string;
    employee_number: string | null;
    status: 'active' | 'inactive' | 'pending';
    created_at: string;
}

interface CompanyInfo {
    id: number;
    company_code: string;
    name: string;
}

export default function DriverList() {
    const [drivers, setDrivers] = useState<Driver[]>([]);
    const [companyInfo, setCompanyInfo] = useState<CompanyInfo | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' as 'success' | 'error' });

    // ダイアログ状態
    const [addDialogOpen, setAddDialogOpen] = useState(false);
    const [inviteDialogOpen, setInviteDialogOpen] = useState(false);
    const [editDialogOpen, setEditDialogOpen] = useState(false);
    const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
    const [selectedDriver, setSelectedDriver] = useState<Driver | null>(null);

    // フォーム状態
    const [formData, setFormData] = useState({
        name: '',
        email: '',
        employeeNumber: '',
        password: ''
    });
    const [inviteUrl, setInviteUrl] = useState('');

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1; // 仮のcompanyId

    useEffect(() => {
        fetchDrivers();
        fetchCompanyInfo();
    }, []);

    const fetchDrivers = async () => {
        try {
            const response = await fetch(`/api/drivers?companyId=${companyId}`, {
                headers: {
                    'Authorization': `Bearer ${user.token}`
                }
            });
            if (!response.ok) throw new Error('Failed to fetch drivers');
            const data = await response.json();
            setDrivers(data);
        } catch (err) {
            setError('ドライバー一覧の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const fetchCompanyInfo = async () => {
        try {
            const response = await fetch(`/api/drivers/company/${companyId}`, {
                headers: {
                    'Authorization': `Bearer ${user.token}`
                }
            });
            if (response.ok) {
                const data = await response.json();
                setCompanyInfo(data);
            }
        } catch (err) {
            console.error('Failed to fetch company info');
        }
    };

    const handleAddDriver = async () => {
        try {
            const response = await fetch('/api/drivers', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    companyId,
                    ...formData
                })
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || 'Failed to add driver');
            }

            setSnackbar({ open: true, message: 'ドライバーを追加しました', severity: 'success' });
            setAddDialogOpen(false);
            resetForm();
            fetchDrivers();
        } catch (err: any) {
            setSnackbar({ open: true, message: err.message, severity: 'error' });
        }
    };

    const handleCreateInvite = async () => {
        try {
            const response = await fetch('/api/drivers/invite', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    companyId,
                    email: formData.email,
                    name: formData.name
                })
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || 'Failed to create invite');
            }

            const data = await response.json();
            setInviteUrl(data.inviteUrl);
            setSnackbar({ open: true, message: '招待リンクを生成しました', severity: 'success' });
            fetchDrivers();
        } catch (err: any) {
            setSnackbar({ open: true, message: err.message, severity: 'error' });
        }
    };

    const handleUpdateDriver = async () => {
        if (!selectedDriver) return;

        try {
            const response = await fetch(`/api/drivers/${selectedDriver.id}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    name: formData.name,
                    employeeNumber: formData.employeeNumber
                })
            });

            if (!response.ok) throw new Error('Failed to update driver');

            setSnackbar({ open: true, message: 'ドライバー情報を更新しました', severity: 'success' });
            setEditDialogOpen(false);
            resetForm();
            fetchDrivers();
        } catch (err) {
            setSnackbar({ open: true, message: '更新に失敗しました', severity: 'error' });
        }
    };

    const handleDeleteDriver = async () => {
        if (!selectedDriver) return;

        try {
            const response = await fetch(`/api/drivers/${selectedDriver.id}`, {
                method: 'DELETE',
                headers: {
                    'Authorization': `Bearer ${user.token}`
                }
            });

            if (!response.ok) throw new Error('Failed to delete driver');

            setSnackbar({ open: true, message: 'ドライバーを削除しました', severity: 'success' });
            setDeleteDialogOpen(false);
            setSelectedDriver(null);
            fetchDrivers();
        } catch (err) {
            setSnackbar({ open: true, message: '削除に失敗しました', severity: 'error' });
        }
    };

    const resetForm = () => {
        setFormData({ name: '', email: '', employeeNumber: '', password: '' });
        setInviteUrl('');
        setSelectedDriver(null);
    };

    const openEditDialog = (driver: Driver) => {
        setSelectedDriver(driver);
        setFormData({
            name: driver.name,
            email: driver.email,
            employeeNumber: driver.employee_number || '',
            password: ''
        });
        setEditDialogOpen(true);
    };

    const copyToClipboard = (text: string) => {
        navigator.clipboard.writeText(text);
        setSnackbar({ open: true, message: 'コピーしました', severity: 'success' });
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'active': return 'success';
            case 'inactive': return 'error';
            case 'pending': return 'warning';
            default: return 'default';
        }
    };

    const getStatusLabel = (status: string) => {
        switch (status) {
            case 'active': return '有効';
            case 'inactive': return '無効';
            case 'pending': return '招待中';
            default: return status;
        }
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
            <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
                <Typography variant="h5" fontWeight="bold">
                    ドライバー管理
                </Typography>
                <Box>
                    <Button
                        variant="outlined"
                        startIcon={<LinkIcon />}
                        onClick={() => { resetForm(); setInviteDialogOpen(true); }}
                        sx={{ mr: 1 }}
                    >
                        招待リンク生成
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={() => { resetForm(); setAddDialogOpen(true); }}
                    >
                        ドライバー追加
                    </Button>
                </Box>
            </Box>

            {/* 会社コード表示 */}
            {companyInfo && (
                <Card sx={{ mb: 3, bgcolor: '#f5f5f5' }}>
                    <CardContent>
                        <Typography variant="subtitle2" color="text.secondary">
                            ドライバー自己登録用 会社コード
                        </Typography>
                        <Box display="flex" alignItems="center" gap={1}>
                            <Typography variant="h6" fontFamily="monospace" fontWeight="bold">
                                {companyInfo.company_code}
                            </Typography>
                            <IconButton size="small" onClick={() => copyToClipboard(companyInfo.company_code)}>
                                <CopyIcon fontSize="small" />
                            </IconButton>
                        </Box>
                        <Typography variant="caption" color="text.secondary">
                            ドライバーがモバイルアプリから登録する際に使用します
                        </Typography>
                    </CardContent>
                </Card>
            )}

            {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

            <TableContainer component={Paper}>
                <Table>
                    <TableHead>
                        <TableRow>
                            <TableCell>名前</TableCell>
                            <TableCell>メールアドレス</TableCell>
                            <TableCell>社員番号</TableCell>
                            <TableCell>ステータス</TableCell>
                            <TableCell>登録日</TableCell>
                            <TableCell align="right">操作</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {drivers.length === 0 ? (
                            <TableRow>
                                <TableCell colSpan={6} align="center">
                                    ドライバーが登録されていません
                                </TableCell>
                            </TableRow>
                        ) : (
                            drivers.map((driver) => (
                                <TableRow key={driver.id}>
                                    <TableCell>{driver.name}</TableCell>
                                    <TableCell>{driver.email}</TableCell>
                                    <TableCell>{driver.employee_number || '-'}</TableCell>
                                    <TableCell>
                                        <Chip
                                            label={getStatusLabel(driver.status)}
                                            color={getStatusColor(driver.status) as any}
                                            size="small"
                                        />
                                    </TableCell>
                                    <TableCell>
                                        {new Date(driver.created_at).toLocaleDateString('ja-JP')}
                                    </TableCell>
                                    <TableCell align="right">
                                        <IconButton onClick={() => openEditDialog(driver)}>
                                            <EditIcon />
                                        </IconButton>
                                        <IconButton
                                            color="error"
                                            onClick={() => {
                                                setSelectedDriver(driver);
                                                setDeleteDialogOpen(true);
                                            }}
                                        >
                                            <DeleteIcon />
                                        </IconButton>
                                    </TableCell>
                                </TableRow>
                            ))
                        )}
                    </TableBody>
                </Table>
            </TableContainer>

            {/* ドライバー追加ダイアログ */}
            <Dialog open={addDialogOpen} onClose={() => setAddDialogOpen(false)} maxWidth="sm" fullWidth>
                <DialogTitle>ドライバー追加</DialogTitle>
                <DialogContent>
                    <TextField
                        label="名前"
                        fullWidth
                        margin="normal"
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    />
                    <TextField
                        label="メールアドレス"
                        type="email"
                        fullWidth
                        margin="normal"
                        value={formData.email}
                        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    />
                    <TextField
                        label="社員番号（任意）"
                        fullWidth
                        margin="normal"
                        value={formData.employeeNumber}
                        onChange={(e) => setFormData({ ...formData, employeeNumber: e.target.value })}
                    />
                    <TextField
                        label="初期パスワード"
                        type="password"
                        fullWidth
                        margin="normal"
                        value={formData.password}
                        onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setAddDialogOpen(false)}>キャンセル</Button>
                    <Button variant="contained" onClick={handleAddDriver}>追加</Button>
                </DialogActions>
            </Dialog>

            {/* 招待リンク生成ダイアログ */}
            <Dialog open={inviteDialogOpen} onClose={() => { setInviteDialogOpen(false); resetForm(); }} maxWidth="sm" fullWidth>
                <DialogTitle>招待リンク生成</DialogTitle>
                <DialogContent>
                    {!inviteUrl ? (
                        <>
                            <TextField
                                label="名前"
                                fullWidth
                                margin="normal"
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                            />
                            <TextField
                                label="メールアドレス"
                                type="email"
                                fullWidth
                                margin="normal"
                                value={formData.email}
                                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                            />
                        </>
                    ) : (
                        <Box>
                            <Alert severity="success" sx={{ mb: 2 }}>
                                招待リンクを生成しました（7日間有効）
                            </Alert>
                            <TextField
                                label="招待URL"
                                fullWidth
                                value={inviteUrl}
                                InputProps={{
                                    readOnly: true,
                                    endAdornment: (
                                        <IconButton onClick={() => copyToClipboard(inviteUrl)}>
                                            <CopyIcon />
                                        </IconButton>
                                    )
                                }}
                            />
                            <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                                このURLをドライバーに共有してください
                            </Typography>
                        </Box>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => { setInviteDialogOpen(false); resetForm(); }}>閉じる</Button>
                    {!inviteUrl && (
                        <Button variant="contained" onClick={handleCreateInvite}>生成</Button>
                    )}
                </DialogActions>
            </Dialog>

            {/* 編集ダイアログ */}
            <Dialog open={editDialogOpen} onClose={() => setEditDialogOpen(false)} maxWidth="sm" fullWidth>
                <DialogTitle>ドライバー編集</DialogTitle>
                <DialogContent>
                    <TextField
                        label="名前"
                        fullWidth
                        margin="normal"
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    />
                    <TextField
                        label="社員番号（任意）"
                        fullWidth
                        margin="normal"
                        value={formData.employeeNumber}
                        onChange={(e) => setFormData({ ...formData, employeeNumber: e.target.value })}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setEditDialogOpen(false)}>キャンセル</Button>
                    <Button variant="contained" onClick={handleUpdateDriver}>保存</Button>
                </DialogActions>
            </Dialog>

            {/* 削除確認ダイアログ */}
            <Dialog open={deleteDialogOpen} onClose={() => setDeleteDialogOpen(false)}>
                <DialogTitle>ドライバー削除</DialogTitle>
                <DialogContent>
                    <Typography>
                        {selectedDriver?.name} を削除しますか？
                    </Typography>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDeleteDialogOpen(false)}>キャンセル</Button>
                    <Button color="error" variant="contained" onClick={handleDeleteDriver}>削除</Button>
                </DialogActions>
            </Dialog>

            {/* Snackbar */}
            <Snackbar
                open={snackbar.open}
                autoHideDuration={3000}
                onClose={() => setSnackbar({ ...snackbar, open: false })}
            >
                <Alert severity={snackbar.severity}>{snackbar.message}</Alert>
            </Snackbar>
        </Box>
    );
}
