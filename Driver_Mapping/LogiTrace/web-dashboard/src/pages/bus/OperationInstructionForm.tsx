import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Container,
  FormControl,
  Grid,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  TextField,
  Typography,
} from '@mui/material';
import {
  ArrowBack as BackIcon,
  Save as SaveIcon,
  Add as AddIcon,
  Delete as DeleteIcon,
} from '@mui/icons-material';

interface Driver {
  id: number;
  name: string;
}

interface Vehicle {
  id: number;
  vehicle_number: string;
}

interface ViaPoint {
  name: string;
  scheduled_time: string;
}

interface PlannedBreak {
  location: string;
  scheduled_time: string;
  duration_minutes: number;
}

interface FormData {
  instruction_date: string;
  route_name: string;
  departure_location: string;
  arrival_location: string;
  via_points: ViaPoint[];
  scheduled_departure_time: string;
  scheduled_arrival_time: string;
  primary_driver_id: number | '';
  secondary_driver_id: number | '';
  vehicle_id: number | '';
  expected_passengers: number | '';
  group_name: string;
  contact_person: string;
  contact_phone: string;
  planned_breaks: PlannedBreak[];
  special_instructions: string;
}

const OperationInstructionForm: React.FC = () => {
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  const isEdit = id && id !== 'new';

  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);

  const [formData, setFormData] = useState<FormData>({
    instruction_date: new Date().toISOString().split('T')[0],
    route_name: '',
    departure_location: '',
    arrival_location: '',
    via_points: [],
    scheduled_departure_time: '09:00',
    scheduled_arrival_time: '18:00',
    primary_driver_id: '',
    secondary_driver_id: '',
    vehicle_id: '',
    expected_passengers: '',
    group_name: '',
    contact_person: '',
    contact_phone: '',
    planned_breaks: [],
    special_instructions: '',
  });

  useEffect(() => {
    fetchDriversAndVehicles();
    if (isEdit) {
      fetchInstruction();
    }
  }, [id]);

  const fetchDriversAndVehicles = async () => {
    try {
      const token = localStorage.getItem('token');
      const user = JSON.parse(localStorage.getItem('user') || '{}');
      const companyId = user.company_id;

      const [driversRes, vehiclesRes] = await Promise.all([
        fetch(`/api/industries/company/${companyId}/drivers`, {
          headers: { 'Authorization': `Bearer ${token}` },
        }),
        fetch(`/api/vehicles?companyId=${companyId}`, {
          headers: { 'Authorization': `Bearer ${token}` },
        }),
      ]);

      if (driversRes.ok) {
        const driversData = await driversRes.json();
        setDrivers(driversData);
      }

      if (vehiclesRes.ok) {
        const vehiclesData = await vehiclesRes.json();
        setVehicles(vehiclesData.data || vehiclesData || []);
      }
    } catch (err) {
      console.error('Error fetching data:', err);
    }
  };

  const fetchInstruction = async () => {
    setLoading(true);
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`/api/operation-instructions/${id}`, {
        headers: { 'Authorization': `Bearer ${token}` },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch instruction');
      }

      const data = await response.json();
      setFormData({
        instruction_date: data.instruction_date?.split('T')[0] || '',
        route_name: data.route_name || '',
        departure_location: data.departure_location || '',
        arrival_location: data.arrival_location || '',
        via_points: data.via_points || [],
        scheduled_departure_time: data.scheduled_departure_time?.slice(0, 5) || '09:00',
        scheduled_arrival_time: data.scheduled_arrival_time?.slice(0, 5) || '18:00',
        primary_driver_id: data.primary_driver_id || '',
        secondary_driver_id: data.secondary_driver_id || '',
        vehicle_id: data.vehicle_id || '',
        expected_passengers: data.expected_passengers || '',
        group_name: data.group_name || '',
        contact_person: data.contact_person || '',
        contact_phone: data.contact_phone || '',
        planned_breaks: data.planned_breaks || [],
        special_instructions: data.special_instructions || '',
      });
    } catch (err) {
      console.error('Error fetching instruction:', err);
      setError('運行指示書の取得に失敗しました');
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (field: keyof FormData, value: any) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  const handleAddViaPoint = () => {
    setFormData((prev) => ({
      ...prev,
      via_points: [...prev.via_points, { name: '', scheduled_time: '' }],
    }));
  };

  const handleRemoveViaPoint = (index: number) => {
    setFormData((prev) => ({
      ...prev,
      via_points: prev.via_points.filter((_, i) => i !== index),
    }));
  };

  const handleViaPointChange = (index: number, field: keyof ViaPoint, value: string) => {
    setFormData((prev) => ({
      ...prev,
      via_points: prev.via_points.map((point, i) =>
        i === index ? { ...point, [field]: value } : point
      ),
    }));
  };

  const handleAddBreak = () => {
    setFormData((prev) => ({
      ...prev,
      planned_breaks: [...prev.planned_breaks, { location: '', scheduled_time: '', duration_minutes: 15 }],
    }));
  };

  const handleRemoveBreak = (index: number) => {
    setFormData((prev) => ({
      ...prev,
      planned_breaks: prev.planned_breaks.filter((_, i) => i !== index),
    }));
  };

  const handleBreakChange = (index: number, field: keyof PlannedBreak, value: string | number) => {
    setFormData((prev) => ({
      ...prev,
      planned_breaks: prev.planned_breaks.map((breakItem, i) =>
        i === index ? { ...breakItem, [field]: value } : breakItem
      ),
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSaving(true);

    try {
      const token = localStorage.getItem('token');
      const user = JSON.parse(localStorage.getItem('user') || '{}');

      const payload = {
        ...formData,
        company_id: user.company_id,
        primary_driver_id: formData.primary_driver_id || null,
        secondary_driver_id: formData.secondary_driver_id || null,
        vehicle_id: formData.vehicle_id || null,
        expected_passengers: formData.expected_passengers || null,
      };

      const url = isEdit
        ? `/api/operation-instructions/${id}`
        : '/api/operation-instructions';

      const response = await fetch(url, {
        method: isEdit ? 'PUT' : 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to save');
      }

      navigate('/bus/operation-instructions');
    } catch (err: any) {
      console.error('Error saving instruction:', err);
      setError(err.message || '保存に失敗しました');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 4 }}>
        <IconButton onClick={() => navigate('/bus/operation-instructions')} sx={{ mr: 2 }}>
          <BackIcon />
        </IconButton>
        <Typography variant="h4" component="h1" fontWeight="bold">
          {isEdit ? '運行指示書編集' : '運行指示書作成'}
        </Typography>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <form onSubmit={handleSubmit}>
        <Grid container spacing={3}>
          {/* Basic Info */}
          <Grid size={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>基本情報</Typography>
                <Grid container spacing={2}>
                  <Grid size={{ xs: 12, md: 4 }}>
                    <TextField
                      fullWidth
                      type="date"
                      label="運行日"
                      value={formData.instruction_date}
                      onChange={(e) => handleInputChange('instruction_date', e.target.value)}
                      InputLabelProps={{ shrink: true }}
                      required
                    />
                  </Grid>
                  <Grid size={{ xs: 12, md: 8 }}>
                    <TextField
                      fullWidth
                      label="路線名"
                      value={formData.route_name}
                      onChange={(e) => handleInputChange('route_name', e.target.value)}
                      placeholder="例: 東京ツアー、学校送迎など"
                    />
                  </Grid>
                </Grid>
              </CardContent>
            </Card>
          </Grid>

          {/* Route Info */}
          <Grid size={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>運行ルート</Typography>
                <Grid container spacing={2}>
                  <Grid size={{ xs: 12, md: 6 }}>
                    <TextField
                      fullWidth
                      label="出発地"
                      value={formData.departure_location}
                      onChange={(e) => handleInputChange('departure_location', e.target.value)}
                      required
                    />
                  </Grid>
                  <Grid size={{ xs: 12, md: 6 }}>
                    <TextField
                      fullWidth
                      label="到着地"
                      value={formData.arrival_location}
                      onChange={(e) => handleInputChange('arrival_location', e.target.value)}
                      required
                    />
                  </Grid>
                  <Grid size={{ xs: 12, md: 3 }}>
                    <TextField
                      fullWidth
                      type="time"
                      label="出発予定時刻"
                      value={formData.scheduled_departure_time}
                      onChange={(e) => handleInputChange('scheduled_departure_time', e.target.value)}
                      InputLabelProps={{ shrink: true }}
                      required
                    />
                  </Grid>
                  <Grid size={{ xs: 12, md: 3 }}>
                    <TextField
                      fullWidth
                      type="time"
                      label="到着予定時刻"
                      value={formData.scheduled_arrival_time}
                      onChange={(e) => handleInputChange('scheduled_arrival_time', e.target.value)}
                      InputLabelProps={{ shrink: true }}
                      required
                    />
                  </Grid>
                </Grid>

                {/* Via Points */}
                <Box sx={{ mt: 3 }}>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                    <Typography variant="subtitle1">経由地</Typography>
                    <Button
                      size="small"
                      startIcon={<AddIcon />}
                      onClick={handleAddViaPoint}
                    >
                      追加
                    </Button>
                  </Box>
                  {formData.via_points.map((point, index) => (
                    <Grid container spacing={2} key={index} sx={{ mb: 1 }}>
                      <Grid size={7}>
                        <TextField
                          fullWidth
                          size="small"
                          label="経由地名"
                          value={point.name}
                          onChange={(e) => handleViaPointChange(index, 'name', e.target.value)}
                        />
                      </Grid>
                      <Grid size={4}>
                        <TextField
                          fullWidth
                          size="small"
                          type="time"
                          label="予定時刻"
                          value={point.scheduled_time}
                          onChange={(e) => handleViaPointChange(index, 'scheduled_time', e.target.value)}
                          InputLabelProps={{ shrink: true }}
                        />
                      </Grid>
                      <Grid size={1}>
                        <IconButton size="small" onClick={() => handleRemoveViaPoint(index)}>
                          <DeleteIcon />
                        </IconButton>
                      </Grid>
                    </Grid>
                  ))}
                </Box>
              </CardContent>
            </Card>
          </Grid>

          {/* Assignment */}
          <Grid size={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>配車情報</Typography>
                <Grid container spacing={2}>
                  <Grid size={{ xs: 12, md: 4 }}>
                    <FormControl fullWidth>
                      <InputLabel>運転者</InputLabel>
                      <Select
                        value={formData.primary_driver_id}
                        onChange={(e) => handleInputChange('primary_driver_id', e.target.value)}
                        label="運転者"
                      >
                        <MenuItem value="">選択してください</MenuItem>
                        {drivers.map((driver) => (
                          <MenuItem key={driver.id} value={driver.id}>
                            {driver.name}
                          </MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                  </Grid>
                  <Grid size={{ xs: 12, md: 4 }}>
                    <FormControl fullWidth>
                      <InputLabel>交替運転者</InputLabel>
                      <Select
                        value={formData.secondary_driver_id}
                        onChange={(e) => handleInputChange('secondary_driver_id', e.target.value)}
                        label="交替運転者"
                      >
                        <MenuItem value="">なし</MenuItem>
                        {drivers.map((driver) => (
                          <MenuItem key={driver.id} value={driver.id}>
                            {driver.name}
                          </MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                  </Grid>
                  <Grid size={{ xs: 12, md: 4 }}>
                    <FormControl fullWidth>
                      <InputLabel>車両</InputLabel>
                      <Select
                        value={formData.vehicle_id}
                        onChange={(e) => handleInputChange('vehicle_id', e.target.value)}
                        label="車両"
                      >
                        <MenuItem value="">選択してください</MenuItem>
                        {vehicles.map((vehicle) => (
                          <MenuItem key={vehicle.id} value={vehicle.id}>
                            {vehicle.vehicle_number}
                          </MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                  </Grid>
                  <Grid size={{ xs: 12, md: 4 }}>
                    <TextField
                      fullWidth
                      type="number"
                      label="予定乗客数"
                      value={formData.expected_passengers}
                      onChange={(e) => handleInputChange('expected_passengers', e.target.value)}
                    />
                  </Grid>
                </Grid>
              </CardContent>
            </Card>
          </Grid>

          {/* Customer Info */}
          <Grid size={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>顧客情報（貸切の場合）</Typography>
                <Grid container spacing={2}>
                  <Grid size={{ xs: 12, md: 4 }}>
                    <TextField
                      fullWidth
                      label="団体名"
                      value={formData.group_name}
                      onChange={(e) => handleInputChange('group_name', e.target.value)}
                    />
                  </Grid>
                  <Grid size={{ xs: 12, md: 4 }}>
                    <TextField
                      fullWidth
                      label="担当者名"
                      value={formData.contact_person}
                      onChange={(e) => handleInputChange('contact_person', e.target.value)}
                    />
                  </Grid>
                  <Grid size={{ xs: 12, md: 4 }}>
                    <TextField
                      fullWidth
                      label="連絡先電話番号"
                      value={formData.contact_phone}
                      onChange={(e) => handleInputChange('contact_phone', e.target.value)}
                    />
                  </Grid>
                </Grid>
              </CardContent>
            </Card>
          </Grid>

          {/* Breaks */}
          <Grid size={12}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                  <Typography variant="h6">休憩計画</Typography>
                  <Button size="small" startIcon={<AddIcon />} onClick={handleAddBreak}>
                    追加
                  </Button>
                </Box>
                {formData.planned_breaks.map((breakItem, index) => (
                  <Grid container spacing={2} key={index} sx={{ mb: 1 }}>
                    <Grid size={5}>
                      <TextField
                        fullWidth
                        size="small"
                        label="休憩場所"
                        value={breakItem.location}
                        onChange={(e) => handleBreakChange(index, 'location', e.target.value)}
                      />
                    </Grid>
                    <Grid size={3}>
                      <TextField
                        fullWidth
                        size="small"
                        type="time"
                        label="予定時刻"
                        value={breakItem.scheduled_time}
                        onChange={(e) => handleBreakChange(index, 'scheduled_time', e.target.value)}
                        InputLabelProps={{ shrink: true }}
                      />
                    </Grid>
                    <Grid size={3}>
                      <TextField
                        fullWidth
                        size="small"
                        type="number"
                        label="休憩時間（分）"
                        value={breakItem.duration_minutes}
                        onChange={(e) => handleBreakChange(index, 'duration_minutes', parseInt(e.target.value) || 0)}
                      />
                    </Grid>
                    <Grid size={1}>
                      <IconButton size="small" onClick={() => handleRemoveBreak(index)}>
                        <DeleteIcon />
                      </IconButton>
                    </Grid>
                  </Grid>
                ))}
              </CardContent>
            </Card>
          </Grid>

          {/* Special Instructions */}
          <Grid size={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>特記事項</Typography>
                <TextField
                  fullWidth
                  multiline
                  rows={4}
                  value={formData.special_instructions}
                  onChange={(e) => handleInputChange('special_instructions', e.target.value)}
                  placeholder="運転者への注意事項、ルート上の注意点など"
                />
              </CardContent>
            </Card>
          </Grid>

          {/* Actions */}
          <Grid size={12}>
            <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2 }}>
              <Button
                variant="outlined"
                onClick={() => navigate('/bus/operation-instructions')}
              >
                キャンセル
              </Button>
              <Button
                type="submit"
                variant="contained"
                startIcon={saving ? <CircularProgress size={20} /> : <SaveIcon />}
                disabled={saving}
              >
                {isEdit ? '更新' : '作成'}
              </Button>
            </Box>
          </Grid>
        </Grid>
      </form>
    </Container>
  );
};

export default OperationInstructionForm;
