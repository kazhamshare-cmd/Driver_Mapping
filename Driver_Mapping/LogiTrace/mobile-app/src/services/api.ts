import { API_BASE_URL, API_ENDPOINTS } from '../config/api';

class ApiService {
    private token: string | null = null;
    private user: any = null;

    setToken(token: string) {
        this.token = token;
    }

    setUser(user: any) {
        this.user = user;
    }

    getUser() {
        return this.user;
    }

    async login(email: string, password: string) {
        try {
            const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.LOGIN}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ email, password }),
            });
            const data = await response.json();
            if (!response.ok) throw new Error(data.error || 'Login failed');

            return data;
        } catch (error) {
            throw error;
        }
    }

    async createWorkRecord(record: any) {
        try {
            const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.WORK_RECORDS}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    // 'Authorization': `Bearer ${this.token}` // Add when JWT is ready
                },
                body: JSON.stringify(record),
            });
            const data = await response.json();
            if (!response.ok) throw new Error(data.error || 'Failed to create record');
            return data;
        } catch (error) {
            throw error;
        }
    }

    async updateWorkRecord(id: number, updates: any) {
        try {
            const response = await fetch(`${API_BASE_URL}${API_ENDPOINTS.WORK_RECORDS}/${id}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(updates),
            });
            const data = await response.json();
            if (!response.ok) throw new Error(data.error || 'Failed to update record');
            return data;
        } catch (error) {
            throw error;
        }
    }
}

export const api = new ApiService();
