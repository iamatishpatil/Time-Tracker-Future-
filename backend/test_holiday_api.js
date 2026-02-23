const axios = require('axios');

async function test() {
  const baseUrl = 'http://localhost:3000/api';
  
  console.log('--- Testing Global Holidays (No Company) ---');
  try {
    const res = await axios.get(`${baseUrl}/admin/holidays`);
    console.log(`Status: ${res.status}, Count: ${res.data.length}`);
    if (res.data.length > 0) console.log(`First holiday: ${res.data[0].name}`);
  } catch (e) { console.error(e.message); }

  console.log('\n--- Testing Holidays for Company "Test" ---');
  try {
    const res = await axios.get(`${baseUrl}/admin/holidays?company=Test`);
    console.log(`Status: ${res.status}, Count: ${res.data.length}`);
    // Should still return global ones (company IS NULL)
  } catch (e) { console.error(e.message); }
}

test();
