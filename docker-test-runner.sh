#!/bin/bash
# ------------------------------------------------------------
# docker-test-runner.sh - Build and test the Docker container
# ------------------------------------------------------------

set -euo pipefail

echo "========================================="
echo "   Docker Build and Test Runner"
echo "========================================="

# Build the Docker image
echo "Building Docker image..."
docker build -t slideshow-app .

if [[ $? -ne 0 ]]; then
    echo "❌ Docker build failed!"
    exit 1
fi

echo "✅ Docker build completed"

# Stop any existing container
echo "Stopping any existing containers..."
docker stop slideshow-test 2>/dev/null || true
docker rm slideshow-test 2>/dev/null || true

# Start the container
echo "Starting Docker container..."
docker run -d \
    --name slideshow-test \
    -p 3000:3000 \
    -v "$(pwd)/projects:/app/projects" \
    slideshow-app

if [[ $? -ne 0 ]]; then
    echo "❌ Failed to start Docker container!"
    exit 1
fi

echo "✅ Docker container started"

# Wait for server to be ready
echo "Waiting for server to start..."
for i in {1..30}; do
    if curl -s -f http://localhost:3000/api/projects > /dev/null; then
        echo "✅ Server is ready"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "❌ Server did not start within 30 seconds"
        docker logs slideshow-test
        docker stop slideshow-test
        docker rm slideshow-test
        exit 1
    fi
    sleep 1
done

# Run the tests
echo "Running API tests..."
./test-docker.sh

TEST_RESULT=$?

# Show container logs if tests failed
if [[ $TEST_RESULT -ne 0 ]]; then
    echo -e "\n========================================="
    echo "   Container Logs (last 50 lines)"
    echo "========================================="
    docker logs --tail 50 slideshow-test
fi

# Cleanup
echo -e "\nCleaning up..."
docker stop slideshow-test
docker rm slideshow-test

if [[ $TEST_RESULT -eq 0 ]]; then
    echo -e "\n🎉 All Docker tests passed!"
    echo "Your slideshow app is ready to use!"
    echo ""
    echo "To run the app:"
    echo "  docker build -t slideshow ."
    echo "  docker run -p 3000:3000 -v \"\$(pwd)/projects:/app/projects\" slideshow"
    echo ""
    echo "Then open http://localhost:3000"
else
    echo -e "\n❌ Docker tests failed!"
    exit 1
fi