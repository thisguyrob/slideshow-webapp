# Stage 1: build frontend
FROM node:18-bookworm AS builder
WORKDIR /app
COPY frontend ./frontend
WORKDIR /app/frontend/my-app
RUN npm ci && npm run build

# Stage 2: runtime
FROM node:18-bookworm-slim
WORKDIR /app
RUN apt-get update && \
    apt-get install -y ffmpeg libheif-examples yt-dlp && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/frontend/my-app/build ./frontend
COPY backend ./backend
COPY projects ./projects
RUN cd backend && npm ci --production
EXPOSE 3000
CMD ["node", "backend/index.js"]
