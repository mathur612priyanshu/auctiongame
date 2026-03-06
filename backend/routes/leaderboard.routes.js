const express = require("express");
const router = express.Router();
const {
  getAuctionLeaderboard,
  getAllLeaderboards,
} = require("../controllers/leaderboard.controller");

// Get leaderboard for specific auction
router.get("/auction/:auctionId", getAuctionLeaderboard);

// Get all leaderboards
router.get("/", getAllLeaderboards);

module.exports = router;
