const User = require("../models/user.model");
const UserLeaderboard = require("../models/userLeaderboard.model");

const getAuctionLeaderboard = async (req, res) => {
  try {
    const { auctionId } = req.params;

    if (!auctionId) {
      return res.status(400).json({
        success: false,
        message: "Auction ID is required",
      });
    }

    const leaderboard = await UserLeaderboard.findAll({
      where: {
        auctionId: auctionId,
      },
      include: [
        {
          model: User,
          as: "User", // Make sure this alias matches your model association
          attributes: ["id", "name", "email", "profilepic"], // Include the fields you need
        },
      ],
      order: [["rank", "ASC"]],
      raw: false,
    });
    // In your formattedLeaderboard mapping function, add:
    const formattedLeaderboard = leaderboard.map((entry) => {
      let playerDetails = [];
      try {
        playerDetails =
          typeof entry.playerDetails === "string"
            ? JSON.parse(entry.playerDetails)
            : entry.playerDetails || [];
      } catch (error) {
        console.error("Error parsing playerDetails:", error);
        playerDetails = [];
      }

      // Calculate remaining budget (assuming initial budget is stored somewhere)
      // You might need to get this from auction settings or user auction data
      const initialBudget = 1000000; // Replace with actual initial budget
      const remainingBudget = initialBudget - (entry.totalSpent || 0);

      return {
        id: entry.id,
        userId: entry.userId,
        auctionId: entry.auctionId,
        playerGroup: entry.playerGroup,
        totalPoints: entry.totalPoints,
        playersCount: entry.playersCount,
        totalSpent: entry.totalSpent,
        remainingBudget: remainingBudget, // Add this
        rank: entry.rank,
        playerDetails: playerDetails,
        lastUpdated: entry.lastUpdated,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        User: entry.User, // This will now be included from the association
      };
    });

    res.status(200).json({
      success: true,
      data: formattedLeaderboard,
      message: "Leaderboard fetched successfully",
    });
  } catch (error) {
    console.error("Error fetching auction leaderboard:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: error.message,
    });
  }
};

const getAllLeaderboards = async (req, res) => {
  try {
    const leaderboards = await UserLeaderboard.findAll({
      order: [
        ["auctionId", "ASC"],
        ["rank", "ASC"],
      ],
      raw: false,
    });

    const formattedLeaderboards = leaderboards.map((entry) => {
      let playerDetails = [];
      try {
        playerDetails =
          typeof entry.playerDetails === "string"
            ? JSON.parse(entry.playerDetails)
            : entry.playerDetails || [];
      } catch (error) {
        console.error("Error parsing playerDetails:", error);
        playerDetails = [];
      }

      return {
        id: entry.id,
        userId: entry.userId,
        auctionId: entry.auctionId,
        playerGroup: entry.playerGroup,
        totalPoints: entry.totalPoints,
        playersCount: entry.playersCount,
        totalSpent: entry.totalSpent,
        rank: entry.rank,
        playerDetails: playerDetails,
        lastUpdated: entry.lastUpdated,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      };
    });

    res.status(200).json({
      success: true,
      data: formattedLeaderboards,
      message: "All leaderboards fetched successfully",
    });
  } catch (error) {
    console.error("Error fetching all leaderboards:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: error.message,
    });
  }
};

module.exports = {
  getAuctionLeaderboard,
  getAllLeaderboards,
};
