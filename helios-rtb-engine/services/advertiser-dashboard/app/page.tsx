'use client';

import { useEffect, useState } from 'react';
import StatsCards from './components/StatsCards';
import OutcomesTable from './components/OutcomesTable';
import WinRateChart from './components/WinRateChart';
import { fetchOutcomes, fetchStatistics, fetchDailyStats } from './lib/api';
import type { AuctionOutcome, Statistics, DailyStats } from './types/auction';

export default function Home() {
  const [outcomes, setOutcomes] = useState<AuctionOutcome[]>([]);
  const [statistics, setStatistics] = useState<Statistics | null>(null);
  const [dailyStats, setDailyStats] = useState<DailyStats[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);

      // Fetch all data in parallel
      const [outcomesData, statsData, dailyStatsData] = await Promise.all([
        fetchOutcomes(page, 50),
        fetchStatistics(),
        fetchDailyStats(),
      ]);

      setOutcomes(outcomesData.results);
      setStatistics(statsData);
      setDailyStats(dailyStatsData);
      setHasMore(outcomesData.next !== null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load data');
      console.error('Error loading dashboard data:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = () => {
    setPage(1);
    loadData();
  };

  const handleNextPage = () => {
    if (hasMore) {
      setPage(page + 1);
    }
  };

  const handlePrevPage = () => {
    if (page > 1) {
      setPage(page - 1);
    }
  };

  useEffect(() => {
    loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page]);

  // Auto-refresh every 30 seconds
  useEffect(() => {
    const interval = setInterval(() => {
      loadData();
    }, 30000);

    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page]);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      {/* Header */}
      <header className="bg-white dark:bg-gray-800 shadow-sm border-b border-gray-200 dark:border-gray-700">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">
                Helios RTB Dashboard
              </h1>
              <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                Real-time auction analytics and insights
              </p>
            </div>
            <button
              onClick={handleRefresh}
              disabled={loading}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white rounded-lg font-medium transition-colors flex items-center gap-2"
            >
              <svg
                className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                />
              </svg>
              {loading ? 'Loading...' : 'Refresh'}
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {error && (
          <div className="mb-6 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4">
            <div className="flex items-center">
              <svg
                className="w-5 h-5 text-red-400 mr-2"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fillRule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                  clipRule="evenodd"
                />
              </svg>
              <p className="text-sm text-red-800 dark:text-red-200">{error}</p>
            </div>
          </div>
        )}

        <div className="space-y-8">
          {/* Statistics Cards */}
          <section>
            <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-4">
              Overview
            </h2>
            <StatsCards stats={statistics} loading={loading} />
          </section>

          {/* Charts */}
          <section>
            <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-4">
              Analytics
            </h2>
            <WinRateChart data={dailyStats} />
          </section>

          {/* Outcomes Table */}
          <section>
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">
                Recent Auction Outcomes
              </h2>
              <div className="flex items-center gap-2">
                <button
                  onClick={handlePrevPage}
                  disabled={page === 1 || loading}
                  className="px-3 py-1 bg-gray-200 hover:bg-gray-300 disabled:bg-gray-100 disabled:text-gray-400 dark:bg-gray-700 dark:hover:bg-gray-600 dark:disabled:bg-gray-800 text-gray-800 dark:text-gray-200 rounded font-medium transition-colors"
                >
                  Previous
                </button>
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  Page {page}
                </span>
                <button
                  onClick={handleNextPage}
                  disabled={!hasMore || loading}
                  className="px-3 py-1 bg-gray-200 hover:bg-gray-300 disabled:bg-gray-100 disabled:text-gray-400 dark:bg-gray-700 dark:hover:bg-gray-600 dark:disabled:bg-gray-800 text-gray-800 dark:text-gray-200 rounded font-medium transition-colors"
                >
                  Next
                </button>
              </div>
            </div>
            <OutcomesTable outcomes={outcomes} />
          </section>
        </div>
      </main>

      {/* Footer */}
      <footer className="mt-12 bg-white dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <p className="text-center text-sm text-gray-500 dark:text-gray-400">
            Helios RTB Engine - Real-Time Bidding Analytics Platform
          </p>
        </div>
      </footer>
    </div>
  );
}
