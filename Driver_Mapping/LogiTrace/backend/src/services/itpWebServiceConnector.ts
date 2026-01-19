/**
 * 富士通 ITP-WebService V3 Connector
 * デジタコ連携API（運行データ取得・運行指示送信）
 */

import axios, { AxiosInstance } from 'axios';
import { pool } from '../utils/db';

// ITP-WebService API設定
interface ITPConfig {
    endpoint: string;
    companyCode: string;
    terminalId: string;
    username: string;
    password: string;
}

// 運行データ
interface ITPOperationRecord {
    operationId: string;
    driverCode: string;
    driverName: string;
    vehicleNumber: string;
    deviceId: string;
    operationDate: string;
    startTime: string;
    endTime: string;
    startOdometer: number;
    endOdometer: number;
    distance: number;
    drivingTime: number;
    restTime: number;
    idleTime: number;
    maxSpeed: number;
    avgSpeed: number;
    fuelConsumption: number;
    harshBrakingCount: number;
    harshAccelerationCount: number;
    speedingCount: number;
    safetyScore: number;
    ecoScore: number;
}

// 位置情報
interface ITPLocationData {
    vehicleNumber: string;
    deviceId: string;
    timestamp: string;
    latitude: number;
    longitude: number;
    speed: number;
    heading: number;
    engineStatus: string;
    eventType: string;
}

// 運行指示
interface ITPInstruction {
    instructionId?: string;
    vehicleNumber: string;
    driverCode: string;
    operationDate: string;
    pickupLocation: string;
    pickupTime: string;
    deliveryLocation: string;
    deliveryTime: string;
    cargo: string;
    notes: string;
}

export class ITPWebServiceConnector {
    private config: ITPConfig;
    private client: AxiosInstance;
    private integrationId: number;
    private accessToken: string | null = null;
    private tokenExpiry: Date | null = null;

    constructor(integrationId: number, config: ITPConfig) {
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
     * 認証トークン取得
     */
    private async authenticate(): Promise<string> {
        // トークンが有効ならそのまま使用
        if (this.accessToken && this.tokenExpiry && new Date() < this.tokenExpiry) {
            return this.accessToken;
        }

        try {
            const response = await this.client.post('/auth/token', {
                companyCode: this.config.companyCode,
                terminalId: this.config.terminalId,
                username: this.config.username,
                password: this.config.password
            });

            this.accessToken = response.data.accessToken;
            // トークンの有効期限（通常1時間）
            this.tokenExpiry = new Date(Date.now() + (response.data.expiresIn || 3600) * 1000);

            return this.accessToken!;
        } catch (error: any) {
            console.error('ITP-WebService authentication failed:', error.message);
            throw new Error('ITP-WebService認証に失敗しました');
        }
    }

    /**
     * 認証ヘッダー付きリクエスト
     */
    private async authenticatedRequest(method: string, path: string, data?: any): Promise<any> {
        const token = await this.authenticate();

        const response = await this.client.request({
            method,
            url: path,
            data,
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        return response.data;
    }

    /**
     * 接続テスト
     */
    async testConnection(): Promise<{ success: boolean; message: string }> {
        try {
            await this.authenticate();
            return { success: true, message: '接続成功' };
        } catch (error: any) {
            return { success: false, message: error.message };
        }
    }

    /**
     * 運行データ取得（日付範囲指定）
     */
    async fetchOperationRecords(startDate: string, endDate: string): Promise<ITPOperationRecord[]> {
        const syncLogId = await this.createSyncLog('import_records', 'inbound');

        try {
            const response = await this.authenticatedRequest('GET', '/operations', {
                params: {
                    startDate,
                    endDate,
                    companyCode: this.config.companyCode
                }
            });

            const records: ITPOperationRecord[] = response.operations || [];

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
    async importOperationRecords(records: ITPOperationRecord[], companyId: number): Promise<{ imported: number; failed: number }> {
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
                         WHERE integration_id = $1 AND external_vehicle_number = $2 AND is_active = true`,
                        [this.integrationId, record.vehicleNumber]
                    );

                    // tachograph_dataに保存
                    await client.query(
                        `INSERT INTO tachograph_data (
                            import_id, integration_id, external_record_id,
                            driver_code, vehicle_number, record_date,
                            start_time, end_time, distance,
                            max_speed, avg_speed, idle_time_minutes,
                            driving_time_minutes, rest_time_minutes,
                            harsh_braking_count, harsh_acceleration_count, speeding_count,
                            match_status, raw_data
                        ) VALUES (
                            NULL, $1, $2, $3, $4, $5,
                            $6, $7, $8, $9, $10, $11,
                            $12, $13, $14, $15, $16, 'unmatched', $17
                        )
                        ON CONFLICT (integration_id, external_record_id) DO UPDATE SET
                            distance = EXCLUDED.distance,
                            updated_at = NOW()
                        RETURNING id`,
                        [
                            this.integrationId,
                            record.operationId,
                            record.driverCode,
                            record.vehicleNumber,
                            record.operationDate,
                            record.startTime,
                            record.endTime,
                            record.distance,
                            record.maxSpeed,
                            record.avgSpeed,
                            record.idleTime,
                            record.drivingTime,
                            record.restTime,
                            record.harshBrakingCount,
                            record.harshAccelerationCount,
                            record.speedingCount,
                            JSON.stringify(record)
                        ]
                    );

                    // 運転評価データ保存
                    if (record.safetyScore || record.ecoScore) {
                        const driverId = driverMapping.rows[0]?.driver_id || null;
                        const vehicleId = vehicleMapping.rows[0]?.vehicle_id || null;

                        await client.query(
                            `INSERT INTO driving_evaluations (
                                company_id, driver_id, vehicle_id, evaluation_date,
                                safety_score, eco_score, overall_score,
                                harsh_braking_count, harsh_acceleration_count, speeding_count,
                                idle_duration_minutes, fuel_consumption
                            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                            ON CONFLICT (driver_id, evaluation_date) DO UPDATE SET
                                safety_score = EXCLUDED.safety_score,
                                eco_score = EXCLUDED.eco_score`,
                            [
                                companyId,
                                driverId,
                                vehicleId,
                                record.operationDate,
                                record.safetyScore,
                                record.ecoScore,
                                Math.round((record.safetyScore + record.ecoScore) / 2),
                                record.harshBrakingCount,
                                record.harshAccelerationCount,
                                record.speedingCount,
                                record.idleTime,
                                record.fuelConsumption
                            ]
                        );
                    }

                    imported++;
                } catch (err) {
                    console.error('Failed to import record:', err);
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
     * リアルタイム位置情報取得
     */
    async fetchVehicleLocations(): Promise<ITPLocationData[]> {
        try {
            const response = await this.authenticatedRequest('GET', '/vehicles/locations', {
                params: {
                    companyCode: this.config.companyCode
                }
            });

            return response.locations || [];
        } catch (error: any) {
            console.error('Failed to fetch vehicle locations:', error.message);
            throw error;
        }
    }

    /**
     * 位置情報をDBに保存
     */
    async saveVehicleLocations(locations: ITPLocationData[], companyId: number): Promise<void> {
        const client = await pool.connect();

        try {
            await client.query('BEGIN');

            for (const loc of locations) {
                // 車両マッピング取得
                const vehicleMapping = await client.query(
                    `SELECT vehicle_id FROM tachograph_vehicle_mappings
                     WHERE integration_id = $1 AND external_vehicle_number = $2 AND is_active = true`,
                    [this.integrationId, loc.vehicleNumber]
                );

                const vehicleId = vehicleMapping.rows[0]?.vehicle_id;
                if (!vehicleId) continue;

                await client.query(
                    `INSERT INTO vehicle_location_history (
                        company_id, vehicle_id, integration_id, recorded_at,
                        latitude, longitude, speed, heading, engine_status, event_type
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
                    [
                        companyId,
                        vehicleId,
                        this.integrationId,
                        loc.timestamp,
                        loc.latitude,
                        loc.longitude,
                        loc.speed,
                        loc.heading,
                        loc.engineStatus,
                        loc.eventType
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
     * 運行指示送信
     */
    async sendInstruction(instruction: ITPInstruction, dispatchId: number, userId: number): Promise<{ success: boolean; externalId?: string; error?: string }> {
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
            const response = await this.authenticatedRequest('POST', '/instructions', {
                companyCode: this.config.companyCode,
                instruction
            });

            const externalId = response.instructionId;

            // 送信履歴更新
            await client.query(
                `UPDATE tachograph_instruction_sends
                 SET status = 'sent', external_instruction_id = $1, response_data = $2
                 WHERE id = $3`,
                [externalId, JSON.stringify(response), sendId]
            );

            await client.query('COMMIT');

            return { success: true, externalId };
        } catch (error: any) {
            await client.query('ROLLBACK');
            return { success: false, error: error.message };
        } finally {
            client.release();
        }
    }

    /**
     * マスタデータ同期（ドライバー・車両）
     */
    async syncMasterData(companyId: number): Promise<{ drivers: number; vehicles: number }> {
        const syncLogId = await this.createSyncLog('sync_master', 'inbound');

        try {
            // ドライバー一覧取得
            const driverResponse = await this.authenticatedRequest('GET', '/masters/drivers', {
                params: { companyCode: this.config.companyCode }
            });

            // 車両一覧取得
            const vehicleResponse = await this.authenticatedRequest('GET', '/masters/vehicles', {
                params: { companyCode: this.config.companyCode }
            });

            const client = await pool.connect();
            let driverCount = 0;
            let vehicleCount = 0;

            try {
                await client.query('BEGIN');

                // ドライバーマッピング更新
                for (const driver of (driverResponse.drivers || [])) {
                    await client.query(
                        `INSERT INTO tachograph_driver_mappings (
                            integration_id, external_driver_id, external_driver_code, external_driver_name
                        ) VALUES ($1, $2, $3, $4)
                        ON CONFLICT (integration_id, external_driver_id) DO UPDATE SET
                            external_driver_code = EXCLUDED.external_driver_code,
                            external_driver_name = EXCLUDED.external_driver_name`,
                        [this.integrationId, driver.driverId, driver.driverCode, driver.driverName]
                    );
                    driverCount++;
                }

                // 車両マッピング更新
                for (const vehicle of (vehicleResponse.vehicles || [])) {
                    await client.query(
                        `INSERT INTO tachograph_vehicle_mappings (
                            integration_id, external_vehicle_id, external_vehicle_number, external_device_id
                        ) VALUES ($1, $2, $3, $4)
                        ON CONFLICT (integration_id, external_vehicle_id) DO UPDATE SET
                            external_vehicle_number = EXCLUDED.external_vehicle_number,
                            external_device_id = EXCLUDED.external_device_id`,
                        [this.integrationId, vehicle.vehicleId, vehicle.vehicleNumber, vehicle.deviceId]
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
export async function createITPConnector(integrationId: number): Promise<ITPWebServiceConnector> {
    const result = await pool.query(
        `SELECT * FROM tachograph_integrations WHERE id = $1 AND provider = 'fujitsu_itp'`,
        [integrationId]
    );

    if (result.rows.length === 0) {
        throw new Error('ITP-WebService連携設定が見つかりません');
    }

    const integration = result.rows[0];

    const config: ITPConfig = {
        endpoint: integration.api_endpoint,
        companyCode: integration.itp_company_code,
        terminalId: integration.itp_terminal_id,
        username: integration.username,
        password: integration.password
    };

    return new ITPWebServiceConnector(integrationId, config);
}
