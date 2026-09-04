const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const upload = require('../middleware/upload');

router.post('/otp/send', authController.sendOtp);
router.post('/otp/verify', authController.verifyOtp);
router.post('/reset-password', authController.resetPassword);
router.post('/change-password', authController.changePassword);
router.post('/register', upload.single('profilePicture'), authController.register);
router.post('/login', authController.login);
router.post('/login/biometric', authController.biometricLogin);

module.exports = router;
