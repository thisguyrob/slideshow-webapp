# Stage 1: build frontend
FROM node:18-bookworm AS builder
WORKDIR /app
COPY frontend ./frontend
WORKDIR /app/frontend/my-app
RUN npm ci && npm run build

# Stage 2: runtime
FROM node:18-bookworm-slim
WORKDIR /app

# Install system dependencies including Python
RUN apt-get update && \
    apt-get install -y \
    ffmpeg \
    libheif-examples \
    yt-dlp \
    zsh \
    jq \
    bc \
    python3 \
    python3-pip \
    python3-numpy \
    python3-scipy \
    libsndfile1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install madmom for beat detection
RUN pip3 install --no-cache-dir madmom

COPY --from=builder /app/frontend/my-app/build ./frontend
COPY backend ./backend
COPY projects ./projects

# Make shell scripts executable
RUN chmod +x backend/*.sh backend/*.zsh

# Install Node dependencies
RUN cd backend && npm ci --production

EXPOSE 3000
CMD ["node", "backend/index.js"]
