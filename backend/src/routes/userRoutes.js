const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { authenticateToken } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.use(authenticateToken);

router.get('/:id', userController.getUser);
router.put('/:id', upload.single('profilePicture'), userController.updateUser);
router.get('/notifications/:userId', userController.getNotifications);
router.put('/notifications/:id/read', userController.markNotificationRead);
router.get('/payslips/:userId', userController.getUserPayslips);
router.post('/fcm-token', userController.updateFcmToken);

module.exports = router;
