import { Request, Response, NextFunction } from 'express';
import { pool } from '../utils/db';
import crypto from 'crypto';

export interface ApiKeyRequest extends Request {
    apiKey?: {
        id: number;
        company_id: number;
        scopes: string[];
        rate_limit_per_minute: number;
    };
}

// Rate limiting store (in production, use Redis)
const rateLimitStore: Map<number, { count: number; resetTime: number }> = new Map();

export const authenticateApiKey = async (req: ApiKeyRequest, res: Response, next: NextFunction) => {
    const authHeader = req.headers['x-api-key'] as string;

    if (!authHeader) {
        await logApiRequest(null, req, 401, 'Missing API key');
        return res.status(401).json({
            error: 'API key required',
            message: 'Please provide your API key in the X-API-Key header'
        });
    }

    try {
        // Look up the API key
        const keyResult = await pool.query(`
            SELECT ak.*, c.subscription_plan, c.subscription_status
            FROM api_keys ak
            JOIN companies c ON ak.company_id = c.id
            WHERE ak.api_key = $1 AND ak.is_active = TRUE
        `, [authHeader]);

        if (keyResult.rows.length === 0) {
            await logApiRequest(null, req, 401, 'Invalid API key');
            return res.status(401).json({
                error: 'Invalid API key',
                message: 'The provided API key is invalid or has been deactivated'
            });
        }

        const apiKey = keyResult.rows[0];

        // Check if key is expired
        if (apiKey.expires_at && new Date(apiKey.expires_at) < new Date()) {
            await logApiRequest(apiKey.id, req, 401, 'API key expired');
            return res.status(401).json({
                error: 'API key expired',
                message: 'Your API key has expired. Please generate a new one.'
            });
        }

        // Check subscription plan (API access requires Pro or Enterprise)
        if (!['pro', 'enterprise'].includes(apiKey.subscription_plan)) {
            await logApiRequest(apiKey.id, req, 403, 'Plan does not include API access');
            return res.status(403).json({
                error: 'API access not available',
                message: 'API access is only available for Pro and Enterprise plans'
            });
        }

        // Check subscription status
        if (apiKey.subscription_status !== 'active') {
            await logApiRequest(apiKey.id, req, 403, 'Subscription not active');
            return res.status(403).json({
                error: 'Subscription inactive',
                message: 'Your subscription is not active'
            });
        }

        // Check IP restrictions
        if (apiKey.allowed_ips && apiKey.allowed_ips.length > 0) {
            const clientIp = req.ip || req.socket.remoteAddress;
            if (!apiKey.allowed_ips.includes(clientIp)) {
                await logApiRequest(apiKey.id, req, 403, `IP not allowed: ${clientIp}`);
                return res.status(403).json({
                    error: 'IP not allowed',
                    message: 'This API key is not authorized for your IP address'
                });
            }
        }

        // Rate limiting
        const now = Date.now();
        const rateLimit = rateLimitStore.get(apiKey.id);

        if (rateLimit) {
            if (now < rateLimit.resetTime) {
                if (rateLimit.count >= apiKey.rate_limit_per_minute) {
                    await logApiRequest(apiKey.id, req, 429, 'Rate limit exceeded');
                    return res.status(429).json({
                        error: 'Rate limit exceeded',
                        message: `You have exceeded the rate limit of ${apiKey.rate_limit_per_minute} requests per minute`,
                        retry_after: Math.ceil((rateLimit.resetTime - now) / 1000)
                    });
                }
                rateLimit.count++;
            } else {
                rateLimitStore.set(apiKey.id, { count: 1, resetTime: now + 60000 });
            }
        } else {
            rateLimitStore.set(apiKey.id, { count: 1, resetTime: now + 60000 });
        }

        // Update last used timestamp
        await pool.query(`
            UPDATE api_keys
            SET last_used_at = CURRENT_TIMESTAMP, usage_count = usage_count + 1
            WHERE id = $1
        `, [apiKey.id]);

        // Attach API key info to request
        req.apiKey = {
            id: apiKey.id,
            company_id: apiKey.company_id,
            scopes: apiKey.scopes || ['read'],
            rate_limit_per_minute: apiKey.rate_limit_per_minute
        };

        next();
    } catch (error) {
        console.error('API key authentication error:', error);
        return res.status(500).json({ error: 'Internal server error' });
    }
};

// Check if the API key has the required scope
export const requireScope = (scope: string) => {
    return (req: ApiKeyRequest, res: Response, next: NextFunction) => {
        if (!req.apiKey) {
            return res.status(401).json({ error: 'API key required' });
        }

        if (!req.apiKey.scopes.includes(scope) && !req.apiKey.scopes.includes('admin')) {
            return res.status(403).json({
                error: 'Insufficient permissions',
                message: `This operation requires the '${scope}' scope`,
                required_scope: scope,
                your_scopes: req.apiKey.scopes
            });
        }

        next();
    };
};

// Log API requests
async function logApiRequest(
    apiKeyId: number | null,
    req: Request,
    statusCode: number,
    errorMessage?: string
): Promise<void> {
    try {
        const startTime = (req as any).startTime || Date.now();
        const responseTime = Date.now() - startTime;

        await pool.query(`
            INSERT INTO api_request_logs
            (api_key_id, company_id, endpoint, method, request_ip, user_agent, status_code, response_time_ms, error_message)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        `, [
            apiKeyId,
            apiKeyId ? null : null, // Will be filled if we have the key
            req.originalUrl,
            req.method,
            req.ip || req.socket.remoteAddress,
            req.headers['user-agent'],
            statusCode,
            responseTime,
            errorMessage
        ]);
    } catch (error) {
        console.error('Failed to log API request:', error);
    }
}

// Generate a secure API key
export function generateApiKey(): { key: string; prefix: string } {
    const prefix = 'lt_' + crypto.randomBytes(4).toString('hex');
    const secret = crypto.randomBytes(24).toString('hex');
    return {
        key: `${prefix}_${secret}`,
        prefix: prefix
    };
}

// Hash API key for storage (optional extra security)
export function hashApiKey(key: string): string {
    return crypto.createHash('sha256').update(key).digest('hex');
}
