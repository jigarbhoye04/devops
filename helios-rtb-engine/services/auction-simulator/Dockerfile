# syntax=docker/dockerfile:1

FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --ignore-scripts
COPY src ./src

FROM gcr.io/distroless/nodejs20-debian12
USER nonroot
WORKDIR /app
COPY --from=build /app ./
CMD ["src/index.js"]
