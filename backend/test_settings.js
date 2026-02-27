const http = require('http');

const data = JSON.stringify({
  company: 'FUTURE',
  companyName: 'FUTURE',
  themeColor: '#7C4DFF'
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/api/admin/settings',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

const req = http.request(options, (res) => {
  console.log(`Status: ${res.statusCode}`);
  res.on('data', (d) => {
    process.stdout.write(d);
  });
});

req.on('error', (error) => {
  console.error(error);
});

req.write(data);
req.end();
