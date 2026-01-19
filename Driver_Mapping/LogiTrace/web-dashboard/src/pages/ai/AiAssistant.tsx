import React, { useState, useRef, useEffect } from 'react';
import {
    Container,
    Typography,
    Box,
    Paper,
    Grid,
    Card,
    CardContent,
    CardActionArea,
    TextField,
    IconButton,
    List,
    ListItem,
    Avatar,
    Chip,
    Divider,
    Tab,
    Tabs,
    Alert,
    CircularProgress,
    Button,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Switch,
    FormControlLabel,
} from '@mui/material';
import {
    Send as SendIcon,
    SmartToy as SmartToyIcon,
    Person as PersonIcon,
    LocalShipping as LocalShippingIcon,
    AttachMoney as AttachMoneyIcon,
    Warning as WarningIcon,
    Analytics as AnalyticsIcon,
    Settings as SettingsIcon,
    TrendingUp as TrendingUpIcon,
    DirectionsCar as DirectionsCarIcon,
    AssignmentTurnedIn as AssignmentTurnedInIcon,
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

interface Message {
    id: number;
    role: 'user' | 'assistant';
    content: string;
    timestamp: Date;
    suggestedAction?: any;
}

interface ComplianceAlert {
    type: string;
    severity: 'critical' | 'warning' | 'info';
    message: string;
    recommendation: string;
}

const AiAssistant: React.FC = () => {
    const [tabValue, setTabValue] = useState(0);
    const [messages, setMessages] = useState<Message[]>([]);
    const [inputValue, setInputValue] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [complianceAlerts, setComplianceAlerts] = useState<ComplianceAlert[]>([]);
    const [openSettings, setOpenSettings] = useState(false);
    const messagesEndRef = useRef<HTMLDivElement>(null);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    };

    useEffect(() => {
        scrollToBottom();
    }, [messages]);

    useEffect(() => {
        // Initial greeting
        setMessages([
            {
                id: 1,
                role: 'assistant',
                content: 'こんにちは！LogiTrace AIアシスタントです。配車の最適化、コスト分析、コンプライアンス確認など、運送業務に関するご質問にお答えします。何かお手伝いできることはありますか？',
                timestamp: new Date(),
            },
        ]);

        // Load compliance alerts
        setComplianceAlerts([
            {
                type: 'driving_time',
                severity: 'warning',
                message: '山田運転手の今週の運転時間が38時間に達しています',
                recommendation: '追加の配車を避け、休息を確保してください',
            },
            {
                type: 'inspection',
                severity: 'critical',
                message: '車両「品川100あ1234」の車検期限が7日後です',
                recommendation: '早急に車検の予約を行ってください',
            },
            {
                type: 'terms_expiry',
                severity: 'info',
                message: '株式会社ABC商事との取引条件書が30日後に期限切れです',
                recommendation: '更新交渉を開始してください',
            },
        ]);
    }, []);

    const handleTabChange = (_event: React.SyntheticEvent, newValue: number) => {
        setTabValue(newValue);
    };

    const handleSendMessage = async () => {
        if (!inputValue.trim()) return;

        const userMessage: Message = {
            id: messages.length + 1,
            role: 'user',
            content: inputValue,
            timestamp: new Date(),
        };

        setMessages((prev) => [...prev, userMessage]);
        setInputValue('');
        setIsLoading(true);

        // Simulate AI response
        setTimeout(() => {
            const aiResponse: Message = {
                id: messages.length + 2,
                role: 'assistant',
                content: generateMockResponse(inputValue),
                timestamp: new Date(),
            };
            setMessages((prev) => [...prev, aiResponse]);
            setIsLoading(false);
        }, 1500);
    };

    const generateMockResponse = (input: string): string => {
        const lowerInput = input.toLowerCase();

        if (lowerInput.includes('配車') || lowerInput.includes('最適化')) {
            return '本日の配車状況を分析しました。現在12台の車両が稼働中で、平均稼働率は78%です。効率を上げるために、以下の提案があります：\n\n1. 東京→大阪ルートの2便を統合することで、1便分の燃料コストを削減できます\n2. 午後の空き時間を活用した帰り荷の取得を検討してください\n3. 明日の配車では、3名のドライバーの運転時間が上限に近づいているため、調整が必要です';
        }

        if (lowerInput.includes('コスト') || lowerInput.includes('費用')) {
            return '今月のコスト分析結果です：\n\n・総運行コスト：850万円（前月比 -3%）\n・燃料費：320万円（売上比 15.2%）\n・人件費：420万円\n・車両維持費：110万円\n\n燃料費は前月より5%減少しています。エコドライブの推進が効果を上げています。さらなるコスト削減のため、以下を推奨します：\n\n1. 高速道路利用の最適化（深夜割引の活用）\n2. 積載率の向上（現在72%→目標80%）';
        }

        if (lowerInput.includes('法令') || lowerInput.includes('コンプライアンス') || lowerInput.includes('改善基準')) {
            return '現在のコンプライアンス状況をお伝えします：\n\n【改善基準告示】\n・週40時間超過の恐れがあるドライバー：2名\n・連続運転4時間超過：なし\n・休息期間不足の恐れ：1名\n\n【点呼実施状況】\n・本日の点呼完了率：95%（19/20名）\n・未実施：佐藤運転手（外出中）\n\n佐藤運転手への点呼を早急に実施してください。電話点呼での対応も可能です。';
        }

        return `「${input}」についてのご質問ありがとうございます。\n\nLogiTrace AIアシスタントでは、以下のようなサポートが可能です：\n\n・配車の最適化提案\n・コスト分析とレポート\n・コンプライアンス状況の確認\n・運転者の稼働状況分析\n・燃費・効率の改善提案\n\n具体的にお知りになりたいことがあれば、お気軽にお聞きください。`;
    };

    const quickQuestions = [
        { icon: <LocalShippingIcon />, label: '今日の配車状況', query: '今日の配車状況を教えてください' },
        { icon: <AttachMoneyIcon />, label: '今月のコスト', query: '今月のコスト状況を分析してください' },
        { icon: <WarningIcon />, label: 'コンプライアンス', query: '現在のコンプライアンス状況を教えてください' },
        { icon: <TrendingUpIcon />, label: '効率改善', query: '運行効率を改善する方法を提案してください' },
    ];

    const getSeverityColor = (severity: string) => {
        switch (severity) {
            case 'critical':
                return 'error';
            case 'warning':
                return 'warning';
            default:
                return 'info';
        }
    };

    return (
        <Container maxWidth="xl">
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
                <Box>
                    <Typography variant="h4" component="h1" gutterBottom>
                        AIアシスタント
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        ChatGPT連携による業務支援・分析機能
                    </Typography>
                </Box>
                <IconButton onClick={() => setOpenSettings(true)}>
                    <SettingsIcon />
                </IconButton>
            </Box>

            <Paper sx={{ mb: 3 }}>
                <Tabs value={tabValue} onChange={handleTabChange}>
                    <Tab icon={<SmartToyIcon />} label="チャット" />
                    <Tab icon={<WarningIcon />} label="コンプライアンスアラート" />
                    <Tab icon={<AnalyticsIcon />} label="分析レポート" />
                </Tabs>
            </Paper>

            {/* Chat Tab */}
            <TabPanel value={tabValue} index={0}>
                <Grid container spacing={3}>
                    {/* Quick Questions */}
                    <Grid size={{ xs: 12 }}>
                        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', mb: 2 }}>
                            {quickQuestions.map((q, index) => (
                                <Chip
                                    key={index}
                                    icon={q.icon}
                                    label={q.label}
                                    onClick={() => {
                                        setInputValue(q.query);
                                    }}
                                    variant="outlined"
                                    sx={{ cursor: 'pointer' }}
                                />
                            ))}
                        </Box>
                    </Grid>

                    {/* Chat Area */}
                    <Grid size={{ xs: 12 }}>
                        <Paper sx={{ height: '500px', display: 'flex', flexDirection: 'column' }}>
                            {/* Messages */}
                            <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
                                <List>
                                    {messages.map((message) => (
                                        <ListItem
                                            key={message.id}
                                            sx={{
                                                flexDirection: message.role === 'user' ? 'row-reverse' : 'row',
                                                alignItems: 'flex-start',
                                                gap: 1,
                                            }}
                                        >
                                            <Avatar
                                                sx={{
                                                    bgcolor: message.role === 'assistant' ? 'primary.main' : 'grey.500',
                                                }}
                                            >
                                                {message.role === 'assistant' ? <SmartToyIcon /> : <PersonIcon />}
                                            </Avatar>
                                            <Paper
                                                sx={{
                                                    p: 2,
                                                    maxWidth: '70%',
                                                    bgcolor: message.role === 'user' ? 'primary.light' : 'grey.100',
                                                    color: message.role === 'user' ? 'white' : 'text.primary',
                                                }}
                                            >
                                                <Typography
                                                    variant="body1"
                                                    sx={{ whiteSpace: 'pre-wrap' }}
                                                >
                                                    {message.content}
                                                </Typography>
                                                <Typography
                                                    variant="caption"
                                                    sx={{
                                                        display: 'block',
                                                        mt: 1,
                                                        opacity: 0.7,
                                                    }}
                                                >
                                                    {message.timestamp.toLocaleTimeString()}
                                                </Typography>
                                            </Paper>
                                        </ListItem>
                                    ))}
                                    {isLoading && (
                                        <ListItem sx={{ gap: 1 }}>
                                            <Avatar sx={{ bgcolor: 'primary.main' }}>
                                                <SmartToyIcon />
                                            </Avatar>
                                            <CircularProgress size={24} />
                                        </ListItem>
                                    )}
                                    <div ref={messagesEndRef} />
                                </List>
                            </Box>

                            <Divider />

                            {/* Input Area */}
                            <Box sx={{ p: 2, display: 'flex', gap: 1 }}>
                                <TextField
                                    fullWidth
                                    placeholder="質問を入力してください..."
                                    value={inputValue}
                                    onChange={(e) => setInputValue(e.target.value)}
                                    onKeyPress={(e) => {
                                        if (e.key === 'Enter' && !e.shiftKey) {
                                            e.preventDefault();
                                            handleSendMessage();
                                        }
                                    }}
                                    multiline
                                    maxRows={3}
                                    disabled={isLoading}
                                />
                                <IconButton
                                    color="primary"
                                    onClick={handleSendMessage}
                                    disabled={isLoading || !inputValue.trim()}
                                >
                                    <SendIcon />
                                </IconButton>
                            </Box>
                        </Paper>
                    </Grid>
                </Grid>
            </TabPanel>

            {/* Compliance Alerts Tab */}
            <TabPanel value={tabValue} index={1}>
                <Grid container spacing={3}>
                    {complianceAlerts.map((alert, index) => (
                        <Grid size={{ xs: 12 }} key={index}>
                            <Alert
                                severity={getSeverityColor(alert.severity) as any}
                                sx={{ mb: 1 }}
                                action={
                                    <Button color="inherit" size="small">
                                        対応する
                                    </Button>
                                }
                            >
                                <Typography variant="subtitle2">{alert.message}</Typography>
                                <Typography variant="body2" sx={{ mt: 1 }}>
                                    推奨: {alert.recommendation}
                                </Typography>
                            </Alert>
                        </Grid>
                    ))}
                </Grid>
            </TabPanel>

            {/* Analysis Reports Tab */}
            <TabPanel value={tabValue} index={2}>
                <Grid container spacing={3}>
                    <Grid size={{ xs: 12, md: 4 }}>
                        <Card>
                            <CardActionArea>
                                <CardContent>
                                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                        <DirectionsCarIcon color="primary" sx={{ mr: 1, fontSize: 40 }} />
                                        <Typography variant="h6">配車最適化レポート</Typography>
                                    </Box>
                                    <Typography variant="body2" color="text.secondary">
                                        本日の配車状況を分析し、効率化の提案を行います
                                    </Typography>
                                    <Button variant="outlined" sx={{ mt: 2 }} fullWidth>
                                        レポートを生成
                                    </Button>
                                </CardContent>
                            </CardActionArea>
                        </Card>
                    </Grid>

                    <Grid size={{ xs: 12, md: 4 }}>
                        <Card>
                            <CardActionArea>
                                <CardContent>
                                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                        <AttachMoneyIcon color="success" sx={{ mr: 1, fontSize: 40 }} />
                                        <Typography variant="h6">コスト分析レポート</Typography>
                                    </Box>
                                    <Typography variant="body2" color="text.secondary">
                                        運行コストを分析し、削減ポイントを提案します
                                    </Typography>
                                    <Button variant="outlined" sx={{ mt: 2 }} fullWidth>
                                        レポートを生成
                                    </Button>
                                </CardContent>
                            </CardActionArea>
                        </Card>
                    </Grid>

                    <Grid size={{ xs: 12, md: 4 }}>
                        <Card>
                            <CardActionArea>
                                <CardContent>
                                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                        <AssignmentTurnedInIcon color="warning" sx={{ mr: 1, fontSize: 40 }} />
                                        <Typography variant="h6">コンプライアンスレポート</Typography>
                                    </Box>
                                    <Typography variant="body2" color="text.secondary">
                                        法令遵守状況を確認し、リスクを報告します
                                    </Typography>
                                    <Button variant="outlined" sx={{ mt: 2 }} fullWidth>
                                        レポートを生成
                                    </Button>
                                </CardContent>
                            </CardActionArea>
                        </Card>
                    </Grid>
                </Grid>
            </TabPanel>

            {/* Settings Dialog */}
            <Dialog open={openSettings} onClose={() => setOpenSettings(false)} maxWidth="sm" fullWidth>
                <DialogTitle>AI設定</DialogTitle>
                <DialogContent>
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="subtitle2" gutterBottom>
                            AIモデル
                        </Typography>
                        <TextField
                            fullWidth
                            select
                            defaultValue="gpt-4"
                            SelectProps={{ native: true }}
                            sx={{ mb: 3 }}
                        >
                            <option value="gpt-4">GPT-4（高精度）</option>
                            <option value="gpt-3.5-turbo">GPT-3.5 Turbo（高速）</option>
                        </TextField>

                        <Divider sx={{ my: 2 }} />

                        <Typography variant="subtitle2" gutterBottom>
                            機能設定
                        </Typography>
                        <FormControlLabel
                            control={<Switch defaultChecked />}
                            label="自動提案を有効にする"
                        />
                        <FormControlLabel
                            control={<Switch defaultChecked />}
                            label="コンプライアンスアラートを有効にする"
                        />
                        <FormControlLabel
                            control={<Switch />}
                            label="日次レポートを自動生成する"
                        />
                        <FormControlLabel
                            control={<Switch defaultChecked />}
                            label="コスト最適化提案を有効にする"
                        />

                        <Divider sx={{ my: 2 }} />

                        <Typography variant="subtitle2" gutterBottom>
                            利用状況
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            今月のトークン使用量: 15,230 / 100,000
                        </Typography>
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setOpenSettings(false)}>キャンセル</Button>
                    <Button variant="contained" onClick={() => setOpenSettings(false)}>
                        保存
                    </Button>
                </DialogActions>
            </Dialog>
        </Container>
    );
};

export default AiAssistant;
