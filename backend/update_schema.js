const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const nodeEnv = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: `.env.${nodeEnv}` });

const dbFile = process.env.DB_FILE || path.join(__dirname, 'time_tracker.db');
const db = new sqlite3.Database(dbFile);

db.serialize(() => {
  // Add columns to holidays table
  db.run("ALTER TABLE holidays ADD COLUMN type TEXT DEFAULT 'Public'", (err) => {
    if (err) {
      if (err.message.includes('duplicate column name')) {
        console.log('Column "type" already exists in holidays table');
      } else {
        console.error('Error adding "type" to holidays:', err.message);
      }
    } else {
      console.log('Column "type" added to holidays table');
    }
  });

  db.run("ALTER TABLE holidays ADD COLUMN duration TEXT DEFAULT 'Full Day'", (err) => {
    if (err) {
      if (err.message.includes('duplicate column name')) {
        console.log('Column "duration" already exists in holidays table');
      } else {
        console.error('Error adding "duration" to holidays:', err.message);
      }
    } else {
      console.log('Column "duration" added to holidays table');
    }
  });

  // Add column to users table
  db.run("ALTER TABLE users ADD COLUMN weekOffs TEXT DEFAULT 'Sunday'", (err) => {
    if (err) {
      if (err.message.includes('duplicate column name')) {
        console.log('Column "weekOffs" already exists in users table');
      } else {
        console.error('Error adding "weekOffs" to users:', err.message);
      }
    } else {
      console.log('Column "weekOffs" added to users table');
    }
  });
});

db.close();
