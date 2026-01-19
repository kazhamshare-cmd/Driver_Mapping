-- Users table
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('driver', 'admin')),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(100) NOT NULL,
  employee_number VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Vehicles table
CREATE TABLE vehicles (
  id SERIAL PRIMARY KEY,
  vehicle_number VARCHAR(50) UNIQUE NOT NULL,
  vehicle_type VARCHAR(50), -- '4t', '10t' etc.
  max_capacity DECIMAL(10,2), -- Maximum capacity in tons
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Work Records table
CREATE TABLE work_records (
  id SERIAL PRIMARY KEY,
  driver_id INTEGER REFERENCES users(id),
  vehicle_id INTEGER REFERENCES vehicles(id),
  work_date DATE NOT NULL,
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP,
  record_method VARCHAR(20) NOT NULL CHECK (record_method IN ('gps', 'manual')),
  
  -- Location info (only for GPS records)
  start_latitude DECIMAL(10,8),
  start_longitude DECIMAL(11,8),
  start_address TEXT,
  end_latitude DECIMAL(10,8),
  end_longitude DECIMAL(11,8),
  end_address TEXT,
  
  -- Achievement data
  distance DECIMAL(10,2) NOT NULL DEFAULT 0, -- Distance in km
  actual_distance DECIMAL(10,2) DEFAULT 0, -- Loaded Distance in km (Jissha)
  cargo_weight DECIMAL(10,2) DEFAULT 0, -- Cargo weight in tons
  revenue DECIMAL(12,2) DEFAULT 0, -- Operating Revenue for this record (optional)
  
  -- Other info
  has_incident BOOLEAN DEFAULT FALSE,
  incident_detail TEXT,
  status VARCHAR(20) DEFAULT 'confirmed', -- confirmed/pending...
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_work_records_work_date ON work_records(work_date);
CREATE INDEX idx_work_records_driver_id ON work_records(driver_id);

-- GPS Tracks table
CREATE TABLE gps_tracks (
  id SERIAL PRIMARY KEY,
  work_record_id INTEGER REFERENCES work_records(id),
  timestamp TIMESTAMP NOT NULL,
  latitude DECIMAL(10,8) NOT NULL,
  longitude DECIMAL(11,8) NOT NULL,
  speed DECIMAL(5,2), -- Speed in km/h
  accuracy DECIMAL(6,2), -- Accuracy in meters
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_gps_tracks_work_record_id ON gps_tracks(work_record_id);
CREATE INDEX idx_gps_tracks_timestamp ON gps_tracks(timestamp);

-- Reports table (Administrative reports)
CREATE TABLE reports (
  id SERIAL PRIMARY KEY,
  report_type VARCHAR(50) NOT NULL, -- 'annual_business', etc.
  fiscal_year INTEGER NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  
  -- Aggregated data stored as JSON
  summary_data JSONB,
  
  -- Generated PDF URL
  pdf_url TEXT,
  
  status VARCHAR(20) DEFAULT 'draft', -- draft/completed
  created_by INTEGER REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
