import { Request, Response } from 'express';
import { StripeService } from '../services/stripeService';
import { pool } from '../utils/db';
import { getPlanById, PlanType } from '../config/pricing-plans';
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '', {
    apiVersion: '2024-12-18.acacia' as any,
});

// Map Plans to Stripe Price IDs from environment variables
const PLAN_PRICE_IDS: Record<string, string> = {
    [PlanType.SMALL]: process.env.STRIPE_PRICE_SMALL || '',
    [PlanType.STANDARD]: process.env.STRIPE_PRICE_STANDARD || '',
    [PlanType.PRO]: process.env.STRIPE_PRICE_PRO || '',
    [PlanType.ENTERPRISE]: process.env.STRIPE_PRICE_ENTERPRISE || '',
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

// Get current subscription info
export const getSubscription = async (req: Request, res: Response) => {
    const user = (req as any).user;

    if (!user || !user.userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        // Get subscription from DB
        const result = await pool.query(`
            SELECT s.*, u.stripe_customer_id
            FROM subscriptions s
            JOIN users u ON s.user_id = u.id
            WHERE s.user_id = $1
            ORDER BY s.created_at DESC
            LIMIT 1
        `, [user.userId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'No subscription found' });
        }

        const subscription = result.rows[0];

        // Get Stripe subscription details for real-time info
        if (subscription.stripe_subscription_id) {
            try {
                const stripeSubscription = await stripe.subscriptions.retrieve(subscription.stripe_subscription_id) as any;

                // Update local subscription with Stripe data
                subscription.status = stripeSubscription.status;
                subscription.trial_ends_at = stripeSubscription.trial_end
                    ? new Date(stripeSubscription.trial_end * 1000).toISOString()
                    : null;
                subscription.current_period_end = stripeSubscription.current_period_end
                    ? new Date(stripeSubscription.current_period_end * 1000).toISOString()
                    : null;
                subscription.cancel_at_period_end = stripeSubscription.cancel_at_period_end;

                // Update DB with latest status
                await pool.query(`
                    UPDATE subscriptions
                    SET status = $1, updated_at = CURRENT_TIMESTAMP
                    WHERE id = $2
                `, [stripeSubscription.status, subscription.id]);
            } catch (stripeErr) {
                console.error('Error fetching Stripe subscription:', stripeErr);
                // Continue with local data
            }
        }

        res.json(subscription);
    } catch (error: any) {
        console.error('Get subscription failed:', error);
        res.status(500).json({ error: error.message || 'Failed to get subscription' });
    }
};

// Cancel subscription
export const cancelSubscription = async (req: Request, res: Response) => {
    const user = (req as any).user;

    if (!user || !user.userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        // Get subscription from DB
        const result = await pool.query(`
            SELECT * FROM subscriptions
            WHERE user_id = $1
            ORDER BY created_at DESC
            LIMIT 1
        `, [user.userId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'No subscription found' });
        }

        const subscription = result.rows[0];

        if (!subscription.stripe_subscription_id) {
            return res.status(400).json({ error: 'No Stripe subscription to cancel' });
        }

        // Cancel at period end (user keeps access until end of billing period)
        const canceledSubscription = await stripe.subscriptions.update(
            subscription.stripe_subscription_id,
            { cancel_at_period_end: true }
        ) as any;

        // Update DB
        await pool.query(`
            UPDATE subscriptions
            SET status = 'canceled', updated_at = CURRENT_TIMESTAMP
            WHERE id = $1
        `, [subscription.id]);

        res.json({
            message: 'Subscription canceled successfully',
            canceledAt: canceledSubscription.cancel_at
                ? new Date(canceledSubscription.cancel_at * 1000).toISOString()
                : null,
            accessUntil: canceledSubscription.current_period_end
                ? new Date(canceledSubscription.current_period_end * 1000).toISOString()
                : null
        });
    } catch (error: any) {
        console.error('Cancel subscription failed:', error);
        res.status(500).json({ error: error.message || 'Failed to cancel subscription' });
    }
};
