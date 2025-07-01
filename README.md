# Slideshow Web App

This repository turns the original slideshow shell scripts into a Docker-packaged web application.
It contains a Svelte front end and a small Node.js server that exposes the existing scripts.
Users can pick a project folder, arrange images, choose or download audio and render a video
without touching the command line.

## Architecture

```
docker-compose.yml
└─ slideshow/
   ├─ backend/        # Express API wrapping the shell scripts
   ├─ frontend/       # SvelteKit single page app
   ├─ scripts/        # legacy *.sh / *.zsh
   └─ projects/       # user data mounted from the host
```

The container includes `ffmpeg`, `libheif-examples` and `yt-dlp` so it can process
HEIC/JPEG images and download audio. Each project folder is treated as the source
of truth and will contain the rendered `slideshow.mp4` file.

## Usage

Build and run the application with Docker and mount a `projects` directory from
your machine:

```bash
docker build -t slideshow .
docker run -it --rm -p 3000:3000 -v "$(pwd)/projects:/app/projects" slideshow
```

Then open [http://localhost:3000](http://localhost:3000) to interact with the UI.
From there you can load or create projects, reorder images, select a music file
(or paste a YouTube URL), pick an "emotional" or "normal" mix and start the render job.

