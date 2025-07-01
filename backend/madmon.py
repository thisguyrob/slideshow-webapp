import json
import os
from madmom.features.downbeats import RNNDownBeatProcessor, DBNDownBeatTrackingProcessor

# Step 1: Set and resolve audio file path
audio_path = "audio.mp3"  # ← Replace this with your file
audio_abs_path = os.path.abspath(audio_path)

# Step 2: Extract downbeat activations
rnn_processor = RNNDownBeatProcessor()
activations = rnn_processor(audio_path)

# Step 3: Downbeat tracking
fps = 100
tracker = DBNDownBeatTrackingProcessor(beats_per_bar=4, fps=fps)
downbeats = tracker(activations)

# Step 4: Convert to frame numbers (60fps video)
video_fps = 60
downbeat_frames = [round(time * video_fps) for time, beat_pos in downbeats if beat_pos == 1]

# Step 5: Save structured JSON output
output_data = {
    "audio_file": audio_abs_path,
    "downbeat_frames": downbeat_frames
}

with open("downbeats_frames.json", "w") as f:
    json.dump(output_data, f, indent=2)

print(f"✅ Saved {len(downbeat_frames)} downbeats to downbeats_frames.json")
