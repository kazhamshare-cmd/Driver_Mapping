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
    Stepper,
    Step,
    StepLabel,
    List,
    ListItem,
    ListItemText,
    Divider,
} from '@mui/material';
import {
    Add as AddIcon,
    LocalShipping as LocalShippingIcon,
    Assignment as AssignmentIcon,
    CheckCircle as CheckCircleIcon,
    Visibility as VisibilityIcon,
    Edit as EditIcon,
    Send as SendIcon,
    AccountTree as AccountTreeIcon,
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

interface TransportChainItem {
    tier: number;
    company: string;
    permit: string;
}

interface ActualTransportRecord {
    id: number;
    record_number: string;
    transport_date: string;
    shipper_name: string;
    actual_carrier_name: string;
    actual_carrier_tier: number;
    pickup_location: string;
    delivery_location: string;
    vehicle_number: string;
    driver_name: string;
    shipper_fare: number;
    actual_carrier_fare: number;
    status: string;
    transport_chain: TransportChainItem[];
}

interface SubcontractAgreement {
    id: number;
    prime_contractor_name: string;
    prime_contractor_permit_number: string;
    subcontractor_tier: number;
    agreement_number: string;
    agreement_start_date: string;
    agreement_end_date: string;
    status: string;
}

interface Summary {
    total_records: number;
    pending_confirmation: number;
    submitted: number;
    multi_tier_transports: number;
}

const ActualTransport: React.FC = () => {
    const [tabValue, setTabValue] = useState(0);
    const [records, setRecords] = useState<ActualTransportRecord[]>([]);
    const [agreements, setAgreements] = useState<SubcontractAgreement[]>([]);
    const [summary, setSummary] = useState<Summary | null>(null);
    const [openRecordDialog, setOpenRecordDialog] = useState(false);
    const [openDetailDialog, setOpenDetailDialog] = useState(false);
    const [selectedRecord, setSelectedRecord] = useState<ActualTransportRecord | null>(null);

    useEffect(() => {
        // Simulated API call
        setSummary({
            total_records: 150,
            pending_confirmation: 8,
            submitted: 142,
            multi_tier_transports: 25,
        });

        setRecords([
            {
                id: 1,
                record_number: 'ATR-2024-0001',
                transport_date: '2024-01-15',
                shipper_name: '株式会社ABC商事',
                actual_carrier_name: '株式会社DEF運送',
                actual_carrier_tier: 2,
                pickup_location: '東京都港区',
                delivery_location: '大阪府大阪市',
                vehicle_number: '品川 100 あ 1234',
                driver_name: '田中太郎',
                shipper_fare: 80000,
                actual_carrier_fare: 55000,
                status: 'confirmed',
                transport_chain: [
                    { tier: 1, company: '当社（株式会社ロジトレース）', permit: '関自貨第1234号' },
                    { tier: 2, company: '株式会社DEF運送', permit: '関自貨第5678号' },
                ],
            },
            {
                id: 2,
                record_number: 'ATR-2024-0002',
                transport_date: '2024-01-16',
                shipper_name: '株式会社XYZ物流',
                actual_carrier_name: '当社（自社運送）',
                actual_carrier_tier: 1,
                pickup_location: '神奈川県横浜市',
                delivery_location: '愛知県名古屋市',
                vehicle_number: '横浜 200 い 5678',
                driver_name: '鈴木一郎',
                shipper_fare: 65000,
                actual_carrier_fare: 65000,
                status: 'draft',
                transport_chain: [
                    { tier: 1, company: '当社（株式会社ロジトレース）', permit: '関自貨第1234号' },
                ],
            },
        ]);

        setAgreements([
            {
                id: 1,
                prime_contractor_name: '大手物流株式会社',
                prime_contractor_permit_number: '関自貨第9999号',
                subcontractor_tier: 1,
                agreement_number: 'SC-2024-001',
                agreement_start_date: '2024-01-01',
                agreement_end_date: '2024-12-31',
                status: 'active',
            },
        ]);
    }, []);

    const handleTabChange = (_event: React.SyntheticEvent, newValue: number) => {
        setTabValue(newValue);
    };

    const handleViewDetail = (record: ActualTransportRecord) => {
        setSelectedRecord(record);
        setOpenDetailDialog(true);
    };

    const getStatusChip = (status: string) => {
        switch (status) {
            case 'draft':
                return <Chip label="下書き" size="small" />;
            case 'confirmed':
                return <Chip label="確認済" color="primary" size="small" />;
            case 'submitted':
                return <Chip label="提出済" color="success" size="small" />;
            case 'active':
                return <Chip label="有効" color="success" size="small" />;
            default:
                return <Chip label={status} size="small" />;
        }
    };

    return (
        <Container maxWidth="xl">
            <Box sx={{ mb: 4 }}>
                <Typography variant="h4" component="h1" gutterBottom>
                    実運送体制管理簿
                </Typography>
                <Typography variant="body2" color="text.secondary">
                    2024年法改正対応：運送委託チェーンの可視化と実運送事業者の管理
                </Typography>
            </Box>

            {/* Summary Cards */}
            {summary && (
                <Grid container spacing={3} sx={{ mb: 4 }}>
                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                    <AssignmentIcon color="primary" sx={{ mr: 1 }} />
                                    <Typography variant="h6">総記録数</Typography>
                                </Box>
                                <Typography variant="h4" color="primary">
                                    {summary.total_records}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>

                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                    <LocalShippingIcon color="warning" sx={{ mr: 1 }} />
                                    <Typography variant="h6">確認待ち</Typography>
                                </Box>
                                <Typography variant="h4" color="warning.main">
                                    {summary.pending_confirmation}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>

                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                    <CheckCircleIcon color="success" sx={{ mr: 1 }} />
                                    <Typography variant="h6">提出済</Typography>
                                </Box>
                                <Typography variant="h4" color="success.main">
                                    {summary.submitted}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>

                    <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                        <Card>
                            <CardContent>
                                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                    <AccountTreeIcon color="info" sx={{ mr: 1 }} />
                                    <Typography variant="h6">多重下請</Typography>
                                </Box>
                                <Typography variant="h4" color="info.main">
                                    {summary.multi_tier_transports}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    2次以上の下請案件
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                </Grid>
            )}

            {/* Tabs */}
            <Paper sx={{ mb: 3 }}>
                <Tabs value={tabValue} onChange={handleTabChange}>
                    <Tab label="実運送体制管理簿" />
                    <Tab label="下請契約管理" />
                </Tabs>
            </Paper>

            {/* Transport Records Tab */}
            <TabPanel value={tabValue} index={0}>
                <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
                    <Button
                        variant="contained"
                        startIcon={<AddIcon />}
                        onClick={() => setOpenRecordDialog(true)}
                    >
                        管理簿を追加
                    </Button>
                </Box>

                <TableContainer component={Paper}>
                    <Table>
                        <TableHead>
                            <TableRow>
                                <TableCell>管理簿番号</TableCell>
                                <TableCell>運送日</TableCell>
                                <TableCell>荷主</TableCell>
                                <TableCell>実運送事業者</TableCell>
                                <TableCell>下請階層</TableCell>
                                <TableCell>車両番号</TableCell>
                                <TableCell align="right">荷主運賃</TableCell>
                                <TableCell align="right">実運送運賃</TableCell>
                                <TableCell align="center">状態</TableCell>
                                <TableCell align="center">操作</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {records.map((record) => (
                                <TableRow key={record.id}>
                                    <TableCell>{record.record_number}</TableCell>
                                    <TableCell>{record.transport_date}</TableCell>
                                    <TableCell>{record.shipper_name}</TableCell>
                                    <TableCell>{record.actual_carrier_name}</TableCell>
                                    <TableCell>
                                        <Chip
                                            label={`${record.actual_carrier_tier}次`}
                                            size="small"
                                            color={record.actual_carrier_tier > 1 ? 'warning' : 'default'}
                                        />
                                    </TableCell>
                                    <TableCell>{record.vehicle_number}</TableCell>
                                    <TableCell align="right">
                                        ¥{record.shipper_fare.toLocaleString()}
                                    </TableCell>
                                    <TableCell align="right">
                                        ¥{record.actual_carrier_fare.toLocaleString()}
                                    </TableCell>
                                    <TableCell align="center">
                                        {getStatusChip(record.status)}
                                    </TableCell>
                                    <TableCell align="center">
                                        <IconButton size="small" onClick={() => handleViewDetail(record)}>
                                            <VisibilityIcon />
                                        </IconButton>
                                        <IconButton size="small">
                                            <EditIcon />
                                        </IconButton>
                                        {record.status === 'confirmed' && (
                                            <Tooltip title="提出する">
                                                <IconButton size="small" color="primary">
                                                    <SendIcon />
                                                </IconButton>
                                            </Tooltip>
                                        )}
                                    </TableCell>
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                </TableContainer>
            </TabPanel>

            {/* Subcontract Agreements Tab */}
            <TabPanel value={tabValue} index={1}>
                <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
                    <Button variant="contained" startIcon={<AddIcon />}>
                        下請契約を追加
                    </Button>
                </Box>

                <TableContainer component={Paper}>
                    <Table>
                        <TableHead>
                            <TableRow>
                                <TableCell>契約番号</TableCell>
                                <TableCell>元請事業者</TableCell>
                                <TableCell>許可番号</TableCell>
                                <TableCell>下請階層</TableCell>
                                <TableCell>契約期間</TableCell>
                                <TableCell align="center">状態</TableCell>
                                <TableCell align="center">操作</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {agreements.map((agreement) => (
                                <TableRow key={agreement.id}>
                                    <TableCell>{agreement.agreement_number}</TableCell>
                                    <TableCell>{agreement.prime_contractor_name}</TableCell>
                                    <TableCell>{agreement.prime_contractor_permit_number}</TableCell>
                                    <TableCell>
                                        <Chip label={`${agreement.subcontractor_tier}次下請`} size="small" />
                                    </TableCell>
                                    <TableCell>
                                        {agreement.agreement_start_date} 〜 {agreement.agreement_end_date}
                                    </TableCell>
                                    <TableCell align="center">
                                        {getStatusChip(agreement.status)}
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

            {/* Add Record Dialog */}
            <Dialog open={openRecordDialog} onClose={() => setOpenRecordDialog(false)} maxWidth="md" fullWidth>
                <DialogTitle>実運送体制管理簿の追加</DialogTitle>
                <DialogContent>
                    <Alert severity="info" sx={{ mb: 2, mt: 1 }}>
                        運送委託チェーン（多重下請構造）を正確に記録してください。
                    </Alert>
                    <Grid container spacing={2}>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                type="date"
                                label="運送日"
                                InputLabelProps={{ shrink: true }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField fullWidth label="荷主名" />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField fullWidth label="積地" />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField fullWidth label="卸地" />
                        </Grid>
                        <Grid size={{ xs: 12 }}>
                            <TextField fullWidth label="貨物概要" multiline rows={2} />
                        </Grid>
                        <Grid size={{ xs: 12 }}>
                            <Typography variant="subtitle2" gutterBottom sx={{ mt: 2 }}>
                                運送委託チェーン
                            </Typography>
                            <Alert severity="warning" sx={{ mb: 2 }}>
                                実際に運送を行う事業者までの委託チェーンを入力してください
                            </Alert>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField fullWidth label="1次：事業者名" defaultValue="当社" disabled />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField fullWidth label="許可番号" defaultValue="関自貨第1234号" disabled />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                fullWidth
                                select
                                label="実運送？"
                                defaultValue="no"
                            >
                                <MenuItem value="yes">はい（自社で運送）</MenuItem>
                                <MenuItem value="no">いいえ（下請に委託）</MenuItem>
                            </TextField>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField fullWidth label="2次：事業者名" />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField fullWidth label="許可番号" />
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <TextField
                                fullWidth
                                select
                                label="実運送？"
                            >
                                <MenuItem value="yes">はい</MenuItem>
                                <MenuItem value="no">いいえ</MenuItem>
                            </TextField>
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField fullWidth label="車両番号" />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField fullWidth label="運転者名" />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                type="number"
                                label="荷主からの運賃"
                                InputProps={{ startAdornment: '¥' }}
                            />
                        </Grid>
                        <Grid size={{ xs: 12, md: 6 }}>
                            <TextField
                                fullWidth
                                type="number"
                                label="実運送者への支払"
                                InputProps={{ startAdornment: '¥' }}
                            />
                        </Grid>
                    </Grid>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setOpenRecordDialog(false)}>キャンセル</Button>
                    <Button variant="contained" onClick={() => setOpenRecordDialog(false)}>
                        保存
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Detail Dialog */}
            <Dialog open={openDetailDialog} onClose={() => setOpenDetailDialog(false)} maxWidth="md" fullWidth>
                <DialogTitle>実運送体制管理簿詳細</DialogTitle>
                <DialogContent>
                    {selectedRecord && (
                        <Box>
                            <Grid container spacing={2} sx={{ mb: 3, mt: 1 }}>
                                <Grid size={{ xs: 6 }}>
                                    <Typography variant="body2" color="text.secondary">管理簿番号</Typography>
                                    <Typography variant="body1">{selectedRecord.record_number}</Typography>
                                </Grid>
                                <Grid size={{ xs: 6 }}>
                                    <Typography variant="body2" color="text.secondary">運送日</Typography>
                                    <Typography variant="body1">{selectedRecord.transport_date}</Typography>
                                </Grid>
                                <Grid size={{ xs: 6 }}>
                                    <Typography variant="body2" color="text.secondary">荷主</Typography>
                                    <Typography variant="body1">{selectedRecord.shipper_name}</Typography>
                                </Grid>
                                <Grid size={{ xs: 6 }}>
                                    <Typography variant="body2" color="text.secondary">運送区間</Typography>
                                    <Typography variant="body1">
                                        {selectedRecord.pickup_location} → {selectedRecord.delivery_location}
                                    </Typography>
                                </Grid>
                            </Grid>

                            <Divider sx={{ my: 2 }} />

                            <Typography variant="h6" gutterBottom>運送委託チェーン</Typography>
                            <Stepper activeStep={selectedRecord.actual_carrier_tier - 1} orientation="vertical">
                                {selectedRecord.transport_chain.map((item) => (
                                    <Step key={item.tier} completed>
                                        <StepLabel>
                                            <Typography variant="subtitle2">
                                                {item.tier}次：{item.company}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                許可番号：{item.permit}
                                            </Typography>
                                        </StepLabel>
                                    </Step>
                                ))}
                            </Stepper>

                            <Divider sx={{ my: 2 }} />

                            <Typography variant="h6" gutterBottom>実運送情報</Typography>
                            <List dense>
                                <ListItem>
                                    <ListItemText
                                        primary="実運送事業者"
                                        secondary={selectedRecord.actual_carrier_name}
                                    />
                                </ListItem>
                                <ListItem>
                                    <ListItemText
                                        primary="車両番号"
                                        secondary={selectedRecord.vehicle_number}
                                    />
                                </ListItem>
                                <ListItem>
                                    <ListItemText
                                        primary="運転者"
                                        secondary={selectedRecord.driver_name}
                                    />
                                </ListItem>
                            </List>

                            <Divider sx={{ my: 2 }} />

                            <Typography variant="h6" gutterBottom>運賃情報</Typography>
                            <Grid container spacing={2}>
                                <Grid size={{ xs: 4 }}>
                                    <Typography variant="body2" color="text.secondary">荷主運賃</Typography>
                                    <Typography variant="h6">
                                        ¥{selectedRecord.shipper_fare.toLocaleString()}
                                    </Typography>
                                </Grid>
                                <Grid size={{ xs: 4 }}>
                                    <Typography variant="body2" color="text.secondary">実運送運賃</Typography>
                                    <Typography variant="h6">
                                        ¥{selectedRecord.actual_carrier_fare.toLocaleString()}
                                    </Typography>
                                </Grid>
                                <Grid size={{ xs: 4 }}>
                                    <Typography variant="body2" color="text.secondary">中間マージン</Typography>
                                    <Typography variant="h6" color="primary">
                                        ¥{(selectedRecord.shipper_fare - selectedRecord.actual_carrier_fare).toLocaleString()}
                                    </Typography>
                                </Grid>
                            </Grid>
                        </Box>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setOpenDetailDialog(false)}>閉じる</Button>
                    {selectedRecord?.status === 'draft' && (
                        <Button variant="contained" color="primary">
                            確認する
                        </Button>
                    )}
                    {selectedRecord?.status === 'confirmed' && (
                        <Button variant="contained" color="success" startIcon={<SendIcon />}>
                            提出する
                        </Button>
                    )}
                </DialogActions>
            </Dialog>
        </Container>
    );
};

export default ActualTransport;
