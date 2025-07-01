#!/usr/bin/env python3
"""
Standalone Madmom Processor
===========================
Isolated Python 3.9 script for madmom downbeat detection.
This runs in a separate environment to avoid Python version conflicts.
"""

import sys
import json
import os
from pathlib import Path

try:
    import numpy as np
    from madmom.features.downbeats import RNNDownBeatProcessor, DBNDownBeatTrackingProcessor
    from madmom.features.beats import BeatTrackingProcessor
    import madmom.audio.signal as signal
    MADMOM_AVAILABLE = True
except ImportError as e:
    MADMOM_AVAILABLE = False
    IMPORT_ERROR = str(e)

def process_downbeats(audio_file_path, output_file_path):
    """Process audio file and detect downbeats using madmom."""
    
    if not MADMOM_AVAILABLE:
        return {
            "success": False,
            "error": f"Madmom not available: {IMPORT_ERROR}",
            "downbeats": []
        }
    
    try:
        # Check if input file exists, try different possible names
        possible_files = [
            audio_file_path,
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
            return {
                "success": False,
                "error": f"Audio file not found. Tried: {', '.join(possible_files)}",
                "downbeats": []
            }
        
        audio_file_path = actual_file
        print(f"Found audio file: {audio_file_path}")
        
        print(f"Processing audio file: {audio_file_path}")
        
        # Initialize processors
        downbeat_processor = RNNDownBeatProcessor()
        downbeat_tracker = DBNDownBeatTrackingProcessor(beats_per_bar=4, fps=100)
        
        # Process the audio file
        print("Detecting downbeats...")
        downbeat_activations = downbeat_processor(audio_file_path)
        downbeats = downbeat_tracker(downbeat_activations)
        
        # Convert to list of timestamps
        downbeat_times = [float(downbeat[0]) for downbeat in downbeats if downbeat[1] == 1]
        
        print(f"Found {len(downbeat_times)} downbeats")
        
        # Save results to output file
        result = {
            "success": True,
            "downbeats": downbeat_times,
            "count": len(downbeat_times),
            "audio_file": audio_file_path
        }
        
        with open(output_file_path, 'w') as f:
            json.dump(result, f, indent=2)
        
        print(f"Results saved to: {output_file_path}")
        return result
        
    except Exception as e:
        error_result = {
            "success": False,
            "error": str(e),
            "downbeats": []
        }
        
        # Still save error result to output file
        with open(output_file_path, 'w') as f:
            json.dump(error_result, f, indent=2)
        
        return error_result

def main():
    """Main entry point for command line usage."""
    
    if len(sys.argv) != 3:
        print("Usage: python madmom_processor.py <input_audio_file> <output_json_file>")
        print("Example: python madmom_processor.py song.mp3 downbeats.json")
        sys.exit(1)
    
    audio_file = sys.argv[1]
    output_file = sys.argv[2]
    
    # Process the file
    result = process_downbeats(audio_file, output_file)
    
    # Print result summary
    if result["success"]:
        print(f"✅ Success: Found {result['count']} downbeats")
        print(f"📁 Results saved to: {output_file}")
        sys.exit(0)
    else:
        print(f"❌ Error: {result['error']}")
        sys.exit(1)

if __name__ == "__main__":
    main()