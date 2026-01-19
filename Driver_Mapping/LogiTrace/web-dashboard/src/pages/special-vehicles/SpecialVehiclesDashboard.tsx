/**
 * 特殊車両・業態管理ダッシュボード
 * Special Vehicles & Operations Dashboard
 */

import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Button,
  Grid,
  Tabs,
  Tab,
  Chip,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Alert,
  IconButton,
  TextField,
  InputAdornment,
} from '@mui/material';
import {
  LocalShipping as TruckIcon,
  DirectionsBoat as BoatIcon,
  Train as TrainIcon,
  ViewModule as ContainerIcon,
  Link as LinkIcon,
  Schedule as ScheduleIcon,
  LocationOn as LocationIcon,
  Search as SearchIcon,
  Refresh as RefreshIcon,
  ArrowForward as ArrowForwardIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
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

interface SummaryData {
  tractors: { total: number; available: number; inUse: number };
  chassis: { total: number; available: number; inUse: number };
  ferryBookings: { total: number; upcoming: number };
  railBookings: { total: number; inTransit: number };
  containers: { total: number; loaded: number };
}

interface FerryBooking {
  id: number;
  booking_number: string;
  route_name: string;
  departure_date: string;
  departure_time: string;
  departure_port_name: string;
  arrival_port_name: string;
  tractor_number: string;
  chassis_number: string;
  driver_name: string;
  boarding_status: string;
}

interface RailBooking {
  id: number;
  booking_number: string;
  route_name: string;
  departure_date: string;
  departure_station_name: string;
  arrival_station_name: string;
  container_number: string;
  booking_status: string;
}

interface Container {
  id: number;
  container_number: string;
  container_type: string;
  status: string;
  current_location: string;
  last_tracked_at: string;
}

const SpecialVehiclesDashboard: React.FC = () => {
  const navigate = useNavigate();
  const [tabValue, setTabValue] = useState(0);
  const [summary, setSummary] = useState<SummaryData | null>(null);
  const [ferryBookings, setFerryBookings] = useState<FerryBooking[]>([]);
  const [railBookings, setRailBookings] = useState<RailBooking[]>([]);
  const [containers, setContainers] = useState<Container[]>([]);
  const [loading, setLoading] = useState(false);

  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const companyId = user.companyId || 1;

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    setLoading(true);
    try {
      const today = new Date().toISOString().split('T')[0];
      const nextWeek = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

      const [tractorsRes, chassisRes, ferryRes, railRes, containersRes] = await Promise.all([
        axios.get(`/api/trailers/tractors?companyId=${companyId}`),
        axios.get(`/api/trailers/chassis?companyId=${companyId}`),
        axios.get(`/api/maritime/ferry-bookings?companyId=${companyId}&startDate=${today}&endDate=${nextWeek}`),
        axios.get(`/api/rail-freight/rail-bookings?companyId=${companyId}&startDate=${today}&endDate=${nextWeek}`),
        axios.get(`/api/rail-freight/containers/locations?companyId=${companyId}`),
      ]);

      const tractors = tractorsRes.data;
      const chassis = chassisRes.data;

      setSummary({
        tractors: {
          total: tractors.length,
          available: tractors.filter((t: any) => t.status === 'available').length,
          inUse: tractors.filter((t: any) => t.status === 'in_use').length,
        },
        chassis: {
          total: chassis.length,
          available: chassis.filter((c: any) => c.status === 'available').length,
          inUse: chassis.filter((c: any) => c.status === 'in_use').length,
        },
        ferryBookings: {
          total: ferryRes.data.length,
          upcoming: ferryRes.data.filter((b: any) => b.boarding_status === 'booked').length,
        },
        railBookings: {
          total: railRes.data.length,
          inTransit: railRes.data.filter((b: any) => b.booking_status === 'in_transit').length,
        },
        containers: {
          total: containersRes.data.length,
          loaded: containersRes.data.filter((c: any) => c.status === 'loaded').length,
        },
      });

      setFerryBookings(ferryRes.data.slice(0, 5));
      setRailBookings(railRes.data.slice(0, 5));
      setContainers(containersRes.data.slice(0, 5));
    } catch (error) {
      console.error('Failed to fetch data:', error);
    } finally {
      setLoading(false);
    }
  };

  const boardingStatusColors: Record<string, 'success' | 'warning' | 'info' | 'error' | 'default'> = {
    booked: 'info',
    checked_in: 'warning',
    boarded: 'success',
    completed: 'default',
    cancelled: 'error',
  };

  const bookingStatusColors: Record<string, 'success' | 'warning' | 'info' | 'error' | 'default'> = {
    booked: 'info',
    confirmed: 'info',
    loaded: 'warning',
    in_transit: 'success',
    arrived: 'success',
    delivered: 'default',
    cancelled: 'error',
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        特殊車両・業態管理
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        トレーラー・海上輸送・鉄道輸送の統合管理
      </Typography>

      {/* サマリーカード */}
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid size={{ xs: 12, sm: 6, md: 2.4 }}>
          <Card
            sx={{ cursor: 'pointer', '&:hover': { boxShadow: 4 } }}
            onClick={() => navigate('/special-vehicles/trailers')}
          >
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                <TruckIcon color="primary" sx={{ mr: 1 }} />
                <Typography variant="subtitle2" color="text.secondary">
                  トラクタ
                </Typography>
              </Box>
              <Typography variant="h4">{summary?.tractors.total || 0}</Typography>
              <Box sx={{ display: 'flex', gap: 1, mt: 1 }}>
                <Chip size="small" label={`空: ${summary?.tractors.available || 0}`} color="success" />
                <Chip size="small" label={`使用: ${summary?.tractors.inUse || 0}`} color="warning" />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, sm: 6, md: 2.4 }}>
          <Card
            sx={{ cursor: 'pointer', '&:hover': { boxShadow: 4 } }}
            onClick={() => navigate('/special-vehicles/trailers')}
          >
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                <ContainerIcon color="secondary" sx={{ mr: 1 }} />
                <Typography variant="subtitle2" color="text.secondary">
                  シャーシ
                </Typography>
              </Box>
              <Typography variant="h4">{summary?.chassis.total || 0}</Typography>
              <Box sx={{ display: 'flex', gap: 1, mt: 1 }}>
                <Chip size="small" label={`空: ${summary?.chassis.available || 0}`} color="success" />
                <Chip size="small" label={`使用: ${summary?.chassis.inUse || 0}`} color="warning" />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, sm: 6, md: 2.4 }}>
          <Card
            sx={{ cursor: 'pointer', '&:hover': { boxShadow: 4 } }}
            onClick={() => navigate('/special-vehicles/maritime')}
          >
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                <BoatIcon color="info" sx={{ mr: 1 }} />
                <Typography variant="subtitle2" color="text.secondary">
                  フェリー予約
                </Typography>
              </Box>
              <Typography variant="h4">{summary?.ferryBookings.total || 0}</Typography>
              <Chip
                size="small"
                label={`今週: ${summary?.ferryBookings.upcoming || 0}件`}
                color="info"
                sx={{ mt: 1 }}
              />
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, sm: 6, md: 2.4 }}>
          <Card
            sx={{ cursor: 'pointer', '&:hover': { boxShadow: 4 } }}
            onClick={() => navigate('/special-vehicles/rail-freight')}
          >
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                <TrainIcon color="success" sx={{ mr: 1 }} />
                <Typography variant="subtitle2" color="text.secondary">
                  鉄道輸送
                </Typography>
              </Box>
              <Typography variant="h4">{summary?.railBookings.total || 0}</Typography>
              <Chip
                size="small"
                label={`輸送中: ${summary?.railBookings.inTransit || 0}件`}
                color="success"
                sx={{ mt: 1 }}
              />
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, sm: 6, md: 2.4 }}>
          <Card
            sx={{ cursor: 'pointer', '&:hover': { boxShadow: 4 } }}
            onClick={() => navigate('/special-vehicles/rail-freight')}
          >
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                <ContainerIcon color="warning" sx={{ mr: 1 }} />
                <Typography variant="subtitle2" color="text.secondary">
                  コンテナ
                </Typography>
              </Box>
              <Typography variant="h4">{summary?.containers.total || 0}</Typography>
              <Chip
                size="small"
                label={`積載: ${summary?.containers.loaded || 0}個`}
                color="warning"
                sx={{ mt: 1 }}
              />
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Card>
        <CardContent>
          <Tabs value={tabValue} onChange={(_, v) => setTabValue(v)}>
            <Tab label="フェリー予約" icon={<BoatIcon />} iconPosition="start" />
            <Tab label="鉄道輸送" icon={<TrainIcon />} iconPosition="start" />
            <Tab label="コンテナ追跡" icon={<LocationIcon />} iconPosition="start" />
          </Tabs>

          {/* フェリー予約 */}
          <TabPanel value={tabValue} index={0}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
              <Typography variant="h6">今週のフェリー予約</Typography>
              <Box>
                <IconButton onClick={fetchData}>
                  <RefreshIcon />
                </IconButton>
                <Button
                  endIcon={<ArrowForwardIcon />}
                  onClick={() => navigate('/special-vehicles/maritime')}
                >
                  詳細へ
                </Button>
              </Box>
            </Box>
            <TableContainer component={Paper} variant="outlined">
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>予約番号</TableCell>
                    <TableCell>航路</TableCell>
                    <TableCell>出発日</TableCell>
                    <TableCell>出発港</TableCell>
                    <TableCell>到着港</TableCell>
                    <TableCell>車両</TableCell>
                    <TableCell>ステータス</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {ferryBookings.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={7} align="center">
                        予約がありません
                      </TableCell>
                    </TableRow>
                  ) : (
                    ferryBookings.map((booking) => (
                      <TableRow key={booking.id}>
                        <TableCell>{booking.booking_number}</TableCell>
                        <TableCell>{booking.route_name}</TableCell>
                        <TableCell>
                          {new Date(booking.departure_date).toLocaleDateString('ja-JP')}
                          <Typography variant="caption" display="block" color="text.secondary">
                            {booking.departure_time}
                          </Typography>
                        </TableCell>
                        <TableCell>{booking.departure_port_name}</TableCell>
                        <TableCell>{booking.arrival_port_name}</TableCell>
                        <TableCell>
                          {booking.tractor_number || booking.chassis_number || '-'}
                        </TableCell>
                        <TableCell>
                          <Chip
                            size="small"
                            label={booking.boarding_status}
                            color={boardingStatusColors[booking.boarding_status] || 'default'}
                          />
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </TableContainer>
          </TabPanel>

          {/* 鉄道輸送 */}
          <TabPanel value={tabValue} index={1}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
              <Typography variant="h6">今週の鉄道輸送</Typography>
              <Box>
                <IconButton onClick={fetchData}>
                  <RefreshIcon />
                </IconButton>
                <Button
                  endIcon={<ArrowForwardIcon />}
                  onClick={() => navigate('/special-vehicles/rail-freight')}
                >
                  詳細へ
                </Button>
              </Box>
            </Box>
            <TableContainer component={Paper} variant="outlined">
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>予約番号</TableCell>
                    <TableCell>ルート</TableCell>
                    <TableCell>出発日</TableCell>
                    <TableCell>出発駅</TableCell>
                    <TableCell>到着駅</TableCell>
                    <TableCell>コンテナ</TableCell>
                    <TableCell>ステータス</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {railBookings.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={7} align="center">
                        予約がありません
                      </TableCell>
                    </TableRow>
                  ) : (
                    railBookings.map((booking) => (
                      <TableRow key={booking.id}>
                        <TableCell>{booking.booking_number}</TableCell>
                        <TableCell>{booking.route_name}</TableCell>
                        <TableCell>
                          {new Date(booking.departure_date).toLocaleDateString('ja-JP')}
                        </TableCell>
                        <TableCell>{booking.departure_station_name}</TableCell>
                        <TableCell>{booking.arrival_station_name}</TableCell>
                        <TableCell>{booking.container_number || '-'}</TableCell>
                        <TableCell>
                          <Chip
                            size="small"
                            label={booking.booking_status}
                            color={bookingStatusColors[booking.booking_status] || 'default'}
                          />
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </TableContainer>
          </TabPanel>

          {/* コンテナ追跡 */}
          <TabPanel value={tabValue} index={2}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
              <Typography variant="h6">コンテナ現在位置</Typography>
              <Box>
                <IconButton onClick={fetchData}>
                  <RefreshIcon />
                </IconButton>
                <Button
                  endIcon={<ArrowForwardIcon />}
                  onClick={() => navigate('/special-vehicles/rail-freight')}
                >
                  詳細へ
                </Button>
              </Box>
            </Box>
            <TableContainer component={Paper} variant="outlined">
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>コンテナ番号</TableCell>
                    <TableCell>タイプ</TableCell>
                    <TableCell>ステータス</TableCell>
                    <TableCell>現在地</TableCell>
                    <TableCell>最終更新</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {containers.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={5} align="center">
                        追跡中のコンテナがありません
                      </TableCell>
                    </TableRow>
                  ) : (
                    containers.map((container) => (
                      <TableRow key={container.id}>
                        <TableCell sx={{ fontWeight: 'bold' }}>{container.container_number}</TableCell>
                        <TableCell>{container.container_type}</TableCell>
                        <TableCell>
                          <Chip
                            size="small"
                            label={container.status}
                            color={container.status === 'in_transit' ? 'success' : 'default'}
                          />
                        </TableCell>
                        <TableCell>{container.current_location || '-'}</TableCell>
                        <TableCell>
                          {container.last_tracked_at
                            ? new Date(container.last_tracked_at).toLocaleString('ja-JP')
                            : '-'}
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

      {/* クイックアクション */}
      <Grid container spacing={2} sx={{ mt: 3 }}>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card
            sx={{
              cursor: 'pointer',
              bgcolor: 'primary.main',
              color: 'white',
              '&:hover': { bgcolor: 'primary.dark' },
            }}
            onClick={() => navigate('/special-vehicles/trailers')}
          >
            <CardContent sx={{ display: 'flex', alignItems: 'center' }}>
              <LinkIcon sx={{ fontSize: 40, mr: 2 }} />
              <Box>
                <Typography variant="subtitle1" fontWeight="bold">
                  連結・解除
                </Typography>
                <Typography variant="caption">トレーラー管理</Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card
            sx={{
              cursor: 'pointer',
              bgcolor: 'info.main',
              color: 'white',
              '&:hover': { bgcolor: 'info.dark' },
            }}
            onClick={() => navigate('/special-vehicles/maritime')}
          >
            <CardContent sx={{ display: 'flex', alignItems: 'center' }}>
              <BoatIcon sx={{ fontSize: 40, mr: 2 }} />
              <Box>
                <Typography variant="subtitle1" fontWeight="bold">
                  フェリー予約
                </Typography>
                <Typography variant="caption">海上輸送管理</Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card
            sx={{
              cursor: 'pointer',
              bgcolor: 'success.main',
              color: 'white',
              '&:hover': { bgcolor: 'success.dark' },
            }}
            onClick={() => navigate('/special-vehicles/rail-freight')}
          >
            <CardContent sx={{ display: 'flex', alignItems: 'center' }}>
              <TrainIcon sx={{ fontSize: 40, mr: 2 }} />
              <Box>
                <Typography variant="subtitle1" fontWeight="bold">
                  鉄道輸送予約
                </Typography>
                <Typography variant="caption">JR貨物連携</Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card
            sx={{
              cursor: 'pointer',
              bgcolor: 'warning.main',
              color: 'white',
              '&:hover': { bgcolor: 'warning.dark' },
            }}
            onClick={() => navigate('/special-vehicles/rail-freight')}
          >
            <CardContent sx={{ display: 'flex', alignItems: 'center' }}>
              <ContainerIcon sx={{ fontSize: 40, mr: 2 }} />
              <Box>
                <Typography variant="subtitle1" fontWeight="bold">
                  コンテナ管理
                </Typography>
                <Typography variant="caption">追跡・在庫管理</Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default SpecialVehiclesDashboard;
