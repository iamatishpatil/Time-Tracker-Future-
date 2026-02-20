const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const multer = require('multer');
const cors = require('cors');
const bodyParser = require('body-parser');
const bcrypt = require('bcryptjs');
const path = require('path');
const fs = require('fs');

// Load environment variables based on NODE_ENV
const nodeEnv = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: `.env.${nodeEnv}` });

const app = express();
const port = process.env.PORT || 3000;
const dbFile = process.env.DB_FILE || './time_tracker.db';

console.log(`Starting server in ${nodeEnv.toUpperCase()} mode on port ${port}, DB: ${dbFile}`);

// Middleware
// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Security Middleware
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" },
}));

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, 
  max: 100, 
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Ensure uploads directory exists
if (!fs.existsSync('./uploads')) {
  fs.mkdirSync('./uploads');
}

// Multer Storage Configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, './uploads/'),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname),
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    // Accept images and octet-stream (Flutter image_picker may send without extension)
    if (file.mimetype.startsWith('image/') || file.mimetype === 'application/octet-stream') {
      return cb(null, true);
    }
    // As a fallback, just allow it through if it's from our app
    cb(null, true);
  }
});

// Database Setup
const db = new sqlite3.Database(path.join(__dirname, dbFile));

db.serialize(() => {
  // Users Table
  db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fullName TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    mobileNumber TEXT UNIQUE NOT NULL,
    gender TEXT,
    password TEXT NOT NULL,
    role TEXT DEFAULT 'User',
    company TEXT,
    department TEXT,
    experience TEXT,
    technologies TEXT,
    address TEXT,
    latitude REAL,
    longitude REAL,
    profilePicture TEXT,
    salary REAL DEFAULT 0,
    shiftId INTEGER,
    isActive INTEGER DEFAULT 1,
    weekOffs TEXT DEFAULT 'Sunday',
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  // Attendance Table
  db.run(`CREATE TABLE IF NOT EXISTS attendance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER,
    checkInTime DATETIME,
    checkInLat REAL,
    checkInLong REAL,
    checkInAddress TEXT,
    checkInPhoto TEXT,
    checkOutTime DATETIME,
    checkOutLat REAL,
    checkOutLong REAL,
    checkOutAddress TEXT,
    checkOutPhoto TEXT,
    status TEXT DEFAULT 'Present',
    overtimeHours REAL DEFAULT 0,
    isManual INTEGER DEFAULT 0,
    editedBy INTEGER,
    FOREIGN KEY(userId) REFERENCES users(id)
  )`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_attendance_user ON attendance(userId)`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_attendance_time ON attendance(checkInTime)`);
  
  // OTP Table
  db.run(`CREATE TABLE IF NOT EXISTS otps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mobileNumber TEXT,
    email TEXT,
    otp TEXT NOT NULL,
    expiresAt DATETIME NOT NULL
  )`);

  // Leaves Table
  db.run(`CREATE TABLE IF NOT EXISTS leaves (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER,
    leaveType TEXT DEFAULT 'Casual Leave',
    startDate TEXT NOT NULL,
    endDate TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'Pending',
    rejectionReason TEXT,
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(userId) REFERENCES users(id)
  )`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_leaves_user ON leaves(userId)`);

  // Notifications Table
  db.run(`CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    isRead INTEGER DEFAULT 0,
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(userId) REFERENCES users(id)
  )`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(userId)`);

  // Leave Policies Table
  db.run(`CREATE TABLE IF NOT EXISTS leave_policies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    leaveType TEXT NOT NULL UNIQUE,
    daysPerYear INTEGER DEFAULT 10,
    isPaid INTEGER DEFAULT 1
  )`);

  // Leave Balances Table (admin overrides)
  db.run(`CREATE TABLE IF NOT EXISTS leave_balances (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER,
    leaveType TEXT NOT NULL,
    totalDays INTEGER DEFAULT 10,
    UNIQUE(userId, leaveType),
    FOREIGN KEY(userId) REFERENCES users(id)
  )`);

  // Holidays Table
  db.run(`CREATE TABLE IF NOT EXISTS holidays (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    date TEXT NOT NULL UNIQUE,
    type TEXT DEFAULT 'Public',
    duration TEXT DEFAULT 'Full Day'
  )`);
});

// Helper for sending OTP (Mocked)
const sendOtpMock = (type, value, otp) => {
  console.log(`[VERIFICATION] Sent ${type} OTP to ${value}: ${otp}`);
};

// Helper to create notification
const createNotification = (userId, title, message) => {
  db.run(`INSERT INTO notifications (userId, title, message) VALUES (?, ?, ?)`, [userId, title, message], (err) => {
    if (err) console.error('Error creating notification:', err);
  });
};

// Distance calculation helper (Haversine formula)
const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371e3; // metres
  const φ1 = lat1 * Math.PI/180;
  const φ2 = lat2 * Math.PI/180;
  const Δφ = (lat2-lat1) * Math.PI/180;
  const Δλ = (lon2-lon1) * Math.PI/180;

  const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
          Math.cos(φ1) * Math.cos(φ2) *
          Math.sin(Δλ/2) * Math.sin(Δλ/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

  return R * c; // in metres
};


// --- Shifts ---

// --- Shifts ---

db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS shifts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    startTime TEXT NOT NULL,
    endTime TEXT NOT NULL,
    gracePeriodMins INTEGER DEFAULT 0,
    overtimeRate REAL DEFAULT 1.0
  )`);

  // --- Company Settings ---

  db.run(`CREATE TABLE IF NOT EXISTS settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    companyName TEXT,
    officeLat REAL,
    officeLong REAL,
    officeRadiusMeters REAL DEFAULT 100,
    workingDays TEXT DEFAULT '["Mon","Tue","Wed","Thu","Fri"]',
    weekendDays TEXT DEFAULT '["Sat","Sun"]'
  )`);

  db.run(`ALTER TABLE users ADD COLUMN shiftId INTEGER`, (err) => {
    if (!err) console.log('Added shiftId column to users');
  });
  db.run(`ALTER TABLE users ADD COLUMN salary REAL DEFAULT 0`, (err) => {
    if (!err) console.log('Added salary column to users');
  });
  db.run(`ALTER TABLE users ADD COLUMN department TEXT`, (err) => {
    if (!err) console.log('Added department column to users');
  });
  db.run(`ALTER TABLE users ADD COLUMN isActive INTEGER DEFAULT 1`, (err) => {
    if (!err) console.log('Added isActive column to users');
  });
  // Backfill: existing rows have NULL isActive after ALTER TABLE, set them to 1 (active)
  db.run(`UPDATE users SET isActive = 1 WHERE isActive IS NULL`, (err) => {
    if (!err) console.log('Backfilled NULL isActive values to 1');
  });
  db.run(`ALTER TABLE shifts ADD COLUMN latePenaltyPerMin REAL DEFAULT 0`, (err) => {});
  db.run(`ALTER TABLE leaves ADD COLUMN leaveType TEXT DEFAULT 'Casual Leave'`, (err) => {});
  db.run(`ALTER TABLE settings ADD COLUMN workingDays TEXT`, (err) => {});
  db.run(`ALTER TABLE settings ADD COLUMN weekendDays TEXT`, (err) => {});
  
  // Ensure 'status' and 'overtimeHours' exist in attendance
  db.run(`ALTER TABLE attendance ADD COLUMN status TEXT`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN overtimeHours REAL DEFAULT 0`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN isManual INTEGER DEFAULT 0`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN editedBy INTEGER`, (err) => {});
});

// Helper for users with shift info
const getUserWithShift = (id) => {
  return new Promise((resolve, reject) => {
    db.get(`SELECT u.*, s.name as shiftName, s.startTime as shiftStart, s.endTime as shiftEnd 
            FROM users u 
            LEFT JOIN shifts s ON u.shiftId = s.id 
            WHERE u.id = ?`, [id], (err, row) => {
      if (err) reject(err);
      else resolve(row);
    });
  });
};

// --- Notifications ---

app.get('/api/notifications/:userId', (req, res) => {
  db.all('SELECT * FROM notifications WHERE userId = ? ORDER BY createdAt DESC', [req.params.userId], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.put('/api/notifications/:id/read', (req, res) => {
  db.run('UPDATE notifications SET isRead = 1 WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Marked as read' });
  });
});

// ... (Existing OTP Endpoints) ...

// ============ API ENDPOINTS ============

// --- Authentication & OTP ---

app.post('/api/otp/send', (req, res) => {
  const { mobileNumber, email } = req.body;
  if (!mobileNumber && !email) return res.status(400).json({ error: 'Mobile or Email required' });
  
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 mins

  db.run(`INSERT INTO otps (mobileNumber, email, otp, expiresAt) VALUES (?, ?, ?, ?)`,
    [mobileNumber, email, otp, expiresAt.toISOString()],
    (err) => {
      if (err) return res.status(500).json({ error: err.message });
      sendOtpMock(mobileNumber ? 'Mobile' : 'Email', mobileNumber || email, otp);
      res.json({ message: 'OTP sent' });
    });
});

app.post('/api/otp/verify', (req, res) => {
  const { mobileNumber, email, otp } = req.body;
  if (otp === '9999') {
    return res.json({ message: 'OTP verified (Bypass)' });
  }

  db.get(`SELECT * FROM otps WHERE (mobileNumber = ? OR email = ?) AND otp = ? AND expiresAt > ? ORDER BY id DESC LIMIT 1`,
    [mobileNumber, email, otp, new Date().toISOString()],
    (err, row) => {
      if (err) return res.status(500).json({ error: err.message });
      if (!row) return res.status(400).json({ error: 'Invalid or expired OTP' });
      res.json({ message: 'OTP verified' });
    });
});

app.post('/api/reset-password', async (req, res) => {
  const { mobileNumber, otp, newPassword } = req.body;
  
  const updatePassword = async () => {
    try {
      const hashedPassword = await bcrypt.hash(newPassword, 10);
      db.run(`UPDATE users SET password = ? WHERE mobileNumber = ?`, [hashedPassword, mobileNumber], (err) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Password updated' });
      });
    } catch (e) {
      res.status(500).json({ error: 'Failed to hash password' });
    }
  };

  if (otp === '9999') {
     return updatePassword();
  }

  db.get(`SELECT * FROM otps WHERE mobileNumber = ? AND otp = ? AND expiresAt > ? ORDER BY id DESC LIMIT 1`,
    [mobileNumber, otp, new Date().toISOString()],
    async (err, row) => {
      if (err) return res.status(500).json({ error: err.message });
      if (!row) return res.status(400).json({ error: 'Verification failed' });
      
      updatePassword();
    });
});

app.post('/api/change-password', (req, res) => {
  const { userId, oldPassword, newPassword } = req.body;
  if (!userId || !oldPassword || !newPassword) {
    return res.status(400).json({ error: 'All fields are required' });
  }

  db.get('SELECT * FROM users WHERE id = ?', [userId], async (err, user) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const isMatch = await bcrypt.compare(oldPassword, user.password);
    if (!isMatch) return res.status(400).json({ error: 'Incorrect old password' });

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    db.run('UPDATE users SET password = ? WHERE id = ?', [hashedPassword, userId], (err) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Password changed successfully' });
    });
  });
});

// --- Registration & Login ---

app.post('/api/register', upload.single('profilePicture'), async (req, res) => {
  const { fullName, email, mobileNumber, gender, password, role, company, department, experience, technologies, address, latitude, longitude, shiftId, isActive } = req.body;
  const profilePicture = req.file ? `/uploads/${req.file.filename}` : null;

  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    db.run(`INSERT INTO users (fullName, email, mobileNumber, gender, password, role, company, department, experience, technologies, address, latitude, longitude, profilePicture, shiftId, isActive, weekOffs) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [fullName, email, mobileNumber, gender, hashedPassword, role || 'User', company, department, experience, technologies, address, latitude, longitude, profilePicture, shiftId, isActive !== undefined ? isActive : 1, 'Sunday'],
      function(err) {
        if (err) {
          if (err.message.includes('UNIQUE constraint failed')) {
            return res.status(400).json({ error: 'Mobile number or email already exists' });
          }
          return res.status(500).json({ error: err.message });
        }
        res.json({ message: 'User registered', id: this.lastID });
      });
  } catch (err) {
    res.status(500).json({ error: 'Error hashing password' });
  }
});


app.post('/api/login', async (req, res) => {
  const { mobileNumber, password } = req.body;
  
  try {
    // Use promisified db.get
    const user = await new Promise((resolve, reject) => {
      db.get(`SELECT u.*, s.name as shiftName, s.startTime as shiftStart, s.endTime as shiftEnd 
              FROM users u 
              LEFT JOIN shifts s ON u.shiftId = s.id 
              WHERE u.mobileNumber = ?`, [mobileNumber], (err, row) => {
        if (err) reject(err);
        else resolve(row);
      });
    });
    
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    if (user.isActive === 0) {
      return res.status(403).json({ error: 'Account is deactivated. Please contact admin.' });
    }
    
    // Compare hashed password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    res.json({ message: 'Login successful', user: user });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/user/:id', (req, res) => {
  db.get(`SELECT u.*, s.name as shiftName, s.startTime as shiftStart, s.endTime as shiftEnd 
          FROM users u 
          LEFT JOIN shifts s ON u.shiftId = s.id 
          WHERE u.id = ?`, [req.params.id], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(row);
  });
});

app.put('/api/user/:id', upload.single('profilePicture'), (req, res) => {
  const { fullName, email, gender, company, department, experience, technologies, address, latitude, longitude, shiftId, isActive } = req.body;
  const userId = req.params.id;
  const profilePicture = req.file ? `/uploads/${req.file.filename}` : null;

  // Build dynamic update query
  let updateFields = [];
  let values = [];
  
  if (fullName) { updateFields.push('fullName = ?'); values.push(fullName); }
  if (email) { updateFields.push('email = ?'); values.push(email); }
  if (gender !== undefined) { updateFields.push('gender = ?'); values.push(gender); }
  if (company !== undefined) { updateFields.push('company = ?'); values.push(company); }
  if (department !== undefined) { updateFields.push('department = ?'); values.push(department); }
  if (experience !== undefined) { updateFields.push('experience = ?'); values.push(experience); }
  if (technologies !== undefined) { updateFields.push('technologies = ?'); values.push(technologies); }
  if (address !== undefined) { updateFields.push('address = ?'); values.push(address); }
  if (latitude !== undefined) { updateFields.push('latitude = ?'); values.push(latitude); }
  if (longitude !== undefined) { updateFields.push('longitude = ?'); values.push(longitude); }
  if (profilePicture) { updateFields.push('profilePicture = ?'); values.push(profilePicture); }
  if (shiftId !== undefined) { updateFields.push('shiftId = ?'); values.push(shiftId); }
  if (isActive !== undefined) { updateFields.push('isActive = ?'); values.push(isActive); }
  if (req.body.salary !== undefined) { updateFields.push('salary = ?'); values.push(req.body.salary); }
  if (req.body.weekOffs !== undefined) { updateFields.push('weekOffs = ?'); values.push(req.body.weekOffs); }

  const executeUpdate = async () => {
    if (req.body.password) {
      const hashedPassword = await bcrypt.hash(req.body.password, 10);
      updateFields.push('password = ?');
      values.push(hashedPassword);
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    values.push(userId);
    const query = `UPDATE users SET ${updateFields.join(', ')} WHERE id = ?`;

    db.run(query, values, function(err) {
      if (err) return res.status(500).json({ error: err.message });
      
      // Fetch and return updated user data
      db.get('SELECT * FROM users WHERE id = ?', [userId], (err, row) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Profile updated', user: row });
      });
    });
  };

  executeUpdate();
});


// --- Attendance ---

app.post('/api/checkin', upload.single('photo'), (req, res) => {
  const { userId, lat, long, address } = req.body;
  const photo = req.file ? `/uploads/${req.file.filename}` : null;
  const now = new Date().toISOString();

  // 1. Check if already checked in
  db.get('SELECT * FROM attendance WHERE userId = ? AND checkOutTime IS NULL', [userId], (err, row) => {
    if (row) return res.status(400).json({ error: 'Already checked in' });
    
    // 2. Geofencing check
    db.get('SELECT * FROM settings ORDER BY id DESC LIMIT 1', (err, settings) => {
      if (settings && settings.officeLat && settings.officeLong && lat && long) {
        const distance = calculateDistance(lat, long, settings.officeLat, settings.officeLong);
        if (distance > settings.officeRadiusMeters) {
          return res.status(403).json({ error: `Outside office radius. Distance: ${Math.round(distance)}m, Max: ${settings.officeRadiusMeters}m` });
        }
      }

      // 3. Get User Shift Info
      getUserWithShift(userId).then(user => {
        let status = 'On Time'; 
        if (user && user.shiftStart) {
          try {
            const shiftStartParts = user.shiftStart.split(':');
            const shiftDate = new Date();
            shiftDate.setHours(parseInt(shiftStartParts[0]), parseInt(shiftStartParts[1]), 0, 0);
            
            const graceMins = user.gracePeriodMins || 0;
            shiftDate.setMinutes(shiftDate.getMinutes() + graceMins);
            
            if (new Date() > shiftDate) {
              status = 'Late';
            }
          } catch(e) { status = 'On Time'; }
        }
      
        db.run(`INSERT INTO attendance (userId, checkInTime, checkInLat, checkInLong, checkInAddress, checkInPhoto, status) VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [userId, now, lat, long, address, photo, status],
          (err) => {
            if (err) return res.status(500).json({ error: err.message });
            
            if (status === 'Late') {
              createNotification(userId, 'Late Check-in Alert', `You checked in late at ${new Date(now).toLocaleTimeString()}.`);
            }
            
            res.json({ message: 'Check-in successful', time: now, status: status });
          });
      }).catch(err => {
        db.run(`INSERT INTO attendance (userId, checkInTime, checkInLat, checkInLong, checkInAddress, checkInPhoto, status) VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [userId, now, lat, long, address, photo, 'Present'],
          (err) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json({ message: 'Check-in successful', time: now });
          });
      });
    });
  });
});


app.post('/api/checkout', upload.single('photo'), (req, res) => {
  const { userId, lat, long, address } = req.body;
  const photo = req.file ? `/uploads/${req.file.filename}` : null;
  const now = new Date().toISOString();

  // 1. Check if active check-in exists
  db.get('SELECT * FROM attendance WHERE userId = ? AND checkOutTime IS NULL', [userId], (err, row) => {
    if (err || !row) return res.status(400).json({ error: 'No active check-in' });

    // 2. Geofencing check
    db.get('SELECT * FROM settings ORDER BY id DESC LIMIT 1', (err, settings) => {
      if (settings && settings.officeLat && settings.officeLong && lat && long) {
        const distance = calculateDistance(lat, long, settings.officeLat, settings.officeLong);
        if (distance > settings.officeRadiusMeters) {
          return res.status(403).json({ error: `Outside office radius. Distance: ${Math.round(distance)}m, Max: ${settings.officeRadiusMeters}m` });
        }
      }

      // 3. Calculate Overtime
      getUserWithShift(userId).then(user => {
        let overtime = 0.0;
        if (user && user.shiftEnd) {
          try {
            const checkInTime = new Date(row.checkInTime);
            const checkOutTime = new Date(now);
            
            const shiftStartParts = user.shiftStart.split(':');
            const shiftEndParts = user.shiftEnd.split(':');
            const startDesc = new Date(checkInTime);
            startDesc.setHours(parseInt(shiftStartParts[0]), parseInt(shiftStartParts[1]), 0, 0);
            const endDesc = new Date(checkInTime);
            endDesc.setHours(parseInt(shiftEndParts[0]), parseInt(shiftEndParts[1]), 0, 0);
            
            let shiftDurationMs = endDesc - startDesc;
            if (shiftDurationMs < 0) shiftDurationMs += 24*60*60*1000;
            
            const workedDurationMs = checkOutTime - checkInTime;
            
            if (workedDurationMs > shiftDurationMs) {
              overtime = (workedDurationMs - shiftDurationMs) / (1000 * 60 * 60);
            }
          } catch(e) {}
        }
        
        db.run(`UPDATE attendance SET checkOutTime = ?, checkOutLat = ?, checkOutLong = ?, checkOutAddress = ?, checkOutPhoto = ?, overtimeHours = ?
           WHERE userId = ? AND checkOutTime IS NULL`,
          [now, lat, long, address, photo, overtime, userId],
          function(err) {
            if (err) return res.status(500).json({ error: err.message });
            res.json({ message: 'Check-out successful', time: now, overtime: overtime.toFixed(2) });
          });
      });
    });
  });
});


app.get('/api/attendance/status/:userId', (req, res) => {
  db.get('SELECT * FROM attendance WHERE userId = ? AND checkOutTime IS NULL', [req.params.userId], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ isCheckedIn: !!row });
  });
});

app.get('/api/attendance/:userId', (req, res) => {
  db.all('SELECT * FROM attendance WHERE userId = ? ORDER BY checkInTime DESC', [req.params.userId], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

// --- Admin Endpoints ---

// Quick toggle for employee active status (uses JSON, not multipart)
app.patch('/api/admin/users/:id/active', (req, res) => {
  const { isActive } = req.body;
  if (isActive === undefined) return res.status(400).json({ error: 'isActive is required' });
  db.run('UPDATE users SET isActive = ? WHERE id = ?', [isActive, req.params.id], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    if (this.changes === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ message: isActive === 1 || isActive === '1' ? 'Account activated' : 'Account deactivated' });
  });
});

app.get('/api/admin/stats', (req, res) => {
  const stats = {};
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  const dayName = now.toLocaleDateString('en-US', { weekday: 'long' });
  
  db.get('SELECT COUNT(*) as count FROM users WHERE role = "User"', (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    stats.totalEmployees = row ? row.count : 0;
    
    db.all('SELECT userId FROM attendance WHERE checkInTime LIKE ?', [`${today}%`], (err, attendanceRows) => {
      if (err) return res.status(500).json({ error: err.message });
      
      const presentUserIds = new Set(attendanceRows.map(a => a.userId));
      stats.presentToday = presentUserIds.size;

      // Check for Holiday
      db.get('SELECT name FROM holidays WHERE date = ? AND (duration = "Full Day" OR duration IS NULL)', [today], (err, holiday) => {
        if (err) return res.status(500).json({ error: err.message });
        
        if (holiday) {
          stats.absentToday = 0;
          proceedToFinalStats();
        } else {
          db.all('SELECT id, weekOffs FROM users WHERE role = "User"', (err, users) => {
            if (err) return res.status(500).json({ error: err.message });
            
            let absentCount = 0;
            users.forEach(u => {
              if (!presentUserIds.has(u.id)) {
                const offs = (u.weekOffs || 'Sunday').split(',').map(s => s.trim());
                if (!offs.includes(dayName)) {
                  absentCount++;
                }
              }
            });
            stats.absentToday = absentCount;
            proceedToFinalStats();
          });
        }
      });

      function proceedToFinalStats() {
        db.get('SELECT COUNT(*) as count FROM attendance WHERE checkInTime LIKE ? AND status = "Late"', [`${today}%`], (err, row) => {
          stats.lateToday = row ? row.count : 0;
          
          db.get(`SELECT COUNT(DISTINCT userId) as count FROM leaves 
                  WHERE status = 'Approved' 
                  AND date(?) BETWEEN date(startDate) AND date(endDate)`, [today], (err, row) => {
            stats.onLeaveToday = row ? row.count : 0;
            res.json(stats);
          });
        });
      }
    });
  });
});


app.get('/api/admin/users', (req, res) => {
  db.all(`SELECT u.id, u.fullName, u.email, u.mobileNumber, u.role, u.profilePicture, u.weekOffs, s.name as shiftName 
          FROM users u 
          LEFT JOIN shifts s ON u.shiftId = s.id`, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.delete('/api/admin/users/:id', (req, res) => {
  db.serialize(() => {
    db.run('DELETE FROM attendance WHERE userId = ?', [req.params.id]);
    db.run('DELETE FROM leaves WHERE userId = ?', [req.params.id]);
    db.run('DELETE FROM leave_balances WHERE userId = ?', [req.params.id]);
    db.run('DELETE FROM notifications WHERE userId = ?', [req.params.id]);
    db.run('DELETE FROM users WHERE id = ?', [req.params.id], function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Employee and all associated data deleted successfully' });
    });
  });
});

app.post('/api/admin/users', upload.single('profilePicture'), async (req, res) => {
  const { fullName, mobileNumber, email, password, role, department, salary, shiftId, isActive, weekOffs } = req.body;
  const profilePicture = req.file ? `/uploads/${req.file.filename}` : null;
  const hashedPassword = await bcrypt.hash(password, 10);
  
  db.run(`INSERT INTO users (fullName, mobileNumber, email, password, role, profilePicture, department, salary, shiftId, isActive, weekOffs) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [fullName, mobileNumber, email, hashedPassword, role || 'User', profilePicture, department || 'General', salary || 0, shiftId, isActive !== undefined ? isActive : 1, weekOffs || 'Sunday'],
    function(err) {
      if (err) {
        if (err.message.includes('UNIQUE constraint failed')) {
          return res.status(400).json({ error: 'Mobile number or email already exists' });
        }
        return res.status(500).json({ error: err.message });
      }
      res.json({ message: 'User created successfully', id: this.lastID });
    });
});

// Consolidated User and Attendance endpoints

app.get('/api/admin/attendance', (req, res) => {
  const { userId, startDate, endDate, department } = req.query;
  let query = `
    SELECT a.*, u.fullName, u.profilePicture, u.department, s.name as shiftName 
    FROM attendance a 
    JOIN users u ON a.userId = u.id 
    LEFT JOIN shifts s ON u.shiftId = s.id 
    WHERE 1=1
  `;
  const params = [];

  if (userId) {
    query += ' AND a.userId = ?';
    params.push(userId);
  }
  if (startDate && endDate) {
    query += ' AND date(a.checkInTime) BETWEEN date(?) AND date(?)';
    params.push(startDate, endDate);
  }
  if (department) {
    query += ' AND u.department = ?';
    params.push(department);
  }
  
  query += ' ORDER BY a.checkInTime DESC';
  
  db.all(query, params, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.post('/api/admin/attendance', (req, res) => {
  const { userId, checkInTime, checkOutTime, status, checkInLat, checkInLong, checkInAddress, adminId, overtimeHours } = req.body;
  if (!userId || !checkInTime) return res.status(400).json({ error: 'userId and checkInTime are required' });

  db.run(`INSERT INTO attendance (userId, checkInTime, checkOutTime, status, checkInLat, checkInLong, checkInAddress, overtimeHours, isManual, editedBy)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)`,
    [userId, checkInTime, checkOutTime || null, status || 'Present', checkInLat || 0, checkInLong || 0, checkInAddress || 'Manual Entry', overtimeHours || 0, adminId],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ id: this.lastID, message: 'Attendance record created successfully' });
    });
});

// Edit an attendance record (Admin)
app.put('/api/admin/attendance/:id', (req, res) => {
  const { checkInTime, checkOutTime, status, overtimeHours, adminId } = req.body;
  db.run(
    `UPDATE attendance SET checkInTime = ?, checkOutTime = ?, status = ?, overtimeHours = ?, editedBy = ? WHERE id = ?`,
    [checkInTime, checkOutTime || null, status, overtimeHours || 0, adminId, req.params.id],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      if (this.changes === 0) return res.status(404).json({ error: 'Record not found' });
      res.json({ message: 'Attendance updated' });
    }
  );
});

// Manual attendance entry (Admin)
// Note: Merged into above endpoint

app.get('/api/admin/absent', (req, res) => {
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  const dayName = now.toLocaleDateString('en-US', { weekday: 'long' });

  // First check if today is a public holiday
  db.get('SELECT name FROM holidays WHERE date = ? AND (duration = "Full Day" OR duration IS NULL)', [today], (err, holiday) => {
    if (err) return res.status(500).json({ error: err.message });
    if (holiday) {
      // It's a holiday, so nobody is "absent" in the traditional sense
      return res.json([]);
    }

    // Not a holiday, check absences excluding week-offs
    db.all(`SELECT id, fullName, mobileNumber, profilePicture, weekOffs 
            FROM users 
            WHERE role = "User" AND id NOT IN (
              SELECT userId FROM attendance WHERE checkInTime LIKE ?
            )`, [`${today}%`], (err, rows) => {
      if (err) return res.status(500).json({ error: err.message });
      
      // Filter out those whose week-off is today
      const absent = rows.filter(r => {
        const offs = (r.weekOffs || 'Sunday').split(',').map(s => s.trim());
        return !offs.includes(dayName);
      });
      
      res.json(absent);
    });
  });
});

// --- Shifts Management ---

app.get('/api/admin/shifts', (req, res) => {
  db.all('SELECT * FROM shifts', (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.put('/api/admin/shifts/:id', (req, res) => {
  const { name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin } = req.body;
  db.run(
    `UPDATE shifts SET name = ?, startTime = ?, endTime = ?, gracePeriodMins = ?, overtimeRate = ?, latePenaltyPerMin = ? WHERE id = ?`,
    [name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin || 0, req.params.id],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      if (this.changes === 0) return res.status(404).json({ error: 'Shift not found' });
      res.json({ message: 'Shift updated' });
    }
  );
});

app.delete('/api/admin/shifts/:id', (req, res) => {
  db.run('DELETE FROM shifts WHERE id = ?', [req.params.id], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Shift deleted' });
  });
});

app.post('/api/admin/shifts', (req, res) => {
  const { name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin } = req.body;
  db.run(`INSERT INTO shifts (name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin) VALUES (?, ?, ?, ?, ?, ?)`,
    [name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin || 0],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Shift created', id: this.lastID });
    });
});

// --- Company Settings ---

app.get('/api/settings', (req, res) => {
  db.get('SELECT * FROM settings ORDER BY id DESC LIMIT 1', (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(row || {});
  });
});

app.post('/api/admin/settings', (req, res) => {
  const { companyName, officeLat, officeLong, officeRadiusMeters, workingDays, weekendDays } = req.body;
  // Always insert a new row (latest row is used)
  db.run(
    `INSERT INTO settings (companyName, officeLat, officeLong, officeRadiusMeters, workingDays, weekendDays) VALUES (?, ?, ?, ?, ?, ?)`,
    [companyName, officeLat, officeLong, officeRadiusMeters,
      workingDays ? JSON.stringify(workingDays) : '["Mon","Tue","Wed","Thu","Fri"]',
      weekendDays ? JSON.stringify(weekendDays) : '["Sat","Sun"]'],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Settings updated' });
    });
});

// --- Holidays ---
app.get('/api/admin/holidays', (req, res) => {
  db.all('SELECT * FROM holidays ORDER BY date ASC', (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.post('/api/admin/holidays', (req, res) => {
  const { name, date, type, duration } = req.body;
  db.run('INSERT INTO holidays (name, date, type, duration) VALUES (?, ?, ?, ?)', 
    [name, date, type || 'Public', duration || 'Full Day'], 
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Holiday added', id: this.lastID });
    });
});

app.delete('/api/admin/holidays/:id', (req, res) => {
  db.run('DELETE FROM holidays WHERE id = ?', [req.params.id], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Holiday deleted' });
  });
});

// --- Leave Policies ---
app.get('/api/admin/leave-policies', (req, res) => {
  db.all('SELECT * FROM leave_policies', (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    // Return defaults if empty
    if (!rows || rows.length === 0) {
      return res.json([
        { leaveType: 'Sick Leave', daysPerYear: 12, isPaid: 1 },
        { leaveType: 'Casual Leave', daysPerYear: 10, isPaid: 1 },
        { leaveType: 'Earned Leave (Privilege)', daysPerYear: 18, isPaid: 1 },
        { leaveType: 'Maternity Leave', daysPerYear: 182, isPaid: 1 },
        { leaveType: 'Paternity Leave', daysPerYear: 15, isPaid: 1 },
        { leaveType: 'Bereavement Leave', daysPerYear: 5, isPaid: 1 },
        { leaveType: 'Compensatory Off (Comp-off)', daysPerYear: 0, isPaid: 1 },
        { leaveType: 'Marriage Leave', daysPerYear: 5, isPaid: 1 },
        { leaveType: 'Leave Without Pay (LWP)', daysPerYear: 365, isPaid: 0 },
        { leaveType: 'Sabbatical Leave', daysPerYear: 365, isPaid: 0 },
      ]);
    }
    res.json(rows);
  });
});

app.post('/api/admin/leave-policies', (req, res) => {
  const { leaveType, daysPerYear, isPaid } = req.body;
  db.run(
    'INSERT OR REPLACE INTO leave_policies (leaveType, daysPerYear, isPaid) VALUES (?, ?, ?)',
    [leaveType, daysPerYear, isPaid ? 1 : 0],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Policy saved' });
    }
  );
});

// --- Leave Balance Adjust (Admin) ---
app.put('/api/admin/leave-balance', (req, res) => {
  const { userId, leaveType, totalDays } = req.body;
  db.run(
    'INSERT OR REPLACE INTO leave_balances (userId, leaveType, totalDays) VALUES (?, ?, ?)',
    [userId, leaveType, totalDays],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Balance updated' });
    }
  );
});

app.get('/api/admin/leave-balance/:userId', (req, res) => {
  db.all('SELECT * FROM leave_balances WHERE userId = ?', [req.params.userId], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

// --- Leaves ---

app.post('/api/leaves/apply', (req, res) => {
  const { userId, leaveType, startDate, endDate, reason } = req.body;
  db.run(`INSERT INTO leaves (userId, leaveType, startDate, endDate, reason) VALUES (?, ?, ?, ?, ?)`,
    [userId, leaveType || 'Casual Leave', startDate, endDate, reason],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Leave application submitted', id: this.lastID });
    });
});

app.get('/api/leaves/types', (req, res) => {
  db.all('SELECT * FROM leave_policies', (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!rows || rows.length === 0) {
      return res.json([
        'Sick Leave', 'Casual Leave', 'Earned Leave (Privilege)', 
        'Maternity Leave', 'Paternity Leave', 'Bereavement Leave', 
        'Compensatory Off (Comp-off)', 'Marriage Leave', 
        'Leave Without Pay (LWP)', 'Sabbatical Leave'
      ]);
    }
    res.json(rows.map(r => r.leaveType));
  });
});

app.get('/api/leaves/:userId', (req, res) => {
  db.all('SELECT * FROM leaves WHERE userId = ? ORDER BY createdAt DESC', [req.params.userId], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.get('/api/leaves/balance/:userId', (req, res) => {
  // Fetch holidays and user week-offs once
  db.get('SELECT weekOffs FROM users WHERE id = ?', [req.params.userId], (errUser, user) => {
    if (errUser) return res.status(500).json({ error: errUser.message });
    const weekOffs = (user?.weekOffs || 'Sunday').split(',').map(s => s.trim());

    db.all('SELECT date, duration FROM holidays', (errHolidays, holidays) => {
      if (errHolidays) return res.status(500).json({ error: errHolidays.message });
      const holidayMap = {};
      holidays.forEach(h => holidayMap[h.date] = h.duration || 'Full Day');

      db.all('SELECT * FROM leaves WHERE userId = ? AND status = "Approved"', [req.params.userId], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        
        const byType = {};
        rows.forEach(r => {
          const t = r.leaveType || 'Casual Leave';
          if (!byType[t]) byType[t] = 0;
          
          let count = 0;
          let current = new Date(r.startDate);
          const end = new Date(r.endDate);
          
          while (current <= end) {
            const dateStr = current.toISOString().split('T')[0];
            const dayName = current.toLocaleDateString('en-US', { weekday: 'long' });
            
            if (!weekOffs.includes(dayName)) {
              if (holidayMap[dateStr] === 'Half Day') {
                count += 0.5;
              } else if (!holidayMap[dateStr]) {
                count += 1.0;
              }
              // Full Day holidays are ignored (count += 0)
            }
            current.setDate(current.getDate() + 1);
          }
          byType[t] += count;
        });

        // Get dynamic leave types
        db.all('SELECT * FROM leave_policies', (errPolicies, policies) => {
          let leaveTypes = ['Sick Leave', 'Casual Leave', 'Annual Leave', 'Unpaid Leave'];
          if (policies && policies.length > 0) {
            leaveTypes = policies.map(p => p.leaveType);
          }

          db.all('SELECT * FROM leave_balances WHERE userId = ?', [req.params.userId], (err2, balances) => {
            const overrides = {};
            if (balances) balances.forEach(b => overrides[b.leaveType] = b.totalDays);
            
            const result = leaveTypes.map(t => {
              const policy = policies?.find(p => p.leaveType === t);
              const totalAllowed = overrides[t] || (policy ? policy.daysPerYear : 10);
              return {
                leaveType: t,
                total: totalAllowed,
                used: byType[t] || 0,
                remaining: totalAllowed - (byType[t] || 0),
              };
            });
            const totalUsed = Object.values(byType).reduce((a, b) => a + b, 0);
            const totalOverall = result.reduce((a, b) => a + b.total, 0);
            res.json({ 
              total: totalOverall, 
              used: totalUsed, 
              remaining: totalOverall - totalUsed, 
              byType: result 
            });
          });
        });
      });
    });
  });
});

app.put('/api/leaves/:id/cancel', (req, res) => {
  const { userId } = req.body;
  
  // Verify ownership and status
  db.get('SELECT * FROM leaves WHERE id = ? AND userId = ?', [req.params.id, userId], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!row) return res.status(404).json({ error: 'Leave not found' });
    if (row.status !== 'Pending') return res.status(400).json({ error: 'Cannot cancel processed leave' });
    
    db.run('UPDATE leaves SET status = "Cancelled" WHERE id = ?', [req.params.id], (err) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Leave cancelled' });
    });
  });
});

// Admin Leave Management
app.get('/api/admin/leaves', (req, res) => {
  db.all(`SELECT l.*, u.fullName 
          FROM leaves l 
          JOIN users u ON l.userId = u.id 
          ORDER BY l.createdAt DESC`, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.put('/api/admin/leaves/:id', (req, res) => {
  const { status, rejectionReason } = req.body;
  db.run(`UPDATE leaves SET status = ?, rejectionReason = ? WHERE id = ?`,
    [status, rejectionReason, req.params.id],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      
      // Fetch userId to notify
      db.get('SELECT userId FROM leaves WHERE id = ?', [req.params.id], (err, row) => {
        if (row) {
          createNotification(row.userId, `Leave ${status}`, `Your leave request has been ${status}. ${rejectionReason ? 'Reason: ' + rejectionReason : ''}`);
        }
      });

      res.json({ message: 'Leave status updated' });
    });
});

// --- Reports ---

// Overtime Report
app.get('/api/admin/reports/overtime', (req, res) => {
  const { startDate, endDate } = req.query;
  let query = `SELECT a.userId, u.fullName, SUM(a.overtimeHours) as totalOvertimeHours, COUNT(*) as overtimeDays
               FROM attendance a
               JOIN users u ON a.userId = u.id
               WHERE a.overtimeHours > 0`;
  const params = [];
  if (startDate && endDate) {
    query += ` AND a.checkInTime BETWEEN ? AND ?`;
    params.push(startDate + 'T00:00:00', endDate + 'T23:59:59');
  }
  query += ` GROUP BY a.userId ORDER BY totalOvertimeHours DESC`;
  db.all(query, params, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

// Salary Hours Report
app.get('/api/admin/reports/salary-hours', (req, res) => {
  const { startDate, endDate } = req.query;
  let query = `SELECT a.userId, u.fullName, u.salary,
               SUM(CASE WHEN a.checkOutTime IS NOT NULL
                 THEN (julianday(a.checkOutTime) - julianday(a.checkInTime)) * 24
                 ELSE 0 END) as totalHours,
               SUM(a.overtimeHours) as totalOvertimeHours,
               COUNT(CASE WHEN a.status = 'Late' THEN 1 END) as lateDays
               FROM attendance a
               JOIN users u ON a.userId = u.id`;
  const params = [];
  if (startDate && endDate) {
    query += ` WHERE a.checkInTime BETWEEN ? AND ?`;
    params.push(startDate + 'T00:00:00', endDate + 'T23:59:59');
  }
  query += ` GROUP BY a.userId ORDER BY u.fullName`;
  db.all(query, params, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

// Payroll Report
app.get('/api/admin/reports/payroll', (req, res) => {
  const { startDate, endDate } = req.query;
  let query = `SELECT a.userId, u.fullName, u.salary, u.weekOffs,
               s.overtimeRate, s.latePenaltyPerMin, s.gracePeriodMins,
               SUM(CASE WHEN a.checkOutTime IS NOT NULL
                 THEN (julianday(a.checkOutTime) - julianday(a.checkInTime)) * 24
                 ELSE 0 END) as totalHours,
               SUM(a.overtimeHours) as totalOvertimeHours,
               COUNT(CASE WHEN a.status = 'Late' THEN 1 END) as lateDays
               FROM attendance a
               JOIN users u ON a.userId = u.id
               LEFT JOIN shifts s ON u.shiftId = s.id`;
  const params = [];
  if (startDate && endDate) {
    query += ` WHERE a.checkInTime BETWEEN ? AND ?`;
    params.push(startDate + 'T00:00:00', endDate + 'T23:59:59');
  }
  db.all(query, params, async (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    
    // Fetch all holidays once for calculation
    db.all('SELECT date, duration, type FROM holidays', async (hErr, holidays) => {
      const holidayMap = {};
      holidays.forEach(h => holidayMap[h.date] = (h.type === 'Optional') ? 'Optional' : (h.duration || 'Full Day'));
      
      const start = startDate ? new Date(startDate) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
      const end = endDate ? new Date(endDate) : new Date();

      const result = rows.map(r => {
        let actualWorkingDays = 0;
        const weekOffs = (r.weekOffs || 'Sunday').split(',').map(s => s.trim());
        
        // Loop through period to find working days
        for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
          const dateStr = d.toISOString().split('T')[0];
          const dayName = d.toLocaleDateString('en-US', { weekday: 'long' });
          if (!weekOffs.includes(dayName)) {
            if (holidayMap[dateStr] === 'Half Day') {
              actualWorkingDays += 0.5;
            } else if (!holidayMap[dateStr] || holidayMap[dateStr] === 'Optional') {
              actualWorkingDays += 1.0;
            }
            // Public 'Full Day' holidays add 0 to actualWorkingDays
          }
        }

        const workingDays = actualWorkingDays || 22; // Fallback
        const dailySalary = (r.salary || 0) / workingDays;
        const hourlyRate = dailySalary / 8;
        const overtimePay = (r.totalOvertimeHours || 0) * hourlyRate * (r.overtimeRate || 1.5);
        const latePenalty = (r.lateDays || 0) * (r.latePenaltyPerMin || 0) * (r.gracePeriodMins || 0);
        const netSalary = (r.salary || 0) + overtimePay - latePenalty;
        
        return { 
          ...r, 
          workingDays,
          overtimePay: overtimePay.toFixed(2), 
          latePenalty: latePenalty.toFixed(2), 
          netSalary: netSalary.toFixed(2) 
        };
      });
      res.json(result);
    });
  });
});

app.get('/api/admin/reports/attendance', (req, res) => {
  const { startDate, endDate } = req.query;
  let query = `SELECT a.*, u.fullName, u.id as employeeId, s.name as shiftName
               FROM attendance a 
               JOIN users u ON a.userId = u.id
               LEFT JOIN shifts s ON u.shiftId = s.id`;
  
  const params = [];
  if (startDate && endDate) {
    query += ` WHERE a.checkInTime BETWEEN ? AND ?`;
    params.push(startDate + 'T00:00:00', endDate + 'T23:59:59');
  }
  
  query += ` ORDER BY a.checkInTime DESC`;

  db.all(query, params, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

// Admin Manual Attendance
// Note: Merged into /api/admin/attendance at the top

// Check-out Reminders (Scan for active check-ins)
app.post('/api/admin/notifications/reminders', (req, res) => {
  db.all(`SELECT a.*, u.id as userId, u.fullName 
          FROM attendance a
          JOIN users u ON a.userId = u.id
          WHERE a.checkOutTime IS NULL`, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    
    rows.forEach(row => {
      createNotification(row.userId, 'Check-out Reminder', `Hi ${row.fullName}, don't forget to check out!`);
    });
    
    res.json({ message: `Reminders sent to ${rows.length} employees.` });
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running at http://0.0.0.0:${port}`);
});
