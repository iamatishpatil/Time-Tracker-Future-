const { Pool } = require('pg');
const pool = new Pool({ user: 'postgres', host: 'localhost', database: 'time_tracker_dev', password: '12345', port: 5432 });

async function run() {
  try {
    const res = await pool.query('SELECT company, "companyName", "officeLat", "officeLong", "officeRadiusMeters", "geofenceEnabled" FROM settings');
    console.log('--- SETTINGS ---');
    console.log(JSON.stringify(res.rows, null, 2));
    
    const users = await pool.query('SELECT id, "fullName", company, latitude as "regLat", longitude as "regLong" FROM users WHERE role = \'User\' LIMIT 5');
    console.log('--- USERS ---');
    console.log(JSON.stringify(users.rows, null, 2));
    
  } catch (err) {
    console.error(err);
  } finally {
    await pool.end();
  }
}

run();
