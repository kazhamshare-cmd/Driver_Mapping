import { Request, Response } from 'express';
import { pool } from '../utils/db';

// 業種一覧取得
export const getIndustryTypes = async (req: Request, res: Response) => {
    try {
        const result = await pool.query(
            `SELECT id, code, name_ja, name_en, is_active, created_at
             FROM industry_types
             WHERE is_active = TRUE
             ORDER BY id`
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching industry types:', error);
        res.status(500).json({ error: 'Failed to fetch industry types' });
    }
};

// 業種別車両タイプ取得
export const getVehicleTypesByIndustry = async (req: Request, res: Response) => {
    try {
        const { industryCode } = req.params;

        const result = await pool.query(
            `SELECT vt.id, vt.code, vt.name_ja, vt.name_en, vt.capacity_unit, vt.max_capacity, vt.display_order
             FROM vehicle_type_master vt
             JOIN industry_types it ON vt.industry_type_id = it.id
             WHERE it.code = $1 AND vt.is_active = TRUE
             ORDER BY vt.display_order, vt.name_ja`,
            [industryCode]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching vehicle types:', error);
        res.status(500).json({ error: 'Failed to fetch vehicle types' });
    }
};

// 全車両タイプ取得
export const getAllVehicleTypes = async (req: Request, res: Response) => {
    try {
        const result = await pool.query(
            `SELECT vt.id, vt.code, vt.name_ja, vt.name_en, vt.capacity_unit, vt.max_capacity,
                    it.code as industry_code, it.name_ja as industry_name
             FROM vehicle_type_master vt
             JOIN industry_types it ON vt.industry_type_id = it.id
             WHERE vt.is_active = TRUE
             ORDER BY it.id, vt.display_order, vt.name_ja`
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching all vehicle types:', error);
        res.status(500).json({ error: 'Failed to fetch vehicle types' });
    }
};

// 会社の業種設定
export const updateCompanyIndustry = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.params;
        const { industry_type_id, business_license_number, safety_manager_name, operation_manager_name } = req.body;

        const result = await pool.query(
            `UPDATE companies
             SET industry_type_id = $1,
                 business_license_number = $2,
                 safety_manager_name = $3,
                 operation_manager_name = $4,
                 updated_at = NOW()
             WHERE id = $5
             RETURNING *`,
            [industry_type_id, business_license_number, safety_manager_name, operation_manager_name, companyId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Company not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating company industry:', error);
        res.status(500).json({ error: 'Failed to update company industry' });
    }
};

// 会社情報取得（業種含む）
export const getCompanyWithIndustry = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.params;

        const result = await pool.query(
            `SELECT c.*, it.code as industry_code, it.name_ja as industry_name
             FROM companies c
             LEFT JOIN industry_types it ON c.industry_type_id = it.id
             WHERE c.id = $1`,
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

// 業種別運行種別マスタ取得
export const getOperationTypesByIndustry = async (req: Request, res: Response) => {
    try {
        const { industryCode } = req.params;

        const result = await pool.query(
            `SELECT otm.id, otm.code, otm.name_ja, otm.name_en, otm.description, otm.display_order
             FROM operation_type_master otm
             JOIN industry_types it ON otm.industry_type_id = it.id
             WHERE it.code = $1 AND otm.is_active = TRUE
             ORDER BY otm.display_order, otm.name_ja`,
            [industryCode]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching operation types:', error);
        res.status(500).json({ error: 'Failed to fetch operation types' });
    }
};

// 業種別フィールド設定取得
export const getFieldConfigByIndustry = async (req: Request, res: Response) => {
    try {
        const { industryCode } = req.params;

        const result = await pool.query(
            `SELECT ifc.field_name, ifc.field_label_ja, ifc.field_label_en,
                    ifc.is_visible, ifc.is_required, ifc.display_order, ifc.field_type, ifc.default_value
             FROM industry_field_config ifc
             JOIN industry_types it ON ifc.industry_type_id = it.id
             WHERE it.code = $1
             ORDER BY ifc.display_order, ifc.field_name`,
            [industryCode]
        );

        // Transform to a more usable format
        const fieldConfig: { [key: string]: any } = {};
        result.rows.forEach((row: any) => {
            fieldConfig[row.field_name] = {
                label_ja: row.field_label_ja,
                label_en: row.field_label_en,
                visible: row.is_visible,
                required: row.is_required,
                order: row.display_order,
                type: row.field_type,
                default: row.default_value
            };
        });

        res.json({
            industryCode,
            fields: fieldConfig,
            visibleFields: result.rows.filter((r: any) => r.is_visible).map((r: any) => r.field_name),
            hiddenFields: result.rows.filter((r: any) => !r.is_visible).map((r: any) => r.field_name)
        });
    } catch (error) {
        console.error('Error fetching field config:', error);
        res.status(500).json({ error: 'Failed to fetch field configuration' });
    }
};

// 会社のドライバー一覧取得（交替運転者選択用）
export const getCompanyDrivers = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.params;

        const result = await pool.query(
            `SELECT u.id, u.name, u.employee_number
             FROM users u
             WHERE u.company_id = $1 AND u.user_type = 'driver' AND u.status = 'active'
             ORDER BY u.name`,
            [companyId]
        );

        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching company drivers:', error);
        res.status(500).json({ error: 'Failed to fetch drivers' });
    }
};
