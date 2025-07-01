#!/bin/bash
# Wrapper script to run madmom with appropriate Python environment

set -e

AUDIO_FILE="$1"
OUTPUT_FILE="$2"
PROJECT_DIR="$3"

if [ -z "$AUDIO_FILE" ] || [ -z "$OUTPUT_FILE" ] || [ -z "$PROJECT_DIR" ]; then
    echo "Usage: $0 <audio_file> <output_file> <project_dir>"
    exit 1
fi

cd "$PROJECT_DIR"

echo "🔍 Trying madmom environments..."

# Method 1: Try pyenv madmom environment
if command -v pyenv &> /dev/null; then
    echo "📍 Trying pyenv madmom environment..."
    if pyenv versions | grep -q madmom-env; then
        export PATH="$HOME/.pyenv/bin:$PATH"
        eval "$(pyenv init -)"
        eval "$(pyenv virtualenv-init -)"
        
        if pyenv activate madmom-env 2>/dev/null; then
            echo "✅ Using pyenv madmom environment"
            python "$(dirname "$0")/madmom_processor.py" "$AUDIO_FILE" "$OUTPUT_FILE"
            exit $?
        fi
    fi
fi

# Method 2: Try conda environment
if command -v conda &> /dev/null; then
    echo "📍 Trying conda madmom environment..."
    if conda env list | grep -q madmom; then
        echo "✅ Using conda madmom environment"
        # Use conda run to execute in the madmom environment
        conda run -n madmom python "$(dirname "$0")/madmom_processor.py" "$AUDIO_FILE" "$OUTPUT_FILE"
        exit $?
    fi
fi

# Method 3: Try Docker madmom container
if command -v docker &> /dev/null; then
    echo "📍 Trying Docker madmom container..."
    if docker image ls | grep -q madmom-processor; then
        echo "✅ Using Docker madmom container"
        docker run --rm \
            -v "$PROJECT_DIR:/data" \
            madmom-processor \
            "/data/$AUDIO_FILE" "/data/$OUTPUT_FILE"
        exit $?
    fi
fi

# Method 4: Try system Python with madmom
echo "📍 Trying system Python with madmom..."
if python3 -c "import madmom" 2>/dev/null; then
    echo "✅ Using system Python with madmom"
    python3 "$(dirname "$0")/madmom_processor.py" "$AUDIO_FILE" "$OUTPUT_FILE"
    exit $?
fi

# Method 5: Try alternative Python versions
for python_cmd in python3.9 python3.8 python3.7; do
    if command -v "$python_cmd" &> /dev/null; then
        echo "📍 Trying $python_cmd with madmom..."
        if "$python_cmd" -c "import madmom" 2>/dev/null; then
            echo "✅ Using $python_cmd with madmom"
            "$python_cmd" "$(dirname "$0")/madmom_processor.py" "$AUDIO_FILE" "$OUTPUT_FILE"
            exit $?
        fi
    fi
done

# All methods failed
echo "❌ No compatible madmom installation found"
echo "📋 Available options:"
echo "  1. Install pyenv and create madmom environment: pyenv virtualenv 3.9.18 madmom-env"
echo "  2. Install conda and create madmom environment: conda create -n madmom python=3.9"
echo "  3. Build Docker madmom container: docker build -f Dockerfile.madmom -t madmom-processor ."
echo "  4. Install madmom system-wide: pip install madmom"

# Create empty result file to indicate failure
cat > "$OUTPUT_FILE" << EOF
{
  "success": false,
  "error": "No compatible madmom installation found",
  "downbeats": [],
  "count": 0
}
EOF

exit 1