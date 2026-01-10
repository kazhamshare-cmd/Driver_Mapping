import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { Pool } from 'pg';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
import authRoutes from './routes/authRoutes';
import workRecordRoutes from './routes/workRecordRoutes';
// import billingRoutes from './routes/billingRoutes'; // Deprecated
import subscriptionRoutes from './routes/subscriptionRoutes';

app.use('/auth', authRoutes);
app.use('/work-records', workRecordRoutes);
app.use('/billing', subscriptionRoutes); // Keep /billing prefix for now or change to /subscriptions

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
});

// Health check
app.get('/', (req, res) => {
    res.send('LogiTrace API is running');
});

// Start server
app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
});

export { pool };
