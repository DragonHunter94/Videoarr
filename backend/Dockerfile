# Backend Dockerfile
FROM python:3.11-slim

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

# Copy backend source code
COPY . .

# Create directories for video uploads and output
RUN mkdir -p /tmp/video_uploads /tmp/handbrake_output

# Expose port
EXPOSE 8001

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8001/api/ || exit 1

# Run the application
CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001", "--reload"]