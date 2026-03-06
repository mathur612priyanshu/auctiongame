const express = require("express");
const authentication = require("../controllers/auth.controller");
const router = express.Router();
const auth = require("../middlewares/isAuthenticated");
const multer = require("multer");

const storage = multer.memoryStorage();
const upload = multer({ storage });

// Static admin login for admin-panel
router.post("/auth/login", authentication.static_login);

router.post(
  "/auth/send_verification_code",
  authentication.send_verification_code
);
router.put(
  "/profile-update",
  upload.single("file"),
  auth.isAuthenticated,
  authentication.updateUserProfile
);

router.get("/auth/userdetail", auth.isAuthenticated, authentication.userdetail);

router.post("/auth/otpverify", authentication.verify_otp);

module.exports = router;
