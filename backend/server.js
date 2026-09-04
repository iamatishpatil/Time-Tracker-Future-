const path = require('path');
const nodeEnv = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: path.join(__dirname, `.env.${nodeEnv}`) });

const app = require('./src/app');
const { runMigrations } = require('./src/config/db');
const { initFirebaseAdmin } = require('./src/config/firebase');

const port = process.env.PORT || 3000;
console.log(`Starting server in ${nodeEnv.toUpperCase()} mode on port ${port}`);

// Run migrations on startup
runMigrations();

// Initialize Firebase Admin SDK
initFirebaseAdmin();

app.listen(port, '0.0.0.0', () => {
  console.log(`Trackzo Backend Server running at http://0.0.0.0:${port}`);
});
