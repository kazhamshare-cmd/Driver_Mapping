/**
 * AI Assistant Controller
 * ChatGPT/OpenAI連携による分析支援機能
 */

import { Request, Response } from 'express';
import { pool } from '../index';
import { v4 as uuidv4 } from 'uuid';

// ============================================
// AI設定管理
// ============================================

/**
 * AI設定取得
 */
export const getAiSettings = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        const result = await pool.query(`
            SELECT
                id, company_id,
                preferred_model,
                enable_auto_suggestions,
                enable_daily_reports,
                enable_cost_optimization,
                enable_compliance_alerts,
                monthly_token_limit,
                tokens_used_this_month,
                created_at, updated_at
            FROM ai_settings
            WHERE company_id = $1
        `, [companyId]);

        if (result.rows.length === 0) {
            // デフォルト設定を作成
            const newSettings = await pool.query(`
                INSERT INTO ai_settings (company_id)
                VALUES ($1)
                RETURNING *
            `, [companyId]);
            return res.json(newSettings.rows[0]);
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching AI settings:', error);
        res.status(500).json({ error: 'Failed to fetch AI settings' });
    }
};

/**
 * AI設定更新
 */
export const updateAiSettings = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.params;
        const {
            preferredModel,
            enableAutoSuggestions,
            enableDailyReports,
            enableCostOptimization,
            enableComplianceAlerts,
            monthlyTokenLimit
        } = req.body;

        const result = await pool.query(`
            UPDATE ai_settings
            SET preferred_model = COALESCE($2, preferred_model),
                enable_auto_suggestions = COALESCE($3, enable_auto_suggestions),
                enable_daily_reports = COALESCE($4, enable_daily_reports),
                enable_cost_optimization = COALESCE($5, enable_cost_optimization),
                enable_compliance_alerts = COALESCE($6, enable_compliance_alerts),
                monthly_token_limit = COALESCE($7, monthly_token_limit),
                updated_at = NOW()
            WHERE company_id = $1
            RETURNING *
        `, [companyId, preferredModel, enableAutoSuggestions, enableDailyReports,
            enableCostOptimization, enableComplianceAlerts, monthlyTokenLimit]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'AI settings not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating AI settings:', error);
        res.status(500).json({ error: 'Failed to update AI settings' });
    }
};

// ============================================
// AIチャット機能
// ============================================

/**
 * チャットセッション開始
 */
export const startChatSession = async (req: Request, res: Response) => {
    try {
        const { companyId, userId, relatedFeature } = req.body;
        const sessionId = uuidv4();

        // システムメッセージを記録
        await pool.query(`
            INSERT INTO ai_chat_history (company_id, user_id, session_id, role, content, related_feature)
            VALUES ($1, $2, $3, 'system', '運送業務支援AIアシスタントです。配車、請求、コンプライアンスなどについてお答えします。', $4)
        `, [companyId, userId, sessionId, relatedFeature]);

        res.json({ sessionId });
    } catch (error) {
        console.error('Error starting chat session:', error);
        res.status(500).json({ error: 'Failed to start chat session' });
    }
};

/**
 * チャットメッセージ送信
 */
export const sendChatMessage = async (req: Request, res: Response) => {
    try {
        const { companyId, userId, sessionId, message, relatedFeature, relatedEntityType, relatedEntityId } = req.body;

        // ユーザーメッセージを記録
        await pool.query(`
            INSERT INTO ai_chat_history (company_id, user_id, session_id, role, content, related_feature, related_entity_type, related_entity_id)
            VALUES ($1, $2, $3, 'user', $4, $5, $6, $7)
        `, [companyId, userId, sessionId, message, relatedFeature, relatedEntityType, relatedEntityId]);

        // コンテキストデータを取得（関連エンティティがある場合）
        let contextData = null;
        if (relatedEntityType && relatedEntityId) {
            contextData = await getContextData(relatedEntityType, relatedEntityId);
        }

        // AI応答を生成（実際にはOpenAI APIを呼び出す）
        const aiResponse = await generateAiResponse(companyId, sessionId, message, contextData);

        // AIメッセージを記録
        await pool.query(`
            INSERT INTO ai_chat_history (company_id, user_id, session_id, role, content, related_feature, suggested_action)
            VALUES ($1, $2, $3, 'assistant', $4, $5, $6)
        `, [companyId, userId, sessionId, aiResponse.text, relatedFeature, JSON.stringify(aiResponse.suggestedAction)]);

        // 分析リクエストを記録
        await pool.query(`
            INSERT INTO ai_analysis_requests (company_id, user_id, request_type, request_text, context_data, response_text, response_data, model_used, tokens_used, processing_time_ms)
            VALUES ($1, $2, 'query', $3, $4, $5, $6, $7, $8, $9)
        `, [companyId, userId, message, JSON.stringify(contextData), aiResponse.text,
            JSON.stringify(aiResponse.data), aiResponse.model, aiResponse.tokensUsed, aiResponse.processingTime]);

        res.json({
            message: aiResponse.text,
            suggestedAction: aiResponse.suggestedAction,
            tokensUsed: aiResponse.tokensUsed
        });
    } catch (error) {
        console.error('Error sending chat message:', error);
        res.status(500).json({ error: 'Failed to send chat message' });
    }
};

/**
 * チャット履歴取得
 */
export const getChatHistory = async (req: Request, res: Response) => {
    try {
        const { sessionId } = req.params;

        const result = await pool.query(`
            SELECT * FROM ai_chat_history
            WHERE session_id = $1
            ORDER BY created_at ASC
        `, [sessionId]);

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching chat history:', error);
        res.status(500).json({ error: 'Failed to fetch chat history' });
    }
};

/**
 * ユーザーのセッション一覧取得
 */
export const getUserSessions = async (req: Request, res: Response) => {
    try {
        const { userId } = req.params;
        const { limit = 20 } = req.query;

        const result = await pool.query(`
            SELECT DISTINCT ON (session_id)
                session_id,
                related_feature,
                MIN(created_at) as started_at,
                MAX(created_at) as last_message_at
            FROM ai_chat_history
            WHERE user_id = $1
            GROUP BY session_id, related_feature
            ORDER BY session_id, MAX(created_at) DESC
            LIMIT $2
        `, [userId, limit]);

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching user sessions:', error);
        res.status(500).json({ error: 'Failed to fetch user sessions' });
    }
};

// ============================================
// AI分析機能
// ============================================

/**
 * 配車最適化提案
 */
export const getDispatchOptimization = async (req: Request, res: Response) => {
    try {
        const { companyId, date } = req.query;

        // 当日の配車データを取得
        const ordersResult = await pool.query(`
            SELECT o.*, d.name as driver_name, v.plate_number
            FROM orders o
            LEFT JOIN drivers d ON o.driver_id = d.id
            LEFT JOIN vehicles v ON o.vehicle_id = v.id
            WHERE o.company_id = $1 AND DATE(o.pickup_datetime) = $2
            ORDER BY o.pickup_datetime
        `, [companyId, date]);

        // ドライバーの稼働状況
        const driversResult = await pool.query(`
            SELECT d.*,
                   COUNT(o.id) as assigned_orders,
                   SUM(CASE WHEN o.status = 'completed' THEN 1 ELSE 0 END) as completed_orders
            FROM drivers d
            LEFT JOIN orders o ON d.id = o.driver_id AND DATE(o.pickup_datetime) = $2
            WHERE d.company_id = $1 AND d.status = 'active'
            GROUP BY d.id
        `, [companyId, date]);

        // AI分析を実行（実際にはOpenAI APIを呼び出す）
        const analysis = await analyzeDispatch(ordersResult.rows, driversResult.rows);

        // 分析結果を記録
        await pool.query(`
            INSERT INTO ai_analysis_requests (company_id, request_type, request_text, context_data, response_text, response_data, model_used)
            VALUES ($1, 'analysis', '配車最適化分析', $2, $3, $4, 'gpt-4')
        `, [companyId, JSON.stringify({ orders: ordersResult.rows, drivers: driversResult.rows }),
            analysis.summary, JSON.stringify(analysis)]);

        res.json(analysis);
    } catch (error) {
        console.error('Error getting dispatch optimization:', error);
        res.status(500).json({ error: 'Failed to get dispatch optimization' });
    }
};

/**
 * コスト分析・削減提案
 */
export const getCostAnalysis = async (req: Request, res: Response) => {
    try {
        const { companyId, startDate, endDate } = req.query;

        // コストデータを取得
        const costResult = await pool.query(`
            SELECT
                DATE_TRUNC('week', o.completed_at) as week,
                COUNT(*) as order_count,
                SUM(o.fare_amount) as total_fare,
                SUM(o.fuel_surcharge) as total_fuel_surcharge,
                AVG(o.fare_amount) as avg_fare
            FROM orders o
            WHERE o.company_id = $1
              AND o.completed_at BETWEEN $2 AND $3
              AND o.status = 'completed'
            GROUP BY DATE_TRUNC('week', o.completed_at)
            ORDER BY week
        `, [companyId, startDate, endDate]);

        // 燃料コスト
        const fuelResult = await pool.query(`
            SELECT
                DATE_TRUNC('week', fr.refuel_date) as week,
                SUM(fr.amount_liters) as total_liters,
                SUM(fr.total_cost) as total_fuel_cost,
                AVG(fr.price_per_liter) as avg_price_per_liter
            FROM fuel_records fr
            JOIN vehicles v ON fr.vehicle_id = v.id
            WHERE v.company_id = $1
              AND fr.refuel_date BETWEEN $2 AND $3
            GROUP BY DATE_TRUNC('week', fr.refuel_date)
            ORDER BY week
        `, [companyId, startDate, endDate]);

        // AI分析を実行
        const analysis = await analyzeCosts(costResult.rows, fuelResult.rows);

        res.json(analysis);
    } catch (error) {
        console.error('Error getting cost analysis:', error);
        res.status(500).json({ error: 'Failed to get cost analysis' });
    }
};

/**
 * コンプライアンスアラート
 */
export const getComplianceAlerts = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        const alerts: any[] = [];

        // 運転時間超過チェック
        const drivingTimeResult = await pool.query(`
            SELECT d.id, d.name,
                   SUM(EXTRACT(EPOCH FROM (dr.end_time - dr.start_time))/3600) as total_hours
            FROM drivers d
            JOIN driving_records dr ON d.id = dr.driver_id
            WHERE d.company_id = $1
              AND dr.driving_date >= CURRENT_DATE - INTERVAL '7 days'
            GROUP BY d.id, d.name
            HAVING SUM(EXTRACT(EPOCH FROM (dr.end_time - dr.start_time))/3600) > 40
        `, [companyId]);

        drivingTimeResult.rows.forEach(row => {
            alerts.push({
                type: 'driving_time_exceeded',
                severity: 'warning',
                driver: row.name,
                message: `過去7日間の運転時間が${row.total_hours.toFixed(1)}時間です（基準: 40時間）`,
                recommendation: '休息を確保し、配車を調整してください'
            });
        });

        // 車検期限チェック
        const inspectionResult = await pool.query(`
            SELECT plate_number, inspection_expiry
            FROM vehicles
            WHERE company_id = $1
              AND inspection_expiry <= CURRENT_DATE + INTERVAL '30 days'
              AND status = 'active'
        `, [companyId]);

        inspectionResult.rows.forEach(row => {
            alerts.push({
                type: 'inspection_expiring',
                severity: row.inspection_expiry <= new Date() ? 'critical' : 'warning',
                vehicle: row.plate_number,
                message: `車検期限: ${row.inspection_expiry}`,
                recommendation: '車検の予約を行ってください'
            });
        });

        // 取引条件書の期限チェック
        const termsResult = await pool.query(`
            SELECT tt.terms_number, s.name as shipper_name, tt.expiry_date
            FROM transaction_terms tt
            JOIN shippers s ON tt.shipper_id = s.id
            WHERE tt.company_id = $1
              AND tt.status = 'active'
              AND tt.expiry_date <= CURRENT_DATE + INTERVAL '30 days'
        `, [companyId]);

        termsResult.rows.forEach(row => {
            alerts.push({
                type: 'terms_expiring',
                severity: 'info',
                shipper: row.shipper_name,
                message: `取引条件書 ${row.terms_number} が ${row.expiry_date} に期限切れ`,
                recommendation: '荷主と取引条件の更新交渉を行ってください'
            });
        });

        res.json({
            totalAlerts: alerts.length,
            criticalCount: alerts.filter(a => a.severity === 'critical').length,
            warningCount: alerts.filter(a => a.severity === 'warning').length,
            infoCount: alerts.filter(a => a.severity === 'info').length,
            alerts
        });
    } catch (error) {
        console.error('Error getting compliance alerts:', error);
        res.status(500).json({ error: 'Failed to get compliance alerts' });
    }
};

// ============================================
// AIレポート生成
// ============================================

/**
 * 日次サマリーレポート生成
 */
export const generateDailySummary = async (req: Request, res: Response) => {
    try {
        const { companyId, date } = req.query;

        // 当日のデータを収集
        const ordersResult = await pool.query(`
            SELECT
                COUNT(*) as total_orders,
                COUNT(*) FILTER (WHERE status = 'completed') as completed_orders,
                COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_orders,
                SUM(fare_amount) FILTER (WHERE status = 'completed') as total_revenue
            FROM orders
            WHERE company_id = $1 AND DATE(created_at) = $2
        `, [companyId, date]);

        const driversResult = await pool.query(`
            SELECT
                COUNT(DISTINCT driver_id) as active_drivers
            FROM orders
            WHERE company_id = $1 AND DATE(pickup_datetime) = $2
        `, [companyId, date]);

        // レポートを生成
        const reportData = {
            date,
            orders: ordersResult.rows[0],
            drivers: driversResult.rows[0]
        };

        const summary = `${date}の業務サマリー: 受注${reportData.orders.total_orders}件、完了${reportData.orders.completed_orders}件、売上${reportData.orders.total_revenue || 0}円`;

        // レポートを保存
        const result = await pool.query(`
            INSERT INTO ai_generated_reports (company_id, report_type, report_title, report_period_start, report_period_end, summary, key_findings, source_data)
            VALUES ($1, 'daily_summary', $2, $3, $3, $4, $5, $6)
            RETURNING *
        `, [companyId, `${date} 日次レポート`, date, summary, JSON.stringify([
            { finding: '完了率', value: `${((reportData.orders.completed_orders / reportData.orders.total_orders) * 100).toFixed(1)}%` },
            { finding: '稼働ドライバー数', value: reportData.drivers.active_drivers }
        ]), JSON.stringify(reportData)]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error generating daily summary:', error);
        res.status(500).json({ error: 'Failed to generate daily summary' });
    }
};

/**
 * レポート一覧取得
 */
export const getReports = async (req: Request, res: Response) => {
    try {
        const { companyId, reportType, limit = 20 } = req.query;

        let query = `
            SELECT * FROM ai_generated_reports
            WHERE company_id = $1
        `;
        const params: any[] = [companyId];

        if (reportType) {
            query += ` AND report_type = $2`;
            params.push(reportType);
        }

        query += ` ORDER BY generated_at DESC LIMIT $${params.length + 1}`;
        params.push(limit);

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching reports:', error);
        res.status(500).json({ error: 'Failed to fetch reports' });
    }
};

/**
 * レポート詳細取得
 */
export const getReportById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(`
            SELECT * FROM ai_generated_reports WHERE id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Report not found' });
        }

        // 閲覧日時を記録
        await pool.query(`
            UPDATE ai_generated_reports SET viewed_at = NOW() WHERE id = $1
        `, [id]);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching report:', error);
        res.status(500).json({ error: 'Failed to fetch report' });
    }
};

// ============================================
// ヘルパー関数
// ============================================

/**
 * コンテキストデータ取得
 */
async function getContextData(entityType: string, entityId: number): Promise<any> {
    try {
        let query = '';
        switch (entityType) {
            case 'order':
                query = `SELECT o.*, d.name as driver_name, v.plate_number FROM orders o
                         LEFT JOIN drivers d ON o.driver_id = d.id
                         LEFT JOIN vehicles v ON o.vehicle_id = v.id
                         WHERE o.id = $1`;
                break;
            case 'driver':
                query = `SELECT * FROM drivers WHERE id = $1`;
                break;
            case 'vehicle':
                query = `SELECT * FROM vehicles WHERE id = $1`;
                break;
            default:
                return null;
        }
        const result = await pool.query(query, [entityId]);
        return result.rows[0] || null;
    } catch (error) {
        console.error('Error fetching context data:', error);
        return null;
    }
}

/**
 * AI応答生成（実際の実装ではOpenAI APIを呼び出す）
 */
async function generateAiResponse(companyId: number, sessionId: string, message: string, contextData: any): Promise<any> {
    // 実際の実装ではOpenAI APIを呼び出す
    // ここではモック応答を返す
    const startTime = Date.now();

    // 会話履歴を取得
    const historyResult = await pool.query(`
        SELECT role, content FROM ai_chat_history
        WHERE session_id = $1
        ORDER BY created_at ASC
        LIMIT 10
    `, [sessionId]);

    // TODO: OpenAI API呼び出し
    // const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    // const completion = await openai.chat.completions.create({ ... });

    const processingTime = Date.now() - startTime;

    return {
        text: `ご質問「${message}」について確認しました。詳細な回答を準備中です。`,
        suggestedAction: null,
        data: { context: contextData },
        model: 'gpt-4',
        tokensUsed: 150,
        processingTime
    };
}

/**
 * 配車分析（実際の実装ではOpenAI APIを呼び出す）
 */
async function analyzeDispatch(orders: any[], drivers: any[]): Promise<any> {
    // 実際の実装ではOpenAI APIを呼び出す
    return {
        summary: '配車状況の分析結果',
        utilizationRate: (orders.length / (drivers.length * 3) * 100).toFixed(1) + '%',
        recommendations: [
            '効率的なルート設定により燃料コストを削減できる可能性があります',
            'ドライバーの稼働バランスを調整することをお勧めします'
        ],
        optimizedRoutes: []
    };
}

/**
 * コスト分析（実際の実装ではOpenAI APIを呼び出す）
 */
async function analyzeCosts(revenueData: any[], fuelData: any[]): Promise<any> {
    // 実際の実装ではOpenAI APIを呼び出す
    const totalRevenue = revenueData.reduce((sum, r) => sum + parseFloat(r.total_fare || 0), 0);
    const totalFuelCost = fuelData.reduce((sum, f) => sum + parseFloat(f.total_fuel_cost || 0), 0);

    return {
        summary: 'コスト分析結果',
        totalRevenue,
        totalFuelCost,
        fuelCostRatio: ((totalFuelCost / totalRevenue) * 100).toFixed(1) + '%',
        recommendations: [
            '燃費効率の良い運転を推進することでコスト削減が期待できます',
            'ルート最適化により走行距離を削減できる可能性があります'
        ],
        trends: {
            revenue: revenueData,
            fuel: fuelData
        }
    };
}
