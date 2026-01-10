import { Request, Response } from 'express';
import { StripeService } from '../services/stripeService';
import { pool } from '../utils/db';
import { getPlanById, PlanType } from '../config/pricing-plans';

// Map Plans to Stripe Price IDs
const PLAN_PRICE_IDS: Record<string, string> = {
    [PlanType.SMALL]: 'price_PLACEHOLDER_SMALL',
    [PlanType.STANDARD]: 'price_PLACEHOLDER_STANDARD',
    [PlanType.PRO]: 'price_PLACEHOLDER_PRO',
    [PlanType.ENTERPRISE]: 'price_PLACEHOLDER_ENTERPRISE', // Enterprise usually requires custom handling
};

export const createSubscription = async (req: Request, res: Response) => {
    // Expected to be called AFTER user registration (with Auth Token)
    // req.user is populated by authMiddleware
    const { planId, driverCount } = req.body;
    const user = (req as any).user;

    if (!user || !user.userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        const plan = getPlanById(planId);
        if (!plan) {
            return res.status(400).json({ error: 'Invalid Plan ID' });
        }

        // Validate Driver Count
        if (plan.maxDrivers && (driverCount < plan.minDrivers || driverCount > plan.maxDrivers)) {
            return res.status(400).json({ error: `Driver count must be between ${plan.minDrivers} and ${plan.maxDrivers} for this plan.` });
        }
        if (!plan.maxDrivers && driverCount < plan.minDrivers) {
            return res.status(400).json({ error: `Driver count must be at least ${plan.minDrivers} for this plan.` });
        }

        // 1. Get User from DB
        const userResult = await pool.query('SELECT * FROM users WHERE id = $1', [user.userId]);
        const dbUser = userResult.rows[0];

        if (!dbUser) {
            return res.status(404).json({ error: 'User not found' });
        }

        let customerId = dbUser.stripe_customer_id;

        // 2. Create Stripe Customer if not exists
        if (!customerId) {
            const customer = await StripeService.createCustomer(dbUser.email, dbUser.name);
            customerId = customer.id;
            await pool.query('UPDATE users SET stripe_customer_id = $1 WHERE id = $2', [customerId, user.userId]);
        }

        // 3. Determine Price ID
        const priceId = PLAN_PRICE_IDS[planId];
        if (!priceId) {
            return res.status(500).json({ error: 'Price ID not configured for this plan' });
        }

        // 4. Create Subscription
        // Note: We use the Placeholders from PLAN_PRICE_IDS. 
        // In production, these should be environment variables or fetched from a config service.
        const { subscriptionId, clientSecret, type } = await StripeService.createSubscription(customerId, priceId);

        // 5. Save Subscription to DB
        // We insert with status 'incomplete' initially. Webhooks should update this to 'active'.
        await pool.query(
            `INSERT INTO subscriptions (user_id, plan_id, stripe_subscription_id, stripe_customer_id, current_driver_count, status)
             VALUES ($1, $2, $3, $4, $5, 'incomplete')
             ON CONFLICT (stripe_subscription_id) DO NOTHING`,
            [user.userId, planId, subscriptionId, customerId, driverCount]
        );

        res.json({
            subscriptionId,
            clientSecret,
            type // 'setup' or 'payment'
        });

    } catch (error: any) {
        console.error('Subscription creation failed:', error);
        res.status(500).json({ error: error.message || 'Subscription creation failed' });
    }
};
