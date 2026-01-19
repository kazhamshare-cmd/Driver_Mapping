/**
 * Shipper Controller - 荷主マスタ管理API
 */

import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 荷主一覧取得
export const getShippers = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const { search, is_active } = req.query;

    try {
        let query = `
            SELECT * FROM shippers
            WHERE company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (is_active !== undefined) {
            query += ` AND is_active = $${paramIndex}`;
            params.push(is_active === 'true');
            paramIndex++;
        }

        if (search) {
            query += ` AND (name ILIKE $${paramIndex} OR shipper_code ILIKE $${paramIndex} OR name_kana ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        query += ' ORDER BY name';

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching shippers:', error);
        res.status(500).json({ error: 'Failed to fetch shippers' });
    }
};

// 荷主詳細取得
export const getShipperById = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;

    try {
        const result = await pool.query(
            'SELECT * FROM shippers WHERE id = $1 AND company_id = $2',
            [id, companyId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Shipper not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching shipper:', error);
        res.status(500).json({ error: 'Failed to fetch shipper' });
    }
};

// 荷主作成
export const createShipper = async (req: Request, res: Response) => {
    const companyId = (req as any).user?.companyId;
    const {
        shipper_code,
        name,
        name_kana,
        postal_code,
        address,
        phone,
        fax,
        email,
        contact_person,
        contact_phone,
        invoice_registration_number,
        payment_terms,
        billing_closing_day,
        notes
    } = req.body;

    if (!name) {
        return res.status(400).json({ error: 'Name is required' });
    }

    try {
        const result = await pool.query(`
            INSERT INTO shippers (
                company_id, shipper_code, name, name_kana, postal_code, address,
                phone, fax, email, contact_person, contact_phone,
                invoice_registration_number, payment_terms, billing_closing_day, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
            RETURNING *
        `, [
            companyId, shipper_code, name, name_kana, postal_code, address,
            phone, fax, email, contact_person, contact_phone,
            invoice_registration_number, payment_terms || 30, billing_closing_day || 31, notes
        ]);

        res.status(201).json(result.rows[0]);
    } catch (error: any) {
        if (error.code === '23505') {
            return res.status(400).json({ error: 'Shipper code already exists' });
        }
        console.error('Error creating shipper:', error);
        res.status(500).json({ error: 'Failed to create shipper' });
    }
};

// 荷主更新
export const updateShipper = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;
    const {
        shipper_code,
        name,
        name_kana,
        postal_code,
        address,
        phone,
        fax,
        email,
        contact_person,
        contact_phone,
        invoice_registration_number,
        payment_terms,
        billing_closing_day,
        notes,
        is_active
    } = req.body;

    try {
        const result = await pool.query(`
            UPDATE shippers SET
                shipper_code = COALESCE($1, shipper_code),
                name = COALESCE($2, name),
                name_kana = COALESCE($3, name_kana),
                postal_code = COALESCE($4, postal_code),
                address = COALESCE($5, address),
                phone = COALESCE($6, phone),
                fax = COALESCE($7, fax),
                email = COALESCE($8, email),
                contact_person = COALESCE($9, contact_person),
                contact_phone = COALESCE($10, contact_phone),
                invoice_registration_number = COALESCE($11, invoice_registration_number),
                payment_terms = COALESCE($12, payment_terms),
                billing_closing_day = COALESCE($13, billing_closing_day),
                notes = COALESCE($14, notes),
                is_active = COALESCE($15, is_active),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $16 AND company_id = $17
            RETURNING *
        `, [
            shipper_code, name, name_kana, postal_code, address,
            phone, fax, email, contact_person, contact_phone,
            invoice_registration_number, payment_terms, billing_closing_day,
            notes, is_active, id, companyId
        ]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Shipper not found' });
        }

        res.json(result.rows[0]);
    } catch (error: any) {
        if (error.code === '23505') {
            return res.status(400).json({ error: 'Shipper code already exists' });
        }
        console.error('Error updating shipper:', error);
        res.status(500).json({ error: 'Failed to update shipper' });
    }
};

// 荷主削除（論理削除）
export const deleteShipper = async (req: Request, res: Response) => {
    const { id } = req.params;
    const companyId = (req as any).user?.companyId;

    try {
        // 関連する受注があるかチェック
        const ordersCheck = await pool.query(
            'SELECT COUNT(*) FROM orders WHERE shipper_id = $1',
            [id]
        );

        if (parseInt(ordersCheck.rows[0].count) > 0) {
            // 受注がある場合は論理削除
            const result = await pool.query(`
                UPDATE shippers SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP
                WHERE id = $1 AND company_id = $2
                RETURNING *
            `, [id, companyId]);

            if (result.rows.length === 0) {
                return res.status(404).json({ error: 'Shipper not found' });
            }

            res.json({ message: 'Shipper deactivated (has related orders)', shipper: result.rows[0] });
        } else {
            // 受注がない場合は物理削除
            const result = await pool.query(
                'DELETE FROM shippers WHERE id = $1 AND company_id = $2 RETURNING id',
                [id, companyId]
            );

            if (result.rows.length === 0) {
                return res.status(404).json({ error: 'Shipper not found' });
            }

            res.json({ message: 'Shipper deleted' });
        }
    } catch (error) {
        console.error('Error deleting shipper:', error);
        res.status(500).json({ error: 'Failed to delete shipper' });
    }
};
