import express from 'express';
import multer from 'multer';
import path from 'path';
import { promises as fs } from 'fs';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';
import { promisify } from 'util';
const execFile = promisify(spawn);

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECTS_DIR = path.join(__dirname, '../../projects');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const projectId = req.params.projectId;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    try {
      await fs.access(projectDir);
      cb(null, projectDir);
    } catch (err) {
      cb(new Error('Project not found'));
    }
  },
  filename: (req, file, cb) => {
    // Keep original filename but sanitize it
    const sanitized = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    cb(null, sanitized);
  }
});

const upload = multer({
  storage,
  limits: {
    fileSize: 100 * 1024 * 1024 // 100MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedImageTypes = /jpeg|jpg|png|heic|heif/;
    const allowedAudioTypes = /mp3|wav|m4a|aac/;
    
    const extname = allowedImageTypes.test(path.extname(file.originalname).toLowerCase()) ||
                   allowedAudioTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedImageTypes.test(file.mimetype) ||
                    allowedAudioTypes.test(file.mimetype);
    
    if (extname && mimetype) {
      return cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only images (JPEG, PNG, HEIC) and audio (MP3, WAV, M4A) are allowed.'));
    }
  }
});

// Upload images to a project
router.post('/:projectId/images', upload.array('images', 100), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'No files uploaded' });
    }
    
    const uploadedFiles = req.files.map(file => ({
      name: file.filename,
      size: file.size,
      url: `/api/files/${req.params.projectId}/${file.filename}`
    }));
    
    // Update project metadata
    const metadataPath = path.join(PROJECTS_DIR, req.params.projectId, 'metadata.json');
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      metadata.updatedAt = new Date().toISOString();
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
    } catch (err) {
      // Metadata update failed, but files are uploaded
    }
    
    res.json({
      message: 'Images uploaded successfully',
      files: uploadedFiles
    });
  } catch (error) {
    console.error('Error uploading images:', error);
    res.status(500).json({ error: error.message || 'Failed to upload images' });
  }
});

// Upload audio file to a project
router.post('/:projectId/audio', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file uploaded' });
    }
    
    const uploadedFile = {
      name: req.file.filename,
      size: req.file.size,
      url: `/api/files/${req.params.projectId}/${req.file.filename}`
    };
    
    // Update project metadata
    const metadataPath = path.join(PROJECTS_DIR, req.params.projectId, 'metadata.json');
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      metadata.updatedAt = new Date().toISOString();
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
    } catch (err) {
      // Metadata update failed, but file is uploaded
    }
    
    res.json({
      message: 'Audio uploaded successfully',
      file: uploadedFile
    });
  } catch (error) {
    console.error('Error uploading audio:', error);
    res.status(500).json({ error: error.message || 'Failed to upload audio' });
  }
});

// Set YouTube URL for a project (saves URL only)
router.post('/:projectId/youtube', async (req, res) => {
  try {
    const { projectId } = req.params;
    const { url } = req.body;
    
    if (!url) {
      return res.status(400).json({ error: 'YouTube URL is required' });
    }
    
    // Validate YouTube URL
    const youtubeRegex = /^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be|music\.youtube\.com)\/.+$/;
    if (!youtubeRegex.test(url)) {
      return res.status(400).json({ error: 'Invalid YouTube URL' });
    }
    
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    // Check if project exists
    try {
      await fs.access(projectDir);
    } catch (err) {
      return res.status(404).json({ error: 'Project not found' });
    }
    
    // Write YouTube URL to audio.txt
    await fs.writeFile(path.join(projectDir, 'audio.txt'), url);
    
    // Update project metadata
    const metadataPath = path.join(projectDir, 'metadata.json');
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      metadata.updatedAt = new Date().toISOString();
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
    } catch (err) {
      // Metadata update failed, but URL is saved
    }
    
    res.json({
      message: 'YouTube URL saved successfully',
      url
    });
  } catch (error) {
    console.error('Error saving YouTube URL:', error);
    res.status(500).json({ error: 'Failed to save YouTube URL' });
  }
});

// Download audio from YouTube URL
router.post('/:projectId/youtube-download', async (req, res) => {
  try {
    const { projectId } = req.params;
    const { url, startTime, duration } = req.body;
    
    if (!url) {
      return res.status(400).json({ error: 'YouTube URL is required' });
    }
    
    // Validate YouTube URL
    const youtubeRegex = /^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be|music\.youtube\.com)\/.+$/;
    if (!youtubeRegex.test(url)) {
      return res.status(400).json({ error: 'Invalid YouTube URL' });
    }
    
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    // Check if project exists
    try {
      await fs.access(projectDir);
    } catch (err) {
      return res.status(404).json({ error: 'Project not found' });
    }
    
    // Save URL to audio.txt
    await fs.writeFile(path.join(projectDir, 'audio.txt'), url);
    
    // Download audio using yt-dlp
    const outputPath = path.join(projectDir, 'audio.mp3');
    
    // Build yt-dlp arguments
    const ytdlpArgs = [
      '-x',                    // Extract audio only
      '--audio-format', 'mp3', // Convert to mp3
      '--audio-quality', '0',  // Best quality
      '-o', outputPath         // Output path
    ];
    
    // Add time-based extraction if provided
    if (startTime || duration) {
      const ffmpegArgs = [];
      if (startTime) {
        ffmpegArgs.push(`-ss ${startTime}`);
      }
      if (duration) {
        ffmpegArgs.push(`-t ${duration}`);
      }
      ytdlpArgs.push('--postprocessor-args', `ffmpeg:${ffmpegArgs.join(' ')}`);
    }
    
    ytdlpArgs.push(url); // YouTube URL at the end
    
    return new Promise((resolve) => {
      const ytdlp = spawn('yt-dlp', ytdlpArgs, {
        cwd: projectDir
      });
      
      let output = '';
      let errorOutput = '';
      
      ytdlp.stdout.on('data', (data) => {
        output += data.toString();
      });
      
      ytdlp.stderr.on('data', (data) => {
        errorOutput += data.toString();
      });
      
      ytdlp.on('close', async (code) => {
        if (code === 0) {
          // Update project metadata
          const metadataPath = path.join(projectDir, 'metadata.json');
          try {
            const metadataContent = await fs.readFile(metadataPath, 'utf-8');
            const metadata = JSON.parse(metadataContent);
            metadata.updatedAt = new Date().toISOString();
            
            // Store audio offset if provided (for slideshow processing)
            if (startTime) {
              metadata.audioOffset = startTime;
            }
            
            await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
          } catch (err) {
            // Metadata update failed, but audio is downloaded
          }
          
          res.json({
            message: 'Audio downloaded successfully',
            file: {
              name: 'audio.mp3',
              url: `/api/files/${projectId}/audio.mp3`
            },
            audioOffset: startTime || '00:00'
          });
          resolve();
        } else {
          res.status(500).json({ 
            error: 'Failed to download audio from YouTube',
            details: errorOutput || output
          });
          resolve();
        }
      });
      
      ytdlp.on('error', (err) => {
        res.status(500).json({ 
          error: 'Failed to start yt-dlp',
          details: err.message
        });
        resolve();
      });
    });
  } catch (error) {
    console.error('Error downloading from YouTube:', error);
    res.status(500).json({ error: 'Failed to download audio from YouTube' });
  }
});

// Delete a file from a project
router.delete('/:projectId/files/:filename', async (req, res) => {
  try {
    const { projectId, filename } = req.params;
    const filePath = path.join(PROJECTS_DIR, projectId, filename);
    
    // Check if file exists
    try {
      await fs.access(filePath);
    } catch (err) {
      return res.status(404).json({ error: 'File not found' });
    }
    
    await fs.unlink(filePath);
    
    // Update project metadata
    const metadataPath = path.join(PROJECTS_DIR, projectId, 'metadata.json');
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      metadata.updatedAt = new Date().toISOString();
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
    } catch (err) {
      // Metadata update failed, but file is deleted
    }
    
    res.json({ message: 'File deleted successfully' });
  } catch (error) {
    console.error('Error deleting file:', error);
    res.status(500).json({ error: 'Failed to delete file' });
  }
});

export default router;