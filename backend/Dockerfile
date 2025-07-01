# Use Ubuntu base image for shell script compatibility
FROM ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    ffmpeg \
    imagemagick \
    python3 \
    python3-pip \
    git \
    curl \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Install yt-dlp
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp && \
    chmod a+rx /usr/local/bin/yt-dlp

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install Node dependencies
RUN npm install

# Install Python dependencies for audio analysis
RUN pip3 install numpy cython
RUN pip3 install madmom

# Copy backend code
COPY . .

# Create projects directory
RUN mkdir -p /app/projects

# Make shell scripts executable
RUN chmod +x *.sh *.zsh

# Expose port
EXPOSE 3000

# Start the server
CMD ["node", "index.js"]
