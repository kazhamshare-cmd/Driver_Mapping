/**
 * パイオニア VehicleAssist Connector
 * デジタコ・カーナビ連携API
 */

import axios, { AxiosInstance } from 'axios';
import crypto from 'crypto';
import { pool } from '../utils/db';

// VehicleAssist API設定
interface VehicleAssistConfig {
    endpoint: string;
    customerCode: string;
    contractId: string;
    apiKey: string;
    apiSecret: string;
}

// 運行データ
interface VAOperationRecord {
    recordId: string;
    driverCode: string;
    driverName: string;
    vehicleId: string;
    vehicleNumber: string;
    operationDate: string;
    departureTime: string;
    arrivalTime: string;
    departureLocation: { lat: number; lng: number; address: string };
    arrivalLocation: { lat: number; lng: number; address: string };
    distance: number;
    drivingDuration: number;
    restDuration: number;
    maxSpeed: number;
    avgSpeed: number;
    fuelConsumption: number;
    safetyEvents: {
        harshBraking: number;
        harshAcceleration: number;
        harshCornering: number;
        speeding: number;
    };
    scores: {
        safety: number;
        eco: number;
        overall: number;
    };
}

// 車両位置情報
interface VAVehicleLocation {
    vehicleId: string;
    vehicleNumber: string;
    driverCode: string;
    timestamp: string;
    position: { lat: number; lng: number };
    speed: number;
    heading: number;
    status: string;  // 'driving', 'stopped', 'parked'
    address: string;
}

// 運行指示（カーナビ連携）
interface VANavigationInstruction {
    vehicleId: string;
    destinations: Array<{
        order: number;
        name: string;
        address: string;
        lat: number;
        lng: number;
        scheduledTime: string;
        notes: string;
    }>;
}

export class VehicleAssistConnector {
    private config: VehicleAssistConfig;
    private client: AxiosInstance;
    private integrationId: number;

    constructor(integrationId: number, config: VehicleAssistConfig) {
        this.integrationId = integrationId;
        this.config = config;
        this.client = axios.create({
            baseURL: config.endpoint,
            timeout: 30000,
            headers: {
                'Content-Type': 'application/json'
            }
        });
    }

    /**
     * API署名生成（HMAC-SHA256）
     */
    private generateSignature(timestamp: string, body: string): string {
        const message = `${timestamp}${body}`;
        return crypto
            .createHmac('sha256', this.config.apiSecret)
            .update(message)
            .digest('hex');
    }

    /**
     * 認証ヘッダー付きリクエスト
     */
    private async signedRequest(method: string, path: string, data?: any): Promise<any> {
        const timestamp = new Date().toISOString();
        const body = data ? JSON.stringify(data) : '';
        const signature = this.generateSignature(timestamp, body);

        const response = await this.client.request({
            method,
            url: path,
            data,
            headers: {
                'X-API-Key': this.config.apiKey,
                'X-Timestamp': timestamp,
                'X-Signature': signature,
                'X-Customer-Code': this.config.customerCode,
                'X-Contract-Id': this.config.contractId
            }
        });

        return response.data;
    }

    /**
     * 接続テスト
     */
    async testConnection(): Promise<{ success: boolean; message: string }> {
        try {
            await this.signedRequest('GET', '/api/v1/status');
            return { success: true, message: '接続成功' };
        } catch (error: any) {
            return { success: false, message: error.message };
        }
    }

    /**
     * 運行データ取得
     */
    async fetchOperationRecords(startDate: string, endDate: string): Promise<VAOperationRecord[]> {
        const syncLogId = await this.createSyncLog('import_records', 'inbound');

        try {
            const response = await this.signedRequest('GET', '/api/v1/operations', {
                startDate,
                endDate
            });

            const records: VAOperationRecord[] = response.data || [];

            await this.updateSyncLog(syncLogId, 'completed', records.length, records.length, 0);

            return records;
        } catch (error: any) {
            await this.updateSyncLog(syncLogId, 'failed', 0, 0, 0, error.message);
            throw error;
        }
    }

    /**
     * 運行データをDBに保存
     */
    async importOperationRecords(records: VAOperationRecord[], companyId: number): Promise<{ imported: number; failed: number }> {
        const client = await pool.connect();
        let imported = 0;
        let failed = 0;

        try {
            await client.query('BEGIN');

            for (const record of records) {
                try {
                    // ドライバーマッピング取得
                    const driverMapping = await client.query(
                        `SELECT driver_id FROM tachograph_driver_mappings
                         WHERE integration_id = $1 AND external_driver_code = $2 AND is_active = true`,
                        [this.integrationId, record.driverCode]
                    );

                    // 車両マッピング取得
                    const vehicleMapping = await client.query(
                        `SELECT vehicle_id FROM tachograph_vehicle_mappings
                         WHERE integration_id = $1 AND external_vehicle_id = $2 AND is_active = true`,
                        [this.integrationId, record.vehicleId]
                    );

                    // tachograph_dataに保存
                    const tachoResult = await client.query(
                        `INSERT INTO tachograph_data (
                            import_id, integration_id, external_record_id,
                            driver_code, vehicle_number, record_date,
                            start_time, end_time, distance,
                            max_speed, avg_speed,
                            driving_time_minutes, rest_time_minutes,
                            harsh_braking_count, harsh_acceleration_count, speeding_count,
                            match_status, raw_data
                        ) VALUES (
                            NULL, $1, $2, $3, $4, $5,
                            $6, $7, $8, $9, $10,
                            $11, $12, $13, $14, $15, 'unmatched', $16
                        )
                        ON CONFLICT (integration_id, external_record_id) DO UPDATE SET
                            distance = EXCLUDED.distance,
                            updated_at = NOW()
                        RETURNING id`,
                        [
                            this.integrationId,
                            record.recordId,
                            record.driverCode,
                            record.vehicleNumber,
                            record.operationDate,
                            record.departureTime,
                            record.arrivalTime,
                            record.distance,
                            record.maxSpeed,
                            record.avgSpeed,
                            record.drivingDuration,
                            record.restDuration,
                            record.safetyEvents.harshBraking,
                            record.safetyEvents.harshAcceleration,
                            record.safetyEvents.speeding,
                            JSON.stringify(record)
                        ]
                    );

                    const tachoDataId = tachoResult.rows[0]?.id;

                    // 運転評価データ保存
                    if (record.scores) {
                        const driverId = driverMapping.rows[0]?.driver_id || null;
                        const vehicleId = vehicleMapping.rows[0]?.vehicle_id || null;

                        await client.query(
                            `INSERT INTO driving_evaluations (
                                company_id, driver_id, vehicle_id, tachograph_data_id, evaluation_date,
                                safety_score, eco_score, overall_score,
                                harsh_braking_count, harsh_acceleration_count, harsh_cornering_count, speeding_count,
                                fuel_consumption
                            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
                            ON CONFLICT DO NOTHING`,
                            [
                                companyId,
                                driverId,
                                vehicleId,
                                tachoDataId,
                                record.operationDate,
                                record.scores.safety,
                                record.scores.eco,
                                record.scores.overall,
                                record.safetyEvents.harshBraking,
                                record.safetyEvents.harshAcceleration,
                                record.safetyEvents.harshCornering,
                                record.safetyEvents.speeding,
                                record.fuelConsumption
                            ]
                        );
                    }

                    imported++;
                } catch (err) {
                    console.error('Failed to import VA record:', err);
                    failed++;
                }
            }

            await client.query('COMMIT');
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }

        return { imported, failed };
    }

    /**
     * リアルタイム車両位置取得
     */
    async fetchVehicleLocations(): Promise<VAVehicleLocation[]> {
        try {
            const response = await this.signedRequest('GET', '/api/v1/vehicles/realtime');
            return response.data || [];
        } catch (error: any) {
            console.error('Failed to fetch VA vehicle locations:', error.message);
            throw error;
        }
    }

    /**
     * 位置情報をDBに保存
     */
    async saveVehicleLocations(locations: VAVehicleLocation[], companyId: number): Promise<void> {
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            for (const loc of locations) {
                // 車両マッピング取得
                const vehicleMapping = await client.query(
                    `SELECT vehicle_id FROM tachograph_vehicle_mappings
                     WHERE integration_id = $1 AND external_vehicle_id = $2 AND is_active = true`,
                    [this.integrationId, loc.vehicleId]
                );

                const vehicleId = vehicleMapping.rows[0]?.vehicle_id;
                if (!vehicleId) continue;

                // ドライバーマッピング取得
                const driverMapping = await client.query(
                    `SELECT driver_id FROM tachograph_driver_mappings
                     WHERE integration_id = $1 AND external_driver_code = $2 AND is_active = true`,
                    [this.integrationId, loc.driverCode]
                );

                await client.query(
                    `INSERT INTO vehicle_location_history (
                        company_id, vehicle_id, driver_id, integration_id, recorded_at,
                        latitude, longitude, speed, heading, engine_status, address
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
                    [
                        companyId,
                        vehicleId,
                        driverMapping.rows[0]?.driver_id || null,
                        this.integrationId,
                        loc.timestamp,
                        loc.position.lat,
                        loc.position.lng,
                        loc.speed,
                        loc.heading,
                        loc.status,
                        loc.address
                    ]
                );
            }

            await client.query('COMMIT');
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
        }
    }

    /**
     * カーナビに運行指示送信
     */
    async sendNavigationInstruction(instruction: VANavigationInstruction, dispatchId: number, userId: number): Promise<{ success: boolean; error?: string }> {
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            // 送信履歴作成
            const sendResult = await client.query(
                `INSERT INTO tachograph_instruction_sends (
                    integration_id, dispatch_id, instruction_type, sent_by, request_data
                ) VALUES ($1, $2, 'new', $3, $4)
                RETURNING id`,
                [this.integrationId, dispatchId, userId, JSON.stringify(instruction)]
            );
            const sendId = sendResult.rows[0].id;

            // API送信
            const response = await this.signedRequest('POST', '/api/v1/navigation/route', instruction);

            // 送信履歴更新
            await client.query(
                `UPDATE tachograph_instruction_sends
                 SET status = 'sent', response_data = $1
                 WHERE id = $2`,
                [JSON.stringify(response), sendId]
            );

            await client.query('COMMIT');

            return { success: true };
        } catch (error: any) {
            await client.query('ROLLBACK');
            return { success: false, error: error.message };
        } finally {
            client.release();
        }
    }

    /**
     * マスタデータ同期
     */
    async syncMasterData(companyId: number): Promise<{ drivers: number; vehicles: number }> {
        const syncLogId = await this.createSyncLog('sync_master', 'inbound');

        try {
            // ドライバー一覧取得
            const driverResponse = await this.signedRequest('GET', '/api/v1/masters/drivers');

            // 車両一覧取得
            const vehicleResponse = await this.signedRequest('GET', '/api/v1/masters/vehicles');

            const client = await pool.connect();
            let driverCount = 0;
            let vehicleCount = 0;

            try {
                await client.query('BEGIN');

                // ドライバーマッピング更新
                for (const driver of (driverResponse.data || [])) {
                    await client.query(
                        `INSERT INTO tachograph_driver_mappings (
                            integration_id, external_driver_id, external_driver_code, external_driver_name
                        ) VALUES ($1, $2, $3, $4)
                        ON CONFLICT (integration_id, external_driver_id) DO UPDATE SET
                            external_driver_code = EXCLUDED.external_driver_code,
                            external_driver_name = EXCLUDED.external_driver_name`,
                        [this.integrationId, driver.id, driver.code, driver.name]
                    );
                    driverCount++;
                }

                // 車両マッピング更新
                for (const vehicle of (vehicleResponse.data || [])) {
                    await client.query(
                        `INSERT INTO tachograph_vehicle_mappings (
                            integration_id, external_vehicle_id, external_vehicle_number, external_device_id
                        ) VALUES ($1, $2, $3, $4)
                        ON CONFLICT (integration_id, external_vehicle_id) DO UPDATE SET
                            external_vehicle_number = EXCLUDED.external_vehicle_number,
                            external_device_id = EXCLUDED.external_device_id`,
                        [this.integrationId, vehicle.id, vehicle.number, vehicle.deviceId]
                    );
                    vehicleCount++;
                }

                await client.query('COMMIT');
            } finally {
                client.release();
            }

            await this.updateSyncLog(syncLogId, 'completed', driverCount + vehicleCount, driverCount + vehicleCount, 0);

            return { drivers: driverCount, vehicles: vehicleCount };
        } catch (error: any) {
            await this.updateSyncLog(syncLogId, 'failed', 0, 0, 0, error.message);
            throw error;
        }
    }

    /**
     * 同期ログ作成
     */
    private async createSyncLog(syncType: string, direction: string): Promise<number> {
        const result = await pool.query(
            `INSERT INTO tachograph_sync_logs (integration_id, sync_type, sync_direction)
             VALUES ($1, $2, $3) RETURNING id`,
            [this.integrationId, syncType, direction]
        );
        return result.rows[0].id;
    }

    /**
     * 同期ログ更新
     */
    private async updateSyncLog(
        logId: number,
        status: string,
        processed: number,
        success: number,
        failed: number,
        errorMessage?: string
    ): Promise<void> {
        await pool.query(
            `UPDATE tachograph_sync_logs
             SET status = $1, records_processed = $2, records_success = $3,
                 records_failed = $4, error_message = $5, completed_at = NOW()
             WHERE id = $6`,
            [status, processed, success, failed, errorMessage || null, logId]
        );
    }
}

/**
 * 統合設定からコネクタを作成
 */
export async function createVehicleAssistConnector(integrationId: number): Promise<VehicleAssistConnector> {
    const result = await pool.query(
        `SELECT * FROM tachograph_integrations WHERE id = $1 AND provider = 'pioneer_vehicle_assist'`,
        [integrationId]
    );

    if (result.rows.length === 0) {
        throw new Error('VehicleAssist連携設定が見つかりません');
    }

    const integration = result.rows[0];

    const config: VehicleAssistConfig = {
        endpoint: integration.api_endpoint,
        customerCode: integration.pioneer_customer_code,
        contractId: integration.pioneer_contract_id,
        apiKey: integration.api_key,
        apiSecret: integration.api_secret
    };

    return new VehicleAssistConnector(integrationId, config);
}
