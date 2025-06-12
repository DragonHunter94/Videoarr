#!/usr/bin/env python3
import os
import sys
import requests
import json
import time
import unittest
import logging
from pathlib import Path
import tempfile
import shutil

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Get backend URL from frontend .env file
def get_backend_url():
    env_file = Path('/app/frontend/.env')
    if not env_file.exists():
        logger.error("Frontend .env file not found")
        return None
    
    with open(env_file, 'r') as f:
        for line in f:
            if line.startswith('REACT_APP_BACKEND_URL='):
                backend_url = line.strip().split('=', 1)[1].strip('"\'')
                return f"{backend_url}/api"
    
    logger.error("REACT_APP_BACKEND_URL not found in .env file")
    return None

# Main test class
class VideoOptimizationBackendTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.api_url = get_backend_url()
        if not cls.api_url:
            logger.error("Failed to get backend URL")
            sys.exit(1)
        
        logger.info(f"Using backend API URL: {cls.api_url}")
        
        # Create a temporary directory for test files
        cls.temp_dir = tempfile.mkdtemp()
        
        # Create a small test video file
        cls.create_test_video()
    
    @classmethod
    def tearDownClass(cls):
        # Clean up temporary directory
        shutil.rmtree(cls.temp_dir)
    
    @classmethod
    def create_test_video(cls):
        """Create a small test video file using ffmpeg"""
        try:
            # Path for the test video
            cls.test_video_path = os.path.join(cls.temp_dir, "test_video.mp4")
            
            # Use ffmpeg to create a 5-second test video
            ffmpeg_cmd = (
                f"ffmpeg -y -f lavfi -i testsrc=duration=5:size=640x480:rate=30 "
                f"-c:v libx264 -crf 23 -pix_fmt yuv420p {cls.test_video_path}"
            )
            
            logger.info(f"Creating test video with command: {ffmpeg_cmd}")
            result = os.system(ffmpeg_cmd)
            
            if result != 0:
                logger.error("Failed to create test video")
                return False
            
            logger.info(f"Test video created at: {cls.test_video_path}")
            return True
        except Exception as e:
            logger.error(f"Error creating test video: {str(e)}")
            return False
    
    def test_01_root_endpoint(self):
        """Test the root API endpoint"""
        logger.info("Testing root endpoint")
        response = requests.get(f"{self.api_url}/")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("message", data)
        self.assertIn("version", data)
        logger.info("Root endpoint test passed")
    
    def test_02_video_analysis(self):
        """Test video analysis with FFmpeg integration"""
        logger.info("Testing video analysis endpoint")
        
        # Check if test video exists
        self.assertTrue(os.path.exists(self.test_video_path), "Test video file not found")
        
        # Upload video for analysis
        with open(self.test_video_path, 'rb') as f:
            files = {'file': (os.path.basename(self.test_video_path), f, 'video/mp4')}
            response = requests.post(f"{self.api_url}/analyze-video", files=files)
        
        self.assertEqual(response.status_code, 200, f"Analysis failed with status {response.status_code}: {response.text}")
        
        # Verify response structure
        analysis = response.json()
        logger.info(f"Analysis response: {json.dumps(analysis, indent=2)}")
        
        # Store analysis ID for later tests
        self.__class__.analysis_id = analysis['id']
        
        # Check required fields
        required_fields = [
            'id', 'filename', 'file_path', 'file_size', 'duration', 
            'resolution', 'width', 'height', 'video_codec', 'audio_codec',
            'aspect_ratio', 'container_format'
        ]
        
        for field in required_fields:
            self.assertIn(field, analysis, f"Missing field: {field}")
        
        # Verify video metadata
        self.assertEqual(analysis['filename'], os.path.basename(self.test_video_path))
        self.assertGreater(analysis['file_size'], 0)
        self.assertGreater(analysis['duration'], 0)
        self.assertEqual(analysis['width'], 640)
        self.assertEqual(analysis['height'], 480)
        self.assertEqual(analysis['resolution'], "640x480")
        self.assertEqual(analysis['video_codec'], "h264")
        
        logger.info("Video analysis test passed")
    
    def test_03_get_analyses(self):
        """Test retrieving all video analyses"""
        logger.info("Testing get analyses endpoint")
        
        response = requests.get(f"{self.api_url}/analyses")
        self.assertEqual(response.status_code, 200)
        
        analyses = response.json()
        self.assertIsInstance(analyses, list)
        self.assertGreater(len(analyses), 0, "No analyses found")
        
        # Verify our test video analysis is in the list
        found = False
        for analysis in analyses:
            if hasattr(self.__class__, 'analysis_id') and analysis['id'] == self.__class__.analysis_id:
                found = True
                break
        
        self.assertTrue(found, "Our test analysis was not found in the analyses list")
        logger.info("Get analyses test passed")
    
    def test_04_handbrake_settings(self):
        """Test handbrake settings generation algorithm"""
        logger.info("Testing handbrake settings endpoint")
        
        # Ensure we have an analysis ID
        self.assertTrue(hasattr(self.__class__, 'analysis_id'), "No analysis ID available")
        
        response = requests.get(f"{self.api_url}/analysis/{self.__class__.analysis_id}/settings")
        self.assertEqual(response.status_code, 200)
        
        settings = response.json()
        logger.info(f"Handbrake settings: {json.dumps(settings, indent=2)}")
        
        # Check required fields
        required_fields = [
            'id', 'video_analysis_id', 'preset', 'video_encoder', 
            'quality', 'audio_encoder', 'container', 
            'estimated_compression', 'full_command', 'reasoning'
        ]
        
        for field in required_fields:
            self.assertIn(field, settings, f"Missing field: {field}")
        
        # Verify settings are appropriate for our test video
        self.assertEqual(settings['video_analysis_id'], self.__class__.analysis_id)
        self.assertIn(settings['video_encoder'], ['x264', 'x265'])
        self.assertIn(settings['preset'], ['Very Slow', 'Slow', 'Medium', 'Fast'])
        self.assertIn(settings['container'], ['mp4', 'mkv'])
        self.assertGreater(settings['estimated_compression'], 0)
        self.assertLess(settings['estimated_compression'], 1)
        
        # Store settings ID for job queue test
        self.__class__.settings_id = settings['id']
        
        logger.info("Handbrake settings test passed")
    
    def test_05_queue_handbrake_job(self):
        """Test handbrake job queue system"""
        logger.info("Testing handbrake job queue endpoint")
        
        # Ensure we have an analysis ID
        self.assertTrue(hasattr(self.__class__, 'analysis_id'), "No analysis ID available")
        
        response = requests.post(f"{self.api_url}/queue-handbrake/{self.__class__.analysis_id}")
        self.assertEqual(response.status_code, 200)
        
        job_data = response.json()
        logger.info(f"Job queue response: {json.dumps(job_data, indent=2)}")
        
        self.assertIn('message', job_data)
        self.assertIn('job_id', job_data)
        
        # Store job ID for later tests
        self.__class__.job_id = job_data['job_id']
        
        logger.info("Handbrake job queue test passed")
    
    def test_06_get_jobs(self):
        """Test retrieving all handbrake jobs"""
        logger.info("Testing get jobs endpoint")
        
        # Wait a moment for job processing to start
        time.sleep(2)
        
        response = requests.get(f"{self.api_url}/jobs")
        self.assertEqual(response.status_code, 200)
        
        jobs = response.json()
        self.assertIsInstance(jobs, list)
        self.assertGreater(len(jobs), 0, "No jobs found")
        
        # Verify our test job is in the list
        found = False
        for job in jobs:
            if hasattr(self.__class__, 'job_id') and job['id'] == self.__class__.job_id:
                found = True
                # Check job status
                self.assertIn(job['status'], ['queued', 'running', 'completed', 'failed'])
                break
        
        self.assertTrue(found, "Our test job was not found in the jobs list")
        logger.info("Get jobs test passed")
    
    def test_07_directory_config(self):
        """Test directory configuration API"""
        logger.info("Testing directory config endpoints")
        
        # Create a test directory config
        test_dir = os.path.join(self.temp_dir, "test_monitor_dir")
        os.makedirs(test_dir, exist_ok=True)
        
        config_data = {
            "path": test_dir,
            "monitor_enabled": True,
            "auto_analyze": True
        }
        
        # Create directory config
        response = requests.post(
            f"{self.api_url}/directory-config", 
            json=config_data
        )
        self.assertEqual(response.status_code, 200)
        
        config = response.json()
        logger.info(f"Directory config response: {json.dumps(config, indent=2)}")
        
        # Check required fields
        required_fields = ['id', 'path', 'monitor_enabled', 'auto_analyze']
        for field in required_fields:
            self.assertIn(field, config, f"Missing field: {field}")
        
        # Verify config values
        self.assertEqual(config['path'], test_dir)
        self.assertEqual(config['monitor_enabled'], True)
        self.assertEqual(config['auto_analyze'], True)
        
        # Store config ID
        self.__class__.config_id = config['id']
        
        # Get all directory configs
        response = requests.get(f"{self.api_url}/directory-configs")
        self.assertEqual(response.status_code, 200)
        
        configs = response.json()
        self.assertIsInstance(configs, list)
        
        # Verify our test config is in the list
        found = False
        for cfg in configs:
            if cfg['id'] == self.__class__.config_id:
                found = True
                break
        
        self.assertTrue(found, "Our test config was not found in the configs list")
        logger.info("Directory config tests passed")

if __name__ == "__main__":
    logger.info("Starting backend tests")
    unittest.main(verbosity=2)
