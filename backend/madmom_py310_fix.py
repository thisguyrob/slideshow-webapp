#!/usr/bin/env python3
"""
Madmom Python 3.10+ Compatibility Fix
=====================================
Fixes the MutableSequence import issue in madmom for Python 3.10+
"""

import sys
import os

def fix_madmom_compatibility():
    """Apply compatibility fixes for madmom with Python 3.10+"""
    
    # Fix 1: Monkey patch collections.MutableSequence
    try:
        import collections
        if not hasattr(collections, 'MutableSequence'):
            import collections.abc
            collections.MutableSequence = collections.abc.MutableSequence
            print("✅ Applied MutableSequence compatibility fix")
    except Exception as e:
        print(f"⚠️  Could not apply MutableSequence fix: {e}")
    
    # Fix 2: Monkey patch numpy compatibility issues
    try:
        import numpy as np
        if not hasattr(np, 'float'):
            np.float = float
            print("✅ Applied numpy.float compatibility fix")
        if not hasattr(np, 'int'):
            np.int = int
            print("✅ Applied numpy.int compatibility fix")
        if not hasattr(np, 'complex'):
            np.complex = complex
            print("✅ Applied numpy.complex compatibility fix")
    except Exception as e:
        print(f"⚠️  Could not apply numpy compatibility fixes: {e}")

def test_madmom_import():
    """Test if madmom can be imported after fixes"""
    try:
        import madmom
        print("✅ Madmom imported successfully")
        return True
    except ImportError as e:
        print(f"❌ Madmom import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Madmom error: {e}")
        return False

def process_downbeats_safe(audio_file_path, output_file_path):
    """Process downbeats with compatibility fixes applied"""
    
    # Apply compatibility fixes
    fix_madmom_compatibility()
    
    # Test if madmom works
    if not test_madmom_import():
        result = {
            "success": False,
            "error": "Madmom not available or incompatible",
            "downbeats": [],
            "count": 0
        }
        
        with open(output_file_path, 'w') as f:
            import json
            json.dump(result, f, indent=2)
        return result
    
    # Import madmom modules after fixes
    try:
        from madmom.features.downbeats import RNNDownBeatProcessor, DBNDownBeatTrackingProcessor
        import numpy as np
        import json
        
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
            error_result = {
                "success": False,
                "error": f"Audio file not found. Tried: {', '.join(possible_files)}",
                "downbeats": [],
                "count": 0
            }
            
            with open(output_file_path, 'w') as f:
                json.dump(error_result, f, indent=2)
            
            return error_result
        
        audio_file_path = actual_file
        print(f"Found audio file: {audio_file_path}")
        print(f"Processing audio file: {audio_file_path}")
        
        # Initialize processors
        downbeat_processor = RNNDownBeatProcessor()
        downbeat_tracker = DBNDownBeatTrackingProcessor(beats_per_bar=4, fps=100)
        
        # Process the audio file
        print("Detecting downbeats...")
        
        # Apply additional numpy compatibility for madmom processing
        import warnings
        warnings.filterwarnings('ignore', category=DeprecationWarning)
        warnings.filterwarnings('ignore', category=np.VisibleDeprecationWarning)
        
        downbeat_activations = downbeat_processor(audio_file_path)
        downbeats = downbeat_tracker(downbeat_activations)
        
        # Convert to list of timestamps
        downbeat_times = [float(downbeat[0]) for downbeat in downbeats if downbeat[1] == 1]
        
        print(f"Found {len(downbeat_times)} downbeats")
        
        # Save results
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
            "downbeats": [],
            "count": 0
        }
        
        with open(output_file_path, 'w') as f:
            json.dump(error_result, f, indent=2)
        
        return error_result

def main():
    """Main entry point"""
    if len(sys.argv) != 3:
        print("Usage: python madmom_py310_fix.py <input_audio_file> <output_json_file>")
        sys.exit(1)
    
    audio_file = sys.argv[1]
    output_file = sys.argv[2]
    
    result = process_downbeats_safe(audio_file, output_file)
    
    if result["success"]:
        print(f"✅ Success: Found {result['count']} downbeats")
        sys.exit(0)
    else:
        print(f"❌ Error: {result['error']}")
        sys.exit(1)

if __name__ == "__main__":
    main()