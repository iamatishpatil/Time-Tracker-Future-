const jwt = require('jsonwebtoken');
const { pool } = require('../config/db');

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (token == null) return res.status(401).json({ error: 'Authentication required' });

  jwt.verify(token, process.env.JWT_SECRET || 'fallback_dev_secret_do_not_use_in_prod', (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid or expired token' });
    req.user = user;
    next();
  });
};

const verifyCompanyOwnership = async (req, res, targetUserId) => {
  let requesterCompany = req.user ? req.user.company : null;

  if (!requesterCompany && req.user && req.user.id) {
    try {
      const selfResult = await pool.query('SELECT company FROM users WHERE id = $1', [req.user.id]);
      if (selfResult.rowCount > 0) {
        requesterCompany = selfResult.rows[0].company;
      }
    } catch (err) {
      console.error('verifyCompanyOwnership DB fallback error:', err);
      return false;
    }
  }

  if (!requesterCompany) return false;

  try {
    const result = await pool.query('SELECT company FROM users WHERE id = $1', [targetUserId]);
    if (result.rowCount === 0) return false;
    return result.rows[0].company === requesterCompany;
  } catch (err) {
    console.error('Ownership check error:', err);
    return false;
  }
};

module.exports = {
  authenticateToken,
  verifyCompanyOwnership
};
