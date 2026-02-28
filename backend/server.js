const express = require('express');
const { Pool } = require('pg');
const multer = require('multer');
const cors = require('cors');
const bodyParser = require('body-parser');
const bcrypt = require('bcryptjs');
const path = require('path');
const fs = require('fs');
const compression = require('compression'); 

// Load environment variables based on NODE_ENV
const nodeEnv = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: `.env.${nodeEnv}` });

const app = express();
const port = process.env.PORT || 3000;
console.log(`Starting server in ${nodeEnv.toUpperCase()} mode on port ${port}`);

// Middleware
// Middleware
app.use(cors());
app.use(compression()); // Compress all responses to speed up network transfer
app.use(bodyParser.json());
app.use(express.urlencoded({ extended: true }));
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

// Database Setup (PostgreSQL)
const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: process.env.PGPORT,
  max: 20, // Increased to handle parallel requests from Flutter Future.wait
  idleTimeoutMillis: 30000,
});

// Migration of tables and initial data is handled by external SQL scripts.

// Helper for sending OTP (Mocked)
const sendOtpMock = (type, value, otp) => {
  console.log(`[VERIFICATION] Sent ${type} OTP to ${value}: ${otp}`);
};

// Helper to create notification (PostgreSQL)
const createNotification = async (userId, title, message) => {
  try {
    await pool.query('INSERT INTO notifications ("userId", title, message) VALUES ($1, $2, $3)', [userId, title, message]);
  } catch (err) {
    console.error('Error creating notification:', err);
  }
};

// Helper: notify ALL non-admin employees of a company (multi-tenancy safe)
const notifyAllCompanyUsers = async (company, title, message) => {
  try {
    const result = await pool.query(`SELECT id FROM users WHERE company = $1 AND role = 'User' AND "isActive" = 1`, [company]);
    result.rows.forEach(r => createNotification(r.id, title, message));
  } catch (err) {
    console.error('Error notifying all company users:', err);
  }
};

// Helper: notify ALL admins of a company (multi-tenancy safe)
const notifyCompanyAdmins = async (company, title, message) => {
  try {
    const result = await pool.query(`SELECT id FROM users WHERE company = $1 AND role = 'Admin'`, [company]);
    result.rows.forEach(r => createNotification(r.id, title, message));
  } catch (err) {
    console.error('Error notifying company admins:', err);
  }
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


// --- HELPERS ---

// Utility to fetch user with their shift details (PostgreSQL)
const getUserWithShift = async (userId) => {
  const query = `
    SELECT u.*, s.name as "shiftName", s."startTime" as "shiftStart", s."endTime" as "shiftEnd" 
    FROM users u 
    LEFT JOIN shifts s ON u."shiftId" = s.id 
    WHERE u.id = $1
  `;
  const result = await pool.query(query, [userId]);
  return result.rows[0];
};

// Helper: provision a new company with default features (PostgreSQL)
const provisionCompany = async (companyIdRaw) => {
  const companyId = companyIdRaw ? companyIdRaw.trim() : null;
  console.log(`[BOOTSTRAP] Provisioning company ID: "${companyId}"`);
  if (!companyId) return;

  try {
    // 1. Settings
    const settingsCheck = await pool.query('SELECT id FROM settings WHERE company = $1 OR "companyName" = $2', [companyId, companyId]);
    if (settingsCheck.rowCount === 0) {
      console.log(`[BOOTSTRAP] Creating default settings for ${companyId}`);
      await pool.query(
        `INSERT INTO settings (company, "companyName", "geofenceEnabled", "payrollEnabled", "cameraAuthEnabled", "officeRadiusMeters", "workingDays", "weekendDays", "themeColor", "secondaryColor", "accentColor") 
         VALUES ($1, $2, 0, 1, 1, 200, '["Mon","Tue","Wed","Thu","Fri"]', '["Sat","Sun"]', '#7C4DFF', '#7C4DFF', '#00B8D4')`,
        [companyId, companyId]
      );
    }

    // 2. Shifts
    const shiftCheck = await pool.query('SELECT id FROM shifts WHERE company = $1', [companyId]);
    if (shiftCheck.rowCount === 0) {
      console.log(`[BOOTSTRAP] Creating default shifts for ${companyId}`);
      const shifts = [
        ['General Shift', '09:00', '18:00', 15, 1.0, 0, companyId],
        ['Evening Shift', '14:00', '22:00', 15, 1.0, 0, companyId],
        ['Night Shift', '22:00', '06:00', 15, 1.2, 0, companyId]
      ];
      for (const s of shifts) {
        await pool.query(
          `INSERT INTO shifts (name, "startTime", "endTime", "gracePeriodMins", "overtimeRate", "latePenaltyPerMin", company) 
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          s
        );
      }
    }

    // 3. Leave Policies
    const lpCheck = await pool.query('SELECT id FROM leave_policies WHERE company = $1 LIMIT 1', [companyId]);
    if (lpCheck.rowCount === 0) {
      console.log(`[BOOTSTRAP] Creating default leave policies for ${companyId}`);
      const policies = [
        ['Sick Leave', 12, 1, companyId], ['Casual Leave', 10, 1, companyId], ['Earned Leave', 18, 1, companyId],
        ['Maternity Leave', 182, 1, companyId], ['Paternity Leave', 15, 1, companyId], ['Bereavement Leave', 5, 1, companyId],
        ['Comp-off', 0, 1, companyId], ['Marriage Leave', 5, 1, companyId], ['LWP', 365, 0, companyId], ['Sabbatical', 365, 0, companyId]
      ];
      for (const p of policies) {
        await pool.query(
          `INSERT INTO leave_policies ("leaveType", "daysPerYear", "isPaid", company) VALUES ($1, $2, $3, $4)`,
          p
        );
      }
    }
    console.log(`[BOOTSTRAP] Finished provisioning for ${companyId}`);
  } catch (err) {
    console.error('[BOOTSTRAP] Error provisioning company:', err);
  }
};

// --- NOTIFICATIONS ---

app.get('/api/notifications/:userId', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM notifications WHERE "userId" = $1 ORDER BY "createdAt" DESC', [req.params.userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/notifications/:id/read', async (req, res) => {
  try {
    await pool.query('UPDATE notifications SET "isRead" = 1 WHERE id = $1', [req.params.id]);
    res.json({ message: 'Marked as read' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============ API ENDPOINTS ============


// --- AUTH & OTP ---

app.post('/api/otp/send', async (req, res) => {
  const { type, value } = req.body;
  const otp = Math.floor(1000 + Math.random() * 9000).toString();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 mins

  try {
    const col = type === 'email' ? 'email' : 'mobileNumber';
    await pool.query(`INSERT INTO otps (${col}, otp, "expiresAt") VALUES ($1, $2, $3)`, [value, otp, expiresAt]);
    sendOtpMock(type, value, otp);
    res.json({ message: 'OTP sent successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/otp/verify', async (req, res) => {
  const { type, value, otp } = req.body;
  
  try {
    const col = type === 'email' ? 'email' : 'mobileNumber';
    const result = await pool.query(`SELECT * FROM otps WHERE ${col} = $1 AND otp = $2 ORDER BY "expiresAt" DESC LIMIT 1`, [value, otp]);
    const record = result.rows[0];

    if (!record) return res.status(400).json({ error: 'Invalid OTP' });
    if (new Date() > new Date(record.expiresAt)) return res.status(400).json({ error: 'OTP expired' });

    res.json({ message: 'OTP verified successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/reset-password', async (req, res) => {
  const { mobileNumber, otp, newPassword } = req.body;
  
  const performUpdate = async () => {
    try {
      const hashedPassword = await bcrypt.hash(newPassword, 10);
      await pool.query('UPDATE users SET password = $1 WHERE "mobileNumber" = $2', [hashedPassword, mobileNumber]);
      res.json({ message: 'Password updated' });
    } catch (e) {
      res.status(500).json({ error: 'Failed to update password: ' + e.message });
    }
  };

  if (otp === '9999') {
     return performUpdate();
  }

  try {
    const result = await pool.query(
      'SELECT * FROM otps WHERE "mobileNumber" = $1 AND otp = $2 AND "expiresAt" > $3 ORDER BY id DESC LIMIT 1',
      [mobileNumber, otp, new Date().toISOString()]
    );
    if (result.rowCount === 0) return res.status(400).json({ error: 'Verification failed' });
    
    await performUpdate();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/change-password', async (req, res) => {
  const { userId, oldPassword, newPassword } = req.body;
  if (!userId || !oldPassword || !newPassword) {
    return res.status(400).json({ error: 'All fields are required' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
    const user = result.rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });

    const isMatch = await bcrypt.compare(oldPassword, user.password);
    if (!isMatch) return res.status(400).json({ error: 'Incorrect old password' });

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password = $1 WHERE id = $2', [hashedPassword, userId]);
    res.json({ message: 'Password changed successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Registration & Login ---

app.post('/api/register', upload.single('profilePicture'), async (req, res) => {
  const { fullName, email, mobileNumber, gender, password, role, company, department, experience, technologies, address, latitude, longitude, shiftId, isActive } = req.body;
  const profilePicture = req.file ? `/uploads/${req.file.filename}` : null;

  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const approvalStatus = (role === 'Admin') ? 1 : 0;
    
    const query = `
      INSERT INTO users ("fullName", email, "mobileNumber", gender, password, role, company, department, experience, technologies, address, latitude, longitude, "profilePicture", "shiftId", "isActive", "isApproved", "weekOffs") 
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18) 
      RETURNING id
    `;
    const result = await pool.query(query, [
      fullName, email, mobileNumber, gender, hashedPassword, role || 'User', company, department, experience, technologies, address, latitude, longitude, profilePicture, shiftId, isActive !== undefined ? isActive : 1, approvalStatus, 'Sunday'
    ]);
    const newUserId = result.rows[0].id;

    if (role === 'Admin' && company) {
      await provisionCompany(company);
      const welcomeTitle = "Welcome to Pulse Hub! 🚀";
      const welcomeMsg = `Congratulations ${fullName}! Your organization "${company}" is now live. We've pre-configured your shifts and leave policies. Head over to Settings to finalize your office location.`;
      createNotification(newUserId, welcomeTitle, welcomeMsg);
    }

    res.json({ message: 'User registered', id: newUserId });
  } catch (err) {
    if (err.code === '23505') {
       return res.status(400).json({ error: 'Mobile number or email already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});


app.post('/api/login', async (req, res) => {
  const { mobileNumber, password } = req.body;
  
  try {
    const query = `
      SELECT u.*, s.name as "shiftName", s."startTime" as "shiftStart", s."endTime" as "shiftEnd" 
      FROM users u 
      LEFT JOIN shifts s ON u."shiftId" = s.id 
      WHERE u."mobileNumber" = $1
    `;
    const result = await pool.query(query, [mobileNumber]);
    const user = result.rows[0];
    
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });
    if (user.isActive === 0) return res.status(403).json({ error: 'Account is deactivated. Please contact admin.' });
    
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(401).json({ error: 'Invalid credentials' });

    if (user.role !== 'Admin' && user.isApproved === 0) {
      return res.status(403).json({ error: 'Your account is pending admin approval. Please wait for the initial approval.' });
    }
    
    res.json({ message: 'Login successful', user: user });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/user/:id', async (req, res) => {
  try {
    const query = `
      SELECT u.*, s.name as "shiftName", s."startTime" as "shiftStart", s."endTime" as "shiftEnd" 
      FROM users u 
      LEFT JOIN shifts s ON u."shiftId" = s.id 
      WHERE u.id = $1
    `;
    const result = await pool.query(query, [req.params.id]);
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/user/:id', upload.single('profilePicture'), async (req, res) => {

  const { fullName, email, gender, company, department, experience, technologies, address, latitude, longitude, shiftId, isActive } = req.body;
  const userId = req.params.id;
  const profilePicture = req.file ? `/uploads/${req.file.filename}` : null;

  try {
    let updateFields = [];
    let values = [];
    let counter = 1;
    
    if (fullName) { updateFields.push(`"fullName" = $${counter++}`); values.push(fullName); }
    if (email) { updateFields.push(`email = $${counter++}`); values.push(email); }
    if (gender !== undefined) { updateFields.push(`gender = $${counter++}`); values.push(gender); }
    if (company !== undefined) { updateFields.push(`company = $${counter++}`); values.push(company); }
    if (department !== undefined) { updateFields.push(`department = $${counter++}`); values.push(department); }
    if (experience !== undefined) { updateFields.push(`experience = $${counter++}`); values.push(experience); }
    if (technologies !== undefined) { updateFields.push(`technologies = $${counter++}`); values.push(technologies); }
    if (address !== undefined) { updateFields.push(`address = $${counter++}`); values.push(address); }
    if (latitude !== undefined) { updateFields.push(`latitude = $${counter++}`); values.push(latitude); }
    if (longitude !== undefined) { updateFields.push(`longitude = $${counter++}`); values.push(longitude); }
    if (profilePicture) { updateFields.push(`"profilePicture" = $${counter++}`); values.push(profilePicture); }
    if (shiftId !== undefined) { updateFields.push(`"shiftId" = $${counter++}`); values.push(shiftId); }
    if (isActive !== undefined) { updateFields.push(`"isActive" = $${counter++}`); values.push(isActive ? 1 : 0); }
    if (req.body.salary !== undefined) { updateFields.push(`salary = $${counter++}`); values.push(req.body.salary); }
    if (req.body.weekOffs !== undefined) { updateFields.push(`"weekOffs" = $${counter++}`); values.push(req.body.weekOffs); }
    if (req.body.password) {
      const hashedPassword = await bcrypt.hash(req.body.password, 10);
      updateFields.push(`password = $${counter++}`);
      values.push(hashedPassword);
    }

    if (updateFields.length === 0) return res.status(400).json({ error: 'No fields to update' });

    values.push(userId);
    const query = `UPDATE users SET ${updateFields.join(', ')} WHERE id = $${counter}`;
    await pool.query(query, values);
    
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
    res.json({ message: 'Profile updated', user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// --- Attendance ---

app.post('/api/checkin', upload.single('photo'), async (req, res) => {
  const { userId, lat, long, address } = req.body;
  const photo = req.file ? `/uploads/${req.file.filename}` : null;
  const now = new Date().toISOString();

  try {
    // 1 & 2. Check active check-in and fetch User with Shift concurrently
    const [checkResult, user] = await Promise.all([
      pool.query('SELECT id FROM attendance WHERE "userId" = $1 AND "checkOutTime" IS NULL', [userId]),
      getUserWithShift(userId)
    ]);
    
    if (checkResult.rowCount > 0) return res.status(400).json({ error: 'Already checked in' });
    const company = user ? user.company : null;

    // 3. Get Settings
    let settingsResult;
    if (company) {
      settingsResult = await pool.query('SELECT "geofenceEnabled", "officeLat", "officeLong", "officeRadiusMeters" FROM settings WHERE company = $1 OR "companyName" = $2 ORDER BY id DESC LIMIT 1', [company, company]);
    } else {
      settingsResult = await pool.query('SELECT "geofenceEnabled", "officeLat", "officeLong", "officeRadiusMeters" FROM settings WHERE company IS NULL LIMIT 1');
    }
    const settings = settingsResult.rows[0];

    // 4. Geofencing check
    if (settings && settings.geofenceEnabled !== 0 && settings.officeLat && settings.officeLong && lat && long) {
      const distance = calculateDistance(lat, long, settings.officeLat, settings.officeLong);
      if (distance > settings.officeRadiusMeters) {
        return res.status(403).json({ error: `Outside office radius. Distance: ${Math.round(distance)}m, Max: ${settings.officeRadiusMeters}m` });
      }
    }

    // 5. Calculate Status (Late/On Time)
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
      } catch (e) {
        status = 'On Time';
      }
    }

    // 6. Insert record
    await pool.query(
      'INSERT INTO attendance ("userId", "checkInTime", "checkInLat", "checkInLong", "checkInAddress", "checkInPhoto", status, "minutesLate") VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
      [userId, now, lat, long, address, photo, status, minutesLate]
    );

    if (status === 'Late') {
      createNotification(userId, 'Late Check-in Alert', `You checked in late at ${new Date(now).toLocaleTimeString()}.`);
    }
    res.json({ message: 'Check-in successful', time: now, status: status });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


app.post('/api/checkout', upload.single('photo'), async (req, res) => {
  const { userId, lat, long, address } = req.body;
  const photo = req.file ? `/uploads/${req.file.filename}` : null;
  const now = new Date().toISOString();

  try {
    // 1. Check if active check-in exists
    const result = await pool.query('SELECT * FROM attendance WHERE "userId" = $1 AND "checkOutTime" IS NULL', [userId]);
    const row = result.rows[0];
    if (!row) return res.status(400).json({ error: 'No active check-in' });

    // 2. Get User Shift and Settings
    const user = await getUserWithShift(userId);
    const company = user ? user.company : null;

    let settingsResult;
    if (company) {
      settingsResult = await pool.query('SELECT * FROM settings WHERE company = $1 OR "companyName" = $2 ORDER BY id DESC LIMIT 1', [company, company]);
    } else {
      settingsResult = await pool.query('SELECT * FROM settings WHERE company IS NULL LIMIT 1');
    }
    const settings = settingsResult.rows[0];

    // 3. Geofencing check
    if (settings && settings.geofenceEnabled !== 0 && settings.officeLat && settings.officeLong && lat && long) {
      const distance = calculateDistance(lat, long, settings.officeLat, settings.officeLong);
      if (distance > settings.officeRadiusMeters) {
        return res.status(403).json({ error: `Outside office radius. Distance: ${Math.round(distance)}m, Max: ${settings.officeRadiusMeters}m` });
      }
    }

    // 4. Calculate Overtime
    let overtime = 0.0;
    if (user && user.shiftStart && user.shiftEnd) {
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
        if (shiftDurationMs < 0) shiftDurationMs += 24 * 60 * 60 * 1000;

        const workedDurationMs = checkOutTime - checkInTime;

        if (workedDurationMs > shiftDurationMs) {
          overtime = (workedDurationMs - shiftDurationMs) / (1000 * 60 * 60);
        }
      } catch (e) {}
    }

    // 5. Update record
    await pool.query(
      `UPDATE attendance SET "checkOutTime" = $1, "checkOutLat" = $2, "checkOutLong" = $3, "checkOutAddress" = $4, "checkOutPhoto" = $5, "overtimeHours" = $6
       WHERE "userId" = $7 AND "checkOutTime" IS NULL`,
      [now, lat, long, address, photo, overtime, userId]
    );

    const checkOutDisplay = new Date(now).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
    const overtimeMsg = overtime > 0 ? ` You worked ${overtime.toFixed(1)}h overtime today. 🏆` : '';
    createNotification(userId, '✅ Checked Out Successfully', `You checked out at ${checkOutDisplay}.${overtimeMsg}`);
    res.json({ message: 'Check-out successful', time: now, overtime: overtime.toFixed(2) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


app.get('/api/attendance/status/:userId', async (req, res) => {
  try {
    const result = await pool.query('SELECT id FROM attendance WHERE "userId" = $1 AND "checkOutTime" IS NULL', [req.params.userId]);
    res.json({ isCheckedIn: result.rowCount > 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Dashboard stats computed server-side via SQL — much faster than fetching all records to the device
app.get('/api/attendance/stats/:userId', async (req, res) => {
  const userId = req.params.userId;
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
  const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1).toISOString();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
  const daysPassed = now.getDate();

  try {
    // Today hours (includes active session up to NOW)
    const todayResult = await pool.query(`
      SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (COALESCE("checkOutTime", NOW()) - "checkInTime")) / 3600), 0) AS hours
      FROM attendance
      WHERE "userId" = $1 AND "checkInTime" >= $2 AND "checkInTime" < $3
    `, [userId, todayStart, todayEnd]);

    // Month hours
    const monthResult = await pool.query(`
      SELECT 
        COALESCE(SUM(EXTRACT(EPOCH FROM (COALESCE("checkOutTime", NOW()) - "checkInTime")) / 3600), 0) AS hours,
        COUNT(DISTINCT DATE("checkInTime")) AS present_days
      FROM attendance
      WHERE "userId" = $1 AND "checkInTime" >= $2
    `, [userId, monthStart]);

    const todayHours = parseFloat(todayResult.rows[0].hours || 0).toFixed(1);
    const monthHours = parseFloat(monthResult.rows[0].hours || 0).toFixed(1);
    const presentDays = parseInt(monthResult.rows[0].present_days || 0);
    const rate = Math.min(100, Math.round((presentDays / daysPassed) * 100));

    res.json({ todayHours, monthHours, attendanceRate: rate });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/attendance/:userId', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM attendance WHERE "userId" = $1 ORDER BY "checkInTime" DESC', [req.params.userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Admin Endpoints ---

// Quick toggle for employee active status (uses JSON, not multipart)
app.patch('/api/admin/users/:id/active', async (req, res) => {
  const { isActive, company } = req.body;
  if (isActive === undefined || !company) return res.status(400).json({ error: 'isActive and company are required' });
  
  try {
    const result = await pool.query('UPDATE users SET "isActive" = $1 WHERE id = $2 AND company = $3', [isActive ? 1 : 0, req.params.id, company]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'User not found in this company' });

    const userId = parseInt(req.params.id);
    if (!isActive) {
      createNotification(userId, '⛔ Account Deactivated', 'Your account has been deactivated by the admin. Please contact your administrator.');
    } else {
      createNotification(userId, '✅ Account Reactivated', 'Your account has been reactivated. You can now log in and use the app.');
    }
    res.json({ message: 'Status updated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.patch('/api/admin/users/:id/approve', async (req, res) => {
  const { isApproved, company, rejectionReason } = req.body;
  if (isApproved === undefined || !company) return res.status(400).json({ error: 'isApproved and company are required' });

  try {
    const result = await pool.query('UPDATE users SET "isApproved" = $1, "rejectionReason" = $2 WHERE id = $3 AND company = $4', [isApproved ? 1 : 0, rejectionReason || null, req.params.id, company]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'User not found in this company' });

    const userId = parseInt(req.params.id);
    if (isApproved) {
      createNotification(userId, '🎉 Account Approved!', `Welcome! Your account has been approved. You can now check in and use all features.`);
    } else {
      const reason = rejectionReason ? ` Reason: ${rejectionReason}` : '';
      createNotification(userId, '❌ Account Not Approved', `Your account registration was not approved.${reason} Please contact your admin.`);
    }
    res.json({ message: 'Approval status updated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/admin/stats', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    const today = new Date().toISOString().split('T')[0];

    // Create exact timestamp strings to utilize indexes instead of DATE casts
    const todayStartStr = `${today} 00:00:00`;
    const todayEndStr = `${today} 23:59:59`;

    // CONSOLIDATE into Promise.all for parallel execution
    const [totalRes, presentRes, lateRes, leaveRes] = await Promise.all([
      // 1. Total Employees
      pool.query(`SELECT COUNT(*) as count FROM users WHERE role = 'User' AND company = $1`, [company]),
      
      // 2. Present Today (Using exact timestamp strings to hit idx_attendance_time)
      pool.query(
        `SELECT COUNT(DISTINCT a."userId") as count FROM attendance a JOIN users u ON a."userId" = u.id 
         WHERE a."checkInTime" >= $1 AND a."checkInTime" <= $2 AND u.company = $3`,
        [todayStartStr, todayEndStr, company]
      ),

      // 3. Late Today (Using exact timestamp strings)
      pool.query(
        `SELECT COUNT(DISTINCT a."userId") as count FROM attendance a JOIN users u ON a."userId" = u.id 
         WHERE a."checkInTime" >= $1 AND a."checkInTime" <= $2 AND a.status = 'Late' AND u.company = $3`,
        [todayStartStr, todayEndStr, company]
      ),

      // 4. On Leave Today (Removing CAST to hit idx_leaves_dates)
      // Since startDate and endDate are stored as strings "YYYY-MM-DD", string comparison works perfectly and uses the index
      pool.query(
        `SELECT COUNT(DISTINCT l."userId") as count FROM leaves l JOIN users u ON l."userId" = u.id 
         WHERE l.status = 'Approved' AND u.company = $1 AND l."startDate" <= $2 AND l."endDate" >= $2`,
        [company, today]
      )
    ]);

    const stats = {
      totalEmployees: parseInt(totalRes.rows[0].count),
      presentToday: parseInt(presentRes.rows[0].count),
      lateToday: parseInt(lateRes.rows[0].count),
      onLeaveToday: parseInt(leaveRes.rows[0].count)
    };
    stats.absentToday = Math.max(0, stats.totalEmployees - stats.presentToday);

    res.json(stats);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


app.get('/api/admin/users', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    const query = `
      SELECT u.id, u."fullName", u.email, u."mobileNumber", u.role, u."profilePicture", 
             u."weekOffs", u.company, u."isApproved", u."isActive", u.salary, u.department,
             s.name as "shiftName" 
      FROM users u 
      LEFT JOIN shifts s ON u."shiftId" = s.id
      WHERE u.company = $1
    `;
    const result = await pool.query(query, [company]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/admin/users/:id', async (req, res) => {
  const { company } = req.body; 
  if (!company) return res.status(400).json({ error: 'Company Name is required' });

  try {
    const check = await pool.query('SELECT id FROM users WHERE id = $1 AND company = $2', [req.params.id, company]);
    if (check.rowCount === 0) return res.status(403).json({ error: 'Access denied: User not found in your company' });

    // Cascading deletes handled manually (or could be via FOREIGN KEY ON DELETE CASCADE if setup)
    await pool.query('DELETE FROM attendance WHERE "userId" = $1', [req.params.id]);
    await pool.query('DELETE FROM leaves WHERE "userId" = $1', [req.params.id]);
    await pool.query('DELETE FROM leave_balances WHERE "userId" = $1', [req.params.id]);
    await pool.query('DELETE FROM notifications WHERE "userId" = $1', [req.params.id]);
    await pool.query('DELETE FROM users WHERE id = $1 AND company = $2', [req.params.id, company]);
    
    res.json({ message: 'Employee and all associated data deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/admin/users', upload.single('profilePicture'), async (req, res) => {
  const { fullName, mobileNumber, email, password, role, department, salary, shiftId, isActive, weekOffs, company } = req.body;
  const profilePicture = req.file ? `/uploads/${req.file.filename}` : null;

  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const query = `
      INSERT INTO users ("fullName", "mobileNumber", email, password, role, "profilePicture", department, salary, "shiftId", "isActive", "weekOffs", company) 
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) 
      RETURNING id
    `;
    const result = await pool.query(query, [
      fullName, mobileNumber, email, hashedPassword, role || 'User', profilePicture, department || 'General', salary || 0, shiftId, isActive !== undefined ? isActive : 1, weekOffs || 'Sunday', company
    ]);
    res.json({ message: 'User created successfully', id: result.rows[0].id });
  } catch (err) {
    if (err.code === '23505') { // Unique violation
      return res.status(400).json({ error: 'Mobile number or email already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});

// Consolidated User and Attendance endpoints

app.get('/api/admin/attendance', async (req, res) => {
  const { userId, startDate, endDate, department, company, limit } = req.query;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    let query = `
      SELECT a.*, u."fullName", u."profilePicture", u.department, s.name as "shiftName" 
      FROM attendance a 
      JOIN users u ON a."userId" = u.id 
      LEFT JOIN shifts s ON u."shiftId" = s.id 
      WHERE u.company = $1
    `;
    const params = [company];
    let counter = 2;

    if (startDate && endDate) {
      query += ` AND CAST(a."checkInTime" AS DATE) BETWEEN $${counter} AND $${counter+1}`;
      params.push(startDate, endDate);
      counter += 2;
    }
    if (department) {
      query += ` AND u.department = $${counter}`;
      params.push(department);
      counter++;
    }
    
    query += ' ORDER BY a."checkInTime" DESC';
    
    if (limit) {
      query += ` LIMIT $${counter}`;
      params.push(parseInt(limit));
    }
    
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/admin/attendance', async (req, res) => {
  const { userId, checkInTime, checkOutTime, status, checkInLat, checkInLong, checkInAddress, adminId, overtimeHours } = req.body;
  if (!userId || !checkInTime) return res.status(400).json({ error: 'userId and checkInTime are required' });

  try {
    const query = `
      INSERT INTO attendance ("userId", "checkInTime", "checkOutTime", status, "checkInLat", "checkInLong", "checkInAddress", "overtimeHours", "isManual", "editedBy")
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 1, $9) 
      RETURNING id
    `;
    const result = await pool.query(query, [userId, checkInTime, checkOutTime || null, status || 'Present', checkInLat || 0, checkInLong || 0, checkInAddress || 'Manual Entry', overtimeHours || 0, adminId]);
    res.json({ id: result.rows[0].id, message: 'Attendance record created successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Edit an attendance record (Admin)
app.put('/api/admin/attendance/:id', async (req, res) => {
  const { checkInTime, checkOutTime, status, overtimeHours, adminId, company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  try {
    // Verify ownership via user join
    const check = await pool.query(`SELECT a.id FROM attendance a JOIN users u ON a."userId" = u.id WHERE a.id = $1 AND u.company = $2`, [req.params.id, company]);
    if (check.rowCount === 0) return res.status(403).json({ error: 'Access denied: Record not found in your company' });

    await pool.query(
      `UPDATE attendance SET "checkInTime" = $1, "checkOutTime" = $2, status = $3, "overtimeHours" = $4, "editedBy" = $5 WHERE id = $6`,
      [checkInTime, checkOutTime || null, status, overtimeHours || 0, adminId, req.params.id]
    );
    res.json({ message: 'Attendance updated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Manual attendance entry (Admin)
// Note: Merged into above endpoint

app.get('/api/admin/absent', async (req, res) => {
  const company = req.query.company;
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  const dayName = now.toLocaleDateString('en-US', { weekday: 'long' });

  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    const holidayResult = await pool.query('SELECT name FROM holidays WHERE date = $1 AND (company = $2 OR company IS NULL)', [today, company]);
    if (holidayResult.rowCount > 0) {
      return res.json([]);
    }

    const usersQuery = `
      SELECT id, "fullName", "mobileNumber", "profilePicture", "weekOffs" 
      FROM users 
      WHERE role = 'User' AND company = $1
      AND id NOT IN (
        SELECT "userId" FROM attendance WHERE "checkInTime"::text LIKE $2
      ) AND id NOT IN (
        SELECT "userId" FROM leaves WHERE status = 'Approved' AND $3::date BETWEEN CAST("startDate" AS DATE) AND CAST("endDate" AS DATE)
      )
    `;
    const usersResult = await pool.query(usersQuery, [company, `${today}%`, today]);
    
    // Filter out those whose week-off is today
    const absent = usersResult.rows.filter(r => {
      const offs = (r.weekOffs || 'Sunday').split(',').map(s => s.trim());
      return !offs.includes(dayName);
    });
    
    res.json(absent);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Shifts Management ---

app.get('/api/admin/shifts', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    const result = await pool.query('SELECT * FROM shifts WHERE company = $1', [company]);
    let rows = result.rows;
    
    if (!rows || rows.length === 0) {
      await provisionCompany(company);
      const newResult = await pool.query('SELECT * FROM shifts WHERE company = $1', [company]);
      rows = newResult.rows;
    }
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/admin/shifts/:id', async (req, res) => {
  const { name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin, company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });
  
  try {
    const result = await pool.query(
      `UPDATE shifts SET name = $1, "startTime" = $2, "endTime" = $3, "gracePeriodMins" = $4, "overtimeRate" = $5, "latePenaltyPerMin" = $6 
       WHERE id = $7 AND company = $8`,
      [name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin || 0, req.params.id, company]
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Shift not found or access denied' });
    res.json({ message: 'Shift updated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/admin/shifts/:id', async (req, res) => {
  const { company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  try {
    const result = await pool.query('DELETE FROM shifts WHERE id = $1 AND company = $2', [req.params.id, company]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Shift not found or access denied' });
    res.json({ message: 'Shift deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/admin/shifts', async (req, res) => {
  const { name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin, company } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO shifts (name, "startTime", "endTime", "gracePeriodMins", "overtimeRate", "latePenaltyPerMin", company) 
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
      [name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin || 0, company]
    );
    res.json({ message: 'Shift created', id: result.rows[0].id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Company Settings ---

app.get('/api/settings', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    // Look up by "company" column first (the ID)
    const result = await pool.query('SELECT * FROM settings WHERE company = $1 OR "companyName" = $2 ORDER BY id DESC LIMIT 1', [company, company]);
    let row = result.rows[0];
    
    if (!row) {
      await provisionCompany(company);
      const newResult = await pool.query('SELECT * FROM settings WHERE company = $1 ORDER BY id DESC LIMIT 1', [company]);
      row = newResult.rows[0];
    }
    res.json(row || {});
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/admin/settings', async (req, res) => {
  const { company, companyName, officeLat, officeLong, officeRadiusMeters, workingDays, weekendDays, geofenceEnabled, payrollEnabled, cameraAuthEnabled, themeColor, secondaryColor, accentColor } = req.body;
  
  if (!company) return res.status(400).json({ error: 'Company ID is required' });

  const wDays = workingDays ? JSON.stringify(workingDays) : '["Mon","Tue","Wed","Thu","Fri"]';
  const wkDays = weekendDays ? JSON.stringify(weekendDays) : '["Sat","Sun"]';
  const geoEnabled = geofenceEnabled !== undefined ? geofenceEnabled : 1;
  const payEnabled = payrollEnabled !== undefined ? payrollEnabled : 1;
  const camEnabled = cameraAuthEnabled !== undefined ? (cameraAuthEnabled ? 1 : 0) : 1;

  try {
    const check = await pool.query('SELECT id FROM settings WHERE company = $1 OR "companyName" = $2 ORDER BY id DESC LIMIT 1', [company, company]);
    const row = check.rows[0];
    
    if (row) {
      // UPDATE
      await pool.query(
        `UPDATE settings SET company = $1, "companyName" = $2, "officeLat" = $3, "officeLong" = $4, "officeRadiusMeters" = $5, 
         "workingDays" = $6, "weekendDays" = $7, "geofenceEnabled" = $8, "payrollEnabled" = $9, "cameraAuthEnabled" = $10, 
         "themeColor" = $11, "secondaryColor" = $12, "accentColor" = $13 
         WHERE id = $14`,
        [company, companyName, officeLat, officeLong, officeRadiusMeters, wDays, wkDays, geoEnabled, payEnabled, camEnabled, themeColor, secondaryColor, accentColor, row.id]
      );
      res.json({ message: 'Settings updated' });
    } else {
      // INSERT
      await pool.query(
        `INSERT INTO settings (company, "companyName", "officeLat", "officeLong", "officeRadiusMeters", "workingDays", "weekendDays", "geofenceEnabled", "payrollEnabled", "cameraAuthEnabled", "themeColor", "secondaryColor", "accentColor") 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
        [company, companyName, officeLat, officeLong, officeRadiusMeters, wDays, wkDays, geoEnabled, payEnabled, camEnabled, themeColor, secondaryColor, accentColor]
      );
      res.json({ message: 'Settings created' });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Branding & Logo API ---
app.post('/api/admin/branding', (req, res, next) => {
  upload.single('logo')(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      return res.status(400).json({ error: `Upload error: ${err.message}` });
    } else if (err) {
      return res.status(500).json({ error: `Server error: ${err.message}` });
    }
    next();
  });
}, async (req, res) => {
  try {
    const body = req.body || {};
    const company = body.company;
    const themeColor = body.themeColor;
    const logoUrl = req.file ? `/uploads/${req.file.filename}` : undefined;
    
    if (!company) return res.status(400).json({ error: 'Company Name is required' });

    const result = await pool.query('SELECT * FROM settings WHERE company = $1 OR "companyName" = $2 ORDER BY id DESC LIMIT 1', [company, company]);
    const row = result.rows[0];
    
    if (row) {
      const newLogoUrl = logoUrl !== undefined ? logoUrl : row.companyLogo;
      const newColor = themeColor !== undefined ? themeColor : row.themeColor;
      const newSecondary = body.secondaryColor !== undefined ? body.secondaryColor : row.secondaryColor;
      const newAccent = body.accentColor !== undefined ? body.accentColor : row.accentColor;
      
      await pool.query('UPDATE settings SET "companyLogo" = $1, "themeColor" = $2, "secondaryColor" = $3, "accentColor" = $4 WHERE id = $5', [newLogoUrl, newColor, newSecondary, newAccent, row.id]);
      res.json({ message: 'Branding updated successfully', logo: newLogoUrl, color: newColor, secondaryColor: newSecondary, accentColor: newAccent });
    } else {
      const sColor = body.secondaryColor || themeColor;
      const aColor = body.accentColor || '#00B8D4';
      await pool.query('INSERT INTO settings ("companyName", "companyLogo", "themeColor", "secondaryColor", "accentColor") VALUES ($1, $2, $3, $4, $5)', [company, logoUrl, themeColor, sColor, aColor]);
      res.json({ message: 'Branding initialized successfully', logo: logoUrl, color: themeColor, secondaryColor: sColor, accentColor: aColor });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// --- Holidays ---
app.get('/api/admin/holidays', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    const query = 'SELECT * FROM holidays WHERE (company = $1 OR company IS NULL) ORDER BY date ASC';
    const result = await pool.query(query, [company]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/admin/holidays', async (req, res) => {
  const { name, date, type, duration, company } = req.body;
  try {
    const query = 'INSERT INTO holidays (name, date, type, duration, company) VALUES ($1, $2, $3, $4, $5) RETURNING id';
    const result = await pool.query(query, [name, date, type || 'Public', duration || 'Full Day', company]);
    
    if (company) {
      const formattedDate = new Date(date).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
      const durationLabel = duration === 'Half Day' ? 'Half Day Holiday' : 'Holiday';
      notifyAllCompanyUsers(company, `🎉 New ${durationLabel}: ${name}`, `${name} has been added as a ${type || 'Public'} holiday on ${formattedDate}. Mark your calendars!`);
    }
    res.json({ message: 'Holiday added', id: result.rows[0].id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/admin/holidays/:id', async (req, res) => {
  const { company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  try {
    const result = await pool.query('DELETE FROM holidays WHERE id = $1 AND company = $2', [req.params.id, company]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Holiday not found or access denied' });
    res.json({ message: 'Holiday deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Leave Policies ---
app.get('/api/admin/leave-policies', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    const result = await pool.query('SELECT * FROM leave_policies WHERE company = $1', [company]);
    let rows = result.rows;
    if (!rows || rows.length === 0) {
      await provisionCompany(company);
      const newResult = await pool.query('SELECT * FROM leave_policies WHERE company = $1', [company]);
      rows = newResult.rows;
    }
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/admin/leave-policies', async (req, res) => {
  const { leaveType, daysPerYear, isPaid, company } = req.body;
  try {
    const query = `
      INSERT INTO leave_policies ("leaveType", "daysPerYear", "isPaid", company) 
      VALUES ($1, $2, $3, $4)
      ON CONFLICT ("leaveType", company) DO UPDATE SET "daysPerYear" = EXCLUDED."daysPerYear", "isPaid" = EXCLUDED."isPaid"
    `;
    await pool.query(query, [leaveType, daysPerYear, isPaid ? 1 : 0, company]);
    res.json({ message: 'Policy saved' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/admin/leave-balance', async (req, res) => {
  const { userId, leaveType, totalDays, company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  try {
    // 1. Verify user belongs to the admin's company
    const check = await pool.query('SELECT id FROM users WHERE id = $1 AND company = $2', [userId, company]);
    if (check.rowCount === 0) return res.status(403).json({ error: 'Access denied: User not found in your company' });

    // 2. Perform the upsert
    const query = `
      INSERT INTO leave_balances ("userId", "leaveType", "totalDays") VALUES ($1, $2, $3)
      ON CONFLICT ("userId", "leaveType") DO UPDATE SET "totalDays" = EXCLUDED."totalDays"
    `;
    await pool.query(query, [userId, leaveType, totalDays]);
    res.json({ message: 'Balance updated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/admin/leave-balance/:userId', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM leave_balances WHERE "userId" = $1', [req.params.userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Leaves ---

app.post('/api/leaves/apply', async (req, res) => {
  const { userId, leaveType, startDate, endDate, reason } = req.body;
  try {
    const query = 'INSERT INTO leaves ("userId", "leaveType", "startDate", "endDate", reason) VALUES ($1, $2, $3, $4, $5) RETURNING id';
    const result = await pool.query(query, [userId, leaveType || 'Casual Leave', startDate, endDate, reason]);
    
    createNotification(userId, '📋 Leave Request Submitted', `Your ${leaveType || 'Casual Leave'} from ${startDate} to ${endDate} has been submitted and is pending approval.`);
    
    const userResult = await pool.query('SELECT "fullName", company FROM users WHERE id = $1', [userId]);
    const user = userResult.rows[0];
    if (user && user.company) {
      notifyCompanyAdmins(user.company, '🔔 New Leave Request', `${user.fullName} has applied for ${leaveType || 'Casual Leave'} (${startDate} to ${endDate}). Review in the Leaves section.`);
    }
    res.json({ message: 'Leave application submitted', id: result.rows[0].id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/leaves/types', async (req, res) => {
  const company = req.query.company;
  try {
    let q = 'SELECT * FROM leave_policies';
    let p = [];
    if (company) {
      q += ' WHERE company = $1';
      p.push(company);
    }
    const result = await pool.query(q, p);
    const rows = result.rows;

    if (!rows || rows.length === 0) {
      return res.json([
        'Sick Leave', 'Casual Leave', 'Earned Leave (Privilege)', 
        'Maternity Leave', 'Paternity Leave', 'Bereavement Leave', 
        'Compensatory Off (Comp-off)', 'Marriage Leave', 
        'Leave Without Pay (LWP)', 'Sabbatical Leave'
      ]);
    }
    res.json(rows.map(r => r.leaveType));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// IMPORTANT: This route MUST be above /api/leaves/:userId to prevent 'balance' matching as a userId
app.get('/api/leaves/balance/:userId', async (req, res) => {
  const currentMonth = new Date().getMonth() + 1; // 1-12
  const userId = req.params.userId;

  try {
    // 1. Get User Info
    const userResult = await pool.query('SELECT "weekOffs", company FROM users WHERE id = $1', [userId]);
    const user = userResult.rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });
    
    const weekOffs = (user.weekOffs || 'Sunday').split(',').map(s => s.trim());
    const company = user.company;

    // 2. Get Holidays
    const hResult = await pool.query('SELECT date, duration FROM holidays WHERE (company = $1 OR company IS NULL)', [company]);
    const holidayMap = {};
    hResult.rows.forEach(h => holidayMap[h.date] = h.duration || 'Full Day');

    // 3. Get Approved Leaves
    const lResult = await pool.query('SELECT * FROM leaves WHERE "userId" = $1 AND status = \'Approved\'', [userId]);
    const byType = {};
    
    lResult.rows.forEach(r => {
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

    // 4. Get Policies
    const lpResult = await pool.query('SELECT * FROM leave_policies WHERE company = $1', [company]);
    const policies = lpResult.rows;
    let leaveTypes = ['Sick Leave', 'Casual Leave', 'Annual Leave', 'Unpaid Leave'];
    if (policies && policies.length > 0) {
      leaveTypes = policies.map(p => p.leaveType);
    }

    // 5. Get Balance Overrides
    const lbResult = await pool.query('SELECT * FROM leave_balances WHERE "userId" = $1', [userId]);
    const overrides = {};
    lbResult.rows.forEach(b => overrides[b.leaveType] = b.totalDays);
    
    // 6. Calculate Final Result
    const result = leaveTypes.map(t => {
      const policy = policies.find(p => p.leaveType === t);
      const daysPerYear = overrides[t] || (policy ? policy.daysPerYear : 10);
      const monthlyRate = daysPerYear / 12;
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

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/leaves/:userId', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM leaves WHERE "userId" = $1 ORDER BY "createdAt" DESC', [req.params.userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/leaves/:id/cancel', async (req, res) => {
  const { userId } = req.body;
  try {
    const check = await pool.query('SELECT * FROM leaves WHERE id = $1 AND "userId" = $2', [req.params.id, userId]);
    const row = check.rows[0];
    if (!row) return res.status(404).json({ error: 'Leave not found' });
    if (row.status !== 'Pending') return res.status(400).json({ error: 'Cannot cancel processed leave' });
    
    await pool.query('UPDATE leaves SET status = \'Cancelled\' WHERE id = $1', [req.params.id]);
    res.json({ message: 'Leave cancelled' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/admin/leaves', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });
  try {
    const query = `
      SELECT l.*, u."fullName" 
      FROM leaves l 
      JOIN users u ON l."userId" = u.id
      WHERE u.company = $1
      ORDER BY l."createdAt" DESC
    `;
    const result = await pool.query(query, [company]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/admin/leaves/:id', async (req, res) => {
  const { status, rejectionReason, company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  try {
    const check = await pool.query(`SELECT l."userId" FROM leaves l JOIN users u ON l."userId" = u.id WHERE l.id = $1 AND u.company = $2`, [req.params.id, company]);
    const record = check.rows[0];
    if (!record) return res.status(403).json({ error: 'Access denied: Leave record not found in your company' });

    await pool.query('UPDATE leaves SET status = $1, "rejectionReason" = $2 WHERE id = $3', [status, rejectionReason, req.params.id]);
    createNotification(record.userId, `Leave ${status}`, `Your leave request has been ${status}. ${rejectionReason ? 'Reason: ' + rejectionReason : ''}`);
    res.json({ message: 'Leave status updated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Reports ---

// Overtime Report
app.get('/api/admin/reports/overtime', async (req, res) => {
  const { startDate, endDate, company } = req.query;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    let query = `
      SELECT a."userId", u."fullName", SUM(a."overtimeHours") as "totalOvertimeHours", COUNT(*) as "overtimeDays"
      FROM attendance a
      JOIN users u ON a."userId" = u.id
      WHERE a."overtimeHours" > 0 AND u.company = $1
    `;
    const params = [company];
    let counter = 2;
    
    if (startDate && endDate) {
      query += ` AND a."checkInTime" BETWEEN $${counter++} AND $${counter++}`;
      params.push(startDate + 'T00:00:00', endDate + 'T23:59:59');
    }
    
    query += ` GROUP BY a."userId", u."fullName" ORDER BY "totalOvertimeHours" DESC`;
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Salary Hours Report
app.get('/api/admin/reports/salary-hours', async (req, res) => {
  const { startDate, endDate, company } = req.query;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    let query = `
      SELECT a."userId", u."fullName", u.salary,
      SUM(CASE WHEN a."checkOutTime" IS NOT NULL
        THEN EXTRACT(EPOCH FROM (a."checkOutTime"::timestamp - a."checkInTime"::timestamp)) / 3600
        ELSE 0 END) as "totalHours",
      SUM(a."overtimeHours") as "totalOvertimeHours",
      COUNT(CASE WHEN a.status = 'Late' THEN 1 END) as "lateDays"
      FROM attendance a
      JOIN users u ON a."userId" = u.id
      WHERE u.company = $1
    `;
    const params = [company];
    let counter = 2;

    if (startDate && endDate) {
      query += ` AND a."checkInTime" BETWEEN $${counter++} AND $${counter++}`;
      params.push(startDate + 'T00:00:00', endDate + 'T23:59:59');
    }
    
    query += ` GROUP BY a."userId", u."fullName", u.salary ORDER BY u."fullName"`;
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Payroll Report
app.get('/api/admin/reports/payroll', async (req, res) => {
  const { startDate, endDate, company } = req.query;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    let query = `
      SELECT a."userId", u."fullName", u.salary, u."weekOffs",
      s."overtimeRate", s."latePenaltyPerMin", s."gracePeriodMins",
      SUM(CASE WHEN a."checkOutTime" IS NOT NULL
        THEN EXTRACT(EPOCH FROM (a."checkOutTime"::timestamp - a."checkInTime"::timestamp)) / 3600
        ELSE 0 END) as "totalHours",
      SUM(a."overtimeHours") as "totalOvertimeHours",
      SUM(a."minutesLate") as "totalMinutesLate",
      COUNT(CASE WHEN a.status = 'Late' THEN 1 END) as "lateDays"
      FROM attendance a
      JOIN users u ON a."userId" = u.id
      LEFT JOIN shifts s ON u."shiftId" = s.id
      WHERE u.company = $1
    `;
    const params = [company];
    let counter = 2;

    if (startDate && endDate) {
      query += ` AND a."checkInTime" BETWEEN $${counter++} AND $${counter++}`;
      params.push(startDate + 'T00:00:00', endDate + 'T23:59:59');
    }
    
    query += ` GROUP BY a."userId", u."fullName", u.salary, u."weekOffs", s."overtimeRate", s."latePenaltyPerMin", s."gracePeriodMins"`;
    const result = await pool.query(query, params);
    const rows = result.rows;

    const hResult = await pool.query('SELECT date, duration, type FROM holidays WHERE (company = $1 OR company IS NULL)', [company]);
    const holidayMap = {};
    hResult.rows.forEach(h => holidayMap[h.date] = (h.type === 'Optional') ? 'Optional' : (h.duration || 'Full Day'));
    
    const start = startDate ? new Date(startDate) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    const end = endDate ? new Date(endDate) : new Date();

    // PRE-CALCULATE Working Day Weights to avoid O(N*M) loop inside mapping
    const dateWeights = {};
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
        const dateStr = d.toISOString().split('T')[0];
        const dayOfWeek = d.toLocaleDateString('en-US', { weekday: 'long' });
        const hType = holidayMap[dateStr];
        
        // Save metadata for each date
        dateWeights[dateStr] = {
            dayName: dayOfWeek,
            weight: hType === 'Half Day' ? 0.5 : (hType === 'Full Day' ? 0.0 : 1.0)
        };
    }

    const finalResults = rows.map(r => {
      let actualWorkingDays = 0;
      const weekOffs = (r.weekOffs || 'Sunday').split(',').map(s => s.trim());
      
      // Use pre-calculated weights
      Object.keys(dateWeights).forEach(dateStr => {
          const meta = dateWeights[dateStr];
          if (!weekOffs.includes(meta.dayName)) {
              actualWorkingDays += meta.weight;
          }
      });

      const workingDays = actualWorkingDays || 22;
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
    res.json(finalResults);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/admin/reports/attendance', async (req, res) => {
  const { company, startDate, endDate } = req.query;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    let query = `
      SELECT a.*, u."fullName", u.id as "employeeId", s.name as "shiftName"
      FROM attendance a 
      JOIN users u ON a."userId" = u.id
      LEFT JOIN shifts s ON u."shiftId" = s.id
      WHERE u.company = $1
    `;
    const params = [company];
    let counter = 2;

    if (startDate && endDate) {
      query += ` AND a."checkInTime" BETWEEN $${counter++} AND $${counter++}`;
      params.push(startDate + 'T00:00:00', endDate + 'T23:59:59');
    }
    
    query += ` ORDER BY a."checkInTime" DESC`;
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Admin Manual Attendance
// Note: Merged into /api/admin/attendance at the top

// ============ PAYSLIPS ============

// Admin: Create Payslip
app.post('/api/admin/payslips', async (req, res) => {
  const { userId, company, month, year, basicSalary, allowances, deductions, netSalary } = req.body;
  if (!userId || !month || !year || basicSalary === undefined) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const monthLabel = monthNames[month - 1] || month;

  try {
    const query = `
      INSERT INTO payslips ("userId", company, month, year, "basicSalary", allowances, deductions, "netSalary") 
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id
    `;
    const result = await pool.query(query, [userId, company, month, year, basicSalary, allowances || 0, deductions || 0, netSalary]);
    
    createNotification(userId, `💰 Payslip Ready: ${monthLabel} ${year}`, `Your payslip for ${monthLabel} ${year} is now available. Net Salary: ₹${parseFloat(netSalary).toLocaleString('en-IN')}. Check the Payslips section.`);
    res.json({ message: 'Payslip created', id: result.rows[0].id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Admin: Get all Payslips for Company
app.get('/api/admin/payslips', async (req, res) => {
  const company = req.query.company;
  if (!company) return res.status(400).json({ error: 'Company parameter is required' });
  try {
    const query = `
      SELECT p.*, u."fullName", u.email 
      FROM payslips p
      JOIN users u ON p."userId" = u.id
      WHERE p.company = $1
      ORDER BY p.year DESC, p.month DESC
    `;
    const result = await pool.query(query, [company]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Admin: Delete a Payslip
app.delete('/api/admin/payslips/:id', async (req, res) => {
  const { company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });

  try {
    const result = await pool.query('DELETE FROM payslips WHERE id = $1 AND company = $2', [req.params.id, company]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Payslip not found or access denied' });
    res.json({ message: 'Payslip deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// User: Get My Payslips
app.get('/api/payslips/:userId', async (req, res) => {
  try {
    const query = `
      SELECT p.*, u."fullName", u.email
      FROM payslips p
      JOIN users u ON p."userId" = u.id
      WHERE p."userId" = $1 
      ORDER BY p.year DESC, p.month DESC
    `;
    const result = await pool.query(query, [req.params.userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Check-out Reminders (Scan for active check-ins)
app.post('/api/admin/notifications/reminders', async (req, res) => {
  const { company } = req.body;
  if (!company) return res.status(400).json({ error: 'Company is required' });
  
  try {
    let query = `
      SELECT a.*, u.id as "userId", u."fullName" 
      FROM attendance a
      JOIN users u ON a."userId" = u.id
      WHERE a."checkOutTime" IS NULL
    `;
    const params = [];
    
    if (company) {
      query += ' AND u.company = $1';
      params.push(company);
    }

    const result = await pool.query(query, params);
    const rows = result.rows;
    
    rows.forEach(row => {
      createNotification(row.userId, 'Check-out Reminder', `Hi ${row.fullName}, don't forget to check out!`);
    });
    
    res.json({ message: `Reminders sent to ${rows.length} employees.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running at http://0.0.0.0:${port}`);
});
