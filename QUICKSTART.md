# Quick Start Guide for Video Optimizer Docker

## 🚀 5-Minute Setup

### Prerequisites Check
```bash
# Check if Docker is installed
docker --version
docker-compose --version

# If not installed, install Docker:
# Ubuntu/Debian: sudo apt install docker.io docker-compose
# CentOS/RHEL: sudo yum install docker docker-compose
# macOS: Download Docker Desktop
# Windows: Download Docker Desktop
```

### One-Command Setup
```bash
# Clone and start
git clone <your-repo> video-optimizer
cd video-optimizer
./setup.sh
```

### Manual Setup (3 steps)
```bash
# 1. Setup environment
make setup

# 2. Start services
make up

# 3. Check status
make health
```

## 🌐 Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| **Web App** | http://localhost:3000 | Main interface |
| **API Docs** | http://localhost:8001/docs | API documentation |
| **Health** | http://localhost:8001/api/ | Service status |

## 📁 Video Processing

### Upload Videos
1. **Web Interface**: Drag & drop at http://localhost:3000
2. **File System**: Place files in `./videos/` directory

### View Results
- **Analysis**: See video metadata and optimization recommendations
- **Output**: Processed videos appear in `./output/` directory

## 🛠️ Common Commands

```bash
# Start/Stop
make up          # Start all services
make down        # Stop all services
make restart     # Restart services

# Monitoring
make logs        # View all logs
make logs-f      # Follow logs in real-time
make status      # Service status
make health      # Health check

# Maintenance
make backup      # Backup database
make clean       # Full cleanup
make update      # Update images

# Production
make prod        # Start production mode
```

## 🔧 Troubleshooting

### Services Won't Start
```bash
# Check Docker status
sudo systemctl status docker

# Free up resources
docker system prune -f

# Rebuild images
make build
```

### Upload Issues
```bash
# Check upload limits
make logs frontend

# Verify backend processing
make logs backend

# Test upload endpoint
curl -F "file=@test.mp4" http://localhost:8001/api/test-upload
```

### Database Issues
```bash
# Access MongoDB
make db-shell

# Check connection
docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Reset database (⚠️ deletes all data)
docker-compose down -v
make up
```

## 📊 Configuration

### Environment Variables
Edit `.env` file:
```bash
# Ports
BACKEND_PORT=8001
FRONTEND_PORT=3000

# Directories
VIDEO_INPUT_DIR=./videos
VIDEO_OUTPUT_DIR=./output

# Security
MONGO_ROOT_PASSWORD=your-secure-password
```

### Resource Limits
For large video files, increase Docker resources:
- **Memory**: 4GB+ recommended
- **Disk**: 10GB+ free space
- **CPU**: 2+ cores for encoding

## 🔐 Security Notes

### Development
- Default passwords in `.env.example`
- All ports exposed to localhost
- No SSL/TLS encryption

### Production
- Change all passwords in `.env`
- Use `make prod` for production mode
- Configure SSL certificates
- Restrict port access

## 📈 Performance Tips

### Large Files
- Use `./videos/` directory for better performance
- Enable hardware acceleration if available
- Monitor disk space during processing

### Scaling
- Increase worker processes in production
- Use external database for multiple instances
- Configure load balancer for web interface

## 🆘 Support

### Logs
```bash
# View specific service logs
docker-compose logs backend
docker-compose logs frontend
docker-compose logs mongodb

# Save logs to file
docker-compose logs > debug.log
```

### Reset Everything
```bash
# Nuclear option - resets everything
make clean
rm -rf videos/* output/* logs/*
make setup
make up
```

### Getting Help
1. Run `./validate-docker.sh` to check configuration
2. Check service logs for errors
3. Verify port availability
4. Ensure sufficient disk space and memory