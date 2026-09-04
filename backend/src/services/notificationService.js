const { pool } = require('../config/db');
const { sendPushNotification } = require('../config/firebase');

const createNotification = async (userId, title, message) => {
  try {
    await pool.query('INSERT INTO notifications ("userId", title, message) VALUES ($1, $2, $3)', [userId, title, message]);
    
    // Dispatch real-time Firebase Push Notification if device FCM token exists
    const userRes = await pool.query('SELECT "fcmToken" FROM users WHERE id = $1', [userId]);
    const fcmToken = userRes.rows[0]?.fcmToken;
    if (fcmToken) {
      await sendPushNotification(fcmToken, title, message, { userId: String(userId) });
    }
  } catch (err) {
    console.error('Error creating notification:', err);
  }
};

const notifyAllCompanyUsers = async (company, title, message) => {
  try {
    const result = await pool.query(`SELECT id FROM users WHERE company = $1 AND role = 'User' AND "isActive" = 1`, [company]);
    result.rows.forEach(r => createNotification(r.id, title, message));
  } catch (err) {
    console.error('Error notifying all company users:', err);
  }
};

const notifyCompanyAdmins = async (company, title, message) => {
  try {
    const result = await pool.query(`SELECT id FROM users WHERE company = $1 AND role = 'Admin'`, [company]);
    result.rows.forEach(r => createNotification(r.id, title, message));
  } catch (err) {
    console.error('Error notifying company admins:', err);
  }
};

const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371e3;
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) *
    Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
};

const checkGeofenceBreach = async (userId, lat, long, company) => {
  try {
    const settingsResult = await pool.query('SELECT "officeLat", "officeLong", "officeRadiusMeters" FROM settings WHERE company = $1 OR "companyName" = $2 ORDER BY id DESC LIMIT 1', [company, company]);
    const settings = settingsResult.rows[0];
    if (!settings || !settings.officeLat) return;

    const distance = calculateDistance(lat, long, settings.officeLat, settings.officeLong);
    const buffer = 20.0;
    const isNowOutside = distance > (settings.officeRadiusMeters + buffer);

    const attendanceResult = await pool.query('SELECT id, "isOutside" FROM attendance WHERE "userId" = $1 AND "checkOutTime" IS NULL ORDER BY "checkInTime" DESC LIMIT 1', [userId]);
    const attendance = attendanceResult.rows[0];
    if (!attendance) return;

    const wasOutside = attendance.isOutside === 1;

    if (isNowOutside && !wasOutside) {
      const employeeResult = await pool.query('SELECT "fullName" FROM users WHERE id = $1', [userId]);
      const employeeName = employeeResult.rows[0]?.fullName || 'Employee';

      await pool.query('UPDATE attendance SET "isOutside" = 1 WHERE id = $1', [attendance.id]);
      await createNotification(userId, '📍 Outside Workspace', 'You are going out side the radius. Please return to your work area.');
      await notifyCompanyAdmins(company, '📍 Geofence Breach', `${employeeName} is going outside the radius.`);

    } else if (!isNowOutside && wasOutside) {
      const employeeResult = await pool.query('SELECT "fullName" FROM users WHERE id = $1', [userId]);
      const employeeName = employeeResult.rows[0]?.fullName || 'Employee';

      await pool.query('UPDATE attendance SET "isOutside" = 0 WHERE id = $1', [attendance.id]);
      await createNotification(userId, '✅ Back in Workspace', 'You have returned to the office radius.');
      await notifyCompanyAdmins(company, '✅ Geofence Resolved', `${employeeName} came inside the radius.`);
    }
  } catch (err) {
    console.error('Error in checkGeofenceBreach:', err);
  }
};

module.exports = {
  createNotification,
  notifyAllCompanyUsers,
  notifyCompanyAdmins,
  calculateDistance,
  checkGeofenceBreach
};
