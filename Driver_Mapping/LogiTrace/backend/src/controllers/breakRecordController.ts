import { Request, Response } from 'express';
import { pool } from '../utils/db';
import { processBreakDetection } from '../services/breakDetectionService';

// 休憩記録一覧取得
export const getBreakRecords = async (req: Request, res: Response) => {
    const { work_record_id } = req.params;

    try {
        const result = await pool.query(`
            SELECT * FROM break_records
            WHERE work_record_id = $1
            ORDER BY start_time ASC
        `, [work_record_id]);

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching break records:', error);
        res.status(500).json({ error: 'Failed to fetch break records' });
    }
};

// 休憩を自動検出（手動トリガー）
export const detectBreaks = async (req: Request, res: Response) => {
    const { work_record_id } = req.params;

    try {
        // 権限チェック：自分の運行記録または同じ会社の記録
        const companyId = (req as any).user?.companyId;
        const userId = (req as any).user?.userId;

        const checkResult = await pool.query(`
            SELECT wr.id, wr.driver_id, u.company_id
            FROM work_records wr
            JOIN users u ON wr.driver_id = u.id
            WHERE wr.id = $1
        `, [work_record_id]);

        if (checkResult.rows.length === 0) {
            return res.status(404).json({ error: 'Work record not found' });
        }

        const record = checkResult.rows[0];
        if (record.company_id !== companyId) {
            return res.status(403).json({ error: 'Access denied' });
        }

        // 休憩検出実行
        const result = await processBreakDetection(parseInt(work_record_id));

        res.json({
            message: 'Break detection completed',
            ...result
        });
    } catch (error) {
        console.error('Error detecting breaks:', error);
        res.status(500).json({ error: 'Failed to detect breaks' });
    }
};

// 休憩記録を手動追加
export const addBreakRecord = async (req: Request, res: Response) => {
    const { work_record_id } = req.params;
    const { start_time, end_time, location_name, latitude, longitude } = req.body;

    try {
        // 時間差を計算
        const startDate = new Date(start_time);
        const endDate = new Date(end_time);
        const durationMinutes = Math.round((endDate.getTime() - startDate.getTime()) / 60000);

        if (durationMinutes < 0) {
            return res.status(400).json({ error: 'End time must be after start time' });
        }

        const result = await pool.query(`
            INSERT INTO break_records
            (work_record_id, start_time, end_time, duration_minutes, location_name, latitude, longitude, detection_method)
            VALUES ($1, $2, $3, $4, $5, $6, $7, 'manual')
            RETURNING *
        `, [work_record_id, start_time, end_time, durationMinutes, location_name, latitude, longitude]);

        // work_recordsの休憩時間を再計算
        await recalculateBreakTime(parseInt(work_record_id));

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error adding break record:', error);
        res.status(500).json({ error: 'Failed to add break record' });
    }
};

// 休憩記録を更新
export const updateBreakRecord = async (req: Request, res: Response) => {
    const { id } = req.params;
    const { start_time, end_time, location_name } = req.body;

    try {
        // 時間差を計算
        let durationMinutes = null;
        if (start_time && end_time) {
            const startDate = new Date(start_time);
            const endDate = new Date(end_time);
            durationMinutes = Math.round((endDate.getTime() - startDate.getTime()) / 60000);

            if (durationMinutes < 0) {
                return res.status(400).json({ error: 'End time must be after start time' });
            }
        }

        const result = await pool.query(`
            UPDATE break_records SET
                start_time = COALESCE($1, start_time),
                end_time = COALESCE($2, end_time),
                duration_minutes = COALESCE($3, duration_minutes),
                location_name = COALESCE($4, location_name),
                detection_method = 'manual'
            WHERE id = $5
            RETURNING *
        `, [start_time, end_time, durationMinutes, location_name, id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Break record not found' });
        }

        // work_recordsの休憩時間を再計算
        await recalculateBreakTime(result.rows[0].work_record_id);

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating break record:', error);
        res.status(500).json({ error: 'Failed to update break record' });
    }
};

// 休憩記録を削除
export const deleteBreakRecord = async (req: Request, res: Response) => {
    const { id } = req.params;

    try {
        // まずwork_record_idを取得
        const breakResult = await pool.query(
            'SELECT work_record_id FROM break_records WHERE id = $1',
            [id]
        );

        if (breakResult.rows.length === 0) {
            return res.status(404).json({ error: 'Break record not found' });
        }

        const workRecordId = breakResult.rows[0].work_record_id;

        // 削除
        await pool.query('DELETE FROM break_records WHERE id = $1', [id]);

        // work_recordsの休憩時間を再計算
        await recalculateBreakTime(workRecordId);

        res.json({ message: 'Break record deleted' });
    } catch (error) {
        console.error('Error deleting break record:', error);
        res.status(500).json({ error: 'Failed to delete break record' });
    }
};

// 休憩時間の再計算
async function recalculateBreakTime(workRecordId: number): Promise<void> {
    // 自動検出の休憩時間
    const autoResult = await pool.query(`
        SELECT COALESCE(SUM(duration_minutes), 0) as total
        FROM break_records
        WHERE work_record_id = $1 AND detection_method = 'auto'
    `, [workRecordId]);

    // 手動追加の休憩時間
    const manualResult = await pool.query(`
        SELECT COALESCE(SUM(duration_minutes), 0) as total
        FROM break_records
        WHERE work_record_id = $1 AND detection_method = 'manual'
    `, [workRecordId]);

    const autoBreakMinutes = parseInt(autoResult.rows[0].total);
    const manualBreakMinutes = parseInt(manualResult.rows[0].total);

    await pool.query(`
        UPDATE work_records SET
            auto_break_minutes = $1,
            manual_break_minutes = $2
        WHERE id = $3
    `, [autoBreakMinutes, autoBreakMinutes + manualBreakMinutes, workRecordId]);
}
