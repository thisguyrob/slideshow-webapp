# Use Node.js 20 base image for proper ES module support
FROM node:20

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install required packages and build tools
RUN apt-get update && apt-get install -y \
    ffmpeg \
    imagemagick \
    libheif-examples \
    build-essential \
    pkg-config \
    libasound2-dev \
    libsndfile1-dev \
    libfftw3-dev \
    git \
    curl \
    zsh \
    wget \
    jq \
    bc \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda (with architecture detection)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    wget $MINICONDA_URL -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh && \
    /opt/conda/bin/conda clean --all -y

# Add conda to PATH
ENV PATH="/opt/conda/bin:$PATH"

# Create conda environment for madmom (Python 3.9)
RUN conda create -n madmom python=3.9 -y && \
    conda run -n madmom pip install numpy==1.21.6 && \
    conda run -n madmom pip install scipy==1.7.3 && \
    conda run -n madmom pip install cython==0.29.32 && \
    conda run -n madmom pip install librosa && \
    conda run -n madmom pip install mido && \
    conda run -n madmom pip install madmom

# Create conda environment for yt-dlp (Python 3.11)
RUN conda create -n ytdlp python=3.11 -y && \
    conda run -n ytdlp pip install yt-dlp

# Create wrapper scripts
RUN echo '#!/bin/bash\n/opt/conda/envs/ytdlp/bin/python -m yt_dlp "$@"' > /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp

RUN echo '#!/bin/bash\n/opt/conda/envs/madmom/bin/python "$@"' > /usr/local/bin/madmom-python && \
    chmod +x /usr/local/bin/madmom-python

# Set working directory
WORKDIR /app

# Copy backend package files first to enable ES modules
COPY ./backend/package*.json ./

# Install Node dependencies
RUN npm install

# Verify conda environments work
RUN conda run -n madmom python -c "import madmom; print('✅ Madmom installed successfully in Python 3.9')"
RUN conda run -n ytdlp python -c "import yt_dlp; print('✅ yt-dlp installed successfully in Python 3.11')"

# Copy and build frontend first
COPY ./frontend/my-app ./frontend/my-app
WORKDIR /app/frontend/my-app
RUN npm install && npm run build

# Return to backend directory and copy backend code
WORKDIR /app
COPY ./backend .
# Remove the backend copy of package files since we already copied them
RUN rm -f package*.json

# Create projects directory
RUN mkdir -p /app/projects

# Make shell scripts executable
RUN chmod +x *.sh *.zsh

# Expose port
EXPOSE 3000

# Start the server
CMD ["node", "index.js"]