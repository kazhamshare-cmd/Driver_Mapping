import React, { useState } from 'react';
import { useNavigate, Link as RouterLink } from 'react-router-dom';
import {
    Box,
    Button,
    Container,
    TextField,
    Typography,
    Paper,
    FormControlLabel,
    Checkbox,
    Link,
    Grid,
    InputAdornment,
    IconButton,
    useTheme,
    useMediaQuery,
    Chip,
    CircularProgress,
    Alert,
    Divider
} from '@mui/material';
import {
    Visibility,
    VisibilityOff,
    EmailOutlined,
    LockOutlined,
    LocalShipping,
    PlayArrow
} from '@mui/icons-material';

// Demo account credentials
const DEMO_EMAIL = 'demo@logitrace.jp';
const DEMO_PASSWORD = 'demo1234';

const Login = () => {
    const navigate = useNavigate();
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('md'));
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            const response = await fetch('/api/auth/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password }),
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || 'ログインに失敗しました');
            }

            // Store user data and token
            localStorage.setItem('user', JSON.stringify({
                id: data.user.id,
                name: data.user.name,
                email: data.user.email,
                userType: data.user.user_type,
                companyId: data.user.company_id || 1,
                token: data.token
            }));

            navigate('/dashboard');
        } catch (err) {
            setError(err instanceof Error ? err.message : 'ログインに失敗しました');
        } finally {
            setLoading(false);
        }
    };

    const handleDemoLogin = async () => {
        setEmail(DEMO_EMAIL);
        setPassword(DEMO_PASSWORD);
        setError('');
    };

    return (
        <Grid container sx={{ minHeight: '100vh', bgcolor: 'white' }}>
            {/* Left Side: Visual Area */}
            <Grid size={{ xs: 12, md: 6 }} sx={{
                position: 'relative',
                bgcolor: '#0a1929',
                display: { xs: 'none', md: 'flex' },
                flexDirection: 'column',
                justifyContent: 'flex-end',
                p: 6,
                overflow: 'hidden'
            }}>
                {/* CSS-based Background Effect (Abstract logistics network) */}
                <Box sx={{
                    position: 'absolute',
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    opacity: 0.6,
                    background: `
                        radial-gradient(circle at 20% 30%, rgba(33, 150, 243, 0.3) 0%, transparent 50%),
                        radial-gradient(circle at 80% 70%, rgba(76, 175, 80, 0.3) 0%, transparent 50%),
                        linear-gradient(135deg, rgba(26, 35, 126, 0.95) 0%, rgba(13, 71, 161, 0.95) 100%)
                    `,
                    zIndex: 1
                }} />

                {/* Simulated Network Nodes/Lines */}
                <Box sx={{
                    position: 'absolute',
                    top: '20%',
                    left: '10%',
                    width: '80%',
                    height: '60%',
                    border: '1px solid rgba(255,255,255,0.1)',
                    borderRadius: '50%',
                    transform: 'rotate(-15deg)',
                    zIndex: 0
                }} />
                <Box sx={{
                    position: 'absolute',
                    top: '30%',
                    right: '-10%',
                    width: '60%',
                    height: '60%',
                    border: '1px dashed rgba(255,255,255,0.1)',
                    borderRadius: '50%',
                    zIndex: 0
                }} />

                <Box position="relative" zIndex={2} color="white" mb={4}>
                    <Box display="flex" alignItems="center" gap={2} mb={3}>
                        <Box p={1} bgcolor="rgba(255,255,255,0.1)" borderRadius={2} display="flex">
                            <LocalShipping sx={{ fontSize: 32, color: '#4fc3f7' }} />
                        </Box>
                        <Typography variant="h5" fontWeight="bold" sx={{ letterSpacing: 1 }}>
                            LogiTrace
                        </Typography>
                        <Chip label="SaaS Platform" size="small" sx={{ bgcolor: 'rgba(255,255,255,0.2)', color: 'white', fontWeight: 'bold' }} />
                    </Box>
                    <Typography variant="h3" fontWeight="800" sx={{ mb: 2, lineHeight: 1.2 }}>
                        配送業務のすべてを、<br />
                        <span style={{ color: '#4fc3f7' }}>ひとつの場所で。</span>
                    </Typography>
                    <Typography variant="h6" sx={{ color: 'rgba(255,255,255,0.7)', fontWeight: 'normal', mb: 4, lineHeight: 1.6 }}>
                        リアルタイムな動態管理から、<br />
                        法令遵守のための帳票作成まで。<br />
                        次世代の物流管理プラットフォーム。
                    </Typography>

                    <Paper sx={{
                        p: 3,
                        bgcolor: 'rgba(0, 0, 0, 0.4)',
                        backdropFilter: 'blur(10px)',
                        border: '1px solid rgba(255,255,255,0.1)',
                        borderRadius: 3,
                        maxWidth: 400
                    }}>
                        <Box display="flex" alignItems="flex-start" gap={2}>
                            <Box sx={{ p: 0.5, bgcolor: 'rgba(76, 175, 80, 0.2)', borderRadius: 1 }}>
                                <Visibility sx={{ color: '#66bb6a' }} />
                            </Box>
                            <Box>
                                <Typography variant="subtitle2" sx={{ color: 'white', fontWeight: 'bold' }}>業務効率 40% UP</Typography>
                                <Typography variant="caption" sx={{ color: 'rgba(255,255,255,0.7)' }}>
                                    過去の導入実績に基づく平均的な改善効果です。
                                </Typography>
                            </Box>
                        </Box>
                    </Paper>
                </Box>
            </Grid>

            {/* Right Side: Login Form */}
            <Grid size={{ xs: 12, md: 6 }} sx={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                bgcolor: '#ffffff',
                p: 4
            }}>
                <Container maxWidth="xs">
                    <Box sx={{ textAlign: 'center', mb: 4 }}>
                        {isMobile && (
                            <Box display="flex" justifyContent="center" mb={2}>
                                <LocalShipping color="primary" sx={{ fontSize: 40 }} />
                            </Box>
                        )}
                        <Typography variant="h4" fontWeight="800" gutterBottom sx={{ color: '#1a237e' }}>
                            おかえりなさい
                        </Typography>
                        <Typography color="text.secondary">
                            アカウントにログインして管理を始めましょう
                        </Typography>
                    </Box>

                    {/* Demo Login Alert */}
                    <Paper
                        elevation={0}
                        sx={{
                            p: 2,
                            mb: 3,
                            backgroundColor: '#f1f8e9',
                            border: '1px dashed #66bb6a',
                            borderRadius: 2,
                            textAlign: 'left'
                        }}
                    >
                        <Box display="flex" justifyContent="space-between" alignItems="center">
                            <Box>
                                <Typography variant="subtitle2" color="success.main" fontWeight="bold">
                                    デモ環境をお試しですか？
                                </Typography>
                                <Typography variant="caption" color="text.secondary">
                                    登録不要ですぐに使えます
                                </Typography>
                            </Box>
                            <Button
                                size="small"
                                variant="contained"
                                color="success"
                                startIcon={<PlayArrow />}
                                onClick={handleDemoLogin}
                                sx={{ fontWeight: 'bold', boxShadow: 'none' }}
                            >
                                入力する
                            </Button>
                        </Box>
                    </Paper>

                    <form onSubmit={handleLogin}>
                        <Box sx={{ mb: 3 }}>
                            <TextField
                                fullWidth
                                label="メールアドレス"
                                placeholder="name@company.com"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                margin="normal"
                                required
                                disabled={loading}
                                InputProps={{
                                    startAdornment: (
                                        <InputAdornment position="start">
                                            <EmailOutlined color="action" />
                                        </InputAdornment>
                                    ),
                                }}
                                sx={{
                                    '& .MuiOutlinedInput-root': { borderRadius: 2 }
                                }}
                            />
                            <TextField
                                fullWidth
                                label="パスワード"
                                type={showPassword ? 'text' : 'password'}
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                margin="normal"
                                required
                                disabled={loading}
                                InputProps={{
                                    startAdornment: (
                                        <InputAdornment position="start">
                                            <LockOutlined color="action" />
                                        </InputAdornment>
                                    ),
                                    endAdornment: (
                                        <InputAdornment position="end">
                                            <IconButton
                                                onClick={() => setShowPassword(!showPassword)}
                                                edge="end"
                                            >
                                                {showPassword ? <VisibilityOff /> : <Visibility />}
                                            </IconButton>
                                        </InputAdornment>
                                    ),
                                }}
                                sx={{
                                    '& .MuiOutlinedInput-root': { borderRadius: 2 }
                                }}
                            />
                        </Box>

                        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                            <FormControlLabel
                                control={<Checkbox color="primary" />}
                                label={<Typography variant="body2">ログイン状態を保存</Typography>}
                            />
                            <Link component={RouterLink} to="/forgot-password" variant="body2" underline="hover" fontWeight="bold">
                                パスワードをお忘れですか？
                            </Link>
                        </Box>

                        {error && (
                            <Alert severity="error" sx={{ mb: 3, borderRadius: 2 }}>
                                {error}
                            </Alert>
                        )}

                        <Button
                            type="submit"
                            fullWidth
                            variant="contained"
                            size="large"
                            disabled={loading}
                            sx={{
                                py: 1.5,
                                mb: 3,
                                borderRadius: 2,
                                fontSize: '1rem',
                                fontWeight: 'bold',
                                textTransform: 'none',
                                boxShadow: '0 4px 12px rgba(33, 150, 243, 0.3)',
                                background: 'linear-gradient(45deg, #1976d2 30%, #2196f3 90%)',
                            }}
                        >
                            {loading ? <CircularProgress size={24} color="inherit" /> : 'ログイン'}
                        </Button>

                        <Divider sx={{ mb: 3 }}>
                            <Typography variant="caption" color="text.secondary">または</Typography>
                        </Divider>

                        <Box sx={{ textAlign: 'center' }}>
                            <Typography variant="body2" color="text.secondary">
                                アカウントをお持ちでないですか？{' '}
                                <Link component={RouterLink} to="/register" fontWeight="bold" underline="hover" sx={{ color: '#1976d2' }}>
                                    無料でアカウント作成
                                </Link>
                            </Typography>
                        </Box>
                    </form>
                </Container>
            </Grid>
        </Grid>
    );
};

export default Login;
