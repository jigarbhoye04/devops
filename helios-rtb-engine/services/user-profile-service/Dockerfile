# syntax=docker/dockerfile:1

FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --ignore-scripts
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM gcr.io/distroless/nodejs20-debian12
USER nonroot
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY package.json package-lock.json* ./
COPY --from=build /app/node_modules ./node_modules
ENV NODE_ENV=production
CMD ["dist/index.js"]
