const fs = require('fs');
const path = 'c:\\Users\\admin\\Desktop\\Time Tracker\\backend\\server.js';
let content = fs.readFileSync(path, 'utf8');

// Replacement for check-in (lines 540-542)
const checkInOld = /if \(distance > settings\.officeRadiusMeters\) \{\s+return res\.status\(403\)\.json\(\{ error: `Outside office radius\. Distance: \$\{Math\.round\(distance\)\}m, Max: \$\{settings\.officeRadiusMeters\}m` \}\);\s+\}/;
const checkInNew = `const buffer = 20.0;\n      if (distance > (settings.officeRadiusMeters + buffer)) {\n        return res.status(403).json({ error: \`Outside office radius. Distance: \${Math.round(distance)}m, Limit: \${settings.officeRadiusMeters + buffer}m (incl. buffer)\` });\n      }`;

// We perform replacement twice as it appears in check-in and check-out
// The patterns are identical in both places based on grep.
content = content.replace(new RegExp(checkInOld, 'g'), checkInNew);

fs.writeFileSync(path, content);
console.log('Successfully updated server.js with geofence buffer.');
