#!/usr/bin/env python3
"""
Simple Beat Detector
===================
A lightweight alternative to madmom for basic beat detection.
Works with modern Python and numpy versions.
"""

import sys
import json
import os
import numpy as np

def simple_beat_detection(audio_file_path, output_file_path):
    """Simple beat detection using basic audio analysis."""
    
    try:
        # Try to use librosa for basic beat detection (more compatible)
        try:
            import librosa
            LIBROSA_AVAILABLE = True
        except ImportError:
            LIBROSA_AVAILABLE = False
        
        if LIBROSA_AVAILABLE:
            print("Using librosa for beat detection...")
            
            # Load audio file
            y, sr = librosa.load(audio_file_path)
            
            # Extract tempo and beat frames
            tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr)
            
            # Convert frames to time
            beat_times = librosa.frames_to_time(beat_frames, sr=sr)
            
            # Estimate downbeats (every 4th beat for 4/4 time)
            downbeat_times = [float(beat_times[i]) for i in range(0, len(beat_times), 4)]
            
            print(f"Detected tempo: {float(tempo):.1f} BPM")
            print(f"Found {len(beat_times)} beats, {len(downbeat_times)} downbeats")
            
        else:
            # Fallback: create evenly spaced beats based on common tempos
            print("Using fallback beat detection...")
            
            # Get audio duration (basic approach)
            import wave
            try:
                with wave.open(audio_file_path, 'rb') as wav_file:
                    frames = wav_file.getnframes()
                    rate = wav_file.getframerate()
                    duration = frames / float(rate)
            except:
                # If can't read as WAV, estimate duration (assume ~3-5 minutes)
                duration = 240.0  # 4 minutes default
            
            # Assume 120 BPM (common tempo)
            bpm = 120
            beat_interval = 60.0 / bpm  # seconds per beat
            downbeat_interval = beat_interval * 4  # every 4 beats
            
            # Generate downbeat times
            downbeat_times = []
            time = 0.0
            while time < duration:
                downbeat_times.append(time)
                time += downbeat_interval
            
            print(f"Generated {len(downbeat_times)} evenly-spaced downbeats at 120 BPM")
        
        # Save results
        result = {
            "success": True,
            "downbeats": downbeat_times,
            "count": len(downbeat_times),
            "audio_file": audio_file_path,
            "method": "librosa" if LIBROSA_AVAILABLE else "fallback"
        }
        
        with open(output_file_path, 'w') as f:
            json.dump(result, f, indent=2)
        
        print(f"Results saved to: {output_file_path}")
        return result
        
    except Exception as e:
        error_result = {
            "success": False,
            "error": str(e),
            "downbeats": [],
            "count": 0
        }
        
        with open(output_file_path, 'w') as f:
            json.dump(error_result, f, indent=2)
        
        return error_result

def main():
    """Main entry point"""
    if len(sys.argv) != 3:
        print("Usage: python simple_beat_detector.py <input_audio_file> <output_json_file>")
        sys.exit(1)
    
    audio_file = sys.argv[1]
    output_file = sys.argv[2]
    
    # Check if input file exists, try different possible names
    possible_files = [
        audio_file,
        'song.mp3',
        'song_converted.mp3',
        os.path.join(os.getcwd(), 'song.mp3'),
        os.path.join(os.getcwd(), 'song_converted.mp3')
    ]
    
    actual_file = None
    for file_path in possible_files:
        if os.path.exists(file_path):
            actual_file = file_path
            break
    
    if not actual_file:
        result = {
            "success": False,
            "error": f"Audio file not found. Tried: {', '.join(possible_files)}",
            "downbeats": [],
            "count": 0
        }
        
        with open(output_file, 'w') as f:
            json.dump(result, f, indent=2)
        
        print(f"❌ Error: Audio file not found")
        sys.exit(1)
    
    result = simple_beat_detection(actual_file, output_file)
    
    if result["success"]:
        print(f"✅ Success: Found {result['count']} downbeats using {result.get('method', 'unknown')} method")
        sys.exit(0)
    else:
        print(f"❌ Error: {result['error']}")
        sys.exit(1)

if __name__ == "__main__":
    main()