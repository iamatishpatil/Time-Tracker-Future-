const axios = require('axios');
const fs = require('fs');
const FormData = require('form-data');
const path = require('path');

const BASE_URL = 'http://localhost:3000/api';

async function runTest() {
    try {
        const uniqueIdA = Date.now().toString().slice(-6) + '1';
        const uniqueIdB = Date.now().toString().slice(-6) + '2';
        console.log('--- STARTING MULTI-TENANCY & BRANDING TEST ---');

        // ==== 1. Setup Company A (Apple) ====
        console.log('\n[Company A] Registering Admin...');
        const adminAResponse = await axios.post(`${BASE_URL}/register`, {
            fullName: 'Admin Apple ' + uniqueIdA,
            mobileNumber: '99' + uniqueIdA,
            email: `adminA${uniqueIdA}@apple.com`,
            password: 'pwd',
            role: 'Admin',
            company: 'Apple'
        });
        if (adminAResponse.status !== 200 && adminAResponse.status !== 201) throw new Error('Failed to register A');

        console.log('[Company A] Logging in Admin...');
        const loginA = await axios.post(`${BASE_URL}/login`, {
            mobileNumber: '99' + uniqueIdA,
            password: 'pwd'
        });

        // Ensure "Apple" settings are scoped properly
        console.log('[Company A] Adding Shift...');
        await axios.post(`${BASE_URL}/admin/shifts`, {
            name: `Apple Morning Shift ${uniqueIdA}`,
            startTime: '09:00',
            endTime: '17:00',
            graceTime: 15,
            company: 'Apple'
        });

        console.log('[Company A] Setting Branding...');
        // Create a fake logo file
        fs.writeFileSync('temp_apple_logo.png', 'fake image data');
        const formA = new FormData();
        formA.append('logo', fs.createReadStream('temp_apple_logo.png'));
        formA.append('themeColor', '#FF0000');
        formA.append('company', 'Apple');
        formA.append('companyName', 'Apple');
        await axios.post(`${BASE_URL}/admin/branding`, formA, {
            headers: formA.getHeaders()
        });

        // ==== 2. Setup Company B (Banana) ====
        console.log('\n[Company B] Registering Admin...');
        const adminBResponse = await axios.post(`${BASE_URL}/register`, {
            fullName: 'Admin Banana ' + uniqueIdB,
            mobileNumber: '88' + uniqueIdB,
            email: `adminB${uniqueIdB}@banana.com`,
            password: 'pwd',
            role: 'Admin',
            company: 'Banana'
        });
        if (adminBResponse.status !== 200 && adminBResponse.status !== 201) throw new Error('Failed to register B');

        console.log('[Company B] Logging in Admin...');
        const loginB = await axios.post(`${BASE_URL}/login`, {
            mobileNumber: '88' + uniqueIdB,
            password: 'pwd'
        });

        console.log('[Company B] Adding Shift...');
        await axios.post(`${BASE_URL}/admin/shifts`, {
            name: 'Banana Night Shift',
            startTime: '18:00',
            endTime: '02:00',
            graceTime: 10,
            company: 'Banana'
        });


        // ==== 3. Data Isolation Verification ====
        console.log('\n--- VERIFYING DATA ISOLATION ---');
        
        // Fetch Settings A
        console.log('[Company A] Fetching Settings...');
        const settingsA = await axios.get(`${BASE_URL}/settings?company=Apple`);
        if (settingsA.data.themeColor !== '#FF0000') throw new Error('Company A themeColor mismatch');
        if (!settingsA.data.companyLogo) throw new Error('Company A logo missing');
        console.log('✅ Company A Branding Correct');

        // Fetch Settings B
        console.log('[Company B] Fetching Settings...');
        const settingsB = await axios.get(`${BASE_URL}/settings?company=Banana`);
        if (settingsB.data.themeColor && settingsB.data.themeColor === '#FF0000') throw new Error('Company B leaked Company A branding!');
        console.log('✅ Company B Branding Isolated');

        // Fetch Shifts A
        console.log('[Company A] Fetching Shifts...');
        const shiftsA = await axios.get(`${BASE_URL}/admin/shifts?company=Apple`);
        if (!shiftsA.data.some(s => s.name === `Apple Morning Shift ${uniqueIdA}`)) throw new Error('Company A missing shift');
        if (shiftsA.data.some(s => s.name === 'Banana Night Shift')) throw new Error('Company A sees Company B shift!');
        console.log('✅ Company A Shifts Isolated');

        // Fetch Shifts B
        console.log('[Company B] Fetching Shifts...');
        const shiftsB = await axios.get(`${BASE_URL}/admin/shifts?company=Banana`);
        if (!shiftsB.data.some(s => s.name === 'Banana Night Shift')) throw new Error('Company B missing shift');
        if (shiftsB.data.some(s => s.name === `Apple Morning Shift ${uniqueIdA}`)) throw new Error('Company B sees Company A shift!');
        console.log('✅ Company B Shifts Isolated');

        console.log('\n🎉 ALL TESTS PASSED! Multi-Tenancy and Branding APIs are working flawlessly.');

    } catch (err) {
        console.error('\n❌ TEST FAILED:', err.message);
        if(err.response) {
             console.error('Response Data:', err.response.data);
        }
    } finally {
        if (fs.existsSync('temp_apple_logo.png')) fs.unlinkSync('temp_apple_logo.png');
    }
}

runTest();
