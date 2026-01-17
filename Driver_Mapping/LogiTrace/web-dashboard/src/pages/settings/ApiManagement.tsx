import { useState, useEffect } from 'react';
import {
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    Container,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    FormControl,
    Grid,
    IconButton,
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
    Alert,
    Tooltip,
    Tabs,
    Tab,
    Snackbar
} from '@mui/material';
import {
    Add as AddIcon,
    Delete as DeleteIcon,
    Refresh as RefreshIcon,
    ContentCopy as CopyIcon,
    Visibility as ViewIcon,
    VisibilityOff as HideIcon,
    Key as KeyIcon,
    Webhook as WebhookIcon,
    BarChart as ChartIcon,
    PlayArrow as TestIcon
} from '@mui/icons-material';

interface ApiKey {
    id: number;
    key_name: string;
    key_prefix: string;
    key?: string; // Only available on creation
    scopes: string[];
    rate_limit_per_minute: number;
    allowed_ips: string[] | null;
    is_active: boolean;
    last_used_at: string | null;
    usage_count: number;
    expires_at: string | null;
    created_at: string;
}

interface Webhook {
    id: number;
    webhook_name: string;
    webhook_url: string;
    events: string[];
    is_active: boolean;
    last_triggered_at: string | null;
    failure_count: number;
    created_at: string;
}

interface UsageStats {
    keyUsage: any[];
    dailyUsage: any[];
    topEndpoints: any[];
    period: string;
}

const AVAILABLE_SCOPES = [
    { value: 'read', label: '読み取り', description: 'データの取得' },
    { value: 'write', label: '書き込み', description: 'データの作成・更新' },
    { value: 'delete', label: '削除', description: 'データの削除' },
    { value: 'admin', label: '管理者', description: 'すべての操作' }
];

const AVAILABLE_EVENTS = [
    { value: 'work_record.created', label: '日報作成時' },
    { value: 'tenko.created', label: '点呼記録作成時' },
    { value: 'inspection.created', label: '点検記録作成時' },
    { value: 'license.expiring', label: '免許期限アラート' },
    { value: 'inspection.expiring', label: '車検期限アラート' },
    { value: 'health.expiring', label: '健康診断期限アラート' }
];

export default function ApiManagement() {
    const [activeTab, setActiveTab] = useState(0);
    const [apiKeys, setApiKeys] = useState<ApiKey[]>([]);
    const [webhooks, setWebhooks] = useState<Webhook[]>([]);
    const [usageStats, setUsageStats] = useState<UsageStats | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');

    // Dialog states
    const [keyDialogOpen, setKeyDialogOpen] = useState(false);
    const [webhookDialogOpen, setWebhookDialogOpen] = useState(false);
    const [newKeyVisible, setNewKeyVisible] = useState<string | null>(null);

    // Form states
    const [keyForm, setKeyForm] = useState({
        keyName: '',
        scopes: ['read'],
        rateLimitPerMinute: 60,
        allowedIps: '',
        expiresAt: ''
    });

    const [webhookForm, setWebhookForm] = useState({
        webhookName: '',
        webhookUrl: '',
        events: [] as string[]
    });

    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const companyId = user.companyId || 1;

    useEffect(() => {
        fetchData();
    }, [activeTab]);

    const fetchData = async () => {
        setLoading(true);
        try {
            if (activeTab === 0) {
                await fetchApiKeys();
            } else if (activeTab === 1) {
                await fetchWebhooks();
            } else {
                await fetchUsageStats();
            }
        } catch (err) {
            setError('データの取得に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const fetchApiKeys = async () => {
        const response = await fetch(`/api/api-management/keys?companyId=${companyId}`, {
            headers: { 'Authorization': `Bearer ${user.token}` }
        });
        if (!response.ok) throw new Error('Failed to fetch API keys');
        const data = await response.json();
        setApiKeys(data);
    };

    const fetchWebhooks = async () => {
        const response = await fetch(`/api/api-management/webhooks?companyId=${companyId}`, {
            headers: { 'Authorization': `Bearer ${user.token}` }
        });
        if (!response.ok) throw new Error('Failed to fetch webhooks');
        const data = await response.json();
        setWebhooks(data);
    };

    const fetchUsageStats = async () => {
        const response = await fetch(`/api/api-management/usage?companyId=${companyId}&days=30`, {
            headers: { 'Authorization': `Bearer ${user.token}` }
        });
        if (!response.ok) throw new Error('Failed to fetch usage stats');
        const data = await response.json();
        setUsageStats(data);
    };

    const handleCreateKey = async () => {
        try {
            const response = await fetch('/api/api-management/keys', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    companyId,
                    keyName: keyForm.keyName,
                    scopes: keyForm.scopes,
                    rateLimitPerMinute: keyForm.rateLimitPerMinute,
                    allowedIps: keyForm.allowedIps ? keyForm.allowedIps.split(',').map(ip => ip.trim()) : [],
                    expiresAt: keyForm.expiresAt || null
                })
            });

            if (!response.ok) {
                const err = await response.json();
                throw new Error(err.message || 'Failed to create API key');
            }

            const result = await response.json();
            setNewKeyVisible(result.apiKey.key);
            setSuccess('APIキーが作成されました。このキーは一度だけ表示されます。');
            fetchApiKeys();
            resetKeyForm();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'APIキーの作成に失敗しました');
        }
    };

    const handleDeleteKey = async (id: number) => {
        if (!confirm('このAPIキーを削除しますか？削除すると、このキーを使用しているすべての連携が停止します。')) return;

        try {
            const response = await fetch(`/api/api-management/keys/${id}?companyId=${companyId}`, {
                method: 'DELETE',
                headers: { 'Authorization': `Bearer ${user.token}` }
            });

            if (!response.ok) throw new Error('Failed to delete API key');
            setSuccess('APIキーを削除しました');
            fetchApiKeys();
        } catch (err) {
            setError('APIキーの削除に失敗しました');
        }
    };

    const handleToggleKeyActive = async (key: ApiKey) => {
        try {
            const response = await fetch(`/api/api-management/keys/${key.id}?companyId=${companyId}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({ isActive: !key.is_active })
            });

            if (!response.ok) throw new Error('Failed to update API key');
            setSuccess(`APIキーを${key.is_active ? '無効化' : '有効化'}しました`);
            fetchApiKeys();
        } catch (err) {
            setError('APIキーの更新に失敗しました');
        }
    };

    const handleRegenerateKey = async (id: number) => {
        if (!confirm('このAPIキーを再生成しますか？古いキーは無効になります。')) return;

        try {
            const response = await fetch(`/api/api-management/keys/${id}/regenerate?companyId=${companyId}`, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${user.token}` }
            });

            if (!response.ok) throw new Error('Failed to regenerate API key');
            const result = await response.json();
            setNewKeyVisible(result.apiKey.key);
            setSuccess('APIキーが再生成されました。このキーは一度だけ表示されます。');
            fetchApiKeys();
        } catch (err) {
            setError('APIキーの再生成に失敗しました');
        }
    };

    const handleCreateWebhook = async () => {
        try {
            const response = await fetch('/api/api-management/webhooks', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${user.token}`
                },
                body: JSON.stringify({
                    companyId,
                    webhookName: webhookForm.webhookName,
                    webhookUrl: webhookForm.webhookUrl,
                    events: webhookForm.events
                })
            });

            if (!response.ok) throw new Error('Failed to create webhook');
            setSuccess('Webhookが作成されました');
            setWebhookDialogOpen(false);
            resetWebhookForm();
            fetchWebhooks();
        } catch (err) {
            setError('Webhookの作成に失敗しました');
        }
    };

    const handleDeleteWebhook = async (id: number) => {
        if (!confirm('このWebhookを削除しますか？')) return;

        try {
            const response = await fetch(`/api/api-management/webhooks/${id}?companyId=${companyId}`, {
                method: 'DELETE',
                headers: { 'Authorization': `Bearer ${user.token}` }
            });

            if (!response.ok) throw new Error('Failed to delete webhook');
            setSuccess('Webhookを削除しました');
            fetchWebhooks();
        } catch (err) {
            setError('Webhookの削除に失敗しました');
        }
    };

    const handleTestWebhook = async (id: number) => {
        try {
            const response = await fetch(`/api/api-management/webhooks/${id}/test?companyId=${companyId}`, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${user.token}` }
            });

            const result = await response.json();
            if (result.success) {
                setSuccess('テストWebhookを送信しました');
            } else {
                setError(`Webhookテスト失敗: ${result.response}`);
            }
        } catch (err) {
            setError('Webhookテストに失敗しました');
        }
    };

    const copyToClipboard = (text: string) => {
        navigator.clipboard.writeText(text);
        setSuccess('クリップボードにコピーしました');
    };

    const resetKeyForm = () => {
        setKeyForm({
            keyName: '',
            scopes: ['read'],
            rateLimitPerMinute: 60,
            allowedIps: '',
            expiresAt: ''
        });
        setKeyDialogOpen(false);
    };

    const resetWebhookForm = () => {
        setWebhookForm({
            webhookName: '',
            webhookUrl: '',
            events: []
        });
    };

    return (
        <Container maxWidth="lg">
            <Box sx={{ my: 4 }}>
                <Typography variant="h4" component="h1" gutterBottom>
                    API連携設定
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                    外部システム（会計ソフト、ERPなど）との連携に使用するAPIキーとWebhookを管理します。
                </Typography>

                <Paper sx={{ mb: 3 }}>
                    <Tabs value={activeTab} onChange={(_, v) => setActiveTab(v)}>
                        <Tab icon={<KeyIcon />} label="APIキー" />
                        <Tab icon={<WebhookIcon />} label="Webhook" />
                        <Tab icon={<ChartIcon />} label="使用状況" />
                    </Tabs>
                </Paper>

                {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>{error}</Alert>}

                {loading ? (
                    <Box display="flex" justifyContent="center" py={4}>
                        <CircularProgress />
                    </Box>
                ) : (
                    <>
                        {/* API Keys Tab */}
                        {activeTab === 0 && (
                            <>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                                    <Typography variant="h6">APIキー一覧</Typography>
                                    <Button
                                        variant="contained"
                                        startIcon={<AddIcon />}
                                        onClick={() => setKeyDialogOpen(true)}
                                    >
                                        新規APIキー作成
                                    </Button>
                                </Box>

                                <TableContainer component={Paper}>
                                    <Table>
                                        <TableHead>
                                            <TableRow>
                                                <TableCell>名前</TableCell>
                                                <TableCell>キープレフィックス</TableCell>
                                                <TableCell>権限</TableCell>
                                                <TableCell>レート制限</TableCell>
                                                <TableCell>状態</TableCell>
                                                <TableCell>最終使用</TableCell>
                                                <TableCell>使用回数</TableCell>
                                                <TableCell align="right">操作</TableCell>
                                            </TableRow>
                                        </TableHead>
                                        <TableBody>
                                            {apiKeys.length === 0 ? (
                                                <TableRow>
                                                    <TableCell colSpan={8} align="center">
                                                        APIキーがありません。「新規APIキー作成」から作成してください。
                                                    </TableCell>
                                                </TableRow>
                                            ) : (
                                                apiKeys.map((key) => (
                                                    <TableRow key={key.id}>
                                                        <TableCell>{key.key_name}</TableCell>
                                                        <TableCell>
                                                            <code>{key.key_prefix}...</code>
                                                        </TableCell>
                                                        <TableCell>
                                                            {key.scopes.map(scope => (
                                                                <Chip
                                                                    key={scope}
                                                                    label={scope}
                                                                    size="small"
                                                                    sx={{ mr: 0.5 }}
                                                                />
                                                            ))}
                                                        </TableCell>
                                                        <TableCell>{key.rate_limit_per_minute}/分</TableCell>
                                                        <TableCell>
                                                            <Chip
                                                                label={key.is_active ? '有効' : '無効'}
                                                                color={key.is_active ? 'success' : 'default'}
                                                                size="small"
                                                            />
                                                        </TableCell>
                                                        <TableCell>
                                                            {key.last_used_at
                                                                ? new Date(key.last_used_at).toLocaleString('ja-JP')
                                                                : '-'
                                                            }
                                                        </TableCell>
                                                        <TableCell>{key.usage_count.toLocaleString()}</TableCell>
                                                        <TableCell align="right">
                                                            <Tooltip title={key.is_active ? '無効化' : '有効化'}>
                                                                <IconButton onClick={() => handleToggleKeyActive(key)}>
                                                                    {key.is_active ? <HideIcon /> : <ViewIcon />}
                                                                </IconButton>
                                                            </Tooltip>
                                                            <Tooltip title="再生成">
                                                                <IconButton onClick={() => handleRegenerateKey(key.id)}>
                                                                    <RefreshIcon />
                                                                </IconButton>
                                                            </Tooltip>
                                                            <Tooltip title="削除">
                                                                <IconButton onClick={() => handleDeleteKey(key.id)} color="error">
                                                                    <DeleteIcon />
                                                                </IconButton>
                                                            </Tooltip>
                                                        </TableCell>
                                                    </TableRow>
                                                ))
                                            )}
                                        </TableBody>
                                    </Table>
                                </TableContainer>

                                {/* API Documentation Link */}
                                <Card sx={{ mt: 3 }}>
                                    <CardContent>
                                        <Typography variant="h6" gutterBottom>APIドキュメント</Typography>
                                        <Typography variant="body2" color="text.secondary" paragraph>
                                            外部システムからAPIを呼び出す際は、リクエストヘッダーに<code>X-API-Key</code>を含めてください。
                                        </Typography>
                                        <Box sx={{ bgcolor: 'grey.100', p: 2, borderRadius: 1, mb: 2 }}>
                                            <Typography variant="body2" component="pre" sx={{ fontFamily: 'monospace' }}>
                                                {`curl -X GET "https://haisha-pro.com/api/v1/work-records" \\
  -H "X-API-Key: YOUR_API_KEY" \\
  -H "Content-Type: application/json"`}
                                            </Typography>
                                        </Box>
                                        <Typography variant="body2">
                                            利用可能なエンドポイント:
                                        </Typography>
                                        <Box component="ul" sx={{ mt: 1 }}>
                                            <li><code>GET /api/v1/work-records</code> - 日報データ</li>
                                            <li><code>GET /api/v1/tenko</code> - 点呼記録</li>
                                            <li><code>GET /api/v1/inspections</code> - 点検記録</li>
                                            <li><code>GET /api/v1/drivers</code> - 運転者情報</li>
                                            <li><code>GET /api/v1/vehicles</code> - 車両情報</li>
                                            <li><code>GET /api/v1/compliance/summary</code> - コンプライアンスサマリー</li>
                                            <li><code>GET /api/v1/compliance/alerts</code> - 期限アラート</li>
                                        </Box>
                                    </CardContent>
                                </Card>
                            </>
                        )}

                        {/* Webhooks Tab */}
                        {activeTab === 1 && (
                            <>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                                    <Typography variant="h6">Webhook一覧</Typography>
                                    <Button
                                        variant="contained"
                                        startIcon={<AddIcon />}
                                        onClick={() => setWebhookDialogOpen(true)}
                                    >
                                        新規Webhook作成
                                    </Button>
                                </Box>

                                <TableContainer component={Paper}>
                                    <Table>
                                        <TableHead>
                                            <TableRow>
                                                <TableCell>名前</TableCell>
                                                <TableCell>URL</TableCell>
                                                <TableCell>イベント</TableCell>
                                                <TableCell>状態</TableCell>
                                                <TableCell>最終発火</TableCell>
                                                <TableCell align="right">操作</TableCell>
                                            </TableRow>
                                        </TableHead>
                                        <TableBody>
                                            {webhooks.length === 0 ? (
                                                <TableRow>
                                                    <TableCell colSpan={6} align="center">
                                                        Webhookがありません。「新規Webhook作成」から作成してください。
                                                    </TableCell>
                                                </TableRow>
                                            ) : (
                                                webhooks.map((webhook) => (
                                                    <TableRow key={webhook.id}>
                                                        <TableCell>{webhook.webhook_name}</TableCell>
                                                        <TableCell>
                                                            <Typography
                                                                variant="body2"
                                                                sx={{
                                                                    maxWidth: 200,
                                                                    overflow: 'hidden',
                                                                    textOverflow: 'ellipsis',
                                                                    whiteSpace: 'nowrap'
                                                                }}
                                                            >
                                                                {webhook.webhook_url}
                                                            </Typography>
                                                        </TableCell>
                                                        <TableCell>
                                                            {webhook.events.length} イベント
                                                        </TableCell>
                                                        <TableCell>
                                                            <Chip
                                                                label={webhook.is_active ? '有効' : '無効'}
                                                                color={webhook.is_active ? 'success' : 'default'}
                                                                size="small"
                                                            />
                                                            {webhook.failure_count > 0 && (
                                                                <Chip
                                                                    label={`エラー: ${webhook.failure_count}`}
                                                                    color="error"
                                                                    size="small"
                                                                    sx={{ ml: 1 }}
                                                                />
                                                            )}
                                                        </TableCell>
                                                        <TableCell>
                                                            {webhook.last_triggered_at
                                                                ? new Date(webhook.last_triggered_at).toLocaleString('ja-JP')
                                                                : '-'
                                                            }
                                                        </TableCell>
                                                        <TableCell align="right">
                                                            <Tooltip title="テスト送信">
                                                                <IconButton onClick={() => handleTestWebhook(webhook.id)}>
                                                                    <TestIcon />
                                                                </IconButton>
                                                            </Tooltip>
                                                            <Tooltip title="削除">
                                                                <IconButton onClick={() => handleDeleteWebhook(webhook.id)} color="error">
                                                                    <DeleteIcon />
                                                                </IconButton>
                                                            </Tooltip>
                                                        </TableCell>
                                                    </TableRow>
                                                ))
                                            )}
                                        </TableBody>
                                    </Table>
                                </TableContainer>
                            </>
                        )}

                        {/* Usage Stats Tab */}
                        {activeTab === 2 && usageStats && (
                            <>
                                <Typography variant="h6" gutterBottom>API使用状況（過去30日）</Typography>

                                <Grid container spacing={3}>
                                    <Grid size={{ xs: 12, md: 6 }}>
                                        <Card>
                                            <CardContent>
                                                <Typography variant="subtitle1" gutterBottom>キー別使用状況</Typography>
                                                <TableContainer>
                                                    <Table size="small">
                                                        <TableHead>
                                                            <TableRow>
                                                                <TableCell>キー名</TableCell>
                                                                <TableCell align="right">リクエスト数</TableCell>
                                                                <TableCell align="right">成功率</TableCell>
                                                            </TableRow>
                                                        </TableHead>
                                                        <TableBody>
                                                            {usageStats.keyUsage.map((key) => (
                                                                <TableRow key={key.id}>
                                                                    <TableCell>{key.key_name}</TableCell>
                                                                    <TableCell align="right">{key.recent_requests}</TableCell>
                                                                    <TableCell align="right">
                                                                        {key.recent_requests > 0
                                                                            ? `${Math.round((key.successful_requests / key.recent_requests) * 100)}%`
                                                                            : '-'
                                                                        }
                                                                    </TableCell>
                                                                </TableRow>
                                                            ))}
                                                        </TableBody>
                                                    </Table>
                                                </TableContainer>
                                            </CardContent>
                                        </Card>
                                    </Grid>

                                    <Grid size={{ xs: 12, md: 6 }}>
                                        <Card>
                                            <CardContent>
                                                <Typography variant="subtitle1" gutterBottom>人気エンドポイント</Typography>
                                                <TableContainer>
                                                    <Table size="small">
                                                        <TableHead>
                                                            <TableRow>
                                                                <TableCell>エンドポイント</TableCell>
                                                                <TableCell align="right">リクエスト数</TableCell>
                                                                <TableCell align="right">平均応答時間</TableCell>
                                                            </TableRow>
                                                        </TableHead>
                                                        <TableBody>
                                                            {usageStats.topEndpoints.map((endpoint, index) => (
                                                                <TableRow key={index}>
                                                                    <TableCell>
                                                                        <code>{endpoint.method} {endpoint.endpoint}</code>
                                                                    </TableCell>
                                                                    <TableCell align="right">{endpoint.request_count}</TableCell>
                                                                    <TableCell align="right">
                                                                        {Math.round(endpoint.avg_response_time)}ms
                                                                    </TableCell>
                                                                </TableRow>
                                                            ))}
                                                        </TableBody>
                                                    </Table>
                                                </TableContainer>
                                            </CardContent>
                                        </Card>
                                    </Grid>
                                </Grid>
                            </>
                        )}
                    </>
                )}

                {/* Create API Key Dialog */}
                <Dialog open={keyDialogOpen} onClose={resetKeyForm} maxWidth="sm" fullWidth>
                    <DialogTitle>新規APIキー作成</DialogTitle>
                    <DialogContent>
                        <TextField
                            fullWidth
                            label="キー名"
                            value={keyForm.keyName}
                            onChange={(e) => setKeyForm({ ...keyForm, keyName: e.target.value })}
                            margin="normal"
                            placeholder="例: 会計システム連携用"
                        />

                        <FormControl fullWidth margin="normal">
                            <InputLabel>権限スコープ</InputLabel>
                            <Select
                                multiple
                                value={keyForm.scopes}
                                onChange={(e) => setKeyForm({ ...keyForm, scopes: e.target.value as string[] })}
                                label="権限スコープ"
                            >
                                {AVAILABLE_SCOPES.map((scope) => (
                                    <MenuItem key={scope.value} value={scope.value}>
                                        {scope.label} - {scope.description}
                                    </MenuItem>
                                ))}
                            </Select>
                        </FormControl>

                        <TextField
                            fullWidth
                            label="レート制限（リクエスト/分）"
                            type="number"
                            value={keyForm.rateLimitPerMinute}
                            onChange={(e) => setKeyForm({ ...keyForm, rateLimitPerMinute: parseInt(e.target.value) })}
                            margin="normal"
                        />

                        <TextField
                            fullWidth
                            label="許可IPアドレス（カンマ区切り、空欄で制限なし）"
                            value={keyForm.allowedIps}
                            onChange={(e) => setKeyForm({ ...keyForm, allowedIps: e.target.value })}
                            margin="normal"
                            placeholder="例: 192.168.1.1, 10.0.0.1"
                        />

                        <TextField
                            fullWidth
                            label="有効期限（空欄で無期限）"
                            type="date"
                            value={keyForm.expiresAt}
                            onChange={(e) => setKeyForm({ ...keyForm, expiresAt: e.target.value })}
                            margin="normal"
                            InputLabelProps={{ shrink: true }}
                        />
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={resetKeyForm}>キャンセル</Button>
                        <Button
                            onClick={handleCreateKey}
                            variant="contained"
                            disabled={!keyForm.keyName}
                        >
                            作成
                        </Button>
                    </DialogActions>
                </Dialog>

                {/* New Key Display Dialog */}
                <Dialog open={!!newKeyVisible} onClose={() => setNewKeyVisible(null)} maxWidth="sm" fullWidth>
                    <DialogTitle>APIキーが作成されました</DialogTitle>
                    <DialogContent>
                        <Alert severity="warning" sx={{ mb: 2 }}>
                            このAPIキーは一度だけ表示されます。安全な場所に保存してください。
                        </Alert>
                        <Box sx={{ bgcolor: 'grey.100', p: 2, borderRadius: 1, display: 'flex', alignItems: 'center' }}>
                            <Typography variant="body2" sx={{ fontFamily: 'monospace', flex: 1, wordBreak: 'break-all' }}>
                                {newKeyVisible}
                            </Typography>
                            <IconButton onClick={() => copyToClipboard(newKeyVisible || '')}>
                                <CopyIcon />
                            </IconButton>
                        </Box>
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => setNewKeyVisible(null)} variant="contained">
                            閉じる
                        </Button>
                    </DialogActions>
                </Dialog>

                {/* Create Webhook Dialog */}
                <Dialog open={webhookDialogOpen} onClose={() => { setWebhookDialogOpen(false); resetWebhookForm(); }} maxWidth="sm" fullWidth>
                    <DialogTitle>新規Webhook作成</DialogTitle>
                    <DialogContent>
                        <TextField
                            fullWidth
                            label="Webhook名"
                            value={webhookForm.webhookName}
                            onChange={(e) => setWebhookForm({ ...webhookForm, webhookName: e.target.value })}
                            margin="normal"
                            placeholder="例: Slack通知"
                        />

                        <TextField
                            fullWidth
                            label="Webhook URL"
                            value={webhookForm.webhookUrl}
                            onChange={(e) => setWebhookForm({ ...webhookForm, webhookUrl: e.target.value })}
                            margin="normal"
                            placeholder="https://example.com/webhook"
                        />

                        <FormControl fullWidth margin="normal">
                            <InputLabel>トリガーイベント</InputLabel>
                            <Select
                                multiple
                                value={webhookForm.events}
                                onChange={(e) => setWebhookForm({ ...webhookForm, events: e.target.value as string[] })}
                                label="トリガーイベント"
                            >
                                {AVAILABLE_EVENTS.map((event) => (
                                    <MenuItem key={event.value} value={event.value}>
                                        {event.label}
                                    </MenuItem>
                                ))}
                            </Select>
                        </FormControl>
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => { setWebhookDialogOpen(false); resetWebhookForm(); }}>キャンセル</Button>
                        <Button
                            onClick={handleCreateWebhook}
                            variant="contained"
                            disabled={!webhookForm.webhookName || !webhookForm.webhookUrl}
                        >
                            作成
                        </Button>
                    </DialogActions>
                </Dialog>

                {/* Success Snackbar */}
                <Snackbar
                    open={!!success}
                    autoHideDuration={3000}
                    onClose={() => setSuccess('')}
                    message={success}
                />
            </Box>
        </Container>
    );
}
