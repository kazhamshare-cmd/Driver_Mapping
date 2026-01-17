import React, { useState } from 'react';
import {
    AppBar, Toolbar, Typography, Container, Box, Drawer, List, ListItem,
    ListItemButton, ListItemIcon, ListItemText, IconButton, Divider, Button
} from '@mui/material';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import MenuIcon from '@mui/icons-material/Menu';
import DashboardIcon from '@mui/icons-material/Dashboard';
import PersonIcon from '@mui/icons-material/Person';
import BadgeIcon from '@mui/icons-material/Badge';
import LocalHospitalIcon from '@mui/icons-material/LocalHospital';
import PsychologyIcon from '@mui/icons-material/Psychology';
import SchoolIcon from '@mui/icons-material/School';
import WarningIcon from '@mui/icons-material/Warning';
import FactCheckIcon from '@mui/icons-material/FactCheck';
import CarRepairIcon from '@mui/icons-material/CarRepair';
import SpeedIcon from '@mui/icons-material/Speed';
import DescriptionIcon from '@mui/icons-material/Description';
import LogoutIcon from '@mui/icons-material/Logout';

const drawerWidth = 260;

const menuItems = [
    { text: 'ダッシュボード', icon: <DashboardIcon />, path: '/dashboard' },
    { divider: true, label: '運転者管理' },
    { text: 'ドライバー一覧', icon: <PersonIcon />, path: '/drivers' },
    { text: '運転者台帳', icon: <BadgeIcon />, path: '/registry' },
    { text: '健康診断', icon: <LocalHospitalIcon />, path: '/health' },
    { text: '適性診断', icon: <PsychologyIcon />, path: '/aptitude' },
    { text: '教育研修', icon: <SchoolIcon />, path: '/training' },
    { text: '事故・違反', icon: <WarningIcon />, path: '/accidents' },
    { divider: true, label: 'コンプライアンス' },
    { text: '点呼記録', icon: <FactCheckIcon />, path: '/compliance/tenko' },
    { text: '日常点検', icon: <CarRepairIcon />, path: '/compliance/inspections' },
    { text: 'タコグラフ', icon: <SpeedIcon />, path: '/compliance/tachograph' },
    { text: '監査出力', icon: <DescriptionIcon />, path: '/compliance/audit' },
];

const Layout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [mobileOpen, setMobileOpen] = useState(false);
    const navigate = useNavigate();
    const location = useLocation();
    const user = localStorage.getItem('user');
    const isLoggedIn = Boolean(user);

    const handleDrawerToggle = () => {
        setMobileOpen(!mobileOpen);
    };

    const handleLogout = () => {
        localStorage.removeItem('user');
        navigate('/login');
    };

    const drawer = (
        <Box>
            <Toolbar>
                <Typography variant="h6" fontWeight="bold" color="primary">
                    LogiTrace
                </Typography>
            </Toolbar>
            <Divider />
            <List>
                {menuItems.map((item, index) => {
                    if (item.divider) {
                        return (
                            <Box key={index}>
                                <Divider sx={{ mt: 1 }} />
                                <Typography variant="caption" sx={{ px: 2, py: 1, display: 'block', color: 'text.secondary' }}>
                                    {item.label}
                                </Typography>
                            </Box>
                        );
                    }
                    return (
                        <ListItem key={item.path} disablePadding>
                            <ListItemButton
                                component={Link}
                                to={item.path!}
                                selected={location.pathname === item.path}
                                onClick={() => setMobileOpen(false)}
                            >
                                <ListItemIcon sx={{ minWidth: 40 }}>{item.icon}</ListItemIcon>
                                <ListItemText primary={item.text} />
                            </ListItemButton>
                        </ListItem>
                    );
                })}
            </List>
            <Divider />
            <List>
                <ListItem disablePadding>
                    <ListItemButton onClick={handleLogout}>
                        <ListItemIcon sx={{ minWidth: 40 }}><LogoutIcon /></ListItemIcon>
                        <ListItemText primary="ログアウト" />
                    </ListItemButton>
                </ListItem>
            </List>
        </Box>
    );

    // 非ログイン状態のシンプルレイアウト
    if (!isLoggedIn || ['/', '/login', '/register', '/driver/setup'].includes(location.pathname)) {
        return (
            <>
                <AppBar position="static">
                    <Toolbar>
                        <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
                            <Link to="/" style={{ textDecoration: 'none', color: 'inherit' }}>
                                LogiTrace
                            </Link>
                        </Typography>
                        <Link to="/login" style={{ textDecoration: 'none', color: 'inherit', marginRight: '20px' }}>
                            ログイン
                        </Link>
                        <Link to="/register" style={{ textDecoration: 'none', color: 'inherit' }}>
                            無料で始める
                        </Link>
                    </Toolbar>
                </AppBar>
                <Container maxWidth="lg">
                    <Box sx={{ my: 4 }}>
                        {children}
                    </Box>
                </Container>
            </>
        );
    }

    // ログイン後のドロワー付きレイアウト
    return (
        <Box sx={{ display: 'flex' }}>
            <AppBar position="fixed" sx={{ zIndex: (theme) => theme.zIndex.drawer + 1 }}>
                <Toolbar>
                    <IconButton
                        color="inherit"
                        edge="start"
                        onClick={handleDrawerToggle}
                        sx={{ mr: 2, display: { md: 'none' } }}
                    >
                        <MenuIcon />
                    </IconButton>
                    <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
                        LogiTrace
                    </Typography>
                    <Button color="inherit" onClick={handleLogout} startIcon={<LogoutIcon />}>
                        ログアウト
                    </Button>
                </Toolbar>
            </AppBar>

            {/* モバイル用ドロワー */}
            <Drawer
                variant="temporary"
                open={mobileOpen}
                onClose={handleDrawerToggle}
                ModalProps={{ keepMounted: true }}
                sx={{
                    display: { xs: 'block', md: 'none' },
                    '& .MuiDrawer-paper': { boxSizing: 'border-box', width: drawerWidth },
                }}
            >
                {drawer}
            </Drawer>

            {/* デスクトップ用ドロワー */}
            <Drawer
                variant="permanent"
                sx={{
                    display: { xs: 'none', md: 'block' },
                    '& .MuiDrawer-paper': { boxSizing: 'border-box', width: drawerWidth },
                }}
                open
            >
                {drawer}
            </Drawer>

            {/* メインコンテンツ */}
            <Box
                component="main"
                sx={{
                    flexGrow: 1,
                    p: 3,
                    width: { md: `calc(100% - ${drawerWidth}px)` },
                    ml: { md: `${drawerWidth}px` },
                    mt: 8
                }}
            >
                {children}
            </Box>
        </Box>
    );
};

export default Layout;
