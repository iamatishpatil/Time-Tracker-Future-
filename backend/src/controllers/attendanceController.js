const { pool } = require('../config/db');
const { verifyCompanyOwnership } = require('../middleware/auth');
const { createNotification, calculateDistance, checkGeofenceBreach } = require('../services/notificationService');

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

exports.checkin = async (req, res) => {
  const { userId, lat, long, address } = req.body;
  const photo = req.file ? `/uploads/${req.file.filename}` : null;
  const now = new Date().toISOString();

  try {
    const [checkResult, user] = await Promise.all([
      pool.query('SELECT id FROM attendance WHERE "userId" = $1 AND "checkOutTime" IS NULL', [userId]),
      getUserWithShift(userId)
    ]);
    
    if (checkResult.rowCount > 0) return res.status(400).json({ error: 'Already checked in' });
    const company = user ? user.company : null;

    let settingsResult;
    if (company) {
      settingsResult = await pool.query('SELECT "geofenceEnabled", "officeLat", "officeLong", "officeRadiusMeters" FROM settings WHERE company = $1 OR "companyName" = $2 ORDER BY id DESC LIMIT 1', [company, company]);
    } else {
      settingsResult = await pool.query('SELECT "geofenceEnabled", "officeLat", "officeLong", "officeRadiusMeters" FROM settings WHERE company IS NULL LIMIT 1');
    }
    const settings = settingsResult.rows[0];

    if (settings && settings.geofenceEnabled !== 0 && settings.officeLat && settings.officeLong && lat && long) {
      const distance = calculateDistance(lat, long, settings.officeLat, settings.officeLong);
      const buffer = 20.0;
      if (distance > (settings.officeRadiusMeters + buffer)) {
        return res.status(403).json({ error: `Outside office radius. Distance: ${Math.round(distance)}m, Limit: ${settings.officeRadiusMeters + buffer}m (incl. buffer)` });
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
      } catch (e) {
        status = 'On Time';
      }
    }

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
};

exports.checkout = async (req, res) => {
  const { userId, lat, long, address } = req.body;
  const photo = req.file ? `/uploads/${req.file.filename}` : null;
  const now = new Date().toISOString();

  try {
    const result = await pool.query('SELECT * FROM attendance WHERE "userId" = $1 AND "checkOutTime" IS NULL', [userId]);
    const row = result.rows[0];
    if (!row) return res.status(400).json({ error: 'No active check-in' });

    const user = await getUserWithShift(userId);
    const company = user ? user.company : null;

    let settingsResult;
    if (company) {
      settingsResult = await pool.query('SELECT * FROM settings WHERE company = $1 OR "companyName" = $2 ORDER BY id DESC LIMIT 1', [company, company]);
    } else {
      settingsResult = await pool.query('SELECT * FROM settings WHERE company IS NULL LIMIT 1');
    }
    const settings = settingsResult.rows[0];

    if (settings && settings.geofenceEnabled !== 0 && settings.officeLat && settings.officeLong && lat && long) {
      const distance = calculateDistance(lat, long, settings.officeLat, settings.officeLong);
      const buffer = 20.0;
      if (distance > (settings.officeRadiusMeters + buffer)) {
        return res.status(403).json({ error: `Outside office radius. Distance: ${Math.round(distance)}m, Limit: ${settings.officeRadiusMeters + buffer}m (incl. buffer)` });
      }
    }

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

    await pool.query(
      `UPDATE attendance SET "checkOutTime" = $1, "checkOutLat" = $2, "checkOutLong" = $3, "checkOutAddress" = $4, "checkOutPhoto" = $5, "overtimeHours" = $6, "isOutside" = 0
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
};

exports.getStatus = async (req, res) => {
  if (!(await verifyCompanyOwnership(req, res, req.params.userId))) {
    return res.status(403).json({ error: 'Access denied: User belongs to a different company' });
  }
  try {
    const result = await pool.query('SELECT id FROM attendance WHERE "userId" = $1 AND "checkOutTime" IS NULL', [req.params.userId]);
    res.json({ isCheckedIn: result.rowCount > 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getStats = async (req, res) => {
  if (!(await verifyCompanyOwnership(req, res, req.params.userId))) {
    return res.status(403).json({ error: 'Access denied: User belongs to a different company' });
  }
  const userId = req.params.userId;
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
  const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1).toISOString();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
  const daysPassed = now.getDate();

  try {
    const todayResult = await pool.query(`
      SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (COALESCE("checkOutTime", NOW()) - "checkInTime")) / 3600), 0) AS hours
      FROM attendance
      WHERE "userId" = $1 AND "checkInTime" >= $2 AND "checkInTime" < $3
    `, [userId, todayStart, todayEnd]);

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
};

exports.getUserAttendance = async (req, res) => {
  if (!(await verifyCompanyOwnership(req, res, req.params.userId))) {
    return res.status(403).json({ error: 'Access denied: User belongs to a different company' });
  }
  const { startDate, endDate } = req.query;
  try {
    let query = 'SELECT * FROM attendance WHERE "userId" = $1';
    const params = [req.params.userId];

    if (startDate && endDate) {
      query += ' AND "checkInTime" BETWEEN $2 AND $3';
      params.push(startDate + ' 00:00:00', endDate + ' 23:59:59');
    }

    query += ' ORDER BY "checkInTime" DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.geofenceAlert = async (req, res) => {
  const { userId, lat, long } = req.body;
  const company = req.user.company;
  
  if (!userId || !lat || !long) return res.status(400).json({ error: 'Missing data' });
  
  try {
     await checkGeofenceBreach(userId, lat, long, company);
     res.json({ message: 'Status checked' });
  } catch (err) {
     res.status(500).json({ error: err.message });
  }
};
