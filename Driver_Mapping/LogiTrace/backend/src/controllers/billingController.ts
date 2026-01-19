import { Request, Response } from 'express';
import { StripeService, PRICE_IDS } from '../services/stripeService';
import { pool } from '../utils/db';

export const createSubscription = async (req: Request, res: Response) => {
    // Expected to be called AFTER user registration (with Auth Token)
    // req.user is populated by authMiddleware
    const { plan } = req.body; // 'monthly' or 'yearly'
    const user = (req as any).user;

    if (!user || !user.userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        // 1. Get User from DB to check if they already have a stripe_customer_id
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

            // Save stripe_customer_id to DB
            await pool.query('UPDATE users SET stripe_customer_id = $1 WHERE id = $2', [customerId, user.userId]);
        }

        // 3. Determine Price ID
        const priceId = plan === 'yearly' ? PRICE_IDS.YEARLY : PRICE_IDS.MONTHLY;

        // 4. Create Subscription
        const { subscriptionId, clientSecret } = await StripeService.createSubscription(customerId, priceId);

        res.json({
            subscriptionId,
            clientSecret,
        });

    } catch (error: any) {
        console.error('Subscription creation failed:', error);
        res.status(500).json({ error: error.message || 'Subscription creation failed' });
    }
};
