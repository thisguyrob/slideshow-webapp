import express from 'express';
import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs/promises';
import { fileURLToPath } from 'url';

const router = express.Router();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECTS_DIR = path.join(__dirname, '../../projects');

// Analyze audio and calculate required images
router.post('/:projectId/analyze', async (req, res) => {
  try {
    const { projectId } = req.params;
    const { audioType = 'normal' } = req.body;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    // Check if project exists
    try {
      await fs.access(projectDir);
    } catch (err) {
      return res.status(404).json({ error: 'Project not found' });
    }
    
    // Find audio file
    const files = await fs.readdir(projectDir);
    let audioFile = null;
    
    for (const file of files) {
      if (/\.(mp3|wav|m4a|aac)$/i.test(file)) {
        audioFile = file;
        break;
      }
    }
    
    if (!audioFile) {
      return res.status(400).json({ error: 'No audio file found in project' });
    }
    
    const audioPath = path.join(projectDir, audioFile);
    
    if (audioType === 'emotional') {
      // For emotional mode, calculate based on crossfade timing
      analyzeEmotionalAudio(audioPath, projectId, res);
    } else {
      // For normal mode, detect beats using madmom
      analyzeBeatAudio(audioPath, projectId, res);
    }
  } catch (error) {
    console.error('Error analyzing audio:', error);
    res.status(500).json({ error: 'Failed to analyze audio' });
  }
});

// Analyze audio for emotional slideshow (crossfade timing)
async function analyzeEmotionalAudio(audioPath, projectId, res) {
  try {
    // Get audio duration using ffprobe
    const ffprobe = spawn('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      audioPath
    ]);
    
    let duration = '';
    
    ffprobe.stdout.on('data', (data) => {
      duration += data.toString();
    });
    
    ffprobe.on('close', async (code) => {
      if (code !== 0) {
        return res.status(500).json({ error: 'Failed to get audio duration' });
      }
      
      const audioDuration = parseFloat(duration.trim());
      
      // Emotional slideshow calculations
      const CROSSFADE_DURATION = 3.0;
      const FADE_IN_DURATION = 2.0;
      const FADE_OUT_DURATION = 3.0;
      
      // Calculate how many images we need
      // Each image needs to be visible for at least the crossfade duration
      const availableTime = audioDuration - FADE_IN_DURATION - FADE_OUT_DURATION;
      
      // Minimum images for smooth flow
      const minImages = 3;
      
      // Calculate based on having each image visible for crossfade + some static time
      const targetImageTime = CROSSFADE_DURATION + 2.0; // Each image visible for 5 seconds total
      let numImages = Math.floor(availableTime / (targetImageTime - CROSSFADE_DURATION));
      
      // Ensure minimum
      numImages = Math.max(numImages, minImages);
      
      // Calculate actual timing
      const totalTransitions = numImages - 1;
      const transitionTime = totalTransitions * CROSSFADE_DURATION;
      const staticTime = availableTime - transitionTime;
      const imageDisplayTime = staticTime / numImages + CROSSFADE_DURATION;
      
      // Update metadata
      const metadataPath = path.join(PROJECTS_DIR, projectId, 'metadata.json');
      try {
        const metadataContent = await fs.readFile(metadataPath, 'utf-8');
        const metadata = JSON.parse(metadataContent);
        metadata.audioAnalysis = {
          type: 'emotional',
          duration: audioDuration,
          requiredImages: numImages,
          imageDisplayTime,
          crossfadeDuration: CROSSFADE_DURATION,
          analyzedAt: new Date().toISOString()
        };
        await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
      } catch (err) {
        // Metadata update failed
      }
      
      res.json({
        type: 'emotional',
        audioDuration,
        requiredImages: numImages,
        imageDisplayTime: parseFloat(imageDisplayTime.toFixed(2)),
        crossfadeDuration: CROSSFADE_DURATION,
        fadeInDuration: FADE_IN_DURATION,
        fadeOutDuration: FADE_OUT_DURATION,
        message: `You need ${numImages} images for this ${Math.floor(audioDuration)}s emotional slideshow`
      });
    });
  } catch (error) {
    console.error('Error analyzing emotional audio:', error);
    res.status(500).json({ error: 'Failed to analyze audio for emotional mode' });
  }
}

// Analyze audio for beat-synced slideshow
async function analyzeBeatAudio(audioPath, projectId, res) {
  try {
    // First, check if Python and madmom are available
    const checkPython = spawn('python3', ['-c', 'import madmom']);
    
    checkPython.on('close', (code) => {
      if (code !== 0) {
        // Madmom not available, fall back to time-based calculation
        fallbackBeatAnalysis(audioPath, projectId, res);
        return;
      }
      
      // Run madmom beat detection
      const beatDetection = spawn('python3', ['-c', `
import madmom
import sys
import json
import subprocess

audio_file = "${audioPath}"

# Get audio duration using ffprobe
duration_cmd = ['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', audio_file]
duration = float(subprocess.check_output(duration_cmd).decode().strip())

# Run beat detection
proc = madmom.features.DBNDownBeatTrackingProcessor(beats_per_bar=[3, 4], fps=100)
act = madmom.features.RNNDownBeatProcessor()(audio_file)
beats = proc(act)

# Get downbeats (where beat_type == 1)
downbeats = [float(beat[0]) for beat in beats if beat[1] == 1]

result = {
    "downbeats": downbeats,
    "total_beats": len(downbeats),
    "duration": duration
}

print(json.dumps(result))
      `]);
      
      let output = '';
      let errorOutput = '';
      
      beatDetection.stdout.on('data', (data) => {
        output += data.toString();
      });
      
      beatDetection.stderr.on('data', (data) => {
        errorOutput += data.toString();
      });
      
      beatDetection.on('close', async (code) => {
        if (code !== 0) {
          // Madmom failed, fall back
          fallbackBeatAnalysis(audioPath, projectId, res);
          return;
        }
        
        try {
          const result = JSON.parse(output.trim());
          const numImages = result.total_beats;
          
          // Update metadata
          const metadataPath = path.join(PROJECTS_DIR, projectId, 'metadata.json');
          try {
            const metadataContent = await fs.readFile(metadataPath, 'utf-8');
            const metadata = JSON.parse(metadataContent);
            metadata.audioAnalysis = {
              type: 'beat-synced',
              duration: result.duration,
              requiredImages: numImages,
              downbeats: result.downbeats,
              analyzedAt: new Date().toISOString()
            };
            await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
          } catch (err) {
            // Metadata update failed
          }
          
          res.json({
            type: 'beat-synced',
            audioDuration: result.duration,
            requiredImages: numImages,
            downbeats: result.downbeats,
            averageBeatInterval: result.duration / numImages,
            message: `You need ${numImages} images for this beat-synced slideshow (one per downbeat)`
          });
        } catch (err) {
          fallbackBeatAnalysis(audioPath, projectId, res);
        }
      });
    });
  } catch (error) {
    fallbackBeatAnalysis(audioPath, projectId, res);
  }
}

// Fallback analysis when madmom is not available
async function fallbackBeatAnalysis(audioPath, projectId, res) {
  try {
    // Get audio duration using ffprobe
    const ffprobe = spawn('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      audioPath
    ]);
    
    let duration = '';
    
    ffprobe.stdout.on('data', (data) => {
      duration += data.toString();
    });
    
    ffprobe.on('close', async (code) => {
      if (code !== 0) {
        return res.status(500).json({ error: 'Failed to get audio duration' });
      }
      
      const audioDuration = parseFloat(duration.trim());
      
      // Estimate beats: assume 120 BPM (2 beats per second)
      // and images change every 4 beats (every 2 seconds)
      const estimatedBPM = 120;
      const beatsPerImage = 4;
      const secondsPerImage = (60 / estimatedBPM) * beatsPerImage;
      const numImages = Math.ceil(audioDuration / secondsPerImage);
      
      // Update metadata
      const metadataPath = path.join(PROJECTS_DIR, projectId, 'metadata.json');
      try {
        const metadataContent = await fs.readFile(metadataPath, 'utf-8');
        const metadata = JSON.parse(metadataContent);
        metadata.audioAnalysis = {
          type: 'time-based',
          duration: audioDuration,
          requiredImages: numImages,
          secondsPerImage,
          estimatedBPM,
          analyzedAt: new Date().toISOString()
        };
        await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
      } catch (err) {
        // Metadata update failed
      }
      
      res.json({
        type: 'time-based',
        audioDuration,
        requiredImages: numImages,
        secondsPerImage: parseFloat(secondsPerImage.toFixed(2)),
        estimatedBPM,
        message: `You need approximately ${numImages} images for this ${Math.floor(audioDuration)}s slideshow (estimated without beat detection)`,
        note: 'Install Python with madmom for accurate beat detection'
      });
    });
  } catch (error) {
    console.error('Error in fallback analysis:', error);
    res.status(500).json({ error: 'Failed to analyze audio' });
  }
}

export default router;