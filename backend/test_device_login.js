const http = require('http');

const postData = JSON.stringify({
  mobileNumber: '9876543210',
  password: 'Admin@123'
});

const options = {
  hostname: '192.168.1.33',
  port: 3000,
  path: '/api/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  },
  timeout: 5000
};

console.log('Testing login from IP: 192.168.1.33:3000');
console.log('This is the IP the Android device is using\n');

const req = http.request(options, (res) => {
  console.log(`✅ Connection successful!`);
  console.log(`Status Code: ${res.statusCode}`);
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log('\nResponse:');
    console.log(data);
  });
});

req.on('error', (error) => {
  console.error('❌ Connection Error:', error.message);
  console.error('\nPossible issues:');
  console.error('1. Server not listening on 192.168.1.33');
  console.error('2. Firewall blocking the connection');
  console.error('3. Wrong IP address configured');
});

req.on('timeout', () => {
  console.error('❌ Request timed out');
  req.destroy();
});

req.write(postData);
req.end();
