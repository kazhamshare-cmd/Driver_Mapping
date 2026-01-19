/**
 * デジタコ連携設定画面
 * Tachograph Integration Settings
 */

import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Button,
  Grid,
  TextField,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Switch,
  FormControlLabel,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  IconButton,
  Tabs,
  Tab,
  Alert,
  CircularProgress,
  Tooltip,
  Autocomplete,
  Divider,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Sync as SyncIcon,
  CheckCircle as CheckCircleIcon,
  Error as ErrorIcon,
  Settings as SettingsIcon,
  Link as LinkIcon,
  LinkOff as LinkOffIcon,
  History as HistoryIcon,
  Speed as SpeedIcon,
  LocationOn as LocationOnIcon,
  Refresh as RefreshIcon,
  PlayArrow as PlayArrowIcon,
} from '@mui/icons-material';
import axios from 'axios';

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;
  return (
    <div role="tabpanel" hidden={value !== index} {...other}>
      {value === index && <Box sx={{ py: 3 }}>{children}</Box>}
    </div>
  );
}

interface Provider {
  id: string;
  name: string;
  description: string;
  features: string[];
}

interface Integration {
  id: number;
  company_id: number;
  provider: string;
  provider_name: string;
  name: string;
  api_endpoint: string;
  sync_enabled: boolean;
  sync_interval_minutes: number;
  last_sync_at: string | null;
  last_sync_status: string | null;
  is_active: boolean;
  created_at: string;
}

interface DriverMapping {
  id: number;
  integration_id: number;
  driver_id: number | null;
  driver_name: string | null;
  external_driver_id: string;
  external_driver_code: string;
  external_driver_name: string;
  is_active: boolean;
}

interface VehicleMapping {
  id: number;
  integration_id: number;
  vehicle_id: number | null;
  vehicle_number: string | null;
  external_vehicle_id: string;
  external_vehicle_number: string;
  external_device_id: string;
  is_active: boolean;
}

interface SyncLog {
  id: number;
  integration_id: number;
  sync_type: string;
  sync_direction: string;
  status: string;
  records_processed: number;
  records_success: number;
  records_failed: number;
  error_message: string | null;
  started_at: string;
  completed_at: string | null;
}

const TachographIntegration: React.FC = () => {
  const [tabValue, setTabValue] = useState(0);
  const [providers, setProviders] = useState<Provider[]>([]);
  const [integrations, setIntegrations] = useState<Integration[]>([]);
  const [selectedIntegration, setSelectedIntegration] = useState<Integration | null>(null);
  const [driverMappings, setDriverMappings] = useState<DriverMapping[]>([]);
  const [vehicleMappings, setVehicleMappings] = useState<VehicleMapping[]>([]);
  const [syncLogs, setSyncLogs] = useState<SyncLog[]>([]);
  const [loading, setLoading] = useState(false);
  const [testing, setTesting] = useState(false);
  const [syncing, setSyncing] = useState(false);

  // Dialogs
  const [addDialogOpen, setAddDialogOpen] = useState(false);
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [mappingDialogOpen, setMappingDialogOpen] = useState(false);
  const [mappingType, setMappingType] = useState<'driver' | 'vehicle'>('driver');
  const [selectedMapping, setSelectedMapping] = useState<DriverMapping | VehicleMapping | null>(null);

  // Form data
  const [formData, setFormData] = useState({
    provider: '',
    name: '',
    api_endpoint: '',
    api_key: '',
    api_secret: '',
    username: '',
    password: '',
    itp_company_code: '',
    itp_terminal_id: '',
    pioneer_customer_code: '',
    pioneer_contract_id: '',
    yazaki_dealer_code: '',
    denso_account_id: '',
    sync_enabled: true,
    sync_interval_minutes: 60,
  });

  // Drivers and Vehicles for mapping
  const [drivers, setDrivers] = useState<Array<{ id: number; name: string }>>([]);
  const [vehicles, setVehicles] = useState<Array<{ id: number; vehicle_number: string }>>([]);

  const [testResult, setTestResult] = useState<{ success: boolean; message: string } | null>(null);
  const [alert, setAlert] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  useEffect(() => {
    fetchProviders();
    fetchIntegrations();
    fetchDriversAndVehicles();
  }, []);

  useEffect(() => {
    if (selectedIntegration) {
      fetchDriverMappings(selectedIntegration.id);
      fetchVehicleMappings(selectedIntegration.id);
      fetchSyncLogs(selectedIntegration.id);
    }
  }, [selectedIntegration]);

  const fetchProviders = async () => {
    try {
      const response = await axios.get('/api/tachograph-integration/providers');
      setProviders(response.data);
    } catch (error) {
      console.error('Failed to fetch providers:', error);
    }
  };

  const fetchIntegrations = async () => {
    setLoading(true);
    try {
      const response = await axios.get('/api/tachograph-integration/integrations');
      setIntegrations(response.data);
      if (response.data.length > 0 && !selectedIntegration) {
        setSelectedIntegration(response.data[0]);
      }
    } catch (error) {
      console.error('Failed to fetch integrations:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchDriversAndVehicles = async () => {
    try {
      const [driversRes, vehiclesRes] = await Promise.all([
        axios.get('/api/drivers'),
        axios.get('/api/vehicles'),
      ]);
      setDrivers(driversRes.data);
      setVehicles(vehiclesRes.data);
    } catch (error) {
      console.error('Failed to fetch drivers/vehicles:', error);
    }
  };

  const fetchDriverMappings = async (integrationId: number) => {
    try {
      const response = await axios.get(`/api/tachograph-integration/integrations/${integrationId}/driver-mappings`);
      setDriverMappings(response.data);
    } catch (error) {
      console.error('Failed to fetch driver mappings:', error);
    }
  };

  const fetchVehicleMappings = async (integrationId: number) => {
    try {
      const response = await axios.get(`/api/tachograph-integration/integrations/${integrationId}/vehicle-mappings`);
      setVehicleMappings(response.data);
    } catch (error) {
      console.error('Failed to fetch vehicle mappings:', error);
    }
  };

  const fetchSyncLogs = async (integrationId: number) => {
    try {
      const response = await axios.get(`/api/tachograph-integration/integrations/${integrationId}/sync-logs`);
      setSyncLogs(response.data);
    } catch (error) {
      console.error('Failed to fetch sync logs:', error);
    }
  };

  const handleAddIntegration = async () => {
    try {
      await axios.post('/api/tachograph-integration/integrations', formData);
      setAddDialogOpen(false);
      resetFormData();
      fetchIntegrations();
      setAlert({ type: 'success', message: '連携設定を追加しました' });
    } catch (error) {
      console.error('Failed to add integration:', error);
      setAlert({ type: 'error', message: '連携設定の追加に失敗しました' });
    }
  };

  const handleUpdateIntegration = async () => {
    if (!selectedIntegration) return;
    try {
      await axios.put(`/api/tachograph-integration/integrations/${selectedIntegration.id}`, formData);
      setEditDialogOpen(false);
      fetchIntegrations();
      setAlert({ type: 'success', message: '連携設定を更新しました' });
    } catch (error) {
      console.error('Failed to update integration:', error);
      setAlert({ type: 'error', message: '連携設定の更新に失敗しました' });
    }
  };

  const handleTestConnection = async () => {
    if (!selectedIntegration) return;
    setTesting(true);
    setTestResult(null);
    try {
      const response = await axios.post(`/api/tachograph-integration/integrations/${selectedIntegration.id}/test`);
      setTestResult(response.data);
    } catch (error: any) {
      setTestResult({ success: false, message: error.response?.data?.message || '接続テストに失敗しました' });
    } finally {
      setTesting(false);
    }
  };

  const handleTriggerSync = async () => {
    if (!selectedIntegration) return;
    setSyncing(true);
    try {
      await axios.post(`/api/tachograph-integration/integrations/${selectedIntegration.id}/sync`);
      fetchSyncLogs(selectedIntegration.id);
      setAlert({ type: 'success', message: '同期を開始しました' });
    } catch (error) {
      console.error('Failed to trigger sync:', error);
      setAlert({ type: 'error', message: '同期の開始に失敗しました' });
    } finally {
      setSyncing(false);
    }
  };

  const handleUpdateMapping = async () => {
    if (!selectedIntegration || !selectedMapping) return;
    try {
      const endpoint = mappingType === 'driver'
        ? `/api/tachograph-integration/integrations/${selectedIntegration.id}/driver-mappings/${selectedMapping.id}`
        : `/api/tachograph-integration/integrations/${selectedIntegration.id}/vehicle-mappings/${selectedMapping.id}`;

      const data = mappingType === 'driver'
        ? { driver_id: (selectedMapping as DriverMapping).driver_id }
        : { vehicle_id: (selectedMapping as VehicleMapping).vehicle_id };

      await axios.put(endpoint, data);
      setMappingDialogOpen(false);

      if (mappingType === 'driver') {
        fetchDriverMappings(selectedIntegration.id);
      } else {
        fetchVehicleMappings(selectedIntegration.id);
      }
      setAlert({ type: 'success', message: 'マッピングを更新しました' });
    } catch (error) {
      console.error('Failed to update mapping:', error);
      setAlert({ type: 'error', message: 'マッピングの更新に失敗しました' });
    }
  };

  const resetFormData = () => {
    setFormData({
      provider: '',
      name: '',
      api_endpoint: '',
      api_key: '',
      api_secret: '',
      username: '',
      password: '',
      itp_company_code: '',
      itp_terminal_id: '',
      pioneer_customer_code: '',
      pioneer_contract_id: '',
      yazaki_dealer_code: '',
      denso_account_id: '',
      sync_enabled: true,
      sync_interval_minutes: 60,
    });
  };

  const openEditDialog = () => {
    if (!selectedIntegration) return;
    setFormData({
      provider: selectedIntegration.provider,
      name: selectedIntegration.name,
      api_endpoint: selectedIntegration.api_endpoint,
      api_key: '',
      api_secret: '',
      username: '',
      password: '',
      itp_company_code: '',
      itp_terminal_id: '',
      pioneer_customer_code: '',
      pioneer_contract_id: '',
      yazaki_dealer_code: '',
      denso_account_id: '',
      sync_enabled: selectedIntegration.sync_enabled,
      sync_interval_minutes: selectedIntegration.sync_interval_minutes,
    });
    setEditDialogOpen(true);
  };

  const getProviderFields = (provider: string) => {
    switch (provider) {
      case 'fujitsu_itp':
        return ['api_endpoint', 'username', 'password', 'itp_company_code', 'itp_terminal_id'];
      case 'pioneer_vehicle_assist':
        return ['api_endpoint', 'api_key', 'api_secret', 'pioneer_customer_code', 'pioneer_contract_id'];
      case 'yazaki':
        return ['api_endpoint', 'api_key', 'yazaki_dealer_code'];
      case 'denso':
        return ['api_endpoint', 'api_key', 'api_secret', 'denso_account_id'];
      default:
        return ['api_endpoint', 'api_key', 'api_secret'];
    }
  };

  const getStatusColor = (status: string | null) => {
    switch (status) {
      case 'completed':
        return 'success';
      case 'failed':
        return 'error';
      case 'running':
        return 'warning';
      default:
        return 'default';
    }
  };

  const getSyncTypeLabel = (type: string) => {
    switch (type) {
      case 'import_records':
        return '運行データ取込';
      case 'sync_master':
        return 'マスタ同期';
      case 'export_instruction':
        return '運行指示送信';
      case 'location_sync':
        return '位置情報同期';
      default:
        return type;
    }
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        デジタコ連携設定
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        各社デジタコシステムとのAPI連携設定を管理します
      </Typography>

      {alert && (
        <Alert severity={alert.type} sx={{ mb: 2 }} onClose={() => setAlert(null)}>
          {alert.message}
        </Alert>
      )}

      <Grid container spacing={3}>
        {/* 連携一覧 */}
        <Grid size={{ xs: 12, md: 4 }}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                <Typography variant="h6">連携設定</Typography>
                <Button
                  variant="contained"
                  startIcon={<AddIcon />}
                  size="small"
                  onClick={() => setAddDialogOpen(true)}
                >
                  追加
                </Button>
              </Box>

              {loading ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', py: 3 }}>
                  <CircularProgress />
                </Box>
              ) : integrations.length === 0 ? (
                <Typography color="text.secondary" align="center">
                  連携設定がありません
                </Typography>
              ) : (
                integrations.map((integration) => (
                  <Card
                    key={integration.id}
                    variant="outlined"
                    sx={{
                      mb: 1,
                      cursor: 'pointer',
                      bgcolor: selectedIntegration?.id === integration.id ? 'action.selected' : 'background.paper',
                    }}
                    onClick={() => setSelectedIntegration(integration)}
                  >
                    <CardContent sx={{ py: 1.5, '&:last-child': { pb: 1.5 } }}>
                      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <Box>
                          <Typography variant="subtitle2">{integration.name}</Typography>
                          <Typography variant="caption" color="text.secondary">
                            {integration.provider_name}
                          </Typography>
                        </Box>
                        <Chip
                          size="small"
                          icon={integration.sync_enabled ? <CheckCircleIcon /> : <ErrorIcon />}
                          label={integration.sync_enabled ? '有効' : '無効'}
                          color={integration.sync_enabled ? 'success' : 'default'}
                        />
                      </Box>
                    </CardContent>
                  </Card>
                ))
              )}
            </CardContent>
          </Card>
        </Grid>

        {/* 詳細設定 */}
        <Grid size={{ xs: 12, md: 8 }}>
          {selectedIntegration ? (
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                  <Typography variant="h6">{selectedIntegration.name}</Typography>
                  <Box>
                    <Button
                      variant="outlined"
                      startIcon={testing ? <CircularProgress size={16} /> : <LinkIcon />}
                      size="small"
                      onClick={handleTestConnection}
                      disabled={testing}
                      sx={{ mr: 1 }}
                    >
                      接続テスト
                    </Button>
                    <Button
                      variant="outlined"
                      startIcon={syncing ? <CircularProgress size={16} /> : <SyncIcon />}
                      size="small"
                      onClick={handleTriggerSync}
                      disabled={syncing}
                      sx={{ mr: 1 }}
                    >
                      手動同期
                    </Button>
                    <IconButton size="small" onClick={openEditDialog}>
                      <SettingsIcon />
                    </IconButton>
                  </Box>
                </Box>

                {testResult && (
                  <Alert severity={testResult.success ? 'success' : 'error'} sx={{ mb: 2 }}>
                    {testResult.message}
                  </Alert>
                )}

                <Grid container spacing={2} sx={{ mb: 2 }}>
                  <Grid size={{ xs: 6, sm: 3 }}>
                    <Typography variant="caption" color="text.secondary">プロバイダー</Typography>
                    <Typography variant="body2">{selectedIntegration.provider_name}</Typography>
                  </Grid>
                  <Grid size={{ xs: 6, sm: 3 }}>
                    <Typography variant="caption" color="text.secondary">同期間隔</Typography>
                    <Typography variant="body2">{selectedIntegration.sync_interval_minutes}分</Typography>
                  </Grid>
                  <Grid size={{ xs: 6, sm: 3 }}>
                    <Typography variant="caption" color="text.secondary">最終同期</Typography>
                    <Typography variant="body2">
                      {selectedIntegration.last_sync_at
                        ? new Date(selectedIntegration.last_sync_at).toLocaleString('ja-JP')
                        : '未実行'}
                    </Typography>
                  </Grid>
                  <Grid size={{ xs: 6, sm: 3 }}>
                    <Typography variant="caption" color="text.secondary">同期状態</Typography>
                    <Chip
                      size="small"
                      label={selectedIntegration.last_sync_status || '未実行'}
                      color={getStatusColor(selectedIntegration.last_sync_status) as any}
                    />
                  </Grid>
                </Grid>

                <Divider sx={{ my: 2 }} />

                <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)}>
                  <Tab label="ドライバーマッピング" icon={<LinkIcon />} iconPosition="start" />
                  <Tab label="車両マッピング" icon={<SpeedIcon />} iconPosition="start" />
                  <Tab label="同期ログ" icon={<HistoryIcon />} iconPosition="start" />
                </Tabs>

                <TabPanel value={tabValue} index={0}>
                  <TableContainer component={Paper} variant="outlined">
                    <Table size="small">
                      <TableHead>
                        <TableRow>
                          <TableCell>外部コード</TableCell>
                          <TableCell>外部名称</TableCell>
                          <TableCell>マッピング先</TableCell>
                          <TableCell>状態</TableCell>
                          <TableCell align="right">操作</TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {driverMappings.length === 0 ? (
                          <TableRow>
                            <TableCell colSpan={5} align="center">
                              マッピングデータがありません
                            </TableCell>
                          </TableRow>
                        ) : (
                          driverMappings.map((mapping) => (
                            <TableRow key={mapping.id}>
                              <TableCell>{mapping.external_driver_code}</TableCell>
                              <TableCell>{mapping.external_driver_name}</TableCell>
                              <TableCell>
                                {mapping.driver_name || (
                                  <Chip size="small" label="未設定" color="warning" />
                                )}
                              </TableCell>
                              <TableCell>
                                <Chip
                                  size="small"
                                  icon={mapping.driver_id ? <LinkIcon /> : <LinkOffIcon />}
                                  label={mapping.driver_id ? 'リンク済' : '未リンク'}
                                  color={mapping.driver_id ? 'success' : 'default'}
                                />
                              </TableCell>
                              <TableCell align="right">
                                <IconButton
                                  size="small"
                                  onClick={() => {
                                    setMappingType('driver');
                                    setSelectedMapping(mapping);
                                    setMappingDialogOpen(true);
                                  }}
                                >
                                  <EditIcon fontSize="small" />
                                </IconButton>
                              </TableCell>
                            </TableRow>
                          ))
                        )}
                      </TableBody>
                    </Table>
                  </TableContainer>
                </TabPanel>

                <TabPanel value={tabValue} index={1}>
                  <TableContainer component={Paper} variant="outlined">
                    <Table size="small">
                      <TableHead>
                        <TableRow>
                          <TableCell>外部車両番号</TableCell>
                          <TableCell>デバイスID</TableCell>
                          <TableCell>マッピング先</TableCell>
                          <TableCell>状態</TableCell>
                          <TableCell align="right">操作</TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {vehicleMappings.length === 0 ? (
                          <TableRow>
                            <TableCell colSpan={5} align="center">
                              マッピングデータがありません
                            </TableCell>
                          </TableRow>
                        ) : (
                          vehicleMappings.map((mapping) => (
                            <TableRow key={mapping.id}>
                              <TableCell>{mapping.external_vehicle_number}</TableCell>
                              <TableCell>{mapping.external_device_id}</TableCell>
                              <TableCell>
                                {mapping.vehicle_number || (
                                  <Chip size="small" label="未設定" color="warning" />
                                )}
                              </TableCell>
                              <TableCell>
                                <Chip
                                  size="small"
                                  icon={mapping.vehicle_id ? <LinkIcon /> : <LinkOffIcon />}
                                  label={mapping.vehicle_id ? 'リンク済' : '未リンク'}
                                  color={mapping.vehicle_id ? 'success' : 'default'}
                                />
                              </TableCell>
                              <TableCell align="right">
                                <IconButton
                                  size="small"
                                  onClick={() => {
                                    setMappingType('vehicle');
                                    setSelectedMapping(mapping);
                                    setMappingDialogOpen(true);
                                  }}
                                >
                                  <EditIcon fontSize="small" />
                                </IconButton>
                              </TableCell>
                            </TableRow>
                          ))
                        )}
                      </TableBody>
                    </Table>
                  </TableContainer>
                </TabPanel>

                <TabPanel value={tabValue} index={2}>
                  <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
                    <Button
                      startIcon={<RefreshIcon />}
                      size="small"
                      onClick={() => fetchSyncLogs(selectedIntegration.id)}
                    >
                      更新
                    </Button>
                  </Box>
                  <TableContainer component={Paper} variant="outlined">
                    <Table size="small">
                      <TableHead>
                        <TableRow>
                          <TableCell>日時</TableCell>
                          <TableCell>種別</TableCell>
                          <TableCell>状態</TableCell>
                          <TableCell align="right">処理件数</TableCell>
                          <TableCell align="right">成功</TableCell>
                          <TableCell align="right">失敗</TableCell>
                          <TableCell>エラー</TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {syncLogs.length === 0 ? (
                          <TableRow>
                            <TableCell colSpan={7} align="center">
                              同期ログがありません
                            </TableCell>
                          </TableRow>
                        ) : (
                          syncLogs.map((log) => (
                            <TableRow key={log.id}>
                              <TableCell>
                                {new Date(log.started_at).toLocaleString('ja-JP')}
                              </TableCell>
                              <TableCell>{getSyncTypeLabel(log.sync_type)}</TableCell>
                              <TableCell>
                                <Chip
                                  size="small"
                                  label={log.status}
                                  color={getStatusColor(log.status) as any}
                                />
                              </TableCell>
                              <TableCell align="right">{log.records_processed}</TableCell>
                              <TableCell align="right">{log.records_success}</TableCell>
                              <TableCell align="right">{log.records_failed}</TableCell>
                              <TableCell>
                                {log.error_message && (
                                  <Tooltip title={log.error_message}>
                                    <ErrorIcon color="error" fontSize="small" />
                                  </Tooltip>
                                )}
                              </TableCell>
                            </TableRow>
                          ))
                        )}
                      </TableBody>
                    </Table>
                  </TableContainer>
                </TabPanel>
              </CardContent>
            </Card>
          ) : (
            <Card>
              <CardContent>
                <Typography color="text.secondary" align="center">
                  左のリストから連携設定を選択してください
                </Typography>
              </CardContent>
            </Card>
          )}
        </Grid>
      </Grid>

      {/* 追加ダイアログ */}
      <Dialog open={addDialogOpen} onClose={() => setAddDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>連携設定の追加</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid size={{ xs: 12 }}>
              <FormControl fullWidth>
                <InputLabel>プロバイダー</InputLabel>
                <Select
                  value={formData.provider}
                  label="プロバイダー"
                  onChange={(e) => setFormData({ ...formData, provider: e.target.value })}
                >
                  {providers.map((provider) => (
                    <MenuItem key={provider.id} value={provider.id}>
                      {provider.name}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid size={{ xs: 12 }}>
              <TextField
                fullWidth
                label="連携名"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              />
            </Grid>

            {formData.provider && getProviderFields(formData.provider).map((field) => (
              <Grid size={{ xs: 12 }} key={field}>
                <TextField
                  fullWidth
                  label={
                    field === 'api_endpoint' ? 'APIエンドポイント' :
                    field === 'api_key' ? 'APIキー' :
                    field === 'api_secret' ? 'APIシークレット' :
                    field === 'username' ? 'ユーザー名' :
                    field === 'password' ? 'パスワード' :
                    field === 'itp_company_code' ? '企業コード' :
                    field === 'itp_terminal_id' ? '端末ID' :
                    field === 'pioneer_customer_code' ? '顧客コード' :
                    field === 'pioneer_contract_id' ? '契約ID' :
                    field === 'yazaki_dealer_code' ? '代理店コード' :
                    field === 'denso_account_id' ? 'アカウントID' : field
                  }
                  type={['password', 'api_secret'].includes(field) ? 'password' : 'text'}
                  value={(formData as any)[field]}
                  onChange={(e) => setFormData({ ...formData, [field]: e.target.value })}
                />
              </Grid>
            ))}

            <Grid size={{ xs: 12, sm: 6 }}>
              <FormControlLabel
                control={
                  <Switch
                    checked={formData.sync_enabled}
                    onChange={(e) => setFormData({ ...formData, sync_enabled: e.target.checked })}
                  />
                }
                label="自動同期を有効にする"
              />
            </Grid>
            <Grid size={{ xs: 12, sm: 6 }}>
              <TextField
                fullWidth
                type="number"
                label="同期間隔（分）"
                value={formData.sync_interval_minutes}
                onChange={(e) => setFormData({ ...formData, sync_interval_minutes: parseInt(e.target.value) })}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setAddDialogOpen(false)}>キャンセル</Button>
          <Button variant="contained" onClick={handleAddIntegration}>追加</Button>
        </DialogActions>
      </Dialog>

      {/* 編集ダイアログ */}
      <Dialog open={editDialogOpen} onClose={() => setEditDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>連携設定の編集</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid size={{ xs: 12 }}>
              <TextField
                fullWidth
                label="連携名"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 12 }}>
              <TextField
                fullWidth
                label="APIエンドポイント"
                value={formData.api_endpoint}
                onChange={(e) => setFormData({ ...formData, api_endpoint: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 12, sm: 6 }}>
              <FormControlLabel
                control={
                  <Switch
                    checked={formData.sync_enabled}
                    onChange={(e) => setFormData({ ...formData, sync_enabled: e.target.checked })}
                  />
                }
                label="自動同期を有効にする"
              />
            </Grid>
            <Grid size={{ xs: 12, sm: 6 }}>
              <TextField
                fullWidth
                type="number"
                label="同期間隔（分）"
                value={formData.sync_interval_minutes}
                onChange={(e) => setFormData({ ...formData, sync_interval_minutes: parseInt(e.target.value) })}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditDialogOpen(false)}>キャンセル</Button>
          <Button variant="contained" onClick={handleUpdateIntegration}>更新</Button>
        </DialogActions>
      </Dialog>

      {/* マッピング編集ダイアログ */}
      <Dialog open={mappingDialogOpen} onClose={() => setMappingDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {mappingType === 'driver' ? 'ドライバーマッピングの編集' : '車両マッピングの編集'}
        </DialogTitle>
        <DialogContent>
          {selectedMapping && (
            <Grid container spacing={2} sx={{ mt: 1 }}>
              <Grid size={{ xs: 12 }}>
                <Typography variant="caption" color="text.secondary">外部システム情報</Typography>
                <Typography variant="body2">
                  {mappingType === 'driver'
                    ? `${(selectedMapping as DriverMapping).external_driver_code} - ${(selectedMapping as DriverMapping).external_driver_name}`
                    : `${(selectedMapping as VehicleMapping).external_vehicle_number} (${(selectedMapping as VehicleMapping).external_device_id})`
                  }
                </Typography>
              </Grid>
              <Grid size={{ xs: 12 }}>
                {mappingType === 'driver' ? (
                  <Autocomplete
                    options={drivers}
                    getOptionLabel={(option) => option.name}
                    value={drivers.find(d => d.id === (selectedMapping as DriverMapping).driver_id) || null}
                    onChange={(_, value) => {
                      setSelectedMapping({
                        ...selectedMapping,
                        driver_id: value?.id || null,
                      } as DriverMapping);
                    }}
                    renderInput={(params) => <TextField {...params} label="マッピング先ドライバー" />}
                  />
                ) : (
                  <Autocomplete
                    options={vehicles}
                    getOptionLabel={(option) => option.vehicle_number}
                    value={vehicles.find(v => v.id === (selectedMapping as VehicleMapping).vehicle_id) || null}
                    onChange={(_, value) => {
                      setSelectedMapping({
                        ...selectedMapping,
                        vehicle_id: value?.id || null,
                      } as VehicleMapping);
                    }}
                    renderInput={(params) => <TextField {...params} label="マッピング先車両" />}
                  />
                )}
              </Grid>
            </Grid>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setMappingDialogOpen(false)}>キャンセル</Button>
          <Button variant="contained" onClick={handleUpdateMapping}>更新</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default TachographIntegration;
