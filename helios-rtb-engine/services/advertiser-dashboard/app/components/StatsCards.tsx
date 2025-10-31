'use client';

import type { Statistics } from '../types/auction';

interface StatsCardsProps {
  stats: Statistics | null;
  loading?: boolean;
}

export default function StatsCards({ stats, loading }: StatsCardsProps) {
  if (loading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="bg-white dark:bg-gray-800 rounded-lg shadow p-6 animate-pulse">
            <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-3/4 mb-2"></div>
            <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-1/2"></div>
          </div>
        ))}
      </div>
    );
  }

  if (!stats) {
    return null;
  }

  const cards = [
    {
      title: 'Total Outcomes',
      value: (stats.total_outcomes || 0).toLocaleString(),
      subtext: `${(stats.total_wins || 0).toLocaleString()} wins, ${(stats.total_losses || 0).toLocaleString()} losses`,
      color: 'blue',
    },
    {
      title: 'Win Rate',
      value: `${(stats.win_rate || 0).toFixed(2)}%`,
      subtext: `${(stats.enriched_count || 0).toLocaleString()} enriched`,
      color: 'green',
    },
    {
      title: 'Total Revenue',
      value: `$${(stats.total_revenue || 0).toFixed(2)}`,
      subtext: `Avg: $${(stats.average_win_price || 0).toFixed(4)}`,
      color: 'purple',
    },
    {
      title: 'Avg Bid Price',
      value: `$${(stats.average_bid_price || 0).toFixed(4)}`,
      subtext: 'All auctions',
      color: 'orange',
    },
  ];

  const colorClasses: Record<string, { bg: string; text: string }> = {
    blue: { bg: 'bg-blue-50 dark:bg-blue-900/20', text: 'text-blue-600 dark:text-blue-400' },
    green: { bg: 'bg-green-50 dark:bg-green-900/20', text: 'text-green-600 dark:text-green-400' },
    purple: { bg: 'bg-purple-50 dark:bg-purple-900/20', text: 'text-purple-600 dark:text-purple-400' },
    orange: { bg: 'bg-orange-50 dark:bg-orange-900/20', text: 'text-orange-600 dark:text-orange-400' },
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      {cards.map((card, idx) => {
        const colors = colorClasses[card.color];
        return (
          <div
            key={idx}
            className={`${colors.bg} rounded-lg shadow p-6 border border-gray-200 dark:border-gray-700`}
          >
            <h3 className="text-sm font-medium text-gray-600 dark:text-gray-400 mb-2">
              {card.title}
            </h3>
            <p className={`text-3xl font-bold ${colors.text} mb-1`}>
              {card.value}
            </p>
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {card.subtext}
            </p>
          </div>
        );
      })}
    </div>
  );
}
