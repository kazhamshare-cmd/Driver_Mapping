import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { UserPlus, AlertCircle, CheckCircle, CreditCard } from 'lucide-react';
import { loadStripe } from '@stripe/stripe-js';
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js';
import { PlanType, getRecommendedPlan, getPlanById, getDisplayPlans } from '../config/pricing-plans';

// TODO: Replace with your actual Stripe Publishable Key
const stripePromise = loadStripe('pk_test_PLACEHOLDER');

const API_BASE = 'http://52.69.62.236:3000';

interface RegisterFormProps {
    selectedPlanId: PlanType;
    driverCount: number;
    name: string;
    email: string;
    password: string;
    setError: (error: string) => void;
    setLoading: (loading: boolean) => void;
}

const RegisterFormWithPayment = ({
    selectedPlanId,
    driverCount,
    name,
    email,
    password,
    setError,
    setLoading
}: RegisterFormProps) => {
    const stripe = useStripe();
    const elements = useElements();
    const navigate = useNavigate();
    const [isProcessing, setIsProcessing] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!stripe || !elements) {
            return;
        }

        setIsProcessing(true);
        setError('');

        try {
            // 1. Confirm the setup intent to get the payment method
            const { error: submitError, setupIntent } = await stripe.confirmSetup({
                elements,
                confirmParams: {
                    return_url: window.location.origin + '/dashboard',
                },
                redirect: 'if_required'
            });

            if (submitError) {
                setError(submitError.message || 'Payment method setup failed');
                setIsProcessing(false);
                return;
            }

            if (!setupIntent || !setupIntent.payment_method) {
                setError('Payment method could not be retrieved');
                setIsProcessing(false);
                return;
            }

            const paymentMethodId = setupIntent.payment_method as string;

            // 2. Register User
            const regResponse = await fetch(`${API_BASE}/auth/register`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name, email, password, user_type: 'admin' }),
            });
            const regData = await regResponse.json();
            if (!regResponse.ok) throw new Error(regData.error || 'Registration failed');

            const token = regData.token;
            localStorage.setItem('token', token);

            // 3. Create Subscription with Payment Method
            const subResponse = await fetch(`${API_BASE}/billing/create-subscription`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
                },
                body: JSON.stringify({
                    planId: selectedPlanId,
                    driverCount: driverCount,
                    paymentMethodId: paymentMethodId
                }),
            });
            const subData = await subResponse.json();
            if (!subResponse.ok) throw new Error(subData.error || 'Subscription creation failed');

            // Success!
            alert('登録完了！14日間の無料トライアルが開始されました。');
            navigate('/dashboard');

        } catch (err: any) {
            setError(err.message || 'Registration failed. Please try again.');
        } finally {
            setIsProcessing(false);
            setLoading(false);
        }
    };

    return (
        <form onSubmit={handleSubmit}>
            <div style={{ marginBottom: '24px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                    <CreditCard size={20} color="var(--primary-color)" />
                    <span style={{ fontWeight: 'bold', color: '#333' }}>クレジットカード情報</span>
                </div>
                <div style={{
                    backgroundColor: '#f8f9fa',
                    padding: '16px',
                    borderRadius: '8px',
                    border: '1px solid #e0e0e0'
                }}>
                    <PaymentElement />
                </div>
                <p style={{ fontSize: '12px', color: '#666', marginTop: '8px' }}>
                    ※ 14日間は完全無料。15日目から自動課金開始。
                </p>
            </div>

            <button
                type="submit"
                className="btn btn-primary"
                style={{ width: '100%', padding: '14px', fontSize: '16px' }}
                disabled={isProcessing || !stripe || !elements}
            >
                <UserPlus size={20} style={{ marginRight: '8px' }} />
                {isProcessing ? '処理中...' : '登録してトライアル開始'}
            </button>
        </form>
    );
};

export default function Register() {
    const [searchParams] = useSearchParams();
    const navigate = useNavigate();

    // Plan & Driver
    const [selectedPlanId, setSelectedPlanId] = useState<PlanType>(PlanType.STARTER);
    const [driverCount, setDriverCount] = useState<number>(4);

    // User Info
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [agreed, setAgreed] = useState(false);

    // UI State
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);

    // Stripe State
    const [clientSecret, setClientSecret] = useState('');
    const [setupIntentLoading, setSetupIntentLoading] = useState(true);

    // Fetch Setup Intent on mount
    useEffect(() => {
        const fetchSetupIntent = async () => {
            try {
                const response = await fetch(`${API_BASE}/billing/create-setup-intent`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                });
                const data = await response.json();
                if (data.clientSecret) {
                    setClientSecret(data.clientSecret);
                }
            } catch (err) {
                console.error('Failed to create setup intent:', err);
            } finally {
                setSetupIntentLoading(false);
            }
        };
        fetchSetupIntent();
    }, []);

    // Init from URL param
    useEffect(() => {
        const planParam = searchParams.get('plan');
        if (planParam && Object.values(PlanType).includes(planParam as PlanType)) {
            setSelectedPlanId(planParam as PlanType);
            const plan = getPlanById(planParam);
            if (plan) setDriverCount(Math.max(plan.minDrivers, 4));
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
    const displayPlans = getDisplayPlans();

    // Validate form before showing payment
    const isFormValid = name.trim() !== '' && email.trim() !== '' && password.length >= 6 && agreed;

    return (
        <div style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'flex-start',
            minHeight: '100vh',
            background: 'linear-gradient(135deg, #e8f5e9 0%, #e3f2fd 100%)',
            padding: '40px 20px'
        }}>
            <div className="card" style={{ width: '100%', maxWidth: '600px' }}>
                <div style={{ textAlign: 'center', marginBottom: '24px' }}>
                    <Link to="/" style={{ textDecoration: 'none' }}>
                        <h1 style={{ color: 'var(--primary-color)', marginBottom: '8px' }}>LogiTrace</h1>
                    </Link>
                    <p style={{ color: 'var(--text-secondary)' }}>
                        アカウント作成 & 14日間無料トライアル開始
                    </p>
                </div>

                {error && (
                    <div style={{
                        backgroundColor: '#ffebee',
                        color: '#c62828',
                        padding: '12px',
                        borderRadius: '8px',
                        marginBottom: '20px',
                        fontSize: '14px',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px'
                    }}>
                        <AlertCircle size={16} /> {error}
                    </div>
                )}

                {/* Plan Selection */}
                <div style={{ marginBottom: '24px' }}>
                    <label style={{ display: 'block', fontSize: '14px', fontWeight: 'bold', marginBottom: '12px', color: '#555' }}>
                        プランを選択
                    </label>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px' }}>
                        {displayPlans.map((plan) => (
                            <div
                                key={plan.id}
                                onClick={() => {
                                    setSelectedPlanId(plan.id);
                                    if (driverCount < plan.minDrivers) {
                                        setDriverCount(plan.minDrivers);
                                    } else if (plan.maxDrivers && driverCount > plan.maxDrivers) {
                                        setDriverCount(plan.maxDrivers);
                                    }
                                }}
                                style={{
                                    padding: '16px',
                                    borderRadius: '12px',
                                    border: selectedPlanId === plan.id ? '2px solid var(--primary-color)' : '1px solid #ddd',
                                    backgroundColor: selectedPlanId === plan.id ? '#e3f2fd' : '#fff',
                                    cursor: 'pointer',
                                    textAlign: 'center',
                                    position: 'relative',
                                    transition: 'all 0.2s ease'
                                }}
                            >
                                {plan.recommended && (
                                    <div style={{
                                        position: 'absolute',
                                        top: '-8px',
                                        left: '50%',
                                        transform: 'translateX(-50%)',
                                        backgroundColor: 'var(--primary-color)',
                                        color: '#fff',
                                        padding: '2px 8px',
                                        borderRadius: '10px',
                                        fontSize: '10px',
                                        fontWeight: 'bold'
                                    }}>
                                        人気
                                    </div>
                                )}
                                <div style={{ fontWeight: 'bold', marginBottom: '4px' }}>{plan.name}</div>
                                <div style={{ fontSize: '18px', fontWeight: 'bold', color: 'var(--primary-color)' }}>
                                    {plan.price > 0 ? `¥${plan.price.toLocaleString()}` : 'お問い合わせ'}
                                </div>
                                <div style={{ fontSize: '12px', color: '#666' }}>
                                    {plan.price > 0 ? '/月' : ''}
                                </div>
                                <div style={{ fontSize: '11px', color: '#888', marginTop: '4px' }}>
                                    {plan.maxDrivers ? `〜${plan.maxDrivers}名` : `${plan.minDrivers}名〜`}
                                </div>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Driver Count */}
                <div style={{ marginBottom: '24px', backgroundColor: '#f8f9fa', padding: '16px', borderRadius: '12px' }}>
                    <label style={{ display: 'block', fontSize: '14px', fontWeight: 'bold', marginBottom: '8px', color: '#555' }}>
                        ドライバー人数
                    </label>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <input
                            type="number"
                            min={selectedPlan?.minDrivers || 1}
                            max={selectedPlan?.maxDrivers || 999}
                            value={driverCount}
                            onChange={(e) => setDriverCount(parseInt(e.target.value) || 1)}
                            style={{ width: '80px', textAlign: 'center', fontSize: '18px', padding: '8px' }}
                        />
                        <span style={{ fontWeight: 'bold' }}>名</span>
                        {selectedPlan && (
                            <span style={{ fontSize: '14px', color: '#666', marginLeft: 'auto' }}>
                                {selectedPlan.name}: ¥{selectedPlan.price.toLocaleString()}/月
                            </span>
                        )}
                    </div>
                </div>

                {/* Account Info */}
                <div style={{ marginBottom: '24px' }}>
                    <div style={{ marginBottom: '16px' }}>
                        <label style={{ display: 'block', fontSize: '14px', fontWeight: 'bold', marginBottom: '6px', color: '#555' }}>
                            お名前
                        </label>
                        <input
                            type="text"
                            value={name}
                            onChange={(e) => setName(e.target.value)}
                            placeholder="山田 太郎"
                            required
                            style={{ width: '100%' }}
                        />
                    </div>

                    <div style={{ marginBottom: '16px' }}>
                        <label style={{ display: 'block', fontSize: '14px', fontWeight: 'bold', marginBottom: '6px', color: '#555' }}>
                            メールアドレス
                        </label>
                        <input
                            type="email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            placeholder="admin@company.com"
                            required
                            style={{ width: '100%' }}
                        />
                    </div>

                    <div style={{ marginBottom: '16px' }}>
                        <label style={{ display: 'block', fontSize: '14px', fontWeight: 'bold', marginBottom: '6px', color: '#555' }}>
                            パスワード（6文字以上）
                        </label>
                        <input
                            type="password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            placeholder="••••••••"
                            required
                            minLength={6}
                            style={{ width: '100%' }}
                        />
                    </div>

                    <div>
                        <label style={{ display: 'flex', alignItems: 'flex-start', gap: '8px', fontSize: '14px', color: '#555', cursor: 'pointer' }}>
                            <input
                                type="checkbox"
                                checked={agreed}
                                onChange={(e) => setAgreed(e.target.checked)}
                                style={{ marginTop: '4px', width: 'auto' }}
                            />
                            <span>
                                <a href="https://b19.co.jp/terms-of-service/" target="_blank" rel="noreferrer" style={{ color: 'var(--primary-color)', fontWeight: 'bold' }}>利用規約</a>
                                と
                                <a href="https://b19.co.jp/privacy-policy/" target="_blank" rel="noreferrer" style={{ color: 'var(--primary-color)', fontWeight: 'bold' }}>プライバシーポリシー</a>
                                に同意します
                            </span>
                        </label>
                    </div>
                </div>

                {/* Payment Section */}
                {isFormValid && clientSecret ? (
                    <Elements stripe={stripePromise} options={{ clientSecret }}>
                        <RegisterFormWithPayment
                            selectedPlanId={selectedPlanId}
                            driverCount={driverCount}
                            name={name}
                            email={email}
                            password={password}
                            setError={setError}
                            setLoading={setLoading}
                        />
                    </Elements>
                ) : (
                    <div>
                        {!isFormValid && (
                            <div style={{
                                backgroundColor: '#fff3e0',
                                padding: '16px',
                                borderRadius: '8px',
                                marginBottom: '16px',
                                fontSize: '14px',
                                color: '#e65100'
                            }}>
                                すべての項目を入力し、利用規約に同意してください
                            </div>
                        )}
                        {setupIntentLoading && (
                            <div style={{ textAlign: 'center', padding: '20px', color: '#666' }}>
                                決済フォームを読み込み中...
                            </div>
                        )}
                        <button
                            type="button"
                            className="btn btn-primary"
                            style={{ width: '100%', padding: '14px', fontSize: '16px', opacity: 0.5 }}
                            disabled
                        >
                            <UserPlus size={20} style={{ marginRight: '8px' }} />
                            登録してトライアル開始
                        </button>
                    </div>
                )}

                {/* Trial Info */}
                <div style={{
                    marginTop: '20px',
                    padding: '16px',
                    backgroundColor: '#e8f5e9',
                    borderRadius: '8px',
                    fontSize: '13px',
                    color: '#2e7d32'
                }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
                        <CheckCircle size={16} />
                        <strong>14日間の無料トライアル</strong>
                    </div>
                    <ul style={{ margin: 0, paddingLeft: '24px', lineHeight: 1.8 }}>
                        <li>14日間はすべての機能を無料でご利用いただけます</li>
                        <li>15日目から選択したプランの料金が自動課金されます</li>
                        <li>トライアル期間中にいつでもキャンセル可能です</li>
                        <li>キャンセルは<Link to="/dashboard/settings" style={{ color: '#1565c0', fontWeight: 'bold' }}>ダッシュボード設定</Link>から</li>
                    </ul>
                </div>

                <p style={{ marginTop: '24px', fontSize: '14px', color: '#999', textAlign: 'center' }}>
                    すでにアカウントをお持ちですか？ <Link to="/login" style={{ color: 'var(--primary-color)', fontWeight: 'bold' }}>ログイン</Link>
                </p>
            </div>
        </div>
    );
}
