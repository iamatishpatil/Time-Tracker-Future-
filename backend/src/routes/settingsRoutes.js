const express = require('express');
const router = express.Router();
const settingsController = require('../controllers/settingsController');
const { authenticateToken } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.use(authenticateToken);

router.get('/settings', settingsController.getSettings);
router.post('/admin/settings', settingsController.updateSettings);
router.post('/admin/branding', upload.single('logo'), settingsController.updateBranding);

module.exports = router;
