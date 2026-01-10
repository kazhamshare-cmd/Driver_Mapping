import { pool } from '../utils/db';
import fs from 'fs';
import path from 'path';

const migrate = async () => {
    try {
        const sqlPath = path.join(__dirname, '../../../database/migrations/001_initial_subscription.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');

        console.log('Running migration: 001_initial_subscription.sql');
        await pool.query(sql);
        console.log('Migration completed successfully');
    } catch (error) {
        console.error('Migration failed:', error);
    } finally {
        await pool.end();
    }
};

migrate();
