#!/usr/bin/env node

import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECTS_DIR = path.join(__dirname, 'projects');

async function fixSlotsUrls() {
  console.log('Fixing slots.json URLs in all projects...\n');
  
  try {
    // Get all project directories
    const projects = await fs.readdir(PROJECTS_DIR);
    
    for (const projectId of projects) {
      const projectPath = path.join(PROJECTS_DIR, projectId);
      const stats = await fs.stat(projectPath);
      
      if (!stats.isDirectory()) continue;
      
      const slotsPath = path.join(projectPath, 'slots.json');
      
      try {
        // Check if slots.json exists
        await fs.access(slotsPath);
        
        // Read slots data
        const slotsContent = await fs.readFile(slotsPath, 'utf-8');
        const slots = JSON.parse(slotsContent);
        
        // Check if any slots need fixing
        let needsUpdate = false;
        const updatedSlots = slots.map(slot => {
          if (slot.image && slot.filename) {
            const correctUrl = `/api/files/${projectId}/${slot.filename}`;
            if (slot.image !== correctUrl) {
              needsUpdate = true;
              console.log(`  Fixing slot ${slot.id}: ${slot.image} → ${correctUrl}`);
              slot.image = correctUrl;
            }
          }
          return slot;
        });
        
        if (needsUpdate) {
          // Write updated slots back to file
          await fs.writeFile(slotsPath, JSON.stringify(updatedSlots, null, 2));
          console.log(`✓ Fixed ${projectId}/slots.json\n`);
        } else {
          console.log(`✓ ${projectId}/slots.json already has correct URLs\n`);
        }
        
      } catch (err) {
        if (err.code !== 'ENOENT') {
          console.error(`✗ Error processing ${projectId}/slots.json:`, err.message);
        }
        // slots.json doesn't exist, skip
      }
    }
    
    console.log('Done!');
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

// Run the migration
fixSlotsUrls();