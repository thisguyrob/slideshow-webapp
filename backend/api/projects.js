import express from 'express';
import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECTS_DIR = path.join(__dirname, '../../projects');

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
    const { name } = req.body;
    
    if (!name) {
      return res.status(400).json({ error: 'Project name is required' });
    }
    
    const projectId = `${Date.now()}-${uuidv4().slice(0, 8)}`;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    await fs.mkdir(projectDir, { recursive: true });
    
    const metadata = {
      id: projectId,
      name,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      audioType: 'normal'
    };
    
    await fs.writeFile(
      path.join(projectDir, 'metadata.json'),
      JSON.stringify(metadata, null, 2)
    );
    
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
    
    res.json({
      ...metadata,
      images: images.sort((a, b) => a.name.localeCompare(b.name)),
      audioFile,
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
    
    await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
    
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
    
    // Rename images with new order
    for (let i = 0; i < images.length; i++) {
      const oldPath = path.join(projectDir, images[i]);
      const ext = path.extname(images[i]);
      const newName = `${String(i + 1).padStart(3, '0')}-${images[i]}`;
      const newPath = path.join(projectDir, newName);
      
      try {
        await fs.rename(oldPath, newPath);
      } catch (err) {
        console.error(`Error renaming ${oldPath} to ${newPath}:`, err);
      }
    }
    
    res.json({ message: 'Images reordered successfully' });
  } catch (error) {
    console.error('Error reordering images:', error);
    res.status(500).json({ error: 'Failed to reorder images' });
  }
});

export default router;