import express from 'express';
import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { v4 as uuidv4 } from 'uuid';
import { atomicWriteJSON, atomicUpdateJSON } from '../utils/atomicFileOps.js';

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECTS_DIR = path.join(__dirname, '../projects');

// Ensure projects directory exists
(async () => {
  try {
    await fs.mkdir(PROJECTS_DIR, { recursive: true });
  } catch (err) {
    console.error('Error creating projects directory:', err);
  }
})();

// Get all projects
router.get('/', async (req, res) => {
  try {
    const files = await fs.readdir(PROJECTS_DIR);
    const projects = [];
    
    for (const file of files) {
      const filePath = path.join(PROJECTS_DIR, file);
      const stat = await fs.stat(filePath);
      
      if (stat.isDirectory()) {
        // Check for project metadata
        const metadataPath = path.join(filePath, 'metadata.json');
        let metadata = { name: file };
        
        try {
          const metadataContent = await fs.readFile(metadataPath, 'utf-8');
          metadata = JSON.parse(metadataContent);
        } catch (err) {
          // No metadata file, use defaults
        }
        
        // Check for generated video
        const videoPath = path.join(filePath, 'slideshow.mp4');
        let hasVideo = false;
        try {
          await fs.access(videoPath);
          hasVideo = true;
        } catch (err) {
          // No video file
        }
        
        projects.push({
          id: file,
          name: metadata.name || file,
          type: metadata.type || 'FWI-main',
          createdAt: metadata.createdAt || stat.birthtime,
          updatedAt: metadata.updatedAt || stat.mtime,
          hasVideo,
          audioType: metadata.audioType || 'normal'
        });
      }
    }
    
    res.json(projects.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt)));
  } catch (error) {
    console.error('Error listing projects:', error);
    res.status(500).json({ error: 'Failed to list projects' });
  }
});

// Create a new project
router.post('/', async (req, res) => {
  try {
    const { name, type } = req.body;
    
    if (!name) {
      return res.status(400).json({ error: 'Project name is required' });
    }
    
    const validTypes = ['FWI-main', 'FWI-emotional', 'Scavenger-Hunt'];
    const projectType = validTypes.includes(type) ? type : 'FWI-main';
    
    const projectId = `${Date.now()}-${uuidv4().slice(0, 8)}`;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    await fs.mkdir(projectDir, { recursive: true });
    
    const metadata = {
      id: projectId,
      name,
      type: projectType,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      audioType: 'normal'
    };
    
    await atomicWriteJSON(path.join(projectDir, 'metadata.json'), metadata);
    
    res.json({ ...metadata, hasVideo: false });
  } catch (error) {
    console.error('Error creating project:', error);
    res.status(500).json({ error: 'Failed to create project' });
  }
});

// Get project details
router.get('/:projectId', async (req, res) => {
  try {
    const { projectId } = req.params;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    // Check if project exists
    try {
      await fs.access(projectDir);
    } catch (err) {
      return res.status(404).json({ error: 'Project not found' });
    }
    
    // Read metadata
    const metadataPath = path.join(projectDir, 'metadata.json');
    let metadata = { id: projectId, name: projectId };
    
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      metadata = JSON.parse(metadataContent);
    } catch (err) {
      // No metadata file
    }
    
    // Get project files
    const files = await fs.readdir(projectDir);
    const images = [];
    let audioFile = null;
    let videoFile = null;
    
    for (const file of files) {
      const ext = path.extname(file).toLowerCase();
      
      if (['.jpg', '.jpeg', '.png', '.heic'].includes(ext)) {
        images.push({
          name: file,
          url: `/api/files/${projectId}/${file}`
        });
      } else if (['.mp3', '.wav', '.m4a'].includes(ext)) {
        audioFile = {
          name: file,
          url: `/api/files/${projectId}/${file}`
        };
      } else if (file === 'slideshow.mp4') {
        videoFile = {
          name: file,
          url: `/api/files/${projectId}/${file}`
        };
      }
    }
    
    // Check for audio.txt (YouTube URL)
    let youtubeUrl = null;
    try {
      youtubeUrl = await fs.readFile(path.join(projectDir, 'audio.txt'), 'utf-8');
      youtubeUrl = youtubeUrl.trim();
    } catch (err) {
      // No audio.txt file
    }
    
    // If metadata has audioFile, use that instead of scanning
    if (metadata.audioFile && files.includes(metadata.audioFile)) {
      audioFile = {
        name: metadata.audioFile,
        url: `/api/files/${projectId}/${metadata.audioFile}`
      };
    }
    
    res.json({
      ...metadata,
      images: images.sort((a, b) => a.name.localeCompare(b.name)),
      audio: audioFile ? audioFile.name : null,
      audioFile,
      video: videoFile ? videoFile.name : null,
      videoFile,
      youtubeUrl
    });
  } catch (error) {
    console.error('Error getting project details:', error);
    res.status(500).json({ error: 'Failed to get project details' });
  }
});

// Update project metadata
router.put('/:projectId', async (req, res) => {
  try {
    const { projectId } = req.params;
    const { name, audioType } = req.body;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    // Check if project exists
    try {
      await fs.access(projectDir);
    } catch (err) {
      return res.status(404).json({ error: 'Project not found' });
    }
    
    // Read existing metadata
    const metadataPath = path.join(projectDir, 'metadata.json');
    let metadata = { id: projectId };
    
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      metadata = JSON.parse(metadataContent);
    } catch (err) {
      // No existing metadata
    }
    
    // Update metadata
    if (name !== undefined) metadata.name = name;
    if (audioType !== undefined) metadata.audioType = audioType;
    metadata.updatedAt = new Date().toISOString();
    
    await atomicWriteJSON(metadataPath, metadata);
    
    res.json(metadata);
  } catch (error) {
    console.error('Error updating project:', error);
    res.status(500).json({ error: 'Failed to update project' });
  }
});

// Delete a project
router.delete('/:projectId', async (req, res) => {
  try {
    const { projectId } = req.params;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    // Check if project exists
    try {
      await fs.access(projectDir);
    } catch (err) {
      return res.status(404).json({ error: 'Project not found' });
    }
    
    // Remove project directory
    await fs.rm(projectDir, { recursive: true, force: true });
    
    res.json({ message: 'Project deleted successfully' });
  } catch (error) {
    console.error('Error deleting project:', error);
    res.status(500).json({ error: 'Failed to delete project' });
  }
});

// Reorder images in a project
router.post('/:projectId/reorder', async (req, res) => {
  try {
    const { projectId } = req.params;
    const { images } = req.body;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    if (!Array.isArray(images)) {
      return res.status(400).json({ error: 'Images array is required' });
    }
    
    // Update metadata with new image order
    const metadataPath = path.join(projectDir, 'metadata.json');
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      
      // Create a map of original names to temp video info
      const tempVideoMap = new Map();
      if (metadata.images && Array.isArray(metadata.images)) {
        metadata.images.forEach(img => {
          if (img.originalName && img.tempVideo) {
            tempVideoMap.set(img.originalName, {
              tempVideo: img.tempVideo,
              hash: img.hash,
              uploadedAt: img.uploadedAt
            });
          }
        });
      }
      
      // Rebuild images array in new order
      metadata.images = images.map(imageName => {
        const tempInfo = tempVideoMap.get(imageName);
        if (tempInfo) {
          return {
            originalName: imageName,
            ...tempInfo
          };
        }
        // If no temp video info, just store the name
        return {
          originalName: imageName,
          uploadedAt: new Date().toISOString()
        };
      });
      
      metadata.updatedAt = new Date().toISOString();
      metadata.imageOrder = images; // Also store simple order array
      
      await atomicWriteJSON(metadataPath, metadata);
    } catch (err) {
      console.error('Error updating metadata:', err);
      // If no metadata exists, create it
      const metadata = {
        id: projectId,
        images: images.map(imageName => ({
          originalName: imageName,
          uploadedAt: new Date().toISOString()
        })),
        imageOrder: images,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      await atomicWriteJSON(metadataPath, metadata);
    }
    
    res.json({ message: 'Images reordered successfully' });
  } catch (error) {
    console.error('Error reordering images:', error);
    res.status(500).json({ error: 'Failed to reorder images' });
  }
});

export default router;