import { Request, Response } from 'express';
import { pool } from '../utils/db';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'your_super_secret_jwt_key_change_in_production';

export const register = async (req: Request, res: Response) => {
    const { email, password, name, user_type } = req.body;

    try {
        const hashedPassword = await bcrypt.hash(password, 10);

        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            // Create user
            const userResult = await client.query(
                'INSERT INTO users (email, password_hash, name, user_type) VALUES ($1, $2, $3, $4) RETURNING id, email, name, user_type',
                [email, hashedPassword, name, user_type]
            );
            const user = userResult.rows[0];

            await client.query('COMMIT');

            // Generate token for immediate login
            const token = jwt.sign(
                { userId: user.id, email: user.email, userType: user.user_type },
                JWT_SECRET,
                { expiresIn: '24h' }
            );

            res.status(201).json({
                message: 'User registered successfully',
                user,
                token
            });
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Registration failed' });
    }
};

export const login = async (req: Request, res: Response) => {
    const { email, password } = req.body;

    try {
        // Query with company and industry information
        const result = await pool.query(`
            SELECT
                u.*,
                c.id as company_id,
                c.name as company_name,
                c.industry_type_id,
                it.code as industry_code,
                it.name_ja as industry_name
            FROM users u
            LEFT JOIN companies c ON u.company_id = c.id
            LEFT JOIN industry_types it ON c.industry_type_id = it.id
            WHERE u.email = $1
        `, [email]);

        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const user = result.rows[0];
        const isMatch = await bcrypt.compare(password, user.password_hash);

        if (!isMatch) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const token = jwt.sign(
            { userId: user.id, email: user.email, userType: user.user_type, companyId: user.company_id },
            JWT_SECRET,
            { expiresIn: '24h' }
        );

        res.json({
            message: 'Login successful',
            token,
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                user_type: user.user_type,
                company_id: user.company_id,
                company_name: user.company_name,
                industry_type_id: user.industry_type_id,
                industry_code: user.industry_code,
                industry_name: user.industry_name
            }
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Login failed' });
    }
};
