import { Request, Response } from 'express';
import { pool } from '../utils/db';
import bcrypt from 'bcrypt';
import crypto from 'crypto';

// ドライバー一覧取得
export const getDrivers = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        const result = await pool.query(
            `SELECT id, email, name, employee_number, status, created_at, updated_at
             FROM users
             WHERE company_id = $1 AND user_type = 'driver'
             ORDER BY created_at DESC`,
            [companyId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching drivers:', error);
        res.status(500).json({ error: 'Failed to fetch drivers' });
    }
};

// ドライバー登録（管理者用）
export const createDriver = async (req: Request, res: Response) => {
    try {
        const { companyId, email, name, employeeNumber, password } = req.body;

        // 既存チェック
        const existing = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [email]
        );

        if (existing.rows.length > 0) {
            return res.status(400).json({ error: 'Email already registered' });
        }

        const passwordHash = await bcrypt.hash(password, 10);

        const result = await pool.query(
            `INSERT INTO users (company_id, user_type, email, password_hash, name, employee_number, status)
             VALUES ($1, 'driver', $2, $3, $4, $5, 'active')
             RETURNING id, email, name, employee_number, status, created_at`,
            [companyId, email, passwordHash, name, employeeNumber]
        );

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating driver:', error);
        res.status(500).json({ error: 'Failed to create driver' });
    }
};

// 招待リンク生成
export const createInvite = async (req: Request, res: Response) => {
    try {
        const { companyId, email, name } = req.body;

        // 既存チェック
        const existing = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [email]
        );

        if (existing.rows.length > 0) {
            return res.status(400).json({ error: 'Email already registered' });
        }

        // 招待トークン生成
        const inviteToken = crypto.randomBytes(32).toString('hex');
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7日間有効

        const result = await pool.query(
            `INSERT INTO users (company_id, user_type, email, name, status, invite_token, invite_expires_at)
             VALUES ($1, 'driver', $2, $3, 'pending', $4, $5)
             RETURNING id, email, name, invite_token`,
            [companyId, email, name, inviteToken, expiresAt]
        );

        // 招待URLを返す
        const inviteUrl = `${process.env.FRONTEND_URL || 'https://haisha-pro.com'}/driver/setup?token=${inviteToken}`;

        res.status(201).json({
            ...result.rows[0],
            inviteUrl
        });
    } catch (error) {
        console.error('Error creating invite:', error);
        res.status(500).json({ error: 'Failed to create invite' });
    }
};

// 招待トークンでパスワード設定
export const setupDriverPassword = async (req: Request, res: Response) => {
    try {
        const { token, password } = req.body;

        // トークン検証
        const user = await pool.query(
            `SELECT id, email, name FROM users
             WHERE invite_token = $1 AND invite_expires_at > NOW() AND status = 'pending'`,
            [token]
        );

        if (user.rows.length === 0) {
            return res.status(400).json({ error: 'Invalid or expired invite token' });
        }

        const passwordHash = await bcrypt.hash(password, 10);

        await pool.query(
            `UPDATE users
             SET password_hash = $1, status = 'active', invite_token = NULL, invite_expires_at = NULL, updated_at = NOW()
             WHERE id = $2`,
            [passwordHash, user.rows[0].id]
        );

        res.json({ message: 'Password set successfully', email: user.rows[0].email });
    } catch (error) {
        console.error('Error setting password:', error);
        res.status(500).json({ error: 'Failed to set password' });
    }
};

// 会社コードでドライバー自己登録
export const registerByCompanyCode = async (req: Request, res: Response) => {
    try {
        const { companyCode, email, password, name } = req.body;

        // 会社コード検証
        const company = await pool.query(
            'SELECT id, name FROM companies WHERE company_code = $1',
            [companyCode]
        );

        if (company.rows.length === 0) {
            return res.status(400).json({ error: 'Invalid company code' });
        }

        // 既存チェック
        const existing = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [email]
        );

        if (existing.rows.length > 0) {
            return res.status(400).json({ error: 'Email already registered' });
        }

        const passwordHash = await bcrypt.hash(password, 10);

        const result = await pool.query(
            `INSERT INTO users (company_id, user_type, email, password_hash, name, status)
             VALUES ($1, 'driver', $2, $3, $4, 'active')
             RETURNING id, email, name, status, created_at`,
            [company.rows[0].id, email, passwordHash, name]
        );

        res.status(201).json({
            ...result.rows[0],
            companyName: company.rows[0].name
        });
    } catch (error) {
        console.error('Error registering driver:', error);
        res.status(500).json({ error: 'Failed to register driver' });
    }
};

// ドライバー更新
export const updateDriver = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { name, employeeNumber, status } = req.body;

        const result = await pool.query(
            `UPDATE users
             SET name = COALESCE($1, name),
                 employee_number = COALESCE($2, employee_number),
                 status = COALESCE($3, status),
                 updated_at = NOW()
             WHERE id = $4 AND user_type = 'driver'
             RETURNING id, email, name, employee_number, status, updated_at`,
            [name, employeeNumber, status, id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Driver not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating driver:', error);
        res.status(500).json({ error: 'Failed to update driver' });
    }
};

// ドライバー削除（論理削除）
export const deleteDriver = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            `UPDATE users
             SET status = 'inactive', updated_at = NOW()
             WHERE id = $1 AND user_type = 'driver'
             RETURNING id`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Driver not found' });
        }

        res.json({ message: 'Driver deleted successfully' });
    } catch (error) {
        console.error('Error deleting driver:', error);
        res.status(500).json({ error: 'Failed to delete driver' });
    }
};

// 会社情報取得（会社コード表示用）
export const getCompanyInfo = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.params;

        const result = await pool.query(
            `SELECT id, company_code, name FROM companies WHERE id = $1`,
            [companyId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Company not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching company:', error);
        res.status(500).json({ error: 'Failed to fetch company' });
    }
};
