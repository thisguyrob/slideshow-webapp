#!/usr/bin/env python3
"""
Madmom Test Script
==================
Tests madmom downbeat detection functionality based on the process used in preprocess.zsh.
This script helps verify that madmom is working correctly before running the full pipeline.

Usage:
    python3 test_madmom.py [audio_file]
    
If no audio file is provided, it will look for 'song.mp3' in the current directory.
"""

import json
import os
import sys
import time
from pathlib import Path

def print_status(message):
    """Print status message with blue info icon"""
    print(f"ℹ︎  {message}")

def print_success(message):
    """Print success message with green checkmark"""
    print(f"✓ {message}")

def print_error(message):
    """Print error message with red X"""
    print(f"✗ {message}")

def print_warning(message):
    """Print warning message with yellow warning icon"""
    print(f"⚠  {message}")

def check_madmom_import():
    """Test if madmom can be imported properly"""
    print_status("Testing madmom import...")
    
    try:
        from madmom.features.downbeats import RNNDownBeatProcessor, DBNDownBeatTrackingProcessor
        print_success("Madmom modules imported successfully")
        return True
    except ImportError as e:
        print_error(f"Failed to import madmom: {e}")
        print_error("Please install madmom: pip install --no-use-pep517 madmom")
        return False
    except Exception as e:
        print_error(f"Unexpected error importing madmom: {e}")
        return False

def test_downbeat_detection(audio_file):
    """Test downbeat detection on the given audio file"""
    # Import here after we've verified imports work
    from madmom.features.downbeats import RNNDownBeatProcessor, DBNDownBeatTrackingProcessor
    
    audio_path = Path(audio_file)
    if not audio_path.exists():
        print_error(f"Audio file not found: {audio_file}")
        return False
    
    print_status(f"Testing downbeat detection on: {audio_file}")
    
    try:
        # Step 1: Extract downbeat activations
        print_status("Step 1: Extracting downbeat activations with RNN processor...")
        start_time = time.time()
        
        rnn_processor = RNNDownBeatProcessor()
        activations = rnn_processor(str(audio_path))
        
        rnn_time = time.time() - start_time
        print_success(f"RNN processing completed in {rnn_time:.2f} seconds")
        print_status(f"Activations shape: {activations.shape}")
        
        # Step 2: Downbeat tracking
        print_status("Step 2: Tracking downbeats with DBN processor...")
        start_time = time.time()
        
        # Use same parameters as preprocess.zsh
        fps = 100
        tracker = DBNDownBeatTrackingProcessor(beats_per_bar=4, fps=fps)
        downbeats = tracker(activations)
        
        tracking_time = time.time() - start_time
        print_success(f"Downbeat tracking completed in {tracking_time:.2f} seconds")
        
        # Step 3: Process results
        print_status("Step 3: Processing results...")
        
        # Filter for downbeats only (beat_pos == 1)
        downbeat_times = [time for time, beat_pos in downbeats if beat_pos == 1]
        
        # Convert to frame numbers (60fps video, same as preprocess.zsh)
        video_fps = 60
        downbeat_frames = [round(time * video_fps) for time in downbeat_times]
        
        print_success(f"Detected {len(downbeat_times)} downbeats")
        
        # Display first few downbeats for verification
        if len(downbeat_times) > 0:
            print_status("First 10 downbeats:")
            for i, (time_sec, frame) in enumerate(zip(downbeat_times[:10], downbeat_frames[:10])):
                minutes = int(time_sec // 60)
                seconds = time_sec % 60
                print(f"  {i+1:2d}. {minutes:02d}:{seconds:06.3f} (frame {frame})")
            
            if len(downbeat_times) > 10:
                print_status(f"... and {len(downbeat_times) - 10} more downbeats")
        
        # Step 4: Save results (same format as preprocess.zsh)
        output_data = {
            "audio_file": str(audio_path.resolve()),
            "downbeat_frames": downbeat_frames,
            "downbeat_times": downbeat_times,
            "processing_info": {
                "rnn_processing_time": rnn_time,
                "tracking_time": tracking_time,
                "total_time": rnn_time + tracking_time,
                "fps": fps,
                "video_fps": video_fps,
                "beats_per_bar": 4
            }
        }
        
        output_file = "test_downbeats.json"
        with open(output_file, "w") as f:
            json.dump(output_data, f, indent=2)
        
        print_success(f"Results saved to {output_file}")
        
        # Performance summary
        total_time = rnn_time + tracking_time
        print_status(f"Performance summary:")
        print_status(f"  RNN processing: {rnn_time:.2f}s")
        print_status(f"  Downbeat tracking: {tracking_time:.2f}s") 
        print_status(f"  Total processing: {total_time:.2f}s")
        
        return True
        
    except Exception as e:
        print_error(f"Error during downbeat detection: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main test function"""
    print_status("🎵 Madmom Downbeat Detection Test")
    print_status("=================================")
    
    # Check command line arguments
    if len(sys.argv) > 1:
        audio_file = sys.argv[1]
    else:
        # Default to song.mp3 like preprocess.zsh
        audio_file = "song.mp3"
    
    print_status(f"Target audio file: {audio_file}")
    
    # Step 1: Test madmom import
    if not check_madmom_import():
        print_error("Madmom import test failed. Cannot proceed.")
        sys.exit(1)
    
    # Step 2: Test downbeat detection
    if not test_downbeat_detection(audio_file):
        print_error("Downbeat detection test failed.")
        sys.exit(1)
    
    print_success("All tests passed! Madmom is working correctly.")
    print_status("")
    print_status("Next steps:")
    print_status("1. Check test_downbeats.json for detailed results")
    print_status("2. Verify the downbeat timings make sense for your audio")
    print_status("3. If results look good, madmom should work in the main pipeline")

if __name__ == "__main__":
    main()