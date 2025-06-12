from fastapi import FastAPI, APIRouter, File, UploadFile, HTTPException, BackgroundTasks, Request
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import uuid
from datetime import datetime
import ffmpeg
import subprocess
import json
import aiofiles
import tempfile
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import threading
import psutil

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# Create the main app without a prefix
app = FastAPI(title="Video Optimization App", description="Analyze videos and optimize Handbrake settings")

# Create a router with the /api prefix
api_router = APIRouter(prefix="/api")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Models
class VideoAnalysis(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    filename: str
    file_path: str
    file_size: int
    duration: float
    resolution: str
    width: int
    height: int
    video_codec: str
    audio_codec: str
    video_bitrate: Optional[int] = None
    audio_bitrate: Optional[int] = None
    frame_rate: Optional[float] = None
    aspect_ratio: str
    container_format: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    analysis_status: str = "completed"

class HandbrakeSettings(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    video_analysis_id: str
    preset: str
    video_encoder: str
    quality: str
    audio_encoder: str
    container: str
    estimated_compression: float
    full_command: str
    reasoning: str
    created_at: datetime = Field(default_factory=datetime.utcnow)

class DirectoryConfig(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    path: str
    monitor_enabled: bool = True
    auto_analyze: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)

class DirectoryConfigCreate(BaseModel):
    path: str
    monitor_enabled: bool = True
    auto_analyze: bool = True

class HandbrakeJob(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    video_analysis_id: str
    input_file: str
    output_file: str
    handbrake_settings_id: str
    status: str = "queued"  # queued, running, completed, failed
    progress: float = 0.0
    created_at: datetime = Field(default_factory=datetime.utcnow)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    error_message: Optional[str] = None

# Video Analysis Functions
def analyze_video_with_ffmpeg(file_path: str) -> Dict[str, Any]:
    """Analyze video file using FFmpeg and return comprehensive metadata"""
    try:
        # Use ffprobe to get video information
        probe = ffmpeg.probe(file_path)
        
        video_stream = None
        audio_stream = None
        
        # Find video and audio streams
        for stream in probe['streams']:
            if stream['codec_type'] == 'video' and video_stream is None:
                video_stream = stream
            elif stream['codec_type'] == 'audio' and audio_stream is None:
                audio_stream = stream
        
        if not video_stream:
            raise HTTPException(status_code=400, detail="No video stream found")
        
        # Extract video information
        width = int(video_stream.get('width', 0))
        height = int(video_stream.get('height', 0))
        duration = float(probe['format'].get('duration', 0))
        file_size = int(probe['format'].get('size', 0))
        
        # Calculate frame rate
        frame_rate = None
        if 'r_frame_rate' in video_stream:
            try:
                num, den = video_stream['r_frame_rate'].split('/')
                frame_rate = float(num) / float(den) if float(den) != 0 else None
            except:
                frame_rate = None
        
        # Calculate bitrates
        video_bitrate = None
        if 'bit_rate' in video_stream:
            video_bitrate = int(video_stream['bit_rate'])
        elif duration > 0:
            # Estimate video bitrate
            total_bitrate = (file_size * 8) / duration
            video_bitrate = int(total_bitrate * 0.8)  # Assume 80% is video
        
        audio_bitrate = None
        if audio_stream and 'bit_rate' in audio_stream:
            audio_bitrate = int(audio_stream['bit_rate'])
        
        analysis = {
            'filename': Path(file_path).name,
            'file_path': file_path,
            'file_size': file_size,
            'duration': duration,
            'resolution': f"{width}x{height}",
            'width': width,
            'height': height,
            'video_codec': video_stream.get('codec_name', 'unknown'),
            'audio_codec': audio_stream.get('codec_name', 'unknown') if audio_stream else 'none',
            'video_bitrate': video_bitrate,
            'audio_bitrate': audio_bitrate,
            'frame_rate': frame_rate,
            'aspect_ratio': video_stream.get('display_aspect_ratio', 'unknown'),
            'container_format': probe['format'].get('format_name', 'unknown')
        }
        
        return analysis
        
    except Exception as e:
        logger.error(f"Error analyzing video {file_path}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Video analysis failed: {str(e)}")

def generate_handbrake_settings(analysis: VideoAnalysis) -> HandbrakeSettings:
    """Generate optimal Handbrake settings based on video analysis"""
    try:
        # Determine optimal settings based on resolution and content
        width, height = analysis.width, analysis.height
        file_size_mb = analysis.file_size / (1024 * 1024)
        duration_minutes = analysis.duration / 60
        
        # Calculate current bitrate per pixel
        pixels = width * height
        current_bitrate_per_pixel = (analysis.video_bitrate or 0) / pixels if pixels > 0 else 0
        
        # Determine quality settings based on resolution
        if height >= 2160:  # 4K
            preset = "Very Slow"
            quality = "20"
            video_encoder = "x265"
            estimated_compression = 0.4
            reasoning = "4K content: Using x265 with CRF 20 for maximum compression while maintaining quality"
        elif height >= 1080:  # 1080p
            preset = "Slow"
            quality = "22" if current_bitrate_per_pixel > 0.15 else "20"
            video_encoder = "x264"
            estimated_compression = 0.5
            reasoning = "1080p content: Using x264 with balanced settings for good compression"
        elif height >= 720:  # 720p
            preset = "Medium"
            quality = "23"
            video_encoder = "x264"
            estimated_compression = 0.6
            reasoning = "720p content: Using medium preset for faster encoding"
        else:  # SD content
            preset = "Fast"
            quality = "25"
            video_encoder = "x264"
            estimated_compression = 0.7
            reasoning = "SD content: Using fast preset with higher CRF"
        
        # Audio settings
        if analysis.audio_codec in ['aac', 'mp3']:
            audio_encoder = "copy"
        else:
            audio_encoder = "aac"
        
        # Container format
        container = "mp4"
        
        # Build HandBrake command
        input_file = analysis.file_path
        output_file = f"{Path(input_file).stem}_optimized.{container}"
        
        handbrake_cmd = [
            "HandBrakeCLI",
            "-i", input_file,
            "-o", output_file,
            "--preset", preset,
            "--encoder", video_encoder,
            "--quality", quality,
            "--aencoder", audio_encoder,
            "--format", container
        ]
        
        # Add x265 specific options for better compression
        if video_encoder == "x265":
            handbrake_cmd.extend(["--encoder-preset", "medium"])
        
        full_command = " ".join(handbrake_cmd)
        
        settings = HandbrakeSettings(
            video_analysis_id=analysis.id,
            preset=preset,
            video_encoder=video_encoder,
            quality=quality,
            audio_encoder=audio_encoder,
            container=container,
            estimated_compression=estimated_compression,
            full_command=full_command,
            reasoning=reasoning
        )
        
        return settings
        
    except Exception as e:
        logger.error(f"Error generating Handbrake settings: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Settings generation failed: {str(e)}")

async def run_handbrake_job(job_id: str):
    """Run Handbrake encoding job in background"""
    try:
        # Get job details
        job_doc = await db.handbrake_jobs.find_one({"id": job_id})
        if not job_doc:
            logger.error(f"Job {job_id} not found")
            return
        
        job = HandbrakeJob(**job_doc)
        
        # Update job status to running
        await db.handbrake_jobs.update_one(
            {"id": job_id},
            {"$set": {"status": "running", "started_at": datetime.utcnow()}}
        )
        
        # Get Handbrake settings
        settings_doc = await db.handbrake_settings.find_one({"id": job.handbrake_settings_id})
        if not settings_doc:
            raise Exception("Handbrake settings not found")
        
        settings = HandbrakeSettings(**settings_doc)
        
        # Parse and execute Handbrake command
        cmd_parts = settings.full_command.split()[1:]  # Remove 'HandBrakeCLI'
        cmd = ["HandBrakeCLI"] + cmd_parts
        
        # Update output path to be in a proper output directory
        output_dir = Path("/tmp/handbrake_output")
        output_dir.mkdir(exist_ok=True)
        
        # Find -o flag and update output path
        for i, part in enumerate(cmd):
            if part == "-o" and i + 1 < len(cmd):
                original_name = Path(cmd[i + 1]).name
                cmd[i + 1] = str(output_dir / original_name)
                break
        
        logger.info(f"Starting Handbrake job: {' '.join(cmd)}")
        
        # Run Handbrake
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        
        # Monitor progress (simplified - just wait for completion)
        stdout, stderr = process.communicate()
        
        if process.returncode == 0:
            # Job completed successfully
            await db.handbrake_jobs.update_one(
                {"id": job_id},
                {"$set": {
                    "status": "completed",
                    "progress": 100.0,
                    "completed_at": datetime.utcnow()
                }}
            )
            logger.info(f"Handbrake job {job_id} completed successfully")
        else:
            # Job failed
            await db.handbrake_jobs.update_one(
                {"id": job_id},
                {"$set": {
                    "status": "failed",
                    "error_message": stderr,
                    "completed_at": datetime.utcnow()
                }}
            )
            logger.error(f"Handbrake job {job_id} failed: {stderr}")
            
    except Exception as e:
        logger.error(f"Error running Handbrake job {job_id}: {str(e)}")
        await db.handbrake_jobs.update_one(
            {"id": job_id},
            {"$set": {
                "status": "failed",
                "error_message": str(e),
                "completed_at": datetime.utcnow()
            }}
        )

# API Routes
@api_router.get("/")
async def root():
    return {"message": "Video Optimization App API", "version": "1.0.0"}

@api_router.post("/analyze-video", response_model=VideoAnalysis)
async def analyze_video_file(file: UploadFile = File(...)):
    """Upload and analyze a video file"""
    try:
        # Create temp directory for uploaded files
        temp_dir = Path("/tmp/video_uploads")
        temp_dir.mkdir(exist_ok=True)
        
        # Save uploaded file
        file_path = temp_dir / file.filename
        async with aiofiles.open(file_path, 'wb') as f:
            content = await file.read()
            await f.write(content)
        
        # Analyze video
        analysis_data = analyze_video_with_ffmpeg(str(file_path))
        analysis = VideoAnalysis(**analysis_data)
        
        # Save analysis to database
        await db.video_analyses.insert_one(analysis.dict())
        
        # Generate Handbrake settings
        handbrake_settings = generate_handbrake_settings(analysis)
        await db.handbrake_settings.insert_one(handbrake_settings.dict())
        
        logger.info(f"Successfully analyzed video: {file.filename}")
        return analysis
        
    except Exception as e:
        logger.error(f"Error in analyze_video_file: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@api_router.get("/analyses", response_model=List[VideoAnalysis])
async def get_video_analyses():
    """Get all video analyses"""
    try:
        analyses = await db.video_analyses.find().sort("created_at", -1).to_list(100)
        return [VideoAnalysis(**analysis) for analysis in analyses]
    except Exception as e:
        logger.error(f"Error getting analyses: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@api_router.get("/analysis/{analysis_id}/settings", response_model=HandbrakeSettings)
async def get_handbrake_settings(analysis_id: str):
    """Get Handbrake settings for a video analysis"""
    try:
        settings = await db.handbrake_settings.find_one({"video_analysis_id": analysis_id})
        if not settings:
            raise HTTPException(status_code=404, detail="Settings not found")
        return HandbrakeSettings(**settings)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting settings: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@api_router.post("/queue-handbrake/{analysis_id}")
async def queue_handbrake_job(analysis_id: str, background_tasks: BackgroundTasks):
    """Queue a Handbrake encoding job"""
    try:
        # Get analysis
        analysis_doc = await db.video_analyses.find_one({"id": analysis_id})
        if not analysis_doc:
            raise HTTPException(status_code=404, detail="Analysis not found")
        
        analysis = VideoAnalysis(**analysis_doc)
        
        # Get settings
        settings_doc = await db.handbrake_settings.find_one({"video_analysis_id": analysis_id})
        if not settings_doc:
            raise HTTPException(status_code=404, detail="Settings not found")
        
        settings = HandbrakeSettings(**settings_doc)
        
        # Create job
        job = HandbrakeJob(
            video_analysis_id=analysis_id,
            input_file=analysis.file_path,
            output_file=f"{Path(analysis.file_path).stem}_optimized.mp4",
            handbrake_settings_id=settings.id
        )
        
        # Save job to database
        await db.handbrake_jobs.insert_one(job.dict())
        
        # Queue background task
        background_tasks.add_task(run_handbrake_job, job.id)
        
        return {"message": "Job queued successfully", "job_id": job.id}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error queuing job: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@api_router.get("/jobs", response_model=List[HandbrakeJob])
async def get_handbrake_jobs():
    """Get all Handbrake jobs"""
    try:
        jobs = await db.handbrake_jobs.find().sort("created_at", -1).to_list(100)
        return [HandbrakeJob(**job) for job in jobs]
    except Exception as e:
        logger.error(f"Error getting jobs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@api_router.post("/directory-config", response_model=DirectoryConfig)
async def create_directory_config(config: DirectoryConfigCreate):
    """Configure a directory for monitoring"""
    try:
        directory_config = DirectoryConfig(**config.dict())
        await db.directory_configs.insert_one(directory_config.dict())
        return directory_config
    except Exception as e:
        logger.error(f"Error creating directory config: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@api_router.get("/directory-configs", response_model=List[DirectoryConfig])
async def get_directory_configs():
    """Get all directory configurations"""
    try:
        configs = await db.directory_configs.find().to_list(100)
        return [DirectoryConfig(**config) for config in configs]
    except Exception as e:
        logger.error(f"Error getting directory configs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Include the router in the main app
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
