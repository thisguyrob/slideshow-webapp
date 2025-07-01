# Slideshow Web App

This project packages a Svelte front-end and Node.js backend into a Docker image. The backend serves the built front-end and includes the original slideshow shell scripts.

## Quick start

Build and run the container, mounting the `projects` folder to store your data:

```bash
docker build -t slideshow .
docker run -it --rm -p 3000:3000 -v "$(pwd)/projects:/app/projects" slideshow
```

Open `http://localhost:3000` in your browser.
