/**
 * トレーラー管理画面
 * Trailer Management (Tractor Heads & Chassis)
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
  Tooltip,
  FormControlLabel,
  Switch,
  Autocomplete,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Link as LinkIcon,
  LinkOff as LinkOffIcon,
  LocalShipping as TruckIcon,
  ViewModule as ChassisIcon,
  History as HistoryIcon,
  CalendarMonth as ScheduleIcon,
  Refresh as RefreshIcon,
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

interface TractorHead {
  id: number;
  tractor_number: string;
  chassis_type: string;
  fifth_wheel_height: number;
  max_towing_weight: number;
  coupling_type: string;
  status: string;
  current_chassis_number: string | null;
  notes: string;
}

interface Chassis {
  id: number;
  chassis_number: string;
  chassis_type: string;
  length_feet: number;
  max_payload_weight: number;
  tare_weight: number;
  axle_count: number;
  is_owned: boolean;
  lease_company: string | null;
  inspection_expiry: string;
  status: string;
  current_location: string;
  current_tractor_number: string | null;
  notes: string;
}

interface CouplingRecord {
  id: number;
  tractor_number: string;
  chassis_number: string;
  driver_name: string;
  action_type: string;
  action_datetime: string;
  location: string;
  seal_number: string;
  inspection_done: boolean;
}

const chassisTypes = [
  { value: 'dry_van', label: 'ドライバン' },
  { value: 'reefer', label: '冷凍・冷蔵' },
  { value: 'flatbed', label: '平床' },
  { value: 'tank', label: 'タンク' },
  { value: 'container_chassis', label: 'コンテナシャーシ' },
  { value: 'lowboy', label: 'ローボーイ' },
];

const statusColors: Record<string, 'success' | 'warning' | 'error' | 'default'> = {
  available: 'success',
  in_use: 'warning',
  maintenance: 'error',
  repair: 'error',
  inactive: 'default',
};

const statusLabels: Record<string, string> = {
  available: '空車',
  in_use: '使用中',
  maintenance: '整備中',
  repair: '修理中',
  inactive: '非稼働',
};

const TrailerManagement: React.FC = () => {
  const [tabValue, setTabValue] = useState(0);
  const [tractorHeads, setTractorHeads] = useState<TractorHead[]>([]);
  const [chassisList, setChassisList] = useState<Chassis[]>([]);
  const [couplingRecords, setCouplingRecords] = useState<CouplingRecord[]>([]);
  const [loading, setLoading] = useState(false);

  // Dialogs
  const [tractorDialogOpen, setTractorDialogOpen] = useState(false);
  const [chassisDialogOpen, setChassisDialogOpen] = useState(false);
  const [coupleDialogOpen, setCoupleDialogOpen] = useState(false);
  const [isEditing, setIsEditing] = useState(false);

  // Form data
  const [tractorForm, setTractorForm] = useState({
    id: 0,
    tractor_number: '',
    chassis_type: '',
    fifth_wheel_height: '',
    max_towing_weight: '',
    coupling_type: '',
    status: 'available',
    notes: '',
  });

  const [chassisForm, setChassisForm] = useState({
    id: 0,
    chassis_number: '',
    chassis_type: '',
    length_feet: '',
    max_payload_weight: '',
    tare_weight: '',
    axle_count: '2',
    is_owned: true,
    lease_company: '',
    inspection_expiry: '',
    current_location: '',
    status: 'available',
    notes: '',
  });

  const [coupleForm, setCoupleForm] = useState({
    tractor_id: null as number | null,
    chassis_id: null as number | null,
    action_type: 'couple',
    location: '',
    seal_number: '',
    inspection_done: false,
  });

  const [alert, setAlert] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const companyId = user.companyId || 1;

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [tractorsRes, chassisRes, recordsRes] = await Promise.all([
        axios.get(`/api/trailers/tractors?companyId=${companyId}`),
        axios.get(`/api/trailers/chassis?companyId=${companyId}`),
        axios.get(`/api/trailers/coupling-records?companyId=${companyId}`),
      ]);
      setTractorHeads(tractorsRes.data);
      setChassisList(chassisRes.data);
      setCouplingRecords(recordsRes.data);
    } catch (error) {
      console.error('Failed to fetch data:', error);
    } finally {
      setLoading(false);
    }
  };

  // トラクタヘッド保存
  const handleSaveTractor = async () => {
    try {
      const data = {
        ...tractorForm,
        company_id: companyId,
        fifth_wheel_height: tractorForm.fifth_wheel_height ? parseInt(tractorForm.fifth_wheel_height) : null,
        max_towing_weight: tractorForm.max_towing_weight ? parseInt(tractorForm.max_towing_weight) : null,
      };

      if (isEditing) {
        await axios.put(`/api/trailers/tractors/${tractorForm.id}`, data);
      } else {
        await axios.post('/api/trailers/tractors', data);
      }

      setTractorDialogOpen(false);
      fetchData();
      setAlert({ type: 'success', message: 'トラクタヘッドを保存しました' });
    } catch (error) {
      console.error('Failed to save tractor:', error);
      setAlert({ type: 'error', message: '保存に失敗しました' });
    }
  };

  // シャーシ保存
  const handleSaveChassis = async () => {
    try {
      const data = {
        ...chassisForm,
        company_id: companyId,
        length_feet: chassisForm.length_feet ? parseInt(chassisForm.length_feet) : null,
        max_payload_weight: chassisForm.max_payload_weight ? parseInt(chassisForm.max_payload_weight) : null,
        tare_weight: chassisForm.tare_weight ? parseInt(chassisForm.tare_weight) : null,
        axle_count: parseInt(chassisForm.axle_count),
      };

      if (isEditing) {
        await axios.put(`/api/trailers/chassis/${chassisForm.id}`, data);
      } else {
        await axios.post('/api/trailers/chassis', data);
      }

      setChassisDialogOpen(false);
      fetchData();
      setAlert({ type: 'success', message: 'シャーシを保存しました' });
    } catch (error) {
      console.error('Failed to save chassis:', error);
      setAlert({ type: 'error', message: '保存に失敗しました' });
    }
  };

  // 連結・連結解除
  const handleCoupling = async () => {
    try {
      const endpoint = coupleForm.action_type === 'couple' ? '/api/trailers/couple' : '/api/trailers/uncouple';
      await axios.post(endpoint, {
        company_id: companyId,
        tractor_id: coupleForm.tractor_id,
        chassis_id: coupleForm.chassis_id,
        driver_id: user.id,
        action_datetime: new Date().toISOString(),
        location: coupleForm.location,
        seal_number: coupleForm.seal_number,
        inspection_done: coupleForm.inspection_done,
      });

      setCoupleDialogOpen(false);
      fetchData();
      setAlert({
        type: 'success',
        message: coupleForm.action_type === 'couple' ? '連結しました' : '連結解除しました',
      });
    } catch (error) {
      console.error('Failed to couple/uncouple:', error);
      setAlert({ type: 'error', message: '処理に失敗しました' });
    }
  };

  const openNewTractorDialog = () => {
    setTractorForm({
      id: 0,
      tractor_number: '',
      chassis_type: '',
      fifth_wheel_height: '',
      max_towing_weight: '',
      coupling_type: '',
      status: 'available',
      notes: '',
    });
    setIsEditing(false);
    setTractorDialogOpen(true);
  };

  const openEditTractorDialog = (tractor: TractorHead) => {
    setTractorForm({
      id: tractor.id,
      tractor_number: tractor.tractor_number,
      chassis_type: tractor.chassis_type || '',
      fifth_wheel_height: tractor.fifth_wheel_height?.toString() || '',
      max_towing_weight: tractor.max_towing_weight?.toString() || '',
      coupling_type: tractor.coupling_type || '',
      status: tractor.status,
      notes: tractor.notes || '',
    });
    setIsEditing(true);
    setTractorDialogOpen(true);
  };

  const openNewChassisDialog = () => {
    setChassisForm({
      id: 0,
      chassis_number: '',
      chassis_type: '',
      length_feet: '',
      max_payload_weight: '',
      tare_weight: '',
      axle_count: '2',
      is_owned: true,
      lease_company: '',
      inspection_expiry: '',
      current_location: '',
      status: 'available',
      notes: '',
    });
    setIsEditing(false);
    setChassisDialogOpen(true);
  };

  const openEditChassisDialog = (chassis: Chassis) => {
    setChassisForm({
      id: chassis.id,
      chassis_number: chassis.chassis_number,
      chassis_type: chassis.chassis_type,
      length_feet: chassis.length_feet?.toString() || '',
      max_payload_weight: chassis.max_payload_weight?.toString() || '',
      tare_weight: chassis.tare_weight?.toString() || '',
      axle_count: chassis.axle_count?.toString() || '2',
      is_owned: chassis.is_owned,
      lease_company: chassis.lease_company || '',
      inspection_expiry: chassis.inspection_expiry?.split('T')[0] || '',
      current_location: chassis.current_location || '',
      status: chassis.status,
      notes: chassis.notes || '',
    });
    setIsEditing(true);
    setChassisDialogOpen(true);
  };

  const availableTractors = tractorHeads.filter((t) => t.status === 'available' && !t.current_chassis_number);
  const availableChassis = chassisList.filter((c) => c.status === 'available' && !c.current_tractor_number);
  const coupledPairs = tractorHeads.filter((t) => t.current_chassis_number);

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        トレーラー管理
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        トラクタヘッド・シャーシの管理と連結記録
      </Typography>

      {alert && (
        <Alert severity={alert.type} sx={{ mb: 2 }} onClose={() => setAlert(null)}>
          {alert.message}
        </Alert>
      )}

      {/* サマリーカード */}
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid size={{ xs: 6, sm: 3 }}>
          <Card>
            <CardContent>
              <Typography variant="subtitle2" color="text.secondary">
                トラクタヘッド
              </Typography>
              <Typography variant="h4">{tractorHeads.length}</Typography>
              <Chip
                size="small"
                label={`空車: ${availableTractors.length}`}
                color="success"
                sx={{ mt: 1 }}
              />
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 6, sm: 3 }}>
          <Card>
            <CardContent>
              <Typography variant="subtitle2" color="text.secondary">
                シャーシ
              </Typography>
              <Typography variant="h4">{chassisList.length}</Typography>
              <Chip
                size="small"
                label={`空車: ${availableChassis.length}`}
                color="success"
                sx={{ mt: 1 }}
              />
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 6, sm: 3 }}>
          <Card>
            <CardContent>
              <Typography variant="subtitle2" color="text.secondary">
                連結中
              </Typography>
              <Typography variant="h4">{coupledPairs.length}</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 6, sm: 3 }}>
          <Card sx={{ bgcolor: 'primary.main', color: 'white' }}>
            <CardContent>
              <Button
                fullWidth
                variant="contained"
                color="inherit"
                startIcon={<LinkIcon />}
                onClick={() => setCoupleDialogOpen(true)}
                sx={{ color: 'primary.main' }}
              >
                連結・解除
              </Button>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Card>
        <CardContent>
          <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)}>
            <Tab label="トラクタヘッド" icon={<TruckIcon />} iconPosition="start" />
            <Tab label="シャーシ" icon={<ChassisIcon />} iconPosition="start" />
            <Tab label="連結記録" icon={<HistoryIcon />} iconPosition="start" />
          </Tabs>

          {/* トラクタヘッド一覧 */}
          <TabPanel value={tabValue} index={0}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
              <Typography variant="h6">トラクタヘッド一覧</Typography>
              <Box>
                <IconButton onClick={fetchData}>
                  <RefreshIcon />
                </IconButton>
                <Button variant="contained" startIcon={<AddIcon />} onClick={openNewTractorDialog}>
                  新規登録
                </Button>
              </Box>
            </Box>
            <TableContainer component={Paper} variant="outlined">
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>車両番号</TableCell>
                    <TableCell>タイプ</TableCell>
                    <TableCell>最大牽引重量</TableCell>
                    <TableCell>ステータス</TableCell>
                    <TableCell>連結中シャーシ</TableCell>
                    <TableCell align="right">操作</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {tractorHeads.map((tractor) => (
                    <TableRow key={tractor.id}>
                      <TableCell sx={{ fontWeight: 'bold' }}>{tractor.tractor_number}</TableCell>
                      <TableCell>{tractor.chassis_type}</TableCell>
                      <TableCell>
                        {tractor.max_towing_weight ? `${tractor.max_towing_weight.toLocaleString()} kg` : '-'}
                      </TableCell>
                      <TableCell>
                        <Chip
                          size="small"
                          label={statusLabels[tractor.status] || tractor.status}
                          color={statusColors[tractor.status] || 'default'}
                        />
                      </TableCell>
                      <TableCell>
                        {tractor.current_chassis_number ? (
                          <Chip
                            size="small"
                            icon={<LinkIcon />}
                            label={tractor.current_chassis_number}
                            color="info"
                          />
                        ) : (
                          '-'
                        )}
                      </TableCell>
                      <TableCell align="right">
                        <IconButton size="small" onClick={() => openEditTractorDialog(tractor)}>
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </TabPanel>

          {/* シャーシ一覧 */}
          <TabPanel value={tabValue} index={1}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
              <Typography variant="h6">シャーシ一覧</Typography>
              <Box>
                <IconButton onClick={fetchData}>
                  <RefreshIcon />
                </IconButton>
                <Button variant="contained" startIcon={<AddIcon />} onClick={openNewChassisDialog}>
                  新規登録
                </Button>
              </Box>
            </Box>
            <TableContainer component={Paper} variant="outlined">
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>シャーシ番号</TableCell>
                    <TableCell>タイプ</TableCell>
                    <TableCell>長さ</TableCell>
                    <TableCell>最大積載量</TableCell>
                    <TableCell>所有</TableCell>
                    <TableCell>ステータス</TableCell>
                    <TableCell>現在地</TableCell>
                    <TableCell align="right">操作</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {chassisList.map((chassis) => (
                    <TableRow key={chassis.id}>
                      <TableCell sx={{ fontWeight: 'bold' }}>{chassis.chassis_number}</TableCell>
                      <TableCell>
                        {chassisTypes.find((t) => t.value === chassis.chassis_type)?.label || chassis.chassis_type}
                      </TableCell>
                      <TableCell>{chassis.length_feet ? `${chassis.length_feet}ft` : '-'}</TableCell>
                      <TableCell>
                        {chassis.max_payload_weight ? `${chassis.max_payload_weight.toLocaleString()} kg` : '-'}
                      </TableCell>
                      <TableCell>
                        <Chip
                          size="small"
                          label={chassis.is_owned ? '自社' : 'リース'}
                          color={chassis.is_owned ? 'default' : 'warning'}
                        />
                      </TableCell>
                      <TableCell>
                        <Chip
                          size="small"
                          label={statusLabels[chassis.status] || chassis.status}
                          color={statusColors[chassis.status] || 'default'}
                        />
                      </TableCell>
                      <TableCell>{chassis.current_location || '-'}</TableCell>
                      <TableCell align="right">
                        <IconButton size="small" onClick={() => openEditChassisDialog(chassis)}>
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </TabPanel>

          {/* 連結記録 */}
          <TabPanel value={tabValue} index={2}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
              <Typography variant="h6">連結記録</Typography>
              <IconButton onClick={fetchData}>
                <RefreshIcon />
              </IconButton>
            </Box>
            <TableContainer component={Paper} variant="outlined">
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>日時</TableCell>
                    <TableCell>種別</TableCell>
                    <TableCell>トラクタ</TableCell>
                    <TableCell>シャーシ</TableCell>
                    <TableCell>ドライバー</TableCell>
                    <TableCell>場所</TableCell>
                    <TableCell>シール番号</TableCell>
                    <TableCell>点検</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {couplingRecords.map((record) => (
                    <TableRow key={record.id}>
                      <TableCell>
                        {new Date(record.action_datetime).toLocaleString('ja-JP')}
                      </TableCell>
                      <TableCell>
                        <Chip
                          size="small"
                          icon={record.action_type === 'couple' ? <LinkIcon /> : <LinkOffIcon />}
                          label={record.action_type === 'couple' ? '連結' : '解除'}
                          color={record.action_type === 'couple' ? 'success' : 'warning'}
                        />
                      </TableCell>
                      <TableCell>{record.tractor_number}</TableCell>
                      <TableCell>{record.chassis_number}</TableCell>
                      <TableCell>{record.driver_name}</TableCell>
                      <TableCell>{record.location || '-'}</TableCell>
                      <TableCell>{record.seal_number || '-'}</TableCell>
                      <TableCell>
                        {record.inspection_done ? (
                          <Chip size="small" label="済" color="success" />
                        ) : (
                          '-'
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </TabPanel>
        </CardContent>
      </Card>

      {/* トラクタヘッドダイアログ */}
      <Dialog open={tractorDialogOpen} onClose={() => setTractorDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>{isEditing ? 'トラクタヘッド編集' : 'トラクタヘッド新規登録'}</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid size={{ xs: 12 }}>
              <TextField
                fullWidth
                required
                label="車両番号"
                value={tractorForm.tractor_number}
                onChange={(e) => setTractorForm({ ...tractorForm, tractor_number: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 6 }}>
              <TextField
                fullWidth
                label="シャーシタイプ"
                value={tractorForm.chassis_type}
                onChange={(e) => setTractorForm({ ...tractorForm, chassis_type: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 6 }}>
              <TextField
                fullWidth
                label="連結装置タイプ"
                value={tractorForm.coupling_type}
                onChange={(e) => setTractorForm({ ...tractorForm, coupling_type: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 6 }}>
              <TextField
                fullWidth
                type="number"
                label="第五輪高さ (mm)"
                value={tractorForm.fifth_wheel_height}
                onChange={(e) => setTractorForm({ ...tractorForm, fifth_wheel_height: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 6 }}>
              <TextField
                fullWidth
                type="number"
                label="最大牽引重量 (kg)"
                value={tractorForm.max_towing_weight}
                onChange={(e) => setTractorForm({ ...tractorForm, max_towing_weight: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 12 }}>
              <FormControl fullWidth>
                <InputLabel>ステータス</InputLabel>
                <Select
                  value={tractorForm.status}
                  label="ステータス"
                  onChange={(e) => setTractorForm({ ...tractorForm, status: e.target.value })}
                >
                  <MenuItem value="available">空車</MenuItem>
                  <MenuItem value="in_use">使用中</MenuItem>
                  <MenuItem value="maintenance">整備中</MenuItem>
                  <MenuItem value="inactive">非稼働</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid size={{ xs: 12 }}>
              <TextField
                fullWidth
                multiline
                rows={2}
                label="備考"
                value={tractorForm.notes}
                onChange={(e) => setTractorForm({ ...tractorForm, notes: e.target.value })}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setTractorDialogOpen(false)}>キャンセル</Button>
          <Button variant="contained" onClick={handleSaveTractor}>
            保存
          </Button>
        </DialogActions>
      </Dialog>

      {/* シャーシダイアログ */}
      <Dialog open={chassisDialogOpen} onClose={() => setChassisDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>{isEditing ? 'シャーシ編集' : 'シャーシ新規登録'}</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid size={{ xs: 12, sm: 6 }}>
              <TextField
                fullWidth
                required
                label="シャーシ番号"
                value={chassisForm.chassis_number}
                onChange={(e) => setChassisForm({ ...chassisForm, chassis_number: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 12, sm: 6 }}>
              <FormControl fullWidth required>
                <InputLabel>タイプ</InputLabel>
                <Select
                  value={chassisForm.chassis_type}
                  label="タイプ"
                  onChange={(e) => setChassisForm({ ...chassisForm, chassis_type: e.target.value })}
                >
                  {chassisTypes.map((type) => (
                    <MenuItem key={type.value} value={type.value}>
                      {type.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid size={{ xs: 6, sm: 3 }}>
              <TextField
                fullWidth
                type="number"
                label="長さ (ft)"
                value={chassisForm.length_feet}
                onChange={(e) => setChassisForm({ ...chassisForm, length_feet: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 6, sm: 3 }}>
              <TextField
                fullWidth
                type="number"
                label="軸数"
                value={chassisForm.axle_count}
                onChange={(e) => setChassisForm({ ...chassisForm, axle_count: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 6, sm: 3 }}>
              <TextField
                fullWidth
                type="number"
                label="最大積載 (kg)"
                value={chassisForm.max_payload_weight}
                onChange={(e) => setChassisForm({ ...chassisForm, max_payload_weight: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 6, sm: 3 }}>
              <TextField
                fullWidth
                type="number"
                label="自重 (kg)"
                value={chassisForm.tare_weight}
                onChange={(e) => setChassisForm({ ...chassisForm, tare_weight: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 6 }}>
              <FormControlLabel
                control={
                  <Switch
                    checked={chassisForm.is_owned}
                    onChange={(e) => setChassisForm({ ...chassisForm, is_owned: e.target.checked })}
                  />
                }
                label="自社所有"
              />
            </Grid>
            <Grid size={{ xs: 6 }}>
              <TextField
                fullWidth
                label="リース会社"
                disabled={chassisForm.is_owned}
                value={chassisForm.lease_company}
                onChange={(e) => setChassisForm({ ...chassisForm, lease_company: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 6 }}>
              <TextField
                fullWidth
                type="date"
                label="車検満了日"
                InputLabelProps={{ shrink: true }}
                value={chassisForm.inspection_expiry}
                onChange={(e) => setChassisForm({ ...chassisForm, inspection_expiry: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 6 }}>
              <FormControl fullWidth>
                <InputLabel>ステータス</InputLabel>
                <Select
                  value={chassisForm.status}
                  label="ステータス"
                  onChange={(e) => setChassisForm({ ...chassisForm, status: e.target.value })}
                >
                  <MenuItem value="available">空車</MenuItem>
                  <MenuItem value="in_use">使用中</MenuItem>
                  <MenuItem value="maintenance">整備中</MenuItem>
                  <MenuItem value="repair">修理中</MenuItem>
                  <MenuItem value="inactive">非稼働</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid size={{ xs: 12 }}>
              <TextField
                fullWidth
                label="現在地"
                value={chassisForm.current_location}
                onChange={(e) => setChassisForm({ ...chassisForm, current_location: e.target.value })}
              />
            </Grid>
            <Grid size={{ xs: 12 }}>
              <TextField
                fullWidth
                multiline
                rows={2}
                label="備考"
                value={chassisForm.notes}
                onChange={(e) => setChassisForm({ ...chassisForm, notes: e.target.value })}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setChassisDialogOpen(false)}>キャンセル</Button>
          <Button variant="contained" onClick={handleSaveChassis}>
            保存
          </Button>
        </DialogActions>
      </Dialog>

      {/* 連結・解除ダイアログ */}
      <Dialog open={coupleDialogOpen} onClose={() => setCoupleDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>連結・連結解除</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid size={{ xs: 12 }}>
              <FormControl fullWidth>
                <InputLabel>操作</InputLabel>
                <Select
                  value={coupleForm.action_type}
                  label="操作"
                  onChange={(e) => setCoupleForm({ ...coupleForm, action_type: e.target.value })}
                >
                  <MenuItem value="couple">連結</MenuItem>
                  <MenuItem value="uncouple">連結解除</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid size={{ xs: 12 }}>
              <Autocomplete
                options={
                  coupleForm.action_type === 'couple'
                    ? availableTractors
                    : tractorHeads.filter((t) => t.current_chassis_number)
                }
                getOptionLabel={(option) => option.tractor_number}
                value={tractorHeads.find((t) => t.id === coupleForm.tractor_id) || null}
                onChange={(_, value) =>
                  setCoupleForm({ ...coupleForm, tractor_id: value?.id || null })
                }
                renderInput={(params) => <TextField {...params} label="トラクタヘッド" />}
              />
            </Grid>
            <Grid size={{ xs: 12 }}>
              <Autocomplete
                options={
                  coupleForm.action_type === 'couple'
                    ? availableChassis
                    : chassisList.filter((c) => c.current_tractor_number)
                }
                getOptionLabel={(option) => `${option.chassis_number} (${chassisTypes.find((t) => t.value === option.chassis_type)?.label || option.chassis_type})`}
                value={chassisList.find((c) => c.id === coupleForm.chassis_id) || null}
                onChange={(_, value) =>
                  setCoupleForm({ ...coupleForm, chassis_id: value?.id || null })
                }
                renderInput={(params) => <TextField {...params} label="シャーシ" />}
              />
            </Grid>
            <Grid size={{ xs: 12 }}>
              <TextField
                fullWidth
                label="場所"
                value={coupleForm.location}
                onChange={(e) => setCoupleForm({ ...coupleForm, location: e.target.value })}
              />
            </Grid>
            {coupleForm.action_type === 'couple' && (
              <>
                <Grid size={{ xs: 6 }}>
                  <TextField
                    fullWidth
                    label="シール番号"
                    value={coupleForm.seal_number}
                    onChange={(e) => setCoupleForm({ ...coupleForm, seal_number: e.target.value })}
                  />
                </Grid>
                <Grid size={{ xs: 6 }}>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={coupleForm.inspection_done}
                        onChange={(e) =>
                          setCoupleForm({ ...coupleForm, inspection_done: e.target.checked })
                        }
                      />
                    }
                    label="連結前点検実施"
                  />
                </Grid>
              </>
            )}
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCoupleDialogOpen(false)}>キャンセル</Button>
          <Button
            variant="contained"
            onClick={handleCoupling}
            disabled={!coupleForm.tractor_id || !coupleForm.chassis_id}
          >
            {coupleForm.action_type === 'couple' ? '連結する' : '連結解除する'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default TrailerManagement;
