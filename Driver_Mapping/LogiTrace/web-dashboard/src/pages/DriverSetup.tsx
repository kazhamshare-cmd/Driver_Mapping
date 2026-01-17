import { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
    Box,
    Card,
    CardContent,
    Typography,
    TextField,
    Button,
    Alert,
    CircularProgress
} from '@mui/material';

export default function DriverSetup() {
    const [searchParams] = useSearchParams();
    const token = searchParams.get('token');

    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState(false);

    useEffect(() => {
        if (!token) {
            setError('無効なリンクです');
        }
    }, [token]);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (password !== confirmPassword) {
            setError('パスワードが一致しません');
            return;
        }

        if (password.length < 6) {
            setError('パスワードは6文字以上で入力してください');
            return;
        }

        setLoading(true);
        setError('');

        try {
            const response = await fetch('/api/drivers/setup-password', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ token, password })
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || 'パスワードの設定に失敗しました');
            }

            setSuccess(true);
        } catch (err: any) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    if (!token) {
        return (
            <Box
                display="flex"
                justifyContent="center"
                alignItems="center"
                minHeight="100vh"
                bgcolor="#f5f5f5"
            >
                <Card sx={{ maxWidth: 400, width: '100%', mx: 2 }}>
                    <CardContent>
                        <Alert severity="error">無効なリンクです</Alert>
                    </CardContent>
                </Card>
            </Box>
        );
    }

    if (success) {
        return (
            <Box
                display="flex"
                justifyContent="center"
                alignItems="center"
                minHeight="100vh"
                bgcolor="#f5f5f5"
            >
                <Card sx={{ maxWidth: 400, width: '100%', mx: 2 }}>
                    <CardContent sx={{ textAlign: 'center' }}>
                        <Typography variant="h5" gutterBottom color="primary">
                            設定完了
                        </Typography>
                        <Typography color="text.secondary" sx={{ mb: 3 }}>
                            パスワードの設定が完了しました。<br />
                            モバイルアプリからログインしてください。
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            アプリをダウンロードして、登録したメールアドレスとパスワードでログインできます。
                        </Typography>
                    </CardContent>
                </Card>
            </Box>
        );
    }

    return (
        <Box
            display="flex"
            justifyContent="center"
            alignItems="center"
            minHeight="100vh"
            bgcolor="#f5f5f5"
        >
            <Card sx={{ maxWidth: 400, width: '100%', mx: 2 }}>
                <CardContent>
                    <Typography variant="h5" gutterBottom textAlign="center">
                        LogiTrace
                    </Typography>
                    <Typography variant="subtitle1" color="text.secondary" textAlign="center" sx={{ mb: 3 }}>
                        パスワード設定
                    </Typography>

                    {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

                    <form onSubmit={handleSubmit}>
                        <TextField
                            label="パスワード"
                            type="password"
                            fullWidth
                            margin="normal"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            required
                            helperText="6文字以上"
                        />
                        <TextField
                            label="パスワード（確認）"
                            type="password"
                            fullWidth
                            margin="normal"
                            value={confirmPassword}
                            onChange={(e) => setConfirmPassword(e.target.value)}
                            required
                        />
                        <Button
                            type="submit"
                            variant="contained"
                            fullWidth
                            size="large"
                            disabled={loading}
                            sx={{ mt: 2 }}
                        >
                            {loading ? <CircularProgress size={24} /> : '設定する'}
                        </Button>
                    </form>
                </CardContent>
            </Card>
        </Box>
    );
}
