// MongoDB initialization script
/* eslint-disable no-undef */

// Initialize MongoDB with application user
db = db.getSiblingDB('video_optimizer');

// Create application user
db.createUser({
  user: "video_user", 
  pwd: "userpassword123", // Change this in production
  roles: [
    {
      role: "readWrite",
      db: "video_optimizer"
    }
  ]
});

// Create collections with indexes
db.createCollection("video_analyses");
db.createCollection("handbrake_settings"); 
db.createCollection("handbrake_jobs");
db.createCollection("directory_configs");

// Create indexes for better performance
db.video_analyses.createIndex({ "id": 1 }, { unique: true });
db.video_analyses.createIndex({ "created_at": -1 });
db.video_analyses.createIndex({ "filename": 1 });

db.handbrake_settings.createIndex({ "id": 1 }, { unique: true });
db.handbrake_settings.createIndex({ "video_analysis_id": 1 });

db.handbrake_jobs.createIndex({ "id": 1 }, { unique: true });
db.handbrake_jobs.createIndex({ "video_analysis_id": 1 });
db.handbrake_jobs.createIndex({ "status": 1 });
db.handbrake_jobs.createIndex({ "created_at": -1 });

db.directory_configs.createIndex({ "id": 1 }, { unique: true });
db.directory_configs.createIndex({ "path": 1 }, { unique: true });

print("Database initialized successfully!");