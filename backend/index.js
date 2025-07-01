import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import cors from 'cors';
import { WebSocketServer } from 'ws';
import projectRoutes from './api/projects.js';
import uploadRoutes from './api/uploads.js';
console.log('About to import process routes...');
import processRoutes, { setWebSocketServer } from './api/process.js';
console.log('Process routes imported:', !!processRoutes);
import analyzeRoutes from './api/analyze.js';
import { handler as svelteKitHandler } from './frontend-build/handler.js';

const app = express();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const buildPath = path.join(__dirname, 'frontend-build');

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// API Routes
console.log('Registering API routes...');
app.use('/api/projects', projectRoutes);
console.log('Projects routes registered');
app.use('/api/upload', uploadRoutes);
console.log('Upload routes registered');
app.use('/api/process', processRoutes);
console.log('Process routes registered');
app.use('/api/analyze', analyzeRoutes);
console.log('Analyze routes registered');

// Serve SvelteKit static assets with proper prefixes
app.use('/_app', express.static(path.join(buildPath, 'client/_app')));
app.use('/favicon.svg', (req, res) => {
  res.sendFile(path.join(buildPath, 'client/favicon.svg'));
});

// Serve project files
app.use('/api/files', express.static(path.join(__dirname, 'projects')));

// SvelteKit handler for all non-API routes
app.use(svelteKitHandler);

const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});

// WebSocket setup for real-time updates
const wss = new WebSocketServer({ server });

// Set the WebSocket server instance for the process routes
setWebSocketServer(wss);

wss.on('connection', (ws) => {
  console.log('WebSocket client connected');
  
  ws.on('close', () => {
    console.log('WebSocket client disconnected');
  });
});

export { wss };
