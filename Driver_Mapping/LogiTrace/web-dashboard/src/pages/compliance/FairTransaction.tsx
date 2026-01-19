import React, { useState, useEffect } from 'react';
import {
    Container,
    Typography,
    Box,
    Paper,
    Grid,
    Card,
    CardContent,
    Button,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Chip,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    MenuItem,
    Tab,
    Tabs,
    Alert,
    IconButton,
    Tooltip,
} from '@mui/material';
import {
    Add as AddIcon,
    Description as DescriptionIcon,
    Warning as WarningIcon,
    CheckCircle as CheckCircleIcon,
    Visibility as VisibilityIcon,
    Edit as EditIcon,
    PictureAsPdf as PdfIcon,
} from '@mui/icons-material';

interface TabPanelProps {
    children?: React.ReactNode;
    index: number;
    value: number;
}

function TabPanel(props: TabPanelProps) {
    const { children, value, index, ...other } = props;
    return (
        <div role="tabpanel" hidden={value !== index} {...other}>
            {value === index && <Box sx={{ pt: 3 }}>{children}</Box>}
        </div>
    );
}

interface TransactionTerms {
    id: number;
    terms_number: string;
    shipper_name: string;
    effective_date: string;
    expiry_date: string;
    cargo_type: string;
    base_fare_amount: number;
    document_received_confirmed: boolean;
    status: string;
}

interface UnfairPractice {
    id: number;
    shipper_name: string;
    incident_date: string;
    practice_type: string;
    description: string;
    original_amount: number;
    actual_amount: number;
    difference_amount: number;
    resolution_status: string;
}

interface Summary {
    transactionTerms: {
        active_terms: number;
        pending_confirmation: number;
        expiring_soon: number;
    };
    unfairPractices: {
        total_incidents: number;
        pending_resolution: number;
        pending_amount: number;
    };
}

const FairTransaction: React.FC = () => {
    const [tabValue, setTabValue] = useState(0);
    const [terms, setTerms] = useState<TransactionTerms[]>([]);
    const [practices, setPractices] = useState<UnfairPractice[]>([]);
    const [summary, setSummary] = useState<Summary | null>(null);
    const [openTermsDialog, setOpenTermsDialog] = useState(false);
    const [openPracticeDialog, setOpenPracticeDialog] = useState(false);

    // Mock data for demonstration
    useEffect(() => {
        // Simulated API call
        setSummary({
            transactionTerms: {
                active_terms: 15,
                pending_confirmation: 3,
                expiring_soon: 2,
            },
            unfairPractices: {
                total_incidents: 5,
                pending_resolution: 2,
                pending_amount: 150000,
            },
        });

        setTerms([
            {
                id: 1,
                terms_number: 'TT-2024-001',
                shipper_name: '株式会社ABC物流',
                effective_date: '2024-01-01',
                expiry_date: '2024-12-31',
                cargo_type: '一般貨物',
                base_fare_amount: 50000,
                document_received_confirmed: true,
                status: 'active',
            },
            {
                id: 2,
                terms_number: 'TT-2024-002',
                shipper_name: '株式会社XYZ商事',
                effective_date: '2024-02-01',
                expiry_date: '2025-01-31',
                cargo_type: '食品',
                base_fare_amount: 45000,
                document_received_confirmed: false,
                status: 'active',
            },
        ]);

        setPractices([
            {
                id: 1,
                shipper_name: '株式会社DEF運輸',
                incident_date: '2024-01-15',
                practice_type: 'price_cut',
                description: '一方的な運賃値下げ要求',
                original_amount: 50000,
                actual_amount: 40000,
                difference_amount: 10000,
                resolution_status: 'pending',
            },
        ]);
    }, []);

    const handleTabChange = (_event: React.SyntheticEvent, newValue: number) => {
        setTabValue(newValue);
    };

    const getPracticeTypeLabel = (type: string) => {
        const types: { [key: string]: string } = {
            price_cut: '運賃値下げ',
            payment_delay: '支払遅延',
            forced_discount: '強制値引',
            unreasonable_request: '不当要求',
        };
        return types[type] || type;
    };

    const getStatusChip = (status: string) => {
        switch (status) {
            case 'active':
                return <Chip label="有効" color="success" size="small" />;
            case 'expired':
                return <Chip label="期限切れ" color="error" size="small" />;
            case 'pending':
                return <Chip label="未解決" color="warning" size="small" />;
            case 'resolved':
                return <Chip label="解決済" color="success" size="small" />;
            default:
                return <Chip label={status} size="small" />;
        }
    };

    return (
        <Container maxWidth="xl">
            <Box sx={{ mb: 4 }}>
                <Typography variant="h4" component="h1" gutterBottom>
                    取適法対応
                </Typography>
                <Typography variant="body2" color="text.secondary">
                    トラック運送業における下請取引適正化法への対応状況を管理します
                </Typography>
            </Box>

            {/* Summary Cards */}
            {summary && (
                <Grid container spacing={3} sx={{ mb: 4 }}>
                    <Grid size={{ xs: 12, md: 4 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                    <DescriptionIcon color="primary" sx={{ mr: 1 }} />
                                    <Typography variant="h6">取引条件書</Typography>
                                </Box>
                                <Typography variant="h4" color="primary">
                                    {summary.transactionTerms.active_terms}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    有効な取引条件書
                                </Typography>
                                {summary.transactionTerms.pending_confirmation > 0 && (
                                    <Alert severity="warning" sx={{ mt: 2 }}>
                                        {summary.transactionTerms.pending_confirmation}件の書面確認待ち
                                    </Alert>
                                )}
                            </CardContent>
                        </Card>
                    </Grid>

                    <Grid size={{ xs: 12, md: 4 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                    <WarningIcon color="warning" sx={{ mr: 1 }} />
                                    <Typography variant="h6">期限間近</Typography>
                                </Box>
                                <Typography variant="h4" color="warning.main">
                                    {summary.transactionTerms.expiring_soon}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    30日以内に期限切れ
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>

                    <Grid size={{ xs: 12, md: 4 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                    <WarningIcon color="error" sx={{ mr: 1 }} />
                                    <Typography variant="h6">不当取引</Typography>
                                </Box>
                                <Typography variant="h4" color="error.main">
                                    {summary.unfairPractices.pending_resolution}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    未解決の事案
                                </Typography>
                                {summary.unfairPractices.pending_amount > 0 && (
                                    <Typography variant="body2" color="error">
                                        未回収額: ¥{summary.unfairPractices.pending_amount.toLocaleString()}
                                    </Typography>
                                )}
                            </CardContent>
                        </Card>
                    </Grid>
                </Grid>
            )}

            {/* Tabs */}
            <Paper sx={{ mb: 3 }}>
                <Tabs value={tabValue} onChange={handleTabChange}>
                    <Tab label="取引条件書" />
                    <Tab label="不当取引行為" />
                </Tabs>
            </Paper>

            {/* Transaction Terms Tab */}
            <TabPanel value={tabValue} index={0}>
                <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
                    <Button
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={() => setOpenTermsDialog(true)}
                    >
                        取引条件書を追加
                    </Button>
                </Box>

                <TableContainer component={Paper}>
                    <Table>
                        <TableHead>
                            <TableRow>
                                <TableCell>条件書番号</TableCell>
                                <TableCell>荷主名</TableCell>
                                <TableCell>適用期間</TableCell>
                                <TableCell>貨物種類</TableCell>
                                <TableCell align="right">基本運賃</TableCell>
                                <TableCell align="center">書面確認</TableCell>
                                <TableCell align="center">状態</TableCell>
                                <TableCell align="center">操作</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {terms.map((term) => (
                                <TableRow key={term.id}>
                                    <TableCell>{term.terms_number}</TableCell>
                                    <TableCell>{term.shipper_name}</TableCell>
                                    <TableCell>
                                        {term.effective_date} 〜 {term.expiry_date}
                                    </TableCell>
                                    <TableCell>{term.cargo_type}</TableCell>
                                    <TableCell align="right">
                                        ¥{term.base_fare_amount.toLocaleString()}
                                    </TableCell>
                                    <TableCell align="center">
                                        {term.document_received_confirmed ? (
                                            <CheckCircleIcon color="success" />
                                        ) : (
                                            <Tooltip title="書面交付確認が必要">
                                                <WarningIcon color="warning" />
                                            </Tooltip>
                                        )}
                                    </TableCell>
                                    <TableCell align="center">
                                        {getStatusChip(term.status)}
                                    </TableCell>
                                    <TableCell align="center">
                                        <IconButton size="small">
                                            <VisibilityIcon />
                                        </IconButton>
                                        <IconButton size="small">
                                            <EditIcon />
                                        </IconButton>
                                        <IconButton size="small">
                                            <PdfIcon />
                                        </IconButton>
                                    </TableCell>
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                </TableContainer>
            </TabPanel>

            {/* Unfair Practices Tab */}
            <TabPanel value={tabValue} index={1}>
                <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
                    <Button
                        variant="contained"
                        color="warning"
                        startIcon={<AddIcon />}
                        onClick={() => setOpenPracticeDialog(true)}
                    >
                        不当取引を記録
                    </Button>
                </Box>

                <TableContainer component={Paper}>
                    <Table>
                        <TableHead>
                            <TableRow>
                                <TableCell>発生日</TableCell>
                                <TableCell>荷主名</TableCell>
                                <TableCell>行為類型</TableCell>
                                <TableCell>概要</TableCell>
                                <TableCell align="right">本来金額</TableCell>
                                <TableCell align="right">実際金額</TableCell>
                                <TableCell align="right">差額</TableCell>
                                <TableCell align="center">状態</TableCell>
                                <TableCell align="center">操作</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {practices.map((practice) => (
                                <TableRow key={practice.id}>
                                    <TableCell>{practice.incident_date}</TableCell>
                                    <TableCell>{practice.shipper_name}</TableCell>
                                    <TableCell>
                                        {getPracticeTypeLabel(practice.practice_type)}
                                    </TableCell>
                                    <TableCell>{practice.description}</TableCell>
                                    <TableCell align="right">
                                        ¥{practice.original_amount.toLocaleString()}
                                    </TableCell>
                                    <TableCell align="right">
                                        ¥{practice.actual_amount.toLocaleString()}
                                    </TableCell>
                                    <TableCell align="right" sx={{ color: 'error.main' }}>
                                        ¥{practice.difference_amount.toLocaleString()}
                                    </TableCell>
                                    <TableCell align="center">
                                        {getStatusChip(practice.resolution_status)}
                                    </TableCell>
                                    <TableCell align="center">
                                        <IconButton size="small">
                                            <VisibilityIcon />
                                        </IconButton>
                                        <IconButton size="small">
                                            <EditIcon />
                                        </IconButton>
                                    </TableCell>
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                </TableContainer>
            </TabPanel>

            {/* Add Transaction Terms Dialog */}
            <Dialog open={openTermsDialog} onClose={() => setOpenTermsDialog(false)} maxWidth="md" fullWidth>
                <DialogTitle>取引条件書の追加</DialogTitle>
                <DialogContent>
                    <Grid container spacing={2} sx={{ mt: 1 }}>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                label="条件書番号"
                                placeholder="TT-2024-XXX"
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                select
                                label="荷主"
                            >
                                <MenuItem value="1">株式会社ABC物流</MenuItem>
                                <MenuItem value="2">株式会社XYZ商事</MenuItem>
                            </TextField>
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                type="date"
                                label="適用開始日"
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                type="date"
                                label="適用終了日"
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField fullWidth label="貨物種類" />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                select
                                label="輸送形態"
                            >
                                <MenuItem value="exclusive">貸切</MenuItem>
                                <MenuItem value="consolidated">積合</MenuItem>
                                <MenuItem value="charter">チャーター</MenuItem>
                            </TextField>
                        </Grid>
                        <Grid size={{ xs: 12 }}>
                            <TextField fullWidth label="運送区間" multiline rows={2} />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                fullWidth
                                type="number"
                                label="基本運賃"
                                InputProps={{ startAdornment: '¥' }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                fullWidth
                                type="number"
                                label="燃料サーチャージ率"
                                InputProps={{ endAdornment: '%' }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                fullWidth
                                type="number"
                                label="待機料（時間）"
                                InputProps={{ startAdornment: '¥' }}
                            />
                        </Grid>
                    </Grid>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setOpenTermsDialog(false)}>キャンセル</Button>
                    <Button variant="contained" onClick={() => setOpenTermsDialog(false)}>
                        保存
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Add Unfair Practice Dialog */}
            <Dialog open={openPracticeDialog} onClose={() => setOpenPracticeDialog(false)} maxWidth="md" fullWidth>
                <DialogTitle>不当取引行為の記録</DialogTitle>
                <DialogContent>
                    <Alert severity="info" sx={{ mb: 2, mt: 1 }}>
                        不当な取引行為を記録することで、証拠を保全し、必要に応じて行政機関への報告が可能です。
                    </Alert>
                    <Grid container spacing={2}>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                type="date"
                                label="発生日"
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                select
                                label="荷主"
                            >
                                <MenuItem value="1">株式会社ABC物流</MenuItem>
                                <MenuItem value="2">株式会社XYZ商事</MenuItem>
                            </TextField>
                        </Grid>
                        <Grid size={{ xs: 12 }}>
                            <TextField
                                fullWidth
                                select
                                label="行為類型"
                            >
                                <MenuItem value="price_cut">運賃値下げ要求</MenuItem>
                                <MenuItem value="payment_delay">支払遅延</MenuItem>
                                <MenuItem value="forced_discount">強制値引</MenuItem>
                                <MenuItem value="unreasonable_request">不当な役務提供要求</MenuItem>
                            </TextField>
                        </Grid>
                        <Grid size={{ xs: 12 }}>
                            <TextField
                                fullWidth
                                label="概要"
                                multiline
                                rows={3}
                                placeholder="発生した事案の詳細を記載してください"
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                type="number"
                                label="本来の金額"
                                InputProps={{ startAdornment: '¥' }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                type="number"
                                label="実際の金額"
                                InputProps={{ startAdornment: '¥' }}
                            />
                        </Grid>
                    </Grid>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setOpenPracticeDialog(false)}>キャンセル</Button>
                    <Button variant="contained" color="warning" onClick={() => setOpenPracticeDialog(false)}>
                        記録する
                    </Button>
                </DialogActions>
            </Dialog>
        </Container>
    );
};

export default FairTransaction;
