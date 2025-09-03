Backend Dockerfile for multi-stage build
Stage 1: Base - Install dependencies that are common to all stages
FROM python:3.10-slim as base

Set working directory inside the container
WORKDIR /app

Install system dependencies including FFmpeg and HandBrake
These are necessary for the video processing logic
RUN apt-get update && 

apt-get install -y 

ffmpeg 

handbrake-cli 

&& rm -rf /var/lib/apt/lists/*

Copy requirements first for better Docker layer caching
COPY requirements.txt .

Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

Stage 2: Development - Optimized for a fast local development loop
FROM base as development

Copy all application code
COPY . .

Create temporary directories required by the application
RUN mkdir -p /tmp/video_uploads /tmp/handbrake_output

Expose the development port
EXPOSE 8001

Set environment variables for development
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

Run the server with Uvicorn and --reload for live changes
CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001", "--reload"]

Stage 3: Production - Optimized for security and performance
FROM base as production

Create a non-root user to run the application for enhanced security
RUN groupadd -r appuser && useradd -r -g appuser appuser

Copy backend source code
COPY . .

Create directories and set permissions for the non-root user
RUN mkdir -p /tmp/video_uploads /tmp/handbrake_output && 

chown -R appuser:appuser /app /tmp/video_uploads /tmp/handbrake_output

Switch to the non-root user
USER appuser

Expose the production port
EXPOSE 8001

Set environment variables for production
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV WORKERS=4

Health check to ensure the container is running and responsive
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 

CMD curl -f http://localhost:8001/api/healthcheck || exit 1

Run the application with Gunicorn, a production-grade web server
CMD ["python", "-m", "gunicorn", "server:app", "-w", "

WORKERS
", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8001", "--access-logfile", "-", "--error-logfile", "-"]
