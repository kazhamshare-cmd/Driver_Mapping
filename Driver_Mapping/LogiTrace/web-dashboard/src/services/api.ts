// API service for making authenticated requests

const getAuthHeaders = () => {
    const token = localStorage.getItem('token');
    return {
        'Content-Type': 'application/json',
        ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
    };
};

interface ApiOptions extends Omit<RequestInit, 'body'> {
    params?: Record<string, string | number | boolean | undefined | null>;
}

const buildUrl = (url: string, params?: Record<string, string | number | boolean | undefined | null>): string => {
    if (!params) return url;
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null) {
            searchParams.append(key, String(value));
        }
    });
    const queryString = searchParams.toString();
    return queryString ? `${url}?${queryString}` : url;
};

export const api = {
    get: async (url: string, options?: ApiOptions) => {
        const { params, ...fetchOptions } = options || {};
        const fullUrl = buildUrl(url, params);
        const response = await fetch(fullUrl, {
            method: 'GET',
            headers: getAuthHeaders(),
            ...fetchOptions,
        });
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
    },
    post: async (url: string, data?: any, options?: ApiOptions) => {
        const { params, ...fetchOptions } = options || {};
        const fullUrl = buildUrl(url, params);
        const response = await fetch(fullUrl, {
            method: 'POST',
            headers: getAuthHeaders(),
            body: data ? JSON.stringify(data) : undefined,
            ...fetchOptions,
        });
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
    },
    put: async (url: string, data?: any, options?: ApiOptions) => {
        const { params, ...fetchOptions } = options || {};
        const fullUrl = buildUrl(url, params);
        const response = await fetch(fullUrl, {
            method: 'PUT',
            headers: getAuthHeaders(),
            body: data ? JSON.stringify(data) : undefined,
            ...fetchOptions,
        });
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
    },
    delete: async (url: string, options?: ApiOptions) => {
        const { params, ...fetchOptions } = options || {};
        const fullUrl = buildUrl(url, params);
        const response = await fetch(fullUrl, {
            method: 'DELETE',
            headers: getAuthHeaders(),
            ...fetchOptions,
        });
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
    }
};

export default api;
