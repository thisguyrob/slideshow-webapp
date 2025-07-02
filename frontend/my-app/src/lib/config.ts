// API configuration that works across devices
export function getApiUrl(): string {
    // In production or when accessing from another device, use the same host
    // but on port 3000 (backend port)
    if (typeof window !== 'undefined') {
        const hostname = window.location.hostname;
        // If we're on localhost:5173 (dev server), use localhost:3000
        // Otherwise, use the same hostname with port 3000
        return `http://${hostname}:3000`;
    }
    // Server-side rendering fallback
    return 'http://localhost:3000';
}

export const API_URL = getApiUrl();