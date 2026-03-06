const express = require("express");
const router = express.Router();
const {
  createAuction,
  getAllAuctions,
  getAuctionById,
  updateAuction,
  deleteAuction,
  bulkDeleteAuctions,
  getAuctionsByStatus,
  addPlayerToAuction,
  removePlayerFromAuction,
  startAuctionmanualUpdate,
  getUserBudget,
  getUserTeam,
  getAllUserBudgets,
  getAuctionStats,
  getAuctionHistory,
  updateUserBudget,
  startAuctionManually,
  stopAuction,
  resetAuction,
  getAuctionStatus,
  getbidofeachplayer,
  getteamsummary,
  joinAuction,
  getAuctionParticipants,
  leaveAuction,
  getUserParticipatedAuctions,
  getAuctionParticipantsWithPlayers,
  getAuctionDetails,
  getUserEnrichedAuctions,
  getAuctionTeams,
} = require("../controllers/auction.controller");

// Create a new auction
router.post("/", createAuction);

// Get all auctions
router.get("/", getAllAuctions);

// Get auction by ID
router.get("/:id", getAuctionById);

// NEW - Get auctions that user has participated in

router.post("/manual-update", startAuctionmanualUpdate);
router.post("/:id/start", startAuctionManually);
router.post("/:id/stop", stopAuction);
router.post("/:id/reset", resetAuction);
router.get("/:id/status", getAuctionStatus);
router.get("/:auctionId/stats", getAuctionStats);
router.get("/:auctionId/history", getAuctionHistory);

// Get auction details including rules and scoring
router.get("/:id/details", getAuctionDetails);

// Update auction
router.put("/:id", updateAuction);

// Delete auction
router.delete("/:id", deleteAuction);

// Bulk delete auctions
router.post("/bulk-delete", bulkDeleteAuctions);

// Get auctions by status
router.get("/status/:status", getAuctionsByStatus);

// Add player to auction
router.post("/:auctionId/players/:playerId", addPlayerToAuction);

// Remove player from auction
router.delete("/:auctionId/players/:playerId", removePlayerFromAuction);

router.get("/:auctionId/user/:userId/budget", getUserBudget);
router.get("/:auctionId/user/:userId/team", getUserTeam);
router.get("/:auctionId/all-budgets", getAllUserBudgets);
router.get("/:auctionId/stats", getAuctionStats);
router.get("/:auctionId/history", getAuctionHistory);
router.put("/:auctionId/user/:userId/budget", updateUserBudget);
router.get("/:auctionId/player/:playerId/bids", getbidofeachplayer);
router.get("/:auctionId/teams-summary", getteamsummary);
router.post("/:auctionId/join", joinAuction);
router.post("/:auctionId/leave", leaveAuction);
router.get("/user-auctions/enriched/:userId", getUserEnrichedAuctions);

router.get("/:auctionId/participants", getAuctionParticipants);
router.get("/user/:userId/participated", getUserParticipatedAuctions);
router.get(
  "/:auctionId/participants-with-players",
  getAuctionParticipantsWithPlayers
);

// Get all teams in an auction with player details
router.get("/:auctionId/teams", getAuctionTeams);

// Get user participated auctions
router.get("/user/:userId/participated", getUserParticipatedAuctions);
router.get(
  "/:auctionId/participants-with-players",
  getAuctionParticipantsWithPlayers
);

module.exports = router;
