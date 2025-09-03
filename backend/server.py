import asyncio
import os
import shutil
import subprocess
from pathlib import Path

from fastapi import FastAPI, HTTPException, BackgroundTasks, status
from pydantic import BaseModel, Field
from motor.motor_asyncio import AsyncIOMotorClient
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# --- Environment Variables ---
from dotenv import load_dotenv

load_dotenv()

MONGO_URL = os.getenv("MONGO_URL")
DB_NAME = os.getenv("DB_NAME")

# --- Globals and Initialization ---
mongo_client = AsyncIOMotorClient(MONGO_URL)
db = mongo_client[DB_NAME]

temp_dir = Path("/tmp/video_processing_temp")
temp_dir.mkdir(parents=True, exist_ok=True)

# --- FastAPI App ---
app = FastAPI(title="Video Optimizer Backend")

# --- Directory Monitoring Queue and Handlers ---
class VideoQueue:
    def __init__(self):
        self._queue = asyncio.Queue()
        self._is_processing = False

    async def add_job(self, video_path: str):
        await self._queue.put(video_path)
        if not self._is_processing:
            asyncio.create_task(self.process_video_queue())

    async def process_video_queue(self):
        self._is_processing = True
        try:
            while not self._queue.empty():
                video_path = await self._queue.get()
                print(f"Starting job for: {video_path}")
                await self.run_handbrake_job(Path(video_path))
                self._queue.task_done()
                print(f"Finished job for: {video_path}")
        finally:
            self._is_processing = False

    async def run_handbrake_job(self, input_path: Path):
        temp_path = temp_dir / input_path.name
        
        try:
            # 1. Move the input file to a temporary location
            shutil.move(str(input_path), str(temp_path))

            # 2. Get HandBrake settings (this is a placeholder)
            # You would implement your logic to determine the best settings here
            settings = await self.get_handbrake_settings()
            
            # 3. Build the HandBrake command
            output_path = input_path.parent / f"optimized_{input_path.name}"
            command = [
                "HandBrakeCLI",
                "-i", str(temp_path),
                "-o", str(output_path),
                "--preset", settings.get("preset", "Fast 1080p30"),
                "--all-audio",
                "--all-subtitles",
            ]
            
            # 4. Run the HandBrake process
            process = await asyncio.create_subprocess_exec(
                *command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                print(f"HandBrake job successful for {input_path.name}.")
                # 5. On success, delete the temporary file
                os.remove(str(temp_path))
            else:
                print(f"HandBrake job failed for {input_path.name}. Restoring original file.")
                # 6. On failure, move the temp file back to the original location
                shutil.move(str(temp_path), str(input_path))
                print(f"Error: {stderr.decode()}")

        except Exception as e:
            print(f"An error occurred during transcoding: {e}")
            if temp_path.exists():
                print(f"Restoring original file from temp: {temp_path}")
                shutil.move(str(temp_path), str(input_path))

    async def get_handbrake_settings(self):
        # This is a placeholder for your logic to dynamically get settings
        return {"preset": "Fast 1080p30"}

video_queue = VideoQueue()

class VideoFileHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory and event.src_path.lower().endswith(('.mp4', '.mov', '.mkv')):
            print(f"Detected new video file: {event.src_path}")
            asyncio.run(video_queue.add_job(event.src_path))

async def start_monitoring(directory: str):
    path_to_monitor = Path(directory)
    if not path_to_monitor.exists():
        print(f"Directory not found: {directory}")
        return

    event_handler = VideoFileHandler()
    observer = Observer()
    observer.schedule(event_handler, path_to_monitor, recursive=False)
    observer.start()
    print(f"Started monitoring directory: {directory}")
    try:
        while True:
            await asyncio.sleep(1)
    finally:
        observer.stop()
        observer.join()

@app.on_event("startup")
async def startup_db_client():
    # You would typically load the list of directories to monitor from the database here
    monitored_dirs = ["/path/to/your/video/folder"]
    
    for directory in monitored_dirs:
        # Start a new task to monitor each directory
        asyncio.create_task(start_monitoring(directory))

@app.on_event("shutdown")
async def shutdown_db_client():
    mongo_client.close()
    
# --- Pydantic Models for API ---
class Directory(BaseModel):
    path: str = Field(..., description="The path of the directory to monitor.")

# --- API Endpoints ---
@app.get("/")
async def read_root():
    return {"message": "Video Optimizer is running"}

@app.post("/monitor_directory", status_code=status.HTTP_202_ACCEPTED)
async def monitor_directory(directory: Directory):
    # In a real-world app, you'd save this path to the database
    # for persistence across restarts and trigger the monitoring task
    asyncio.create_task(start_monitoring(directory.path))
    return {"message": f"Monitoring of directory '{directory.path}' has been initiated."}
