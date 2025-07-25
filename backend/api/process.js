import express from 'express';
import { spawn } from 'child_process';
import path from 'path';
import { promises as fs } from 'fs';
import { fileURLToPath } from 'url';
// wss will be set by the main server
let wss = null;

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECTS_DIR = path.join(__dirname, '../projects');
const SCRIPTS_DIR = path.join(__dirname, '..');

// Active processes map
const activeProcesses = new Map();

// Send progress update to WebSocket clients
function sendProgressUpdate(projectId, message, progress = null, status = 'processing') {
  if (!wss || !wss.clients) return;
  
  const update = {
    type: 'progress',
    projectId,
    message,
    progress,
    status,
    timestamp: new Date().toISOString()
  };
  
  wss.clients.forEach((client) => {
    if (client.readyState === 1) { // WebSocket.OPEN
      client.send(JSON.stringify(update));
    }
  });
}

// Test route
router.get('/test', (req, res) => {
  console.log('Test route hit');
  res.json({ message: 'Process routes working' });
});

// Process slideshow for a project
router.post('/:projectId/process', async (req, res) => {
  console.log('Process route hit with projectId:', req.params.projectId);
  try {
    const { projectId } = req.params;
    let { audioOffset = '00:00', audioType = 'normal' } = req.body;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    // Check for saved audio offset in metadata
    let projectType = null;
    try {
      const metadataPath = path.join(projectDir, 'metadata.json');
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      
      // Get project type
      projectType = metadata.type;
      
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
    console.log(`Checking project directory: ${projectDir}`);
    try {
      await fs.access(projectDir);
      console.log(`Project directory exists: ${projectDir}`);
    } catch (err) {
      console.log(`Project directory not found: ${projectDir}`, err);
      return res.status(404).json({ error: 'Project not found' });
    }
    
    // Check if process is already running
    if (activeProcesses.has(projectId)) {
      return res.status(400).json({ error: 'Process already running for this project' });
    }
    
    // Check for required files
    console.log(`Reading project directory files...`);
    const files = await fs.readdir(projectDir);
    console.log(`Found files:`, files);
    const hasImages = files.some(f => /\.(jpg|jpeg|png|heic)$/i.test(f));
    const hasAudio = files.some(f => /\.(mp3|wav|m4a)$/i.test(f)) || 
                    files.includes('audio.txt');
    
    console.log(`Has images: ${hasImages}, Has audio: ${hasAudio}`);
    
    if (!hasImages) {
      console.log(`No images found in project`);
      return res.status(400).json({ error: 'No images found in project' });
    }
    
    if (!hasAudio) {
      console.log(`No audio found in project`);
      return res.status(400).json({ error: 'No audio file or YouTube URL found' });
    }
    
    // Check if we have pre-generated videos
    let hasPreGeneratedVideos = false;
    try {
      const metadataPath = path.join(projectDir, 'metadata.json');
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      
      if (projectType === 'Scavenger-Hunt') {
        // For scavenger hunt, check slots.json
        const slotsPath = path.join(projectDir, 'slots.json');
        try {
          const slotsContent = await fs.readFile(slotsPath, 'utf-8');
          const slots = JSON.parse(slotsContent);
          // Only use fast processing if ALL slots with images have tempVideo data
          const slotsWithImages = slots.filter(slot => slot.filename);
          hasPreGeneratedVideos = slotsWithImages.length > 0 && 
                                 slotsWithImages.every(slot => slot.tempVideo && files.includes(slot.tempVideo));
        } catch (err) {
          // No slots.json or error reading it
        }
      } else {
        // For regular projects, check metadata.images
        hasPreGeneratedVideos = metadata.images && 
                               metadata.images.length > 0 && 
                               metadata.images.some(img => img.tempVideo && files.includes(img.tempVideo));
      }
    } catch (err) {
      // No metadata or error reading it
    }
    
    // Determine which script to use
    console.log(`Project type: ${projectType}, Audio type: ${audioType}, Has pre-generated videos: ${hasPreGeneratedVideos}`);
    let scriptName;
    if (projectType === 'Scavenger-Hunt') {
      scriptName = hasPreGeneratedVideos ? 'scavenger_hunt_slideshow_builder.sh' : 'process_scavenger_hunt.sh';
    } else if (audioType === 'emotional') {
      scriptName = hasPreGeneratedVideos ? 'process_single_emotional_fast.sh' : 'process_single_emotional.sh';
    } else {
      scriptName = hasPreGeneratedVideos ? 'process_single_project_fast.sh' : 'process_single_project.sh';
    }
    const scriptPath = path.join(SCRIPTS_DIR, scriptName);
    console.log(`Selected script: ${scriptName}, Path: ${scriptPath}`);
    
    // Check if script exists
    try {
      await fs.access(scriptPath);
      console.log(`Script exists: ${scriptPath}`);
    } catch (err) {
      console.log(`Script not found: ${scriptPath}`, err);
      return res.status(500).json({ error: `Script ${scriptName} not found` });
    }
    
    // Start the process
    console.log(`Starting slideshow processing...`);
    sendProgressUpdate(projectId, 'Starting slideshow processing...', 0);
    
    console.log(`Spawning process: /bin/bash ${scriptPath} in ${projectDir}`);
    const childProcess = spawn('/bin/bash', [scriptPath], {
      cwd: projectDir,
      env: {
        ...process.env,
        AUDIO_OFFSET: audioOffset,
        PROJECT_DIR: projectDir,
        AUDIO_TYPE: audioType
      }
    });
    
    console.log(`Process spawned with PID: ${childProcess.pid}`);
    activeProcesses.set(projectId, childProcess);
    
    let output = '';
    let errorOutput = '';
    
    childProcess.stdout.on('data', (data) => {
      const text = data.toString();
      output += text;
      console.log(`[${projectId}] Script output:`, text.trim());
      
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
    
    childProcess.stderr.on('data', (data) => {
      errorOutput += data.toString();
      console.error(`[${projectId}] Script error:`, data.toString().trim());
      sendProgressUpdate(projectId, `Error: ${data.toString().trim()}`);
    });
    
    childProcess.on('close', async (code) => {
      activeProcesses.delete(projectId);
      
      if (code === 0) {
        sendProgressUpdate(projectId, 'Slideshow processing completed!', 100, 'completed');
        
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
        sendProgressUpdate(projectId, `Process failed with code ${code}`, -1, 'failed');
      }
    });
    
    childProcess.on('error', (err) => {
      activeProcesses.delete(projectId);
      sendProgressUpdate(projectId, `Process error: ${err.message}`, -1, 'failed');
    });
    
    res.json({
      message: 'Slideshow processing started',
      projectId,
      status: 'processing'
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
  const childProcess = activeProcesses.get(projectId);
  
  if (!childProcess) {
    return res.status(404).json({ error: 'No active process found for this project' });
  }
  
  childProcess.kill('SIGTERM');
  activeProcesses.delete(projectId);
  sendProgressUpdate(projectId, 'Process cancelled by user', -1, 'cancelled');
  
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

// Function to set the WebSocket server instance
export function setWebSocketServer(wssInstance) {
  wss = wssInstance;
}

export default router;