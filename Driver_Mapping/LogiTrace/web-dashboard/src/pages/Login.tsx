import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { LogIn } from 'lucide-react';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const navigate = useNavigate();

    const handleLogin = (e: React.FormEvent) => {
        e.preventDefault();
        // Dummy login
        if (email && password) {
            localStorage.setItem('user', JSON.stringify({ name: 'Admin User', email }));
            navigate('/dashboard');
        }
    };

    return (
        <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', background: 'linear-gradient(135deg, #e8f5e9 0%, #e3f2fd 100%)' }}>
            <div className="card" style={{ width: '400px', textAlign: 'center' }}>
                <h1 style={{ color: 'var(--primary-color)', marginBottom: '8px' }}>LogiTrace</h1>
                <p style={{ color: 'var(--text-secondary)', marginBottom: '32px' }}>
                    運送業務をスマートに、<br />もっと優しく管理します
                </p>

                <form onSubmit={handleLogin}>
                    <div style={{ textAlign: 'left', marginBottom: '8px' }}>
                        <label style={{ fontSize: '14px', fontWeight: 'bold', color: '#666' }}>メールアドレス</label>
                    </div>
                    <input
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        placeholder="example@company.com"
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
                    />

                    <button type="submit" className="btn btn-primary" style={{ width: '100%', marginTop: '16px', padding: '14px' }}>
                        <LogIn size={20} />
                        ログインする
                    </button>
                </form>

                <p style={{ marginTop: '24px', fontSize: '14px', color: '#999' }}>
                    アカウントをお持ちでない場合は <Link to="/register" style={{ color: 'var(--primary-color)', fontWeight: 'bold' }}>新規登録</Link> してください
                </p>
            </div>
        </div>
    );
};

export default Login;
