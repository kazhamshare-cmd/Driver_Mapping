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
    Checkbox,
    Chip,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Alert,
    CircularProgress,
    Card,
    CardContent,
    IconButton,
    Tooltip,
    Collapse,
    FormControlLabel,
    Switch,
} from '@mui/material';
import Grid from '@mui/material/Grid';
import {
    CheckCircle as ApproveIcon,
    ExpandMore as ExpandIcon,
    ExpandLess as CollapseIcon,
    Warning as WarningIcon,
    Info as InfoIcon,
    Draw as SignatureIcon,
} from '@mui/icons-material';
import SignaturePad from '../../components/SignaturePad';

interface PendingRecord {
    id: number;
    work_date: string;
    start_time: string;
    end_time: string;
    distance: number;
    auto_distance: number;
    manual_break_minutes: number;
    auto_break_minutes: number;
    correction_note: string;
    submitted_at: string;
    cargo_weight: number;
    actual_distance: number;
    num_passengers: number;
    revenue: number;
    has_incident: boolean;
    incident_detail: string;
    driver_id: number;
    driver_name: string;
    employee_number: string;
    vehicle_number: string;
}

const WorkRecordApproval = () => {
    const [records, setRecords] = useState<PendingRecord[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedIds, setSelectedIds] = useState<number[]>([]);
    const [expandedId, setExpandedId] = useState<number | null>(null);
    const [rejectDialogOpen, setRejectDialogOpen] = useState(false);
    const [rejectingId, setRejectingId] = useState<number | null>(null);
    const [rejectReason, setRejectReason] = useState('');
    const [error, setError] = useState<string | null>(null);
    const [successMessage, setSuccessMessage] = useState<string | null>(null);

    // 電子署名関連
    const [signatureDialogOpen, setSignatureDialogOpen] = useState(false);
    const [signatureData, setSignatureData] = useState<string | null>(null);
    const [savedSignature, setSavedSignature] = useState<string | null>(null);
    const [useSavedSignature, setUseSavedSignature] = useState(false);
    const [approvingId, setApprovingId] = useState<number | null>(null);
    const [isBulkApprove, setIsBulkApprove] = useState(false);
    const [approvalComment, setApprovalComment] = useState('');

    const fetchPendingRecords = async () => {
        setLoading(true);
        try {
            const token = localStorage.getItem('token');
            const response = await fetch('/api/work-records/pending', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (!response.ok) throw new Error('Failed to fetch');
            const data = await response.json();
            setRecords(data);
        } catch (err) {
            setError('承認待ちデータの取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const fetchSavedSignature = async () => {
        try {
            const token = localStorage.getItem('token');
            const response = await fetch('/api/manager-confirmations/my-signature', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (response.ok) {
                const data = await response.json();
                if (data.signature_data) {
                    setSavedSignature(data.signature_data);
                }
            }
        } catch (err) {
            console.log('No saved signature found');
        }
    };

    useEffect(() => {
        fetchPendingRecords();
        fetchSavedSignature();
    }, []);

    const handleSelectAll = (checked: boolean) => {
        if (checked) {
            setSelectedIds(records.map(r => r.id));
        } else {
            setSelectedIds([]);
        }
    };

    const handleSelect = (id: number) => {
        if (selectedIds.includes(id)) {
            setSelectedIds(selectedIds.filter(i => i !== id));
        } else {
            setSelectedIds([...selectedIds, id]);
        }
    };

    // 署名ダイアログを開く（単体承認）
    const handleApproveClick = (id: number) => {
        setApprovingId(id);
        setIsBulkApprove(false);
        setSignatureData(null);
        setApprovalComment('');
        setUseSavedSignature(false);
        setSignatureDialogOpen(true);
    };

    // 署名ダイアログを開く（一括承認）
    const handleBulkApproveClick = () => {
        if (selectedIds.length === 0) return;
        setApprovingId(null);
        setIsBulkApprove(true);
        setSignatureData(null);
        setApprovalComment('');
        setUseSavedSignature(false);
        setSignatureDialogOpen(true);
    };

    // 署名付き承認を実行
    const handleApproveWithSignature = async () => {
        const finalSignature = useSavedSignature ? savedSignature : signatureData;
        if (!finalSignature) {
            setError('署名が必要です');
            return;
        }

        try {
            const token = localStorage.getItem('token');

            if (isBulkApprove) {
                // 一括承認
                const response = await fetch('/api/manager-confirmations/bulk-approve', {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${token}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        record_ids: selectedIds,
                        comment: approvalComment || '一括承認',
                        signature_data: finalSignature
                    })
                });
                if (!response.ok) throw new Error('Failed to bulk approve');
                const result = await response.json();
                setSuccessMessage(`${result.approved_count}件を電子署名付きで承認しました`);
                setSelectedIds([]);
            } else if (approvingId) {
                // 単体承認
                const response = await fetch(`/api/manager-confirmations/${approvingId}/approve`, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${token}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        comment: approvalComment || '承認済み',
                        signature_data: finalSignature
                    })
                });
                if (!response.ok) throw new Error('Failed to approve');
                setSuccessMessage('電子署名付きで承認しました');
            }

            setSignatureDialogOpen(false);
            fetchPendingRecords();
            // 新しい署名を保存
            if (!useSavedSignature && signatureData) {
                setSavedSignature(signatureData);
            }
        } catch (err) {
            setError('承認に失敗しました');
        }
    };

    const handleRejectClick = (id: number) => {
        setRejectingId(id);
        setRejectReason('');
        setRejectDialogOpen(true);
    };

    const handleRejectConfirm = async () => {
        if (!rejectingId || !rejectReason) return;
        try {
            const token = localStorage.getItem('token');
            const response = await fetch(`/api/work-records/${rejectingId}/reject`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ reason: rejectReason })
            });
            if (!response.ok) throw new Error('Failed to reject');
            setSuccessMessage('差戻ししました');
            setRejectDialogOpen(false);
            setRejectingId(null);
            setRejectReason('');
            fetchPendingRecords();
        } catch (err) {
            setError('差戻しに失敗しました');
        }
    };

    const formatTime = (datetime: string) => {
        if (!datetime) return '-';
        return new Date(datetime).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
    };

    const formatDate = (datetime: string) => {
        if (!datetime) return '-';
        return new Date(datetime).toLocaleDateString('ja-JP');
    };

    const hasCorrection = (record: PendingRecord) => {
        return record.distance !== record.auto_distance ||
               record.manual_break_minutes !== record.auto_break_minutes;
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
            <Typography variant="h5" gutterBottom fontWeight="bold">
                運行記録 承認待ち
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

            {/* サマリーカード */}
            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Typography color="textSecondary" gutterBottom>
                                承認待ち件数
                            </Typography>
                            <Typography variant="h4" color="warning.main">
                                {records.length}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Typography color="textSecondary" gutterBottom>
                                修正あり
                            </Typography>
                            <Typography variant="h4" color="info.main">
                                {records.filter(hasCorrection).length}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card>
                        <CardContent>
                            <Typography color="textSecondary" gutterBottom>
                                選択中
                            </Typography>
                            <Typography variant="h4" color="primary.main">
                                {selectedIds.length}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                    <Card sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%' }}>
                        <Button
                            variant="contained"
                            color="success"
                            startIcon={<SignatureIcon />}
                            onClick={handleBulkApproveClick}
                            disabled={selectedIds.length === 0}
                            size="large"
                        >
                            署名承認 ({selectedIds.length})
                        </Button>
                    </Card>
                </Grid>
            </Grid>

            {records.length === 0 ? (
                <Paper sx={{ p: 4, textAlign: 'center' }}>
                    <Typography color="textSecondary">
                        承認待ちの運行記録はありません
                    </Typography>
                </Paper>
            ) : (
                <TableContainer component={Paper}>
                    <Table>
                        <TableHead>
                            <TableRow sx={{ bgcolor: 'grey.100' }}>
                                <TableCell padding="checkbox">
                                    <Checkbox
                                        checked={selectedIds.length === records.length}
                                        indeterminate={selectedIds.length > 0 && selectedIds.length < records.length}
                                        onChange={(e) => handleSelectAll(e.target.checked)}
                                    />
                                </TableCell>
                                <TableCell>日付</TableCell>
                                <TableCell>ドライバー</TableCell>
                                <TableCell>車両</TableCell>
                                <TableCell>時間</TableCell>
                                <TableCell align="right">走行距離</TableCell>
                                <TableCell align="right">休憩</TableCell>
                                <TableCell>状態</TableCell>
                                <TableCell align="center">操作</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {records.map((record) => (
                                <>
                                    <TableRow
                                        key={record.id}
                                        hover
                                        selected={selectedIds.includes(record.id)}
                                        sx={{ '& > *': { borderBottom: expandedId === record.id ? 'none' : undefined } }}
                                    >
                                        <TableCell padding="checkbox">
                                            <Checkbox
                                                checked={selectedIds.includes(record.id)}
                                                onChange={() => handleSelect(record.id)}
                                            />
                                        </TableCell>
                                        <TableCell>{formatDate(record.work_date)}</TableCell>
                                        <TableCell>
                                            <Box>
                                                <Typography variant="body2" fontWeight="medium">
                                                    {record.driver_name}
                                                </Typography>
                                                <Typography variant="caption" color="textSecondary">
                                                    {record.employee_number}
                                                </Typography>
                                            </Box>
                                        </TableCell>
                                        <TableCell>{record.vehicle_number || '-'}</TableCell>
                                        <TableCell>
                                            {formatTime(record.start_time)} - {formatTime(record.end_time)}
                                        </TableCell>
                                        <TableCell align="right">
                                            <Box>
                                                <Typography variant="body2">
                                                    {record.distance?.toFixed(1)} km
                                                </Typography>
                                                {hasCorrection(record) && record.auto_distance && (
                                                    <Typography variant="caption" color="textSecondary">
                                                        (自動: {record.auto_distance?.toFixed(1)} km)
                                                    </Typography>
                                                )}
                                            </Box>
                                        </TableCell>
                                        <TableCell align="right">
                                            {record.manual_break_minutes || record.auto_break_minutes || 0} 分
                                        </TableCell>
                                        <TableCell>
                                            {hasCorrection(record) && (
                                                <Tooltip title="ドライバーによる修正あり">
                                                    <Chip
                                                        icon={<InfoIcon />}
                                                        label="修正あり"
                                                        size="small"
                                                        color="info"
                                                    />
                                                </Tooltip>
                                            )}
                                            {record.has_incident && (
                                                <Tooltip title={record.incident_detail}>
                                                    <Chip
                                                        icon={<WarningIcon />}
                                                        label="事故報告"
                                                        size="small"
                                                        color="error"
                                                        sx={{ ml: 0.5 }}
                                                    />
                                                </Tooltip>
                                            )}
                                        </TableCell>
                                        <TableCell align="center">
                                            <Box display="flex" gap={1} justifyContent="center">
                                                <IconButton
                                                    size="small"
                                                    onClick={() => setExpandedId(expandedId === record.id ? null : record.id)}
                                                >
                                                    {expandedId === record.id ? <CollapseIcon /> : <ExpandIcon />}
                                                </IconButton>
                                                <Button
                                                    size="small"
                                                    variant="contained"
                                                    color="success"
                                                    startIcon={<SignatureIcon />}
                                                    onClick={() => handleApproveClick(record.id)}
                                                >
                                                    署名
                                                </Button>
                                                <Button
                                                    size="small"
                                                    variant="outlined"
                                                    color="error"
                                                    onClick={() => handleRejectClick(record.id)}
                                                >
                                                    差戻
                                                </Button>
                                            </Box>
                                        </TableCell>
                                    </TableRow>
                                    <TableRow key={`${record.id}-detail`}>
                                        <TableCell colSpan={9} sx={{ py: 0 }}>
                                            <Collapse in={expandedId === record.id}>
                                                <Box sx={{ p: 2, bgcolor: 'grey.50' }}>
                                                    <Grid container spacing={2}>
                                                        <Grid size={{ xs: 12, md: 6 }}>
                                                            <Typography variant="subtitle2" gutterBottom>
                                                                運行詳細
                                                            </Typography>
                                                            <Typography variant="body2">
                                                                積載量: {record.cargo_weight || 0} t
                                                            </Typography>
                                                            <Typography variant="body2">
                                                                実車距離: {record.actual_distance || 0} km
                                                            </Typography>
                                                            <Typography variant="body2">
                                                                乗客数: {record.num_passengers || 0} 名
                                                            </Typography>
                                                            <Typography variant="body2">
                                                                営業収入: ¥{(record.revenue || 0).toLocaleString()}
                                                            </Typography>
                                                        </Grid>
                                                        <Grid size={{ xs: 12, md: 6 }}>
                                                            {record.correction_note && (
                                                                <>
                                                                    <Typography variant="subtitle2" gutterBottom>
                                                                        修正理由
                                                                    </Typography>
                                                                    <Typography variant="body2" sx={{ bgcolor: 'warning.light', p: 1, borderRadius: 1 }}>
                                                                        {record.correction_note}
                                                                    </Typography>
                                                                </>
                                                            )}
                                                            {record.has_incident && (
                                                                <>
                                                                    <Typography variant="subtitle2" gutterBottom color="error">
                                                                        事故・インシデント報告
                                                                    </Typography>
                                                                    <Typography variant="body2" sx={{ bgcolor: 'error.light', p: 1, borderRadius: 1 }}>
                                                                        {record.incident_detail}
                                                                    </Typography>
                                                                </>
                                                            )}
                                                        </Grid>
                                                    </Grid>
                                                </Box>
                                            </Collapse>
                                        </TableCell>
                                    </TableRow>
                                </>
                            ))}
                        </TableBody>
                    </Table>
                </TableContainer>
            )}

            {/* 差戻しダイアログ */}
            <Dialog open={rejectDialogOpen} onClose={() => setRejectDialogOpen(false)} maxWidth="sm" fullWidth>
                <DialogTitle>運行記録の差戻し</DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                        差戻し理由を入力してください。ドライバーに通知されます。
                    </Typography>
                    <TextField
                        autoFocus
                        fullWidth
                        multiline
                        rows={3}
                        label="差戻し理由"
                        value={rejectReason}
                        onChange={(e) => setRejectReason(e.target.value)}
                        placeholder="例: 走行距離に誤りがあるため確認してください"
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setRejectDialogOpen(false)}>キャンセル</Button>
                    <Button
                        onClick={handleRejectConfirm}
                        color="error"
                        variant="contained"
                        disabled={!rejectReason}
                    >
                        差戻し実行
                    </Button>
                </DialogActions>
            </Dialog>

            {/* 電子署名ダイアログ */}
            <Dialog
                open={signatureDialogOpen}
                onClose={() => setSignatureDialogOpen(false)}
                maxWidth="md"
                fullWidth
            >
                <DialogTitle>
                    {isBulkApprove
                        ? `電子署名による一括承認（${selectedIds.length}件）`
                        : '電子署名による承認'
                    }
                </DialogTitle>
                <DialogContent>
                    <Box sx={{ mb: 2 }}>
                        <Typography variant="body2" color="textSecondary" gutterBottom>
                            運行管理者として電子署名を行い、運行記録を承認します。
                        </Typography>
                        <TextField
                            fullWidth
                            label="承認コメント（任意）"
                            value={approvalComment}
                            onChange={(e) => setApprovalComment(e.target.value)}
                            placeholder="承認に関するコメントがあれば入力"
                            sx={{ mt: 2, mb: 2 }}
                        />
                    </Box>

                    {savedSignature && (
                        <Box sx={{ mb: 2 }}>
                            <FormControlLabel
                                control={
                                    <Switch
                                        checked={useSavedSignature}
                                        onChange={(e) => setUseSavedSignature(e.target.checked)}
                                    />
                                }
                                label="前回の署名を使用"
                            />
                            {useSavedSignature && (
                                <Paper sx={{ p: 2, mt: 1, bgcolor: 'grey.50' }}>
                                    <Typography variant="caption" color="textSecondary" gutterBottom>
                                        保存済みの署名:
                                    </Typography>
                                    <Box sx={{ maxWidth: 300, mt: 1 }}>
                                        <img
                                            src={savedSignature}
                                            alt="保存済み署名"
                                            style={{ width: '100%', border: '1px solid #ddd' }}
                                        />
                                    </Box>
                                </Paper>
                            )}
                        </Box>
                    )}

                    {!useSavedSignature && (
                        <SignaturePad
                            onSignatureChange={setSignatureData}
                            label="運行管理者 電子署名"
                        />
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setSignatureDialogOpen(false)}>
                        キャンセル
                    </Button>
                    <Button
                        onClick={handleApproveWithSignature}
                        color="success"
                        variant="contained"
                        disabled={!useSavedSignature && !signatureData}
                        startIcon={<ApproveIcon />}
                    >
                        {isBulkApprove ? `${selectedIds.length}件を承認` : '承認する'}
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default WorkRecordApproval;
