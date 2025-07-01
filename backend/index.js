import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import cors from 'cors';
import { WebSocketServer } from 'ws';
import projectRoutes from './api/projects.js';
import uploadRoutes from './api/uploads.js';
import processRoutes from './api/process.js';
import analyzeRoutes from './api/analyze.js';

const app = express();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const buildPath = path.join(__dirname, '../frontend/my-app/build');

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// API Routes
app.use('/api/projects', projectRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/process', processRoutes);
app.use('/api/analyze', analyzeRoutes);

// Serve static files from the React app
app.use(express.static(buildPath));

// Serve project files
app.use('/api/files', express.static(path.join(__dirname, '../projects')));

// Catch all handler - serve React app
app.get('*', (_req, res) => {
  res.sendFile(path.join(buildPath, 'index.html'));
});

const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});

// WebSocket setup for real-time updates
const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  console.log('WebSocket client connected');
  
  ws.on('close', () => {
    console.log('WebSocket client disconnected');
  });
});

export { wss };
