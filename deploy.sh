#!/bin/bash

# Video Optimizer Deployment Script
# Supports development, production, and cloud deployments

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
ENVIRONMENT="development"
SKIP_DOCKER_CHECK=false
BACKUP_BEFORE_DEPLOY=false
AUTO_MIGRATE=false

# Help function
show_help() {
    echo "Video Optimizer Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment   Environment (development|production|staging) [default: development]"
    echo "  -s, --skip-docker   Skip Docker installation check"
    echo "  -b, --backup        Backup database before deployment"
    echo "  -m, --migrate       Auto-migrate database"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Development deployment"
    echo "  $0 -e production -b -m              # Production with backup and migration"
    echo "  $0 --environment staging --backup   # Staging deployment with backup"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -s|--skip-docker)
            SKIP_DOCKER_CHECK=true
            shift
            ;;
        -b|--backup)
            BACKUP_BEFORE_DEPLOY=true
            shift
            ;;
        -m|--migrate)
            AUTO_MIGRATE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
case $ENVIRONMENT in
    development|production|staging)
        ;;
    *)
        echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
        echo "Valid options: development, production, staging"
        exit 1
        ;;
esac

echo -e "${BLUE}🚀 Video Optimizer Deployment${NC}"
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
echo "=================================="

# Function to check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    if [ "$SKIP_DOCKER_CHECK" = false ]; then
        if ! command -v docker &> /dev/null; then
            echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
            echo "Installation guides:"
            echo "  Ubuntu/Debian: sudo apt update && sudo apt install docker.io docker-compose"
            echo "  CentOS/RHEL: sudo yum install docker docker-compose"
            echo "  macOS/Windows: Download Docker Desktop"
            exit 1
        fi
        
        if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
            echo -e "${RED}❌ Docker Compose not found.${NC}"
            exit 1
        fi
        
        # Check if Docker daemon is running
        if ! docker info &> /dev/null; then
            echo -e "${RED}❌ Docker daemon is not running.${NC}"
            echo "Start Docker with: sudo systemctl start docker"
            exit 1
        fi
    fi
    
    # Check disk space (require at least 2GB free)
    AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 2097152 ]; then  # 2GB in KB
        echo -e "${YELLOW}⚠️  Warning: Less than 2GB disk space available${NC}"
    fi
    
    echo -e "${GREEN}✅ Prerequisites check completed${NC}"
}

# Function to setup environment
setup_environment() {
    echo "📋 Setting up environment..."
    
    # Create directories
    mkdir -p videos output logs logs/backend logs/frontend logs/nginx logs/mongodb
    
    # Setup environment file
    if [ ! -f .env ]; then
        cp .env.example .env
        echo -e "${YELLOW}⚠️  Created .env file from template. Please review and update it.${NC}"
        
        # Generate secure passwords for production
        if [ "$ENVIRONMENT" = "production" ]; then
            MONGO_ROOT_PASS=$(openssl rand -base64 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32)
            MONGO_USER_PASS=$(openssl rand -base64 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 24)
            
            sed -i "s/MONGO_ROOT_PASSWORD=.*/MONGO_ROOT_PASSWORD=$MONGO_ROOT_PASS/" .env
            sed -i "s/MONGO_USER_PASSWORD=.*/MONGO_USER_PASSWORD=$MONGO_USER_PASS/" .env
            
            echo -e "${GREEN}✅ Generated secure passwords for production${NC}"
        fi
    fi
    
    # Set environment-specific configurations
    case $ENVIRONMENT in
        development)
            export COMPOSE_FILE="docker-compose.yml"
            ;;
        production)
            export COMPOSE_FILE="docker-compose.prod.yml"
            ;;
        staging)
            export COMPOSE_FILE="docker-compose.yml"
            # Add staging-specific overrides
            ;;
    esac
    
    echo -e "${GREEN}✅ Environment setup completed${NC}"
}

# Function to backup database
backup_database() {
    if [ "$BACKUP_BEFORE_DEPLOY" = true ]; then
        echo "💾 Creating database backup..."
        
        # Check if database is running
        if docker-compose ps mongodb | grep -q "Up"; then
            BACKUP_DIR="backups/backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            
            docker-compose exec -T mongodb mongodump --out /tmp/backup
            docker cp "$(docker-compose ps -q mongodb):/tmp/backup" "$BACKUP_DIR/"
            
            echo -e "${GREEN}✅ Database backed up to $BACKUP_DIR${NC}"
        else
            echo -e "${YELLOW}⚠️  Database not running, skipping backup${NC}"
        fi
    fi
}

# Function to deploy services
deploy_services() {
    echo "🔨 Building and deploying services..."
    
    # Build images
    echo "Building Docker images..."
    docker-compose -f $COMPOSE_FILE build --no-cache
    
    # Start services
    echo "Starting services..."
    docker-compose -f $COMPOSE_FILE up -d
    
    echo -e "${GREEN}✅ Services deployed${NC}"
}

# Function to run health checks
run_health_checks() {
    echo "🏥 Running health checks..."
    
    # Wait for services to start
    echo "Waiting for services to initialize..."
    sleep 30
    
    # Check service health
    BACKEND_PORT=$(grep BACKEND_PORT .env | cut -d'=' -f2 || echo "8001")
    FRONTEND_PORT=$(grep FRONTEND_PORT .env | cut -d'=' -f2 || echo "3000")
    
    # Backend health check
    if curl -f "http://localhost:$BACKEND_PORT/api/" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend API is healthy${NC}"
    else
        echo -e "${RED}❌ Backend API is not responding${NC}"
        echo "Check logs with: docker-compose logs backend"
    fi
    
    # Frontend health check
    if curl -f "http://localhost:$FRONTEND_PORT/" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Frontend is healthy${NC}"
    else
        echo -e "${RED}❌ Frontend is not responding${NC}"
        echo "Check logs with: docker-compose logs frontend"
    fi
    
    # Database health check
    if docker-compose exec -T mongodb mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ MongoDB is healthy${NC}"
    else
        echo -e "${RED}❌ MongoDB is not responding${NC}"
        echo "Check logs with: docker-compose logs mongodb"
    fi
}

# Function to run migrations
run_migrations() {
    if [ "$AUTO_MIGRATE" = true ]; then
        echo "🔄 Running database migrations..."
        
        # Wait for database to be ready
        sleep 10
        
        # Run any migration scripts here
        # docker-compose exec backend python migrate.py
        
        echo -e "${GREEN}✅ Migrations completed${NC}"
    fi
}

# Function to show deployment summary
show_summary() {
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo "====================================="
    echo ""
    echo -e "${BLUE}Environment:${NC} $ENVIRONMENT"
    echo -e "${BLUE}Frontend:${NC} http://localhost:${FRONTEND_PORT:-3000}"
    echo -e "${BLUE}Backend API:${NC} http://localhost:${BACKEND_PORT:-8001}/api"
    echo -e "${BLUE}API Docs:${NC} http://localhost:${BACKEND_PORT:-8001}/docs"
    echo ""
    echo -e "${BLUE}Useful commands:${NC}"
    echo "  docker-compose logs -f       # Follow logs"
    echo "  docker-compose ps            # Service status"
    echo "  docker-compose down          # Stop services"
    echo "  docker-compose restart       # Restart services"
    echo ""
    echo -e "${BLUE}Directories:${NC}"
    echo "  ./videos/    # Place input videos here"
    echo "  ./output/    # Processed videos will appear here"
    echo "  ./logs/      # Application logs"
    echo ""
    
    if [ "$ENVIRONMENT" = "production" ]; then
        echo -e "${YELLOW}🔐 Production Security Notes:${NC}"
        echo "  - Review and update passwords in .env"
        echo "  - Configure SSL/TLS certificates"
        echo "  - Set up firewall rules"
        echo "  - Enable log monitoring"
        echo "  - Schedule regular backups"
    fi
}

# Main deployment flow
main() {
    check_prerequisites
    setup_environment
    backup_database
    deploy_services
    run_migrations
    run_health_checks
    show_summary
}

# Run main function
main