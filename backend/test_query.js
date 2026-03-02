const { Pool } = require('pg');
const pool = new Pool({ user: 'postgres', host: 'localhost', database: 'time_tracker_dev', password: '12345', port: 5432 });
pool.query('SELECT a.*, u."fullName", u."profilePicture", u.department, s.name as "shiftName" FROM attendance a JOIN users u ON a."userId" = u.id LEFT JOIN shifts s ON u."shiftId" = s.id WHERE u.company = $1 AND a."checkInTime"::text >= $2 AND a."checkInTime"::text < $3::date + interval \'1 day\'', ['Test', '2026-03-02', '2026-03-02'])
  .then(res => { console.log('SUCCESS:', res.rows.length); process.exit(0); })
  .catch(err => { console.error('SQL ERROR:', err.message); process.exit(1); });
