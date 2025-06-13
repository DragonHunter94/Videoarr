#!/bin/bash

# Docker Setup Validation Script
# Validates the Docker configuration without requiring Docker to be installed

echo "🔍 Video Optimizer Docker Configuration Validation"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# Function to run validation check
validate() {
    local check_name="$1"
    local check_command="$2"
    local is_warning="${3:-false}"
    
    echo -n "Checking $check_name... "
    
    if eval "$check_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
        ((CHECKS_PASSED++))
        return 0
    else
        if [ "$is_warning" = "true" ]; then
            echo -e "${YELLOW}⚠️  WARNING${NC}"
            ((WARNINGS++))
        else
            echo -e "${RED}❌ FAIL${NC}"
            ((CHECKS_FAILED++))
        fi
        return 1
    fi
}

# Function to check file syntax
check_yaml_syntax() {
    local file="$1"
    if command -v python3 > /dev/null 2>&1; then
        python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null
    else
        # Basic YAML syntax check
        grep -q "version:" "$file" && ! grep -q "	" "$file"  # No tabs in YAML
    fi
}

check_dockerfile_syntax() {
    local file="$1"
    grep -q "FROM" "$file" && grep -q "WORKDIR\|RUN\|COPY\|ADD" "$file"
}

check_json_syntax() {
    local file="$1"
    if command -v python3 > /dev/null 2>&1; then
        python3 -c "import json; json.load(open('$file'))" 2>/dev/null
    else
        # Basic JSON check
        grep -q "{" "$file" && grep -q "}" "$file"
    fi
}

echo "📋 File Structure Validation"
echo "----------------------------"

# Check core files exist
validate "docker-compose.yml exists" "[ -f docker-compose.yml ]"
validate "docker-compose.prod.yml exists" "[ -f docker-compose.prod.yml ]"
validate "backend Dockerfile exists" "[ -f backend/Dockerfile ]"
validate "frontend Dockerfile exists" "[ -f frontend/Dockerfile ]"
validate ".env.example exists" "[ -f .env.example ]"
validate "setup script exists" "[ -f setup.sh ]"
validate "test script exists" "[ -f test-docker.sh ]"
validate "Makefile exists" "[ -f Makefile ]"
validate "MongoDB init script exists" "[ -f init-mongo.js ]"

echo ""
echo "📄 Configuration File Validation"
echo "--------------------------------"

# Check file syntax
validate "docker-compose.yml syntax" "check_yaml_syntax docker-compose.yml"
validate "docker-compose.prod.yml syntax" "check_yaml_syntax docker-compose.prod.yml"
validate "backend Dockerfile syntax" "check_dockerfile_syntax backend/Dockerfile"
validate "frontend Dockerfile syntax" "check_dockerfile_syntax frontend/Dockerfile"
validate "package.json syntax" "check_json_syntax frontend/package.json"

echo ""
echo "🔧 Backend Configuration"
echo "------------------------"

# Backend checks
validate "requirements.txt exists" "[ -f backend/requirements.txt ]"
validate "server.py exists" "[ -f backend/server.py ]"
validate "backend .env exists" "[ -f backend/.env ]"
validate "FFmpeg dependency in requirements" "grep -q 'ffmpeg-python' backend/requirements.txt"
validate "FastAPI dependency in requirements" "grep -q 'fastapi' backend/requirements.txt"
validate "Motor MongoDB driver in requirements" "grep -q 'motor' backend/requirements.txt"

echo ""
echo "🎨 Frontend Configuration"
echo "-------------------------"

# Frontend checks  
validate "package.json exists" "[ -f frontend/package.json ]"
validate "React app files exist" "[ -f frontend/src/App.js ]"
validate "Tailwind config exists" "[ -f frontend/tailwind.config.js ]"
validate "nginx config exists" "[ -f frontend/nginx.conf ]"
validate "React dependency in package.json" "grep -q 'react' frontend/package.json"
validate "Axios dependency in package.json" "grep -q 'axios' frontend/package.json"

echo ""
echo "🗄️ Database Configuration"
echo "-------------------------"

# Database checks
validate "MongoDB init script syntax" "grep -q 'createUser' init-mongo.js"
validate "Database collections defined" "grep -q 'createCollection' init-mongo.js"
validate "Database indexes defined" "grep -q 'createIndex' init-mongo.js"

echo ""
echo "🌐 Network & Security Configuration"
echo "-----------------------------------"

# Network and security checks
validate "Custom network defined" "grep -q 'video-optimizer-network' docker-compose.yml"
validate "Health checks configured" "grep -q 'healthcheck' docker-compose.yml"
validate "Volume mounts configured" "grep -q 'volumes:' docker-compose.yml"
validate "Environment variables defined" "grep -q 'environment:' docker-compose.yml"
validate "Security headers in nginx" "grep -q 'X-Frame-Options' frontend/nginx.conf"
validate "File upload limits configured" "grep -q 'client_max_body_size' frontend/nginx.conf"

echo ""
echo "📁 Directory Structure"
echo "----------------------"

# Create directories that should exist
mkdir -p videos output logs logs/backend logs/frontend logs/nginx logs/mongodb

validate "videos directory" "[ -d videos ]"
validate "output directory" "[ -d output ]"
validate "logs directory structure" "[ -d logs/backend ] && [ -d logs/frontend ]"

echo ""
echo "🔐 Security Validation"
echo "----------------------"

# Security checks
validate "Non-root user in backend Dockerfile" "grep -q 'USER appuser' backend/Dockerfile"
validate "Security headers configured" "grep -q 'X-Content-Type-Options' frontend/nginx.conf"
validate "HTTPS redirect capability" "grep -q '443' docker-compose.prod.yml"
validate "Production environment separation" "grep -q 'NODE_ENV=production' frontend/Dockerfile"

echo ""
echo "⚡ Performance & Optimization"
echo "----------------------------"

# Performance checks
validate "Multi-stage builds used" "grep -q 'as builder' frontend/Dockerfile"
validate "Layer caching optimized" "grep -q 'COPY.*requirements.txt' backend/Dockerfile"
validate "Gzip compression enabled" "grep -q 'gzip on' frontend/nginx.conf"
validate "Resource limits in production" "grep -q 'resources:' docker-compose.prod.yml"
validate "Build optimization" "grep -q 'npm ci --only=production' frontend/Dockerfile"

echo ""
echo "📊 Validation Summary"
echo "===================="
echo -e "Checks passed: ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Checks failed: ${RED}$CHECKS_FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

echo ""
if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 Docker configuration is valid and ready for deployment!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Install Docker and Docker Compose"
    echo "2. Copy .env.example to .env and configure"
    echo "3. Run: ./setup.sh"
    echo "4. Test: ./test-docker.sh"
    echo ""
    echo -e "${BLUE}Quick start commands:${NC}"
    echo "  make setup    # Initial setup"
    echo "  make up       # Start development"
    echo "  make prod     # Start production"
    echo "  make health   # Check services"
    exit 0
else
    echo -e "${RED}❌ Configuration issues found. Please fix the errors above.${NC}"
    exit 1
fi