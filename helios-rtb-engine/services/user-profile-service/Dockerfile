# syntax=docker/dockerfile:1.6

FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json package-lock.json tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:20-alpine AS prune
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json package-lock.json ./
RUN npm prune --omit=dev

FROM node:20-alpine AS runtime
ENV NODE_ENV=production
ENV PROTO_PATH=/app/proto/user_profile.proto
WORKDIR /app
COPY --from=prune /app/node_modules ./node_modules
COPY package.json package-lock.json ./
COPY --from=build /app/dist ./dist
# Use non-root user for security
RUN addgroup -g 1001 helios \
	&& adduser -D -G helios -u 1001 helios  \
	&& mkdir -p /app/proto \
	&& chown -R helios:helios /app
# Create a minimal proto file inline for now
RUN echo 'syntax = "proto3";\npackage helios.userprofile;\nservice UserProfileService {\n  rpc GetUserProfile(GetUserProfileRequest) returns (GetUserProfileResponse);\n}\nmessage GetUserProfileRequest {\n  string user_id = 1;\n}\nmessage Interest {\n  string category = 1;\n  double score = 2;\n}\nmessage UserProfile {\n  string user_id = 1;\n  string locale = 2;\n  repeated Interest interests = 3;\n  map<string, string> demographics = 4;\n}\nmessage GetUserProfileResponse {\n  UserProfile profile = 1;\n}' > /app/proto/user_profile.proto
USER helios
CMD ["node", "dist/server.js"]
