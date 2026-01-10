import React from 'react';
import { Link } from 'react-router-dom';
import { CheckCircle, X } from 'lucide-react';
import { PLANS } from '../config/pricing-plans';

export default function Home() {
    return (
        <div style={{ fontFamily: '"Inter", "Helvetica Neue", Arial, sans-serif', color: '#333', lineHeight: 1.6 }}>
            {/* Header */}
            <header style={{ padding: '20px 40px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', backgroundColor: '#fff', boxShadow: '0 2px 4px rgba(0,0,0,0.05)' }}>
                <div style={{ fontSize: '24px', fontWeight: 'bold', color: 'var(--primary-color)' }}>LogiTrace</div>
                <nav>
                    <Link to="/login" style={{ marginRight: '20px', textDecoration: 'none', color: '#666' }}>ログイン</Link>
                    <Link to="/register" className="btn btn-primary">無料で始める</Link>
                </nav>
            </header>

            {/* Hero Section */}
            <section style={{ padding: '80px 20px', textAlign: 'center', background: 'linear-gradient(135deg, #e8f5e9 0%, #e3f2fd 100%)' }}>
                <h1 style={{ fontSize: '48px', fontWeight: 'bold', marginBottom: '20px', color: '#2c3e50' }}>
                    配送業務の「見える化」を、<br />かつてないほど簡単に。
                </h1>
                <p style={{ fontSize: '18px', color: '#555', marginBottom: '40px', maxWidth: '600px', margin: '0 auto 40px' }}>
                    リアルタイムGPS追跡、自動日報作成、そして高度な分析。<br />
                    ドライバーと管理者の負担を劇的に減らす、次世代の配送管理プラットフォーム。
                </p>
                <Link to="/register" className="btn btn-primary" style={{ padding: '16px 32px', fontSize: '18px' }}>
                    14日間の無料トライアルを開始
                </Link>
            </section>

            {/* Pricing Section */}
            <section style={{ padding: '80px 20px', backgroundColor: '#f8f9fa' }}>
                <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
                    <h2 style={{ textAlign: 'center', fontSize: '36px', fontWeight: 'bold', marginBottom: '10px' }}>料金プラン</h2>
                    <p style={{ textAlign: 'center', color: '#666', marginBottom: '60px' }}>
                        事業規模に合わせて最適なプランをお選びいただけます。<br />
                        すべてのプランに14日間の無料トライアルが付いています。
                    </p>

                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '20px' }}>
                        {PLANS.map((plan) => (
                            <div key={plan.id} style={{
                                backgroundColor: '#fff',
                                borderRadius: '16px',
                                padding: '32px',
                                border: plan.recommended ? '2px solid var(--primary-color)' : '1px solid #eee',
                                boxShadow: plan.recommended ? '0 8px 24px rgba(33, 150, 243, 0.15)' : '0 4px 12px rgba(0,0,0,0.05)',
                                position: 'relative',
                                display: 'flex',
                                flexDirection: 'column'
                            }}>
                                {plan.recommended && (
                                    <div style={{
                                        position: 'absolute',
                                        top: '-12px',
                                        left: '50%',
                                        transform: 'translateX(-50%)',
                                        backgroundColor: 'var(--primary-color)',
                                        color: '#fff',
                                        padding: '4px 12px',
                                        borderRadius: '20px',
                                        fontSize: '12px',
                                        fontWeight: 'bold'
                                    }}>
                                        一番人気
                                    </div>
                                )}
                                <h3 style={{ fontSize: '20px', fontWeight: 'bold', marginBottom: '8px' }}>{plan.name}</h3>
                                <p style={{ color: '#666', fontSize: '14px', marginBottom: '20px' }}>{plan.description}</p>

                                <div style={{ marginBottom: '24px' }}>
                                    {plan.price > 0 ? (
                                        <>
                                            <span style={{ fontSize: '32px', fontWeight: 'bold' }}>¥{plan.price.toLocaleString()}</span>
                                            <span style={{ color: '#999' }}>/月</span>
                                        </>
                                    ) : (
                                        <span style={{ fontSize: '28px', fontWeight: 'bold' }}>お問い合わせ</span>
                                    )}
                                </div>

                                <div style={{ borderTop: '1px solid #eee', margin: '0 -32px 24px', paddingTop: '24px', paddingLeft: '32px', paddingRight: '32px' }}>
                                    <div style={{ fontSize: '14px', fontWeight: 'bold', marginBottom: '8px' }}>ドライバー数</div>
                                    <div style={{ fontSize: '16px', color: '#333' }}>
                                        {plan.maxDrivers ? `${plan.minDrivers}〜${plan.maxDrivers}名` : `${plan.minDrivers}名以上`}
                                    </div>
                                </div>

                                <ul style={{ listStyle: 'none', padding: 0, margin: '0 0 32px', flex: 1 }}>
                                    <FeatureItem label={`管理者: ${plan.features.adminCount}`} />
                                    <FeatureItem label="GPS追跡" active={plan.features.gpsTracking} />
                                    <FeatureItem label="日報作成" active={plan.features.dailyReports} />
                                    <FeatureItem label="PDFエクスポート" active={plan.features.pdfExport} />
                                    <FeatureItem label="月次レポート" active={plan.features.monthlyReports} />
                                    <FeatureItem label="年次レポート" active={plan.features.yearlyReports} />
                                    <FeatureItem label={`保存期間: ${plan.features.dataRetention}`} />
                                    <FeatureItem label="API連携" active={plan.features.apiAccess} />
                                    <FeatureItem label={`サポート: ${plan.features.support}`} />
                                </ul>

                                <Link
                                    to={`/register?plan=${plan.id}`}
                                    className={`btn ${plan.recommended ? 'btn-primary' : 'btn-outline'}`}
                                    style={{ textAlign: 'center', width: '100%', display: 'block' }}
                                >
                                    {plan.price === 0 ? '相談する' : 'このプランで始める'}
                                </Link>
                            </div>
                        ))}
                    </div>
                </div>
            </section>

            {/* Footer */}
            <footer style={{ backgroundColor: '#2c3e50', color: '#fff', padding: '60px 20px', textAlign: 'center' }}>
                <div style={{ marginBottom: '20px', fontSize: '20px', fontWeight: 'bold' }}>LogiTrace</div>
                <p style={{ color: '#bdc3c7', marginBottom: '40px' }}>配送業務の効率化を、今日から。</p>
                <div style={{ fontSize: '12px', color: '#7f8c8d' }}>
                    &copy; 2026 LogiTrace. All rights reserved.
                </div>
            </footer>
        </div>
    );
}

function FeatureItem({ label, active = true }: { label: string, active?: boolean }) {
    return (
        <li style={{ display: 'flex', alignItems: 'center', marginBottom: '12px', color: active ? '#333' : '#bbb' }}>
            {active ? (
                <CheckCircle size={18} color="var(--primary-color)" style={{ marginRight: '8px' }} />
            ) : (
                <X size={18} color="#ddd" style={{ marginRight: '8px' }} />
            )}
            <span style={{ fontSize: '14px' }}>{label}</span>
        </li>
    );
}
