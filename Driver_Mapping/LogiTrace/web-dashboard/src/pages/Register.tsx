import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { UserPlus, AlertCircle } from 'lucide-react';
import { loadStripe } from '@stripe/stripe-js';
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js';
import { PlanType, getRecommendedPlan, getPlanById } from '../config/pricing-plans';

// TODO: Replace with your actual Stripe Publishable Key
const stripePromise = loadStripe('pk_test_PLACEHOLDER');

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
        <form onSubmit={handleSubmit} style={{ textAlign: 'left' }}>
            <PaymentElement />
            <button
                disabled={isLoading || !stripe || !elements}
                className="btn btn-primary"
                style={{ width: '100%', marginTop: '20px', padding: '12px' }}
            >
                {isLoading ? '処理中...' : '登録してトライアル開始'}
            </button>
            {message && <div style={{ color: 'red', marginTop: '10px' }}>{message}</div>}
        </form>
    );
};

export default function Register() {
    const [searchParams] = useSearchParams();
    const [step, setStep] = useState(1);
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
            const regResponse = await fetch('http://52.69.62.236:3000/auth/register', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name, email, password, user_type: 'admin' }),
            });
            const regData = await regResponse.json();
            if (!regResponse.ok) throw new Error(regData.error || 'Registration failed');

            const token = regData.token;
            localStorage.setItem('token', token);

            // 2. Create Subscription
            const subResponse = await fetch('http://52.69.62.236:3000/billing/create-subscription', {
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
            setStep(2);

        } catch (err: any) {
            setError(err.message || 'Registration failed. Please try again.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh', background: 'linear-gradient(135deg, #e8f5e9 0%, #e3f2fd 100%)', padding: '20px' }}>
            <div className="card" style={{ width: '100%', maxWidth: '500px', textAlign: 'center' }}>
                <h1 style={{ color: 'var(--primary-color)', marginBottom: '8px' }}>LogiTrace</h1>
                <p style={{ color: 'var(--text-secondary)', marginBottom: '24px' }}>
                    {step === 1 ? 'プラン選択とアカウント作成' : 'お支払い情報の入力'}
                </p>

                {error && (
                    <div style={{ backgroundColor: '#ffebee', color: '#c62828', padding: '12px', borderRadius: '8px', marginBottom: '20px', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <AlertCircle size={16} /> {error}
                    </div>
                )}

                {step === 1 && (
                    <form onSubmit={handleRegister}>
                        {/* Driver Count Input */}
                        <div style={{ marginBottom: '24px', backgroundColor: '#f8f9fa', padding: '20px', borderRadius: '12px' }}>
                            <label style={{ display: 'block', fontSize: '14px', fontWeight: 'bold', marginBottom: '8px', color: '#555' }}>
                                利用するドライバー人数 (1〜30名)
                            </label>
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px' }}>
                                <input
                                    type="number"
                                    min="1"
                                    max="30"
                                    value={driverCount}
                                    onChange={(e) => setDriverCount(parseInt(e.target.value) || 0)}
                                    style={{ width: '80px', textAlign: 'center', fontSize: '18px', padding: '8px' }}
                                />
                                <span style={{ fontWeight: 'bold' }}>名</span>
                            </div>

                            {selectedPlan && (
                                <div style={{ marginTop: '16px', borderTop: '1px solid #ddd', paddingTop: '16px' }}>
                                    <div style={{ fontSize: '12px', color: '#777', marginBottom: '4px' }}>適用プラン</div>
                                    <div style={{ fontSize: '18px', fontWeight: 'bold', color: 'var(--primary-color)' }}>{selectedPlan.name}</div>
                                    <div style={{ fontSize: '24px', fontWeight: 'bold', marginTop: '4px' }}>¥{selectedPlan.price.toLocaleString()}<span style={{ fontSize: '14px', fontWeight: 'normal', color: '#666' }}>/月</span></div>
                                </div>
                            )}
                        </div>

                        {/* Account Info */}
                        <div style={{ textAlign: 'left', marginBottom: '8px' }}>
                            <label style={{ fontSize: '14px', fontWeight: 'bold', color: '#666' }}>お名前</label>
                        </div>
                        <input
                            type="text"
                            value={name}
                            onChange={(e) => setName(e.target.value)}
                            placeholder="山田 太郎"
                            required
                        />

                        <div style={{ textAlign: 'left', marginBottom: '8px' }}>
                            <label style={{ fontSize: '14px', fontWeight: 'bold', color: '#666' }}>メールアドレス</label>
                        </div>
                        <input
                            type="email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            placeholder="admin@company.com"
                            required
                        />

                        <div style={{ textAlign: 'left', marginBottom: '8px' }}>
                            <label style={{ fontSize: '14px', fontWeight: 'bold', color: '#666' }}>パスワード</label>
                        </div>
                        <input
                            type="password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            placeholder="••••••••"
                            required
                            minLength={6}
                        />

                        <div style={{ textAlign: 'left', marginBottom: '24px' }}>
                            <label style={{ display: 'flex', alignItems: 'flex-start', gap: '8px', fontSize: '14px', color: '#555', cursor: 'pointer' }}>
                                <input type="checkbox" required style={{ marginTop: '4px', width: 'auto' }} />
                                <span>
                                    <a href="https://b19.co.jp/terms-of-service/" target="_blank" rel="noreferrer" style={{ color: 'var(--primary-color)', fontWeight: 'bold' }}>利用規約</a>
                                    と
                                    <a href="https://b19.co.jp/privacy-policy/" target="_blank" rel="noreferrer" style={{ color: 'var(--primary-color)', fontWeight: 'bold' }}>プライバシーポリシー</a>
                                    に同意します
                                </span>
                            </label>
                        </div>

                        <button type="submit" className="btn btn-primary" style={{ width: '100%', padding: '14px' }} disabled={loading}>
                            <UserPlus size={20} />
                            {loading ? '処理中...' : '次へ進む'}
                        </button>
                    </form>
                )}

                {step === 2 && clientSecret && (
                    <Elements stripe={stripePromise} options={{ clientSecret }}>
                        <div style={{ marginBottom: '20px', textAlign: 'left' }}>
                            <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>クレジットカード情報</div>
                            <div style={{ fontSize: '12px', color: '#666' }}>
                                ※ 14日間の無料トライアル期間中は請求されません。<br />
                                ※ トライアル終了後、{selectedPlan?.name || '選択プラン'} (¥{selectedPlan?.price.toLocaleString()}/月) が自動的に課金されます。
                            </div>
                        </div>
                        <RegisterForm
                            intentType={intentType}
                            onSuccess={() => { alert('登録完了！'); navigate('/dashboard'); }}
                        />
                    </Elements>
                )}

                <p style={{ marginTop: '24px', fontSize: '14px', color: '#999' }}>
                    すでにアカウントをお持ちですか？ <Link to="/login" style={{ color: 'var(--primary-color)', fontWeight: 'bold' }}>ログイン</Link>
                </p>
            </div>
        </div>
    );
}
