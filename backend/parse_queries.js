const fs = require('fs');
const content = fs.readFileSync('server.js', 'utf8');
const queries = content.match(/pool\.query\(([`'"])([\s\S]*?)\1/g);
if (queries) {
  queries.forEach((q, i) => console.log(`--- Query ${i+1} ---\n${q}\n`));
} else {
  console.log('No queries found');
}
