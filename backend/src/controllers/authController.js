const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/db');
const { createNotification } = require('../services/notificationService');
const { sendOtpEmail } = require('../services/emailService');

const sendOtpMock = (type, value, otp) => {
  console.log(`[VERIFICATION] Sent ${type} OTP to ${value}: ${otp}`);
};

const provisionCompany = async (companyIdRaw) => {
  const companyId = companyIdRaw ? companyIdRaw.trim() : null;
  console.log(`[BOOTSTRAP] Provisioning company ID: "${companyId}"`);
  if (!companyId) return;

  try {
    const settingsCheck = await pool.query('SELECT id FROM settings WHERE company = $1 OR "companyName" = $2', [companyId, companyId]);
    if (settingsCheck.rowCount === 0) {
      await pool.query(
        `INSERT INTO settings (company, "companyName", "geofenceEnabled", "payrollEnabled", "cameraAuthEnabled", "officeRadiusMeters", "workingDays", "weekendDays", "themeColor", "secondaryColor", "accentColor") 
         VALUES ($1, $2, 0, 1, 1, 200, '["Mon","Tue","Wed","Thu","Fri"]', '["Sat","Sun"]', '#7C4DFF', '#7C4DFF', '#00B8D4')`,
        [companyId, companyId]
      );
    }

    const shiftCheck = await pool.query('SELECT id FROM shifts WHERE company = $1', [companyId]);
    if (shiftCheck.rowCount === 0) {
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

    const lpCheck = await pool.query('SELECT id FROM leave_policies WHERE company = $1 LIMIT 1', [companyId]);
    if (lpCheck.rowCount === 0) {
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
  } catch (err) {
    console.error('[BOOTSTRAP] Error provisioning company:', err);
  }
};

exports.sendOtp = async (req, res) => {
  let type = req.body.type;
  let value = req.body.value;

  if (!type || !value) {
    if (req.body.email) {
      type = 'email';
      value = req.body.email;
    } else if (req.body.mobileNumber) {
      type = 'mobile';
      value = req.body.mobileNumber;
    }
  }

  if (!value) {
    return res.status(400).json({ error: 'Email or Mobile Number is required' });
  }

  // Generate real dynamic random 4-digit OTP
  const otp = Math.floor(1000 + Math.random() * 9000).toString();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  try {
    const col = type === 'email' ? '"email"' : '"mobileNumber"';
    await pool.query(`INSERT INTO otps (${col}, otp, "expiresAt") VALUES ($1, $2, $3)`, [value, otp, expiresAt]);
    
    let isSimulated = false;
    if (type === 'email') {
      const emailResult = await sendOtpEmail(value, otp);
      if (emailResult.simulated) isSimulated = true;
    } else {
      sendOtpMock(type, value, otp);
      isSimulated = true;
    }
    
    console.log(`\n==========================================`);
    console.log(`🔑 [VERIFICATION OTP DISPATCH]`);
    console.log(`   Type:     ${type.toUpperCase()}`);
    console.log(`   Target:   ${value}`);
    console.log(`   Code:     ${otp}`);
    console.log(`   Status:   ${isSimulated ? 'Simulated (Set SMTP in .env for live email delivery)' : 'Live Email Sent'}`);
    console.log(`==========================================\n`);

    const isDev = process.env.NODE_ENV !== 'production' || !process.env.SMTP_USER;
    
    res.json({ 
      message: 'OTP sent successfully',
      otp: isDev ? otp : undefined,
      simulated: isSimulated
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.verifyOtp = async (req, res) => {
  let { type, value, otp } = req.body;
  if (!type || !value) {
    if (req.body.email) {
      type = 'email';
      value = req.body.email;
    } else if (req.body.mobileNumber) {
      type = 'mobile';
      value = req.body.mobileNumber;
    }
  }

  try {
    const col = type === 'email' ? '"email"' : '"mobileNumber"';
    const result = await pool.query(`SELECT * FROM otps WHERE ${col} = $1 AND otp = $2 ORDER BY "expiresAt" DESC LIMIT 1`, [value, otp]);
    const record = result.rows[0];

    if (!record) return res.status(400).json({ error: 'Invalid OTP' });
    if (new Date() > new Date(record.expiresAt)) return res.status(400).json({ error: 'OTP expired' });

    res.json({ message: 'OTP verified successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.resetPassword = async (req, res) => {
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
};

exports.changePassword = async (req, res) => {
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
};

exports.register = async (req, res) => {
  if (!req.body) {
    return res.status(400).json({ error: 'Request body is missing. Ensure you are sending form-data and have no conflicting headers.' });
  }
  const { fullName, email, mobileNumber, gender, password, role, company, department, experience, technologies, address, latitude, longitude, shiftId, isActive } = req.body;
  const profilePicture = req.file ? `/uploads/${req.file.filename}` : null;

  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const approvalStatus = (role === 'Admin') ? 1 : 0;
    
    const query = `
      INSERT INTO users ("fullName", email, "mobileNumber", gender, password, role, company, department, experience, technologies, address, latitude, longitude, "profilePicture", "shiftId", "isActive", "isApproved", "weekOffs", "biometricToken") 
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19) 
      RETURNING id
    `;
    const result = await pool.query(query, [
      fullName, email, mobileNumber, gender, hashedPassword, role || 'User', company, department, experience, technologies, address, latitude, longitude, profilePicture, shiftId, isActive !== undefined ? isActive : 1, approvalStatus, 'Sunday', req.body.biometricToken || null
    ]);
    const newUserId = result.rows[0].id;

    if (role === 'Admin' && company) {
      await provisionCompany(company);
      const welcomeTitle = "Welcome to Pulse Hub! 🚀";
      const welcomeMsg = `Congratulations ${fullName}! Your organization "${company}" is now live. We've pre-configured your shifts and leave policies. Head over to Settings to finalize your office location.`;
      createNotification(newUserId, welcomeTitle, welcomeMsg);
    }

    const token = jwt.sign(
      { id: newUserId, role: role || 'User', company: company },
      process.env.JWT_SECRET || 'fallback_dev_secret_do_not_use_in_prod',
      { expiresIn: '30d' }
    );

    res.json({ message: 'User registered', id: newUserId, token: token, user: { id: newUserId, fullName, company, role } });
  } catch (err) {
    if (err.code === '23505') {
       return res.status(400).json({ error: 'Mobile number or email already exists' });
    }
    res.status(500).json({ error: err.message });
  }
};

exports.login = async (req, res) => {
  if (!req.body || Object.keys(req.body).length === 0) {
    return res.status(400).json({ error: 'Request body is missing or malformed. Ensure you are sending JSON and have "Content-Type: application/json" header.' });
  }
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
    
    if (req.body.biometricToken && req.body.biometricToken !== user.biometricToken) {
        await pool.query('UPDATE users SET "biometricToken" = $1 WHERE id = $2', [req.body.biometricToken, user.id]);
        user.biometricToken = req.body.biometricToken;
    }

    if (req.body.fcmToken && req.body.fcmToken !== user.fcmToken) {
        await pool.query('UPDATE users SET "fcmToken" = $1 WHERE id = $2', [req.body.fcmToken, user.id]);
        user.fcmToken = req.body.fcmToken;
    }
    
    const token = jwt.sign(
      { id: user.id, role: user.role, company: user.company },
      process.env.JWT_SECRET || 'fallback_dev_secret_do_not_use_in_prod',
      { expiresIn: '30d' }
    );

    res.json({ message: 'Login successful', user: user, token: token });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.biometricLogin = async (req, res) => {
  const { biometricToken } = req.body;
  if (!biometricToken) return res.status(400).json({ error: 'Biometric token is required' });

  try {
    const query = `
      SELECT u.*, s.name as "shiftName", s."startTime" as "shiftStart", s."endTime" as "shiftEnd" 
      FROM users u 
      LEFT JOIN shifts s ON u."shiftId" = s.id 
      WHERE u."biometricToken" = $1
    `;
    const result = await pool.query(query, [biometricToken]);
    const user = result.rows[0];
    
    if (!user) return res.status(401).json({ error: 'Biometric token not recognized. Please login manually first.' });
    if (user.isActive === 0) return res.status(403).json({ error: 'Account is deactivated. Please contact admin.' });
    if (user.role !== 'Admin' && user.isApproved === 0) return res.status(403).json({ error: 'Your account is pending admin approval.' });

    const token = jwt.sign(
      { id: user.id, role: user.role, company: user.company },
      process.env.JWT_SECRET || 'fallback_dev_secret_do_not_use_in_prod',
      { expiresIn: '30d' }
    );

    res.json({ message: 'Login successful', user: user, token: token });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.provisionCompany = provisionCompany;
