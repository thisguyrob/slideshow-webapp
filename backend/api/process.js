import express from 'express';
import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs/promises';
import { fileURLToPath } from 'url';
import { wss } from '../index.js';

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECTS_DIR = path.join(__dirname, '../../projects');
const SCRIPTS_DIR = path.join(__dirname, '..');

// Active processes map
const activeProcesses = new Map();

// Send progress update to WebSocket clients
function sendProgressUpdate(projectId, message, progress = null) {
  const update = {
    type: 'progress',
    projectId,
    message,
    progress,
    timestamp: new Date().toISOString()
  };
  
  wss.clients.forEach((client) => {
    if (client.readyState === 1) { // WebSocket.OPEN
      client.send(JSON.stringify(update));
    }
  });
}

// Process slideshow for a project
router.post('/:projectId/process', async (req, res) => {
  try {
    const { projectId } = req.params;
    let { audioOffset = '00:00', audioType = 'normal' } = req.body;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    // Check for saved audio offset in metadata
    try {
      const metadataPath = path.join(projectDir, 'metadata.json');
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      
      // Use saved offset if no offset provided in request
      if (!req.body.audioOffset && metadata.audioOffset) {
        audioOffset = metadata.audioOffset;
      }
      
      // Use saved audio type if not provided
      if (!req.body.audioType && metadata.audioType) {
        audioType = metadata.audioType;
      }
    } catch (err) {
      // No metadata or error reading it, use defaults
    }
    
    // Check if project exists
    try {
      await fs.access(projectDir);
    } catch (err) {
      return res.status(404).json({ error: 'Project not found' });
    }
    
    // Check if process is already running
    if (activeProcesses.has(projectId)) {
      return res.status(400).json({ error: 'Process already running for this project' });
    }
    
    // Check for required files
    const files = await fs.readdir(projectDir);
    const hasImages = files.some(f => /\.(jpg|jpeg|png|heic)$/i.test(f));
    const hasAudio = files.some(f => /\.(mp3|wav|m4a)$/i.test(f)) || 
                    files.includes('audio.txt');
    
    if (!hasImages) {
      return res.status(400).json({ error: 'No images found in project' });
    }
    
    if (!hasAudio) {
      return res.status(400).json({ error: 'No audio file or YouTube URL found' });
    }
    
    // Determine which script to use
    const scriptName = audioType === 'emotional' ? 'process_single_emotional.sh' : 'process_single_project.sh';
    const scriptPath = path.join(SCRIPTS_DIR, scriptName);
    
    // Check if script exists
    try {
      await fs.access(scriptPath);
    } catch (err) {
      return res.status(500).json({ error: `Script ${scriptName} not found` });
    }
    
    // Start the process
    sendProgressUpdate(projectId, 'Starting slideshow processing...', 0);
    
    const process = spawn('/bin/bash', [scriptPath], {
      cwd: projectDir,
      env: {
        ...process.env,
        AUDIO_OFFSET: audioOffset,
        PROJECT_DIR: projectDir,
        AUDIO_TYPE: audioType
      }
    });
    
    activeProcesses.set(projectId, process);
    
    let output = '';
    let errorOutput = '';
    
    process.stdout.on('data', (data) => {
      const text = data.toString();
      output += text;
      
      // Parse progress from script output
      if (text.includes('Processing')) {
        sendProgressUpdate(projectId, text.trim(), 25);
      } else if (text.includes('Converting')) {
        sendProgressUpdate(projectId, text.trim(), 50);
      } else if (text.includes('Building')) {
        sendProgressUpdate(projectId, text.trim(), 75);
      } else if (text.includes('Complete')) {
        sendProgressUpdate(projectId, text.trim(), 100);
      } else {
        sendProgressUpdate(projectId, text.trim());
      }
    });
    
    process.stderr.on('data', (data) => {
      errorOutput += data.toString();
      sendProgressUpdate(projectId, `Error: ${data.toString().trim()}`);
    });
    
    process.on('close', async (code) => {
      activeProcesses.delete(projectId);
      
      if (code === 0) {
        sendProgressUpdate(projectId, 'Slideshow processing completed!', 100);
        
        // Update project metadata
        const metadataPath = path.join(projectDir, 'metadata.json');
        try {
          const metadataContent = await fs.readFile(metadataPath, 'utf-8');
          const metadata = JSON.parse(metadataContent);
          metadata.updatedAt = new Date().toISOString();
          metadata.lastProcessed = new Date().toISOString();
          await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
        } catch (err) {
          // Metadata update failed
        }
      } else {
        sendProgressUpdate(projectId, `Process failed with code ${code}`, -1);
      }
    });
    
    process.on('error', (err) => {
      activeProcesses.delete(projectId);
      sendProgressUpdate(projectId, `Process error: ${err.message}`, -1);
    });
    
    res.json({
      message: 'Slideshow processing started',
      projectId
    });
  } catch (error) {
    console.error('Error starting slideshow process:', error);
    res.status(500).json({ error: 'Failed to start slideshow processing' });
  }
});

// Get process status
router.get('/:projectId/status', (req, res) => {
  const { projectId } = req.params;
  const isProcessing = activeProcesses.has(projectId);
  
  res.json({
    projectId,
    isProcessing,
    status: isProcessing ? 'processing' : 'idle'
  });
});

// Cancel ongoing process
router.post('/:projectId/cancel', (req, res) => {
  const { projectId } = req.params;
  const process = activeProcesses.get(projectId);
  
  if (!process) {
    return res.status(404).json({ error: 'No active process found for this project' });
  }
  
  process.kill('SIGTERM');
  activeProcesses.delete(projectId);
  sendProgressUpdate(projectId, 'Process cancelled by user', -1);
  
  res.json({ message: 'Process cancelled successfully' });
});

// Download generated video
router.get('/:projectId/download', async (req, res) => {
  try {
    const { projectId } = req.params;
    const videoPath = path.join(PROJECTS_DIR, projectId, 'slideshow.mp4');
    
    // Check if video exists
    try {
      await fs.access(videoPath);
    } catch (err) {
      return res.status(404).json({ error: 'Video not found. Please process the slideshow first.' });
    }
    
    // Get project metadata for filename
    let projectName = projectId;
    try {
      const metadataPath = path.join(PROJECTS_DIR, projectId, 'metadata.json');
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      projectName = metadata.name || projectId;
    } catch (err) {
      // Use projectId as fallback
    }
    
    const filename = `${projectName.replace(/[^a-zA-Z0-9]/g, '_')}_slideshow.mp4`;
    
    res.download(videoPath, filename);
  } catch (error) {
    console.error('Error downloading video:', error);
    res.status(500).json({ error: 'Failed to download video' });
  }
});

export default router;