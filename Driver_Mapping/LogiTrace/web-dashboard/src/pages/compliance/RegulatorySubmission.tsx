import { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Paper,
    Card,
    CardContent,
    Button,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Checkbox,
    FormControlLabel,
    Alert,
    CircularProgress,
    Divider,
    List,
    ListItem,
    ListItemIcon,
    ListItemText,
    Chip,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
} from '@mui/material';
import Grid from '@mui/material/Grid';
import {
    Description as DocumentIcon,
    CheckCircle as CheckIcon,
    Warning as WarningIcon,
    Error as ErrorIcon,
    Download as DownloadIcon,
    Folder as FolderIcon,
    Assignment as AssignmentIcon,
    LocalShipping as TruckIcon,
    HealthAndSafety as HealthIcon,
    School as TrainingIcon,
    Gavel as LicenseIcon,
} from '@mui/icons-material';

interface Driver {
    id: number;
    name: string;
    employee_number: string;
}

interface ComplianceCheck {
    category: string;
    label: string;
    status: 'ok' | 'warning' | 'error';
    count: number;
    message: string;
}

interface ExportHistory {
    id: number;
    export_type: string;
    date_from: string;
    date_to: string;
    status: string;
    pdf_url: string;
    created_at: string;
}

const RegulatorySubmission = () => {
    const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
    const [selectedMonth, setSelectedMonth] = useState(new Date().getMonth() + 1);
    const [periodType, setPeriodType] = useState<'monthly' | 'quarterly' | 'yearly'>('monthly');
    const [selectedDrivers, setSelectedDrivers] = useState<number[]>([]);
    const [selectAllDrivers, setSelectAllDrivers] = useState(true);
    const [, setDrivers] = useState<Driver[]>([]);
    const [complianceChecks, setComplianceChecks] = useState<ComplianceCheck[]>([]);
    const [exportHistory, setExportHistory] = useState<ExportHistory[]>([]);
    const [loading, setLoading] = useState(false);
    const [generating, setGenerating] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [successMessage, setSuccessMessage] = useState<string | null>(null);
    const [dataCounts, setDataCounts] = useState({
        workRecords: 0,
        tenkoRecords: 0,
        inspectionRecords: 0,
    });

    const currentYear = new Date().getFullYear();
    const years = Array.from({ length: 5 }, (_, i) => currentYear - i);
    const months = Array.from({ length: 12 }, (_, i) => i + 1);
    const quarters = [
        { value: 1, label: '第1四半期 (1-3月)' },
        { value: 2, label: '第2四半期 (4-6月)' },
        { value: 3, label: '第3四半期 (7-9月)' },
        { value: 4, label: '第4四半期 (10-12月)' },
    ];

    // 期間の開始日・終了日を計算
    const getDateRange = () => {
        let dateFrom: string;
        let dateTo: string;

        if (periodType === 'monthly') {
            dateFrom = `${selectedYear}-${String(selectedMonth).padStart(2, '0')}-01`;
            const lastDay = new Date(selectedYear, selectedMonth, 0).getDate();
            dateTo = `${selectedYear}-${String(selectedMonth).padStart(2, '0')}-${lastDay}`;
        } else if (periodType === 'quarterly') {
            const quarterStartMonth = (selectedMonth - 1) * 3 + 1;
            const quarterEndMonth = quarterStartMonth + 2;
            dateFrom = `${selectedYear}-${String(quarterStartMonth).padStart(2, '0')}-01`;
            const lastDay = new Date(selectedYear, quarterEndMonth, 0).getDate();
            dateTo = `${selectedYear}-${String(quarterEndMonth).padStart(2, '0')}-${lastDay}`;
        } else {
            dateFrom = `${selectedYear}-01-01`;
            dateTo = `${selectedYear}-12-31`;
        }

        return { dateFrom, dateTo };
    };

    // ドライバー一覧を取得
    useEffect(() => {
        const fetchDrivers = async () => {
            try {
                const token = localStorage.getItem('token');
                const response = await fetch('/api/drivers', {
                    headers: { 'Authorization': `Bearer ${token}` }
                });
                if (response.ok) {
                    const data = await response.json();
                    setDrivers(data);
                    setSelectedDrivers(data.map((d: Driver) => d.id));
                }
            } catch (err) {
                console.error('Failed to fetch drivers:', err);
            }
        };
        fetchDrivers();
    }, []);

    // コンプライアンスチェックを実行
    const runComplianceCheck = async () => {
        setLoading(true);
        try {
            const token = localStorage.getItem('token');
            const { dateFrom, dateTo } = getDateRange();

            // コンプライアンスサマリーを取得
            const response = await fetch(
                `/api/compliance/summary?dateFrom=${dateFrom}&dateTo=${dateTo}`,
                { headers: { 'Authorization': `Bearer ${token}` } }
            );

            if (!response.ok) throw new Error('コンプライアンスチェックに失敗しました');
            const data = await response.json();

            // チェック結果を整理
            const checks: ComplianceCheck[] = [
                {
                    category: 'license',
                    label: '免許期限',
                    status: data.licenseExpired > 0 ? 'error' : data.licenseExpiring > 0 ? 'warning' : 'ok',
                    count: data.licenseExpired + data.licenseExpiring,
                    message: data.licenseExpired > 0
                        ? `${data.licenseExpired}名の免許が期限切れです`
                        : data.licenseExpiring > 0
                        ? `${data.licenseExpiring}名の免許が30日以内に期限切れ`
                        : '全員問題なし'
                },
                {
                    category: 'health',
                    label: '健康診断',
                    status: data.healthCheckupDue > 0 ? 'warning' : 'ok',
                    count: data.healthCheckupDue,
                    message: data.healthCheckupDue > 0
                        ? `${data.healthCheckupDue}名が未受診`
                        : '全員受診済み'
                },
                {
                    category: 'aptitude',
                    label: '適性診断',
                    status: data.aptitudeTestDue > 0 ? 'warning' : 'ok',
                    count: data.aptitudeTestDue,
                    message: data.aptitudeTestDue > 0
                        ? `${data.aptitudeTestDue}名が要受診`
                        : '全員受診済み'
                },
                {
                    category: 'tenko',
                    label: '点呼実施',
                    status: data.tenkoCompletionRate < 100 ? 'warning' : 'ok',
                    count: 100 - data.tenkoCompletionRate,
                    message: `実施率 ${data.tenkoCompletionRate}%`
                },
                {
                    category: 'inspection',
                    label: '日常点検',
                    status: data.inspectionCompletionRate < 100 ? 'warning' : 'ok',
                    count: 100 - data.inspectionCompletionRate,
                    message: `合格率 ${data.inspectionCompletionRate}%`
                },
            ];

            setComplianceChecks(checks);

            // データ件数も取得
            const summaryResponse = await fetch(
                `/api/audit/summary?companyId=${localStorage.getItem('companyId')}&dateFrom=${dateFrom}&dateTo=${dateTo}`,
                { headers: { 'Authorization': `Bearer ${token}` } }
            );
            if (summaryResponse.ok) {
                const summaryData = await summaryResponse.json();
                setDataCounts({
                    workRecords: summaryData.work_records_count || 0,
                    tenkoRecords: summaryData.tenko_records_count || 0,
                    inspectionRecords: summaryData.inspection_records_count || 0,
                });
            }
        } catch (err) {
            setError(err instanceof Error ? err.message : 'エラーが発生しました');
        } finally {
            setLoading(false);
        }
    };

    // 帳票一括生成
    const generateBulkExport = async (exportType: string) => {
        setGenerating(true);
        setError(null);
        try {
            const token = localStorage.getItem('token');
            const companyId = localStorage.getItem('companyId');
            const { dateFrom, dateTo } = getDateRange();

            const response = await fetch('/api/audit/exports', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    company_id: companyId,
                    export_type: exportType,
                    date_from: dateFrom,
                    date_to: dateTo,
                    driver_ids: selectAllDrivers ? null : selectedDrivers,
                })
            });

            if (!response.ok) throw new Error('帳票生成に失敗しました');
            const result = await response.json();

            setSuccessMessage(`帳票生成を開始しました（ID: ${result.export_id}）`);

            // 出力履歴を更新
            fetchExportHistory();
        } catch (err) {
            setError(err instanceof Error ? err.message : '帳票生成に失敗しました');
        } finally {
            setGenerating(false);
        }
    };

    // 出力履歴を取得
    const fetchExportHistory = async () => {
        try {
            const token = localStorage.getItem('token');
            const companyId = localStorage.getItem('companyId');
            const response = await fetch(
                `/api/audit/exports?companyId=${companyId}&limit=10`,
                { headers: { 'Authorization': `Bearer ${token}` } }
            );
            if (response.ok) {
                const data = await response.json();
                setExportHistory(data);
            }
        } catch (err) {
            console.error('Failed to fetch export history:', err);
        }
    };

    useEffect(() => {
        fetchExportHistory();
    }, []);

    // PDFダウンロード
    const downloadPDF = async (exportId: number) => {
        try {
            const token = localStorage.getItem('token');
            const response = await fetch(`/api/audit/exports/${exportId}/download`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });

            if (!response.ok) throw new Error('ダウンロードに失敗しました');

            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `監査帳票_${exportId}.pdf`;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            a.remove();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'ダウンロードに失敗しました');
        }
    };

    const getStatusIcon = (status: 'ok' | 'warning' | 'error') => {
        switch (status) {
            case 'ok': return <CheckIcon color="success" />;
            case 'warning': return <WarningIcon color="warning" />;
            case 'error': return <ErrorIcon color="error" />;
        }
    };

    const getCategoryIcon = (category: string) => {
        switch (category) {
            case 'license': return <LicenseIcon />;
            case 'health': return <HealthIcon />;
            case 'aptitude': return <TrainingIcon />;
            case 'tenko': return <AssignmentIcon />;
            case 'inspection': return <TruckIcon />;
            default: return <DocumentIcon />;
        }
    };

    const getExportTypeLabel = (type: string) => {
        const labels: Record<string, string> = {
            'all': '3点セット（全帳票）',
            'tenko': '点呼記録簿',
            'inspection': '日常点検記録簿',
            'daily_report': '運転日報',
            'driver_registry_list': '運転者台帳一覧',
            'compliance_summary': 'コンプライアンスサマリー',
        };
        return labels[type] || type;
    };

    const { dateFrom, dateTo } = getDateRange();

    return (
        <Box sx={{ p: 3 }}>
            <Typography variant="h5" gutterBottom fontWeight="bold">
                国土交通省提出用 帳票一括出力
            </Typography>
            <Typography color="textSecondary" sx={{ mb: 3 }}>
                監査や定期報告に必要な帳票を一括で生成・ダウンロードできます
            </Typography>

            {error && (
                <Alert severity="error" onClose={() => setError(null)} sx={{ mb: 2 }}>
                    {error}
                </Alert>
            )}
            {successMessage && (
                <Alert severity="success" onClose={() => setSuccessMessage(null)} sx={{ mb: 2 }}>
                    {successMessage}
                </Alert>
            )}

            <Grid container spacing={3}>
                {/* 期間選択 */}
                <Grid size={{ xs: 12, md: 4 }}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                1. 期間を選択
                            </Typography>

                            <FormControl fullWidth sx={{ mb: 2 }}>
                                <InputLabel>期間タイプ</InputLabel>
                                <Select
                                    value={periodType}
                                    label="期間タイプ"
                                    onChange={(e) => setPeriodType(e.target.value as any)}
                                >
                                    <MenuItem value="monthly">月次</MenuItem>
                                    <MenuItem value="quarterly">四半期</MenuItem>
                                    <MenuItem value="yearly">年次</MenuItem>
                                </Select>
                            </FormControl>

                            <FormControl fullWidth sx={{ mb: 2 }}>
                                <InputLabel>年</InputLabel>
                                <Select
                                    value={selectedYear}
                                    label="年"
                                    onChange={(e) => setSelectedYear(e.target.value as number)}
                                >
                                    {years.map((year) => (
                                        <MenuItem key={year} value={year}>{year}年</MenuItem>
                                    ))}
                                </Select>
                            </FormControl>

                            {periodType === 'monthly' && (
                                <FormControl fullWidth sx={{ mb: 2 }}>
                                    <InputLabel>月</InputLabel>
                                    <Select
                                        value={selectedMonth}
                                        label="月"
                                        onChange={(e) => setSelectedMonth(e.target.value as number)}
                                    >
                                        {months.map((month) => (
                                            <MenuItem key={month} value={month}>{month}月</MenuItem>
                                        ))}
                                    </Select>
                                </FormControl>
                            )}

                            {periodType === 'quarterly' && (
                                <FormControl fullWidth sx={{ mb: 2 }}>
                                    <InputLabel>四半期</InputLabel>
                                    <Select
                                        value={selectedMonth}
                                        label="四半期"
                                        onChange={(e) => setSelectedMonth(e.target.value as number)}
                                    >
                                        {quarters.map((q) => (
                                            <MenuItem key={q.value} value={q.value}>{q.label}</MenuItem>
                                        ))}
                                    </Select>
                                </FormControl>
                            )}

                            <Paper sx={{ p: 2, bgcolor: 'grey.100' }}>
                                <Typography variant="body2" color="textSecondary">
                                    対象期間:
                                </Typography>
                                <Typography variant="body1" fontWeight="medium">
                                    {dateFrom} 〜 {dateTo}
                                </Typography>
                            </Paper>

                            <Divider sx={{ my: 2 }} />

                            <FormControlLabel
                                control={
                                    <Checkbox
                                        checked={selectAllDrivers}
                                        onChange={(e) => setSelectAllDrivers(e.target.checked)}
                                    />
                                }
                                label="全ドライバーを対象"
                            />

                            <Button
                                variant="contained"
                                fullWidth
                                onClick={runComplianceCheck}
                                disabled={loading}
                                sx={{ mt: 2 }}
                            >
                                {loading ? <CircularProgress size={24} /> : 'コンプライアンスチェック実行'}
                            </Button>
                        </CardContent>
                    </Card>
                </Grid>

                {/* コンプライアンスチェック結果 */}
                <Grid size={{ xs: 12, md: 4 }}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                2. コンプライアンス確認
                            </Typography>

                            {complianceChecks.length === 0 ? (
                                <Typography color="textSecondary" sx={{ py: 4, textAlign: 'center' }}>
                                    コンプライアンスチェックを実行してください
                                </Typography>
                            ) : (
                                <List dense>
                                    {complianceChecks.map((check) => (
                                        <ListItem key={check.category}>
                                            <ListItemIcon>
                                                {getCategoryIcon(check.category)}
                                            </ListItemIcon>
                                            <ListItemText
                                                primary={check.label}
                                                secondary={check.message}
                                            />
                                            {getStatusIcon(check.status)}
                                        </ListItem>
                                    ))}
                                </List>
                            )}

                            <Divider sx={{ my: 2 }} />

                            <Typography variant="subtitle2" gutterBottom>
                                対象データ件数
                            </Typography>
                            <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                                <Chip label={`日報: ${dataCounts.workRecords}件`} size="small" />
                                <Chip label={`点呼: ${dataCounts.tenkoRecords}件`} size="small" />
                                <Chip label={`点検: ${dataCounts.inspectionRecords}件`} size="small" />
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>

                {/* 帳票生成 */}
                <Grid size={{ xs: 12, md: 4 }}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                3. 帳票を生成
                            </Typography>

                            <Button
                                variant="contained"
                                color="primary"
                                fullWidth
                                size="large"
                                startIcon={<FolderIcon />}
                                onClick={() => generateBulkExport('all')}
                                disabled={generating}
                                sx={{ mb: 2 }}
                            >
                                {generating ? <CircularProgress size={24} /> : '3点セット一括生成'}
                            </Button>

                            <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                                含まれる帳票: 点呼記録簿、日常点検記録簿、運転日報
                            </Typography>

                            <Divider sx={{ my: 2 }} />

                            <Typography variant="subtitle2" gutterBottom>
                                個別帳票
                            </Typography>

                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                                <Button
                                    variant="outlined"
                                    size="small"
                                    onClick={() => generateBulkExport('tenko')}
                                    disabled={generating}
                                >
                                    点呼記録簿
                                </Button>
                                <Button
                                    variant="outlined"
                                    size="small"
                                    onClick={() => generateBulkExport('inspection')}
                                    disabled={generating}
                                >
                                    日常点検記録簿
                                </Button>
                                <Button
                                    variant="outlined"
                                    size="small"
                                    onClick={() => generateBulkExport('daily_report')}
                                    disabled={generating}
                                >
                                    運転日報
                                </Button>
                                <Button
                                    variant="outlined"
                                    size="small"
                                    onClick={() => generateBulkExport('driver_registry_list')}
                                    disabled={generating}
                                >
                                    運転者台帳一覧
                                </Button>
                                <Button
                                    variant="outlined"
                                    size="small"
                                    onClick={() => generateBulkExport('compliance_summary')}
                                    disabled={generating}
                                >
                                    コンプライアンスサマリー
                                </Button>
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>

                {/* 出力履歴 */}
                <Grid size={{ xs: 12 }}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                出力履歴
                            </Typography>

                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>種類</TableCell>
                                            <TableCell>期間</TableCell>
                                            <TableCell>状態</TableCell>
                                            <TableCell>生成日時</TableCell>
                                            <TableCell align="center">操作</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {exportHistory.length === 0 ? (
                                            <TableRow>
                                                <TableCell colSpan={5} align="center">
                                                    出力履歴がありません
                                                </TableCell>
                                            </TableRow>
                                        ) : (
                                            exportHistory.map((item) => (
                                                <TableRow key={item.id}>
                                                    <TableCell>{getExportTypeLabel(item.export_type)}</TableCell>
                                                    <TableCell>{item.date_from} 〜 {item.date_to}</TableCell>
                                                    <TableCell>
                                                        <Chip
                                                            label={item.status === 'completed' ? '完了' : item.status === 'generating' ? '生成中' : 'エラー'}
                                                            color={item.status === 'completed' ? 'success' : item.status === 'generating' ? 'warning' : 'error'}
                                                            size="small"
                                                        />
                                                    </TableCell>
                                                    <TableCell>
                                                        {new Date(item.created_at).toLocaleString('ja-JP')}
                                                    </TableCell>
                                                    <TableCell align="center">
                                                        <Button
                                                            size="small"
                                                            startIcon={<DownloadIcon />}
                                                            onClick={() => downloadPDF(item.id)}
                                                            disabled={item.status !== 'completed'}
                                                        >
                                                            ダウンロード
                                                        </Button>
                                                    </TableCell>
                                                </TableRow>
                                            ))
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>
        </Box>
    );
};

export default RegulatorySubmission;
