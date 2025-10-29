import type { OutcomesResponse, Statistics, DailyStats } from '../types/auction';

/**
 * Get the analytics API base URL from environment variable
 * Default to localhost for development
 */
const getApiBaseUrl = (): string => {
  // Runtime environment variable for client-side
  if (typeof window !== 'undefined') {
    return (window as Window & { __ANALYTICS_API_URL__?: string }).__ANALYTICS_API_URL__ || 
           process.env.NEXT_PUBLIC_ANALYTICS_API_URL || 
           'http://localhost:8000';
  }
  // Server-side
  return process.env.ANALYTICS_API_URL || 
         process.env.NEXT_PUBLIC_ANALYTICS_API_URL || 
         'http://localhost:8000';
};

/**
 * Fetch auction outcomes from the analytics service
 */
export async function fetchOutcomes(
  page: number = 1,
  pageSize: number = 50
): Promise<OutcomesResponse> {
  const apiUrl = getApiBaseUrl();
  const url = `${apiUrl}/api/outcomes/?page=${page}&page_size=${pageSize}&ordering=-timestamp`;
  
  const response = await fetch(url, {
    cache: 'no-store', // Always get fresh data
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch outcomes: ${response.statusText}`);
  }

  return response.json();
}

/**
 * Fetch statistics from the analytics service
 */
export async function fetchStatistics(): Promise<Statistics> {
  const apiUrl = getApiBaseUrl();
  const url = `${apiUrl}/api/outcomes/stats/`;
  
  const response = await fetch(url, {
    cache: 'no-store',
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch statistics: ${response.statusText}`);
  }

  return response.json();
}

/**
 * Fetch daily statistics for charting
 */
export async function fetchDailyStats(): Promise<DailyStats[]> {
  const apiUrl = getApiBaseUrl();
  const url = `${apiUrl}/api/outcomes/daily_stats/`;
  
  const response = await fetch(url, {
    cache: 'no-store',
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch daily stats: ${response.statusText}`);
  }

  return response.json();
}

/**
 * Fetch winning outcomes only
 */
export async function fetchWinners(
  page: number = 1,
  pageSize: number = 50
): Promise<OutcomesResponse> {
  const apiUrl = getApiBaseUrl();
  const url = `${apiUrl}/api/outcomes/winners/?page=${page}&page_size=${pageSize}&ordering=-timestamp`;
  
  const response = await fetch(url, {
    cache: 'no-store',
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch winners: ${response.statusText}`);
  }

  return response.json();
}
