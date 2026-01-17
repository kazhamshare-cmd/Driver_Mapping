// API Configuration
// Replace with your actual API URL in production
export const API_BASE_URL = 'https://haisha-pro.com/api';

// API Endpoints
export const API_ENDPOINTS = {
    // Auth
    LOGIN: '/auth/login',
    REGISTER: '/drivers/register-by-code',

    // Work Records
    WORK_RECORDS: '/work-records',
    START_WORK: '/work-records/start',
    END_WORK: '/work-records/end',
    UPDATE_LOCATION: '/work-records/location',

    // Driver Info
    DRIVER_PROFILE: '/drivers/me',
};
