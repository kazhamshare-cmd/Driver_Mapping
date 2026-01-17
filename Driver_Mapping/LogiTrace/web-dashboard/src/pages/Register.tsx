import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { loadStripe } from '@stripe/stripe-js';
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js';
import { PlanType, getRecommendedPlan, getPlanById } from '../config/pricing-plans';
import {
    Alert,
    Box,
    Button,
    Checkbox,
    Container,
    FormControlLabel,
    Grid,
    Paper,
    Step,
    StepLabel,
    Stepper,
    TextField,
    Typography,
} from '@mui/material';
import UserPlus from '@mui/icons-material/PersonAdd';
import AlertCircle from '@mui/icons-material/ErrorOutline';

// Stripe Publishable Key from environment variable
const stripePromise = loadStripe(import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY || '');

const RegisterForm = ({ intentType, onSuccess }: { intentType: 'setup' | 'payment', onSuccess: () => void }) => {
    const stripe = useStripe();
    const elements = useElements();
    const [message, setMessage] = useState('');
    const [isLoading, setIsLoading] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!stripe || !elements) {
            return;
        }

        setIsLoading(true);

        const result = intentType === 'setup'
            ? await stripe.confirmSetup({
                elements,
                confirmParams: { return_url: window.location.origin + '/dashboard' },
                redirect: 'if_required'
            })
            : await stripe.confirmPayment({
                elements,
                confirmParams: { return_url: window.location.origin + '/dashboard' },
                redirect: 'if_required'
            });

        if (result.error) {
            setMessage(result.error.message || 'Payment failed');
            setIsLoading(false);
        } else {
            onSuccess();
        }
    };

    return (
        <form onSubmit={handleSubmit}>
            <PaymentElement />
            <Button
                disabled={isLoading || !stripe || !elements}
                fullWidth
                variant="contained"
                sx={{ mt: 3, mb: 2 }}
            >
                {isLoading ? '処理中...' : '登録してトライアル開始'}
            </Button>
            {message && <Alert severity="error">{message}</Alert>}
        </form>
    );
};

export default function Register() {
    const [searchParams] = useSearchParams();
    const [step, setStep] = useState(0);
    const [selectedPlanId, setSelectedPlanId] = useState<PlanType>(PlanType.STANDARD);
    const [driverCount, setDriverCount] = useState<number>(4);

    // User Info
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');

    // UI State
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);

    // Stripe State
    const [clientSecret, setClientSecret] = useState('');
    const [intentType, setIntentType] = useState<'setup' | 'payment'>('payment');

    const navigate = useNavigate();

    // Init from URL param
    useEffect(() => {
        const planParam = searchParams.get('plan');
        if (planParam && Object.values(PlanType).includes(planParam as PlanType)) {
            setSelectedPlanId(planParam as PlanType);
            const plan = getPlanById(planParam);
            if (plan) setDriverCount(plan.minDrivers);
        }
    }, [searchParams]);

    // Update Plan based on Driver Count
    useEffect(() => {
        const recommended = getRecommendedPlan(driverCount);
        if (recommended && recommended.id !== PlanType.ENTERPRISE) {
            setSelectedPlanId(recommended.id);
        }
    }, [driverCount]);

    const selectedPlan = getPlanById(selectedPlanId);

    const handleRegister = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        // Validation
        if (selectedPlan) {
            if (driverCount < selectedPlan.minDrivers) {
                setError(`${selectedPlan.name}は最低${selectedPlan.minDrivers}名のドライバーが必要です。`);
                setLoading(false);
                return;
            }
            if (selectedPlan.maxDrivers && driverCount > selectedPlan.maxDrivers) {
                setError(`${selectedPlan.name}は最大${selectedPlan.maxDrivers}名のドライバーまでです。`);
                setLoading(false);
                return;
            }
        }

        try {
            // 1. Register User
            const regResponse = await fetch('/api/auth/register', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name, email, password, user_type: 'admin' }),
            });
            const regData = await regResponse.json();
            if (!regResponse.ok) throw new Error(regData.error || 'Registration failed');

            const token = regData.token;
            localStorage.setItem('token', token);

            // 2. Create Subscription
            const subResponse = await fetch('/api/billing/create-subscription', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({
                    planId: selectedPlanId,
                    driverCount: driverCount
                }),
            });
            const subData = await subResponse.json();
            if (!subResponse.ok) throw new Error(subData.error || 'Subscription creation failed');

            setClientSecret(subData.clientSecret);
            setIntentType(subData.type);
            setStep(1);

        } catch (err: any) {
            setError(err.message || 'Registration failed. Please try again.');
        } finally {
            setLoading(false);
        }
    };

    const steps = ['プラン選択とアカウント作成', 'お支払い情報の入力'];

    return (
        <Container component="main" maxWidth="sm" sx={{ mb: 4 }}>
            <Paper variant="outlined" sx={{ my: { xs: 3, md: 6 }, p: { xs: 2, md: 3 } }}>
                <Typography component="h1" variant="h4" align="center">
                    LogiTrace
                </Typography>
                <Stepper activeStep={step} sx={{ pt: 3, pb: 5 }}>
                    {steps.map((label) => (
                        <Step key={label}>
                            <StepLabel>{label}</StepLabel>
                        </Step>
                    ))}
                </Stepper>
                {error && (
                    <Alert severity="error" icon={<AlertCircle fontSize="inherit" />} sx={{ mb: 2 }}>
                        {error}
                    </Alert>
                )}

                {step === 0 && (
                    <Box component="form" onSubmit={handleRegister}>
                        <Paper variant="outlined" sx={{ p: 3, mb: 3, backgroundColor: '#f8f9fa' }}>
                            <Typography variant="h6" gutterBottom>
                                利用するドライバー人数
                            </Typography>
                            <Grid container spacing={2} alignItems="center" justifyContent="center">
                                <Grid>
                                    <TextField
                                        type="number"
                                        InputProps={{ inputProps: { min: 1, max: 30 } }}
                                        value={driverCount}
                                        onChange={(e) => setDriverCount(parseInt(e.target.value) || 0)}
                                        sx={{ width: '100px', textAlign: 'center' }}
                                    />
                                </Grid>
                                <Grid>
                                    <Typography variant="h6">名</Typography>
                                </Grid>
                            </Grid>
                            {selectedPlan && (
                                <Box sx={{ mt: 2, pt: 2, borderTop: 1, borderColor: 'divider' }}>
                                    <Typography variant="body2" color="text.secondary">適用プラン</Typography>
                                    <Typography variant="h6" color="primary">{selectedPlan.name}</Typography>
                                    <Typography variant="h5" component="div">
                                        ¥{selectedPlan.price.toLocaleString()}
                                        <Typography variant="caption" color="text.secondary">/月</Typography>
                                    </Typography>
                                </Box>
                            )}
                        </Paper>

                        <Typography variant="h6" gutterBottom>
                            アカウント情報
                        </Typography>
                        <Grid container spacing={2}>
                            <Grid size={12}>
                                <TextField
                                    required
                                    id="name"
                                    name="name"
                                    label="お名前"
                                    fullWidth
                                    autoComplete="name"
                                    value={name}
                                    onChange={(e) => setName(e.target.value)}
                                />
                            </Grid>
                            <Grid size={12}>
                                <TextField
                                    required
                                    id="email"
                                    name="email"
                                    label="メールアドレス"
                                    fullWidth
                                    autoComplete="email"
                                    value={email}
                                    onChange={(e) => setEmail(e.target.value)}
                                />
                            </Grid>
                            <Grid size={12}>
                                <TextField
                                    required
                                    id="password"
                                    name="password"
                                    label="パスワード"
                                    type="password"
                                    fullWidth
                                    autoComplete="new-password"
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    inputProps={{ minLength: 6 }}
                                />
                            </Grid>
                            <Grid size={12}>
                                <FormControlLabel
                                    control={<Checkbox color="primary" required />}
                                    label={
                                        <Typography variant="body2">
                                            <Link to="https://b19.co.jp/terms-of-service/" target="_blank" rel="noreferrer">利用規約</Link>
                                            と
                                            <Link to="https://b19.co.jp/privacy-policy/" target="_blank" rel="noreferrer">プライバシーポリシー</Link>
                                            に同意します
                                        </Typography>
                                    }
                                />
                            </Grid>
                        </Grid>
                        <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
                            <Button
                                variant="contained"
                                type="submit"
                                sx={{ mt: 3, ml: 1 }}
                                disabled={loading}
                                startIcon={<UserPlus />}
                            >
                                {loading ? '処理中...' : '次へ進む'}
                            </Button>
                        </Box>
                    </Box>
                )}

                {step === 1 && clientSecret && (
                    <>
                        <Typography variant="h6" gutterBottom>
                            クレジットカード情報
                        </Typography>

                        {/* Trial Period Notice */}
                        <Paper
                            sx={{
                                p: 2,
                                mb: 3,
                                backgroundColor: '#e3f2fd',
                                border: '1px solid #1976d2'
                            }}
                        >
                            <Typography variant="subtitle1" color="primary" fontWeight="bold" gutterBottom>
                                14日間無料トライアル
                            </Typography>
                            <Typography variant="body2" sx={{ mb: 1 }}>
                                ・ 今日からすべての機能を無料でお試しいただけます
                            </Typography>
                            <Typography variant="body2" sx={{ mb: 1 }}>
                                ・ トライアル期間中はいつでもキャンセル可能（課金なし）
                            </Typography>
                            <Typography variant="body2" sx={{ mb: 1 }}>
                                ・ キャンセルしない場合、14日後に自動的に有料プランへ移行
                            </Typography>
                            <Box sx={{ mt: 2, pt: 2, borderTop: '1px solid #1976d2' }}>
                                <Typography variant="body2" color="text.secondary">
                                    トライアル終了後の料金:
                                </Typography>
                                <Typography variant="h6" color="primary">
                                    {selectedPlan?.name} ¥{selectedPlan?.price.toLocaleString()}/月
                                </Typography>
                            </Box>
                        </Paper>

                        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                            ※ クレジットカード情報は安全に保管され、トライアル終了後の課金に使用されます。<br />
                            ※ トライアル期間中にダッシュボードからいつでもキャンセルできます。
                        </Typography>

                        <Elements stripe={stripePromise} options={{ clientSecret }}>
                            <RegisterForm
                                intentType={intentType}
                                onSuccess={() => { alert('登録完了！14日間の無料トライアルが開始されました。'); navigate('/dashboard'); }}
                            />
                        </Elements>
                    </>
                )}

                <Typography variant="body2" color="text.secondary" align="center" sx={{ mt: 3 }}>
                    すでにアカウントをお持ちですか？ <Link to="/login">ログイン</Link>
                </Typography>
            </Paper>
        </Container>
    );
}
