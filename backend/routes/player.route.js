const express = require("express");
const router = express.Router();
const multer = require("multer");
const upload = multer({ storage: multer.memoryStorage() });

const {
  createPlayer,
  getAllPlayers,
  getPlayerById,
  updatePlayer,
  deletePlayer,
  getPlayersByRole,
  bulkUploadPlayers,
  getPlayersByTeam,
  getPlayersByCategory,
  getPlayerGroups,
  getPlayerGroupsWithAuctions,
  getPlayersByGroup,
  getAllPlayerGroupsForAdmin,
  togglePlayerGroupStatus,
  getAllPlayerGroupsForAdminActive,
  syncPlayerGroups,
} = require("../controllers/player.controller");

router.post("/bulk-upload", upload.single("file"), bulkUploadPlayers);

router.get("/category/:category", getPlayersByCategory);
router.get("/groups", getPlayerGroups);
router.get("/groups-admin-isActive", getAllPlayerGroupsForAdminActive);
router.get("/groups-with-auctions", getPlayerGroupsWithAuctions);
router.get("/groups-admin", getAllPlayerGroupsForAdmin);

router.post("/groups/sync", syncPlayerGroups);
router.put("/groups/:groupName/toggle", togglePlayerGroupStatus);
router.get("/group/:groupName", getPlayersByGroup);
// Create a new player
router.post("/", createPlayer);

// Get all players
router.get("/", getAllPlayers);

// Get players by role
router.get("/role/:role", getPlayersByRole);

// Get players by team
router.get("/team/:team", getPlayersByTeam);
// Get player by ID
router.get("/:id", getPlayerById);

// Update player
router.put("/:id", updatePlayer);

// Delete player
router.delete("/:id", deletePlayer);

module.exports = router;
