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
const PROJECTS_DIR = path.join(__dirname, '../projects');

// Function to convert HEIC/HEIF files to JPG using ImageMagick
async function convertHeicToJpg(inputPath, outputPath) {
  return new Promise((resolve, reject) => {
    const convert = spawn('convert', [inputPath, outputPath]);
    
    let errorOutput = '';
    
    convert.stderr.on('data', (data) => {
      errorOutput += data.toString();
    });
    
    convert.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`ImageMagick conversion failed: ${errorOutput}`));
      }
    });
    
    convert.on('error', (err) => {
      reject(new Error(`Failed to start ImageMagick: ${err.message}`));
    });
  });
}

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const projectId = req.params.projectId;
    console.log(`[Upload] Checking project: ${projectId}`);
    const projectDir = path.join(PROJECTS_DIR, projectId);
    console.log(`[Upload] Project directory: ${projectDir}`);
    
    try {
      await fs.access(projectDir);
      console.log(`[Upload] Project directory exists`);
      cb(null, projectDir);
    } catch (err) {
      console.error(`[Upload] Project directory not found: ${err.message}`);
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
router.post('/:projectId/images', (req, res, next) => {
  console.log(`[Upload] Route hit: POST /${req.params.projectId}/images`);
  console.log(`[Upload] Files in request:`, req.files?.length || 0);
  next();
}, upload.array('images', 100), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: 'No files uploaded' });
    }
    
    // Process uploaded files and convert HEIC/HEIF to JPG
    const uploadedFiles = [];
    
    for (const file of req.files) {
      const fileExt = path.extname(file.filename).toLowerCase();
      let processedFile = {
        name: file.filename,
        size: file.size,
        url: `/api/files/${req.params.projectId}/${file.filename}`
      };
      
      // Convert HEIC/HEIF files to JPG
      if (fileExt === '.heic' || fileExt === '.heif') {
        try {
          const originalPath = file.path;
          const jpgFilename = file.filename.replace(/\.(heic|heif)$/i, '.jpg');
          const jpgPath = path.join(path.dirname(originalPath), jpgFilename);
          
          console.log(`Converting ${file.filename} to ${jpgFilename}...`);
          await convertHeicToJpg(originalPath, jpgPath);
          
          // Get the size of the converted file
          const jpgStats = await fs.stat(jpgPath);
          
          // Remove the original HEIC file
          await fs.unlink(originalPath);
          
          processedFile = {
            name: jpgFilename,
            size: jpgStats.size,
            url: `/api/files/${req.params.projectId}/${jpgFilename}`,
            converted: true,
            originalName: file.filename
          };
          
          console.log(`Successfully converted ${file.filename} to ${jpgFilename}`);
        } catch (conversionError) {
          console.error(`Failed to convert ${file.filename}:`, conversionError);
          // Keep the original HEIC file if conversion fails
          processedFile.conversionError = conversionError.message;
        }
      }
      
      uploadedFiles.push(processedFile);
    }
    
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
    
    const { projectId } = req.params;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    const uploadedFile = {
      name: req.file.filename,
      size: req.file.size,
      url: `/api/files/${projectId}/${req.file.filename}`
    };
    
    console.log(`[${projectId}] Audio file uploaded: ${req.file.filename}`);
    console.log(`[${projectId}] Starting madmom downbeat detection...`);
    
    // Run madmom downbeat detection on uploaded audio
    const audioFile = req.file.filename;
    const outputFile = 'downbeats.json';
    
    // Try multiple madmom approaches with compatibility fixes
    let python;
    
    // Method 1: Try simple beat detector with conda environment
    const simpleDetector = path.join(__dirname, '../simple_beat_detector.py');
    
    try {
      python = spawn('conda', ['run', '-n', 'madmom', 'python', simpleDetector, audioFile, outputFile], {
        cwd: projectDir
      });
      console.log(`[${projectId}] Using simple beat detector with conda madmom environment`);
    } catch (error) {
      console.log(`[${projectId}] Simple detector failed, trying madmom compatibility fix`);
      
      // Method 2: Try Python 3.10+ madmom compatibility fix
      try {
        const compatScript = path.join(__dirname, '../madmom_py310_fix.py');
        python = spawn('python3', [compatScript, audioFile, outputFile], {
          cwd: projectDir
        });
        console.log(`[${projectId}] Using Python 3.10+ compatibility fix for madmom`);
      } catch (error2) {
        console.log(`[${projectId}] Madmom compatibility script failed, trying python3.9`);
        
        // Method 3: Try python3.9 directly
        try {
          const madmomScript = path.join(__dirname, '../madmom_processor.py');
          python = spawn('python3.9', [madmomScript, audioFile, outputFile], {
            cwd: projectDir
          });
          console.log(`[${projectId}] Using python3.9 for madmom processing`);
        } catch (error3) {
          console.log(`[${projectId}] python3.9 not available, trying wrapper script`);
          
          // Method 4: Fallback to wrapper script
          const wrapperScript = path.join(__dirname, '../run_madmom.sh');
          python = spawn('bash', [wrapperScript, audioFile, outputFile, projectDir], {
            cwd: projectDir
          });
        }
      }
    }
    
    let pythonOutput = '';
    let pythonError = '';
    
    python.stdout.on('data', (data) => {
      const text = data.toString();
      pythonOutput += text;
      console.log(`[${projectId}] madmom: ${text.trim()}`);
    });
    
    python.stderr.on('data', (data) => {
      const text = data.toString();
      pythonError += text;
      console.log(`[${projectId}] madmom stderr: ${text.trim()}`);
    });
    
    python.on('close', async (pythonCode) => {
      // Read madmom results from JSON file
      let madmomResult = null;
      try {
        const resultPath = path.join(projectDir, 'downbeats.json');
        const resultContent = await fs.readFile(resultPath, 'utf-8');
        madmomResult = JSON.parse(resultContent);
      } catch (err) {
        console.log(`[${projectId}] Could not read madmom results: ${err.message}`);
      }
      
      const madmomSuccess = madmomResult && madmomResult.success;
      
      if (madmomSuccess) {
        console.log(`[${projectId}] Madmom processing completed: Found ${madmomResult.count} downbeats`);
      } else {
        console.log(`[${projectId}] Madmom processing failed or unavailable`);
      }
      
      // Update project metadata with madmom results
      const metadataPath = path.join(projectDir, 'metadata.json');
      try {
        const metadataContent = await fs.readFile(metadataPath, 'utf-8');
        const metadata = JSON.parse(metadataContent);
        metadata.updatedAt = new Date().toISOString();
        
        if (madmomSuccess) {
          metadata.downbeats = madmomResult.downbeats;
          metadata.downbeatCount = madmomResult.count;
        }
        
        await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
      } catch (err) {
        console.log(`[${projectId}] Warning: Could not update metadata`);
      }
    });
    
    python.on('error', (err) => {
      console.log(`[${projectId}] Madmom processing error: ${err.message}`);
    });
    
    // Update project metadata
    const metadataPath = path.join(PROJECTS_DIR, projectId, 'metadata.json');
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      metadata.updatedAt = new Date().toISOString();
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
    } catch (err) {
      // Metadata update failed, but file is uploaded
    }
    
    res.json({
      message: 'Audio uploaded successfully. Downbeat detection running in background.',
      file: uploadedFile,
      processing: 'Madmom downbeat detection started'
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

// Download audio from YouTube URL with full processing pipeline
router.post('/:projectId/youtube-download', async (req, res) => {
  try {
    const { projectId } = req.params;
    const { url, startTime = '0:00' } = req.body;
    
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
    
    console.log(`[${projectId}] Starting YouTube audio processing pipeline`);
    console.log(`[${projectId}] YouTube URL: ${url}`);
    console.log(`[${projectId}] Start time: ${startTime}`);
    
    // Download audio using yt-dlp
    const outputPath = path.join(projectDir, 'song.mp3');
    
    console.log(`[${projectId}] Step 1: Downloading audio with yt-dlp...`);
    
    // Build yt-dlp arguments
    const ytdlpArgs = [
      '--extract-audio',
      '--audio-format', 'mp3',
      '--audio-quality', '0',
      '-o', 'song.%(ext)s'
    ];
    
    // Add start time trimming if not default
    if (startTime && startTime !== '0:00' && startTime !== '00:00') {
      ytdlpArgs.push('--postprocessor-args', `ffmpeg:-ss ${startTime}`);
    }
    
    ytdlpArgs.push(url);
    
    return new Promise((resolve) => {
      const ytdlp = spawn('yt-dlp', ytdlpArgs, {
        cwd: projectDir
      });
      
      let output = '';
      let errorOutput = '';
      
      ytdlp.stdout.on('data', (data) => {
        const text = data.toString();
        output += text;
        console.log(`[${projectId}] yt-dlp: ${text.trim()}`);
      });
      
      ytdlp.stderr.on('data', (data) => {
        const text = data.toString();
        errorOutput += text;
        console.log(`[${projectId}] yt-dlp stderr: ${text.trim()}`);
      });
      
      ytdlp.on('close', async (code) => {
        if (code === 0) {
          console.log(`[${projectId}] Step 1 completed: Audio downloaded successfully`);
          
          // Step 2: Convert to MP3 using ffmpeg if needed
          console.log(`[${projectId}] Step 2: Ensuring MP3 format with ffmpeg...`);
          
          const ffmpegArgs = [
            '-i', 'song.mp3',
            '-acodec', 'mp3',
            '-ab', '320k',
            '-y', // Overwrite output file
            'song_converted.mp3'
          ];
          
          const ffmpeg = spawn('ffmpeg', ffmpegArgs, {
            cwd: projectDir
          });
          
          let ffmpegOutput = '';
          let ffmpegError = '';
          
          ffmpeg.stdout.on('data', (data) => {
            const text = data.toString();
            ffmpegOutput += text;
            console.log(`[${projectId}] ffmpeg: ${text.trim()}`);
          });
          
          ffmpeg.stderr.on('data', (data) => {
            const text = data.toString();
            ffmpegError += text;
            console.log(`[${projectId}] ffmpeg stderr: ${text.trim()}`);
          });
          
          ffmpeg.on('close', async (ffmpegCode) => {
            if (ffmpegCode === 0) {
              console.log(`[${projectId}] Step 2 completed: Audio converted to MP3`);
              
              // Replace original with converted version
              try {
                await fs.rename(path.join(projectDir, 'song_converted.mp3'), path.join(projectDir, 'song.mp3'));
              } catch (err) {
                console.log(`[${projectId}] Note: Could not rename converted file, using original`);
              }
              
              // Check if this is a Scavenger Hunt project
              const metadataPath = path.join(projectDir, 'metadata.json');
              let isScavengerHunt = false;
              try {
                const metadataContent = await fs.readFile(metadataPath, 'utf-8');
                const metadata = JSON.parse(metadataContent);
                isScavengerHunt = metadata.type === 'Scavenger-Hunt';
              } catch (err) {
                console.log(`[${projectId}] Could not read metadata to check project type`);
              }
              
              if (isScavengerHunt) {
                // For Scavenger Hunt: Check audio length and trim to 73 seconds from start time
                console.log(`[${projectId}] Step 3: Checking audio length for Scavenger Hunt...`);
                
                // First, get the duration of the downloaded audio
                const ffprobe = spawn('ffprobe', [
                  '-i', 'song.mp3',
                  '-show_entries', 'format=duration',
                  '-v', 'quiet',
                  '-of', 'csv=p=0'
                ], {
                  cwd: projectDir
                });
                
                let durationOutput = '';
                let durationError = '';
                
                ffprobe.stdout.on('data', (data) => {
                  durationOutput += data.toString();
                });
                
                ffprobe.stderr.on('data', (data) => {
                  durationError += data.toString();
                });
                
                ffprobe.on('close', async (probeCode) => {
                  if (probeCode === 0) {
                    const duration = parseFloat(durationOutput.trim());
                    console.log(`[${projectId}] Audio duration: ${duration} seconds`);
                    
                    // Check if audio is long enough (minimum 73 seconds for final trimmed audio)
                    if (duration < 73) {
                      console.log(`[${projectId}] Error: Audio too short (${duration}s). Need at least 73 seconds for Scavenger Hunt.`);
                      
                      // Parse the original video duration from metadata if available
                      let originalDuration = null;
                      try {
                        const metadataContent = await fs.readFile(metadataPath, 'utf-8');
                        const metadata = JSON.parse(metadataContent);
                        // We don't have original duration stored, so we'll work with what we have
                      } catch (err) {
                        // Ignore metadata errors
                      }
                      
                      // Parse start time to get the offset in seconds
                      let startTimeSeconds = 0;
                      if (startTime && startTime !== '0:00') {
                        const timeParts = startTime.split(':').map(Number);
                        if (timeParts.length === 2) {
                          startTimeSeconds = timeParts[0] * 60 + timeParts[1]; // mm:ss
                        } else if (timeParts.length === 3) {
                          startTimeSeconds = timeParts[0] * 3600 + timeParts[1] * 60 + timeParts[2]; // hh:mm:ss
                        }
                      }
                      
                      // Calculate the original video length
                      const estimatedOriginalDuration = duration + startTimeSeconds;
                      
                      let errorMessage;
                      if (estimatedOriginalDuration < 73) {
                        // Video is too short entirely
                        errorMessage = `This video is too short for Scavenger Hunt. The video is only ${Math.round(estimatedOriginalDuration)} seconds long, but we need at least 73 seconds. Please choose a different video.`;
                      } else {
                        // Video is long enough, but start time is too late
                        const maxStartTimeSeconds = estimatedOriginalDuration - 73;
                        const maxStartMinutes = Math.floor(maxStartTimeSeconds / 60);
                        const maxStartSecondsRemainder = Math.floor(maxStartTimeSeconds % 60);
                        const maxStartTime = `${maxStartMinutes}:${maxStartSecondsRemainder.toString().padStart(2, '0')}`;
                        
                        errorMessage = `Start time too late for Scavenger Hunt. With your current start time (${startTime}), only ${Math.round(duration)} seconds remain. Try a start time of ${maxStartTime} or earlier.`;
                      }
                      
                      // Clean up the invalid audio file so next attempt can download fresh
                      try {
                        await fs.unlink(path.join(projectDir, 'song.mp3'));
                        console.log(`[${projectId}] Cleaned up invalid audio file`);
                      } catch (unlinkErr) {
                        console.log(`[${projectId}] Could not clean up audio file: ${unlinkErr.message}`);
                      }
                      
                      res.status(400).json({ 
                        error: errorMessage,
                        audioDuration: Math.round(duration),
                        minimumRequired: 73
                      });
                      resolve();
                      return;
                    }
                    
                    console.log(`[${projectId}] Audio length OK (${duration}s >= 73s). Trimming to 73 seconds...`);
                    
                    // For Scavenger Hunt: yt-dlp already applied the start time,
                    // so we just need to trim to 73 seconds from the beginning
                    const trimArgs = [
                      '-i', 'song.mp3',
                      '-t', '73',
                      '-acodec', 'mp3',
                      '-ab', '320k',
                      '-y',
                      'song_trimmed.mp3'
                    ];
                
                    const trimFfmpeg = spawn('ffmpeg', trimArgs, {
                      cwd: projectDir
                    });
                
                let trimOutput = '';
                let trimError = '';
                
                trimFfmpeg.stdout.on('data', (data) => {
                  const text = data.toString();
                  trimOutput += text;
                  console.log(`[${projectId}] ffmpeg trim: ${text.trim()}`);
                });
                
                trimFfmpeg.stderr.on('data', (data) => {
                  const text = data.toString();
                  trimError += text;
                  console.log(`[${projectId}] ffmpeg trim stderr: ${text.trim()}`);
                });
                
                trimFfmpeg.on('close', async (trimCode) => {
                  if (trimCode === 0) {
                    console.log(`[${projectId}] Step 3 completed: Audio trimmed to 73 seconds`);
                    
                    // Replace original with trimmed version
                    try {
                      await fs.rename(path.join(projectDir, 'song_trimmed.mp3'), path.join(projectDir, 'song.mp3'));
                    } catch (err) {
                      console.log(`[${projectId}] Error: Could not rename trimmed file`);
                    }
                    
                    // Update metadata
                    try {
                      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
                      const metadata = JSON.parse(metadataContent);
                      metadata.updatedAt = new Date().toISOString();
                      metadata.audioOffset = startTime;
                      metadata.audioTrimmed = true;
                      metadata.audioDuration = 73;
                      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
                    } catch (err) {
                      console.log(`[${projectId}] Warning: Could not update metadata`);
                    }
                    
                    res.json({
                      message: 'Audio downloaded and trimmed successfully for Scavenger Hunt',
                      file: {
                        name: 'song.mp3',
                        url: `/api/files/${projectId}/song.mp3`
                      },
                      audioOffset: startTime,
                      audioTrimmed: true,
                      audioDuration: 73
                    });
                  } else {
                    console.log(`[${projectId}] Step 3 failed: Audio trimming failed`);
                    res.status(500).json({ error: 'Failed to trim audio' });
                  }
                  resolve();
                  });
                  
                  trimFfmpeg.on('error', (err) => {
                    console.log(`[${projectId}] Step 3 error: ${err.message}`);
                    res.status(500).json({ 
                      error: 'Failed to start audio trimming',
                      details: err.message
                    });
                    resolve();
                  });
                  
                } else {
                  console.log(`[${projectId}] Error: Could not determine audio duration`);
                  res.status(500).json({ 
                    error: 'Failed to check audio duration',
                    details: durationError
                  });
                  resolve();
                }
              });
              
              ffprobe.on('error', (err) => {
                console.log(`[${projectId}] Duration check error: ${err.message}`);
                res.status(500).json({ 
                  error: 'Failed to check audio duration',
                  details: err.message
                });
                resolve();
              });
                
                return; // Exit early for Scavenger Hunt
              }
              
              // For other project types: Run madmom downbeats detector
              console.log(`[${projectId}] Step 3: Running madmom downbeats detector...`);
              
              const pythonScript = `
import json
import os
import sys
from madmom.features.downbeats import RNNDownBeatProcessor, DBNDownBeatTrackingProcessor

try:
    # Set paths
    audio_path = "song.mp3"
    audio_abs_path = os.path.abspath(audio_path)
    
    print(f"Processing audio file: {audio_abs_path}")
    
    # Extract downbeat activations  
    rnn_processor = RNNDownBeatProcessor()
    activations = rnn_processor(audio_path)
    
    # Downbeat tracking
    fps = 100
    tracker = DBNDownBeatTrackingProcessor(beats_per_bar=4, fps=fps)
    downbeats = tracker(activations)
    
    # Convert to frame numbers (60fps video)
    video_fps = 60
    downbeat_frames = [round(time * video_fps) for time, beat_pos in downbeats if beat_pos == 1]
    
    # Save structured JSON output
    output_data = {
        "audio_file": audio_abs_path,
        "downbeat_frames": downbeat_frames
    }
    
    with open("downbeats.json", "w") as f:
        json.dump(output_data, f, indent=2)
    
    print(f"✅ Detected {len(downbeat_frames)} downbeats")
    
except Exception as e:
    print(f"❌ Error processing downbeats: {e}")
    sys.exit(1)
`;
              
              await fs.writeFile(path.join(projectDir, 'process_downbeats.py'), pythonScript);
              
              // Try multiple madmom approaches with compatibility fixes
              let python;
              const audioFile = 'song.mp3'; // Use the final renamed file
              const outputFile = 'downbeats.json';
              
              // Method 1: Try simple beat detector with conda environment
              const simpleDetector = path.join(__dirname, '../simple_beat_detector.py');
              
              try {
                python = spawn('conda', ['run', '-n', 'madmom', 'python', simpleDetector, audioFile, outputFile], {
                  cwd: projectDir
                });
                console.log(`[${projectId}] Using simple beat detector with conda madmom environment`);
              } catch (error) {
                console.log(`[${projectId}] Simple detector failed, trying madmom compatibility fix`);
                
                // Method 2: Try Python 3.10+ madmom compatibility fix
                try {
                  const compatScript = path.join(__dirname, '../madmom_py310_fix.py');
                  python = spawn('python3', [compatScript, audioFile, outputFile], {
                    cwd: projectDir
                  });
                  console.log(`[${projectId}] Using Python 3.10+ compatibility fix for madmom`);
                } catch (error2) {
                  console.log(`[${projectId}] Madmom compatibility script failed, trying python3.9`);
                  
                  // Method 3: Try python3.9 directly
                  try {
                    const madmomScript = path.join(__dirname, '../madmom_processor.py');
                    python = spawn('python3.9', [madmomScript, audioFile, outputFile], {
                      cwd: projectDir
                    });
                    console.log(`[${projectId}] Using python3.9 for madmom processing`);
                  } catch (error3) {
                    console.log(`[${projectId}] python3.9 not available, trying wrapper script`);
                    
                    // Method 4: Fallback to wrapper script
                    const wrapperScript = path.join(__dirname, '../run_madmom.sh');
                    python = spawn('bash', [wrapperScript, audioFile, outputFile, projectDir], {
                      cwd: projectDir
                    });
                  }
                }
              }
              
              let pythonOutput = '';
              let pythonError = '';
              let responseStepSent = false;
              
              python.stdout.on('data', (data) => {
                const text = data.toString();
                pythonOutput += text;
                console.log(`[${projectId}] python: ${text.trim()}`);
              });
              
              python.stderr.on('data', (data) => {
                const text = data.toString();
                pythonError += text;
                console.log(`[${projectId}] python stderr: ${text.trim()}`);
              });
              
              python.on('close', async (pythonCode) => {
                // Clean up temporary python script
                try {
                  await fs.unlink(path.join(projectDir, 'process_downbeats.py'));
                } catch (err) {
                  // Ignore cleanup errors
                }
                
                // Read madmom results from JSON file
                let madmomResult = null;
                try {
                  const resultPath = path.join(projectDir, 'downbeats.json');
                  const resultContent = await fs.readFile(resultPath, 'utf-8');
                  madmomResult = JSON.parse(resultContent);
                } catch (err) {
                  console.log(`[${projectId}] Could not read madmom results: ${err.message}`);
                }
                
                const madmomSuccess = madmomResult && madmomResult.success;
                
                if (madmomSuccess) {
                  console.log(`[${projectId}] Step 3 completed: Found ${madmomResult.count} downbeats`);
                } else {
                  console.log(`[${projectId}] Step 3 completed: Madmom processing failed or unavailable`);
                }
                
                console.log(`[${projectId}] All processing steps completed!`);
                
                // Update project metadata
                const metadataPath = path.join(projectDir, 'metadata.json');
                try {
                  const metadataContent = await fs.readFile(metadataPath, 'utf-8');
                  const metadata = JSON.parse(metadataContent);
                  metadata.updatedAt = new Date().toISOString();
                  
                  if (startTime && startTime !== '0:00' && startTime !== '00:00') {
                    metadata.audioOffset = startTime;
                  }
                  
                  if (madmomSuccess) {
                    metadata.downbeats = madmomResult.downbeats;
                    metadata.downbeatCount = madmomResult.count;
                  }
                  
                  await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
                } catch (err) {
                  console.log(`[${projectId}] Warning: Could not update metadata`);
                }
                
                if (!responseStepSent) {
                  responseStepSent = true;
                  res.json({
                    message: madmomSuccess 
                      ? 'Audio downloaded and processed successfully'
                      : 'Audio downloaded successfully (downbeat detection unavailable)',
                    file: {
                      name: 'song.mp3',
                      url: `/api/files/${projectId}/song.mp3`
                    },
                    audioOffset: startTime,
                    downbeatsDetected: madmomSuccess,
                    downbeats: madmomSuccess ? madmomResult.downbeats : undefined,
                    downbeatCount: madmomSuccess ? madmomResult.count : 0,
                    madmomError: madmomSuccess ? undefined : (madmomResult && madmomResult.error ? madmomResult.error : 'Madmom processing failed')
                  });
                }
                resolve();
              });
              
              python.on('error', (err) => {
                console.log(`[${projectId}] Step 3 error: ${err.message}`);
                if (!responseStepSent) {
                  responseStepSent = true;
                  res.status(500).json({ 
                    error: 'Failed to start madmom processing',
                    details: err.message
                  });
                }
                resolve();
              });
              
            } else {
              console.log(`[${projectId}] Step 2 failed: FFmpeg conversion failed`);
              res.status(500).json({ 
                error: 'Failed to convert audio to MP3',
                details: ffmpegError || ffmpegOutput
              });
              resolve();
            }
          });
          
          ffmpeg.on('error', (err) => {
            console.log(`[${projectId}] Step 2 error: ${err.message}`);
            res.status(500).json({ 
              error: 'Failed to start ffmpeg',
              details: err.message
            });
            resolve();
          });
          
        } else {
          console.log(`[${projectId}] Step 1 failed: yt-dlp download failed`);
          res.status(500).json({ 
            error: 'Failed to download audio from YouTube',
            details: errorOutput || output
          });
          resolve();
        }
      });
      
      ytdlp.on('error', (err) => {
        console.log(`[${projectId}] Step 1 error: ${err.message}`);
        res.status(500).json({ 
          error: 'Failed to start yt-dlp',
          details: err.message
        });
        resolve();
      });
    });
  } catch (error) {
    console.error(`[${projectId}] Error in YouTube processing:`, error);
    res.status(500).json({ error: 'Failed to process YouTube URL' });
  }
});

// Upload image to specific slot for scavenger hunt projects
router.post('/:projectId/scavenger-hunt-slot', upload.single('images'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No image file uploaded' });
    }

    const { projectId } = req.params;
    const { slot } = req.body;
    
    if (!slot || slot < 1 || slot > 12) {
      return res.status(400).json({ error: 'Invalid slot number. Must be between 1 and 12.' });
    }

    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    // Check if project exists and is a scavenger hunt
    const metadataPath = path.join(projectDir, 'metadata.json');
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      if (metadata.type !== 'Scavenger-Hunt') {
        return res.status(400).json({ error: 'This endpoint is only for Scavenger Hunt projects' });
      }
    } catch (err) {
      return res.status(404).json({ error: 'Project not found or invalid' });
    }

    // Get current slot data
    const slotsPath = path.join(projectDir, 'slots.json');
    let slots = Array.from({ length: 12 }, (_, i) => ({ id: i + 1 }));
    try {
      const slotsContent = await fs.readFile(slotsPath, 'utf-8');
      slots = JSON.parse(slotsContent);
    } catch (err) {
      // slots.json doesn't exist yet, use default empty slots
    }

    // Check for duplicate filename across all slots
    const uploadedFilenames = slots
      .filter(s => s.filename)
      .map(s => s.filename);
    
    if (uploadedFilenames.includes(req.file.filename)) {
      // Delete the uploaded file since it's a duplicate
      await fs.unlink(req.file.path);
      return res.status(409).json({ 
        error: `Image "${req.file.filename}" is already uploaded in another slot`,
        existingSlot: slots.find(s => s.filename === req.file.filename)?.id
      });
    }

    // Remove any existing image in the slot
    const targetSlot = slots.find(s => s.id === parseInt(slot));
    if (targetSlot && targetSlot.filename) {
      try {
        await fs.unlink(path.join(projectDir, targetSlot.filename));
      } catch (err) {
        // File might not exist, continue
      }
    }

    let processedFile = {
      name: req.file.filename,
      size: req.file.size,
      filename: req.file.filename
    };

    // Convert HEIC/HEIF files to JPG
    const fileExt = path.extname(req.file.filename).toLowerCase();
    if (fileExt === '.heic' || fileExt === '.heif') {
      try {
        const originalPath = req.file.path;
        const jpgFilename = req.file.filename.replace(/\.(heic|heif)$/i, '.jpg');
        const jpgPath = path.join(path.dirname(originalPath), jpgFilename);
        
        console.log(`Converting ${req.file.filename} to ${jpgFilename}...`);
        await convertHeicToJpg(originalPath, jpgPath);
        
        // Get the size of the converted file
        const jpgStats = await fs.stat(jpgPath);
        
        // Remove the original HEIC file
        await fs.unlink(originalPath);
        
        processedFile = {
          name: jpgFilename,
          size: jpgStats.size,
          filename: jpgFilename,
          converted: true,
          originalName: req.file.filename
        };
        
        console.log(`Successfully converted ${req.file.filename} to ${jpgFilename}`);
      } catch (conversionError) {
        console.error(`Failed to convert ${req.file.filename}:`, conversionError);
        return res.status(500).json({ 
          error: `Failed to convert ${req.file.filename}: ${conversionError.message}` 
        });
      }
    }

    // Update slot data
    const slotIndex = parseInt(slot) - 1;
    slots[slotIndex] = {
      id: parseInt(slot),
      filename: processedFile.filename,
      image: `/api/uploads/${projectId}/images/${processedFile.filename}`,
      uploadedAt: new Date().toISOString()
    };

    // Save slots data
    await fs.writeFile(slotsPath, JSON.stringify(slots, null, 2));

    // Update project metadata
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      metadata.updatedAt = new Date().toISOString();
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));
    } catch (err) {
      // Metadata update failed, but file is uploaded
    }

    res.json({
      message: 'Image uploaded to slot successfully',
      slot: parseInt(slot),
      filename: processedFile.filename,
      file: processedFile
    });
  } catch (error) {
    console.error('Error uploading image to slot:', error);
    res.status(500).json({ error: error.message || 'Failed to upload image to slot' });
  }
});

// Get slot data for scavenger hunt projects
router.get('/:projectId/scavenger-hunt-slots', async (req, res) => {
  try {
    const { projectId } = req.params;
    const projectDir = path.join(PROJECTS_DIR, projectId);
    
    // Check if project exists and is a scavenger hunt
    const metadataPath = path.join(projectDir, 'metadata.json');
    try {
      const metadataContent = await fs.readFile(metadataPath, 'utf-8');
      const metadata = JSON.parse(metadataContent);
      if (metadata.type !== 'Scavenger-Hunt') {
        return res.status(400).json({ error: 'This endpoint is only for Scavenger Hunt projects' });
      }
    } catch (err) {
      return res.status(404).json({ error: 'Project not found or invalid' });
    }

    // Get slot data
    const slotsPath = path.join(projectDir, 'slots.json');
    let slots = Array.from({ length: 12 }, (_, i) => ({ id: i + 1 }));
    try {
      const slotsContent = await fs.readFile(slotsPath, 'utf-8');
      slots = JSON.parse(slotsContent);
    } catch (err) {
      // slots.json doesn't exist yet, return empty slots
    }

    res.json({ slots });
  } catch (error) {
    console.error('Error getting slot data:', error);
    res.status(500).json({ error: 'Failed to get slot data' });
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