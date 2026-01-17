import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    Container,
    Divider,
    Grid,
    Paper,
    Tab,
    Tabs,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Typography,
    CircularProgress,
    Alert
} from '@mui/material';
import {
    ArrowBack as BackIcon,
    Edit as EditIcon,
    LocalHospital as HealthIcon,
    Psychology as AptitudeIcon,
    School as TrainingIcon,
    Warning as AccidentIcon,
    PictureAsPdf as PdfIcon
} from '@mui/icons-material';

interface DriverRegistry {
    id: number;
    driver_id: number;
    full_name: string;
    full_name_kana: string;
    birth_date: string;
    address: string;
    phone: string;
    emergency_contact: string;
    emergency_phone: string;
    hire_date: string;
    termination_date: string | null;
    license_number: string;
    license_type: string;
    license_expiry_date: string;
    license_conditions: string | null;
    hazmat_license: boolean;
    hazmat_expiry_date: string | null;
    forklift_license: boolean;
    second_class_license: boolean;
    status: string;
    notes: string | null;
    employee_number: string | null;
}

interface HealthRecord {
    id: number;
    checkup_date: string;
    checkup_type: string;
    overall_result: string;
    facility_name: string;
}

interface AptitudeRecord {
    id: number;
    test_date: string;
    test_type: string;
    overall_score: number;
    facility_name: string;
}

interface TrainingRecord {
    id: number;
    training_date: string;
    training_name: string;
    training_type: string;
    completion_status: string;
}

interface AccidentRecord {
    id: number;
    incident_date: string;
    record_type: string;
    description: string;
    severity: string;
}

interface TabPanelProps {
    children?: React.ReactNode;
    index: number;
    value: number;
}

function TabPanel(props: TabPanelProps) {
    const { children, value, index, ...other } = props;
    return (
        <div role="tabpanel" hidden={value !== index} {...other}>
            {value === index && <Box sx={{ pt: 2 }}>{children}</Box>}
        </div>
    );
}

export default function DriverRegistryDetail() {
    const navigate = useNavigate();
    const { id } = useParams<{ id: string }>();
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [registry, setRegistry] = useState<DriverRegistry | null>(null);
    const [tabValue, setTabValue] = useState(0);
    const [downloadingPdf, setDownloadingPdf] = useState(false);

    const [healthRecords, setHealthRecords] = useState<HealthRecord[]>([]);
    const [aptitudeRecords, setAptitudeRecords] = useState<AptitudeRecord[]>([]);
    const [trainingRecords, setTrainingRecords] = useState<TrainingRecord[]>([]);
    const [accidentRecords, setAccidentRecords] = useState<AccidentRecord[]>([]);

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchRegistry();
    }, [id]);

    useEffect(() => {
        if (registry) {
            fetchRelatedRecords();
        }
    }, [registry]);

    const fetchRegistry = async () => {
        setLoading(true);
        try {
            const response = await fetch(`/api/driver-registry/${id}`, {
                headers: { 'Authorization': `Bearer ${user.token}` }
            });
            if (!response.ok) throw new Error('Failed to fetch registry');
            const data = await response.json();
            setRegistry(data);
        } catch (err) {
            setError('運転者台帳の取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const fetchRelatedRecords = async () => {
        if (!registry) return;

        try {
            const [healthRes, aptitudeRes, trainingRes, accidentRes] = await Promise.all([
                fetch(`/api/health-checkups/driver/${registry.driver_id}/history`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }),
                fetch(`/api/aptitude-tests/driver/${registry.driver_id}/history`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }),
                fetch(`/api/training/driver/${registry.driver_id}/history`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }),
                fetch(`/api/accidents/driver/${registry.driver_id}/history`, {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                })
            ]);

            if (healthRes.ok) setHealthRecords(await healthRes.json());
            if (aptitudeRes.ok) setAptitudeRecords(await aptitudeRes.json());
            if (trainingRes.ok) setTrainingRecords(await trainingRes.json());
            if (accidentRes.ok) setAccidentRecords(await accidentRes.json());
        } catch (err) {
            console.error('Failed to fetch related records');
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

    const getCheckupTypeLabel = (type: string) => {
        const types: { [key: string]: string } = {
            'regular': '定期健康診断',
            'special': '特殊健康診断',
            'pre_employment': '雇入時健康診断'
        };
        return types[type] || type;
    };

    const getTestTypeLabel = (type: string) => {
        const types: { [key: string]: string } = {
            'initial': '初任診断',
            'age_based': '適齢診断',
            'specific': '特定診断',
            'voluntary': '一般診断'
        };
        return types[type] || type;
    };

    const getResultColor = (result: string) => {
        switch (result) {
            case 'normal': return 'success';
            case 'observation': return 'warning';
            case 'treatment':
            case 'work_restriction': return 'error';
            default: return 'default';
        }
    };

    const getResultLabel = (result: string) => {
        const labels: { [key: string]: string } = {
            'normal': '異常なし',
            'observation': '要経過観察',
            'treatment': '要治療',
            'work_restriction': '就業制限'
        };
        return labels[result] || result;
    };

    const handleDownloadPDF = async () => {
        if (!registry) return;
        setDownloadingPdf(true);
        try {
            const response = await fetch(
                `/api/audit/driver-registry/${registry.driver_id}/pdf?companyId=${companyId}`,
                {
                    headers: { 'Authorization': `Bearer ${user.token}` }
                }
            );
            if (!response.ok) throw new Error('PDF download failed');

            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `運転者台帳_${registry.full_name}.pdf`;
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

    if (loading) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
                <CircularProgress />
            </Box>
        );
    }

    if (error || !registry) {
        return (
            <Container maxWidth="lg">
                <Box sx={{ my: 4 }}>
                    <Alert severity="error">{error || 'データが見つかりません'}</Alert>
                    <Button startIcon={<BackIcon />} onClick={() => navigate('/registry')} sx={{ mt: 2 }}>
                        一覧に戻る
                    </Button>
                </Box>
            </Container>
        );
    }

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center' }}>
                        <Button startIcon={<BackIcon />} onClick={() => navigate('/registry')} sx={{ mr: 2 }}>
                            戻る
                        </Button>
                        <Typography variant="h4" component="h1">
                            {registry.full_name}
                        </Typography>
                        <Chip
                            label={registry.status === 'active' ? '在籍' : registry.status === 'inactive' ? '退職' : '休止'}
                            color={registry.status === 'active' ? 'success' : 'default'}
                            sx={{ ml: 2 }}
                        />
                    </Box>
                    <Box sx={{ display: 'flex', gap: 1 }}>
                        <Button
                            variant="outlined"
                            startIcon={<PdfIcon />}
                            onClick={handleDownloadPDF}
                            disabled={downloadingPdf}
                        >
                            {downloadingPdf ? 'ダウンロード中...' : 'PDF出力'}
                        </Button>
                        <Button
                            variant="contained"
                            startIcon={<EditIcon />}
                            onClick={() => navigate(`/registry/${id}/edit`)}
                        >
                            編集
                        </Button>
                    </Box>
                </Box>

                {/* 基本情報カード */}
                <Grid container spacing={3} sx={{ mb: 3 }}>
                    <Grid size={{ xs: 12, md: 6 }}>
                        <Card>
                            <CardContent>
                                <Typography variant="h6" gutterBottom>基本情報</Typography>
                                <Grid container spacing={1}>
                                    <Grid size={{ xs: 4 }}><Typography color="text.secondary">フリガナ</Typography></Grid>
                                    <Grid size={{ xs: 8 }}><Typography>{registry.full_name_kana || '-'}</Typography></Grid>
                                    <Grid size={{ xs: 4 }}><Typography color="text.secondary">生年月日</Typography></Grid>
                                    <Grid size={{ xs: 8 }}><Typography>{registry.birth_date ? new Date(registry.birth_date).toLocaleDateString('ja-JP') : '-'}</Typography></Grid>
                                    <Grid size={{ xs: 4 }}><Typography color="text.secondary">電話番号</Typography></Grid>
                                    <Grid size={{ xs: 8 }}><Typography>{registry.phone || '-'}</Typography></Grid>
                                    <Grid size={{ xs: 4 }}><Typography color="text.secondary">住所</Typography></Grid>
                                    <Grid size={{ xs: 8 }}><Typography>{registry.address || '-'}</Typography></Grid>
                                    <Grid size={{ xs: 4 }}><Typography color="text.secondary">緊急連絡先</Typography></Grid>
                                    <Grid size={{ xs: 8 }}><Typography>{registry.emergency_contact || '-'} ({registry.emergency_phone || '-'})</Typography></Grid>
                                </Grid>
                            </CardContent>
                        </Card>
                    </Grid>
                    <Grid size={{ xs: 12, md: 6 }}>
                        <Card>
                            <CardContent>
                                <Typography variant="h6" gutterBottom>免許情報</Typography>
                                <Grid container spacing={1}>
                                    <Grid size={{ xs: 4 }}><Typography color="text.secondary">免許番号</Typography></Grid>
                                    <Grid size={{ xs: 8 }}><Typography>{registry.license_number}</Typography></Grid>
                                    <Grid size={{ xs: 4 }}><Typography color="text.secondary">免許種類</Typography></Grid>
                                    <Grid size={{ xs: 8 }}><Typography>{getLicenseTypeLabel(registry.license_type)}</Typography></Grid>
                                    <Grid size={{ xs: 4 }}><Typography color="text.secondary">有効期限</Typography></Grid>
                                    <Grid size={{ xs: 8 }}>
                                        <Typography>{new Date(registry.license_expiry_date).toLocaleDateString('ja-JP')}</Typography>
                                    </Grid>
                                    <Grid size={{ xs: 4 }}><Typography color="text.secondary">条件等</Typography></Grid>
                                    <Grid size={{ xs: 8 }}><Typography>{registry.license_conditions || '-'}</Typography></Grid>
                                </Grid>
                                <Divider sx={{ my: 1 }} />
                                <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                                    {registry.hazmat_license && <Chip label="危険物" size="small" color="warning" />}
                                    {registry.forklift_license && <Chip label="フォークリフト" size="small" color="info" />}
                                    {registry.second_class_license && <Chip label="第二種" size="small" color="primary" />}
                                </Box>
                            </CardContent>
                        </Card>
                    </Grid>
                </Grid>

                {/* タブ */}
                <Paper sx={{ mb: 3 }}>
                    <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)}>
                        <Tab icon={<HealthIcon />} label="健康診断" />
                        <Tab icon={<AptitudeIcon />} label="適性診断" />
                        <Tab icon={<TrainingIcon />} label="教育研修" />
                        <Tab icon={<AccidentIcon />} label="事故・違反" />
                    </Tabs>

                    <Box sx={{ p: 2 }}>
                        {/* 健康診断タブ */}
                        <TabPanel value={tabValue} index={0}>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>受診日</TableCell>
                                            <TableCell>種別</TableCell>
                                            <TableCell>結果</TableCell>
                                            <TableCell>実施機関</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {healthRecords.length === 0 ? (
                                            <TableRow>
                                                <TableCell colSpan={4} align="center">記録がありません</TableCell>
                                            </TableRow>
                                        ) : (
                                            healthRecords.map((record) => (
                                                <TableRow key={record.id}>
                                                    <TableCell>{new Date(record.checkup_date).toLocaleDateString('ja-JP')}</TableCell>
                                                    <TableCell>{getCheckupTypeLabel(record.checkup_type)}</TableCell>
                                                    <TableCell>
                                                        <Chip
                                                            label={getResultLabel(record.overall_result)}
                                                            color={getResultColor(record.overall_result) as any}
                                                            size="small"
                                                        />
                                                    </TableCell>
                                                    <TableCell>{record.facility_name}</TableCell>
                                                </TableRow>
                                            ))
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </TabPanel>

                        {/* 適性診断タブ */}
                        <TabPanel value={tabValue} index={1}>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>受診日</TableCell>
                                            <TableCell>種別</TableCell>
                                            <TableCell>スコア</TableCell>
                                            <TableCell>実施機関</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {aptitudeRecords.length === 0 ? (
                                            <TableRow>
                                                <TableCell colSpan={4} align="center">記録がありません</TableCell>
                                            </TableRow>
                                        ) : (
                                            aptitudeRecords.map((record) => (
                                                <TableRow key={record.id}>
                                                    <TableCell>{new Date(record.test_date).toLocaleDateString('ja-JP')}</TableCell>
                                                    <TableCell>{getTestTypeLabel(record.test_type)}</TableCell>
                                                    <TableCell>{record.overall_score || '-'}</TableCell>
                                                    <TableCell>{record.facility_name}</TableCell>
                                                </TableRow>
                                            ))
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </TabPanel>

                        {/* 教育研修タブ */}
                        <TabPanel value={tabValue} index={2}>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>実施日</TableCell>
                                            <TableCell>研修名</TableCell>
                                            <TableCell>種別</TableCell>
                                            <TableCell>状況</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {trainingRecords.length === 0 ? (
                                            <TableRow>
                                                <TableCell colSpan={4} align="center">記録がありません</TableCell>
                                            </TableRow>
                                        ) : (
                                            trainingRecords.map((record) => (
                                                <TableRow key={record.id}>
                                                    <TableCell>{new Date(record.training_date).toLocaleDateString('ja-JP')}</TableCell>
                                                    <TableCell>{record.training_name}</TableCell>
                                                    <TableCell>{record.training_type}</TableCell>
                                                    <TableCell>
                                                        <Chip
                                                            label={record.completion_status === 'completed' ? '完了' : record.completion_status === 'scheduled' ? '予定' : '未完了'}
                                                            color={record.completion_status === 'completed' ? 'success' : 'warning'}
                                                            size="small"
                                                        />
                                                    </TableCell>
                                                </TableRow>
                                            ))
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </TabPanel>

                        {/* 事故・違反タブ */}
                        <TabPanel value={tabValue} index={3}>
                            <TableContainer>
                                <Table size="small">
                                    <TableHead>
                                        <TableRow>
                                            <TableCell>発生日</TableCell>
                                            <TableCell>種別</TableCell>
                                            <TableCell>内容</TableCell>
                                            <TableCell>重大度</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {accidentRecords.length === 0 ? (
                                            <TableRow>
                                                <TableCell colSpan={4} align="center">記録がありません</TableCell>
                                            </TableRow>
                                        ) : (
                                            accidentRecords.map((record) => (
                                                <TableRow key={record.id}>
                                                    <TableCell>{new Date(record.incident_date).toLocaleDateString('ja-JP')}</TableCell>
                                                    <TableCell>
                                                        <Chip
                                                            label={record.record_type === 'accident' ? '事故' : '違反'}
                                                            color={record.record_type === 'accident' ? 'error' : 'warning'}
                                                            size="small"
                                                        />
                                                    </TableCell>
                                                    <TableCell>{record.description}</TableCell>
                                                    <TableCell>{record.severity || '-'}</TableCell>
                                                </TableRow>
                                            ))
                                        )}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        </TabPanel>
                    </Box>
                </Paper>
            </Box>
        </Container>
    );
}
