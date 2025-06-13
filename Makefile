# Video Optimizer Docker Management
# Use this Makefile for easy Docker operations

.PHONY: help build up down logs clean setup test prod

# Default target
help:
	@echo "Video Optimizer Docker Commands:"
	@echo "  setup      - Initial setup (copy .env, create dirs)"
	@echo "  build      - Build all Docker images"
	@echo "  up         - Start development services"
	@echo "  prod       - Start production services"
	@echo "  down       - Stop all services"
	@echo "  logs       - View logs from all services"
	@echo "  logs-f     - Follow logs from all services"
	@echo "  clean      - Clean up containers and volumes"
	@echo "  test       - Run application tests"
	@echo "  restart    - Restart all services"
	@echo "  status     - Show service status"

# Initial setup
setup:
	@echo "🚀 Setting up Video Optimizer..."
	@mkdir -p videos output logs logs/backend logs/frontend logs/nginx logs/mongodb
	@if [ ! -f .env ]; then cp .env.example .env; echo "✅ Created .env file - please edit it"; fi
	@echo "✅ Setup complete!"

# Build images
build:
	@echo "🔨 Building Docker images..."
	docker-compose build --no-cache

# Development mode
up: setup
	@echo "🚀 Starting development services..."
	docker-compose up -d
	@echo "✅ Services started!"
	@echo "Frontend: http://localhost:3000"
	@echo "Backend API: http://localhost:8001/api"

# Production mode
prod: setup
	@echo "🏭 Starting production services..."
	docker-compose -f docker-compose.prod.yml up -d
	@echo "✅ Production services started!"

# Stop services
down:
	@echo "🛑 Stopping services..."
	docker-compose down
	docker-compose -f docker-compose.prod.yml down 2>/dev/null || true

# View logs
logs:
	docker-compose logs

# Follow logs
logs-f:
	docker-compose logs -f

# Restart services
restart:
	@echo "🔄 Restarting services..."
	docker-compose restart

# Service status
status:
	@echo "📊 Service Status:"
	docker-compose ps

# Clean up
clean:
	@echo "🧹 Cleaning up..."
	docker-compose down -v
	docker-compose -f docker-compose.prod.yml down -v 2>/dev/null || true
	docker system prune -f
	@echo "✅ Cleanup complete!"

# Run tests
test:
	@echo "🧪 Running tests..."
	docker-compose exec backend python -m pytest
	@echo "✅ Tests complete!"

# Development helpers
backend-shell:
	docker-compose exec backend bash

frontend-shell:
	docker-compose exec frontend sh

db-shell:
	docker-compose exec mongodb mongosh

# Backup database
backup:
	@echo "💾 Backing up database..."
	@mkdir -p backups
	docker-compose exec mongodb mongodump --out /tmp/backup
	docker cp $$(docker-compose ps -q mongodb):/tmp/backup ./backups/backup-$$(date +%Y%m%d-%H%M%S)
	@echo "✅ Database backed up!"

# Restore database (usage: make restore BACKUP=backup-20231201-120000)
restore:
	@if [ -z "$(BACKUP)" ]; then echo "❌ Please specify BACKUP=backup-folder-name"; exit 1; fi
	@echo "📥 Restoring database from $(BACKUP)..."
	docker cp ./backups/$(BACKUP) $$(docker-compose ps -q mongodb):/tmp/restore
	docker-compose exec mongodb mongorestore /tmp/restore
	@echo "✅ Database restored!"

# Update images
update:
	@echo "📥 Updating images..."
	docker-compose pull
	docker-compose up -d --force-recreate
	@echo "✅ Images updated!"

# Check health
health:
	@echo "🏥 Checking service health..."
	@curl -s http://localhost:8001/api/ > /dev/null && echo "✅ Backend: Healthy" || echo "❌ Backend: Unhealthy"
	@curl -s http://localhost:3000/ > /dev/null && echo "✅ Frontend: Healthy" || echo "❌ Frontend: Unhealthy"
	@docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1 && echo "✅ MongoDB: Healthy" || echo "❌ MongoDB: Unhealthy"