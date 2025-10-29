'use client';

import type { AuctionOutcome } from '../types/auction';

interface OutcomesTableProps {
  outcomes: AuctionOutcome[];
}

export default function OutcomesTable({ outcomes }: OutcomesTableProps) {
  const formatPrice = (price: string | number) => {
    return typeof price === 'string' ? parseFloat(price).toFixed(4) : price.toFixed(4);
  };

  const formatTimestamp = (timestamp: string) => {
    return new Date(timestamp).toLocaleString();
  };

  return (
    <div className="overflow-x-auto rounded-lg border border-gray-200 dark:border-gray-700">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
              Bid ID
            </th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
              User ID
            </th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
              Site
            </th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
              Status
            </th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
              Bid Price
            </th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
              Win Price
            </th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
              Enriched
            </th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
              Timestamp
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
          {outcomes.length === 0 ? (
            <tr>
              <td colSpan={8} className="px-4 py-8 text-center text-gray-500 dark:text-gray-400">
                No auction outcomes found
              </td>
            </tr>
          ) : (
            outcomes.map((outcome) => (
              <tr key={outcome.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
                <td className="px-4 py-3 whitespace-nowrap text-sm font-mono text-gray-900 dark:text-gray-100">
                  {outcome.bid_id.substring(0, 12)}...
                </td>
                <td className="px-4 py-3 whitespace-nowrap text-sm font-mono text-gray-900 dark:text-gray-100">
                  {outcome.user_id.substring(0, 10)}...
                </td>
                <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                  {outcome.site_domain || 'N/A'}
                </td>
                <td className="px-4 py-3 whitespace-nowrap text-sm">
                  {outcome.win_status ? (
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
                      Won
                    </span>
                  ) : (
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200">
                      Lost
                    </span>
                  )}
                </td>
                <td className="px-4 py-3 whitespace-nowrap text-sm font-mono text-gray-900 dark:text-gray-100">
                  {formatPrice(outcome.bid_price)} {outcome.currency}
                </td>
                <td className="px-4 py-3 whitespace-nowrap text-sm font-mono text-gray-900 dark:text-gray-100">
                  {outcome.win_status ? `${formatPrice(outcome.win_price)} ${outcome.currency}` : '-'}
                </td>
                <td className="px-4 py-3 whitespace-nowrap text-sm">
                  {outcome.enriched ? (
                    <span className="text-blue-600 dark:text-blue-400">✓</span>
                  ) : (
                    <span className="text-gray-400">-</span>
                  )}
                </td>
                <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                  {formatTimestamp(outcome.timestamp)}
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}
