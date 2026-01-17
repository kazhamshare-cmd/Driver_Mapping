import { useState, useEffect, useCallback } from 'react';
import {
    Alert,
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
    LinearProgress,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
} from '@mui/material';
import {
    CloudUpload as UploadIcon,
    CheckCircle as CheckIcon,
    Error as ErrorIcon,
    Refresh as RefreshIcon,
    Preview as PreviewIcon,
} from '@mui/icons-material';

interface ImportHistory {
    id: number;
    file_name: string;
    file_type: string;
    status: string;
    records_imported: number;
    records_failed: number;
    uploaded_by_name: string;
    created_at: string;
}

interface PreviewData {
    total_records: number;
    sample_records: Array<{
        date: string;
        vehicle_number: string;
        driver_name: string;
        distance: number;
        duration: string;
    }>;
    warnings: string[];
}

export default function TachographImport() {
    const [loading, setLoading] = useState(false);
    const [uploading, setUploading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [history, setHistory] = useState<ImportHistory[]>([]);
    const [fileType, setFileType] = useState('yazaki');
    const [selectedFile, setSelectedFile] = useState<File | null>(null);
    const [previewOpen, setPreviewOpen] = useState(false);
    const [previewData, setPreviewData] = useState<PreviewData | null>(null);
    const [dragActive, setDragActive] = useState(false);

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchHistory();
    }, []);

    const fetchHistory = async () => {
        setLoading(true);
        try {
            const response = await fetch(`/api/tachograph/imports?companyId=${companyId}`, {
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

    const handleDrag = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
        if (e.type === 'dragenter' || e.type === 'dragover') {
            setDragActive(true);
        } else if (e.type === 'dragleave') {
            setDragActive(false);
        }
    }, []);

    const handleDrop = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
        setDragActive(false);
        if (e.dataTransfer.files && e.dataTransfer.files[0]) {
            setSelectedFile(e.dataTransfer.files[0]);
        }
    }, []);

    const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files[0]) {
            setSelectedFile(e.target.files[0]);
        }
    };

    const handlePreview = async () => {
        if (!selectedFile) return;

        setError('');
        setUploading(true);

        try {
            const formData = new FormData();
            formData.append('file', selectedFile);
            formData.append('fileType', fileType);
            formData.append('companyId', companyId.toString());

            const response = await fetch('/api/tachograph/preview', {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${user.token}` },
                body: formData
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || 'プレビューに失敗しました');
            }

            const data = await response.json();
            setPreviewData(data);
            setPreviewOpen(true);
        } catch (err: any) {
            setError(err.message);
        } finally {
            setUploading(false);
        }
    };

    const handleUpload = async () => {
        if (!selectedFile) return;

        setError('');
        setSuccess('');
        setUploading(true);
        setPreviewOpen(false);

        try {
            const formData = new FormData();
            formData.append('file', selectedFile);
            formData.append('fileType', fileType);
            formData.append('companyId', companyId.toString());

            const response = await fetch('/api/tachograph/upload', {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${user.token}` },
                body: formData
            });

            if (!response.ok) {
                const data = await response.json();
                throw new Error(data.error || 'アップロードに失敗しました');
            }

            const data = await response.json();
            setSuccess(`${data.records_imported}件のレコードをインポートしました`);
            setSelectedFile(null);
            fetchHistory();
        } catch (err: any) {
            setError(err.message);
        } finally {
            setUploading(false);
        }
    };

    const getStatusChip = (status: string) => {
        switch (status) {
            case 'completed':
                return <Chip icon={<CheckIcon />} label="完了" color="success" size="small" />;
            case 'failed':
                return <Chip icon={<ErrorIcon />} label="失敗" color="error" size="small" />;
            case 'processing':
                return <Chip label="処理中" color="warning" size="small" />;
            default:
                return <Chip label={status} size="small" />;
        }
    };

    const getFileTypeLabel = (type: string) => {
        switch (type) {
            case 'yazaki': return '矢崎';
            case 'denso': return 'デンソー';
            case 'manual': return '手動入力';
            default: return type;
        }
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Typography variant="h4" component="h1" gutterBottom>
                    デジタコCSVインポート
                </Typography>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
                {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

                {/* アップロードエリア */}
                <Card sx={{ mb: 3 }}>
                    <CardContent>
                        <Grid container spacing={3}>
                            <Grid size={{ xs: 12, sm: 4 }}>
                                <FormControl fullWidth>
                                    <InputLabel>デジタコ種別</InputLabel>
                                    <Select
                                        value={fileType}
                                        label="デジタコ種別"
                                        onChange={(e) => setFileType(e.target.value)}
                                    >
                                        <MenuItem value="yazaki">矢崎（Yazaki）</MenuItem>
                                        <MenuItem value="denso">デンソー（Denso）</MenuItem>
                                        <MenuItem value="manual">アナタコ（手動入力）</MenuItem>
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid size={12}>
                                <Box
                                    onDragEnter={handleDrag}
                                    onDragLeave={handleDrag}
                                    onDragOver={handleDrag}
                                    onDrop={handleDrop}
                                    sx={{
                                        border: '2px dashed',
                                        borderColor: dragActive ? 'primary.main' : 'grey.300',
                                        borderRadius: 2,
                                        p: 4,
                                        textAlign: 'center',
                                        backgroundColor: dragActive ? 'action.hover' : 'background.paper',
                                        cursor: 'pointer',
                                        transition: 'all 0.2s ease'
                                    }}
                                    onClick={() => document.getElementById('file-input')?.click()}
                                >
                                    <input
                                        id="file-input"
                                        type="file"
                                        accept=".csv"
                                        onChange={handleFileChange}
                                        style={{ display: 'none' }}
                                    />
                                    <UploadIcon sx={{ fontSize: 48, color: 'grey.500', mb: 2 }} />
                                    <Typography variant="h6" gutterBottom>
                                        CSVファイルをドラッグ＆ドロップ
                                    </Typography>
                                    <Typography color="text.secondary">
                                        またはクリックしてファイルを選択
                                    </Typography>
                                    {selectedFile && (
                                        <Box sx={{ mt: 2 }}>
                                            <Chip
                                                label={selectedFile.name}
                                                color="primary"
                                                onDelete={() => setSelectedFile(null)}
                                            />
                                        </Box>
                                    )}
                                </Box>
                            </Grid>
                            <Grid size={12}>
                                <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2 }}>
                                    <Button
                                        variant="outlined"
                                        startIcon={<PreviewIcon />}
                                        onClick={handlePreview}
                                        disabled={!selectedFile || uploading}
                                    >
                                        プレビュー
                                    </Button>
                                    <Button
                                        variant="contained"
                                        startIcon={uploading ? <CircularProgress size={20} /> : <UploadIcon />}
                                        onClick={handleUpload}
                                        disabled={!selectedFile || uploading}
                                    >
                                        インポート
                                    </Button>
                                </Box>
                            </Grid>
                        </Grid>

                        {uploading && <LinearProgress sx={{ mt: 2 }} />}
                    </CardContent>
                </Card>

                {/* 対応フォーマット説明 */}
                <Card sx={{ mb: 3 }}>
                    <CardContent>
                        <Typography variant="h6" gutterBottom>
                            対応フォーマット
                        </Typography>
                        <Grid container spacing={2}>
                            <Grid size={{ xs: 12, md: 4 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="subtitle1" fontWeight="bold" color="primary">
                                        矢崎（Yazaki）
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        DTG7/DTG4シリーズのCSV出力に対応
                                    </Typography>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 4 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="subtitle1" fontWeight="bold" color="primary">
                                        デンソー（Denso）
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        運行データCSV出力に対応
                                    </Typography>
                                </Paper>
                            </Grid>
                            <Grid size={{ xs: 12, md: 4 }}>
                                <Paper sx={{ p: 2 }}>
                                    <Typography variant="subtitle1" fontWeight="bold" color="primary">
                                        アナタコ（手動入力）
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        所定フォーマットのExcel/CSVで手入力
                                    </Typography>
                                </Paper>
                            </Grid>
                        </Grid>
                    </CardContent>
                </Card>

                {/* インポート履歴 */}
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                    <Typography variant="h6">
                        インポート履歴
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
                                    <TableCell>ファイル名</TableCell>
                                    <TableCell>種別</TableCell>
                                    <TableCell>ステータス</TableCell>
                                    <TableCell>成功</TableCell>
                                    <TableCell>失敗</TableCell>
                                    <TableCell>実行者</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {history.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={7} align="center">
                                            インポート履歴がありません
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    history.map((record) => (
                                        <TableRow key={record.id} hover>
                                            <TableCell>
                                                {new Date(record.created_at).toLocaleString('ja-JP')}
                                            </TableCell>
                                            <TableCell>{record.file_name}</TableCell>
                                            <TableCell>{getFileTypeLabel(record.file_type)}</TableCell>
                                            <TableCell>{getStatusChip(record.status)}</TableCell>
                                            <TableCell>
                                                <Typography color="success.main" fontWeight="bold">
                                                    {record.records_imported}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Typography color={record.records_failed > 0 ? 'error.main' : 'text.secondary'}>
                                                    {record.records_failed}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>{record.uploaded_by_name}</TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                )}

                {/* プレビューダイアログ */}
                <Dialog open={previewOpen} onClose={() => setPreviewOpen(false)} maxWidth="md" fullWidth>
                    <DialogTitle>インポートプレビュー</DialogTitle>
                    <DialogContent>
                        {previewData && (
                            <>
                                <Alert severity="info" sx={{ mb: 2 }}>
                                    {previewData.total_records}件のレコードがインポートされます
                                </Alert>

                                {previewData.warnings.length > 0 && (
                                    <Alert severity="warning" sx={{ mb: 2 }}>
                                        <Typography variant="subtitle2">警告:</Typography>
                                        <ul style={{ margin: 0, paddingLeft: 20 }}>
                                            {previewData.warnings.map((warning, index) => (
                                                <li key={index}>{warning}</li>
                                            ))}
                                        </ul>
                                    </Alert>
                                )}

                                <Typography variant="subtitle2" gutterBottom>
                                    サンプルデータ（最初の5件）:
                                </Typography>
                                <TableContainer>
                                    <Table size="small">
                                        <TableHead>
                                            <TableRow>
                                                <TableCell>日付</TableCell>
                                                <TableCell>車両番号</TableCell>
                                                <TableCell>ドライバー</TableCell>
                                                <TableCell>走行距離</TableCell>
                                                <TableCell>運転時間</TableCell>
                                            </TableRow>
                                        </TableHead>
                                        <TableBody>
                                            {previewData.sample_records.map((record, index) => (
                                                <TableRow key={index}>
                                                    <TableCell>{record.date}</TableCell>
                                                    <TableCell>{record.vehicle_number}</TableCell>
                                                    <TableCell>{record.driver_name}</TableCell>
                                                    <TableCell>{record.distance}km</TableCell>
                                                    <TableCell>{record.duration}</TableCell>
                                                </TableRow>
                                            ))}
                                        </TableBody>
                                    </Table>
                                </TableContainer>
                            </>
                        )}
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => setPreviewOpen(false)}>キャンセル</Button>
                        <Button onClick={handleUpload} variant="contained" color="primary">
                            インポート実行
                        </Button>
                    </DialogActions>
                </Dialog>
            </Box>
        </Container>
    );
}
