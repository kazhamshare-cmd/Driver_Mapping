import React from 'react';
import { Users, Truck, FileText, CheckCircle } from 'lucide-react';

const Dashboard = () => {
    return (
        <div className="container">
            <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px', padding: '20px 0' }}>
                <div>
                    <h1 style={{ margin: 0, color: 'var(--text-color)' }}>管理者ダッシュボード</h1>
                    <p style={{ margin: '4px 0 0', color: 'var(--text-secondary)' }}>今日の業務状況を一目で確認できます</p>
                </div>
                <div style={{ display: 'flex', gap: '16px' }}>
                    <button className="btn btn-primary" onClick={() => window.location.href = '/reports'}>
                        日報一覧を見る
                    </button>
                    <button className="btn btn-outline" onClick={() => {
                        localStorage.removeItem('user');
                        window.location.reload();
                    }}>
                        ログアウト
                    </button>
                </div>
            </header>

            {/* Summary Cards */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '24px', marginBottom: '32px' }}>
                <SummaryCard
                    icon={<Truck color="#2196F3" size={32} />}
                    title="稼働車両"
                    value="12 / 15 台"
                    subText="現在稼働率 80%"
                />
                <SummaryCard
                    icon={<Users color="#4CAF50" size={32} />}
                    title="出勤ドライバー"
                    value="12 名"
                    subText="遅刻・欠勤なし"
                />
                <SummaryCard
                    icon={<CheckCircle color="#FF9800" size={32} />}
                    title="本日の日報"
                    value="3 件完了"
                    subText="9 件待ち"
                />
                <SummaryCard
                    icon={<FileText color="#9C27B0" size={32} />}
                    title="今月の走行距離"
                    value="12,450 km"
                    subText="前月比 +5%"
                />
            </div>

            <div className="card">
                <h2 style={{ marginTop: 0 }}>最近の活動</h2>
                <div style={{ height: '200px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#999', background: '#f9f9f9', borderRadius: '8px' }}>
                    ここに地図や詳細リストが表示されます
                </div>
            </div>
        </div>
    );
};

const SummaryCard = ({ icon, title, value, subText }: { icon: React.ReactNode, title: string, value: string, subText: string }) => (
    <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <span style={{ fontSize: '14px', color: '#666', fontWeight: 'bold' }}>{title}</span>
            {icon}
        </div>
        <div style={{ fontSize: '28px', fontWeight: 'bold', color: '#333' }}>{value}</div>
        <div style={{ fontSize: '12px', color: '#888' }}>{subText}</div>
    </div>
);

export default Dashboard;
