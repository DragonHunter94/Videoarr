# Backend Dockerfile
FROM python:3.11-slim as base

# Set working directory
WORKDIR /app

# Install system dependencies including FFmpeg and HandBrake
RUN apt-get update && apt-get install -y \
    ffmpeg \
    handbrake-cli \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Development stage
FROM base as development
COPY . .
RUN mkdir -p /tmp/video_uploads /tmp/handbrake_output
EXPOSE 8001
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001", "--reload"]

# Production stage
FROM base as production

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy backend source code
COPY . .

# Create directories and set permissions
RUN mkdir -p /tmp/video_uploads /tmp/handbrake_output /app/logs && \
    chown -R appuser:appuser /app /tmp/video_uploads /tmp/handbrake_output

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8001

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV WORKERS=4

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8001/api/ || exit 1

# Run the application with gunicorn in production
CMD ["python", "-m", "gunicorn", "server:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8001", "--access-logfile", "-", "--error-logfile", "-"]