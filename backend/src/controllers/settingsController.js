const { pool } = require('../config/db');
const { provisionCompany } = require('./authController');

exports.getSettings = async (req, res) => {
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  try {
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
};

exports.updateSettings = async (req, res) => {
  const { companyName, officeLat, officeLong, officeRadiusMeters, workingDays, weekendDays, geofenceEnabled, payrollEnabled, cameraAuthEnabled, themeColor, secondaryColor, accentColor } = req.body;
  const company = req.user.company;
  if (!company) return res.status(403).json({ error: 'Company context missing in token' });

  const wDays = workingDays ? JSON.stringify(workingDays) : '["Mon","Tue","Wed","Thu","Fri"]';
  const wkDays = weekendDays ? JSON.stringify(weekendDays) : '["Sat","Sun"]';
  const geoEnabled = geofenceEnabled !== undefined ? geofenceEnabled : 1;
  const payEnabled = payrollEnabled !== undefined ? payrollEnabled : 1;
  const camEnabled = cameraAuthEnabled !== undefined ? (cameraAuthEnabled ? 1 : 0) : 1;

  try {
    const check = await pool.query('SELECT id FROM settings WHERE company = $1 OR "companyName" = $2 ORDER BY id DESC LIMIT 1', [company, company]);
    const row = check.rows[0];
    
    if (row) {
      await pool.query(
        `UPDATE settings SET company = $1, "companyName" = $2, "officeLat" = $3, "officeLong" = $4, "officeRadiusMeters" = $5, 
         "workingDays" = $6, "weekendDays" = $7, "geofenceEnabled" = $8, "payrollEnabled" = $9, "cameraAuthEnabled" = $10, 
         "themeColor" = $11, "secondaryColor" = $12, "accentColor" = $13 
         WHERE id = $14`,
        [company, companyName, officeLat, officeLong, officeRadiusMeters, wDays, wkDays, geoEnabled, payEnabled, camEnabled, themeColor, secondaryColor, accentColor, row.id]
      );
      res.json({ message: 'Settings updated' });
    } else {
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
};

exports.updateBranding = async (req, res) => {
  try {
    const body = req.body || {};
    const company = body.company || req.user.company;
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
};
