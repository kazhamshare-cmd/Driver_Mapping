import { Link } from 'react-router-dom';
import {
    CheckCircle, X, Truck, MapPin, BarChart3, Clock, Users, Shield,
    Bell, TrendingUp, Smartphone, ArrowRight, FileText, ClipboardCheck,
    Zap, Play, Route
} from 'lucide-react';
import { getDisplayPlans } from '../config/pricing-plans';

export default function Home() {
    const displayPlans = getDisplayPlans();

    return (
        <div style={{ fontFamily: '"Inter", "Helvetica Neue", Arial, sans-serif', color: '#1f2937', lineHeight: 1.6 }}>
            {/* Header */}
            <header style={{
                padding: '16px 40px',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                backgroundColor: 'rgba(255,255,255,0.95)',
                backdropFilter: 'blur(10px)',
                boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
                position: 'fixed',
                top: 0,
                left: 0,
                right: 0,
                zIndex: 100
            }}>
                <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#2563eb' }}>LogiTrace</div>
                <nav style={{ display: 'flex', alignItems: 'center', gap: '24px' }}>
                    <Link to="/login" style={{ textDecoration: 'none', color: '#4b5563', fontWeight: '500' }}>ログイン</Link>
                    <Link to="/register" style={{
                        padding: '10px 24px',
                        backgroundColor: '#2563eb',
                        color: '#fff',
                        borderRadius: '8px',
                        textDecoration: 'none',
                        fontWeight: '600',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        transition: 'all 0.3s ease'
                    }}>
                        無料で始める
                        <ArrowRight size={18} />
                    </Link>
                </nav>
            </header>

            {/* Hero Section */}
            <section style={{
                position: 'relative',
                minHeight: '700px',
                display: 'flex',
                alignItems: 'center',
                overflow: 'hidden',
                marginTop: '64px'
            }}>
                {/* Background Image */}
                <div style={{
                    position: 'absolute',
                    inset: 0,
                    zIndex: 0
                }}>
                    <img
                        src="/images/hero-truck.jpg"
                        alt="運送業務"
                        style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    />
                    <div style={{
                        position: 'absolute',
                        inset: 0,
                        background: 'linear-gradient(to right, rgba(0,0,0,0.75), rgba(0,0,0,0.5), rgba(0,0,0,0.3))'
                    }} />
                </div>

                {/* Content */}
                <div style={{
                    position: 'relative',
                    zIndex: 10,
                    width: '100%',
                    maxWidth: '1200px',
                    margin: '0 auto',
                    padding: '80px 24px'
                }}>
                    <div style={{ maxWidth: '700px' }}>
                        <div style={{
                            display: 'inline-block',
                            marginBottom: '24px',
                            padding: '8px 16px',
                            backgroundColor: 'rgba(37, 99, 235, 0.9)',
                            backdropFilter: 'blur(4px)',
                            borderRadius: '24px'
                        }}>
                            <p style={{ color: '#fff', fontSize: '14px', fontWeight: '600', margin: 0 }}>
                                運送業務DXの新スタンダード
                            </p>
                        </div>

                        <h1 style={{
                            fontSize: '52px',
                            fontWeight: 'bold',
                            color: '#fff',
                            marginBottom: '24px',
                            lineHeight: 1.2
                        }}>
                            運送業務を、<br />もっとスマートに。
                        </h1>

                        <p style={{
                            fontSize: '20px',
                            color: 'rgba(255,255,255,0.9)',
                            marginBottom: '40px',
                            lineHeight: 1.7
                        }}>
                            リアルタイムな動態管理から、複雑な法定帳票作成まで。<br />
                            LogiTraceは、運送会社の業務を一元管理する<br />
                            次世代のクラウドプラットフォームです。
                        </p>

                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '16px' }}>
                            <Link to="/register" style={{
                                padding: '16px 32px',
                                backgroundColor: '#2563eb',
                                color: '#fff',
                                borderRadius: '12px',
                                textDecoration: 'none',
                                fontWeight: '600',
                                fontSize: '18px',
                                display: 'flex',
                                alignItems: 'center',
                                gap: '8px',
                                boxShadow: '0 10px 25px rgba(37, 99, 235, 0.4)',
                                transition: 'transform 0.3s ease'
                            }}>
                                14日間無料で試す
                                <ArrowRight size={20} />
                            </Link>

                            <a href="#features" style={{
                                padding: '16px 32px',
                                backgroundColor: 'rgba(255,255,255,0.1)',
                                backdropFilter: 'blur(8px)',
                                color: '#fff',
                                border: '2px solid rgba(255,255,255,0.3)',
                                borderRadius: '12px',
                                textDecoration: 'none',
                                fontWeight: '600',
                                fontSize: '18px',
                                display: 'flex',
                                alignItems: 'center',
                                gap: '8px'
                            }}>
                                <Play size={20} />
                                機能を見る
                            </a>
                        </div>
                    </div>
                </div>
            </section>

            {/* Industry Support Section */}
            <section style={{ padding: '80px 24px', backgroundColor: '#f9fafb' }}>
                <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
                    <div style={{ textAlign: 'center', marginBottom: '48px' }}>
                        <div style={{
                            display: 'inline-block',
                            marginBottom: '16px',
                            padding: '8px 16px',
                            backgroundColor: '#dbeafe',
                            borderRadius: '24px'
                        }}>
                            <p style={{ color: '#1d4ed8', fontSize: '14px', fontWeight: '600', margin: 0 }}>
                                SUPPORTED INDUSTRIES
                            </p>
                        </div>
                        <h2 style={{ fontSize: '36px', fontWeight: 'bold', color: '#111827', marginBottom: '16px' }}>
                            対応業種
                        </h2>
                        <p style={{ fontSize: '18px', color: '#6b7280' }}>
                            トラック・タクシー・バス、あらゆる運送業に対応
                        </p>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '24px' }}>
                        {[
                            { icon: <Truck size={40} />, title: 'トラック運送', desc: '一般貨物・特積み対応', color: '#3b82f6' },
                            { icon: <Users size={40} />, title: 'タクシー', desc: '法人・個人タクシー', color: '#10b981' },
                            { icon: <Route size={40} />, title: 'バス', desc: '貸切・路線バス', color: '#8b5cf6' }
                        ].map((item, idx) => (
                            <div key={idx} style={{
                                backgroundColor: '#fff',
                                padding: '40px 32px',
                                borderRadius: '16px',
                                textAlign: 'center',
                                boxShadow: '0 4px 15px rgba(0,0,0,0.08)',
                                border: '1px solid #f3f4f6',
                                transition: 'transform 0.3s ease, box-shadow 0.3s ease'
                            }}>
                                <div style={{
                                    width: '80px',
                                    height: '80px',
                                    margin: '0 auto 20px',
                                    borderRadius: '16px',
                                    background: `linear-gradient(135deg, ${item.color}, ${item.color}dd)`,
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    color: '#fff'
                                }}>
                                    {item.icon}
                                </div>
                                <h3 style={{ fontSize: '20px', fontWeight: 'bold', marginBottom: '8px', color: '#111827' }}>{item.title}</h3>
                                <p style={{ color: '#6b7280', fontSize: '15px', margin: 0 }}>{item.desc}</p>
                            </div>
                        ))}
                    </div>
                </div>
            </section>

            {/* System Intro Section */}
            <section style={{ padding: '100px 24px', backgroundColor: '#fff' }}>
                <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
                    <div style={{ textAlign: 'center', marginBottom: '64px' }}>
                        <div style={{
                            display: 'inline-block',
                            marginBottom: '16px',
                            padding: '8px 16px',
                            backgroundColor: '#dbeafe',
                            borderRadius: '24px'
                        }}>
                            <p style={{ color: '#1d4ed8', fontSize: '14px', fontWeight: '600', margin: 0 }}>
                                ABOUT SYSTEM
                            </p>
                        </div>
                        <h2 style={{ fontSize: '36px', fontWeight: 'bold', color: '#111827', marginBottom: '16px' }}>
                            LogiTraceとは
                        </h2>
                        <p style={{ fontSize: '18px', color: '#6b7280', maxWidth: '800px', margin: '0 auto' }}>
                            運送業に必要な法定帳票管理、動態管理、労務管理を一元化する次世代クラウドシステムです
                        </p>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '60px', alignItems: 'center' }}>
                        <div style={{
                            borderRadius: '20px',
                            overflow: 'hidden',
                            boxShadow: '0 25px 50px rgba(0,0,0,0.15)'
                        }}>
                            <img
                                src="/images/driver-tablet.jpg"
                                alt="タブレット操作"
                                style={{ width: '100%', height: '500px', objectFit: 'cover' }}
                            />
                        </div>

                        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                            {[
                                {
                                    icon: <MapPin size={24} />,
                                    title: 'リアルタイム位置追跡',
                                    desc: 'GPS技術により全ドライバーの現在位置を地図上で確認。配車状況を瞬時に把握し、急な依頼にも柔軟に対応。',
                                    color: '#3b82f6',
                                    bg: '#dbeafe'
                                },
                                {
                                    icon: <Smartphone size={24} />,
                                    title: 'スマートフォン対応',
                                    desc: 'ドライバーも管理者もスマホからアクセス可能。点呼・点検・日報がワンタップで完了。',
                                    color: '#10b981',
                                    bg: '#d1fae5'
                                },
                                {
                                    icon: <BarChart3 size={24} />,
                                    title: 'データ分析・最適化',
                                    desc: '運行データを自動集計し、視覚的なレポートを生成。経営判断に必要なデータをリアルタイムで提供。',
                                    color: '#8b5cf6',
                                    bg: '#ede9fe'
                                }
                            ].map((item, idx) => (
                                <div key={idx} style={{
                                    backgroundColor: '#fff',
                                    padding: '24px',
                                    borderRadius: '16px',
                                    boxShadow: '0 4px 15px rgba(0,0,0,0.08)',
                                    border: '1px solid #f3f4f6',
                                    display: 'flex',
                                    gap: '16px'
                                }}>
                                    <div style={{
                                        width: '48px',
                                        height: '48px',
                                        borderRadius: '12px',
                                        backgroundColor: item.bg,
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        color: item.color,
                                        flexShrink: 0
                                    }}>
                                        {item.icon}
                                    </div>
                                    <div>
                                        <h3 style={{ fontSize: '18px', fontWeight: 'bold', color: '#111827', marginBottom: '8px' }}>
                                            {item.title}
                                        </h3>
                                        <p style={{ color: '#6b7280', fontSize: '15px', margin: 0, lineHeight: 1.6 }}>
                                            {item.desc}
                                        </p>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            </section>

            {/* Features Section */}
            <section id="features" style={{ padding: '100px 24px', backgroundColor: '#f9fafb' }}>
                <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
                    <div style={{ textAlign: 'center', marginBottom: '64px' }}>
                        <div style={{
                            display: 'inline-block',
                            marginBottom: '16px',
                            padding: '8px 16px',
                            backgroundColor: '#dbeafe',
                            borderRadius: '24px'
                        }}>
                            <p style={{ color: '#1d4ed8', fontSize: '14px', fontWeight: '600', margin: 0 }}>
                                FEATURES
                            </p>
                        </div>
                        <h2 style={{ fontSize: '36px', fontWeight: 'bold', color: '#111827', marginBottom: '16px' }}>
                            法定帳票をオールインワンで管理
                        </h2>
                        <p style={{ fontSize: '18px', color: '#6b7280', maxWidth: '800px', margin: '0 auto' }}>
                            運送業法が求めるすべての記録を、このシステム1つで完結
                        </p>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: '24px' }}>
                        {[
                            { icon: <ClipboardCheck size={32} />, title: '点呼記録簿', desc: '乗務前・乗務後点呼をデジタル化。アルコールチェック結果も記録。IT点呼にも対応。', gradient: 'linear-gradient(135deg, #3b82f6, #2563eb)' },
                            { icon: <FileText size={32} />, title: '日常点検記録', desc: '車両の日常点検をチェックリスト形式で実施。不良箇所は管理者に即時通知。', gradient: 'linear-gradient(135deg, #10b981, #059669)' },
                            { icon: <BarChart3 size={32} />, title: '運転日報', desc: 'GPSと連動して走行記録を自動作成。手書き不要で正確な記録を実現。', gradient: 'linear-gradient(135deg, #8b5cf6, #7c3aed)' },
                            { icon: <Users size={32} />, title: '運転者台帳', desc: '法定様式に準拠した運転者台帳。免許期限・健診期限を自動アラート。', gradient: 'linear-gradient(135deg, #f59e0b, #d97706)' },
                            { icon: <Shield size={32} />, title: '健康診断管理', desc: '定期健診・特殊健診の受診履歴と次回予定を一元管理。', gradient: 'linear-gradient(135deg, #ef4444, #dc2626)' },
                            { icon: <TrendingUp size={32} />, title: '適性診断管理', desc: '初任・適齢・特定診断の記録管理。65歳以上は自動で適齢判定。', gradient: 'linear-gradient(135deg, #6366f1, #4f46e5)' }
                        ].map((feature, idx) => (
                            <div key={idx} style={{
                                backgroundColor: '#fff',
                                borderRadius: '20px',
                                padding: '32px',
                                boxShadow: '0 4px 15px rgba(0,0,0,0.08)',
                                border: '1px solid #f3f4f6',
                                transition: 'transform 0.3s ease, box-shadow 0.3s ease'
                            }}>
                                <div style={{
                                    width: '64px',
                                    height: '64px',
                                    borderRadius: '16px',
                                    background: feature.gradient,
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    color: '#fff',
                                    marginBottom: '20px'
                                }}>
                                    {feature.icon}
                                </div>
                                <h3 style={{ fontSize: '20px', fontWeight: 'bold', color: '#111827', marginBottom: '12px' }}>
                                    {feature.title}
                                </h3>
                                <p style={{ color: '#6b7280', fontSize: '15px', lineHeight: 1.7, margin: 0 }}>
                                    {feature.desc}
                                </p>
                            </div>
                        ))}
                    </div>
                </div>
            </section>

            {/* Benefits Section */}
            <section style={{ padding: '100px 24px', backgroundColor: '#fff' }}>
                <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '60px', alignItems: 'center' }}>
                        <div>
                            <div style={{
                                display: 'inline-block',
                                marginBottom: '16px',
                                padding: '8px 16px',
                                backgroundColor: '#dcfce7',
                                borderRadius: '24px'
                            }}>
                                <p style={{ color: '#16a34a', fontSize: '14px', fontWeight: '600', margin: 0 }}>
                                    BENEFITS
                                </p>
                            </div>
                            <h2 style={{ fontSize: '36px', fontWeight: 'bold', color: '#111827', marginBottom: '40px' }}>
                                導入で変わる3つのこと
                            </h2>

                            {[
                                { icon: <Zap size={28} />, title: '事務作業時間', value: '-80%', desc: '手書き日報・転記作業が不要に。管理者の事務作業を大幅削減。', color: '#3b82f6' },
                                { icon: <BarChart3 size={28} />, title: 'コスト削減', value: '-50%', desc: '紙・印刷費ゼロ、人件費も削減。月額費用で導入も低リスク。', color: '#10b981' },
                                { icon: <Shield size={28} />, title: '監査対応', value: '100%', desc: '法定様式に完全準拠。監査時も慌てず書類を提出。', color: '#8b5cf6' }
                            ].map((benefit, idx) => (
                                <div key={idx} style={{ marginBottom: '32px', display: 'flex', gap: '20px' }}>
                                    <div style={{
                                        width: '56px',
                                        height: '56px',
                                        borderRadius: '14px',
                                        backgroundColor: `${benefit.color}15`,
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        color: benefit.color,
                                        flexShrink: 0
                                    }}>
                                        {benefit.icon}
                                    </div>
                                    <div>
                                        <div style={{ fontSize: '14px', color: '#6b7280', marginBottom: '4px' }}>{benefit.title}</div>
                                        <div style={{ fontSize: '32px', fontWeight: 'bold', color: benefit.color, marginBottom: '8px' }}>{benefit.value}</div>
                                        <p style={{ color: '#6b7280', fontSize: '15px', margin: 0 }}>{benefit.desc}</p>
                                    </div>
                                </div>
                            ))}
                        </div>

                        <div style={{
                            borderRadius: '20px',
                            overflow: 'hidden',
                            boxShadow: '0 25px 50px rgba(0,0,0,0.15)'
                        }}>
                            <img
                                src="/images/office-logistics.jpg"
                                alt="オフィス"
                                style={{ width: '100%', height: '600px', objectFit: 'cover' }}
                            />
                        </div>
                    </div>
                </div>
            </section>

            {/* Pricing Section */}
            <section style={{ padding: '100px 24px', background: 'linear-gradient(to bottom, #fff, #f9fafb)' }}>
                <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
                    <div style={{ textAlign: 'center', marginBottom: '24px' }}>
                        <div style={{
                            display: 'inline-block',
                            marginBottom: '16px',
                            padding: '8px 16px',
                            backgroundColor: '#f3e8ff',
                            borderRadius: '24px'
                        }}>
                            <p style={{ color: '#7c3aed', fontSize: '14px', fontWeight: '600', margin: 0 }}>
                                PRICING
                            </p>
                        </div>
                        <h2 style={{ fontSize: '36px', fontWeight: 'bold', color: '#111827', marginBottom: '16px' }}>
                            料金プラン
                        </h2>
                        <p style={{ fontSize: '18px', color: '#6b7280', marginBottom: '16px' }}>
                            事業規模に合わせた柔軟な料金プランをご用意
                        </p>
                    </div>

                    {/* Trial Badge */}
                    <div style={{ textAlign: 'center', marginBottom: '48px' }}>
                        <div style={{
                            display: 'inline-block',
                            backgroundColor: '#dcfce7',
                            padding: '16px 32px',
                            borderRadius: '12px',
                            border: '1px solid #bbf7d0'
                        }}>
                            <span style={{ fontWeight: 'bold', color: '#16a34a', fontSize: '16px' }}>
                                14日間の無料トライアル付き
                            </span>
                            <span style={{ color: '#6b7280', marginLeft: '12px', fontSize: '14px' }}>
                                15日目から自動課金開始（いつでもキャンセル可能）
                            </span>
                        </div>
                    </div>

                    {/* Pricing Cards */}
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '24px', marginBottom: '48px' }}>
                        {displayPlans.map((plan, idx) => {
                            const gradients = [
                                'linear-gradient(135deg, #3b82f6, #2563eb)',
                                'linear-gradient(135deg, #8b5cf6, #7c3aed)',
                                'linear-gradient(135deg, #6366f1, #4f46e5)'
                            ];
                            return (
                                <div key={plan.id} style={{
                                    backgroundColor: '#fff',
                                    borderRadius: '20px',
                                    boxShadow: plan.recommended ? '0 20px 40px rgba(139, 92, 246, 0.2)' : '0 4px 15px rgba(0,0,0,0.08)',
                                    overflow: 'hidden',
                                    position: 'relative',
                                    transform: plan.recommended ? 'scale(1.02)' : 'none',
                                    border: plan.recommended ? '2px solid #8b5cf6' : '1px solid #f3f4f6'
                                }}>
                                    {plan.recommended && (
                                        <div style={{
                                            position: 'absolute',
                                            top: 0,
                                            right: 0,
                                            background: 'linear-gradient(135deg, #8b5cf6, #ec4899)',
                                            color: '#fff',
                                            padding: '6px 16px',
                                            borderBottomLeftRadius: '12px',
                                            fontSize: '13px',
                                            fontWeight: '600'
                                        }}>
                                            おすすめ
                                        </div>
                                    )}

                                    {/* Card Header */}
                                    <div style={{
                                        padding: '32px',
                                        background: gradients[idx % gradients.length],
                                        color: '#fff'
                                    }}>
                                        <h3 style={{ fontSize: '24px', fontWeight: 'bold', marginBottom: '8px' }}>{plan.name}</h3>
                                        <p style={{ color: 'rgba(255,255,255,0.85)', fontSize: '14px', marginBottom: '16px' }}>{plan.description}</p>
                                        <div style={{ display: 'flex', alignItems: 'baseline', gap: '4px' }}>
                                            <span style={{ fontSize: '40px', fontWeight: 'bold' }}>
                                                {plan.price > 0 ? `¥${plan.price.toLocaleString()}` : 'お問い合わせ'}
                                            </span>
                                            {plan.price > 0 && <span style={{ color: 'rgba(255,255,255,0.8)' }}>/ 月</span>}
                                        </div>
                                    </div>

                                    {/* Card Body */}
                                    <div style={{ padding: '32px' }}>
                                        <div style={{ marginBottom: '24px', paddingBottom: '20px', borderBottom: '1px solid #f3f4f6' }}>
                                            <div style={{ fontSize: '14px', color: '#6b7280', marginBottom: '4px' }}>ドライバー数</div>
                                            <div style={{ fontSize: '16px', fontWeight: '600', color: '#111827' }}>
                                                {plan.maxDrivers ? `${plan.minDrivers}〜${plan.maxDrivers}名` : `${plan.minDrivers}名以上`}
                                            </div>
                                        </div>

                                        <ul style={{ listStyle: 'none', padding: 0, margin: '0 0 24px' }}>
                                            <FeatureItem label={`管理者: ${plan.features.adminCount}`} />
                                            <FeatureItem label="GPS追跡" active={plan.features.gpsTracking} />
                                            <FeatureItem label="日報作成" active={plan.features.dailyReports} />
                                            <FeatureItem label="PDFエクスポート" active={plan.features.pdfExport} />
                                            <FeatureItem label="月次レポート" active={plan.features.monthlyReports} />
                                            <FeatureItem label="デジタル署名" active={plan.features.digitalSignature} />
                                            <FeatureItem label="タコグラフ連携" active={plan.features.tachographIntegration} />
                                            <FeatureItem label={`保存期間: ${plan.features.dataRetention}`} />
                                        </ul>

                                        <Link
                                            to={`/register?plan=${plan.id}`}
                                            style={{
                                                display: 'block',
                                                width: '100%',
                                                padding: '14px',
                                                textAlign: 'center',
                                                borderRadius: '12px',
                                                textDecoration: 'none',
                                                fontWeight: '600',
                                                fontSize: '16px',
                                                background: plan.recommended ? 'linear-gradient(135deg, #8b5cf6, #ec4899)' : '#f3f4f6',
                                                color: plan.recommended ? '#fff' : '#111827',
                                                boxShadow: plan.recommended ? '0 4px 15px rgba(139, 92, 246, 0.3)' : 'none'
                                            }}
                                        >
                                            {plan.price === 0 ? 'お問い合わせ' : '無料で始める'}
                                        </Link>
                                    </div>
                                </div>
                            );
                        })}
                    </div>

                    {/* Additional Info */}
                    <div style={{
                        backgroundColor: '#eff6ff',
                        borderRadius: '20px',
                        padding: '40px',
                        display: 'grid',
                        gridTemplateColumns: '1fr 1fr',
                        gap: '40px'
                    }}>
                        <div>
                            <h3 style={{ fontSize: '20px', fontWeight: 'bold', color: '#111827', marginBottom: '20px' }}>
                                全プラン共通の特典
                            </h3>
                            <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
                                {['14日間の無料トライアル', '初期導入サポート無料', '操作トレーニング実施', 'SSL暗号化・セキュリティ対策'].map((item, idx) => (
                                    <li key={idx} style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
                                        <CheckCircle size={20} color="#2563eb" />
                                        <span style={{ color: '#4b5563' }}>{item}</span>
                                    </li>
                                ))}
                            </ul>
                        </div>
                        <div>
                            <h3 style={{ fontSize: '20px', fontWeight: 'bold', color: '#111827', marginBottom: '20px' }}>
                                お支払い方法
                            </h3>
                            <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
                                {['クレジットカード決済', '銀行振込（月払い・年払い）', '請求書払い（法人のみ）'].map((item, idx) => (
                                    <li key={idx} style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
                                        <CheckCircle size={20} color="#2563eb" />
                                        <span style={{ color: '#4b5563' }}>{item}</span>
                                    </li>
                                ))}
                            </ul>
                        </div>
                    </div>
                </div>
            </section>

            {/* CTA Section */}
            <section style={{
                position: 'relative',
                padding: '100px 24px',
                overflow: 'hidden'
            }}>
                {/* Background */}
                <div style={{
                    position: 'absolute',
                    inset: 0,
                    zIndex: 0
                }}>
                    <img
                        src="/images/truck-road.jpg"
                        alt="道路"
                        style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    />
                    <div style={{
                        position: 'absolute',
                        inset: 0,
                        background: 'linear-gradient(135deg, rgba(30, 58, 138, 0.95), rgba(109, 40, 217, 0.95))'
                    }} />
                </div>

                {/* Content */}
                <div style={{ position: 'relative', zIndex: 10, maxWidth: '800px', margin: '0 auto', textAlign: 'center' }}>
                    <h2 style={{ fontSize: '40px', fontWeight: 'bold', color: '#fff', marginBottom: '24px' }}>
                        今すぐ始めませんか？
                    </h2>
                    <p style={{ fontSize: '20px', color: 'rgba(255,255,255,0.9)', marginBottom: '16px', lineHeight: 1.7 }}>
                        14日間の無料トライアルで、LogiTraceの効果を実感してください。
                    </p>
                    <p style={{ fontSize: '14px', color: 'rgba(255,255,255,0.7)', marginBottom: '40px' }}>
                        ※ 14日間は完全無料。15日目から自動課金開始。いつでもキャンセル可能です。
                    </p>

                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '16px', justifyContent: 'center', marginBottom: '24px' }}>
                        <Link to="/register" style={{
                            padding: '18px 40px',
                            backgroundColor: '#fff',
                            color: '#2563eb',
                            borderRadius: '12px',
                            textDecoration: 'none',
                            fontWeight: 'bold',
                            fontSize: '18px',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '8px',
                            boxShadow: '0 10px 30px rgba(0,0,0,0.2)'
                        }}>
                            無料トライアルを始める
                            <ArrowRight size={20} />
                        </Link>
                    </div>

                    <p style={{ fontSize: '12px', color: 'rgba(255,255,255,0.6)' }}>
                        キャンセルはダッシュボードの設定画面からいつでも可能です
                    </p>
                </div>
            </section>

            {/* Footer */}
            <footer style={{ backgroundColor: '#111827', color: '#fff', padding: '60px 24px' }}>
                <div style={{ maxWidth: '1200px', margin: '0 auto', textAlign: 'center' }}>
                    <div style={{ fontSize: '24px', fontWeight: 'bold', marginBottom: '16px' }}>LogiTrace</div>
                    <p style={{ color: '#9ca3af', marginBottom: '32px' }}>運送業務の効率化を、今日から。</p>
                    <div style={{ display: 'flex', justifyContent: 'center', gap: '24px', marginBottom: '32px', flexWrap: 'wrap' }}>
                        <a href="https://b19.co.jp/terms-of-service/" target="_blank" rel="noreferrer" style={{ color: '#9ca3af', textDecoration: 'none', fontSize: '14px' }}>利用規約</a>
                        <a href="https://b19.co.jp/privacy-policy/" target="_blank" rel="noreferrer" style={{ color: '#9ca3af', textDecoration: 'none', fontSize: '14px' }}>プライバシーポリシー</a>
                        <a href="mailto:info@b19.co.jp" style={{ color: '#9ca3af', textDecoration: 'none', fontSize: '14px' }}>お問い合わせ</a>
                    </div>
                    <div style={{ fontSize: '12px', color: '#6b7280' }}>
                        &copy; 2026 LogiTrace by B19 Inc. All rights reserved.
                    </div>
                </div>
            </footer>
        </div>
    );
}

function FeatureItem({ label, active = true }: { label: string, active?: boolean }) {
    return (
        <li style={{ display: 'flex', alignItems: 'center', marginBottom: '12px', color: active ? '#374151' : '#d1d5db' }}>
            {active ? (
                <CheckCircle size={18} color="#10b981" style={{ marginRight: '10px', flexShrink: 0 }} />
            ) : (
                <X size={18} color="#d1d5db" style={{ marginRight: '10px', flexShrink: 0 }} />
            )}
            <span style={{ fontSize: '14px' }}>{label}</span>
        </li>
    );
}
