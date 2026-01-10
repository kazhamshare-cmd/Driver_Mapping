import Stripe from 'stripe';

const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || 'sk_test_PLACEHOLDER';
const stripe = new Stripe(STRIPE_SECRET_KEY, {
    apiVersion: '2024-12-18.acacia' as any, // Updated to a recent version
});

// Price IDs (Replace with real ones from Stripe Dashboard)
export const PRICE_IDS = {
    MONTHLY: 'price_PLACEHOLDER_MONTHLY',
    YEARLY: 'price_PLACEHOLDER_YEARLY',
};

export class StripeService {
    static async createCustomer(email: string, name: string) {
        return await stripe.customers.create({
            email,
            name,
        });
    }

    static async createSubscription(customerId: string, priceId: string) {
        // Create subscription with 'incomplete' status to handle initial payment/setup
        const subscription = await stripe.subscriptions.create({
            customer: customerId,
            items: [{ price: priceId }],
            payment_behavior: 'default_incomplete',
            payment_settings: { save_default_payment_method: 'on_subscription' },
            expand: ['latest_invoice.payment_intent', 'pending_setup_intent'],
            trial_period_days: 14,
        });

        // For subscriptions with trial, Stripe often creates a SetupIntent (pending_setup_intent)
        // because no payment is due immediately. If a payment WAS due, it would be a PaymentIntent.

        // However, if we want to collect card details upfront for a future charge (default_incomplete),
        // we typically rely on the SetupIntent for standard trialing.

        // Let's check if we have a payment intent or setup intent.
        // If there's a trial, the latest_invoice might allow us to setup the card.

        let clientSecret = '';
        let intentType: 'setup' | 'payment' = 'payment';

        if (subscription.pending_setup_intent) {
            const setupIntent = subscription.pending_setup_intent as Stripe.SetupIntent;
            clientSecret = setupIntent.client_secret || '';
            intentType = 'setup';
        } else if (subscription.latest_invoice) {
            const invoice = subscription.latest_invoice as any; // Cast to any to avoid strict type issues with expansion
            if (invoice.payment_intent) {
                const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent;
                clientSecret = paymentIntent.client_secret || '';
                intentType = 'payment';
            }
        }

        return {
            subscriptionId: subscription.id,
            clientSecret,
            type: intentType
        };
    }
}
