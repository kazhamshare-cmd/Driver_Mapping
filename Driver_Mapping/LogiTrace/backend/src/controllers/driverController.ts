import { Request, Response } from 'express';
import { pool } from '../utils/db';
import bcrypt from 'bcrypt';
import crypto from 'crypto';

// ドライバー数上限チェック
const checkDriverLimit = async (companyId: number): Promise<{ canAdd: boolean; current: number; max: number; message?: string }> => {
    const result = await pool.query(
        `SELECT
            s.max_driver_count,
            COUNT(u.id) FILTER (WHERE u.status = 'active') as active_count,
            COUNT(u.id) as total_count
         FROM subscriptions s
         LEFT JOIN users u ON u.company_id = s.company_id AND u.user_type = 'driver'
         WHERE s.company_id = $1 AND s.status = 'active'
         GROUP BY s.max_driver_count`,
        [companyId]
    );

    if (result.rows.length === 0) {
        // サブスクリプションがない場合はデフォルト上限（3名）
        const countResult = await pool.query(
            `SELECT COUNT(*) as count FROM users WHERE company_id = $1 AND user_type = 'driver' AND status = 'active'`,
            [companyId]
        );
        const current = parseInt(countResult.rows[0].count) || 0;
        const max = 3; // デフォルト上限
        return {
            canAdd: current < max,
            current,
            max,
            message: current >= max ? `ドライバー数が上限（${max}名）に達しています。プランをアップグレードしてください。` : undefined
        };
    }

    const { max_driver_count, active_count } = result.rows[0];
    const current = parseInt(active_count) || 0;
    const max = parseInt(max_driver_count) || 3;

    return {
        canAdd: current < max,
        current,
        max,
        message: current >= max ? `ドライバー数が上限（${max}名）に達しています。プランをアップグレードしてください。` : undefined
    };
};

// ドライバー利用状況取得
export const getDriverUsage = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.query;

        if (!companyId) {
            return res.status(400).json({ error: 'companyId is required' });
        }

        const usage = await checkDriverLimit(Number(companyId));

        // プラン情報も取得
        const planResult = await pool.query(
            `SELECT s.plan_id, s.status, s.current_period_end
             FROM subscriptions s
             WHERE s.company_id = $1 AND s.status = 'active'
             ORDER BY s.created_at DESC
             LIMIT 1`,
            [companyId]
        );

        res.json({
            ...usage,
            plan: planResult.rows[0] || { plan_id: 'free', status: 'active' }
        });
    } catch (error) {
        console.error('Error fetching driver usage:', error);
        res.status(500).json({ error: 'Failed to fetch driver usage' });
    }
};

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

        // 上限チェック
        const limitCheck = await checkDriverLimit(companyId);
        if (!limitCheck.canAdd) {
            return res.status(403).json({
                error: 'Driver limit reached',
                message: limitCheck.message,
                current: limitCheck.current,
                max: limitCheck.max
            });
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
            `INSERT INTO users (company_id, user_type, email, password_hash, name, employee_number, status)
             VALUES ($1, 'driver', $2, $3, $4, $5, 'active')
             RETURNING id, email, name, employee_number, status, created_at`,
            [companyId, email, passwordHash, name, employeeNumber]
        );

        // サブスクリプションの現在ドライバー数を更新
        await pool.query(
            `UPDATE subscriptions SET current_driver_count = current_driver_count + 1, updated_at = NOW()
             WHERE company_id = $1 AND status = 'active'`,
            [companyId]
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

        // 上限チェック
        const limitCheck = await checkDriverLimit(companyId);
        if (!limitCheck.canAdd) {
            return res.status(403).json({
                error: 'Driver limit reached',
                message: limitCheck.message,
                current: limitCheck.current,
                max: limitCheck.max
            });
        }

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

// パスワード再発行（管理者用）
export const resetDriverPassword = async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const { companyId } = req.body;

        // 対象ドライバーが存在し、同じ会社かチェック
        const driver = await pool.query(
            `SELECT id, email, name FROM users
             WHERE id = $1 AND company_id = $2 AND user_type = 'driver'`,
            [id, companyId]
        );

        if (driver.rows.length === 0) {
            return res.status(404).json({ error: 'Driver not found' });
        }

        // 新しいパスワードを生成（8文字の英数字）
        const newPassword = crypto.randomBytes(4).toString('hex'); // 8文字の16進数
        const passwordHash = await bcrypt.hash(newPassword, 10);

        await pool.query(
            `UPDATE users
             SET password_hash = $1, updated_at = NOW()
             WHERE id = $2`,
            [passwordHash, id]
        );

        // 新しいパスワードを返す（管理者がドライバーに伝える）
        res.json({
            message: 'Password reset successfully',
            driver: {
                id: driver.rows[0].id,
                email: driver.rows[0].email,
                name: driver.rows[0].name
            },
            newPassword: newPassword,
            note: 'このパスワードをドライバーに伝えてください。この画面を閉じると再表示できません。'
        });
    } catch (error) {
        console.error('Error resetting password:', error);
        res.status(500).json({ error: 'Failed to reset password' });
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
