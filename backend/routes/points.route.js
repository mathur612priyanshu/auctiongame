const express = require("express");
const multer = require("multer");
const {
  getPlayerGroupsWithAuctions,
  bulkUploadPlayerPoints,
  getLeaderboard,
  getAllLeaderboardsForPlayerGroup,
  getPlayerPoints,
  getScoringRules,
  triggerLeaderboardUpdate,
  getUserPerformance,
} = require("../controllers/points.controller");

const router = express.Router();

// Configure multer for file upload
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    if (
      file.mimetype.includes("spreadsheet") ||
      file.mimetype.includes("excel") ||
      file.originalname.endsWith(".xlsx") ||
      file.originalname.endsWith(".xls")
    ) {
      cb(null, true);
    } else {
      cb(new Error("Only Excel files are allowed!"), false);
    }
  },
});

// Routes
router.get("/player-groups", getPlayerGroupsWithAuctions);
router.post("/upload-points", upload.single("file"), bulkUploadPlayerPoints);
router.get("/leaderboard/:auctionId/:playerGroup", getLeaderboard);
router.get("/leaderboards/:playerGroup", getAllLeaderboardsForPlayerGroup);
router.get("/player-points/:playerGroup", getPlayerPoints);
router.get("/scoring-rules", getScoringRules);
router.post("/update-leaderboard", triggerLeaderboardUpdate);
router.get("/user-performance/:userId/:playerGroup", getUserPerformance);

module.exports = router;
