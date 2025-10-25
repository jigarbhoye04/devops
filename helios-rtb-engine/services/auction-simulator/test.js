// Test script for Auction Simulator Service
// This script simulates the auction logic locally for testing

const { runAuction, logJSON } = require('./src/index.js');

console.log('=== Auction Simulator Test Suite ===\n');

// Test cases
const testCases = [
  {
    name: 'High bid - should likely win',
    bidResponse: {
      bid_request_id: 'test-001',
      user_id: 'user-123',
      bid_price: 1.50,
      currency: 'USD',
      timestamp: new Date().toISOString(),
      enriched: true,
      user_interests: ['technology', 'sports']
    }
  },
  {
    name: 'Low bid - should likely lose',
    bidResponse: {
      bid_request_id: 'test-002',
      user_id: 'user-456',
      bid_price: 0.20,
      currency: 'USD',
      timestamp: new Date().toISOString(),
      enriched: false
    }
  },
  {
    name: 'Threshold bid - 50/50 chance',
    bidResponse: {
      bid_request_id: 'test-003',
      user_id: 'user-789',
      bid_price: 0.55,
      currency: 'USD',
      timestamp: new Date().toISOString(),
      enriched: true,
      user_interests: ['finance']
    }
  },
  {
    name: 'Zero bid - should lose',
    bidResponse: {
      bid_request_id: 'test-004',
      user_id: 'user-999',
      bid_price: 0.00,
      currency: 'USD',
      timestamp: new Date().toISOString(),
      enriched: false
    }
  }
];

// Run tests
testCases.forEach((testCase, index) => {
  console.log(`Test ${index + 1}: ${testCase.name}`);
  console.log('Input:', JSON.stringify(testCase.bidResponse, null, 2));
  
  const outcome = runAuction(testCase.bidResponse);
  
  console.log('Output:', JSON.stringify(outcome, null, 2));
  console.log('Result:', outcome.win_status ? '✅ WON' : '❌ LOST');
  if (outcome.win_status) {
    console.log(`Win Price: $${outcome.win_price}`);
  }
  console.log('---\n');
});

// Statistics over 100 runs
console.log('\n=== Running 100 iterations for statistics ===\n');

const testBid = {
  bid_request_id: 'stat-test',
  user_id: 'user-stat',
  bid_price: 0.75,
  currency: 'USD',
  timestamp: new Date().toISOString(),
  enriched: true
};

let wins = 0;
let totalWinPrice = 0;

for (let i = 0; i < 100; i++) {
  const result = runAuction({ ...testBid, bid_request_id: `stat-${i}` });
  if (result.win_status) {
    wins++;
    totalWinPrice += result.win_price;
  }
}

console.log(`Bid Price: $${testBid.bid_price}`);
console.log(`Win Rate: ${wins}% (${wins}/100)`);
if (wins > 0) {
  console.log(`Average Win Price: $${(totalWinPrice / wins).toFixed(2)}`);
}
console.log(`Expected Win Rate: ~70% (with default WIN_PROBABILITY=0.7)`);
console.log(`Deviation: ${Math.abs(wins - 70)}%\n`);

console.log('=== Test Complete ===');
