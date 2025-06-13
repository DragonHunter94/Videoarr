#!/bin/bash

# Video Optimizer Monitoring and Maintenance Script
# Monitors system health, performs backups, and handles maintenance tasks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_RETENTION_DAYS=7
LOG_RETENTION_DAYS=30
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_DISK=90

# Functions
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a logs/maintenance.log
}

check_service_health() {
    local service=$1
    local url=$2
    
    if curl -f -s --max-time 10 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $service is healthy${NC}"
        return 0
    else
        echo -e "${RED}❌ $service is not responding${NC}"
        return 1
    fi
}

check_docker_health() {
    log_message "Checking Docker service health..."
    
    local unhealthy_services=()
    
    # Get service status
    while IFS= read -r line; do
        service=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $4}')
        
        if [[ "$status" != "Up" ]] && [[ "$status" != "Up (healthy)" ]]; then
            unhealthy_services+=("$service")
        fi
    done < <(docker-compose ps --format "table {{.Name}}\t{{.Status}}" | tail -n +2)
    
    if [ ${#unhealthy_services[@]} -eq 0 ]; then
        log_message "All Docker services are healthy"
        return 0
    else
        log_message "Unhealthy services: ${unhealthy_services[*]}"
        return 1
    fi
}

check_resource_usage() {
    log_message "Checking resource usage..."
    
    # CPU usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$CPU_USAGE > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        echo -e "${YELLOW}⚠️  High CPU usage: ${CPU_USAGE}%${NC}"
    fi
    
    # Memory usage
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    if (( $(echo "$MEMORY_USAGE > $ALERT_THRESHOLD_MEMORY" | bc -l) )); then
        echo -e "${YELLOW}⚠️  High memory usage: ${MEMORY_USAGE}%${NC}"
    fi
    
    # Disk usage
    DISK_USAGE=$(df . | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    if [ "$DISK_USAGE" -gt "$ALERT_THRESHOLD_DISK" ]; then
        echo -e "${RED}🚨 High disk usage: ${DISK_USAGE}%${NC}"
    fi
    
    # Docker resource usage
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tail -n +2 | while read line; do
        container=$(echo "$line" | awk '{print $1}')
        cpu=$(echo "$line" | awk '{print $2}' | cut -d'%' -f1)
        memory=$(echo "$line" | awk '{print $3}')
        
        if (( $(echo "$cpu > 50" | bc -l) )); then
            echo -e "${YELLOW}⚠️  High CPU usage in $container: ${cpu}%${NC}"
        fi
    done
}

backup_database() {
    log_message "Starting database backup..."
    
    local backup_dir="backups/auto-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    if docker-compose ps mongodb | grep -q "Up"; then
        # Create backup
        docker-compose exec -T mongodb mongodump --out /tmp/backup --quiet
        docker cp "$(docker-compose ps -q mongodb):/tmp/backup" "$backup_dir/"
        
        # Compress backup
        tar -czf "$backup_dir.tar.gz" -C backups "$(basename "$backup_dir")"
        rm -rf "$backup_dir"
        
        log_message "Database backup completed: $backup_dir.tar.gz"
        
        # Clean old backups
        find backups/ -name "auto-backup-*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete
        log_message "Cleaned backups older than $BACKUP_RETENTION_DAYS days"
    else
        log_message "ERROR: MongoDB is not running, backup skipped"
        return 1
    fi
}

cleanup_logs() {
    log_message "Cleaning up old logs..."
    
    # Clean application logs
    find logs/ -name "*.log" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
    
    # Clean Docker logs
    docker system prune -f --filter "until=${LOG_RETENTION_DAYS}d" > /dev/null 2>&1 || true
    
    # Rotate current logs if they're too large (>100MB)
    for logfile in logs/*.log; do
        if [ -f "$logfile" ] && [ $(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile") -gt 104857600 ]; then
            mv "$logfile" "${logfile}.$(date +%Y%m%d)"
            touch "$logfile"
            log_message "Rotated large log file: $logfile"
        fi
    done
    
    log_message "Log cleanup completed"
}

check_video_processing() {
    log_message "Checking video processing status..."
    
    # Check pending jobs
    local pending_jobs=$(curl -s http://localhost:8001/api/jobs | jq -r '. | map(select(.status == "queued" or .status == "running")) | length' 2>/dev/null || echo "0")
    
    if [ "$pending_jobs" -gt "0" ]; then
        echo -e "${BLUE}📊 Active video processing jobs: $pending_jobs${NC}"
    fi
    
    # Check for failed jobs in the last 24 hours
    local failed_jobs=$(curl -s http://localhost:8001/api/jobs | jq -r '. | map(select(.status == "failed" and (.created_at | strptime("%Y-%m-%dT%H:%M:%S") | mktime) > (now - 86400))) | length' 2>/dev/null || echo "0")
    
    if [ "$failed_jobs" -gt "0" ]; then
        echo -e "${YELLOW}⚠️  Failed jobs in last 24h: $failed_jobs${NC}"
    fi
}

update_system() {
    log_message "Updating Docker images..."
    
    # Pull latest images
    docker-compose pull
    
    # Restart services with new images
    docker-compose up -d --force-recreate
    
    log_message "System update completed"
}

generate_report() {
    local report_file="logs/health-report-$(date +%Y%m%d-%H%M%S).json"
    
    # System information
    local system_info=$(cat <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "system": {
        "hostname": "$(hostname)",
        "uptime": "$(uptime -p 2>/dev/null || uptime)",
        "load_average": "$(uptime | awk -F'load average:' '{print $2}')",
        "cpu_usage": "$CPU_USAGE%",
        "memory_usage": "$MEMORY_USAGE%",
        "disk_usage": "$DISK_USAGE%"
    },
    "docker": {
        "services": $(docker-compose ps --format json 2>/dev/null || echo "[]"),
        "images": $(docker images --format json 2>/dev/null | jq -s '.' || echo "[]")
    },
    "application": {
        "backend_status": "$(curl -s http://localhost:8001/api/ > /dev/null && echo "healthy" || echo "unhealthy")",
        "frontend_status": "$(curl -s http://localhost:3000/ > /dev/null && echo "healthy" || echo "unhealthy")",
        "database_status": "$(docker-compose exec -T mongodb mongosh --eval 'db.adminCommand(\"ping\")' > /dev/null 2>&1 && echo "healthy" || echo "unhealthy")"
    }
}
EOF
)
    
    echo "$system_info" > "$report_file"
    log_message "Health report generated: $report_file"
}

show_help() {
    echo "Video Optimizer Monitoring and Maintenance"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  monitor     Run full health check and monitoring"
    echo "  backup      Backup database"
    echo "  cleanup     Clean up logs and temporary files"
    echo "  update      Update Docker images and restart services"
    echo "  report      Generate detailed health report"
    echo "  status      Show current system status"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 monitor     # Full health check"
    echo "  $0 backup      # Backup database only"
    echo "  $0 cleanup     # Clean logs and temp files"
}

main() {
    local command=${1:-monitor}
    
    # Ensure logs directory exists
    mkdir -p logs backups
    
    case $command in
        monitor)
            log_message "=== Starting full monitoring cycle ==="
            check_docker_health
            check_resource_usage
            check_service_health "Backend API" "http://localhost:8001/api/"
            check_service_health "Frontend" "http://localhost:3000/"
            check_video_processing
            generate_report
            log_message "=== Monitoring cycle completed ==="
            ;;
        backup)
            backup_database
            ;;
        cleanup)
            cleanup_logs
            ;;
        update)
            update_system
            ;;
        report)
            check_resource_usage
            generate_report
            ;;
        status)
            echo -e "${BLUE}Video Optimizer System Status${NC}"
            echo "=============================="
            docker-compose ps
            echo ""
            check_resource_usage
            ;;
        help)
            show_help
            ;;
        *)
            echo "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Install required tools if needed
if ! command -v bc > /dev/null; then
    echo "Installing bc calculator..."
    apt-get update && apt-get install -y bc > /dev/null 2>&1 || true
fi

if ! command -v jq > /dev/null; then
    echo "Installing jq JSON processor..."
    apt-get update && apt-get install -y jq > /dev/null 2>&1 || true
fi

main "$@"