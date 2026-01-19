import { Request, Response } from 'express';
import { StripeService } from '../services/stripeService';
import { pool } from '../utils/db';
import { getPlanById, PlanType } from '../config/pricing-plans';
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '', {
    apiVersion: '2023-10-16',
});

// Map Plans to Stripe Price IDs
const PLAN_PRICE_IDS: Record<string, string> = {
    [PlanType.FREE]: 'price_PLACEHOLDER_FREE',
    [PlanType.STARTER]: 'price_PLACEHOLDER_STARTER',
    [PlanType.PROFESSIONAL]: 'price_PLACEHOLDER_PROFESSIONAL',
    [PlanType.ENTERPRISE]: 'price_PLACEHOLDER_ENTERPRISE',
};

// Create Setup Intent (for collecting payment method before registration)
export const createSetupIntent = async (req: Request, res: Response) => {
    try {
        const setupIntent = await stripe.setupIntents.create({
            payment_method_types: ['card'],
        });
        res.json({ clientSecret: setupIntent.client_secret });
    } catch (error: any) {
        console.error('SetupIntent creation failed:', error);
        res.status(500).json({ error: error.message || 'SetupIntent creation failed' });
    }
};

export const createSubscription = async (req: Request, res: Response) => {
    const { planId, driverCount, paymentMethodId } = req.body;
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

        // 3. Attach Payment Method to Customer (if provided)
        if (paymentMethodId) {
            await stripe.paymentMethods.attach(paymentMethodId, {
                customer: customerId,
            });
            // Set as default payment method
            await stripe.customers.update(customerId, {
                invoice_settings: {
                    default_payment_method: paymentMethodId,
                },
            });
        }

        // 4. Determine Price ID
        const priceId = PLAN_PRICE_IDS[planId];
        if (!priceId) {
            return res.status(500).json({ error: 'Price ID not configured for this plan' });
        }

        // 5. Create Subscription with 14-day trial
        const subscription = await stripe.subscriptions.create({
            customer: customerId,
            items: [{ price: priceId }],
            trial_period_days: 14,
            payment_settings: {
                payment_method_types: ['card'],
                save_default_payment_method: 'on_subscription',
            },
            expand: ['latest_invoice.payment_intent', 'pending_setup_intent'],
        });

        // 6. Save Subscription to DB
        await pool.query(
            `INSERT INTO subscriptions (user_id, plan_id, stripe_subscription_id, stripe_customer_id, current_driver_count, status, trial_end)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             ON CONFLICT (stripe_subscription_id) DO UPDATE SET
             status = EXCLUDED.status,
             trial_end = EXCLUDED.trial_end`,
            [
                user.userId,
                planId,
                subscription.id,
                customerId,
                driverCount,
                subscription.status,
                subscription.trial_end ? new Date(subscription.trial_end * 1000) : null
            ]
        );

        // 7. Determine client secret for frontend
        let clientSecret = null;
        let type: 'setup' | 'payment' = 'setup';

        if (subscription.pending_setup_intent) {
            const setupIntent = subscription.pending_setup_intent as Stripe.SetupIntent;
            clientSecret = setupIntent.client_secret;
            type = 'setup';
        } else if (subscription.latest_invoice) {
            const invoice = subscription.latest_invoice as Stripe.Invoice;
            if (invoice.payment_intent) {
                const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent;
                clientSecret = paymentIntent.client_secret;
                type = 'payment';
            }
        }

        res.json({
            subscriptionId: subscription.id,
            clientSecret,
            type,
            status: subscription.status,
            trialEnd: subscription.trial_end
        });

    } catch (error: any) {
        console.error('Subscription creation failed:', error);
        res.status(500).json({ error: error.message || 'Subscription creation failed' });
    }
};
