import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Container,
  IconButton,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
  Menu,
  MenuItem,
  Alert,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  MoreVert as MoreVertIcon,
  PlayArrow as PlayIcon,
  Check as CheckIcon,
  Block as CancelIcon,
  FilterList as FilterIcon,
} from '@mui/icons-material';

interface OperationInstruction {
  id: number;
  instruction_number: string;
  instruction_date: string;
  route_name: string;
  departure_location: string;
  arrival_location: string;
  scheduled_departure_time: string;
  scheduled_arrival_time: string;
  primary_driver_name: string;
  secondary_driver_name: string | null;
  vehicle_number: string;
  expected_passengers: number;
  status: 'draft' | 'issued' | 'in_progress' | 'completed' | 'cancelled';
  created_by_name: string;
}

const STATUS_CONFIG: Record<string, { label: string; color: 'default' | 'primary' | 'success' | 'warning' | 'error' | 'info' }> = {
  draft: { label: '下書き', color: 'default' },
  issued: { label: '発行済', color: 'primary' },
  in_progress: { label: '運行中', color: 'success' },
  completed: { label: '完了', color: 'info' },
  cancelled: { label: '中止', color: 'error' },
};

const OperationInstructionList: React.FC = () => {
  const navigate = useNavigate();
  const [instructions, setInstructions] = useState<OperationInstruction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dateFrom, setDateFrom] = useState<string>(new Date().toISOString().split('T')[0]);
  const [dateTo, setDateTo] = useState<string>(new Date().toISOString().split('T')[0]);
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [selectedInstruction, setSelectedInstruction] = useState<OperationInstruction | null>(null);

  const fetchInstructions = async () => {
    setLoading(true);
    setError(null);

    try {
      const token = localStorage.getItem('token');
      const user = JSON.parse(localStorage.getItem('user') || '{}');
      const companyId = user.company_id;

      let url = `/api/operation-instructions?companyId=${companyId}`;
      if (dateFrom) url += `&dateFrom=${dateFrom}`;
      if (dateTo) url += `&dateTo=${dateTo}`;
      if (statusFilter) url += `&status=${statusFilter}`;

      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch operation instructions');
      }

      const data = await response.json();
      setInstructions(data.data || []);
    } catch (err) {
      console.error('Error fetching instructions:', err);
      setError('運行指示書の取得に失敗しました');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchInstructions();
  }, [dateFrom, dateTo, statusFilter]);

  const handleMenuOpen = (event: React.MouseEvent<HTMLElement>, instruction: OperationInstruction) => {
    setAnchorEl(event.currentTarget);
    setSelectedInstruction(instruction);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
    setSelectedInstruction(null);
  };

  const handleStatusUpdate = async (newStatus: string) => {
    if (!selectedInstruction) return;

    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`/api/operation-instructions/${selectedInstruction.id}/status`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status: newStatus }),
      });

      if (!response.ok) {
        throw new Error('Failed to update status');
      }

      fetchInstructions();
    } catch (err) {
      console.error('Error updating status:', err);
      setError('ステータスの更新に失敗しました');
    }

    handleMenuClose();
  };

  const formatTime = (time: string): string => {
    if (!time) return '-';
    return time.slice(0, 5);
  };

  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return `${date.getMonth() + 1}/${date.getDate()}`;
  };

  return (
    <Container maxWidth="xl" sx={{ py: 4 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
        <Typography variant="h4" component="h1" fontWeight="bold">
          運行指示書管理
        </Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => navigate('/bus/operation-instructions/new')}
        >
          新規作成
        </Button>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* Filters */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box sx={{ display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
            <FilterIcon color="action" />
            <TextField
              type="date"
              label="開始日"
              value={dateFrom}
              onChange={(e) => setDateFrom(e.target.value)}
              size="small"
              InputLabelProps={{ shrink: true }}
            />
            <TextField
              type="date"
              label="終了日"
              value={dateTo}
              onChange={(e) => setDateTo(e.target.value)}
              size="small"
              InputLabelProps={{ shrink: true }}
            />
            <TextField
              select
              label="ステータス"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              size="small"
              sx={{ minWidth: 120 }}
            >
              <MenuItem value="">すべて</MenuItem>
              {Object.entries(STATUS_CONFIG).map(([key, config]) => (
                <MenuItem key={key} value={key}>{config.label}</MenuItem>
              ))}
            </TextField>
            <Button variant="outlined" onClick={fetchInstructions}>
              検索
            </Button>
          </Box>
        </CardContent>
      </Card>

      {/* Instructions Table */}
      <TableContainer component={Paper}>
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
            <CircularProgress />
          </Box>
        ) : instructions.length === 0 ? (
          <Box sx={{ textAlign: 'center', py: 8 }}>
            <Typography color="text.secondary">
              該当する運行指示書がありません
            </Typography>
          </Box>
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>指示書番号</TableCell>
                <TableCell>日付</TableCell>
                <TableCell>路線・行先</TableCell>
                <TableCell>予定時刻</TableCell>
                <TableCell>運転者</TableCell>
                <TableCell>車両</TableCell>
                <TableCell>乗客数</TableCell>
                <TableCell>ステータス</TableCell>
                <TableCell align="right">操作</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {instructions.map((instruction) => {
                const statusConfig = STATUS_CONFIG[instruction.status] || STATUS_CONFIG.draft;
                return (
                  <TableRow key={instruction.id} hover>
                    <TableCell>
                      <Typography variant="body2" fontWeight="medium">
                        {instruction.instruction_number}
                      </Typography>
                    </TableCell>
                    <TableCell>{formatDate(instruction.instruction_date)}</TableCell>
                    <TableCell>
                      <Box>
                        <Typography variant="body2" fontWeight="medium">
                          {instruction.route_name || '-'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          {instruction.departure_location} → {instruction.arrival_location}
                        </Typography>
                      </Box>
                    </TableCell>
                    <TableCell>
                      {formatTime(instruction.scheduled_departure_time)} - {formatTime(instruction.scheduled_arrival_time)}
                    </TableCell>
                    <TableCell>
                      <Box>
                        <Typography variant="body2">{instruction.primary_driver_name}</Typography>
                        {instruction.secondary_driver_name && (
                          <Typography variant="caption" color="text.secondary">
                            交替: {instruction.secondary_driver_name}
                          </Typography>
                        )}
                      </Box>
                    </TableCell>
                    <TableCell>{instruction.vehicle_number || '-'}</TableCell>
                    <TableCell>{instruction.expected_passengers || '-'}名</TableCell>
                    <TableCell>
                      <Chip
                        label={statusConfig.label}
                        color={statusConfig.color}
                        size="small"
                      />
                    </TableCell>
                    <TableCell align="right">
                      <IconButton
                        size="small"
                        onClick={() => navigate(`/bus/operation-instructions/${instruction.id}`)}
                      >
                        <EditIcon />
                      </IconButton>
                      <IconButton
                        size="small"
                        onClick={(e) => handleMenuOpen(e, instruction)}
                      >
                        <MoreVertIcon />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
      </TableContainer>

      {/* Status Menu */}
      <Menu
        anchorEl={anchorEl}
        open={Boolean(anchorEl)}
        onClose={handleMenuClose}
      >
        {selectedInstruction?.status === 'draft' && (
          <MenuItem onClick={() => handleStatusUpdate('issued')}>
            <PlayIcon fontSize="small" sx={{ mr: 1 }} /> 発行する
          </MenuItem>
        )}
        {selectedInstruction?.status === 'issued' && (
          <MenuItem onClick={() => handleStatusUpdate('in_progress')}>
            <PlayIcon fontSize="small" sx={{ mr: 1 }} /> 運行開始
          </MenuItem>
        )}
        {selectedInstruction?.status === 'in_progress' && (
          <MenuItem onClick={() => handleStatusUpdate('completed')}>
            <CheckIcon fontSize="small" sx={{ mr: 1 }} /> 運行完了
          </MenuItem>
        )}
        {(selectedInstruction?.status === 'draft' || selectedInstruction?.status === 'issued') && (
          <MenuItem onClick={() => handleStatusUpdate('cancelled')}>
            <CancelIcon fontSize="small" sx={{ mr: 1 }} /> 中止
          </MenuItem>
        )}
      </Menu>
    </Container>
  );
};

export default OperationInstructionList;
