const xlsx = require("xlsx");
const Player = require("../models/player.model");
const PlayerPoints = require("../models/playerspoint.model");
const UserLeaderboard = require("../models/userLeaderboard.model");
const AuctionPlayers = require("../models/auctionPlayers.model");
const Auction = require("../models/auction.model");
const User = require("../models/user.model");
const { Op } = require("sequelize");
const { sequelize } = require("../config/database");
const AuctionResult = require("../models/auctionresult.model");

// Scoring rules for different sports
const SCORING_RULES = {
  cricket: {
    runs: 1,
    wickets: 2,
    catches: 1.5,
    stumpings: 2,
    runouts: 1.5,
  },
  football: {
    goals: 4,
    assists: 2,
    saves: 1,
    cleansheets: 3,
    yellowcards: -0.5,
    redcards: -2,
  },
  basketball: {
    points: 1,
    rebounds: 1.2,
    assists: 1.5,
    steals: 2,
    blocks: 2,
  },
};

// Get all player groups with their associated auctions
const getPlayerGroupsWithAuctions = async (req, res) => {
  try {
    const playerGroupsData = await sequelize.query(
      `
      SELECT 
        p.playerGroup,
        p.category,
        COUNT(DISTINCT p.id) as playerCount,
        COUNT(DISTINCT ap.auctionId) as auctionCount,
        GROUP_CONCAT(DISTINCT ap.auctionId) as auctionIds
      FROM Players p
      LEFT JOIN AuctionPlayers ap ON p.id = ap.playerId
      WHERE p.playerGroup IS NOT NULL 
        AND p.isActive = true
      GROUP BY p.playerGroup, p.category
      ORDER BY p.playerGroup ASC
      `,
      {
        type: sequelize.QueryTypes.SELECT,
      }
    );

    // Get auction details for each group
    const enrichedData = await Promise.all(
      playerGroupsData.map(async (group) => {
        const auctionIds = group.auctionIds
          ? group.auctionIds.split(",").map((id) => parseInt(id))
          : [];

        const auctions = await Auction.findAll({
          where: { id: { [Op.in]: auctionIds } },
          attributes: ["id", "name", "status", "category", "type"],
        });

        return {
          ...group,
          auctions: auctions,
        };
      })
    );

    res.status(200).json({
      success: true,
      message: "Player groups with auctions retrieved successfully",
      data: enrichedData,
    });
  } catch (error) {
    console.error("Error fetching player groups:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching player groups",
      error: error.message,
    });
  }
};

// Bulk upload player points from Excel
const bulkUploadPlayerPoints = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "Excel file is required",
      });
    }

    const { playerGroup } = req.body;

    if (!playerGroup) {
      return res.status(400).json({
        success: false,
        message: "Player group is required",
      });
    }

    // Get all players in this group
    const playersInGroup = await Player.findAll({
      where: {
        playerGroup,
        isActive: true,
      },
    });

    if (playersInGroup.length === 0) {
      return res.status(400).json({
        success: false,
        message: `No players found in group: ${playerGroup}`,
      });
    }

    const category = playersInGroup[0].category;
    // Dynamic per-auction scoring: we'll store raw stats (runs, wickets) here.
    // Weighted points will be computed per auction using Auction.runPoint and Auction.wicketPoint.

    // Parse Excel file
    const workbook = xlsx.read(req.file.buffer, { type: "buffer" });
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const newrow = xlsx.utils.sheet_to_json(worksheet, { header: 1 });
    const filteredRows = newrow
      .slice(1)
      .filter((row) =>
        row.some((cell) => cell !== null && cell !== undefined && cell !== "")
      );

    // Then prepend headers back
    const rows = [newrow[0], ...filteredRows];

    if (rows.length < 2) {
      return res.status(400).json({
        success: false,
        message: "Excel file doesn't have enough data",
      });
    }

    const headers = rows[0].map((h) => h?.toString().toLowerCase().trim());
    const pointsToUpdate = [];
    const errors = [];

    // Find name column - Enhanced to handle more variations
    const nameIndex = headers.findIndex((h) => {
      const normalizedHeader = h.toLowerCase().trim().replace(/\s+/g, "");
      return (
        normalizedHeader === "name" ||
        normalizedHeader === "playername" ||
        normalizedHeader === "player_name" ||
        h.toLowerCase().includes("name")
      );
    });

    if (nameIndex === -1) {
      return res.status(400).json({
        success: false,
        message:
          "Name column not found in Excel file. Expected columns: 'name', 'player name', 'playername', or 'player_name'",
      });
    }

    // Process each row
    for (let i = 1; i < rows.length; i++) {
      const row = rows[i];
      console.log("player=====", row);
      const playerName = row[nameIndex]?.toString().trim();
      console.log("playername", playerName);
      if (!playerName) {
        errors.push({
          row: i + 1,
          error: "Player name is missing",
        });
        continue;
      }

      try {
        // Find player in the group - Enhanced matching
        const player = playersInGroup.find(
          (p) =>
            p.name.toLowerCase().trim() === playerName.toLowerCase().trim() ||
            p.name.toLowerCase().includes(playerName.toLowerCase()) ||
            playerName.toLowerCase().includes(p.name.toLowerCase())
        );

        if (!player) {
          errors.push({
            row: i + 1,
            error: `Player not found: ${playerName}`,
          });
          continue;
        }

        // Extract only raw stats: runs and wickets. Weighted points are applied per auction.
        const stats = {};
        const pointsBreakdown = {};
        let totalPoints = 0;

        for (let j = 0; j < headers.length; j++) {
          if (j === nameIndex) continue;

          const header = headers[j] ? headers[j].toString().toLowerCase().trim().replace(/\s+/g, "") : "";
          const value = parseFloat(row[j]) || 0;

          if (header === "runs" || header === "run") {
            stats.runs = value;
            pointsBreakdown.runs = value; // raw
            totalPoints += value;
          } else if (header === "wickets" || header === "wicket") {
            stats.wickets = value;
            pointsBreakdown.wickets = value; // raw
            totalPoints += value;
          }
        }

        pointsBreakdown.totalRaw = totalPoints;

        pointsToUpdate.push({
          playerId: player.id,
          playerGroup,
          category,
          stats,
          totalPoints,
          pointsBreakdown,
          lastUpdated: new Date(),
        });
      } catch (error) {
        errors.push({
          row: i + 1,
          error: error.message,
        });
      }
    }

    // Bulk upsert player points
    let updatedCount = 0;
    if (pointsToUpdate.length > 0) {
      for (const pointData of pointsToUpdate) {
        await PlayerPoints.upsert(pointData, {
          conflictFields: ["playerId", "playerGroup"],
        });
        updatedCount++;
      }

      // Update leaderboard for all auctions in this player group
      await updateAllLeaderboardsForPlayerGroup(playerGroup);
    }

    res.status(200).json({
      success: true,
      message: `Points updated successfully. ${updatedCount} players updated.`,
      data: {
        updated: updatedCount,
        errors: errors.length,
        errorDetails: errors,
        playerGroup,
        category,
        scoringMode: "dynamic_per_auction_runs_wickets",
      },
    });
  } catch (error) {
    console.error("Bulk upload points error:", error);
    res.status(500).json({
      success: false,
      message: "Error in bulk upload points",
      error: error.message,
    });
  }
};

// Update leaderboards for all auctions in a player group
async function updateAllLeaderboardsForPlayerGroup(playerGroup) {
  try {
    console.log(`🔄 Updating leaderboards for player group: ${playerGroup}`);

    // Get all auctions that have players from this group - FIXED for MySQL
    const auctionsWithPlayers = await sequelize.query(
      `
      SELECT DISTINCT ap.auctionId, a.name as auctionName, a.category
      FROM AuctionPlayers ap
      JOIN Players p ON ap.playerId = p.id
      JOIN Auctions a ON ap.auctionId = a.id
      WHERE p.playerGroup = :playerGroup
        AND p.isActive = true
      `,
      {
        replacements: { playerGroup },
        type: sequelize.QueryTypes.SELECT,
      }
    );

    console.log(
      `Found ${auctionsWithPlayers.length} auctions for player group: ${playerGroup}`
    );

    // Update leaderboard for each auction
    for (const auction of auctionsWithPlayers) {
      await updateLeaderboardForSpecificAuction(auction.auctionId, playerGroup);
    }

    console.log(
      `✅ Updated leaderboards for all auctions in player group: ${playerGroup}`
    );
  } catch (error) {
    console.error("Error updating leaderboards for player group:", error);
    throw error;
  }
}

// Update leaderboard for a specific auction
async function updateLeaderboardForSpecificAuction(auctionId, playerGroup) {
  const transaction = await sequelize.transaction();

  try {
    console.log(
      `🔄 Updating leaderboard for auction: ${auctionId}, player group: ${playerGroup}`
    );

    // Step 1: Get all players from this group that were part of this auction - FIXED for MySQL
    const auctionPlayersData = await sequelize.query(
      `
      SELECT DISTINCT 
        ap.playerId,
        ap.auctionId,
        p.name as playerName,
        p.playerGroup,
        p.category
      FROM AuctionPlayers ap
      JOIN Players p ON ap.playerId = p.id
      WHERE ap.auctionId = :auctionId 
        AND p.playerGroup = :playerGroup
        AND p.isActive = true
      `,
      {
        replacements: { auctionId, playerGroup },
        type: sequelize.QueryTypes.SELECT,
        transaction,
      }
    );

    if (auctionPlayersData.length === 0) {
      console.log(
        `No players found for auction ${auctionId} in group ${playerGroup}`
      );
      await transaction.commit();
      return;
    }

    const playerIds = auctionPlayersData.map((p) => p.playerId);

    // Fetch auction scoring rules (dynamic)
    const auction = await Auction.findByPk(auctionId, { transaction });
    const runPoint = auction?.runPoint ?? 1;
    const wicketPoint = auction?.wicketPoint ?? 10;

    // Step 2: Get auction results for these specific players in this auction
    const auctionResults = await AuctionResult.findAll({
      where: {
        auctionId: auctionId,
        playerId: { [Op.in]: playerIds },
        winnerId: { [Op.not]: null },
        status: "sold",
      },
      transaction,
    });

    // Step 3: Get player points for these players
    const playerPoints = await PlayerPoints.findAll({
      where: {
        playerId: { [Op.in]: playerIds },
        playerGroup,
      },
      include: [
        {
          model: Player,
          attributes: ["name", "basePrice"],
        },
      ],
      transaction,
    });

    // Create a map for quick lookup
    const pointsMap = new Map();
    playerPoints.forEach((pp) => {
      pointsMap.set(pp.playerId, pp);
    });

    // Step 4: Group by user for this specific auction
    const userDataMap = new Map();

    for (const result of auctionResults) {
      const userId = result.winnerId;

      if (!userDataMap.has(userId)) {
        userDataMap.set(userId, {
          userId: userId,
          auctionId: auctionId,
          totalPoints: 0,
          playersCount: 0,
          totalSpent: 0,
          playerDetails: [],
        });
      }

      const userData = userDataMap.get(userId);
      const playerPoint = pointsMap.get(result.playerId);

      if (playerPoint) {
        const stats = playerPoint.stats || {};
        const runs = Number(stats.runs || 0);
        const wickets = Number(stats.wickets || 0);
        const computedPoints = runs * runPoint + wickets * wicketPoint;

        userData.totalPoints += computedPoints;
        userData.playersCount += 1;
        userData.totalSpent += result.finalBid || 0;
        userData.playerDetails.push({
          playerId: result.playerId,
          playerName: playerPoint.Player?.name,
          points: computedPoints,
          purchasePrice: result.finalBid,
          stats: stats,
          pointsBreakdown: {
            runs: runs * runPoint,
            wickets: wickets * wicketPoint,
            runPoint,
            wicketPoint,
            total: computedPoints,
            raw: { runs, wickets },
          },
        });
      }
    }

    // Step 5: Update leaderboard entries for this auction
    for (const [userId, userData] of userDataMap) {
      await UserLeaderboard.upsert(
        {
          userId: userData.userId,
          auctionId: userData.auctionId,
          playerGroup,
          totalPoints: userData.totalPoints,
          playersCount: userData.playersCount,
          totalSpent: userData.totalSpent,
          playerDetails: userData.playerDetails,
          lastUpdated: new Date(),
        },
        {
          conflictFields: ["userId", "auctionId", "playerGroup"],
          transaction,
        }
      );
    }

    // Step 6: Update ranks for this specific auction
    const leaderboardEntries = await UserLeaderboard.findAll({
      where: {
        auctionId: auctionId,
        playerGroup,
      },
      order: [["totalPoints", "DESC"]],
      transaction,
    });

    for (let i = 0; i < leaderboardEntries.length; i++) {
      await leaderboardEntries[i].update({ rank: i + 1 }, { transaction });
    }

    await transaction.commit();
    console.log(
      `✅ Updated leaderboard for auction ${auctionId}, player group ${playerGroup}`
    );
  } catch (error) {
    await transaction.rollback();
    console.error(
      `Error updating leaderboard for auction ${auctionId}:`,
      error
    );
    throw error;
  }
}

// Get leaderboard for a specific auction and player group
// Get leaderboard for a specific auction and player group
const getLeaderboard = async (req, res) => {
  try {
    const { auctionId, playerGroup } = req.params;
    const { page = 1, limit = 20 } = req.query;

    const offset = (page - 1) * limit;

    const leaderboard = await UserLeaderboard.findAndCountAll({
      where: {
        auctionId,
        playerGroup,
      },
      include: [
        {
          model: User,
          attributes: ["id", "name", "email"],
        },
      ],
      order: [["rank", "ASC"]],
      limit: parseInt(limit),
      offset: offset,
    });

    // Get auction details
    const auction = await Auction.findByPk(auctionId, {
      attributes: ["id", "name", "category", "status"],
    });

    res.status(200).json({
      success: true,
      message: "Leaderboard retrieved successfully",
      data: {
        auction,
        playerGroup,
        leaderboard: leaderboard.rows,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(leaderboard.count / limit),
          totalEntries: leaderboard.count,
          hasNext: offset + limit < leaderboard.count,
          hasPrev: page > 1,
        },
      },
    });
  } catch (error) {
    console.error("Error fetching leaderboard:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching leaderboard",
      error: error.message,
    });
  }
};

// Get all leaderboards for a player group (across all auctions)
const getAllLeaderboardsForPlayerGroup = async (req, res) => {
  try {
    const { playerGroup } = req.params;

    const leaderboards = await UserLeaderboard.findAll({
      where: { playerGroup },
      include: [
        {
          model: User,
          attributes: ["id", "name", "email"],
        },
        {
          model: Auction,
          attributes: ["id", "name", "category", "status"],
        },
      ],
      order: [
        ["auctionId", "ASC"],
        ["rank", "ASC"],
      ],
    });

    // Group by auction
    const groupedLeaderboards = leaderboards.reduce((acc, entry) => {
      const auctionId = entry.auctionId;
      if (!acc[auctionId]) {
        acc[auctionId] = {
          auction: entry.Auction,
          entries: [],
        };
      }
      acc[auctionId].entries.push(entry);
      return acc;
    }, {});

    res.status(200).json({
      success: true,
      message: "All leaderboards retrieved successfully",
      data: {
        playerGroup,
        leaderboards: groupedLeaderboards,
      },
    });
  } catch (error) {
    console.error("Error fetching all leaderboards:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching all leaderboards",
      error: error.message,
    });
  }
};

// Get player points for a specific player group
const getPlayerPoints = async (req, res) => {
  try {
    const { playerGroup } = req.params;
    const { page = 1, limit = 50 } = req.query;

    const offset = (page - 1) * limit;

    const playerPoints = await PlayerPoints.findAndCountAll({
      where: { playerGroup },
      include: [
        {
          model: Player,
          attributes: ["id", "name", "basePrice", "team", "category", "type"],
        },
      ],
      order: [["totalPoints", "DESC"]],
      limit: parseInt(limit),
      offset: offset,
    });

    res.status(200).json({
      success: true,
      message: "Player points retrieved successfully",
      data: {
        playerGroup,
        players: playerPoints.rows,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(playerPoints.count / limit),
          totalPlayers: playerPoints.count,
          hasNext: offset + limit < playerPoints.count,
          hasPrev: page > 1,
        },
      },
    });
  } catch (error) {
    console.error("Error fetching player points:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching player points",
      error: error.message,
    });
  }
};

// Get scoring rules for all categories
const getScoringRules = async (req, res) => {
  try {
    res.status(200).json({
      success: true,
      message: "Scoring rules retrieved successfully",
      data: SCORING_RULES,
    });
  } catch (error) {
    console.error("Error fetching scoring rules:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching scoring rules",
      error: error.message,
    });
  }
};

// Manual trigger to update leaderboard for specific auction
const triggerLeaderboardUpdate = async (req, res) => {
  try {
    const { auctionId, playerGroup } = req.body;

    if (!auctionId || !playerGroup) {
      return res.status(400).json({
        success: false,
        message: "Auction ID and player group are required",
      });
    }

    await updateLeaderboardForSpecificAuction(auctionId, playerGroup);

    res.status(200).json({
      success: true,
      message: "Leaderboard updated successfully",
      data: { auctionId, playerGroup },
    });
  } catch (error) {
    console.error("Error updating leaderboard:", error);
    res.status(500).json({
      success: false,
      message: "Error updating leaderboard",
      error: error.message,
    });
  }
};

// Get user's performance across all auctions in a player group
const getUserPerformance = async (req, res) => {
  try {
    const { userId, playerGroup } = req.params;

    const userPerformance = await UserLeaderboard.findAll({
      where: {
        userId,
        playerGroup,
      },
      include: [
        {
          model: Auction,
          attributes: ["id", "name", "category", "status"],
        },
      ],
      order: [["totalPoints", "DESC"]],
    });

    // Calculate overall stats
    const overallStats = userPerformance.reduce(
      (acc, entry) => {
        acc.totalPoints += entry.totalPoints;
        acc.totalPlayersOwned += entry.playersCount;
        acc.totalSpent += entry.totalSpent;
        acc.auctionsParticipated += 1;
        return acc;
      },
      {
        totalPoints: 0,
        totalPlayersOwned: 0,
        totalSpent: 0,
        auctionsParticipated: 0,
      }
    );

    res.status(200).json({
      success: true,
      message: "User performance retrieved successfully",
      data: {
        userId,
        playerGroup,
        overallStats,
        auctionPerformance: userPerformance,
      },
    });
  } catch (error) {
    console.error("Error fetching user performance:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching user performance",
      error: error.message,
    });
  }
};

// Get detailed stats for a specific player
const getPlayerDetailedStats = async (req, res) => {
  try {
    const { playerId, playerGroup } = req.params;

    const playerStats = await PlayerPoints.findOne({
      where: {
        playerId,
        playerGroup,
      },
      include: [
        {
          model: Player,
          attributes: [
            "id",
            "name",
            "basePrice",
            "team",
            "category",
            "type",
            "imageurl",
          ],
        },
      ],
    });

    if (!playerStats) {
      return res.status(404).json({
        success: false,
        message: "Player stats not found",
      });
    }

    // Get auction results for this player
    const auctionResults = await AuctionResult.findAll({
      where: {
        playerId,
        status: "sold",
      },
      include: [
        {
          model: Auction,
          attributes: ["id", "name", "category", "status"],
        },
      ],
    });

    res.status(200).json({
      success: true,
      message: "Player detailed stats retrieved successfully",
      data: {
        playerStats,
        auctionHistory: auctionResults,
      },
    });
  } catch (error) {
    console.error("Error fetching player detailed stats:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching player detailed stats",
      error: error.message,
    });
  }
};

// Get top performers for a player group
const getTopPerformers = async (req, res) => {
  try {
    const { playerGroup } = req.params;
    const { limit = 10 } = req.query;

    const topPerformers = await PlayerPoints.findAll({
      where: { playerGroup },
      include: [
        {
          model: Player,
          attributes: [
            "id",
            "name",
            "basePrice",
            "team",
            "category",
            "type",
            "imageurl",
          ],
        },
      ],
      order: [["totalPoints", "DESC"]],
      limit: parseInt(limit),
    });

    res.status(200).json({
      success: true,
      message: "Top performers retrieved successfully",
      data: {
        playerGroup,
        topPerformers,
      },
    });
  } catch (error) {
    console.error("Error fetching top performers:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching top performers",
      error: error.message,
    });
  }
};

// Get statistics summary for a player group
const getPlayerGroupSummary = async (req, res) => {
  try {
    const { playerGroup } = req.params;

    // Get basic stats
    const summary = await sequelize.query(
      `
      SELECT 
        COUNT(DISTINCT pp.playerId) as totalPlayers,
        AVG(pp.totalPoints) as averagePoints,
        MAX(pp.totalPoints) as highestPoints,
        MIN(pp.totalPoints) as lowestPoints,
        SUM(pp.totalPoints) as totalPoints,
        p.category
      FROM PlayerPoints pp
      JOIN Players p ON pp.playerId = p.id
      WHERE pp.playerGroup = :playerGroup
      GROUP BY p.category
      `,
      {
        replacements: { playerGroup },
        type: sequelize.QueryTypes.SELECT,
      }
    );

    // Get auction participation stats
    const auctionStats = await sequelize.query(
      `
      SELECT 
        COUNT(DISTINCT ap.auctionId) as totalAuctions,
        COUNT(DISTINCT ar.winnerId) as totalBuyers,
        AVG(ar.finalBid) as averageBid,
        SUM(ar.finalBid) as totalSpent
      FROM AuctionPlayers ap
      JOIN Players p ON ap.playerId = p.id
      LEFT JOIN AuctionResults ar ON ap.playerId = ar.playerId AND ar.status = 'sold'
      WHERE p.playerGroup = :playerGroup
      `,
      {
        replacements: { playerGroup },
        type: sequelize.QueryTypes.SELECT,
      }
    );

    res.status(200).json({
      success: true,
      message: "Player group summary retrieved successfully",
      data: {
        playerGroup,
        summary: summary[0] || {},
        auctionStats: auctionStats[0] || {},
      },
    });
  } catch (error) {
    console.error("Error fetching player group summary:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching player group summary",
      error: error.message,
    });
  }
};

// Export all functions
module.exports = {
  getPlayerGroupsWithAuctions,
  bulkUploadPlayerPoints,
  getLeaderboard,
  getAllLeaderboardsForPlayerGroup,
  getPlayerPoints,
  getScoringRules,
  triggerLeaderboardUpdate,
  getUserPerformance,
  getPlayerDetailedStats,
  getTopPerformers,
  getPlayerGroupSummary,
};
