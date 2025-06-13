#!/bin/bash

# Docker Setup Test Script
# Tests the complete Docker setup to ensure everything works correctly

set -e

echo "🧪 Video Optimizer Docker Setup Test"
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to test HTTP endpoint
test_http() {
    local url="$1"
    local expected_status="${2:-200}"
    
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    [ "$status_code" = "$expected_status" ]
}

# Function to test service health
test_service_health() {
    local service="$1"
    docker-compose ps "$service" | grep -q "Up.*healthy"
}

echo "🔍 Pre-flight checks..."

# Check if required commands exist
run_test "Docker installation" "command -v docker"
run_test "Docker Compose installation" "command -v docker-compose || docker compose version"
run_test "curl installation" "command -v curl"

echo ""
echo "🏗️ Setup validation..."

# Check if required files exist
run_test ".env file exists" "[ -f .env ]"
run_test "docker-compose.yml exists" "[ -f docker-compose.yml ]"
run_test "backend Dockerfile exists" "[ -f backend/Dockerfile ]"
run_test "frontend Dockerfile exists" "[ -f frontend/Dockerfile ]"

echo ""
echo "📁 Directory structure..."

# Check directories
run_test "videos directory exists" "[ -d videos ]"
run_test "output directory exists" "[ -d output ]"
run_test "logs directory exists" "[ -d logs ]"

echo ""
echo "🚀 Starting services..."

# Start services
if docker-compose up -d; then
    echo -e "${GREEN}✅ Services started${NC}"
else
    echo -e "${RED}❌ Failed to start services${NC}"
    exit 1
fi

echo ""
echo "⏳ Waiting for services to initialize..."
sleep 30

echo ""
echo "🏥 Health checks..."

# Test service health
run_test "MongoDB health" "test_service_health mongodb"
run_test "Backend health" "test_service_health backend"
run_test "Frontend health" "test_service_health frontend"

echo ""
echo "🌐 Endpoint tests..."

# Test HTTP endpoints
run_test "Backend API root" "test_http http://localhost:8001/api/"
run_test "Backend system info" "test_http http://localhost:8001/api/system-info"
run_test "Frontend homepage" "test_http http://localhost:3000/"

echo ""
echo "💾 Database tests..."

# Test database connectivity
run_test "MongoDB ping" "docker-compose exec -T mongodb mongosh --eval 'db.adminCommand(\"ping\")'"
run_test "Database initialization" "docker-compose exec -T mongodb mongosh video_optimizer --eval 'db.video_analyses.countDocuments({})'"

echo ""
echo "📤 Upload functionality test..."

# Create a small test video
if ! [ -f /tmp/test_video.mp4 ]; then
    echo "Creating test video..."
    docker-compose exec -T backend ffmpeg -y -f lavfi -i testsrc=duration=5:size=320x240:rate=25 -c:v libx264 -t 5 /tmp/test_upload.mp4 > /dev/null 2>&1
fi

# Test upload endpoint
run_test "Video upload test endpoint" "docker-compose exec -T backend curl -s -F 'file=@/tmp/test_upload.mp4' http://localhost:8001/api/test-upload"

echo ""
echo "🔧 Service logs check..."

# Check for errors in logs
run_test "Backend logs clean" "! docker-compose logs backend | grep -i error"
run_test "Frontend logs clean" "! docker-compose logs frontend | grep -i error"
run_test "MongoDB logs clean" "! docker-compose logs mongodb | grep -i error"

echo ""
echo "📊 Performance tests..."

# Test system resources
run_test "Sufficient disk space" "[ $(df /tmp | tail -1 | awk '{print $4}') -gt 1000000 ]"  # 1GB free
run_test "Memory usage reasonable" "[ $(docker stats --no-stream --format 'table {{.MemUsage}}' | tail -n +2 | head -1 | cut -d'/' -f1 | sed 's/[^0-9.]//g' | cut -d'.' -f1) -lt 2000 ]"  # Less than 2GB

echo ""
echo "🧹 Cleanup test..."

# Test cleanup
run_test "Service stop" "docker-compose stop"
run_test "Service removal" "docker-compose rm -f"

echo ""
echo "📋 Test Summary"
echo "==============="
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All tests passed! Your Docker setup is ready.${NC}"
    echo ""
    echo "To start the application:"
    echo "  docker-compose up -d"
    echo ""
    echo "Access the application at:"
    echo "  Frontend: http://localhost:3000"
    echo "  Backend API: http://localhost:8001/api"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some tests failed. Please check the configuration.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  - Ensure Docker and Docker Compose are properly installed"
    echo "  - Check that ports 3000, 8001, and 27017 are available"
    echo "  - Verify .env file is properly configured"
    echo "  - Check Docker daemon is running"
    exit 1
fi