/**
 * Tachograph Integration Controller
 * デジタコ連携統合管理（設定・同期・マッピング）
 */

import { Request, Response } from 'express';
import { pool } from '../utils/db';
import { createITPConnector } from '../services/itpWebServiceConnector';
import { createVehicleAssistConnector } from '../services/vehicleAssistConnector';

// 対応プロバイダー一覧
const PROVIDERS = [
    {
        id: 'fujitsu_itp',
        name: '富士通 ITP-WebService V3',
        description: 'デジタコ連携、運行指示送信対応',
        features: ['運行データ取込', '運行指示送信', 'リアルタイム位置', 'マスタ同期']
    },
    {
        id: 'pioneer_vehicle_assist',
        name: 'パイオニア VehicleAssist',
        description: 'デジタコ・カーナビ連携',
        features: ['運行データ取込', 'カーナビ連携', 'リアルタイム位置', 'マスタ同期']
    },
    {
        id: 'yazaki',
        name: '矢崎 DTG/DTS',
        description: 'CSV取込対応（手動アップロード）',
        features: ['CSVインポート', '自動マッチング']
    },
    {
        id: 'denso',
        name: 'デンソー',
        description: 'CSV取込対応（手動アップロード）',
        features: ['CSVインポート', '自動マッチング']
    },
    {
        id: 'custom',
        name: 'カスタム連携',
        description: '汎用CSV/API連携',
        features: ['CSVインポート', 'API連携']
    }
];

/**
 * 対応プロバイダー一覧取得
 */
export const getProviders = async (req: Request, res: Response) => {
    res.json(PROVIDERS);
};

/**
 * 連携設定一覧取得
 */
export const getIntegrations = async (req: Request, res: Response) => {
    try {
        const companyId = (req as any).user?.companyId;

        const result = await pool.query(
            `SELECT
                ti.*,
                (SELECT COUNT(*) FROM tachograph_driver_mappings WHERE integration_id = ti.id AND is_active = true) as mapped_drivers,
                (SELECT COUNT(*) FROM tachograph_vehicle_mappings WHERE integration_id = ti.id AND is_active = true) as mapped_vehicles,
                (SELECT COUNT(*) FROM tachograph_sync_logs WHERE integration_id = ti.id AND status = 'completed') as sync_count
             FROM tachograph_integrations ti
             WHERE ti.company_id = $1
             ORDER BY ti.created_at DESC`,
            [companyId]
        );

        // パスワード等の機密情報を除外
        const integrations = result.rows.map(row => ({
            ...row,
            password: row.password ? '********' : null,
            api_secret: row.api_secret ? '********' : null
        }));

        res.json(integrations);
    } catch (error) {
        console.error('Error fetching integrations:', error);
        res.status(500).json({ error: '連携設定の取得に失敗しました' });
    }
};

/**
 * 連携設定詳細取得
 */
export const getIntegrationById = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const companyId = (req as any).user?.companyId;

        const result = await pool.query(
            `SELECT * FROM tachograph_integrations
             WHERE id = $1 AND company_id = $2`,
            [id, companyId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: '連携設定が見つかりません' });
        }

        const integration = result.rows[0];

        // パスワード等の機密情報を除外
        integration.password = integration.password ? '********' : null;
        integration.api_secret = integration.api_secret ? '********' : null;

        res.json(integration);
    } catch (error) {
        console.error('Error fetching integration:', error);
        res.status(500).json({ error: '連携設定の取得に失敗しました' });
    }
};

/**
 * 連携設定作成
 */
export const createIntegration = async (req: Request, res: Response) => {
    try {
        const companyId = (req as any).user?.companyId;
        const {
            provider,
            integration_name,
            api_endpoint,
            api_key,
            api_secret,
            username,
            password,
            itp_company_code,
            itp_terminal_id,
            pioneer_customer_code,
            pioneer_contract_id,
            sync_enabled,
            sync_interval_minutes,
            auto_import_records,
            auto_send_instructions,
            sync_master_data,
            driver_mapping_method,
            vehicle_mapping_method
        } = req.body;

        // プロバイダーの重複チェック
        const existingCheck = await pool.query(
            `SELECT id FROM tachograph_integrations WHERE company_id = $1 AND provider = $2`,
            [companyId, provider]
        );

        if (existingCheck.rows.length > 0) {
            return res.status(400).json({ error: 'このプロバイダーの連携設定は既に存在します' });
        }

        const result = await pool.query(
            `INSERT INTO tachograph_integrations (
                company_id, provider, integration_name, api_endpoint,
                api_key, api_secret, username, password,
                itp_company_code, itp_terminal_id,
                pioneer_customer_code, pioneer_contract_id,
                sync_enabled, sync_interval_minutes,
                auto_import_records, auto_send_instructions, sync_master_data,
                driver_mapping_method, vehicle_mapping_method, status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, 'inactive')
            RETURNING id`,
            [
                companyId, provider, integration_name, api_endpoint,
                api_key, api_secret, username, password,
                itp_company_code, itp_terminal_id,
                pioneer_customer_code, pioneer_contract_id,
                sync_enabled || false, sync_interval_minutes || 60,
                auto_import_records ?? true, auto_send_instructions ?? false, sync_master_data ?? false,
                driver_mapping_method || 'employee_number', vehicle_mapping_method || 'vehicle_number'
            ]
        );

        res.status(201).json({
            id: result.rows[0].id,
            message: '連携設定を作成しました'
        });
    } catch (error) {
        console.error('Error creating integration:', error);
        res.status(500).json({ error: '連携設定の作成に失敗しました' });
    }
};

/**
 * 連携設定更新
 */
export const updateIntegration = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const companyId = (req as any).user?.companyId;
        const updates = req.body;

        // パスワードが'********'の場合は更新しない
        if (updates.password === '********') delete updates.password;
        if (updates.api_secret === '********') delete updates.api_secret;

        const fields: string[] = [];
        const values: any[] = [];
        let paramIndex = 1;

        Object.entries(updates).forEach(([key, value]) => {
            if (key !== 'id' && key !== 'company_id') {
                fields.push(`${key} = $${paramIndex}`);
                values.push(value);
                paramIndex++;
            }
        });

        if (fields.length === 0) {
            return res.status(400).json({ error: '更新する項目がありません' });
        }

        fields.push('updated_at = NOW()');

        values.push(id, companyId);

        await pool.query(
            `UPDATE tachograph_integrations
             SET ${fields.join(', ')}
             WHERE id = $${paramIndex} AND company_id = $${paramIndex + 1}`,
            values
        );

        res.json({ message: '連携設定を更新しました' });
    } catch (error) {
        console.error('Error updating integration:', error);
        res.status(500).json({ error: '連携設定の更新に失敗しました' });
    }
};

/**
 * 接続テスト
 */
export const testConnection = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const companyId = (req as any).user?.companyId;

        const result = await pool.query(
            `SELECT * FROM tachograph_integrations WHERE id = $1 AND company_id = $2`,
            [id, companyId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: '連携設定が見つかりません' });
        }

        const integration = result.rows[0];
        let testResult: { success: boolean; message: string };

        switch (integration.provider) {
            case 'fujitsu_itp':
                const itpConnector = await createITPConnector(parseInt(id));
                testResult = await itpConnector.testConnection();
                break;
            case 'pioneer_vehicle_assist':
                const vaConnector = await createVehicleAssistConnector(parseInt(id));
                testResult = await vaConnector.testConnection();
                break;
            case 'yazaki':
            case 'denso':
                // CSVベースのため接続テストは成功とする
                testResult = { success: true, message: 'CSVインポート形式（接続テスト不要）' };
                break;
            default:
                testResult = { success: false, message: '未対応のプロバイダーです' };
        }

        // 結果に応じてステータス更新
        await pool.query(
            `UPDATE tachograph_integrations
             SET status = $1, error_message = $2, updated_at = NOW()
             WHERE id = $3`,
            [
                testResult.success ? 'active' : 'error',
                testResult.success ? null : testResult.message,
                id
            ]
        );

        res.json(testResult);
    } catch (error: any) {
        console.error('Error testing connection:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * 手動同期実行
 */
export const triggerSync = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { sync_type, start_date, end_date } = req.body;
        const companyId = (req as any).user?.companyId;

        const result = await pool.query(
            `SELECT * FROM tachograph_integrations WHERE id = $1 AND company_id = $2`,
            [id, companyId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: '連携設定が見つかりません' });
        }

        const integration = result.rows[0];
        let syncResult: any;

        // 日付デフォルト（過去7日間）
        const defaultStartDate = new Date();
        defaultStartDate.setDate(defaultStartDate.getDate() - 7);
        const startDateStr = start_date || defaultStartDate.toISOString().split('T')[0];
        const endDateStr = end_date || new Date().toISOString().split('T')[0];

        switch (integration.provider) {
            case 'fujitsu_itp':
                const itpConnector = await createITPConnector(parseInt(id));
                if (sync_type === 'master') {
                    syncResult = await itpConnector.syncMasterData(companyId);
                } else {
                    const records = await itpConnector.fetchOperationRecords(startDateStr, endDateStr);
                    const importResult = await itpConnector.importOperationRecords(records, companyId);
                    syncResult = { records_fetched: records.length, ...importResult };
                }
                break;
            case 'pioneer_vehicle_assist':
                const vaConnector = await createVehicleAssistConnector(parseInt(id));
                if (sync_type === 'master') {
                    syncResult = await vaConnector.syncMasterData(companyId);
                } else {
                    const records = await vaConnector.fetchOperationRecords(startDateStr, endDateStr);
                    const importResult = await vaConnector.importOperationRecords(records, companyId);
                    syncResult = { records_fetched: records.length, ...importResult };
                }
                break;
            default:
                return res.status(400).json({ error: 'このプロバイダーは手動同期に対応していません' });
        }

        // 最終同期日時更新
        await pool.query(
            `UPDATE tachograph_integrations
             SET last_sync_at = NOW(), next_sync_at = NOW() + ($1 || ' minutes')::INTERVAL
             WHERE id = $2`,
            [integration.sync_interval_minutes, id]
        );

        res.json({
            success: true,
            sync_type,
            result: syncResult
        });
    } catch (error: any) {
        console.error('Error triggering sync:', error);
        res.status(500).json({ error: error.message });
    }
};

/**
 * ドライバーマッピング一覧取得
 */
export const getDriverMappings = async (req: Request, res: Response) => {
    try {
        const { integrationId } = req.params;
        const companyId = (req as any).user?.companyId;

        // 連携設定の確認
        const integrationCheck = await pool.query(
            `SELECT id FROM tachograph_integrations WHERE id = $1 AND company_id = $2`,
            [integrationId, companyId]
        );

        if (integrationCheck.rows.length === 0) {
            return res.status(404).json({ error: '連携設定が見つかりません' });
        }

        const result = await pool.query(
            `SELECT
                tdm.*,
                u.name as driver_name,
                u.employee_number
             FROM tachograph_driver_mappings tdm
             LEFT JOIN users u ON tdm.driver_id = u.id
             WHERE tdm.integration_id = $1
             ORDER BY tdm.external_driver_code`,
            [integrationId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching driver mappings:', error);
        res.status(500).json({ error: 'ドライバーマッピングの取得に失敗しました' });
    }
};

/**
 * ドライバーマッピング更新
 */
export const updateDriverMapping = async (req: Request, res: Response) => {
    try {
        const { integrationId, mappingId } = req.params;
        const { driver_id, is_active } = req.body;

        await pool.query(
            `UPDATE tachograph_driver_mappings
             SET driver_id = $1, is_active = $2, mapped_at = NOW()
             WHERE id = $3 AND integration_id = $4`,
            [driver_id, is_active ?? true, mappingId, integrationId]
        );

        res.json({ message: 'マッピングを更新しました' });
    } catch (error) {
        console.error('Error updating driver mapping:', error);
        res.status(500).json({ error: 'マッピングの更新に失敗しました' });
    }
};

/**
 * 車両マッピング一覧取得
 */
export const getVehicleMappings = async (req: Request, res: Response) => {
    try {
        const { integrationId } = req.params;
        const companyId = (req as any).user?.companyId;

        // 連携設定の確認
        const integrationCheck = await pool.query(
            `SELECT id FROM tachograph_integrations WHERE id = $1 AND company_id = $2`,
            [integrationId, companyId]
        );

        if (integrationCheck.rows.length === 0) {
            return res.status(404).json({ error: '連携設定が見つかりません' });
        }

        const result = await pool.query(
            `SELECT
                tvm.*,
                v.vehicle_number as system_vehicle_number,
                v.vehicle_type
             FROM tachograph_vehicle_mappings tvm
             LEFT JOIN vehicles v ON tvm.vehicle_id = v.id
             WHERE tvm.integration_id = $1
             ORDER BY tvm.external_vehicle_number`,
            [integrationId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching vehicle mappings:', error);
        res.status(500).json({ error: '車両マッピングの取得に失敗しました' });
    }
};

/**
 * 車両マッピング更新
 */
export const updateVehicleMapping = async (req: Request, res: Response) => {
    try {
        const { integrationId, mappingId } = req.params;
        const { vehicle_id, is_active } = req.body;

        await pool.query(
            `UPDATE tachograph_vehicle_mappings
             SET vehicle_id = $1, is_active = $2, mapped_at = NOW()
             WHERE id = $3 AND integration_id = $4`,
            [vehicle_id, is_active ?? true, mappingId, integrationId]
        );

        res.json({ message: 'マッピングを更新しました' });
    } catch (error) {
        console.error('Error updating vehicle mapping:', error);
        res.status(500).json({ error: 'マッピングの更新に失敗しました' });
    }
};

/**
 * 同期ログ一覧取得
 */
export const getSyncLogs = async (req: Request, res: Response) => {
    try {
        const { integrationId } = req.params;
        const { limit = 50, offset = 0 } = req.query;
        const companyId = (req as any).user?.companyId;

        // 連携設定の確認
        const integrationCheck = await pool.query(
            `SELECT id FROM tachograph_integrations WHERE id = $1 AND company_id = $2`,
            [integrationId, companyId]
        );

        if (integrationCheck.rows.length === 0) {
            return res.status(404).json({ error: '連携設定が見つかりません' });
        }

        const result = await pool.query(
            `SELECT * FROM tachograph_sync_logs
             WHERE integration_id = $1
             ORDER BY started_at DESC
             LIMIT $2 OFFSET $3`,
            [integrationId, limit, offset]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching sync logs:', error);
        res.status(500).json({ error: '同期ログの取得に失敗しました' });
    }
};

/**
 * 運転評価データ取得
 */
export const getDrivingEvaluations = async (req: Request, res: Response) => {
    try {
        const { driver_id, vehicle_id, start_date, end_date, limit = 50 } = req.query;
        const companyId = (req as any).user?.companyId;

        let query = `
            SELECT
                de.*,
                u.name as driver_name,
                v.vehicle_number
            FROM driving_evaluations de
            LEFT JOIN users u ON de.driver_id = u.id
            LEFT JOIN vehicles v ON de.vehicle_id = v.id
            WHERE de.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (driver_id) {
            query += ` AND de.driver_id = $${paramIndex}`;
            params.push(driver_id);
            paramIndex++;
        }

        if (vehicle_id) {
            query += ` AND de.vehicle_id = $${paramIndex}`;
            params.push(vehicle_id);
            paramIndex++;
        }

        if (start_date) {
            query += ` AND de.evaluation_date >= $${paramIndex}`;
            params.push(start_date);
            paramIndex++;
        }

        if (end_date) {
            query += ` AND de.evaluation_date <= $${paramIndex}`;
            params.push(end_date);
            paramIndex++;
        }

        query += ` ORDER BY de.evaluation_date DESC LIMIT $${paramIndex}`;
        params.push(limit);

        const result = await pool.query(query, params);

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching driving evaluations:', error);
        res.status(500).json({ error: '運転評価データの取得に失敗しました' });
    }
};

/**
 * 車両位置履歴取得
 */
export const getVehicleLocationHistory = async (req: Request, res: Response) => {
    try {
        const { vehicle_id, start_time, end_time, limit = 1000 } = req.query;
        const companyId = (req as any).user?.companyId;

        if (!vehicle_id) {
            return res.status(400).json({ error: '車両IDが必要です' });
        }

        let query = `
            SELECT * FROM vehicle_location_history
            WHERE company_id = $1 AND vehicle_id = $2
        `;
        const params: any[] = [companyId, vehicle_id];
        let paramIndex = 3;

        if (start_time) {
            query += ` AND recorded_at >= $${paramIndex}`;
            params.push(start_time);
            paramIndex++;
        }

        if (end_time) {
            query += ` AND recorded_at <= $${paramIndex}`;
            params.push(end_time);
            paramIndex++;
        }

        query += ` ORDER BY recorded_at DESC LIMIT $${paramIndex}`;
        params.push(limit);

        const result = await pool.query(query, params);

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching location history:', error);
        res.status(500).json({ error: '位置履歴の取得に失敗しました' });
    }
};

/**
 * リアルタイム車両位置取得（全車両）
 */
export const getCurrentVehicleLocations = async (req: Request, res: Response) => {
    try {
        const companyId = (req as any).user?.companyId;

        // 各車両の最新位置を取得
        const result = await pool.query(
            `SELECT DISTINCT ON (vehicle_id)
                vlh.*,
                v.vehicle_number,
                v.vehicle_type,
                u.name as driver_name
             FROM vehicle_location_history vlh
             JOIN vehicles v ON vlh.vehicle_id = v.id
             LEFT JOIN users u ON vlh.driver_id = u.id
             WHERE vlh.company_id = $1
               AND vlh.recorded_at > NOW() - INTERVAL '30 minutes'
             ORDER BY vehicle_id, recorded_at DESC`,
            [companyId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching current locations:', error);
        res.status(500).json({ error: '現在位置の取得に失敗しました' });
    }
};
