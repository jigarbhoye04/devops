const { Kafka } = require('kafkajs');

/**
 * Logs a structured JSON message to stdout
 * @param {string} level - Log level (info, warning, error, fatal)
 * @param {string} message - Log message
 * @param {Object} fields - Additional fields to include
 */
function logJSON(level, message, fields = {}) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...fields
  };
  console.log(JSON.stringify(logEntry));
}

/**
 * Gets an environment variable or throws an error if not found
 * @param {string} name - Environment variable name
 * @returns {string} - Environment variable value
 */
function getEnvVar(name) {
  const value = process.env[name];
  if (!value) {
    logJSON('fatal', 'Missing required environment variable', { env: name });
    process.exit(1);
  }
  return value;
}

/**
 * Simulates auction logic to determine if a bid wins
 * @param {Object} bidResponse - The bid response object
 * @returns {Object} - Auction outcome with win_status and win_price
 */
function runAuction(bidResponse) {
  const { bid_price, user_id, bid_request_id } = bidResponse;
  
  // Simple auction logic:
  // 1. Bid must have a valid price
  // 2. Random chance (70%) of winning if price > threshold (e.g., $0.50)
  // 3. Win price is typically the bid price (first-price auction simulation)
  
  const MIN_BID_THRESHOLD = parseFloat(process.env.MIN_BID_THRESHOLD || '0.5');
  const WIN_PROBABILITY = parseFloat(process.env.WIN_PROBABILITY || '0.7');
  
  let winStatus = false;
  let winPrice = 0.0;
  
  if (typeof bid_price === 'number' && bid_price > MIN_BID_THRESHOLD) {
    // Random chance to win
    winStatus = Math.random() < WIN_PROBABILITY;
    
    if (winStatus) {
      // In a first-price auction, winner pays their bid
      // Could also implement second-price auction logic
      winPrice = bid_price;
    }
  }
  
  logJSON('info', 'Auction processed', {
    user_id,
    bid_request_id,
    bid_price,
    win_status: winStatus,
    win_price: winPrice
  });
  
  return {
    ...bidResponse,
    win_status: winStatus,
    win_price: winPrice,
    auction_timestamp: new Date().toISOString()
  };
}

/**
 * Main application entry point
 */
async function main() {
  // Load environment variables
  const kafkaBroker = getEnvVar('KAFKA_BROKER');
  const bidResponseTopic = getEnvVar('KAFKA_BID_RESPONSE_TOPIC');
  const auctionOutcomeTopic = getEnvVar('KAFKA_AUCTION_OUTCOME_TOPIC');
  const consumerGroup = process.env.KAFKA_CONSUMER_GROUP || 'auction-simulator-group';
  
  logJSON('info', 'Starting Auction Simulator Service', {
    kafka_broker: kafkaBroker,
    bid_response_topic: bidResponseTopic,
    auction_outcome_topic: auctionOutcomeTopic,
    consumer_group: consumerGroup
  });
  
  // Initialize Kafka client
  const kafka = new Kafka({
    clientId: 'auction-simulator',
    brokers: kafkaBroker.split(',').map(b => b.trim()),
    retry: {
      initialRetryTime: 100,
      retries: 8
    }
  });
  
  const consumer = kafka.consumer({ groupId: consumerGroup });
  const producer = kafka.producer();
  
  // Graceful shutdown handler
  const shutdown = async () => {
    logJSON('info', 'Shutting down gracefully...');
    await consumer.disconnect();
    await producer.disconnect();
    process.exit(0);
  };
  
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
  
  try {
    // Connect consumer and producer
    await consumer.connect();
    await producer.connect();
    
    logJSON('info', 'Kafka consumer and producer connected');
    
    // Subscribe to bid responses topic
    await consumer.subscribe({
      topic: bidResponseTopic,
      fromBeginning: true
    });
    
    logJSON('info', 'Subscribed to bid responses topic', {
      topic: bidResponseTopic
    });
    
    // Process messages
    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const rawValue = message.value.toString();
          
          logJSON('info', 'Bid response received', {
            topic,
            partition,
            offset: message.offset,
            value: rawValue
          });
          
          // Parse bid response
          let bidResponse;
          try {
            bidResponse = JSON.parse(rawValue);
          } catch (parseError) {
            logJSON('error', 'Failed to parse bid response JSON', {
              payload: rawValue,
              error: parseError.message
            });
            return;
          }
          
          // Validate bid response has required fields
          if (!bidResponse.bid_request_id) {
            logJSON('warning', 'Bid response missing bid_request_id', {
              bid_response: bidResponse
            });
            return;
          }
          
          // Run auction logic
          const auctionOutcome = runAuction(bidResponse);
          
          // Produce auction outcome to Kafka
          await producer.send({
            topic: auctionOutcomeTopic,
            messages: [
              {
                key: auctionOutcome.bid_request_id,
                value: JSON.stringify(auctionOutcome)
              }
            ]
          });
          
          logJSON('info', 'Auction outcome published', {
            topic: auctionOutcomeTopic,
            bid_request_id: auctionOutcome.bid_request_id,
            win_status: auctionOutcome.win_status,
            win_price: auctionOutcome.win_price
          });
          
        } catch (error) {
          logJSON('error', 'Error processing bid response', {
            error: error.message,
            stack: error.stack
          });
        }
      }
    });
    
  } catch (error) {
    logJSON('fatal', 'Fatal error in auction simulator', {
      error: error.message,
      stack: error.stack
    });
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch(error => {
    logJSON('fatal', 'Unhandled error in main', {
      error: error.message,
      stack: error.stack
    });
    process.exit(1);
  });
}

module.exports = { main, runAuction, logJSON };
