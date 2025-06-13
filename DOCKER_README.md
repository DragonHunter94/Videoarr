# Video Optimizer - Docker Deployment

A complete Docker setup for the Video Optimization Studio that analyzes videos and generates optimal HandBrake settings.

## 🚀 Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- 2GB+ available disk space
- 4GB+ RAM recommended

### 1. Clone and Setup
```bash
# Clone the repository
git clone <your-repo-url>
cd video-optimizer

# Run the setup script
chmod +x setup.sh
./setup.sh
```

### 2. Manual Setup (Alternative)
```bash
# Create required directories
mkdir -p videos output logs

# Copy and configure environment
cp .env.example .env
# Edit .env with your settings

# Build and start services
docker-compose up -d
```

## 📋 Services Overview

| Service | Port | Description |
|---------|------|-------------|
| Frontend | 3000 | React web interface |
| Backend | 8001 | FastAPI REST API |
| MongoDB | 27017 | Database |
| Nginx | 80 | Reverse proxy (production) |

## 🎯 Usage

### Access the Application
- **Web Interface**: http://localhost:3000
- **API Documentation**: http://localhost:8001/docs
- **Health Check**: http://localhost:8001/api/

### Video Processing
1. Place video files in the `./videos` directory
2. Upload videos through the web interface
3. Review analysis and HandBrake recommendations
4. Queue encoding jobs
5. Processed videos saved to `./output` directory

## 📁 Directory Structure

```
video-optimizer/
├── backend/                 # FastAPI backend service
│   ├── Dockerfile
│   ├── server.py
│   └── requirements.txt
├── frontend/                # React frontend service  
│   ├── Dockerfile
│   ├── nginx.conf
│   └── src/
├── nginx/                   # Production nginx config
├── videos/                  # Input video directory (mount point)
├── output/                  # Processed video output
├── docker-compose.yml       # Main orchestration
├── .env.example            # Environment template
└── setup.sh               # Setup script
```

## ⚙️ Configuration

### Environment Variables (.env)
```bash
# Database
MONGO_ROOT_PASSWORD=securepassword123
MONGO_USER_PASSWORD=userpassword123

# Service Ports
BACKEND_PORT=8001
FRONTEND_PORT=3000
NGINX_PORT=80

# Directories
VIDEO_INPUT_DIR=./videos
VIDEO_OUTPUT_DIR=./output
```

### Volume Mounts
- `./videos:/app/videos:ro` - Video input (read-only)
- `./output:/app/output` - Processed output
- `video_uploads:/tmp/video_uploads` - Upload staging
- `handbrake_output:/tmp/handbrake_output` - Encoding output

## 🔧 Management Commands

### Start Services
```bash
docker-compose up -d
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f frontend
```

### Stop Services
```bash
docker-compose down
```

### Update and Restart
```bash
docker-compose pull
docker-compose up -d --force-recreate
```

### Database Management
```bash
# Access MongoDB shell
docker-compose exec mongodb mongosh

# Backup database
docker-compose exec mongodb mongodump --out /data/backup

# Restore database
docker-compose exec mongodb mongorestore /data/backup
```

## 🏭 Production Deployment

### Enable Nginx Proxy
```bash
# Add to .env
COMPOSE_PROFILES=production

# Start with nginx
docker-compose --profile production up -d
```

### SSL/TLS Configuration
1. Update `nginx/nginx.conf` with SSL settings
2. Mount certificate volumes
3. Configure domain name and DNS

### Performance Tuning
- Increase `client_max_body_size` for larger files
- Adjust worker processes based on CPU cores
- Configure MongoDB memory settings
- Set up log rotation

## 🔍 Troubleshooting

### Common Issues

**Services won't start:**
```bash
# Check system resources
docker system df
docker system prune

# Rebuild images
docker-compose build --no-cache
```

**Upload failures:**
```bash
# Check nginx upload limits
docker-compose logs frontend

# Verify backend processing
docker-compose logs backend
```

**Database connection errors:**
```bash
# Check MongoDB status
docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Verify network connectivity
docker-compose exec backend ping mongodb
```

### Log Locations
- Container logs: `docker-compose logs [service]`
- Application logs: `./logs/` directory
- Nginx logs: Inside nginx container at `/var/log/nginx/`

## 📊 Monitoring

### Health Checks
All services include health checks:
```bash
# Check service health
docker-compose ps
```

### Metrics
- MongoDB: Built-in monitoring via mongosh
- Backend: FastAPI `/docs` endpoint for API metrics
- Frontend: Nginx access logs for user metrics

## 🔐 Security

### Production Security Checklist
- [ ] Change default passwords in `.env`
- [ ] Enable SSL/TLS
- [ ] Configure firewall rules
- [ ] Set up log monitoring
- [ ] Regular security updates
- [ ] Backup strategy

### Network Security
- Services isolated on private Docker network
- Only necessary ports exposed
- Rate limiting configured
- Security headers added

## 📖 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [HandBrake CLI Guide](https://handbrake.fr/docs/en/latest/cli/cli-guide.html)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review service logs
3. Verify configuration files
4. Check resource availability