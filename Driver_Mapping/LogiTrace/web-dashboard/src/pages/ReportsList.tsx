import React, { useEffect, useState } from 'react';
import { Search } from 'lucide-react';

// API URL (Temporary hardcoded for MVP)
const API_URL = 'http://localhost:3000';

export default function ReportsList() {
    const [reports, setReports] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchReports();
    }, []);

    const fetchReports = async () => {
        try {
            const response = await fetch(`${API_URL}/work-records`);
            if (response.ok) {
                const data = await response.json();
                setReports(data);
            }
        } catch (error) {
            console.error('Failed to fetch reports', error);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="container">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                <h1 style={{ margin: 0 }}>日報一覧</h1>

                <div style={{ position: 'relative', width: '300px' }}>
                    <input type="text" placeholder="ドライバー名や日付で検索..." style={{ paddingLeft: '40px', marginBottom: 0 }} />
                    <Search size={18} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#888' }} />
                </div>
            </div>

            <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead style={{ backgroundColor: '#f9f9f9', borderBottom: '1px solid #eee' }}>
                        <tr>
                            <th style={thStyle}>日付</th>
                            <th style={thStyle}>ドライバー</th>
                            <th style={thStyle}>車両</th>
                            <th style={thStyle}>開始・終了時刻</th>
                            <th style={thStyle}>距離 (km)</th>
                            <th style={thStyle}>記録方法</th>
                            <th style={thStyle}>ステータス</th>
                            <th style={thStyle}>操作</th>
                        </tr>
                    </thead>
                    <tbody>
                        {loading ? (
                            <tr><td colSpan={8} style={{ padding: '40px', textAlign: 'center' }}>読み込み中...</td></tr>
                        ) : reports.length === 0 ? (
                            <tr><td colSpan={8} style={{ padding: '40px', textAlign: 'center', color: '#999' }}>データがありません</td></tr>
                        ) : (
                            reports.map((report) => (
                                <tr key={report.id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                                    <td style={tdStyle}>{new Date(report.work_date).toLocaleDateString()}</td>
                                    <td style={tdStyle}>{report.driver_name || '未登録'}</td>
                                    <td style={tdStyle}>{report.vehicle_number || '-'}</td>
                                    <td style={tdStyle}>
                                        {new Date(report.start_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} -
                                        {report.end_time ? new Date(report.end_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ' 勤務中'}
                                    </td>
                                    <td style={tdStyle} dangerouslySetInnerHTML={{ __html: report.distance ? Number(report.distance).toFixed(1) : '<span style="color:#ddd">-</span>' }}></td>
                                    <td style={tdStyle}>
                                        <span style={{
                                            padding: '4px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 'bold',
                                            backgroundColor: report.record_method === 'gps' ? '#e3f2fd' : '#fff3e0',
                                            color: report.record_method === 'gps' ? '#2196F3' : '#ff9800'
                                        }}>
                                            {report.record_method === 'gps' ? 'GPS' : '手動'}
                                        </span>
                                    </td>
                                    <td style={tdStyle}>
                                        {report.status === 'confirmed'
                                            ? <span style={{ color: '#4CAF50', display: 'flex', alignItems: 'center', gap: '4px' }}>● 確定済</span>
                                            : <span style={{ color: '#999' }}>● 未確定</span>}
                                    </td>
                                    <td style={tdStyle}>
                                        <button className="btn btn-outline" style={{ padding: '6px 12px', fontSize: '12px' }}>詳細</button>
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

const thStyle: React.CSSProperties = {
    padding: '16px',
    textAlign: 'left',
    fontSize: '13px',
    color: '#666',
    fontWeight: 'bold'
};

const tdStyle: React.CSSProperties = {
    padding: '16px',
    fontSize: '14px',
    color: '#333'
};
