import path from "node:path";
import process from "node:process";
import {
  Server,
  ServerCredentials,
  handleUnaryCall,
  loadPackageDefinition,
  status,
} from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import { createClient } from "redis";
import { config } from "dotenv";
config({ path: '../../.env' });

interface GetUserProfileRequestMessage {
  userId: string;
}

interface InterestMessage {
  category: string;
  score: number;
}

interface UserProfileMessage {
  userId: string;
  locale: string;
  interests: InterestMessage[];
  demographics: Record<string, string>;
}

interface GetUserProfileResponseMessage {
  profile: UserProfileMessage;
}

interface UserProfileServiceHandlers {
  GetUserProfile: handleUnaryCall<
    GetUserProfileRequestMessage,
    GetUserProfileResponseMessage
  >;
}

interface ProtoGrpcType {
  helios: {
    userprofile: {
      UserProfileService: {
        service: import("@grpc/grpc-js").ServiceDefinition<UserProfileServiceHandlers>;
      };
    };
  };
}

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

const buildDefaultProfile = (userId = ""): UserProfileMessage => ({
  userId,
  locale: "",
  interests: [],
  demographics: {},
});

const normalizeProfile = (raw: unknown, fallbackUserId: string): UserProfileMessage => {
  if (typeof raw !== "object" || raw === null) {
    return buildDefaultProfile(fallbackUserId);
  }

  const candidate = raw as Record<string, unknown>;
  const interestsRaw = Array.isArray(candidate.interests)
    ? (candidate.interests as unknown[])
    : [];

  const interests: InterestMessage[] = interestsRaw
    .map((item) => {
      if (typeof item !== "object" || item === null) {
        return undefined;
      }

      const interestCandidate = item as Record<string, unknown>;
      const category =
        typeof interestCandidate.category === "string"
          ? interestCandidate.category
          : typeof interestCandidate["category"] === "string"
          ? (interestCandidate["category"] as string)
          : undefined;
      const scoreRaw = interestCandidate.score ?? interestCandidate["score"];
      const score = typeof scoreRaw === "number" ? scoreRaw : undefined;

      if (!category || typeof score !== "number") {
        return undefined;
      }

      return { category, score } satisfies InterestMessage;
    })
    .filter((interest): interest is InterestMessage => interest !== undefined);

  const demographicsSource = candidate.demographics ?? candidate["demographics"];
  const demographics: Record<string, string> =
    demographicsSource && typeof demographicsSource === "object"
      ? Object.entries(demographicsSource as Record<string, unknown>)
          .filter((entry): entry is [string, string] => typeof entry[1] === "string")
          .reduce<Record<string, string>>((acc, [key, value]) => {
            acc[key] = value;
            return acc;
          }, {})
      : {};

  const userIdValue =
    typeof candidate.userId === "string"
      ? candidate.userId
      : typeof candidate["user_id"] === "string"
      ? (candidate["user_id"] as string)
      : fallbackUserId;

  const localeValue =
    typeof candidate.locale === "string"
      ? candidate.locale
      : typeof candidate["locale"] === "string"
      ? (candidate["locale"] as string)
      : "";

  return {
    userId: userIdValue,
    locale: localeValue,
    interests,
    demographics,
  };
};

const loadProto = (): ProtoGrpcType => {
  const defaultProtoPath = path.resolve(
    __dirname,
    "..",
    "..",
    "..",
    "proto",
    "user_profile.proto"
  );

  const protoPath = process.env.PROTO_PATH ?? defaultProtoPath;

  const packageDefinition = protoLoader.loadSync(protoPath, {
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
    keepCase: false,
  });

  return loadPackageDefinition(packageDefinition) as unknown as ProtoGrpcType;
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

const startServer = async (): Promise<void> => {
  const redisClient = await createRedisClient();
  const proto = loadProto();
  const server = new Server();

  const getUserProfile: UserProfileServiceHandlers["GetUserProfile"] = async (
    call,
    callback
  ) => {
    const requestUserId =
      call.request?.userId ?? (call.request as unknown as { user_id?: string })?.user_id ?? "";

    log("INFO", "Received GetUserProfile request", {
      userId: requestUserId,
    });

    if (!requestUserId) {
      callback({
        code: status.INVALID_ARGUMENT,
        message: "user_id is required",
      });
      return;
    }

    try {
      const rawProfile = await redisClient.get(requestUserId);

      if (!rawProfile) {
        const response: GetUserProfileResponseMessage = {
          profile: buildDefaultProfile(requestUserId),
        };
        log("INFO", "User profile not found", {
          userId: requestUserId,
          response,
        });
        callback(null, response);
        return;
      }

      const parsed = JSON.parse(rawProfile) as unknown;
      const profile = normalizeProfile(parsed, requestUserId);

      const response: GetUserProfileResponseMessage = { profile };
      log("INFO", "Returning user profile", {
        userId: requestUserId,
        response,
      });
      callback(null, response);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      log("ERROR", "Failed to retrieve user profile", {
        userId: requestUserId,
        error: message,
      });
      callback({
        code: status.INTERNAL,
        message: "Failed to retrieve user profile",
      });
    }
  };

  server.addService(
    proto.helios.userprofile.UserProfileService.service,
    {
      GetUserProfile: getUserProfile,
    }
  );

  const serverAddress = "0.0.0.0:50051";
  server.bindAsync(
    serverAddress,
    ServerCredentials.createInsecure(),
    (error, port) => {
      if (error) {
        log("ERROR", "Failed to bind gRPC server", { error: error.message });
        process.exit(1);
      }

      server.start();
      log("INFO", "User Profile gRPC server started", {
        port,
      });
    }
  );

  const shutdown = async () => {
    log("INFO", "Shutting down server");
    server.tryShutdown((serverError) => {
      if (serverError) {
        log("ERROR", "Error during gRPC shutdown", { error: serverError.message });
      }
    });

    await redisClient.quit();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
};

startServer().catch((error) => {
  const message = error instanceof Error ? error.message : "Unknown error";
  log("ERROR", "Fatal error while starting service", { error: message });
  process.exit(1);
});
