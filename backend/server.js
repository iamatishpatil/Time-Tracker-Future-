const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const multer = require('multer');
const cors = require('cors');
const bodyParser = require('body-parser');
const bcrypt = require('bcryptjs');
const path = require('path');
const fs = require('fs');

const app = express();
const port = 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Ensure uploads directory exists
if (!fs.existsSync('./uploads')) {
  fs.mkdirSync('./uploads');
}

// Multer Storage Configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, './uploads/'),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname),
});
const upload = multer({ storage: storage });

// Database Setup
const db = new sqlite3.Database('./time_tracker.db');

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
    FOREIGN KEY(userId) REFERENCES users(id)
  )`);
  
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
    startDate TEXT NOT NULL,
    endDate TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'Pending',
    rejectionReason TEXT,
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(userId) REFERENCES users(id)
  )`);
});

// Helper for sending OTP (Mocked)
const sendOtpMock = (type, value, otp) => {
  console.log(`[VERIFICATION] Sent ${type} OTP to ${value}: ${otp}`);
};

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
  db.get(`SELECT * FROM otps WHERE (mobileNumber = ? OR email = ?) AND otp = ? AND expiresAt > ? ORDER BY id DESC LIMIT 1`,
    [mobileNumber, email, otp, new Date().toISOString()],
    (err, row) => {
      if (err) return res.status(500).json({ error: err.message });
      if (!row) return res.status(400).json({ error: 'Invalid or expired OTP' });
      res.json({ message: 'OTP verified' });
    });
});

app.post('/api/reset-password', (req, res) => {
  const { mobileNumber, otp, newPassword } = req.body;
  db.get(`SELECT * FROM otps WHERE mobileNumber = ? AND otp = ? AND expiresAt > ? ORDER BY id DESC LIMIT 1`,
    [mobileNumber, otp, new Date().toISOString()],
    (err, row) => {
      if (err) return res.status(500).json({ error: err.message });
      if (!row) return res.status(400).json({ error: 'Verification failed' });
      
      db.run(`UPDATE users SET password = ? WHERE mobileNumber = ?`, [newPassword, mobileNumber], (err) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Password updated' });
      });
    });
});

// --- Registration & Login ---

app.post('/api/register', upload.single('profilePicture'), (req, res) => {
  const { fullName, email, mobileNumber, gender, password, role, company, department, experience, technologies, address, latitude, longitude } = req.body;
  const profilePicture = req.file ? `/uploads/${req.file.filename}` : null;

  db.run(`INSERT INTO users (fullName, email, mobileNumber, gender, password, role, company, department, experience, technologies, address, latitude, longitude, profilePicture) 
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [fullName, email, mobileNumber, gender, password, role || 'User', company, department, experience, technologies, address, latitude, longitude, profilePicture],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'User registered', id: this.lastID });
    });
});


app.post('/api/login', async (req, res) => {
  const { mobileNumber, password } = req.body;
  
  try {
    // Use promisified db.get
    const user = await new Promise((resolve, reject) => {
      db.get('SELECT * FROM users WHERE mobileNumber = ?', [mobileNumber], (err, row) => {
        if (err) reject(err);
        else resolve(row);
      });
    });
    
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
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
  db.get('SELECT * FROM users WHERE id = ?', [req.params.id], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(row);
  });
});

app.put('/api/user/:id', upload.single('profilePicture'), (req, res) => {
  const { fullName, email, gender, company, department, experience, technologies, address, latitude, longitude } = req.body;
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
});

// --- Attendance ---

app.post('/api/checkin', upload.single('photo'), (req, res) => {
  const { userId, lat, long, address } = req.body;
  const photo = req.file ? `/uploads/${req.file.filename}` : null;
  const now = new Date().toISOString();

  // Check if already checked in
  db.get('SELECT * FROM attendance WHERE userId = ? AND checkOutTime IS NULL', [userId], (err, row) => {
    if (row) return res.status(400).json({ error: 'Already checked in' });
    
    db.run(`INSERT INTO attendance (userId, checkInTime, checkInLat, checkInLong, checkInAddress, checkInPhoto) VALUES (?, ?, ?, ?, ?, ?)`,
      [userId, now, lat, long, address, photo],
      (err) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Check-in successful', time: now });
      });
  });
});

app.post('/api/checkout', upload.single('photo'), (req, res) => {
  const { userId, lat, long, address } = req.body;
  const photo = req.file ? `/uploads/${req.file.filename}` : null;
  const now = new Date().toISOString();

  db.run(`UPDATE attendance SET checkOutTime = ?, checkOutLat = ?, checkOutLong = ?, checkOutAddress = ?, checkOutPhoto = ? 
          WHERE userId = ? AND checkOutTime IS NULL`,
    [now, lat, long, address, photo, userId],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      if (this.changes === 0) return res.status(400).json({ error: 'No active check-in found' });
      res.json({ message: 'Check-out successful', time: now });
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

app.get('/api/admin/stats', (req, res) => {
  const stats = {};
  const today = new Date().toISOString().split('T')[0];
  
  db.get('SELECT COUNT(*) as count FROM users WHERE role = "User"', (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    stats.totalEmployees = row ? row.count : 0;
    
    db.get('SELECT COUNT(DISTINCT userId) as count FROM attendance WHERE checkInTime LIKE ?', [`${today}%`], (err, row) => {
      if (err) return res.status(500).json({ error: err.message });
      stats.presentToday = row ? row.count : 0;
      stats.absentToday = Math.max(0, stats.totalEmployees - stats.presentToday);
      stats.onLeaveToday = 0; // Simple mock
      res.json(stats);
    });
  });
});

app.get('/api/admin/users', (req, res) => {
  db.all('SELECT id, fullName, email, mobileNumber, role, profilePicture FROM users', (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.post('/api/admin/users', upload.single('profilePicture'), (req, res) => {
  const { fullName, email, mobileNumber, password, role } = req.body;
  const userRole = role || 'User';
  const profilePicture = req.file ? `/uploads/${req.file.filename}` : null;

  db.run(`INSERT INTO users (fullName, email, mobileNumber, password, role, profilePicture) VALUES (?, ?, ?, ?, ?, ?)`,
    [fullName, email, mobileNumber, password, userRole, profilePicture],
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

app.delete('/api/admin/users/:id', (req, res) => {
  db.run('DELETE FROM users WHERE id = ?', [req.params.id], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'User deleted successfully' });
  });
});

app.get('/api/admin/attendance', (req, res) => {
  db.all(`SELECT a.*, u.fullName, u.profilePicture 
          FROM attendance a 
          JOIN users u ON a.userId = u.id 
          ORDER BY a.checkInTime DESC`, (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.get('/api/admin/absent', (req, res) => {
  const today = new Date().toISOString().split('T')[0];
  db.all(`SELECT id, fullName, mobileNumber, profilePicture 
          FROM users 
          WHERE role = "User" AND id NOT IN (
            SELECT userId FROM attendance WHERE checkInTime LIKE ?
          )`, [`${today}%`], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

// --- Leaves ---

app.post('/api/leaves/apply', (req, res) => {
  const { userId, startDate, endDate, reason } = req.body;
  db.run(`INSERT INTO leaves (userId, startDate, endDate, reason) VALUES (?, ?, ?, ?)`,
    [userId, startDate, endDate, reason],
    function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'Leave application submitted', id: this.lastID });
    });
});

app.get('/api/leaves/:userId', (req, res) => {
  db.all('SELECT * FROM leaves WHERE userId = ? ORDER BY createdAt DESC', [req.params.userId], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.get('/api/leaves/balance/:userId', (req, res) => {
  // Simple mock balance logic: 10 days per year total
  db.all('SELECT * FROM leaves WHERE userId = ? AND status = "Approved"', [req.params.userId], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    const used = rows.length * 1; // Assuming each leave is 1 day for simplicity in mock
    res.json({ total: 10, used: used, remaining: 10 - used });
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
      res.json({ message: 'Leave status updated' });
    });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
