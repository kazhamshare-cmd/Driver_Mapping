import { Request, Response } from 'express';
import { pool } from '../utils/db';

// GET /operation-instructions - List operation instructions for a company
export const getOperationInstructions = async (req: Request, res: Response) => {
    const companyId = req.query.companyId || (req as any).user?.companyId;
    const { status, dateFrom, dateTo, driverId, limit = 50, offset = 0 } = req.query;

    try {
        let query = `
            SELECT
                oi.*,
                pd.name as primary_driver_name,
                sd.name as secondary_driver_name,
                v.vehicle_number,
                u.name as created_by_name
            FROM operation_instructions oi
            LEFT JOIN users pd ON oi.primary_driver_id = pd.id
            LEFT JOIN users sd ON oi.secondary_driver_id = sd.id
            LEFT JOIN vehicles v ON oi.vehicle_id = v.id
            LEFT JOIN users u ON oi.created_by = u.id
            WHERE oi.company_id = $1
        `;
        const params: any[] = [companyId];
        let paramIndex = 2;

        if (status) {
            query += ` AND oi.status = $${paramIndex}`;
            params.push(status);
            paramIndex++;
        }

        if (dateFrom) {
            query += ` AND oi.instruction_date >= $${paramIndex}`;
            params.push(dateFrom);
            paramIndex++;
        }

        if (dateTo) {
            query += ` AND oi.instruction_date <= $${paramIndex}`;
            params.push(dateTo);
            paramIndex++;
        }

        if (driverId) {
            query += ` AND (oi.primary_driver_id = $${paramIndex} OR oi.secondary_driver_id = $${paramIndex})`;
            params.push(driverId);
            paramIndex++;
        }

        query += ` ORDER BY oi.instruction_date DESC, oi.scheduled_departure_time DESC`;
        query += ` LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);

        // Get total count
        const countResult = await pool.query(
            `SELECT COUNT(*) FROM operation_instructions WHERE company_id = $1`,
            [companyId]
        );

        res.json({
            data: result.rows,
            total: parseInt(countResult.rows[0].count),
            limit: parseInt(limit as string),
            offset: parseInt(offset as string)
        });
    } catch (error) {
        console.error('Error fetching operation instructions:', error);
        res.status(500).json({ error: 'Failed to fetch operation instructions' });
    }
};

// GET /operation-instructions/:id - Get single operation instruction
export const getOperationInstruction = async (req: Request, res: Response) => {
    const { id } = req.params;

    try {
        const result = await pool.query(`
            SELECT
                oi.*,
                pd.name as primary_driver_name,
                sd.name as secondary_driver_name,
                v.vehicle_number,
                v.vehicle_type,
                u.name as created_by_name,
                iu.name as issued_by_name
            FROM operation_instructions oi
            LEFT JOIN users pd ON oi.primary_driver_id = pd.id
            LEFT JOIN users sd ON oi.secondary_driver_id = sd.id
            LEFT JOIN vehicles v ON oi.vehicle_id = v.id
            LEFT JOIN users u ON oi.created_by = u.id
            LEFT JOIN users iu ON oi.issued_by = iu.id
            WHERE oi.id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Operation instruction not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching operation instruction:', error);
        res.status(500).json({ error: 'Failed to fetch operation instruction' });
    }
};

// GET /operation-instructions/driver/:driverId - Get instructions for a specific driver
export const getDriverOperationInstructions = async (req: Request, res: Response) => {
    const { driverId } = req.params;
    const { date, status } = req.query;

    try {
        let query = `
            SELECT
                oi.*,
                pd.name as primary_driver_name,
                sd.name as secondary_driver_name,
                v.vehicle_number,
                v.vehicle_type
            FROM operation_instructions oi
            LEFT JOIN users pd ON oi.primary_driver_id = pd.id
            LEFT JOIN users sd ON oi.secondary_driver_id = sd.id
            LEFT JOIN vehicles v ON oi.vehicle_id = v.id
            WHERE (oi.primary_driver_id = $1 OR oi.secondary_driver_id = $1)
        `;
        const params: any[] = [driverId];
        let paramIndex = 2;

        if (date) {
            query += ` AND oi.instruction_date = $${paramIndex}`;
            params.push(date);
            paramIndex++;
        }

        if (status) {
            query += ` AND oi.status = $${paramIndex}`;
            params.push(status);
            paramIndex++;
        }

        query += ` ORDER BY oi.instruction_date DESC, oi.scheduled_departure_time ASC`;

        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching driver operation instructions:', error);
        res.status(500).json({ error: 'Failed to fetch driver operation instructions' });
    }
};

// POST /operation-instructions - Create new operation instruction
export const createOperationInstruction = async (req: Request, res: Response) => {
    const {
        instruction_number,
        instruction_date,
        route_name,
        departure_location,
        arrival_location,
        via_points,
        scheduled_departure_time,
        scheduled_arrival_time,
        primary_driver_id,
        secondary_driver_id,
        vehicle_id,
        expected_passengers,
        group_name,
        contact_person,
        contact_phone,
        planned_breaks,
        special_instructions
    } = req.body;

    const company_id = (req as any).user?.companyId;
    const createdBy = (req as any).user?.userId;

    try {
        // Generate instruction number if not provided
        let finalInstructionNumber = instruction_number;
        if (!finalInstructionNumber) {
            const dateStr = new Date(instruction_date).toISOString().slice(0, 10).replace(/-/g, '');
            const countResult = await pool.query(
                `SELECT COUNT(*) FROM operation_instructions WHERE company_id = $1 AND instruction_date = $2`,
                [company_id, instruction_date]
            );
            const count = parseInt(countResult.rows[0].count) + 1;
            finalInstructionNumber = `OI-${dateStr}-${String(count).padStart(3, '0')}`;
        }

        const result = await pool.query(`
            INSERT INTO operation_instructions (
                company_id, instruction_number, instruction_date, route_name,
                departure_location, arrival_location, via_points,
                scheduled_departure_time, scheduled_arrival_time,
                primary_driver_id, secondary_driver_id, vehicle_id,
                expected_passengers, group_name, contact_person, contact_phone,
                planned_breaks, special_instructions, created_by, status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, 'draft')
            RETURNING *
        `, [
            company_id, finalInstructionNumber, instruction_date, route_name,
            departure_location, arrival_location, via_points ? JSON.stringify(via_points) : null,
            scheduled_departure_time, scheduled_arrival_time,
            primary_driver_id, secondary_driver_id, vehicle_id,
            expected_passengers, group_name, contact_person, contact_phone,
            planned_breaks ? JSON.stringify(planned_breaks) : null, special_instructions, createdBy
        ]);

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating operation instruction:', error);
        if ((error as any).code === '23505') { // Unique constraint violation
            res.status(400).json({ error: 'Instruction number already exists' });
        } else {
            res.status(500).json({ error: 'Failed to create operation instruction' });
        }
    }
};

// PUT /operation-instructions/:id - Update operation instruction
export const updateOperationInstruction = async (req: Request, res: Response) => {
    const { id } = req.params;
    const {
        instruction_date,
        route_name,
        departure_location,
        arrival_location,
        via_points,
        scheduled_departure_time,
        scheduled_arrival_time,
        primary_driver_id,
        secondary_driver_id,
        vehicle_id,
        expected_passengers,
        group_name,
        contact_person,
        contact_phone,
        planned_breaks,
        special_instructions
    } = req.body;

    try {
        const result = await pool.query(`
            UPDATE operation_instructions SET
                instruction_date = COALESCE($1, instruction_date),
                route_name = COALESCE($2, route_name),
                departure_location = COALESCE($3, departure_location),
                arrival_location = COALESCE($4, arrival_location),
                via_points = COALESCE($5, via_points),
                scheduled_departure_time = COALESCE($6, scheduled_departure_time),
                scheduled_arrival_time = COALESCE($7, scheduled_arrival_time),
                primary_driver_id = COALESCE($8, primary_driver_id),
                secondary_driver_id = $9,
                vehicle_id = COALESCE($10, vehicle_id),
                expected_passengers = COALESCE($11, expected_passengers),
                group_name = $12,
                contact_person = $13,
                contact_phone = $14,
                planned_breaks = COALESCE($15, planned_breaks),
                special_instructions = $16,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $17
            RETURNING *
        `, [
            instruction_date, route_name, departure_location, arrival_location,
            via_points ? JSON.stringify(via_points) : null,
            scheduled_departure_time, scheduled_arrival_time,
            primary_driver_id, secondary_driver_id, vehicle_id,
            expected_passengers, group_name, contact_person, contact_phone,
            planned_breaks ? JSON.stringify(planned_breaks) : null, special_instructions, id
        ]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Operation instruction not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating operation instruction:', error);
        res.status(500).json({ error: 'Failed to update operation instruction' });
    }
};

// PUT /operation-instructions/:id/status - Update status (issue, start, complete, cancel)
export const updateOperationInstructionStatus = async (req: Request, res: Response) => {
    const { id } = req.params;
    const { status, actual_departure_time, actual_arrival_time, actual_passengers, completion_notes } = req.body;
    const userId = (req as any).user?.userId;

    try {
        // Validate status transition
        const currentResult = await pool.query(
            'SELECT status FROM operation_instructions WHERE id = $1',
            [id]
        );

        if (currentResult.rows.length === 0) {
            return res.status(404).json({ error: 'Operation instruction not found' });
        }

        const currentStatus = currentResult.rows[0].status;
        const validTransitions: { [key: string]: string[] } = {
            'draft': ['issued', 'cancelled'],
            'issued': ['in_progress', 'cancelled'],
            'in_progress': ['completed', 'cancelled'],
            'completed': [],
            'cancelled': []
        };

        if (!validTransitions[currentStatus]?.includes(status)) {
            return res.status(400).json({
                error: `Invalid status transition from ${currentStatus} to ${status}`
            });
        }

        let query = `
            UPDATE operation_instructions SET
                status = $1,
                updated_at = CURRENT_TIMESTAMP
        `;
        const params: any[] = [status];
        let paramIndex = 2;

        // Set issued info when issuing
        if (status === 'issued') {
            query += `, issued_by = $${paramIndex}, issued_at = CURRENT_TIMESTAMP`;
            params.push(userId);
            paramIndex++;
        }

        // Set actual times when completing
        if (status === 'completed') {
            if (actual_departure_time) {
                query += `, actual_departure_time = $${paramIndex}`;
                params.push(actual_departure_time);
                paramIndex++;
            }
            if (actual_arrival_time) {
                query += `, actual_arrival_time = $${paramIndex}`;
                params.push(actual_arrival_time);
                paramIndex++;
            }
            if (actual_passengers !== undefined) {
                query += `, actual_passengers = $${paramIndex}`;
                params.push(actual_passengers);
                paramIndex++;
            }
            if (completion_notes) {
                query += `, completion_notes = $${paramIndex}`;
                params.push(completion_notes);
                paramIndex++;
            }
        }

        query += ` WHERE id = $${paramIndex} RETURNING *`;
        params.push(id);

        const result = await pool.query(query, params);
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating operation instruction status:', error);
        res.status(500).json({ error: 'Failed to update status' });
    }
};

// DELETE /operation-instructions/:id - Delete operation instruction (only draft)
export const deleteOperationInstruction = async (req: Request, res: Response) => {
    const { id } = req.params;

    try {
        // Check if the instruction is in draft status
        const checkResult = await pool.query(
            'SELECT status FROM operation_instructions WHERE id = $1',
            [id]
        );

        if (checkResult.rows.length === 0) {
            return res.status(404).json({ error: 'Operation instruction not found' });
        }

        if (checkResult.rows[0].status !== 'draft') {
            return res.status(400).json({ error: 'Only draft instructions can be deleted' });
        }

        await pool.query('DELETE FROM operation_instructions WHERE id = $1', [id]);
        res.json({ message: 'Operation instruction deleted successfully' });
    } catch (error) {
        console.error('Error deleting operation instruction:', error);
        res.status(500).json({ error: 'Failed to delete operation instruction' });
    }
};
