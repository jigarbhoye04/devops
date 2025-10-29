/**
 * Auction Outcome type definition matching the analytics-service API
 */
export interface AuctionOutcome {
  id: number;
  bid_id: string;
  user_id: string;
  site_domain: string | null;
  win_status: boolean;
  win_price: string;
  bid_price: string;
  currency: string;
  enriched: boolean;
  timestamp: string;
  auction_timestamp: string;
  user_interests: string[];
  raw_data: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

/**
 * API response structure for paginated outcomes
 */
export interface OutcomesResponse {
  count: number;
  next: string | null;
  previous: string | null;
  results: AuctionOutcome[];
}

/**
 * Statistics response from the API
 */
export interface Statistics {
  total_outcomes: number;
  total_wins: number;
  total_losses: number;
  win_rate: number;
  total_revenue: number;
  average_win_price: number;
  average_bid_price: number;
  enriched_count: number;
}

/**
 * Daily statistics for charts
 */
export interface DailyStats {
  date: string;
  total_bids: number;
  wins: number;
  losses: number;
  win_rate: number;
  total_revenue: number;
  avg_win_price: number;
}
