const bcrypt = require('bcryptjs');
const { pool } = require('../config/db');
const { verifyCompanyOwnership } = require('../middleware/auth');
const { createNotification, notifyAllCompanyUsers, notifyCompanyAdmins } = require('../services/notificationService');

exports.updateUserActive = async (req, res) => {
  const { isActive } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });
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
};

exports.updateUserApproval = async (req, res) => {
  const { isApproved, rejectionReason } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });
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
};

exports.getStats = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  try {
    const today = new Date().toISOString().split('T')[0];
    const todayStartStr = `${today} 00:00:00`;
    const todayEndStr = `${today} 23:59:59`;

    const [totalRes, presentRes, lateRes, leaveRes] = await Promise.all([
      pool.query(`SELECT COUNT(*) as count FROM users WHERE role = 'User' AND company = $1`, [company]),
      pool.query(
        `SELECT COUNT(DISTINCT a."userId") as count FROM attendance a JOIN users u ON a."userId" = u.id 
         WHERE a."checkInTime" >= $1 AND a."checkInTime" <= $2 AND u.company = $3`,
        [todayStartStr, todayEndStr, company]
      ),
      pool.query(
        `SELECT COUNT(DISTINCT a."userId") as count FROM attendance a JOIN users u ON a."userId" = u.id 
         WHERE a."checkInTime" >= $1 AND a."checkInTime" <= $2 AND a.status = 'Late' AND u.company = $3`,
        [todayStartStr, todayEndStr, company]
      ),
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
};

exports.getUsers = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

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
};

exports.deleteUser = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' }); 

  try {
    const check = await pool.query('SELECT id FROM users WHERE id = $1 AND company = $2', [req.params.id, company]);
    if (check.rowCount === 0) return res.status(403).json({ error: 'Access denied: User not found in your company' });

    await pool.query('DELETE FROM attendance WHERE "userId" = $1', [req.params.id]);
    await pool.query('DELETE FROM leaves WHERE "userId" = $1', [req.params.id]);
    await pool.query('DELETE FROM leave_balances WHERE "userId" = $1', [req.params.id]);
    await pool.query('DELETE FROM notifications WHERE "userId" = $1', [req.params.id]);
    await pool.query('DELETE FROM users WHERE id = $1 AND company = $2', [req.params.id, company]);
    
    res.json({ message: 'Employee and all associated data deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createUser = async (req, res) => {
  const { fullName, mobileNumber, email, password, role, department, salary, shiftId, isActive, weekOffs } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });
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
    if (err.code === '23505') {
      return res.status(400).json({ error: 'Mobile number or email already exists' });
    }
    res.status(500).json({ error: err.message });
  }
};

exports.getAttendance = async (req, res) => {
  const { userId, startDate, endDate, department, limit } = req.query;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

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
      query += ` AND a."checkInTime" >= $${counter}::date AND a."checkInTime" < $${counter+1}::date + interval '1 day'`;
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
};

exports.createAttendance = async (req, res) => {
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
};

exports.updateAttendance = async (req, res) => {
  const { checkInTime, checkOutTime, status, overtimeHours, adminId } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  try {
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
};

exports.getAbsentUsers = async (req, res) => {
  const company = req.user.company;
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
    
    const absent = usersResult.rows.filter(r => {
      const offs = (r.weekOffs || 'Sunday').split(',').map(s => s.trim());
      return !offs.includes(dayName);
    });
    
    res.json(absent);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getShifts = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  try {
    const result = await pool.query('SELECT * FROM shifts WHERE company = $1', [company]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createShift = async (req, res) => {
  const { name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });
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
};

exports.updateShift = async (req, res) => {
  const { name, startTime, endTime, gracePeriodMins, overtimeRate, latePenaltyPerMin } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });
  
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
};

exports.deleteShift = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  try {
    const result = await pool.query('DELETE FROM shifts WHERE id = $1 AND company = $2', [req.params.id, company]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Shift not found or access denied' });
    res.json({ message: 'Shift deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getHolidays = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  try {
    const query = 'SELECT * FROM holidays WHERE (company = $1 OR company IS NULL) ORDER BY date ASC';
    const result = await pool.query(query, [company]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createHoliday = async (req, res) => {
  const { name, date, type, duration } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });
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
};

exports.deleteHoliday = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  try {
    const result = await pool.query('DELETE FROM holidays WHERE id = $1 AND company = $2', [req.params.id, company]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Holiday not found or access denied' });
    res.json({ message: 'Holiday deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getLeavePolicies = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  try {
    const result = await pool.query('SELECT * FROM leave_policies WHERE company = $1', [company]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createLeavePolicy = async (req, res) => {
  const { leaveType, daysPerYear, isPaid } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });
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
};

exports.updateLeaveBalance = async (req, res) => {
  const { userId, leaveType, totalDays } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  try {
    const check = await pool.query('SELECT id FROM users WHERE id = $1 AND company = $2', [userId, company]);
    if (check.rowCount === 0) return res.status(403).json({ error: 'Access denied: User not found in your company' });

    const query = `
      INSERT INTO leave_balances ("userId", "leaveType", "totalDays") VALUES ($1, $2, $3)
      ON CONFLICT ("userId", "leaveType") DO UPDATE SET "totalDays" = EXCLUDED."totalDays"
    `;
    await pool.query(query, [userId, leaveType, totalDays]);
    res.json({ message: 'Balance updated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getUserLeaveBalance = async (req, res) => {
  if (!(await verifyCompanyOwnership(req, res, req.params.userId))) {
    return res.status(403).json({ error: 'Access denied: User belongs to a different company' });
  }
  try {
    const result = await pool.query('SELECT * FROM leave_balances WHERE "userId" = $1', [req.params.userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.applyLeave = async (req, res) => {
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
};

exports.getLeaveTypes = async (req, res) => {
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
};

exports.getLeaveBalance = async (req, res) => {
  if (!(await verifyCompanyOwnership(req, res, req.params.userId))) {
    return res.status(403).json({ error: 'Access denied: User belongs to a different company' });
  }
  const currentMonth = new Date().getMonth() + 1;
  const userId = req.params.userId;

  try {
    const userResult = await pool.query('SELECT "weekOffs", company FROM users WHERE id = $1', [userId]);
    const user = userResult.rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });
    
    const weekOffs = (user.weekOffs || 'Sunday').split(',').map(s => s.trim());
    const company = user.company;

    const hResult = await pool.query('SELECT date, duration FROM holidays WHERE (company = $1 OR company IS NULL)', [company]);
    const holidayMap = {};
    hResult.rows.forEach(h => holidayMap[h.date] = h.duration || 'Full Day');

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

    const lpResult = await pool.query('SELECT * FROM leave_policies WHERE company = $1', [company]);
    const policies = lpResult.rows;
    let leaveTypes = ['Sick Leave', 'Casual Leave', 'Annual Leave', 'Unpaid Leave'];
    if (policies && policies.length > 0) {
      leaveTypes = policies.map(p => p.leaveType);
    }

    const lbResult = await pool.query('SELECT * FROM leave_balances WHERE "userId" = $1', [userId]);
    const overrides = {};
    lbResult.rows.forEach(b => overrides[b.leaveType] = b.totalDays);
    
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
};

exports.getUserLeaves = async (req, res) => {
  if (!(await verifyCompanyOwnership(req, res, req.params.userId))) {
    return res.status(403).json({ error: 'Access denied: User belongs to a different company' });
  }
  try {
    const result = await pool.query('SELECT * FROM leaves WHERE "userId" = $1 ORDER BY "createdAt" DESC', [req.params.userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.cancelLeave = async (req, res) => {
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
};

exports.getAdminLeaves = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });
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
};

exports.updateLeaveStatus = async (req, res) => {
  const { status, rejectionReason } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

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
};

exports.getOvertimeReport = async (req, res) => {
  const { startDate, endDate, company } = req.query;
  const reqCompany = req.user.company || company;
  if (!reqCompany) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    let query = `
      SELECT a."userId", u."fullName", SUM(a."overtimeHours") as "totalOvertimeHours", COUNT(*) as "overtimeDays"
      FROM attendance a
      JOIN users u ON a."userId" = u.id
      WHERE a."overtimeHours" > 0 AND u.company = $1
    `;
    const params = [reqCompany];
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
};

exports.getSalaryHoursReport = async (req, res) => {
  const { startDate, endDate, company } = req.query;
  const reqCompany = req.user.company || company;
  if (!reqCompany) return res.status(400).json({ error: 'Company parameter is required' });

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
    const params = [reqCompany];
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
};

exports.getPayrollReport = async (req, res) => {
  const { startDate, endDate, company } = req.query;
  const reqCompany = req.user.company || company;
  if (!reqCompany) return res.status(400).json({ error: 'Company parameter is required' });

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
    const params = [reqCompany];
    let counter = 2;

    if (startDate && endDate) {
      query += ` AND a."checkInTime" BETWEEN $${counter++} AND $${counter++}`;
      params.push(startDate + 'T00:00:00', endDate + 'T23:59:59');
    }
    
    query += ` GROUP BY a."userId", u."fullName", u.salary, u."weekOffs", s."overtimeRate", s."latePenaltyPerMin", s."gracePeriodMins"`;
    const result = await pool.query(query, params);
    const rows = result.rows;

    const hResult = await pool.query('SELECT date, duration, type FROM holidays WHERE (company = $1 OR company IS NULL)', [reqCompany]);
    const holidayMap = {};
    hResult.rows.forEach(h => holidayMap[h.date] = (h.type === 'Optional') ? 'Optional' : (h.duration || 'Full Day'));
    
    const start = startDate ? new Date(startDate) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    const end = endDate ? new Date(endDate) : new Date();

    const dateWeights = {};
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
        const dateStr = d.toISOString().split('T')[0];
        const dayOfWeek = d.toLocaleDateString('en-US', { weekday: 'long' });
        const hType = holidayMap[dateStr];
        
        dateWeights[dateStr] = {
            dayName: dayOfWeek,
            weight: hType === 'Half Day' ? 0.5 : (hType === 'Full Day' ? 0.0 : 1.0)
        };
    }

    const finalResults = rows.map(r => {
      let actualWorkingDays = 0;
      const weekOffs = (r.weekOffs || 'Sunday').split(',').map(s => s.trim());
      
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
};

exports.getAttendanceReport = async (req, res) => {
  const { company, startDate, endDate } = req.query;
  const reqCompany = req.user.company || company;
  if (!reqCompany) return res.status(400).json({ error: 'Company parameter is required' });

  try {
    let query = `
      SELECT a.*, u."fullName", u.id as "employeeId", s.name as "shiftName"
      FROM attendance a 
      JOIN users u ON a."userId" = u.id
      LEFT JOIN shifts s ON u."shiftId" = s.id
      WHERE u.company = $1
    `;
    const params = [reqCompany];
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
};

exports.createPayslip = async (req, res) => {
  const { userId, month, year, basicSalary, allowances, deductions, netSalary } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });
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
};

exports.getCompanyPayslips = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });
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
};

exports.deletePayslip = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  try {
    const result = await pool.query('DELETE FROM payslips WHERE id = $1 AND company = $2', [req.params.id, company]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Payslip not found or access denied' });
    res.json({ message: 'Payslip deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.sendCheckoutReminders = async (req, res) => {
  const { company } = req.body;
  const reqCompany = req.user.company || company;
  if (!reqCompany) return res.status(400).json({ error: 'Company is required' });
  
  try {
    let query = `
      SELECT a.*, u.id as "userId", u."fullName" 
      FROM attendance a
      JOIN users u ON a."userId" = u.id
      WHERE a."checkOutTime" IS NULL AND u.company = $1
    `;

    const result = await pool.query(query, [reqCompany]);
    const rows = result.rows;
    
    rows.forEach(row => {
      createNotification(row.userId, 'Check-out Reminder', `Hi ${row.fullName}, don't forget to check out!`);
    });
    
    res.json({ message: `Reminders sent to ${rows.length} employees.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
