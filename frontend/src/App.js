import React, { useState, useEffect } from "react";
import "./App.css";
import axios from "axios";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

// Components
const VideoUpload = ({ onUploadSuccess }) => {
  const [uploading, setUploading] = useState(false);
  const [dragActive, setDragActive] = useState(false);

  const handleFileUpload = async (file) => {
    if (!file || !file.type.startsWith('video/')) {
      alert('Please select a valid video file');
      return;
    }

    setUploading(true);
    try {
      const formData = new FormData();
      formData.append('file', file);

      const response = await axios.post(`${API}/analyze-video`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

      onUploadSuccess(response.data);
    } catch (error) {
      console.error('Upload failed:', error);
      alert('Failed to upload and analyze video. Please try again.');
    } finally {
      setUploading(false);
    }
  };

  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileUpload(e.dataTransfer.files[0]);
    }
  };

  const handleFileSelect = (e) => {
    if (e.target.files && e.target.files[0]) {
      handleFileUpload(e.target.files[0]);
    }
  };

  return (
    <div className="bg-white rounded-xl shadow-lg p-8 mb-8">
      <h2 className="text-2xl font-bold text-gray-800 mb-6">Upload Video for Analysis</h2>
      
      <div
        className={`border-2 border-dashed rounded-lg p-12 text-center transition-all duration-200 ${
          dragActive 
            ? 'border-blue-500 bg-blue-50' 
            : 'border-gray-300 hover:border-gray-400'
        }`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
      >
        {uploading ? (
          <div className="space-y-4">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
            <p className="text-gray-600">Analyzing video...</p>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="text-gray-400">
              <svg className="mx-auto h-16 w-16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
              </svg>
            </div>
            <div>
              <p className="text-lg text-gray-600 mb-2">
                Drag and drop your video file here, or
              </p>
              <label className="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors cursor-pointer">
                Browse Files
                <input
                  type="file"
                  accept="video/*"
                  onChange={handleFileSelect}
                  className="hidden"
                />
              </label>
            </div>
            <p className="text-sm text-gray-500">
              Supports MP4, AVI, MKV, MOV, and other common video formats
            </p>
          </div>
        )}
      </div>
    </div>
  );
};

const VideoAnalysisCard = ({ analysis, onQueueJob, onViewSettings }) => {
  const formatFileSize = (bytes) => {
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    if (bytes === 0) return '0 Bytes';
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
  };

  const formatDuration = (seconds) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);
    
    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className="bg-white rounded-xl shadow-lg p-6 hover:shadow-xl transition-shadow">
      <div className="flex justify-between items-start mb-4">
        <h3 className="text-xl font-semibold text-gray-800 truncate flex-1 mr-4">
          {analysis.filename}
        </h3>
        <div className="flex space-x-2">
          <button
            onClick={() => onViewSettings(analysis.id)}
            className="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm"
          >
            View Settings
          </button>
          <button
            onClick={() => onQueueJob(analysis.id)}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm"
          >
            Queue Job
          </button>
        </div>
      </div>
      
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
        <div>
          <span className="text-gray-500">Resolution:</span>
          <p className="font-medium">{analysis.resolution}</p>
        </div>
        <div>
          <span className="text-gray-500">Duration:</span>
          <p className="font-medium">{formatDuration(analysis.duration)}</p>
        </div>
        <div>
          <span className="text-gray-500">File Size:</span>
          <p className="font-medium">{formatFileSize(analysis.file_size)}</p>
        </div>
        <div>
          <span className="text-gray-500">Video Codec:</span>
          <p className="font-medium">{analysis.video_codec}</p>
        </div>
        <div>
          <span className="text-gray-500">Audio Codec:</span>
          <p className="font-medium">{analysis.audio_codec}</p>
        </div>
        <div>
          <span className="text-gray-500">Frame Rate:</span>
          <p className="font-medium">{analysis.frame_rate ? `${analysis.frame_rate.toFixed(2)} fps` : 'N/A'}</p>
        </div>
        <div>
          <span className="text-gray-500">Video Bitrate:</span>
          <p className="font-medium">{analysis.video_bitrate ? `${Math.round(analysis.video_bitrate / 1000)} kbps` : 'N/A'}</p>
        </div>
        <div>
          <span className="text-gray-500">Container:</span>
          <p className="font-medium">{analysis.container_format}</p>
        </div>
      </div>
    </div>
  );
};

const HandbrakeSettingsModal = ({ isOpen, onClose, settings, onQueue }) => {
  if (!isOpen || !settings) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl max-w-4xl w-full max-h-90vh overflow-y-auto">
        <div className="p-6">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-2xl font-bold text-gray-800">Recommended Handbrake Settings</h2>
            <button
              onClick={onClose}
              className="text-gray-500 hover:text-gray-700 text-2xl"
            >
              ×
            </button>
          </div>
          
          <div className="space-y-6">
            <div className="bg-blue-50 p-4 rounded-lg">
              <h3 className="font-semibold text-blue-800 mb-2">Optimization Reasoning</h3>
              <p className="text-blue-700">{settings.reasoning}</p>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <h3 className="font-semibold text-gray-800">Video Settings</h3>
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Preset:</span>
                    <span className="font-medium">{settings.preset}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Encoder:</span>
                    <span className="font-medium">{settings.video_encoder}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Quality (CRF):</span>
                    <span className="font-medium">{settings.quality}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Container:</span>
                    <span className="font-medium">{settings.container}</span>
                  </div>
                </div>
              </div>
              
              <div className="space-y-4">
                <h3 className="font-semibold text-gray-800">Audio Settings</h3>
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Audio Encoder:</span>
                    <span className="font-medium">{settings.audio_encoder}</span>
                  </div>
                </div>
                
                <h3 className="font-semibold text-gray-800 mt-6">Estimated Results</h3>
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Expected Compression:</span>
                    <span className="font-medium text-green-600">
                      {Math.round((1 - settings.estimated_compression) * 100)}% size reduction
                    </span>
                  </div>
                </div>
              </div>
            </div>
            
            <div className="space-y-4">
              <h3 className="font-semibold text-gray-800">Full Handbrake Command</h3>
              <div className="bg-gray-100 p-4 rounded-lg">
                <code className="text-sm text-gray-800 break-all">{settings.full_command}</code>
              </div>
            </div>
            
            <div className="flex justify-end space-x-4 pt-4 border-t">
              <button
                onClick={onClose}
                className="px-6 py-2 text-gray-600 hover:text-gray-800 transition-colors"
              >
                Close
              </button>
              <button
                onClick={() => onQueue(settings.video_analysis_id)}
                className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors"
              >
                Queue Encoding Job
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const JobsPanel = ({ jobs }) => {
  const getStatusColor = (status) => {
    switch (status) {
      case 'completed': return 'text-green-600 bg-green-100';
      case 'running': return 'text-blue-600 bg-blue-100';
      case 'failed': return 'text-red-600 bg-red-100';
      default: return 'text-yellow-600 bg-yellow-100';
    }
  };

  return (
    <div className="bg-white rounded-xl shadow-lg p-6">
      <h2 className="text-2xl font-bold text-gray-800 mb-6">Handbrake Jobs</h2>
      
      {jobs.length === 0 ? (
        <p className="text-gray-500 text-center py-8">No encoding jobs yet</p>
      ) : (
        <div className="space-y-4">
          {jobs.map((job) => (
            <div key={job.id} className="border rounded-lg p-4">
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <h3 className="font-medium text-gray-800">{job.input_file.split('/').pop()}</h3>
                  <p className="text-sm text-gray-600 mt-1">Output: {job.output_file}</p>
                </div>
                <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(job.status)}`}>
                  {job.status.charAt(0).toUpperCase() + job.status.slice(1)}
                </span>
              </div>
              
              {job.status === 'running' && (
                <div className="mt-3">
                  <div className="bg-gray-200 rounded-full h-2">
                    <div 
                      className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                      style={{ width: `${job.progress}%` }}
                    ></div>
                  </div>
                  <p className="text-sm text-gray-600 mt-1">{job.progress.toFixed(1)}% complete</p>
                </div>
              )}
              
              {job.error_message && (
                <div className="mt-3 p-3 bg-red-50 rounded-lg">
                  <p className="text-sm text-red-700">{job.error_message}</p>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

function App() {
  const [analyses, setAnalyses] = useState([]);
  const [jobs, setJobs] = useState([]);
  const [selectedSettings, setSelectedSettings] = useState(null);
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchAnalyses();
    fetchJobs();
    
    // Set up polling for job updates
    const interval = setInterval(fetchJobs, 5000);
    return () => clearInterval(interval);
  }, []);

  const fetchAnalyses = async () => {
    try {
      const response = await axios.get(`${API}/analyses`);
      setAnalyses(response.data);
    } catch (error) {
      console.error('Failed to fetch analyses:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchJobs = async () => {
    try {
      const response = await axios.get(`${API}/jobs`);
      setJobs(response.data);
    } catch (error) {
      console.error('Failed to fetch jobs:', error);
    }
  };

  const handleUploadSuccess = (analysis) => {
    setAnalyses(prev => [analysis, ...prev]);
  };

  const handleViewSettings = async (analysisId) => {
    try {
      const response = await axios.get(`${API}/analysis/${analysisId}/settings`);
      setSelectedSettings(response.data);
      setShowSettingsModal(true);
    } catch (error) {
      console.error('Failed to fetch settings:', error);
      alert('Failed to fetch Handbrake settings');
    }
  };

  const handleQueueJob = async (analysisId) => {
    try {
      await axios.post(`${API}/queue-handbrake/${analysisId}`);
      alert('Encoding job queued successfully!');
      fetchJobs();
      setShowSettingsModal(false);
    } catch (error) {
      console.error('Failed to queue job:', error);
      alert('Failed to queue encoding job');
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      {/* Header */}
      <div className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 py-6">
          <div className="flex items-center space-x-3">
            <div className="bg-blue-600 p-2 rounded-lg">
              <svg className="h-8 w-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </div>
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Video Optimization Studio</h1>
              <p className="text-gray-600">Analyze videos and optimize Handbrake settings for maximum compression</p>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-4 py-8">
        {/* Upload Section */}
        <VideoUpload onUploadSuccess={handleUploadSuccess} />

        {/* Content Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Video Analyses */}
          <div className="lg:col-span-2">
            <h2 className="text-2xl font-bold text-gray-800 mb-6">Video Analyses</h2>
            {analyses.length === 0 ? (
              <div className="bg-white rounded-xl shadow-lg p-12 text-center">
                <div className="text-gray-400 mb-4">
                  <svg className="mx-auto h-16 w-16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                  </svg>
                </div>
                <h3 className="text-lg font-medium text-gray-900 mb-2">No videos analyzed yet</h3>
                <p className="text-gray-600">Upload a video file to get started with optimization</p>
              </div>
            ) : (
              <div className="space-y-6">
                {analyses.map((analysis) => (
                  <VideoAnalysisCard
                    key={analysis.id}
                    analysis={analysis}
                    onQueueJob={handleQueueJob}
                    onViewSettings={handleViewSettings}
                  />
                ))}
              </div>
            )}
          </div>

          {/* Jobs Panel */}
          <div className="lg:col-span-1">
            <JobsPanel jobs={jobs} />
          </div>
        </div>
      </div>

      {/* Settings Modal */}
      <HandbrakeSettingsModal
        isOpen={showSettingsModal}
        onClose={() => setShowSettingsModal(false)}
        settings={selectedSettings}
        onQueue={handleQueueJob}
      />
    </div>
  );
}

export default App;