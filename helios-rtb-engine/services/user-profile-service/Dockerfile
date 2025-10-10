# syntax=docker/dockerfile:1.6

FROM node:20-alpine AS deps
WORKDIR /app
COPY services/user-profile-service/package.json ./package.json
COPY services/user-profile-service/package-lock.json ./package-lock.json
RUN npm ci

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY services/user-profile-service/package.json ./package.json
COPY services/user-profile-service/package-lock.json ./package-lock.json
COPY services/user-profile-service/tsconfig.json ./tsconfig.json
COPY services/user-profile-service/src ./src
RUN npm run build

FROM node:20-alpine AS prune
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY services/user-profile-service/package.json ./package.json
COPY services/user-profile-service/package-lock.json ./package-lock.json
RUN npm prune --omit=dev

FROM node:20-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=prune /app/node_modules ./node_modules
COPY services/user-profile-service/package.json ./package.json
COPY services/user-profile-service/package-lock.json ./package-lock.json
COPY --from=build /app/dist ./dist
COPY proto/user_profile.proto ./proto/user_profile.proto
# Use non-root user for security
RUN mkdir -p proto \
	&& addgroup -g 1001 helios \
	&& adduser -D -G helios -u 1001 helios
USER helios
CMD ["node", "dist/server.js"]
