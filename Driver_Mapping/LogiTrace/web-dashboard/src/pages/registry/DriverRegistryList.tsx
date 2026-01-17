import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    Container,
    FormControl,
    Grid,
    InputLabel,
    MenuItem,
    Paper,
    Select,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Typography,
    CircularProgress,
    Alert,
    IconButton,
    Tooltip
} from '@mui/material';
import {
    Add as AddIcon,
    Refresh as RefreshIcon,
    Visibility as ViewIcon,
    Edit as EditIcon,
    Warning as WarningIcon,
    PictureAsPdf as PdfIcon
} from '@mui/icons-material';

interface DriverRegistry {
    id: number;
    driver_id: number;
    full_name: string;
    full_name_kana: string;
    employee_number: string;
    driver_email: string;
    hire_date: string;
    license_number: string;
    license_type: string;
    license_expiry_date: string;
    status: 'active' | 'inactive' | 'suspended';
    phone: string;
}

export default function DriverRegistryList() {
    const navigate = useNavigate();
    const [registries, setRegistries] = useState<DriverRegistry[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [statusFilter, setStatusFilter] = useState<string>('active');
    const [expiringOnly, setExpiringOnly] = useState(false);
    const [downloadingPdf, setDownloadingPdf] = useState(false);

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchRegistries();
    }, [statusFilter, expiringOnly]);

    const fetchRegistries = async () => {
        setLoading(true);
        try {
            let url = `/api/driver-registry?companyId=${companyId}`;
            if (statusFilter) url += `&status=${statusFilter}`;
            if (expiringOnly) url += `&licenseExpiringSoon=true`;

            const response = await fetch(url, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });

            if (!response.ok) throw new Error('Failed to fetch registries');
            const data = await response.json();
            setRegistries(data);
        } catch (err) {
            setError('運転者台帳の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'active': return 'success';
            case 'inactive': return 'default';
            case 'suspended': return 'error';
            default: return 'default';
        }
    };

    const getStatusLabel = (status: string) => {
        switch (status) {
            case 'active': return '在籍';
            case 'inactive': return '退職';
            case 'suspended': return '休止';
            default: return status;
        }
    };

    const getLicenseTypeLabel = (type: string) => {
        const types: { [key: string]: string } = {
            'large': '大型',
            'medium': '中型',
            'ordinary': '普通',
            'large_special': '大型特殊',
            'second_class_large': '大型二種',
            'second_class_medium': '中型二種',
            'second_class_ordinary': '普通二種'
        };
        return types[type] || type;
    };

    const getDaysUntilExpiry = (expiryDate: string) => {
        const expiry = new Date(expiryDate);
        const today = new Date();
        const diffTime = expiry.getTime() - today.getTime();
        return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    };

    const getExpiryChip = (expiryDate: string) => {
        const days = getDaysUntilExpiry(expiryDate);
        if (days < 0) {
            return <Chip label="期限切れ" color="error" size="small" icon={<WarningIcon />} />;
        } else if (days <= 7) {
            return <Chip label={`残${days}日`} color="error" size="small" />;
        } else if (days <= 30) {
            return <Chip label={`残${days}日`} color="warning" size="small" />;
        }
        return <Chip label="有効" color="success" size="small" />;
    };

    const handleDownloadListPDF = async () => {
        setDownloadingPdf(true);
        try {
            const response = await fetch(
                `/api/audit/driver-registry-list/pdf?companyId=${companyId}`,
                {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }
            );
            if (!response.ok) throw new Error('PDF download failed');

            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `運転者台帳一覧_${new Date().toISOString().split('T')[0]}.pdf`;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(a);
        } catch (err) {
            console.error('PDF download error:', err);
            alert('PDFのダウンロードに失敗しました');
        } finally {
            setDownloadingPdf(false);
        }
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4" component="h1">
                        運転者台帳
                    </Typography>
                    <Box sx={{ display: 'flex', gap: 1 }}>
                        <Button
                            variant="outlined"
                            startIcon={<PdfIcon />}
                            onClick={handleDownloadListPDF}
                            disabled={downloadingPdf}
                        >
                            {downloadingPdf ? '出力中...' : '一覧PDF出力'}
                        </Button>
                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={fetchRegistries}
                        >
                            更新
                        </Button>
                        <Button
                            variant="contained"
                            startIcon={<AddIcon />}
                            onClick={() => navigate('/registry/new')}
                        >
                            新規登録
                        </Button>
                    </Box>
                </Box>

                {/* フィルター */}
                <Card sx={{ mb: 3 }}>
                    <CardContent>
                        <Grid container spacing={2} alignItems="center">
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <FormControl fullWidth>
                                    <InputLabel>ステータス</InputLabel>
                                    <Select
                                        value={statusFilter}
                                        label="ステータス"
                                        onChange={(e) => setStatusFilter(e.target.value)}
                                    >
                                        <MenuItem value="">すべて</MenuItem>
                                        <MenuItem value="active">在籍</MenuItem>
                                        <MenuItem value="inactive">退職</MenuItem>
                                        <MenuItem value="suspended">休止</MenuItem>
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid size={{ xs: 12, sm: 3 }}>
                                <FormControl fullWidth>
                                    <InputLabel>免許期限</InputLabel>
                                    <Select
                                        value={expiringOnly ? 'expiring' : ''}
                                        label="免許期限"
                                        onChange={(e) => setExpiringOnly(e.target.value === 'expiring')}
                                    >
                                        <MenuItem value="">すべて</MenuItem>
                                        <MenuItem value="expiring">30日以内に期限切れ</MenuItem>
                                    </Select>
                                </FormControl>
                            </Grid>
                        </Grid>
                    </CardContent>
                </Card>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

                {loading ? (
                    <Box display="flex" justifyContent="center" py={4}>
                        <CircularProgress />
                    </Box>
                ) : (
                    <TableContainer component={Paper}>
                        <Table>
                            <TableHead>
                                <TableRow>
                                    <TableCell>氏名</TableCell>
                                    <TableCell>社員番号</TableCell>
                                    <TableCell>入社日</TableCell>
                                    <TableCell>免許種類</TableCell>
                                    <TableCell>免許番号</TableCell>
                                    <TableCell>免許有効期限</TableCell>
                                    <TableCell>ステータス</TableCell>
                                    <TableCell align="right">操作</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {registries.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={8} align="center">
                                            運転者台帳が登録されていません
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    registries.map((registry) => (
                                        <TableRow key={registry.id} hover>
                                            <TableCell>
                                                <Typography variant="body2" fontWeight="bold">
                                                    {registry.full_name}
                                                </Typography>
                                                <Typography variant="caption" color="text.secondary">
                                                    {registry.full_name_kana}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>{registry.employee_number || '-'}</TableCell>
                                            <TableCell>
                                                {new Date(registry.hire_date).toLocaleDateString('ja-JP')}
                                            </TableCell>
                                            <TableCell>{getLicenseTypeLabel(registry.license_type)}</TableCell>
                                            <TableCell>{registry.license_number}</TableCell>
                                            <TableCell>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    {new Date(registry.license_expiry_date).toLocaleDateString('ja-JP')}
                                                    {getExpiryChip(registry.license_expiry_date)}
                                                </Box>
                                            </TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={getStatusLabel(registry.status)}
                                                    color={getStatusColor(registry.status) as any}
                                                    size="small"
                                                />
                                            </TableCell>
                                            <TableCell align="right">
                                                <Tooltip title="詳細">
                                                    <IconButton onClick={() => navigate(`/registry/${registry.id}`)}>
                                                        <ViewIcon />
                                                    </IconButton>
                                                </Tooltip>
                                                <Tooltip title="編集">
                                                    <IconButton onClick={() => navigate(`/registry/${registry.id}/edit`)}>
                                                        <EditIcon />
                                                    </IconButton>
                                                </Tooltip>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                )}
            </Box>
        </Container>
    );
}
