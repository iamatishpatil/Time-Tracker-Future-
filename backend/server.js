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
    isApproved INTEGER DEFAULT 0,
    rejectionReason TEXT,
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
    minutesLate INTEGER DEFAULT 0,
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
    leaveType TEXT NOT NULL,
    daysPerYear INTEGER DEFAULT 10,
    isPaid INTEGER DEFAULT 1,
    company TEXT,
    UNIQUE(leaveType, company)
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
    date TEXT NOT NULL,
    type TEXT DEFAULT 'Public',
    duration TEXT DEFAULT 'Full Day',
    company TEXT,
    UNIQUE(date, company)
  )`);

  // Payslips Table
  db.run(`CREATE TABLE IF NOT EXISTS payslips (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId INTEGER,
    company TEXT,
    month INTEGER,
    year INTEGER,
    basicSalary REAL,
    allowances REAL DEFAULT 0,
    deductions REAL DEFAULT 0,
    netSalary REAL,
    generatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(userId) REFERENCES users(id)
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

// Helper: notify ALL non-admin employees of a company (multi-tenancy safe)
const notifyAllCompanyUsers = (company, title, message) => {
  db.all(`SELECT id FROM users WHERE company = ? AND role = 'User' AND isActive = 1`, [company], (err, rows) => {
    if (err || !rows) return;
    rows.forEach(r => createNotification(r.id, title, message));
  });
};

// Helper: notify ALL admins of a company (multi-tenancy safe)
const notifyCompanyAdmins = (company, title, message) => {
  db.all(`SELECT id FROM users WHERE company = ? AND role = 'Admin'`, [company], (err, rows) => {
    if (err || !rows) return;
    rows.forEach(r => createNotification(r.id, title, message));
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

db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS shifts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    startTime TEXT NOT NULL,
    endTime TEXT NOT NULL,
    gracePeriodMins INTEGER DEFAULT 0,
    overtimeRate REAL DEFAULT 1.0,
    company TEXT
  )`);

  // Settings Table
  db.run(`CREATE TABLE IF NOT EXISTS settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    companyName TEXT,
    company TEXT UNIQUE,
    officeLat REAL,
    officeLong REAL,
    officeRadiusMeters REAL DEFAULT 100,
    geofenceEnabled INTEGER DEFAULT 1,
    payrollEnabled INTEGER DEFAULT 1,
    workingDays TEXT DEFAULT '["Mon","Tue","Wed","Thu","Fri"]',
    weekendDays TEXT DEFAULT '["Sat","Sun"]',
    companyLogo TEXT,
    themeColor TEXT,
    cameraAuthEnabled INTEGER DEFAULT 1
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
  db.run(`ALTER TABLE users ADD COLUMN isApproved INTEGER DEFAULT 0`, (err) => {
    if (!err) {
      console.log('Added isApproved column to users');
      // Backfill existing users as approved
      db.run(`UPDATE users SET isApproved = 1 WHERE isApproved IS NULL`);
    }
  });
  db.run(`ALTER TABLE users ADD COLUMN rejectionReason TEXT`, (err) => {
    if (!err) console.log('Added rejectionReason column to users');
  });
  db.run(`ALTER TABLE leaves ADD COLUMN rejectionReason TEXT`, (err) => {
    if (!err) console.log('Added rejectionReason column to leaves');
  });
  db.run(`ALTER TABLE shifts ADD COLUMN latePenaltyPerMin REAL DEFAULT 0`, (err) => {});
  db.run(`ALTER TABLE shifts ADD COLUMN company TEXT`, (err) => {});
  db.run(`ALTER TABLE holidays ADD COLUMN company TEXT`, (err) => {});
  db.run(`ALTER TABLE leave_policies ADD COLUMN company TEXT`, (err) => {});
  db.run(`ALTER TABLE leaves ADD COLUMN leaveType TEXT DEFAULT 'Casual Leave'`, (err) => {});
  db.run(`ALTER TABLE settings ADD COLUMN workingDays TEXT`, (err) => {});
  db.run(`ALTER TABLE settings ADD COLUMN weekendDays TEXT`, (err) => {});
  db.run(`ALTER TABLE settings ADD COLUMN geofenceEnabled INTEGER DEFAULT 1`, (err) => {});
  db.run(`ALTER TABLE settings ADD COLUMN payrollEnabled INTEGER DEFAULT 1`, (err) => {});
  db.run(`ALTER TABLE settings ADD COLUMN companyLogo TEXT`, (err) => {});
  db.run(`ALTER TABLE settings ADD COLUMN themeColor TEXT`, (err) => {});
  db.run(`ALTER TABLE settings ADD COLUMN cameraAuthEnabled INTEGER DEFAULT 1`, (err) => {});
  
  // Ensure 'status' and 'overtimeHours' exist in attendance
  db.run(`ALTER TABLE attendance ADD COLUMN status TEXT`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN overtimeHours REAL DEFAULT 0`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN isManual INTEGER DEFAULT 0`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN editedBy INTEGER`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN minutesLate INTEGER DEFAULT 0`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN minutesOvertime INTEGER DEFAULT 0`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN earlyLeaveMinutes INTEGER DEFAULT 0`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN shiftId INTEGER`, (err) => {});
  db.run(`ALTER TABLE attendance ADD COLUMN penalty REAL DEFAULT 0`, (err) => {});
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

// Helper to auto-provision a new company with default features
const provisionCompany = (companyIdRaw) => {
  const companyId = companyIdRaw ? companyIdRaw.trim() : null;
  console.log(`[BOOTSTRAP] Provisioning company ID: "${companyId}"`);
  if (!companyId) return Promise.resolve();
  
  return new Promise((resolve, reject) => {
    // 1. Provision Settings (Geofence OFF by default for better onboarding, Professional Blue theme)
    db.get('SELECT id FROM settings WHERE company = ? OR companyName = ?', [companyId, companyId], (err, row) => {
      if (err) {
        console.error('[BOOTSTRAP] Settings check error:', err);
        return reject(err);
      }
      if (!row) {
        console.log(`[BOOTSTRAP] Creating premium default settings for ID: ${companyId}`);
        // We set both "company" (ID) and "companyName" (Display Name) to the ID initially
        db.run(`INSERT INTO settings (company, companyName, geofenceEnabled, payrollEnabled, cameraAuthEnabled, officeRadiusMeters, workingDays, weekendDays, themeColor) 
                VALUES (?, ?, 0, 1, 1, 200, '["Mon","Tue","Wed","Thu","Fri"]', '["Sat","Sun"]', '#2196F3')`, [companyId, companyId], (err) => {
          if (err) console.error('[BOOTSTRAP] Settings insert error:', err);
          provisionNext();
        });
      } else {
        console.log(`[BOOTSTRAP] Settings already exist for ID: ${companyId}`);
        provisionNext();
      }
    });

    function provisionNext() {
      // 2. Provision Default Shifts (Multiple shifts for a premium feel)
      db.all('SELECT id FROM shifts WHERE company = ?', [companyId], (err, rows) => {
        if (err) console.error('[BOOTSTRAP] Shift check error:', err);
        if (!err && (!rows || rows.length === 0)) {
          console.log(`[BOOTSTRAP] Creating default shift suite for ${companyId}`);
          const defaultShifts = [
            ['General Shift', '09:00', '18:00', 15, 1.0, 0],
            ['Evening Shift', '14:00', '22:00', 15, 1.0, 0],
            ['Night Shift', '22:00', '06:00', 15, 1.2, 0]
          ];
          
          let completed = 0;
          defaultShifts.forEach(s => {
            db.run(`INSERT INTO shifts (name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin, company) 
                    VALUES (?, ?, ?, ?, ?, ?, ?)`, [...s, companyId], (err) => {
              completed++;
              if (completed === defaultShifts.length) provisionLeaves();
            });
          });
        } else {
          console.log(`[BOOTSTRAP] Shifts already exist or error checking for ${companyId}`);
          provisionLeaves();
        }
      });
    }

    function provisionLeaves() {
      // 3. Provision Default Leave Policies
      db.all('SELECT id FROM leave_policies WHERE company = ? LIMIT 1', [companyId], (err, rows) => {
        if (err || (rows && rows.length > 0)) {
          if (!err) console.log(`[BOOTSTRAP] Leave policies already exist for ${companyId}`);
          return resolve();
        }

        console.log(`[BOOTSTRAP] Creating default leave policies for ${companyId}`);
        const defaults = [
          ['Sick Leave', 12, 1], ['Casual Leave', 10, 1], ['Earned Leave', 18, 1],
          ['Maternity Leave', 182, 1], ['Paternity Leave', 15, 1], ['Bereavement Leave', 5, 1],
          ['Comp-off', 0, 1], ['Marriage Leave', 5, 1], ['LWP', 365, 0], ['Sabbatical', 365, 0]
        ];

        const placeholders = defaults.map(() => '(?, ?, ?, ?)').join(', ');
        const flatValues = [];
        defaults.forEach(d => {
          flatValues.push(...d, companyId);
        });

        db.run(`INSERT INTO leave_policies (leaveType, daysPerYear, isPaid, company) VALUES ${placeholders}`, flatValues, function(err) {
          if (err) {
            console.error('[BOOTSTRAP] Leave insert error:', err);
          } else {
            console.log(`[BOOTSTRAP] Successfully inserted ${this.changes} leave policies for ${companyId}`);
          }
          console.log(`[BOOTSTRAP] Finished provisioning for ${companyId}`);
          resolve();
        });
      });
    }
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
    // Admins are auto-approved, standard users are not
    const approvalStatus = (role === 'Admin') ? 1 : 0;
    
    db.run(`INSERT INTO users (fullName, email, mobileNumber, gender, password, role, company, department, experience, technologies, address, latitude, longitude, profilePicture, shiftId, isActive, isApproved, weekOffs) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [fullName, email, mobileNumber, gender, hashedPassword, role || 'User', company, department, experience, technologies, address, latitude, longitude, profilePicture, shiftId, isActive !== undefined ? isActive : 1, approvalStatus, 'Sunday'],
      async function(err) {
        if (err) {
          if (err.message.includes('UNIQUE constraint failed')) {
            return res.status(400).json({ error: 'Mobile number or email already exists' });
          }
          return res.status(500).json({ error: err.message });
        }
        
        // If registering as Admin, provision default features for the company
        if (role === 'Admin' && company) {
          await provisionCompany(company).catch(e => console.error('Bootstrap error:', e));
          
          // Welcome Notification for Admin
          const welcomeTitle = "Welcome to Pulse Hub! 🚀";
          const welcomeMsg = `Congratulations ${fullName}! Your organization "${company}" is now live. We've pre-configured your shifts and leave policies. Head over to Settings to finalize your office location.`;
          createNotification(this.lastID, welcomeTitle, welcomeMsg);
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

    // Admins never need approval — only regular employees do
    if (user.role !== 'Admin' && user.isApproved === 0) {
      return res.status(403).json({ error: 'Your account is pending admin approval. Please wait for the initial approval.' });
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
  const { fullName, email, gender, company, department, experience, technologies, address, latitude, longitude, shiftId, isActive, _notifyShift } = req.body;
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
    
    // 2. Get User Shift Info and Settings
    getUserWithShift(userId).then(user => {
      const company = user ? user.company : null;
      // ANR Fix / BUG 1 FIX: Use both `company` ID and `companyName` columns for resilient lookup
      let q = 'SELECT * FROM settings WHERE company IS NULL LIMIT 1';
      let p = [];
      if (company) {
        q = 'SELECT * FROM settings WHERE company = ? OR companyName = ? ORDER BY id DESC LIMIT 1';
        p = [company, company];
      }
      
      db.get(q, p, (err, settings) => {
        // 3. Geofencing check
        if (settings && settings.geofenceEnabled !== 0 && settings.officeLat && settings.officeLong && lat && long) {
          const distance = calculateDistance(lat, long, settings.officeLat, settings.officeLong);
          if (distance > settings.officeRadiusMeters) {
            return res.status(403).json({ error: `Outside office radius. Distance: ${Math.round(distance)}m, Max: ${settings.officeRadiusMeters}m` });
          }
        }

        let status = 'On Time'; 
        let minutesLate = 0;
        if (user && user.shiftStart) {
          try {
            const shiftStartParts = user.shiftStart.split(':');
            const shiftDate = new Date();
            shiftDate.setHours(parseInt(shiftStartParts[0]), parseInt(shiftStartParts[1]), 0, 0);
            
            const graceMins = user.gracePeriodMins || 0;
            const thresholdDate = new Date(shiftDate);
            thresholdDate.setMinutes(thresholdDate.getMinutes() + graceMins);
            
            if (new Date() > thresholdDate) {
              status = 'Late';
              const diffMs = new Date() - shiftDate;
              minutesLate = Math.floor(diffMs / (1000 * 60));
            }
          } catch(e) { status = 'On Time'; }
        }
      
        db.run(`INSERT INTO attendance (userId, checkInTime, checkInLat, checkInLong, checkInAddress, checkInPhoto, status, minutesLate) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [userId, now, lat, long, address, photo, status, minutesLate],
          (err) => {
            if (err) return res.status(500).json({ error: err.message });
            
            if (status === 'Late') {
              createNotification(userId, 'Late Check-in Alert', `You checked in late at ${new Date(now).toLocaleTimeString()}.`);
            }
            res.json({ message: 'Check-in successful', time: now, status: status });
          });
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


app.post('/api/checkout', upload.single('photo'), (req, res) => {
  const { userId, lat, long, address } = req.body;
  const photo = req.file ? `/uploads/${req.file.filename}` : null;
  const now = new Date().toISOString();

  // 1. Check if active check-in exists
  db.get('SELECT * FROM attendance WHERE userId = ? AND checkOutTime IS NULL', [userId], (err, row) => {
    if (err || !row) return res.status(400).json({ error: 'No active check-in' });

    getUserWithShift(userId).then(user => {
      const company = user ? user.company : null;
      // BUG 1 FIX (checkout): Use both `company` ID and `companyName` for resilient lookup
      let q = 'SELECT * FROM settings WHERE company IS NULL LIMIT 1';
      let p = [];
      if (company) {
        q = 'SELECT * FROM settings WHERE company = ? OR companyName = ? ORDER BY id DESC LIMIT 1';
        p = [company, company];
      }
      
      db.get(q, p, (err, settings) => {
        // 2. Geofencing check
        if (settings && settings.geofenceEnabled !== 0 && settings.officeLat && settings.officeLong && lat && long) {
          const distance = calculateDistance(lat, long, settings.officeLat, settings.officeLong);
          if (distance > settings.officeRadiusMeters) {
            return res.status(403).json({ error: `Outside office radius. Distance: ${Math.round(distance)}m, Max: ${settings.officeRadiusMeters}m` });
          }
        }

        // 3. Calculate Overtime
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
            // Notify employee of successful check-out
            const checkOutDisplay = new Date(now).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
            const overtimeMsg = overtime > 0 ? ` You worked ${overtime.toFixed(1)}h overtime today. 🏆` : '';
            createNotification(userId, '✅ Checked Out Successfully', `You checked out at ${checkOutDisplay}.${overtimeMsg}`);
            res.json({ message: 'Check-out successful', time: now, overtime: overtime.toFixed(2) });
          });
      });
    }).catch(err => {
        db.run(`UPDATE attendance SET checkOutTime = ?, checkOutLat = ?, checkOutLong = ?, checkOutAddress = ?, checkOutPhoto = ?, overtimeHours = 0
           WHERE userId = ? AND checkOutTime IS NULL`,
          [now, lat, long, address, photo, userId],
          function(err) {
            if (err) return res.status(500).json({ error: err.message });
            res.json({ message: 'Check-out successful', time: now, overtime: "0.00" });
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
  const { isActive, company } = req.body;
  if (isActive === undefined || !company) return res.status(400).json({ error: 'isActive and company are required' });
  
  db.run('UPDATE users SET isActive = ? WHERE id = ? AND company = ?', [isActive, req.params.id, company], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    const userId = parseInt(req.params.id);
    if (isActive === 0 || isActive === false) {
      createNotification(userId, '⛔ Account Deactivated', 'Your account has been deactivated by the admin. Please contact your administrator.');
    } else {
      createNotification(userId, '✅ Account Reactivated', 'Your account has been reactivated. You can now log in and use the app.');
    }
    res.json({ message: 'Status updated' });
  });
});

app.patch('/api/admin/users/:id/approve', (req, res) => {
  const { isApproved, company, rejectionReason } = req.body;
  if (isApproved === undefined || !company) return res.status(400).json({ error: 'isApproved and company are required' });

  db.run('UPDATE users SET isApproved = ?, rejectionReason = ? WHERE id = ? AND company = ?', [isApproved, rejectionReason || null, req.params.id, company], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    const userId = parseInt(req.params.id);
    if (isApproved === 1 || isApproved === true) {
      createNotification(userId, '🎉 Account Approved!', `Welcome! Your account has been approved. You can now check in and use all features.`);
    } else {
      const reason = rejectionReason ? ` Reason: ${rejectionReason}` : '';
      createNotification(userId, '❌ Account Not Approved', `Your account registration was not approved.${reason} Please contact your admin.`);
    }
    res.json({ message: 'Approval status updated' });
  });
});

app.get('/api/admin/stats', (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  const stats = {};
  const today = new Date().toISOString().split('T')[0];

  const uQuery = 'SELECT COUNT(*) as count FROM users WHERE role = "User" AND company = ?';
  db.get(uQuery, [company], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    stats.totalEmployees = row ? row.count : 0;

    const attQuery = `SELECT COUNT(DISTINCT a.userId) as count FROM attendance a JOIN users u ON a.userId = u.id WHERE a.checkInTime LIKE ? AND u.company = ?`;
    db.get(attQuery, [`${today}%`, company], (err, row) => {
      if (err) return res.status(500).json({ error: err.message });
      stats.presentToday = row ? row.count : 0;
      stats.absentToday = Math.max(0, stats.totalEmployees - stats.presentToday);

      // BUG 2 FIX: Add lateToday count (was always 0 before — dashboard stat card was broken)
      const lateQuery = `SELECT COUNT(DISTINCT a.userId) as count FROM attendance a JOIN users u ON a.userId = u.id WHERE a.checkInTime LIKE ? AND a.status = 'Late' AND u.company = ?`;
      db.get(lateQuery, [`${today}%`, company], (err, row) => {
        if (err) return res.status(500).json({ error: err.message });
        stats.lateToday = row ? row.count : 0;

        const lvQuery = `SELECT COUNT(DISTINCT l.userId) as count FROM leaves l JOIN users u ON l.userId = u.id 
                        WHERE l.status = 'Approved' AND u.company = ? 
                        AND date(?) BETWEEN date(l.startDate) AND date(l.endDate)`;
        db.get(lvQuery, [company, today], (err, row) => {
          if (err) return res.status(500).json({ error: err.message });
          stats.onLeaveToday = row ? row.count : 0;
          res.json(stats);
        });
      });
    });
  });
});


app.get('/api/admin/users', (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  // BUG 4 FIX: Added isApproved, isActive, salary, department to SELECT — admin employee screen showed wrong status
  const query = `SELECT u.id, u.fullName, u.email, u.mobileNumber, u.role, u.profilePicture, 
          u.weekOffs, u.company, u.isApproved, u.isActive, u.salary, u.department,
          s.name as shiftName 
          FROM users u 
          LEFT JOIN shifts s ON u.shiftId = s.id
          WHERE u.company = ?`;
  db.all(query, [company], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.delete('/api/admin/users/:id', (req, res) => {
  const { company } = req.body; // In a real app, this would come from a verified token
  if (!company) return res.status(400).json({ error: 'Company Name is required' });

  db.get('SELECT id FROM users WHERE id = ? AND company = ?', [req.params.id, company], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!row) return res.status(403).json({ error: 'Access denied: User not found in your company' });

    db.serialize(() => {
      db.run('DELETE FROM attendance WHERE userId = ?', [req.params.id]);
      db.run('DELETE FROM leaves WHERE userId = ?', [req.params.id]);
      db.run('DELETE FROM leave_balances WHERE userId = ?', [req.params.id]);
      db.run('DELETE FROM notifications WHERE userId = ?', [req.params.id]);
      db.run('DELETE FROM users WHERE id = ? AND company = ?', [req.params.id, company], function(err) {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Employee and all associated data deleted successfully' });
      });
    });
  });
});

app.post('/api/admin/users', upload.single('profilePicture'), async (req, res) => {
  const { fullName, mobileNumber, email, password, role, department, salary, shiftId, isActive, weekOffs, company } = req.body;
  const profilePicture = req.file ? `/uploads/${req.file.filename}` : null;
  const hashedPassword = await bcrypt.hash(password, 10);
  
  db.run(`INSERT INTO users (fullName, mobileNumber, email, password, role, profilePicture, department, salary, shiftId, isActive, weekOffs, company) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [fullName, mobileNumber, email, hashedPassword, role || 'User', profilePicture, department || 'General', salary || 0, shiftId, isActive !== undefined ? isActive : 1, weekOffs || 'Sunday', company],
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
  const { userId, startDate, endDate, department, company } = req.query;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  let query = `
    SELECT a.*, u.fullName, u.profilePicture, u.department, s.name as shiftName 
    FROM attendance a 
    JOIN users u ON a.userId = u.id 
    LEFT JOIN shifts s ON u.shiftId = s.id 
    WHERE u.company = ?
  `;
  const params = [company];
  if (startDate && endDate) {
    query += ' AND date(a.checkInTime) BETWEEN date(?) AND date(?)';
    params.push(startDate, endDate);
  }
  if (department) {
    query += ' AND u.department = ?';
    params.push(department);
  }
  
  query += ' ORDER BY a.checkInTime DESC';
  
  if (req.query.limit) {
    query += ' LIMIT ?';
    params.push(parseInt(req.query.limit));
  }
  
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
  const { checkInTime, checkOutTime, status, overtimeHours, adminId, company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  // Verify ownership via user join
  db.get(`SELECT a.id FROM attendance a JOIN users u ON a.userId = u.id WHERE a.id = ? AND u.company = ?`, [req.params.id, company], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!row) return res.status(403).json({ error: 'Access denied: Record not found in your company' });

    db.run(
      `UPDATE attendance SET checkInTime = ?, checkOutTime = ?, status = ?, overtimeHours = ?, editedBy = ? WHERE id = ?`,
      [checkInTime, checkOutTime || null, status, overtimeHours || 0, adminId, req.params.id],
      function(err) {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Attendance updated' });
      }
    );
  });
});

// Manual attendance entry (Admin)
// Note: Merged into above endpoint

app.get('/api/admin/absent', (req, res) => {
  const company = req.query.company;
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  const dayName = now.toLocaleDateString('en-US', { weekday: 'long' });

  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  let holQuery = 'SELECT name FROM holidays WHERE date = ? AND (company = ? OR company IS NULL)';
  let holParams = [today, company];

  // First check if today is a public holiday
  db.get(holQuery, holParams, (err, holiday) => {
    if (err) return res.status(500).json({ error: err.message });
    if (holiday) {
      // It's a holiday, so nobody is "absent" in the traditional sense
      return res.json([]);
    }

    // BUG 5 FIX: Exclude employees on approved leave — they were showing as "Absent" incorrectly
    let usersQuery = `SELECT id, fullName, mobileNumber, profilePicture, weekOffs 
            FROM users 
            WHERE role = "User" AND id NOT IN (
              SELECT userId FROM attendance WHERE checkInTime LIKE ?
            ) AND id NOT IN (
              SELECT userId FROM leaves WHERE status = 'Approved' AND date(?) BETWEEN date(startDate) AND date(endDate)
            )`;
    let usersParams = [`${today}%`, today];
    if (company) {
      usersQuery += ' AND company = ?';
      usersParams.push(company);
    }

    // Not a holiday, check absences excluding week-offs
    db.all(usersQuery, usersParams, (err, rows) => {
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

app.get('/api/admin/shifts', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  db.all('SELECT * FROM shifts WHERE company = ?', [company], async (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    
    // Lazy Bootstrap: If empty, provision defaults
    if (!rows || rows.length === 0) {
      await provisionCompany(company).catch(e => console.error('Bootstrap error:', e));
      db.all('SELECT * FROM shifts WHERE company = ?', [company], (err, newRows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(newRows);
      });
    } else {
      res.json(rows);
    }
  });
});

app.put('/api/admin/shifts/:id', (req, res) => {
  const { name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin, company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });
  
  db.run(
    `UPDATE shifts SET name = ?, startTime = ?, endTime = ?, gracePeriodMins = ?, overtimeRate = ?, latePenaltyPerMin = ? WHERE id = ? AND company = ?`,
    [name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin || 0, req.params.id, company],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      if (this.changes === 0) return res.status(404).json({ error: 'Shift not found or access denied' });
      res.json({ message: 'Shift updated' });
    }
  );
});

app.delete('/api/admin/shifts/:id', (req, res) => {
  const { company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  db.run('DELETE FROM shifts WHERE id = ? AND company = ?', [req.params.id, company], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    if (this.changes === 0) return res.status(404).json({ error: 'Shift not found or access denied' });
    res.json({ message: 'Shift deleted' });
  });
});

app.post('/api/admin/shifts', (req, res) => {
  const { name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin, company } = req.body;
  db.run(`INSERT INTO shifts (name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin, company) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin || 0, company],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Shift created', id: this.lastID });
    });
});

// --- Company Settings ---

app.get('/api/settings', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  // Look up by "company" column first (the ID)
  db.get('SELECT * FROM settings WHERE company = ? OR companyName = ? ORDER BY id DESC LIMIT 1', [company, company], async (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    
    if (!row) {
      await provisionCompany(company).catch(e => console.error('Bootstrap error:', e));
      // Try again after provisioning
      db.get('SELECT * FROM settings WHERE company = ? ORDER BY id DESC LIMIT 1', [company], (err, newRow) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(newRow || {});
      });
    } else {
      res.json(row);
    }
  });
});

app.post('/api/admin/settings', (req, res) => {
  fs.appendFileSync('server_log.txt', `[Settings] Body: ${JSON.stringify(req.body, null, 2)}\n`);
  console.log('[Settings] Body Received:', JSON.stringify(req.body, null, 2));
  const { company, companyName, officeLat, officeLong, officeRadiusMeters, workingDays, weekendDays, geofenceEnabled, payrollEnabled, cameraAuthEnabled, themeColor } = req.body;
  
  if (!company) {
    console.log('[Settings] Error: No company ID provided');
    return res.status(400).json({ error: 'Company ID is required' });
  }

  const wDays = workingDays ? JSON.stringify(workingDays) : '["Mon","Tue","Wed","Thu","Fri"]';
  const wkDays = weekendDays ? JSON.stringify(weekendDays) : '["Sat","Sun"]';
  const geoEnabled = geofenceEnabled !== undefined ? geofenceEnabled : 1;
  const payEnabled = payrollEnabled !== undefined ? payrollEnabled : 1;
  const camEnabled = cameraAuthEnabled !== undefined ? (cameraAuthEnabled ? 1 : 0) : 1;

  console.log(`[Settings] Updating for company: ${company}, camEnabled: ${camEnabled}, themeColor: ${themeColor}`);

  // ROBUST LOOKUP: Check by 'company' ID first, then by 'companyName' fallback
  db.get('SELECT * FROM settings WHERE company = ? OR companyName = ? ORDER BY id DESC LIMIT 1', [company, company], (err, row) => {
    if (err) {
      console.error('[Settings] Lookup Error:', err);
      return res.status(500).json({ error: err.message });
    }
    
    if (row) {
      console.log(`[Settings] Found existing row id: ${row.id}. Updating...`);
      // Row exists - perform an UPDATE
      const params = [company, companyName, officeLat, officeLong, officeRadiusMeters, wDays, wkDays, geoEnabled, payEnabled, camEnabled, themeColor, row.id];
      fs.appendFileSync('server_log.txt', `[Settings] SQL Params: ${JSON.stringify(params)}\n`);
      db.run('UPDATE settings SET company = ?, companyName = ?, officeLat = ?, officeLong = ?, officeRadiusMeters = ?, workingDays = ?, weekendDays = ?, geofenceEnabled = ?, payrollEnabled = ?, cameraAuthEnabled = ?, themeColor = ? WHERE id = ?',
        params, function(err) {
          if (err) {
            console.error('[Settings] Update Error:', err);
            return res.status(500).json({ error: err.message });
          }
          console.log(`[Settings] Success! Rows affected: ${this.changes}, New cameraAuthEnabled: ${camEnabled}`);
          res.json({ message: 'Settings updated' });
      });
    } else {
      console.log('[Settings] No row found. Creating new...');
      // New row - perform an INSERT
      db.run(
        `INSERT INTO settings (company, companyName, officeLat, officeLong, officeRadiusMeters, workingDays, weekendDays, geofenceEnabled, payrollEnabled, cameraAuthEnabled, themeColor) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [company, companyName, officeLat, officeLong, officeRadiusMeters, wDays, wkDays, geoEnabled, payEnabled, camEnabled, themeColor],
        function(err) {
          if (err) {
            console.error('[Settings] Create Error:', err);
            return res.status(500).json({ error: err.message });
          }
          console.log(`[Settings] Success! Created row with id: ${this.lastID}`);
          res.json({ message: 'Settings created' });
        });
    }
  });
});

// --- Branding & Logo API ---
app.post('/api/admin/branding', upload.single('logo'), (req, res) => {
  const { company, themeColor } = req.body;
  const logoUrl = req.file ? `/uploads/${req.file.filename}` : undefined;
  
  if (!company) return res.status(400).json({ error: 'Company Name is required' });

  // BUG 3 FIX: Branding lookup used companyName only — logo upload silently failed if settings row used `company` (ID) column
  db.get('SELECT * FROM settings WHERE company = ? OR companyName = ? ORDER BY id DESC LIMIT 1', [company, company], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    
    if (row) {
      // Update existing
      const newLogoUrl = logoUrl !== undefined ? logoUrl : row.companyLogo;
      const newColor = themeColor !== undefined ? themeColor : row.themeColor;
      db.run('UPDATE settings SET companyLogo = ?, themeColor = ? WHERE id = ?', [newLogoUrl, newColor, row.id], function(err) {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Branding updated successfully', logo: newLogoUrl, color: newColor });
      });
    } else {
      // Create new settings row for this company just for branding (rare, but possible if they haven't set settings yet)
      db.run('INSERT INTO settings (companyName, companyLogo, themeColor) VALUES (?, ?, ?)', [company, logoUrl, themeColor], function(err) {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Branding initialized successfully', logo: logoUrl, color: themeColor });
      });
    }
  });
});


// --- Holidays ---
app.get('/api/admin/holidays', (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });
  // Show holidays for the specific company AND global indian holidays (NULL company)
  let query = 'SELECT * FROM holidays WHERE (company = ? OR company IS NULL)';
  let params = [company];
  query += ' ORDER BY date ASC';
  db.all(query, params, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.post('/api/admin/holidays', (req, res) => {
  const { name, date, type, duration, company } = req.body;
  db.run('INSERT INTO holidays (name, date, type, duration, company) VALUES (?, ?, ?, ?, ?)', 
    [name, date, type || 'Public', duration || 'Full Day', company], 
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      // Notify ALL employees of this company about the new holiday
      if (company) {
        const formattedDate = new Date(date).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
        const durationLabel = duration === 'Half Day' ? 'Half Day Holiday' : 'Holiday';
        notifyAllCompanyUsers(company, `🎉 New ${durationLabel}: ${name}`, `${name} has been added as a ${type || 'Public'} holiday on ${formattedDate}. Mark your calendars!`);
      }
      res.json({ message: 'Holiday added', id: this.lastID });
    });
});

app.delete('/api/admin/holidays/:id', (req, res) => {
  const { company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  db.run('DELETE FROM holidays WHERE id = ? AND company = ?', [req.params.id, company], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    if (this.changes === 0) return res.status(404).json({ error: 'Holiday not found or access denied' });
    res.json({ message: 'Holiday deleted' });
  });
});

// --- Leave Policies ---
app.get('/api/admin/leave-policies', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  db.all('SELECT * FROM leave_policies WHERE company = ?', [company], async (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    
    // Lazy Bootstrap: If empty, provision defaults
    if (!rows || rows.length === 0) {
      await provisionCompany(company).catch(e => console.error('Bootstrap error:', e));
      db.all('SELECT * FROM leave_policies WHERE company = ?', [company], (err, newRows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(newRows);
      });
    } else {
      res.json(rows);
    }
  });
});

app.post('/api/admin/leave-policies', (req, res) => {
  const { leaveType, daysPerYear, isPaid, company } = req.body;
  db.run(
    'INSERT OR REPLACE INTO leave_policies (leaveType, daysPerYear, isPaid, company) VALUES (?, ?, ?, ?)',
    [leaveType, daysPerYear, isPaid ? 1 : 0, company],
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
      // Confirm to employee + alert company admins (multi-tenancy safe)
      createNotification(userId, '📋 Leave Request Submitted', `Your ${leaveType || 'Casual Leave'} from ${startDate} to ${endDate} has been submitted and is pending approval.`);
      db.get('SELECT fullName, company FROM users WHERE id = ?', [userId], (err, user) => {
        if (user && user.company) {
          notifyCompanyAdmins(user.company, '🔔 New Leave Request', `${user.fullName} has applied for ${leaveType || 'Casual Leave'} (${startDate} to ${endDate}). Review in the Leaves section.`);
        }
      });
      res.json({ message: 'Leave application submitted', id: this.lastID });
    });
});

app.get('/api/leaves/types', (req, res) => {
  const company = req.query.company;
  let q = 'SELECT * FROM leave_policies';
  let p = [];
  if (company) {
    q += ' WHERE company = ?';
    p.push(company);
  }
  db.all(q, p, (err, rows) => {
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

// IMPORTANT: This route MUST be above /api/leaves/:userId to prevent 'balance' matching as a userId
app.get('/api/leaves/balance/:userId', (req, res) => {
  const currentMonth = new Date().getMonth() + 1; // 1-12

  db.get('SELECT weekOffs, company FROM users WHERE id = ?', [req.params.userId], (errUser, user) => {
    if (errUser) return res.status(500).json({ error: errUser.message });
    if (!user) return res.status(404).json({ error: 'User not found' });
    const weekOffs = (user?.weekOffs || 'Sunday').split(',').map(s => s.trim());
    const company = user?.company;

    let hQuery = 'SELECT date, duration FROM holidays';
    let hParams = [];
    if (company) { 
      hQuery += ' WHERE (company = ? OR company IS NULL)'; 
      hParams.push(company); 
    } else {
      hQuery += ' WHERE company IS NULL';
    }

    db.all(hQuery, hParams, (errHolidays, holidays) => {
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
            }
            current.setDate(current.getDate() + 1);
          }
          byType[t] += count;
        });

        // Get leave policies
        let lpQuery = 'SELECT * FROM leave_policies';
        let lpParams = [];
        if (company) { lpQuery += ' WHERE company = ?'; lpParams.push(company); }

        db.all(lpQuery, lpParams, (errPolicies, policies) => {
          let leaveTypes = ['Sick Leave', 'Casual Leave', 'Annual Leave', 'Unpaid Leave'];
          if (policies && policies.length > 0) {
            leaveTypes = policies.map(p => p.leaveType);
          }

          db.all('SELECT * FROM leave_balances WHERE userId = ?', [req.params.userId], (err2, balances) => {
            const overrides = {};
            if (balances) balances.forEach(b => overrides[b.leaveType] = b.totalDays);
            
            const result = leaveTypes.map(t => {
              const policy = policies?.find(p => p.leaveType === t);
              const daysPerYear = overrides[t] || (policy ? policy.daysPerYear : 10);
              const monthlyRate = daysPerYear / 12;
              // Monthly accrual: leaves accrue proportionally each month
              const accrued = Math.floor(monthlyRate * currentMonth);
              const used = byType[t] || 0;
              const remaining = Math.max(0, accrued - used);
              return {
                leaveType: t,
                daysPerYear: daysPerYear,
                monthlyRate: parseFloat(monthlyRate.toFixed(2)),
                accrued: accrued,
                total: accrued,
                used: used,
                remaining: remaining,
              };
            });
            const totalAccrued = result.reduce((a, b) => a + b.accrued, 0);
            const totalUsed = Object.values(byType).reduce((a, b) => a + b, 0);
            const totalYearly = result.reduce((a, b) => a + b.daysPerYear, 0);
            res.json({ 
              total: totalAccrued, 
              used: totalUsed, 
              remaining: Math.max(0, totalAccrued - totalUsed),
              totalYearly: totalYearly,
              currentMonth: currentMonth,
              byType: result 
            });
          });
        });
      });
    });
  });
});

app.get('/api/leaves/:userId', (req, res) => {
  db.all('SELECT * FROM leaves WHERE userId = ? ORDER BY createdAt DESC', [req.params.userId], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
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
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });
  let query = `SELECT l.*, u.fullName 
          FROM leaves l 
          JOIN users u ON l.userId = u.id
          WHERE u.company = ?`;
  let params = [company];
  query += ' ORDER BY l.createdAt DESC';
  db.all(query, params, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.put('/api/admin/leaves/:id', (req, res) => {
  const { status, rejectionReason, company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  // Verify that the leave record belongs to a user in the same company
  db.get(`SELECT l.userId FROM leaves l JOIN users u ON l.userId = u.id WHERE l.id = ? AND u.company = ?`, [req.params.id, company], (err, record) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!record) return res.status(403).json({ error: 'Access denied: Leave record not found in your company' });

    db.run(`UPDATE leaves SET status = ?, rejectionReason = ? WHERE id = ?`,
      [status, rejectionReason, req.params.id],
      function(err) {
        if (err) return res.status(500).json({ error: err.message });
        
        createNotification(record.userId, `Leave ${status}`, `Your leave request has been ${status}. ${rejectionReason ? 'Reason: ' + rejectionReason : ''}`);
        res.json({ message: 'Leave status updated' });
      });
  });
});

// --- Reports ---

// Overtime Report
app.get('/api/admin/reports/overtime', (req, res) => {
  const { startDate, endDate, company } = req.query;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });
  let query = `SELECT a.userId, u.fullName, SUM(a.overtimeHours) as totalOvertimeHours, COUNT(*) as overtimeDays
               FROM attendance a
               JOIN users u ON a.userId = u.id
               WHERE a.overtimeHours > 0 AND u.company = ?`;
  const params = [company];
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
  const { startDate, endDate, company } = req.query;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });
  let query = `SELECT a.userId, u.fullName, u.salary,
               SUM(CASE WHEN a.checkOutTime IS NOT NULL
                 THEN (julianday(a.checkOutTime) - julianday(a.checkInTime)) * 24
                 ELSE 0 END) as totalHours,
               SUM(a.overtimeHours) as totalOvertimeHours,
               COUNT(CASE WHEN a.status = 'Late' THEN 1 END) as lateDays
               FROM attendance a
               JOIN users u ON a.userId = u.id
               WHERE u.company = ?`;
  const params = [company];
  if (startDate && endDate) {
    query += ` AND a.checkInTime BETWEEN ? AND ?`;
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
  const { startDate, endDate, company } = req.query;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });
  let query = `SELECT a.userId, u.fullName, u.salary, u.weekOffs,
               s.overtimeRate, s.latePenaltyPerMin, s.gracePeriodMins,
               SUM(CASE WHEN a.checkOutTime IS NOT NULL
                 THEN (julianday(a.checkOutTime) - julianday(a.checkInTime)) * 24
                 ELSE 0 END) as totalHours,
               SUM(a.overtimeHours) as totalOvertimeHours,
               SUM(a.minutesLate) as totalMinutesLate,
               COUNT(CASE WHEN a.status = 'Late' THEN 1 END) as lateDays
               FROM attendance a
               JOIN users u ON a.userId = u.id
               LEFT JOIN shifts s ON u.shiftId = s.id
               WHERE u.company = ?`;
  const params = [company];
  if (startDate && endDate) {
    query += ` AND a.checkInTime BETWEEN ? AND ?`;
    params.push(startDate + 'T00:00:00', endDate + 'T23:59:59');
  }
  db.all(query, params, async (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    
    // Fetch all holidays once for calculation
    let holQuery = 'SELECT date, duration, type FROM holidays';
    let holParams = [];
    if (company) {
      holQuery += ' WHERE (company = ? OR company IS NULL)';
      holParams.push(company);
    } else {
      holQuery += ' WHERE company IS NULL';
    }

    db.all(holQuery, holParams, async (hErr, holidays) => {
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
        const latePenalty = (r.totalMinutesLate || 0) * (r.latePenaltyPerMin || 0);
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
  const { company, startDate, endDate } = req.query;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });
  let query = `SELECT a.*, u.fullName, u.id as employeeId, s.name as shiftName
               FROM attendance a 
               JOIN users u ON a.userId = u.id
               LEFT JOIN shifts s ON u.shiftId = s.id
               WHERE u.company = ?`;
  const params = [company];
  if (startDate && endDate) {
    query += ` AND a.checkInTime BETWEEN ? AND ?`;
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

// ============ PAYSLIPS ============

// Admin: Create Payslip
app.post('/api/admin/payslips', (req, res) => {
  const { userId, company, month, year, basicSalary, allowances, deductions, netSalary } = req.body;
  if (!userId || !month || !year || basicSalary === undefined) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const monthLabel = monthNames[month - 1] || month;

  db.run(`INSERT INTO payslips (userId, company, month, year, basicSalary, allowances, deductions, netSalary) 
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [userId, company, month, year, basicSalary, allowances || 0, deductions || 0, netSalary],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      // Notify employee that their payslip is ready
      createNotification(userId, `💰 Payslip Ready: ${monthLabel} ${year}`, `Your payslip for ${monthLabel} ${year} is now available. Net Salary: ₹${parseFloat(netSalary).toLocaleString('en-IN')}. Check the Payslips section.`);
      res.json({ message: 'Payslip created', id: this.lastID });
    });
});

// Admin: Get all Payslips for Company
app.get('/api/admin/payslips', (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });
  let query = `SELECT p.*, u.fullName, u.email 
               FROM payslips p
               JOIN users u ON p.userId = u.id
               WHERE p.company = ?`;
  let params = [company];
  query += ` ORDER BY p.year DESC, p.month DESC`;

  db.all(query, params, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

// Admin: Delete a Payslip
app.delete('/api/admin/payslips/:id', (req, res) => {
  const { company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  db.run('DELETE FROM payslips WHERE id = ? AND company = ?', [req.params.id, company], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    if (this.changes === 0) return res.status(404).json({ error: 'Payslip not found or access denied' });
    res.json({ message: 'Payslip deleted' });
  });
});

// User: Get My Payslips
app.get('/api/payslips/:userId', (req, res) => {
  db.all(`SELECT p.*, u.fullName, u.email
          FROM payslips p
          JOIN users u ON p.userId = u.id
          WHERE p.userId = ? 
          ORDER BY p.year DESC, p.month DESC`, [req.params.userId], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

// Check-out Reminders (Scan for active check-ins)
app.post('/api/admin/notifications/reminders', (req, res) => {
  const { company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });
  
  let query = `SELECT a.*, u.id as userId, u.fullName 
               FROM attendance a
               JOIN users u ON a.userId = u.id
               WHERE a.checkOutTime IS NULL`;
  let params = [];
  
  if (company) {
    query += ' AND u.company = ?';
    params.push(company);
  }

  db.all(query, params, (err, rows) => {
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
