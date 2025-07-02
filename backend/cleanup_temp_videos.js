#!/usr/bin/env node
import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECTS_DIR = path.join(__dirname, 'projects');

async function cleanupProject(projectDir) {
  console.log(`Cleaning up project: ${path.basename(projectDir)}`);
  
  try {
    // Read all files in project directory
    const files = await fs.readdir(projectDir);
    const tempVideos = files.filter(f => f.startsWith('temp_') && f.endsWith('.mp4'));
    
    if (tempVideos.length === 0) {
      return { cleaned: 0 };
    }
    
    // Read metadata to get tracked temp videos
    const metadataPath = path.join(projectDir, 'metadata.json');
    let trackedVideos = new Set();
    
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      
      // Collect temp videos from regular images
      if (metadata.images && Array.isArray(metadata.images)) {
        metadata.images.forEach(img => {
          if (img.tempVideo) {
            trackedVideos.add(img.tempVideo);
          }
        });
      }
      
      // Also check slots.json for scavenger hunt projects
      if (metadata.type === 'Scavenger-Hunt') {
        try {
          const slotsPath = path.join(projectDir, 'slots.json');
          const slotsContent = await fs.readFile(slotsPath, 'utf-8');
          const slots = JSON.parse(slotsContent);
          
          slots.forEach(slot => {
            if (slot.tempVideo) {
              trackedVideos.add(slot.tempVideo);
            }
          });
        } catch (err) {
          // No slots.json
        }
      }
    } catch (err) {
      console.log(`  No metadata found, skipping cleanup`);
      return { cleaned: 0 };
    }
    
    // Delete orphaned temp videos
    let cleaned = 0;
    for (const tempVideo of tempVideos) {
      if (!trackedVideos.has(tempVideo)) {
        const videoPath = path.join(projectDir, tempVideo);
        try {
          await fs.unlink(videoPath);
          console.log(`  Deleted orphaned video: ${tempVideo}`);
          cleaned++;
        } catch (err) {
          console.error(`  Failed to delete ${tempVideo}: ${err.message}`);
        }
      }
    }
    
    return { cleaned, total: tempVideos.length, tracked: trackedVideos.size };
    
  } catch (err) {
    console.error(`Error cleaning project ${path.basename(projectDir)}: ${err.message}`);
    return { cleaned: 0, error: err.message };
  }
}

async function cleanupAllProjects() {
  console.log('Starting cleanup of orphaned temp videos...\n');
  
  try {
    const projects = await fs.readdir(PROJECTS_DIR);
    let totalCleaned = 0;
    let totalProjects = 0;
    
    for (const project of projects) {
      const projectPath = path.join(PROJECTS_DIR, project);
      const stat = await fs.stat(projectPath);
      
      if (stat.isDirectory()) {
        totalProjects++;
        const result = await cleanupProject(projectPath);
        totalCleaned += result.cleaned || 0;
        
        if (result.cleaned > 0) {
          console.log(`  Summary: ${result.cleaned} orphaned videos deleted (${result.tracked} tracked, ${result.total} total)\n`);
        }
      }
    }
    
    console.log(`\nCleanup complete!`);
    console.log(`Projects processed: ${totalProjects}`);
    console.log(`Orphaned videos deleted: ${totalCleaned}`);
    
  } catch (err) {
    console.error('Error during cleanup:', err);
    process.exit(1);
  }
}

// Run cleanup
cleanupAllProjects();