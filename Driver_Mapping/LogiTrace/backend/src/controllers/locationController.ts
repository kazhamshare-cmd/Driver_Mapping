/**
 * Location Controller - 発着地マスタ管理API
 */

import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 発着地一覧取得
export const getLocations = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { search, location_type, is_active } = req.query;

    try {
        let query = `
            SELECT * FROM locations
            WHERE company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (is_active !== undefined) {
            query += ` AND is_active = $${paramIndex}`;
            params.push(is_active === 'true');
            paramIndex++;
        }

        if (location_type) {
            query += ` AND (location_type = $${paramIndex} OR location_type = 'both')`;
            params.push(location_type);
            paramIndex++;
        }

        if (search) {
            query += ` AND (name ILIKE $${paramIndex} OR location_code ILIKE $${paramIndex} OR address ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        query += ' ORDER BY name';

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching locations:', error);
        res.status(500).json({ error: 'Failed to fetch locations' });
    }
};

// 発着地詳細取得
export const getLocationById = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;

    try {
        const result = await pool.query(
            'SELECT * FROM locations WHERE id = $1 AND company_id = $2',
            [id, companyId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Location not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching location:', error);
        res.status(500).json({ error: 'Failed to fetch location' });
    }
};

// 発着地作成
export const createLocation = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const {
        location_code,
        name,
        name_kana,
        location_type,
        postal_code,
        address,
        latitude,
        longitude,
        contact_person,
        contact_phone,
        operating_hours_start,
        operating_hours_end,
        loading_time_minutes,
        unloading_time_minutes,
        notes
    } = req.body;

    if (!name || !address) {
        return res.status(400).json({ error: 'Name and address are required' });
    }

    try {
        const result = await pool.query(`
            INSERT INTO locations (
                company_id, location_code, name, name_kana, location_type,
                postal_code, address, latitude, longitude,
                contact_person, contact_phone,
                operating_hours_start, operating_hours_end,
                loading_time_minutes, unloading_time_minutes, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
            RETURNING *
        `, [
            companyId, location_code, name, name_kana, location_type || 'both',
            postal_code, address, latitude, longitude,
            contact_person, contact_phone,
            operating_hours_start, operating_hours_end,
            loading_time_minutes || 30, unloading_time_minutes || 30, notes
        ]);

        res.status(201).json(result.rows[0]);
    } catch (error: any) {
        if (error.code === '23505') {
            return res.status(400).json({ error: 'Location code already exists' });
        }
        console.error('Error creating location:', error);
        res.status(500).json({ error: 'Failed to create location' });
    }
};

// 発着地更新
export const updateLocation = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;
    const {
        location_code,
        name,
        name_kana,
        location_type,
        postal_code,
        address,
        latitude,
        longitude,
        contact_person,
        contact_phone,
        operating_hours_start,
        operating_hours_end,
        loading_time_minutes,
        unloading_time_minutes,
        notes,
        is_active
    } = req.body;

    try {
        const result = await pool.query(`
            UPDATE locations SET
                location_code = COALESCE($1, location_code),
                name = COALESCE($2, name),
                name_kana = COALESCE($3, name_kana),
                location_type = COALESCE($4, location_type),
                postal_code = COALESCE($5, postal_code),
                address = COALESCE($6, address),
                latitude = COALESCE($7, latitude),
                longitude = COALESCE($8, longitude),
                contact_person = COALESCE($9, contact_person),
                contact_phone = COALESCE($10, contact_phone),
                operating_hours_start = COALESCE($11, operating_hours_start),
                operating_hours_end = COALESCE($12, operating_hours_end),
                loading_time_minutes = COALESCE($13, loading_time_minutes),
                unloading_time_minutes = COALESCE($14, unloading_time_minutes),
                notes = COALESCE($15, notes),
                is_active = COALESCE($16, is_active),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $17 AND company_id = $18
            RETURNING *
        `, [
            location_code, name, name_kana, location_type,
            postal_code, address, latitude, longitude,
            contact_person, contact_phone,
            operating_hours_start, operating_hours_end,
            loading_time_minutes, unloading_time_minutes,
            notes, is_active, id, companyId
        ]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Location not found' });
        }

        res.json(result.rows[0]);
    } catch (error: any) {
        if (error.code === '23505') {
            return res.status(400).json({ error: 'Location code already exists' });
        }
        console.error('Error updating location:', error);
        res.status(500).json({ error: 'Failed to update location' });
    }
};

// 発着地削除
export const deleteLocation = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;

    try {
        // 関連する受注があるかチェック
        const ordersCheck = await pool.query(
            'SELECT COUNT(*) FROM orders WHERE pickup_location_id = $1 OR delivery_location_id = $1',
            [id]
        );

        if (parseInt(ordersCheck.rows[0].count) > 0) {
            // 受注がある場合は論理削除
            const result = await pool.query(`
                UPDATE locations SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP
                WHERE id = $1 AND company_id = $2
                RETURNING *
            `, [id, companyId]);

            if (result.rows.length === 0) {
                return res.status(404).json({ error: 'Location not found' });
            }

            res.json({ message: 'Location deactivated (has related orders)', location: result.rows[0] });
        } else {
            // 受注がない場合は物理削除
            const result = await pool.query(
                'DELETE FROM locations WHERE id = $1 AND company_id = $2 RETURNING id',
                [id, companyId]
            );

            if (result.rows.length === 0) {
                return res.status(404).json({ error: 'Location not found' });
            }

            res.json({ message: 'Location deleted' });
        }
    } catch (error) {
        console.error('Error deleting location:', error);
        res.status(500).json({ error: 'Failed to delete location' });
    }
};

// 住所から緯度経度を取得（外部API連携用プレースホルダー）
export const geocodeAddress = async (req: Request, res: Response) => {
    const { address } = req.body;

    if (!address) {
        return res.status(400).json({ error: 'Address is required' });
    }

    // TODO: Google Maps Geocoding API等との連携
    // 現在はプレースホルダーとして返却
    res.json({
        message: 'Geocoding API integration pending',
        address,
        latitude: null,
        longitude: null
    });
};
