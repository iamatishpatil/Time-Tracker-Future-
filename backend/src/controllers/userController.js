const bcrypt = require('bcryptjs');
const { pool } = require('../config/db');
const { verifyCompanyOwnership } = require('../middleware/auth');

exports.getUser = async (req, res) => {
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
};

exports.updateUser = async (req, res) => {
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
};

exports.getNotifications = async (req, res) => {
  if (!(await verifyCompanyOwnership(req, res, req.params.userId))) {
    return res.status(403).json({ error: 'Access denied: User belongs to a different company' });
  }
  try {
    const result = await pool.query('SELECT * FROM notifications WHERE "userId" = $1 ORDER BY "createdAt" DESC', [req.params.userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.markNotificationRead = async (req, res) => {
  try {
    await pool.query('UPDATE notifications SET "isRead" = 1 WHERE id = $1', [req.params.id]);
    res.json({ message: 'Marked as read' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getUserPayslips = async (req, res) => {
  if (!(await verifyCompanyOwnership(req, res, req.params.userId))) {
    return res.status(403).json({ error: 'Access denied: User belongs to a different company' });
  }
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
};

exports.updateFcmToken = async (req, res) => {
  const { userId, fcmToken } = req.body;
  if (!userId || !fcmToken) return res.status(400).json({ error: 'userId and fcmToken are required' });
  try {
    await pool.query('UPDATE users SET "fcmToken" = $1 WHERE id = $2', [fcmToken, userId]);
    res.json({ message: 'FCM Token updated successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
