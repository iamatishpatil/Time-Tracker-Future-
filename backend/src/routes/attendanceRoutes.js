const express = require('express');
const router = express.Router();
const attendanceController = require('../controllers/attendanceController');
const { authenticateToken } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.use(authenticateToken);

router.post('/checkin', upload.single('photo'), attendanceController.checkin);
router.post('/checkout', upload.single('photo'), attendanceController.checkout);
router.get('/status/:userId', attendanceController.getStatus);
router.get('/stats/:userId', attendanceController.getStats);
router.get('/geofence-alert', attendanceController.geofenceAlert);
router.post('/geofence-alert', attendanceController.geofenceAlert);
router.get('/:userId', attendanceController.getUserAttendance);

module.exports = router;
