import { Request, Response } from 'express';
import { pool } from '../utils/db';

// Start work (Clock In)
export const createWorkRecord = async (req: Request, res: Response) => {
    const { driver_id, vehicle_id, work_date, start_time, record_method, start_latitude, start_longitude, start_address } = req.body;

    try {
        const result = await pool.query(
            `INSERT INTO work_records 
      (driver_id, vehicle_id, work_date, start_time, record_method, start_latitude, start_longitude, start_address) 
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8) 
      RETURNING *`,
            [driver_id, vehicle_id, work_date, start_time, record_method, start_latitude, start_longitude, start_address]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to create work record' });
    }
};

// End work (Clock Out) or Update
export const updateWorkRecord = async (req: Request, res: Response) => {
    const { id } = req.params;
    const { end_time, end_latitude, end_longitude, end_address, distance, cargo_weight, has_incident, incident_detail, status } = req.body;

    try {
        // Dynamic query building could be better, but simplified for MVP
        const result = await pool.query(
            `UPDATE work_records 
      SET end_time = COALESCE($1, end_time),
          end_latitude = COALESCE($2, end_latitude),
          end_longitude = COALESCE($3, end_longitude),
          end_address = COALESCE($4, end_address),
          distance = COALESCE($5, distance),
          cargo_weight = COALESCE($6, cargo_weight),
          has_incident = COALESCE($7, has_incident),
          incident_detail = COALESCE($8, incident_detail),
          status = COALESCE($9, status),
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $10
      RETURNING *`,
            [end_time, end_latitude, end_longitude, end_address, distance, cargo_weight, has_incident, incident_detail, status, id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Record not found' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to update work record' });
    }
};

// Get all records (with filters)
export const getWorkRecords = async (req: Request, res: Response) => {
    const { driver_id, date_from, date_to } = req.query;

    try {
        let query = 'SELECT work_records.*, users.name as driver_name, vehicles.vehicle_number FROM work_records LEFT JOIN users ON work_records.driver_id = users.id LEFT JOIN vehicles ON work_records.vehicle_id = vehicles.id WHERE 1=1';
        const params: any[] = [];
        let paramCount = 1;

        if (driver_id) {
            query += ` AND driver_id = $${paramCount}`;
            params.push(driver_id);
            paramCount++;
        }

        if (date_from) {
            query += ` AND work_date >= $${paramCount}`;
            params.push(date_from);
            paramCount++;
        }

        if (date_to) {
            query += ` AND work_date <= $${paramCount}`;
            params.push(date_to);
            paramCount++;
        }

        query += ' ORDER BY work_date DESC, start_time DESC';

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to fetch work records' });
    }
};

export const getWorkRecordById = async (req: Request, res: Response) => {
    const { id } = req.params;
    try {
        const result = await pool.query('SELECT * FROM work_records WHERE id = $1', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Record not found' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to fetch record' });
    }
};
