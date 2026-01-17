import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_BASE_URL, API_ENDPOINTS } from '../config/api';

const TOKEN_KEY = 'auth_token';
const USER_KEY = 'user_data';

export type IndustryCode = 'trucking' | 'taxi' | 'bus';

export interface User {
    id: number;
    email: string;
    name: string;
    user_type: 'driver' | 'admin';
    company_id: number;
    company_name?: string;
    industry_type_id?: number;
    industry_code?: IndustryCode;
    industry_name?: string;
    // Legacy aliases for backward compatibility
    companyId?: number;
    companyName?: string;
}

export interface LoginResponse {
    token: string;
    user: User;
}

class AuthService {
    // Login with email and password
    async login(email: string, password: string): Promise<LoginResponse> {
        const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.LOGIN}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ email, password }),
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'ログインに失敗しました');
        }

        const data = await response.json();

        // Store token and user data
        await this.setToken(data.token);
        await this.setUser(data.user);

        return data;
    }

    // Register driver with company code
    async registerWithCompanyCode(
        companyCode: string,
        name: string,
        email: string,
        password: string
    ): Promise<LoginResponse> {
        const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.REGISTER}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ companyCode, name, email, password }),
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || '登録に失敗しました');
        }

        const data = await response.json();

        // Store token and user data
        await this.setToken(data.token);
        await this.setUser(data.user);

        return data;
    }

    // Get stored token
    async getToken(): Promise<string | null> {
        return await AsyncStorage.getItem(TOKEN_KEY);
    }

    // Set token
    async setToken(token: string): Promise<void> {
        await AsyncStorage.setItem(TOKEN_KEY, token);
    }

    // Get stored user
    async getUser(): Promise<User | null> {
        const userData = await AsyncStorage.getItem(USER_KEY);
        return userData ? JSON.parse(userData) : null;
    }

    // Set user
    async setUser(user: User): Promise<void> {
        await AsyncStorage.setItem(USER_KEY, JSON.stringify(user));
    }

    // Logout
    async logout(): Promise<void> {
        await AsyncStorage.multiRemove([TOKEN_KEY, USER_KEY]);
    }

    // Check if user is logged in
    async isLoggedIn(): Promise<boolean> {
        const token = await this.getToken();
        return !!token;
    }

    // Make authenticated API request
    async authenticatedFetch(endpoint: string, options: RequestInit = {}): Promise<Response> {
        const token = await this.getToken();

        const headers = {
            'Content-Type': 'application/json',
            ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
            ...options.headers,
        };

        return fetch(`${API_BASE_URL}${endpoint}`, {
            ...options,
            headers,
        });
    }
}

export const authService = new AuthService();
