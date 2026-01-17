import { Request, Response } from 'express';
import { pool } from '../utils/db';
import { generateApiKey } from '../middleware/apiKeyAuth';
import crypto from 'crypto';

interface AuthRequest extends Request {
    user?: {
        userId: number;
        email: string;
        companyId?: number;
    };
}

// Get all API keys for the company
export const getApiKeys = async (req: AuthRequest, res: Response) => {
    try {
        const companyId = req.query.companyId || req.user?.companyId;

        if (!companyId) {
            return res.status(400).json({ error: 'Company ID is required' });
        }

        const result = await pool.query(`
            SELECT
                id, key_name, key_prefix, scopes, rate_limit_per_minute,
                allowed_ips, is_active, last_used_at, usage_count, expires_at,
                created_at, updated_at
            FROM api_keys
            WHERE company_id = $1
            ORDER BY created_at DESC
        `, [companyId]);

        res.json(result.rows);
    } catch (error) {
        console.error('Get API keys error:', error);
        res.status(500).json({ error: 'Failed to fetch API keys' });
    }
};

// Create a new API key
export const createApiKey = async (req: AuthRequest, res: Response) => {
    const {
        companyId,
        keyName,
        scopes = ['read'],
        rateLimitPerMinute = 60,
        allowedIps = [],
        expiresAt
    } = req.body;

    if (!companyId || !keyName) {
        return res.status(400).json({ error: 'Company ID and key name are required' });
    }

    try {
        // Check if company has Pro or Enterprise plan
        const companyResult = await pool.query(`
            SELECT subscription_plan FROM companies WHERE id = $1
        `, [companyId]);

        if (companyResult.rows.length === 0) {
            return res.status(404).json({ error: 'Company not found' });
        }

        const plan = companyResult.rows[0].subscription_plan;
        if (!['pro', 'enterprise'].includes(plan)) {
            return res.status(403).json({
                error: 'API access not available',
                message: 'API key generation is only available for Pro and Enterprise plans'
            });
        }

        // Generate new API key
        const { key, prefix } = generateApiKey();

        const result = await pool.query(`
            INSERT INTO api_keys
            (company_id, key_name, api_key, key_prefix, scopes, rate_limit_per_minute, allowed_ips, expires_at, created_by)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING id, key_name, key_prefix, scopes, rate_limit_per_minute, allowed_ips, is_active, expires_at, created_at
        `, [
            companyId,
            keyName,
            key,
            prefix,
            JSON.stringify(scopes),
            rateLimitPerMinute,
            allowedIps.length > 0 ? allowedIps : null,
            expiresAt || null,
            req.user?.userId || 1
        ]);

        // Return the full API key only once (on creation)
        res.status(201).json({
            message: 'API key created successfully',
            apiKey: {
                ...result.rows[0],
                key: key // Only returned on creation
            },
            warning: 'Please save this API key securely. It will not be shown again.'
        });
    } catch (error) {
        console.error('Create API key error:', error);
        res.status(500).json({ error: 'Failed to create API key' });
    }
};

// Update an API key
export const updateApiKey = async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const { keyName, scopes, rateLimitPerMinute, allowedIps, isActive, expiresAt } = req.body;
    const companyId = req.query.companyId || req.user?.companyId;

    try {
        // Build dynamic update query
        const updates: string[] = [];
        const values: any[] = [];
        let paramCount = 1;

        if (keyName !== undefined) {
            updates.push(`key_name = $${paramCount++}`);
            values.push(keyName);
        }
        if (scopes !== undefined) {
            updates.push(`scopes = $${paramCount++}`);
            values.push(JSON.stringify(scopes));
        }
        if (rateLimitPerMinute !== undefined) {
            updates.push(`rate_limit_per_minute = $${paramCount++}`);
            values.push(rateLimitPerMinute);
        }
        if (allowedIps !== undefined) {
            updates.push(`allowed_ips = $${paramCount++}`);
            values.push(allowedIps.length > 0 ? allowedIps : null);
        }
        if (isActive !== undefined) {
            updates.push(`is_active = $${paramCount++}`);
            values.push(isActive);
        }
        if (expiresAt !== undefined) {
            updates.push(`expires_at = $${paramCount++}`);
            values.push(expiresAt);
        }

        updates.push(`updated_at = CURRENT_TIMESTAMP`);

        if (updates.length === 1) {
            return res.status(400).json({ error: 'No fields to update' });
        }

        values.push(id);
        values.push(companyId);

        const result = await pool.query(`
            UPDATE api_keys
            SET ${updates.join(', ')}
            WHERE id = $${paramCount++} AND company_id = $${paramCount}
            RETURNING id, key_name, key_prefix, scopes, rate_limit_per_minute, allowed_ips, is_active, expires_at, updated_at
        `, values);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'API key not found' });
        }

        res.json({
            message: 'API key updated successfully',
            apiKey: result.rows[0]
        });
    } catch (error) {
        console.error('Update API key error:', error);
        res.status(500).json({ error: 'Failed to update API key' });
    }
};

// Delete an API key
export const deleteApiKey = async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const companyId = req.query.companyId || req.user?.companyId;

    try {
        const result = await pool.query(`
            DELETE FROM api_keys
            WHERE id = $1 AND company_id = $2
            RETURNING id, key_name
        `, [id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'API key not found' });
        }

        res.json({
            message: 'API key deleted successfully',
            deletedKey: result.rows[0]
        });
    } catch (error) {
        console.error('Delete API key error:', error);
        res.status(500).json({ error: 'Failed to delete API key' });
    }
};

// Regenerate an API key
export const regenerateApiKey = async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const companyId = req.query.companyId || req.user?.companyId;

    try {
        // Generate new API key
        const { key, prefix } = generateApiKey();

        const result = await pool.query(`
            UPDATE api_keys
            SET api_key = $1, key_prefix = $2, updated_at = CURRENT_TIMESTAMP, usage_count = 0
            WHERE id = $3 AND company_id = $4
            RETURNING id, key_name, key_prefix, scopes, rate_limit_per_minute, allowed_ips, is_active, expires_at
        `, [key, prefix, id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'API key not found' });
        }

        res.json({
            message: 'API key regenerated successfully',
            apiKey: {
                ...result.rows[0],
                key: key // Only returned on regeneration
            },
            warning: 'The old API key has been invalidated. Please update your applications.'
        });
    } catch (error) {
        console.error('Regenerate API key error:', error);
        res.status(500).json({ error: 'Failed to regenerate API key' });
    }
};

// Get API usage statistics
export const getApiUsageStats = async (req: AuthRequest, res: Response) => {
    const companyId = req.query.companyId || req.user?.companyId;
    const days = parseInt(req.query.days as string) || 30;

    try {
        // Get total usage per key
        const keyUsage = await pool.query(`
            SELECT
                ak.id, ak.key_name, ak.key_prefix, ak.usage_count, ak.last_used_at,
                COUNT(arl.id) as recent_requests,
                COUNT(CASE WHEN arl.status_code >= 200 AND arl.status_code < 300 THEN 1 END) as successful_requests,
                COUNT(CASE WHEN arl.status_code >= 400 THEN 1 END) as failed_requests,
                AVG(arl.response_time_ms) as avg_response_time
            FROM api_keys ak
            LEFT JOIN api_request_logs arl ON ak.id = arl.api_key_id AND arl.created_at > NOW() - INTERVAL '${days} days'
            WHERE ak.company_id = $1
            GROUP BY ak.id
            ORDER BY ak.usage_count DESC
        `, [companyId]);

        // Get daily usage for the period
        const dailyUsage = await pool.query(`
            SELECT
                DATE(created_at) as date,
                COUNT(*) as total_requests,
                COUNT(CASE WHEN status_code >= 200 AND status_code < 300 THEN 1 END) as successful,
                COUNT(CASE WHEN status_code >= 400 THEN 1 END) as failed
            FROM api_request_logs
            WHERE company_id = $1 AND created_at > NOW() - INTERVAL '${days} days'
            GROUP BY DATE(created_at)
            ORDER BY date DESC
        `, [companyId]);

        // Get most used endpoints
        const topEndpoints = await pool.query(`
            SELECT
                endpoint,
                method,
                COUNT(*) as request_count,
                AVG(response_time_ms) as avg_response_time
            FROM api_request_logs
            WHERE company_id = $1 AND created_at > NOW() - INTERVAL '${days} days'
            GROUP BY endpoint, method
            ORDER BY request_count DESC
            LIMIT 10
        `, [companyId]);

        res.json({
            keyUsage: keyUsage.rows,
            dailyUsage: dailyUsage.rows,
            topEndpoints: topEndpoints.rows,
            period: `${days} days`
        });
    } catch (error) {
        console.error('Get API usage stats error:', error);
        res.status(500).json({ error: 'Failed to fetch API usage statistics' });
    }
};

// === Webhook Management ===

// Get all webhooks for the company
export const getWebhooks = async (req: AuthRequest, res: Response) => {
    const companyId = req.query.companyId || req.user?.companyId;

    try {
        const result = await pool.query(`
            SELECT
                id, webhook_name, webhook_url, events, is_active,
                last_triggered_at, failure_count, created_at, updated_at
            FROM webhook_configs
            WHERE company_id = $1
            ORDER BY created_at DESC
        `, [companyId]);

        res.json(result.rows);
    } catch (error) {
        console.error('Get webhooks error:', error);
        res.status(500).json({ error: 'Failed to fetch webhooks' });
    }
};

// Create a webhook
export const createWebhook = async (req: AuthRequest, res: Response) => {
    const { companyId, webhookName, webhookUrl, events = [] } = req.body;

    if (!companyId || !webhookName || !webhookUrl) {
        return res.status(400).json({ error: 'Company ID, webhook name, and URL are required' });
    }

    try {
        // Generate webhook secret
        const secretKey = crypto.randomBytes(32).toString('hex');

        const result = await pool.query(`
            INSERT INTO webhook_configs
            (company_id, webhook_name, webhook_url, secret_key, events, created_by)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING id, webhook_name, webhook_url, events, is_active, created_at
        `, [
            companyId,
            webhookName,
            webhookUrl,
            secretKey,
            JSON.stringify(events),
            req.user?.userId || 1
        ]);

        res.status(201).json({
            message: 'Webhook created successfully',
            webhook: result.rows[0],
            secretKey: secretKey,
            warning: 'Please save this secret key securely. It will not be shown again.'
        });
    } catch (error) {
        console.error('Create webhook error:', error);
        res.status(500).json({ error: 'Failed to create webhook' });
    }
};

// Update a webhook
export const updateWebhook = async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const { webhookName, webhookUrl, events, isActive } = req.body;
    const companyId = req.query.companyId || req.user?.companyId;

    try {
        const updates: string[] = [];
        const values: any[] = [];
        let paramCount = 1;

        if (webhookName !== undefined) {
            updates.push(`webhook_name = $${paramCount++}`);
            values.push(webhookName);
        }
        if (webhookUrl !== undefined) {
            updates.push(`webhook_url = $${paramCount++}`);
            values.push(webhookUrl);
        }
        if (events !== undefined) {
            updates.push(`events = $${paramCount++}`);
            values.push(JSON.stringify(events));
        }
        if (isActive !== undefined) {
            updates.push(`is_active = $${paramCount++}`);
            values.push(isActive);
        }

        updates.push(`updated_at = CURRENT_TIMESTAMP`);

        values.push(id);
        values.push(companyId);

        const result = await pool.query(`
            UPDATE webhook_configs
            SET ${updates.join(', ')}
            WHERE id = $${paramCount++} AND company_id = $${paramCount}
            RETURNING id, webhook_name, webhook_url, events, is_active, updated_at
        `, values);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Webhook not found' });
        }

        res.json({
            message: 'Webhook updated successfully',
            webhook: result.rows[0]
        });
    } catch (error) {
        console.error('Update webhook error:', error);
        res.status(500).json({ error: 'Failed to update webhook' });
    }
};

// Delete a webhook
export const deleteWebhook = async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const companyId = req.query.companyId || req.user?.companyId;

    try {
        const result = await pool.query(`
            DELETE FROM webhook_configs
            WHERE id = $1 AND company_id = $2
            RETURNING id, webhook_name
        `, [id, companyId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Webhook not found' });
        }

        res.json({
            message: 'Webhook deleted successfully',
            deletedWebhook: result.rows[0]
        });
    } catch (error) {
        console.error('Delete webhook error:', error);
        res.status(500).json({ error: 'Failed to delete webhook' });
    }
};

// Test a webhook
export const testWebhook = async (req: AuthRequest, res: Response) => {
    const { id } = req.params;
    const companyId = req.query.companyId || req.user?.companyId;

    try {
        const webhookResult = await pool.query(`
            SELECT * FROM webhook_configs WHERE id = $1 AND company_id = $2
        `, [id, companyId]);

        if (webhookResult.rows.length === 0) {
            return res.status(404).json({ error: 'Webhook not found' });
        }

        const webhook = webhookResult.rows[0];

        // Create test payload
        const testPayload = {
            event: 'test',
            timestamp: new Date().toISOString(),
            data: {
                message: 'This is a test webhook from LogiTrace',
                webhook_id: webhook.id,
                webhook_name: webhook.webhook_name
            }
        };

        // Create signature
        const signature = crypto
            .createHmac('sha256', webhook.secret_key)
            .update(JSON.stringify(testPayload))
            .digest('hex');

        // Send test webhook
        const response = await fetch(webhook.webhook_url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-LogiTrace-Signature': signature,
                'X-LogiTrace-Event': 'test'
            },
            body: JSON.stringify(testPayload)
        });

        res.json({
            message: 'Test webhook sent',
            status: response.status,
            success: response.ok,
            response: response.ok ? 'Webhook endpoint responded successfully' : `Endpoint returned status ${response.status}`
        });
    } catch (error) {
        console.error('Test webhook error:', error);
        res.status(500).json({
            error: 'Webhook test failed',
            message: error instanceof Error ? error.message : 'Unknown error'
        });
    }
};
