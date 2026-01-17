import { useState, useEffect } from 'react';
import {
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    Checkbox,
    Chip,
    Container,
    FormControl,
    FormControlLabel,
    FormGroup,
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
    TextField,
    Typography,
    CircularProgress,
    LinearProgress,
} from '@mui/material';
import {
    Download as DownloadIcon,
    PictureAsPdf as PdfIcon,
    Refresh as RefreshIcon,
    CheckCircle as CheckIcon,
    Error as ErrorIcon,
    HourglassEmpty as PendingIcon,
} from '@mui/icons-material';

interface Driver {
    id: number;
    name: string;
    email: string;
}

interface ExportHistory {
    id: number;
    export_type: string;
    date_from: string;
    date_to: string;
    driver_ids: number[];
    pdf_url: string | null;
    status: string;
    generated_by_name: string;
    created_at: string;
}

export default function AuditExport() {
    const [loading, setLoading] = useState(false);
    const [generating, setGenerating] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [drivers, setDrivers] = useState<Driver[]>([]);
    const [history, setHistory] = useState<ExportHistory[]>([]);

    // フォームデータ
    const [exportType, setExportType] = useState('all');
    const [dateFrom, setDateFrom] = useState(() => {
        const date = new Date();
        date.setMonth(date.getMonth() - 1);
        return date.toISOString().split('T')[0];
    });
    const [dateTo, setDateTo] = useState(new Date().toISOString().split('T')[0]);
    const [selectedDrivers, setSelectedDrivers] = useState<number[]>([]);
    const [selectAll, setSelectAll] = useState(true);

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchDrivers();
        fetchHistory();
    }, []);

    const fetchDrivers = async () => {
        try {
            const response = await fetch(`/api/drivers?companyId=${companyId}`, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (response.ok) {
                const data = await response.json();
                setDrivers(data.filter((d: any) => d.status === 'active'));
            }
        } catch (err) {
            console.error('Error fetching drivers:', err);
        }
    };

    const fetchHistory = async () => {
        setLoading(true);
        try {
            const response = await fetch(`/api/audit/exports?companyId=${companyId}`, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (response.ok) {
                const data = await response.json();
                setHistory(data);
            }
        } catch (err) {
            console.error('Error fetching history:', err);
        } finally {
            setLoading(false);
        }
    };

    const handleDriverToggle = (driverId: number) => {
        setSelectedDrivers(prev =>
            prev.includes(driverId)
                ? prev.filter(id => id !== driverId)
                : [...prev, driverId]
        );
        setSelectAll(false);
    };

    const handleSelectAll = (checked: boolean) => {
        setSelectAll(checked);
        if (checked) {
            setSelectedDrivers([]);
        }
    };

    const handleGenerate = async () => {
        setError('');
        setSuccess('');
        setGenerating(true);

        try {
            const response = await fetch('/api/audit/export', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    company_id: companyId,
                    export_type: exportType,
                    date_from: dateFrom,
                    date_to: dateTo,
                    driver_ids: selectAll ? null : selectedDrivers
                })
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || 'PDF生成に失敗しました');
            }

            const data = await response.json();
            setSuccess(`PDF生成を開始しました（ID: ${data.id}）`);
            fetchHistory();
        } catch (err: any) {
            setError(err.message);
        } finally {
            setGenerating(false);
        }
    };

    const handleDownload = async (exportId: number) => {
        try {
            window.open(`/api/audit/exports/${exportId}/download`, '_blank');
        } catch (err) {
            setError('ダウンロードに失敗しました');
        }
    };

    const getExportTypeLabel = (type: string) => {
        switch (type) {
            case 'tenko': return '点呼記録簿';
            case 'inspection': return '日常点検記録簿';
            case 'daily_report': return '運転日報';
            case 'all': return '3点セット';
            case 'driver_registry_list': return '運転者台帳一覧';
            case 'compliance_summary': return 'コンプライアンスサマリー';
            default: return type;
        }
    };

    const getStatusChip = (status: string) => {
        switch (status) {
            case 'completed':
                return <Chip icon={<CheckIcon />} label="完了" color="success" size="small" />;
            case 'failed':
                return <Chip icon={<ErrorIcon />} label="失敗" color="error" size="small" />;
            case 'processing':
                return <Chip icon={<PendingIcon />} label="生成中" color="warning" size="small" />;
            default:
                return <Chip label={status} size="small" />;
        }
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Typography variant="h4" component="h1" gutterBottom>
                    監査用帳票出力
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                    運輸局監査に必要な帳票をPDF形式で出力します
                </Typography>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

                {/* 出力設定 */}
                <Card sx={{ mb: 3 }}>
                    <CardContent>
                        <Typography variant="h6" gutterBottom>
                            出力設定
                        </Typography>
                        <Grid container spacing={3}>
                            {/* 出力種別 */}
                            <Grid size={{ xs: 12, sm: 6, md: 4 }}>
                                <FormControl fullWidth>
                                    <InputLabel>出力種別</InputLabel>
                                    <Select
                                        value={exportType}
                                        label="出力種別"
                                        onChange={(e) => setExportType(e.target.value)}
                                    >
                                        <MenuItem value="all">3点セット（推奨）</MenuItem>
                                        <MenuItem value="tenko">点呼記録簿のみ</MenuItem>
                                        <MenuItem value="inspection">日常点検記録簿のみ</MenuItem>
                                        <MenuItem value="daily_report">運転日報のみ</MenuItem>
                                        <MenuItem value="driver_registry_list">運転者台帳一覧</MenuItem>
                                        <MenuItem value="compliance_summary">コンプライアンスサマリー</MenuItem>
                                    </Select>
                                </FormControl>
                            </Grid>

                            {/* 期間指定 */}
                            <Grid size={{ xs: 12, sm: 6, md: 4 }}>
                                <TextField
                                    label="開始日"
                                    type="date"
                                    fullWidth
                                    value={dateFrom}
                                    onChange={(e) => setDateFrom(e.target.value)}
                                    InputLabelProps={{ shrink: true }}
                                />
                            </Grid>
                            <Grid size={{ xs: 12, sm: 6, md: 4 }}>
                                <TextField
                                    label="終了日"
                                    type="date"
                                    fullWidth
                                    value={dateTo}
                                    onChange={(e) => setDateTo(e.target.value)}
                                    InputLabelProps={{ shrink: true }}
                                />
                            </Grid>

                            {/* ドライバー選択 */}
                            <Grid size={12}>
                                <Typography variant="subtitle2" gutterBottom>
                                    対象ドライバー
                                </Typography>
                                <Paper variant="outlined" sx={{ p: 2 }}>
                                    <FormGroup>
                                        <FormControlLabel
                                            control={
                                                <Checkbox
                                                    checked={selectAll}
                                                    onChange={(e) => handleSelectAll(e.target.checked)}
                                                />
                                            }
                                            label="全ドライバー"
                                        />
                                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, ml: 3, mt: 1 }}>
                                            {drivers.map(driver => (
                                                <Chip
                                                    key={driver.id}
                                                    label={driver.name}
                                                    variant={selectAll || selectedDrivers.includes(driver.id) ? 'filled' : 'outlined'}
                                                    color={selectAll || selectedDrivers.includes(driver.id) ? 'primary' : 'default'}
                                                    onClick={() => handleDriverToggle(driver.id)}
                                                    disabled={selectAll}
                                                />
                                            ))}
                                        </Box>
                                    </FormGroup>
                                </Paper>
                            </Grid>

                            {/* 生成ボタン */}
                            <Grid size={12}>
                                <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2 }}>
                                    <Button
                                        variant="contained"
                                        size="large"
                                        startIcon={generating ? <CircularProgress size={20} /> : <PdfIcon />}
                                        onClick={handleGenerate}
                                        disabled={generating || (!selectAll && selectedDrivers.length === 0)}
                                    >
                                        PDF生成
                                    </Button>
                                </Box>
                            </Grid>
                        </Grid>

                        {generating && <LinearProgress sx={{ mt: 2 }} />}
                    </CardContent>
                </Card>

                {/* 出力種別説明 */}
                <Card sx={{ mb: 3 }}>
                    <CardContent>
                        <Typography variant="h6" gutterBottom>
                            帳票種別説明
                        </Typography>
                        <Grid container spacing={2}>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2, backgroundColor: 'primary.50' }}>
                                    <Typography variant="subtitle1" fontWeight="bold" color="primary">
                                        3点セット（推奨）
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        監査で必要な3種類の帳票（点呼記録簿、日常点検記録簿、運転日報）を
                                        ドライバー別・日付順にまとめたPDFファイルです。
                                    </Typography>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="subtitle1" fontWeight="bold">
                                        点呼記録簿
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        乗務前・乗務後の点呼実施記録。アルコールチェック結果、
                                        健康状態、疲労度などを記録した法定帳票です。
                                    </Typography>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="subtitle1" fontWeight="bold">
                                        日常点検記録簿
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        車両の日常点検実施記録。法定15項目の点検結果と
                                        不具合への対応状況を記録した帳票です。
                                    </Typography>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="subtitle1" fontWeight="bold">
                                        運転日報
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        ドライバーの運行記録。出発・到着時刻、走行距離、
                                        休憩時間などの運行実績を記録した帳票です。
                                    </Typography>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="subtitle1" fontWeight="bold">
                                        運転者台帳一覧
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        全運転者の基本情報、免許情報を一覧形式で出力。
                                        法定の運転者台帳フォーマットに準拠しています。
                                    </Typography>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 6 }}>
                                <Paper sx={{ p: 2, backgroundColor: 'info.50' }}>
                                    <Typography variant="subtitle1" fontWeight="bold" color="info.main">
                                        コンプライアンスサマリー
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        点呼実施率、点検合格率、期限切れアラート、事故・違反件数など
                                        コンプライアンス状況をまとめたレポートです。
                                    </Typography>
                                </Paper>
                            </Grid>
                        </Grid>
                    </CardContent>
                </Card>

                {/* 出力履歴 */}
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                    <Typography variant="h6">
                        出力履歴
                    </Typography>
                    <Button
                        startIcon={<RefreshIcon />}
                        onClick={fetchHistory}
                        disabled={loading}
                    >
                        更新
                    </Button>
                </Box>

                {loading ? (
                    <Box display="flex" justifyContent="center" py={4}>
                        <CircularProgress />
                    </Box>
                ) : (
                    <TableContainer component={Paper}>
                        <Table>
                            <TableHead>
                                <TableRow>
                                    <TableCell>日時</TableCell>
                                    <TableCell>種別</TableCell>
                                    <TableCell>期間</TableCell>
                                    <TableCell>ステータス</TableCell>
                                    <TableCell>実行者</TableCell>
                                    <TableCell>ダウンロード</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {history.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={6} align="center">
                                            出力履歴がありません
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    history.map((record) => (
                                        <TableRow key={record.id} hover>
                                            <TableCell>
                                                {new Date(record.created_at).toLocaleString('ja-JP')}
                                            </TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={getExportTypeLabel(record.export_type)}
                                                    size="small"
                                                    color={record.export_type === 'all' ? 'primary' : 'default'}
                                                />
                                            </TableCell>
                                            <TableCell>
                                                {new Date(record.date_from).toLocaleDateString('ja-JP')}
                                                {' 〜 '}
                                                {new Date(record.date_to).toLocaleDateString('ja-JP')}
                                            </TableCell>
                                            <TableCell>{getStatusChip(record.status)}</TableCell>
                                            <TableCell>{record.generated_by_name}</TableCell>
                                            <TableCell>
                                                {record.status === 'completed' && record.pdf_url && (
                                                    <Button
                                                        size="small"
                                                        startIcon={<DownloadIcon />}
                                                        onClick={() => handleDownload(record.id)}
                                                    >
                                                        ダウンロード
                                                    </Button>
                                                )}
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
