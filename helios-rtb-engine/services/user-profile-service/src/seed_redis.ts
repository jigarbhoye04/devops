import process from "node:process";
import { createClient } from "redis";

import { config } from "dotenv";
config({ path: '../../.env' });

type Interest = {
  category: string;
  score: number;
};

type UserProfile = {
  user_id: string;
  locale: string;
  interests: Interest[];
  demographics: Record<string, string>;
};

type LogLevel = "INFO" | "ERROR";

type LogContext = Record<string, unknown> | undefined;

const log = (level: LogLevel, message: string, context?: LogContext): void => {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...(context ?? {}),
  };

  console.log(JSON.stringify(entry));
};

const generateInterests = (count: number): Interest[] => {
  const categories = [
    "sports",
    "technology",
    "travel",
    "food",
    "finance",
    "gaming",
    "music",
    "automotive",
    "fitness",
    "fashion",
  ];

  const interests: Interest[] = [];

  for (let i = 0; i < count; i += 1) {
    const category = categories[Math.floor(Math.random() * categories.length)];
    const score = Number((0.5 + Math.random() * 0.5).toFixed(2));
    interests.push({ category, score });
  }

  return interests;
};

const generateDemographics = (): Record<string, string> => {
  const ageBrackets = ["18-24", "25-34", "35-44", "45-54", "55-64"];
  const incomeBrackets = ["<50k", "50k-100k", "100k-150k", "150k+"];
  const genders = ["female", "male", "non-binary"];

  return {
    age_bracket: ageBrackets[Math.floor(Math.random() * ageBrackets.length)],
    income_bracket: incomeBrackets[Math.floor(Math.random() * incomeBrackets.length)],
    gender: genders[Math.floor(Math.random() * genders.length)],
  };
};

const generateProfiles = (count: number): UserProfile[] => {
  const locales = ["en-US", "en-GB", "fr-FR", "es-ES", "de-DE", "ja-JP"];

  return Array.from({ length: count }, (_, index) => {
    const userNumber = (index + 1).toString().padStart(3, "0");
    return {
      user_id: `user-${userNumber}`,
      locale: locales[Math.floor(Math.random() * locales.length)],
      interests: generateInterests(3 + Math.floor(Math.random() * 3)),
      demographics: generateDemographics(),
    } satisfies UserProfile;
  });
};

type RedisClient = ReturnType<typeof createClient>;

const createRedisClient = async (): Promise<RedisClient> => {
  const host = process.env.REDIS_HOST ?? "localhost";
  const port = process.env.REDIS_PORT ? Number(process.env.REDIS_PORT) : 6379;

  if (Number.isNaN(port)) {
    throw new Error("REDIS_PORT must be a valid number");
  }

  const client = createClient({
    socket: {
      host,
      port,
    },
  });

  client.on("error", (error: Error) => {
    log("ERROR", "Redis client error", { error: error.message });
  });

  await client.connect();
  log("INFO", "Connected to Redis", { host, port });
  return client;
};

const seedProfiles = async (client: RedisClient, profiles: UserProfile[]): Promise<void> => {
  for (const profile of profiles) {
    await client.set(profile.user_id, JSON.stringify(profile));
  }
};

const main = async (): Promise<void> => {
  const client = await createRedisClient();
  try {
  const profileCount = 5 + Math.floor(Math.random() * 6); // Generates between 5 and 10 profiles
    const profiles = generateProfiles(profileCount);

    await seedProfiles(client, profiles);

    log("INFO", "Seeded user profiles to Redis", {
      count: profiles.length,
      userIds: profiles.map((profile) => profile.user_id),
    });
  } finally {
    await client.quit();
    log("INFO", "Disconnected from Redis");
  }
};

main().catch((error) => {
  const message = error instanceof Error ? error.message : "Unknown error";
  log("ERROR", "Failed to seed Redis", { error: message });
  process.exit(1);
});
