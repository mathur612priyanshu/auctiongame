const { sequelize } = require("../config/database");
const { Op } = require("sequelize");
const { getRedisClient } = require("../config/redis");
const { manualUpdate } = require("../crons/auctionlivestatus");
const Auction = require("../models/auction.model");
const AuctionParticipants = require("../models/auctionParticipants.model");
const AuctionPlayers = require("../models/auctionPlayers.model");
const AuctionResult = require("../models/auctionresult.model");
const BidHistory = require("../models/bidHistory.model");
const Player = require("../models/player.model");
const User = require("../models/user.model");
const UserAuctionBudget = require("../models/userAuctionBudget.model");
const UserLeaderboard = require("../models/userLeaderboard.model");
const { scheduleAuctionStart } = require("../queuejobs/auctionstart.queue");
// Create a new auction
const createAuction = async (req, res) => {
  try {
    const {
      name,
      category,
      type,
      minPlayers,
      startTime,
      selectedPlayers,
      runPoint = 1,
      wicketPoint = 10,
      maxPlayerAllowed,
      entryAmount,
      captain,
      vicecaptain,
      countedPlayers,
    } = req.body;

    if (!name || !category || !minPlayers) {
      return res.status(400).json({
        success: false,
        message: "Name, category, and minPlayers are required",
      });
    }

    // 1. Create auction
    const auction = await Auction.create({
      name,
      category,
      minPlayers,
      startTime,
      runPoint: parseInt(runPoint) || 1,
      wicketPoint: parseInt(wicketPoint) || 10,
      maxPlayerAllowed: maxPlayerAllowed ? parseInt(maxPlayerAllowed) : null,
      entryAmount: entryAmount ? parseInt(entryAmount) : null,
      captainPoints: captain ? parseInt(captain) : null,
      viceCaptainPoints: vicecaptain ? parseInt(vicecaptain) : null,
      countedPlayers: countedPlayers ? parseInt(countedPlayers) : 0,
    });
    console.log(auction);
    await scheduleAuctionStart(auction); // <-- this is the key line

    // 2. Associate players if any are selected
    if (
      selectedPlayers &&
      Array.isArray(selectedPlayers) &&
      selectedPlayers.length > 0
    ) {
      await auction.setPlayers(selectedPlayers); // This creates rows in AuctionPlayers
    }

    res.status(201).json({
      success: true,
      message: "Auction created successfully",
      data: auction,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error creating auction",
      error: error.message,
    });
  }
};

// Get all auctions
const getAllAuctions = async (req, res) => {
  try {
    const {
      includeDetails = false,
      page = 1,
      limit = 10,
      search = "",
      category = "",
      type = "",
      sort = "latest", // latest | oldest
      paginated = "false", // maintain backward compatibility (default to old array response)
    } = req.query;

    const pageNum = Math.max(parseInt(page) || 1, 1);
    const pageSize = Math.min(Math.max(parseInt(limit) || 10, 1), 100);
    const offset = (pageNum - 1) * pageSize;

    // Build filters
    const where = {};
    if (search && String(search).trim().length > 0) {
      const s = String(search).trim();
      const orConds = [{ name: { [Op.like]: `%${s}%` } }];
      const idNum = Number(s);
      if (!Number.isNaN(idNum)) {
        orConds.push({ id: idNum });
      }
      where[Op.or] = orConds;
    }
    if (category && category !== "all") {
      where.category = category;
    }
    // If your Auction model has a `type` column, enable this filter
    if (
      type &&
      type !== "all" &&
      Auction.rawAttributes &&
      Auction.rawAttributes.type
    ) {
      where.type = type;
    }

    const orderDirection = sort === "oldest" ? "ASC" : "DESC";
    const baseOrder = [["startTime", orderDirection]];

    // Choose attributes when not including heavy relations
    const baseAttributes = [
      "id",
      "name",
      "status",
      "category",
      "startTime",
      "minPlayers",
    ];

    // Backward compatible mode: if paginated !== 'true', return the original array shape
    if (paginated !== "true") {
      let auctions;
      if (includeDetails === "true") {
        auctions = await Auction.findAll({
          include: [
            {
              model: Player,
              through: { attributes: [] },
              as: "players",
            },
          ],
          order: baseOrder,
        });
      } else {
        auctions = await Auction.findAll({
          attributes: baseAttributes,
          order: baseOrder,
        });
      }

      return res.status(200).json({
        success: true,
        message: "Auctions retrieved successfully",
        data: auctions,
      });
    }

    let result;
    if (includeDetails === "true") {
      result = await Auction.findAndCountAll({
        where,
        include: [
          {
            model: Player,
            through: { attributes: [] },
            as: "players",
          },
        ],
        distinct: true, // important when using include to get correct count
        order: baseOrder,
        offset,
        limit: pageSize,
      });
    } else {
      result = await Auction.findAndCountAll({
        where,
        attributes: baseAttributes,
        order: baseOrder,
        offset,
        limit: pageSize,
      });
    }

    const total = result.count;
    const totalPages = Math.max(Math.ceil(total / pageSize), 1);

    res.status(200).json({
      success: true,
      message: "Auctions retrieved successfully",
      data: {
        items: result.rows,
        pagination: {
          total,
          page: pageNum,
          limit: pageSize,
          totalPages,
          hasNext: pageNum < totalPages,
          hasPrev: pageNum > 1,
        },
      },
    });
  } catch (error) {
    console.log(error);
    res.status(500).json({
      success: false,
      message: "Error retrieving auctions",
      error: error.message,
    });
  }
};

// Get auction by ID
const getAuctionById = async (req, res) => {
  try {
    const { id } = req.params;
    const auction = await Auction.findByPk(id, {
      include: [
        {
          model: Player,
          through: { attributes: [] },
          as: "players",
        },
      ],
    });

    if (!auction) {
      return res.status(404).json({
        success: false,
        message: "Auction not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Auction retrieved successfully",
      data: auction,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving auction",
      error: error.message,
    });
  }
};

// Update auction (only when upcoming): allows editing core fields except player/group selection
const updateAuction = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      name,
      category,
      startTime,
      minPlayers,
      entryAmount,
      maxPlayerAllowed,
      captainPoints,
      viceCaptainPoints,
      runPoint,
      wicketPoint,
    } = req.body;

    const auction = await Auction.findByPk(id);

    if (!auction) {
      return res
        .status(404)
        .json({ success: false, message: "Auction not found" });
    }

    if (auction.status !== "upcoming") {
      return res.status(400).json({
        success: false,
        message: "Only upcoming auctions can be edited",
      });
    }

    // Build update payload with provided fields only
    const updatePayload = {};
    if (name !== undefined) updatePayload.name = name;
    if (category !== undefined) updatePayload.category = category;
    if (startTime !== undefined) updatePayload.startTime = startTime;
    if (minPlayers !== undefined)
      updatePayload.minPlayers = parseInt(minPlayers) || 0;
    if (entryAmount !== undefined)
      updatePayload.entryAmount = parseInt(entryAmount) || 0;
    if (maxPlayerAllowed !== undefined)
      updatePayload.maxPlayerAllowed = parseInt(maxPlayerAllowed) || null;
    if (captainPoints !== undefined)
      updatePayload.captainPoints = parseInt(captainPoints) || null;
    if (viceCaptainPoints !== undefined)
      updatePayload.viceCaptainPoints = parseInt(viceCaptainPoints) || null;
    if (runPoint !== undefined)
      updatePayload.runPoint = parseInt(runPoint) || 0;
    if (wicketPoint !== undefined)
      updatePayload.wicketPoint = parseInt(wicketPoint) || 0;

    await auction.update(updatePayload);

    res.status(200).json({
      success: true,
      message: "Auction updated successfully",
      data: auction,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error updating auction",
      error: error.message,
    });
  }
};

// Delete auction
const deleteAuction = async (req, res) => {
  try {
    const { id } = req.params;
    const auction = await Auction.findByPk(id);

    if (!auction) {
      return res.status(404).json({
        success: false,
        message: "Auction not found",
      });
    }

    await auction.destroy();

    res.status(200).json({
      success: true,
      message: "Auction deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error deleting auction",
      error: error.message,
    });
  }
};

// Get auctions by status
const getAuctionsByStatus = async (req, res) => {
  try {
    const { status } = req.params;
    const auctions = await Auction.findAll({
      where: { status },
      include: [
        {
          model: Player,
          through: { attributes: [] },
        },
      ],
    });

    res.status(200).json({
      success: true,
      message: `Auctions with status ${status} retrieved successfully`,
      data: auctions,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving auctions by status",
      error: error.message,
    });
  }
};

// Add player to auction
const addPlayerToAuction = async (req, res) => {
  try {
    const { auctionId, playerId } = req.params;

    const auction = await Auction.findByPk(auctionId);
    const player = await Player.findByPk(playerId);

    if (!auction) {
      return res.status(404).json({
        success: false,
        message: "Auction not found",
      });
    }

    if (!player) {
      return res.status(404).json({
        success: false,
        message: "Player not found",
      });
    }

    await auction.addPlayer(player);

    res.status(200).json({
      success: true,
      message: "Player added to auction successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error adding player to auction",
      error: error.message,
    });
  }
};

// Remove player from auction
const removePlayerFromAuction = async (req, res) => {
  try {
    const { auctionId, playerId } = req.params;

    const auction = await Auction.findByPk(auctionId);
    const player = await Player.findByPk(playerId);

    if (!auction) {
      return res.status(404).json({
        success: false,
        message: "Auction not found",
      });
    }

    if (!player) {
      return res.status(404).json({
        success: false,
        message: "Player not found",
      });
    }

    await auction.removePlayer(player);

    res.status(200).json({
      success: true,
      message: "Player removed from auction successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error removing player from auction",
      error: error.message,
    });
  }
};
const startAuctionmanualUpdate = async (req, res) => {
  try {
    await manualUpdate();
    res.json({
      success: true,
      message: "Auction statuses updated manually",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Failed to update auction statuses",
      error: error.message,
    });
  }
};
const startAuctionManually = async (req, res) => {
  const { id } = req.params;
  const { retryCount = 0 } = req.body;

  try {
    console.log(
      `🚀 Starting auction ${id} manually (attempt ${retryCount + 1})`
    );

    // Get auction details
    const auction = await Auction.findByPk(id, {
      include: [
        {
          model: Player,
          as: "players",
          through: { attributes: [] },
        },
      ],
    });

    if (!auction) {
      return res.status(404).json({
        success: false,
        message: "Auction not found",
      });
    }

    if (auction.status === "ongoing") {
      return res.status(400).json({
        success: false,
        message: "Auction is already ongoing",
        data: {
          status: auction.status,
          currentPlayerIndex: auction.currentPlayerIndex,
        },
      });
    }

    if (!auction.players || auction.players.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No players added to this auction",
      });
    }

    const redis = getRedisClient();
    // const io = getSocketIO();

    // Clear any existing auction data
    await redis.del(`auction:${id}:state`);
    await redis.del(`auction:${id}:current_player`);
    await redis.del(`auction:${id}:player_queue`);

    // Initialize player queue
    const shuffleArray = (array) => {
      for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [array[i], array[j]] = [array[j], array[i]];
      }
      return array;
    };

    let playerIds = auction.players.map((player) => player.id.toString());
    playerIds = shuffleArray(playerIds);
    if (playerIds.length > 0) {
      await redis.rPush(`auction:${id}:player_queue`, playerIds);
    }

    // Get first player
    const firstPlayerId = await redis.lPop(`auction:${id}:player_queue`);
    const firstPlayer = await Player.findByPk(firstPlayerId);

    if (!firstPlayer) {
      throw new Error("Failed to get first player");
    }

    // Create initial auction state
    const initialState = {
      currentPlayer: {
        id: firstPlayer.id,
        name: firstPlayer.name,
        basePrice: firstPlayer.basePrice,
        type: firstPlayer.type,
        team: firstPlayer.team,
        age: firstPlayer?.age,
        matches: firstPlayer.matches,
        runs: firstPlayer.runs,
        average: firstPlayer.average,
        strikeRate: firstPlayer.strikeRate,
        previousTeam: firstPlayer.previousTeam,
        previousPrice: firstPlayer.previousPrice,
        metadata: firstPlayer.metadata,
        image: firstPlayer.imageurl,
      },
      currentBid: firstPlayer.basePrice,
      highestBidder: "No bids yet",
      highestBidderId: null,
      timeRemaining: 12,
      startTime: new Date(),
      totalPlayers: auction.players.length,
      currentPlayerIndex: 1,
    };

    // Store in Redis
    await redis.set(`auction:${id}:state`, JSON.stringify(initialState));
    await redis.set(`auction:${id}:current_player`, firstPlayerId);

    // Update auction in database
    await auction.update({
      status: "ongoing",
      startTime: new Date(),
      currentPlayerIndex: 1,
      currentBid: firstPlayer.basePrice,
      highestBidder: "No bids yet",
      highestBidderId: null,
      timeRemaining: 12,
    });

    // Initialize auction in socket controller
    const auctionSocketController = require("../sockets/auction.socket");
    // if (io && io.auctionController) {
    //   await io.auctionController.initializeAuction(id, initialState);
    //   io.auctionController.resetAuctionTimer(id);
    // }

    // // Broadcast to all connected users
    // io.to(`auction_${id}`).emit("auctionStarted", {
    //   message: "Auction has started!",
    //   auctionId: id,
    //   currentPlayer: initialState.currentPlayer,
    //   timestamp: new Date(),
    // });

    console.log(`✅ Auction ${id} started successfully`);

    res.json({
      success: true,
      message: "Auction started successfully",
      data: {
        auctionId: id,
        status: "ongoing",
        currentPlayer: firstPlayer.name,
        totalPlayers: auction.players.length,
        startTime: new Date(),
      },
    });
  } catch (error) {
    console.error(`❌ Error starting auction ${id}:`, error);

    // Auto-retry logic (max 3 attempts)
    if (retryCount < 2) {
      console.log(`🔄 Retrying auction start (attempt ${retryCount + 2})`);

      setTimeout(async () => {
        try {
          await startAuctionManually(
            { ...req, body: { ...req.body, retryCount: retryCount + 1 } },
            res
          );
        } catch (retryError) {
          console.error(`❌ Retry failed:`, retryError);
        }
      }, 2000); // Wait 2 seconds before retry

      return;
    }

    res.status(500).json({
      success: false,
      message: "Failed to start auction after multiple attempts",
      error: error.message,
      retryCount: retryCount + 1,
    });
  }
};

// NEW: Stop auction
const stopAuction = async (req, res) => {
  const { id } = req.params;

  try {
    console.log(`🛑 Stopping auction ${id}`);

    const auction = await Auction.findByPk(id);
    if (!auction) {
      return res.status(404).json({
        success: false,
        message: "Auction not found",
      });
    }

    // Update auction status
    await auction.update({
      status: "upcoming", // Reset to upcoming
      currentBid: 0,
      highestBidder: null,
      highestBidderId: null,
      timeRemaining: 0,
    });

    const redis = getRedisClient();
    // const io = getSocketIO();

    // Clear Redis data
    await redis.del(`auction:${id}:state`);
    await redis.del(`auction:${id}:current_player`);

    // Notify all connected users
    // io.to(`auction_${id}`).emit("auctionStopped", {
    //   message: "Auction has been stopped by admin",
    //   auctionId: id,
    //   timestamp: new Date(),
    // });

    console.log(`✅ Auction ${id} stopped successfully`);

    res.json({
      success: true,
      message: "Auction stopped successfully",
      data: {
        auctionId: id,
        status: "upcoming",
      },
    });
  } catch (error) {
    console.error(`❌ Error stopping auction ${id}:`, error);
    res.status(500).json({
      success: false,
      message: "Failed to stop auction",
      error: error.message,
    });
  }
};

// NEW: Reset auction
const resetAuction = async (req, res) => {
  const { id } = req.params;

  try {
    console.log(`🔄 Resetting auction ${id}`);

    const auction = await Auction.findByPk(id);
    if (!auction) {
      return res.status(404).json({
        success: false,
        message: "Auction not found",
      });
    }

    // Reset auction to initial state
    await auction.update({
      status: "upcoming",
      currentPlayerIndex: 0,
      currentBid: 0,
      highestBidder: null,
      highestBidderId: null,
      timeRemaining: 30,
      startTime: null,
    });

    const redis = getRedisClient();
    // const io = getSocketIO();

    // Clear all Redis data for this auction
    const keys = await redis.keys(`auction:${id}:*`);
    if (keys.length > 0) {
      await redis.del(keys);
    }

    // Notify all connected users
    // io.to(`auction_${id}`).emit("auctionReset", {
    //   message: "Auction has been reset by admin",
    //   auctionId: id,
    //   timestamp: new Date(),
    // });

    console.log(`✅ Auction ${id} reset successfully`);

    res.json({
      success: true,
      message: "Auction reset successfully",
      data: {
        auctionId: id,
        status: "upcoming",
      },
    });
  } catch (error) {
    console.error(`❌ Error resetting auction ${id}:`, error);
    res.status(500).json({
      success: false,
      message: "Failed to reset auction",
      error: error.message,
    });
  }
};

// NEW: Get detailed auction status
const getAuctionStatus = async (req, res) => {
  const { id } = req.params;

  try {
    const auction = await Auction.findByPk(id, {
      include: [
        {
          model: Player,
          as: "players",
          through: { attributes: [] },
        },
      ],
    });

    if (!auction) {
      return res.status(404).json({
        success: false,
        message: "Auction not found",
      });
    }

    const redis = getRedisClient();

    // Get current state from Redis
    const stateStr = await redis.get(`auction:${id}:state`);
    const currentState = stateStr ? JSON.parse(stateStr) : null;

    // Get connected users
    const connectedUsers = await redis.sMembers(`auction:${id}:users`);
    const userCount = connectedUsers.length;

    // Get remaining players in queue
    const remainingPlayers = await redis.lLen(`auction:${id}:player_queue`);

    res.json({
      success: true,
      data: {
        auction: {
          id: auction.id,
          name: auction.name,
          status: auction.status,
          totalPlayers: auction.players?.length || 0,
          currentPlayerIndex: auction.currentPlayerIndex,
          startTime: auction.startTime,
        },
        currentState,
        connectedUsers: userCount,
        remainingPlayers,
        isActive: auction.status === "ongoing",
        canStart: auction.status === "upcoming" && auction.players?.length > 0,
      },
    });
  } catch (error) {
    console.error(`❌ Error getting auction status ${id}:`, error);
    res.status(500).json({
      success: false,
      message: "Failed to get auction status",
      error: error.message,
    });
  }
};

const getUserBudget = async (req, res) => {
  try {
    const { auctionId, userId } = req.params;

    let userBudget = await UserAuctionBudget.findOne({
      where: { userId, auctionId },
      include: [
        {
          model: User,
          as: "user",
          attributes: ["name", "email"],
        },
      ],
    });

    // Create initial budget if doesn't exist (when user joins auction)
    if (!userBudget) {
      userBudget = await UserAuctionBudget.create({
        userId,
        auctionId,
        totalBudget: 900000000, // 90 Cr default
        spentAmount: 0,
        playersCount: 0,
        isActive: true,
      });

      await userBudget.reload({
        include: [
          {
            model: User,
            as: "user",
            attributes: ["name", "email"],
          },
        ],
      });
    }

    res.json({
      success: true,
      data: {
        userId: userBudget.userId,
        userName: userBudget.user.name,
        totalBudget: userBudget.totalBudget,
        spentAmount: userBudget.spentAmount,
        remainingBudget: userBudget.totalBudget - userBudget.spentAmount,
        playersCount: userBudget.playersCount,
        maxPlayers: userBudget.maxPlayers,
        isActive: userBudget.isActive,
        totalBidsPlaced: userBudget.totalBidsPlaced,
        playersWon: userBudget.playersWon,
        lastBidAmount: userBudget.lastBidAmount,
      },
    });
  } catch (error) {
    console.error("Error fetching user budget:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Get user's team for specific auction
const getUserTeam = async (req, res) => {
  try {
    const { auctionId, userId } = req.params;

    // Get user's won players
    const wonPlayers = await AuctionResult.findAll({
      where: {
        auctionId,
        winnerId: userId,
        status: "sold",
      },
      include: [
        {
          model: Player,
          as: "player",
          attributes: ["id", "name", "type", "team", "imageurl", "matches"],
        },
      ],
      order: [["createdAt", "DESC"]],
    });

    // Get user's budget info
    const userBudget = await UserAuctionBudget.findOne({
      where: { userId, auctionId },
      include: [
        {
          model: User,
          as: "user",
          attributes: ["name"],
        },
      ],
    });

    const team = wonPlayers.map((item) => ({
      id: item.player?.id,
      name: item.player?.name,
      role: item.player?.type,
      price: item.finalBid,
      team: item.player?.team,
      image: item.player?.imageurl,
      age: item.player?.age,
      matches: item.player?.matches,
      runs: item.player?.runs,
      average: item.player?.average,
      strikeRate: item.player?.strikeRate,
      purchaseDate: item.createdAt,
    }));

    const budgetInfo = userBudget
      ? {
          totalBudget: userBudget.totalBudget,
          spentAmount: userBudget.spentAmount,
          remainingBudget: userBudget.totalBudget - userBudget.spentAmount,
          playersCount: userBudget.playersCount,
          isActive: userBudget.isActive,
          totalBidsPlaced: userBudget.totalBidsPlaced,
          playersWon: userBudget.playersWon,
        }
      : null;

    res.json({
      success: true,
      team,
      budgetInfo,
      userName: userBudget?.user?.name || "Unknown User",
    });
  } catch (error) {
    console.error("Error fetching user team:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch user team",
    });
  }
};

// Get all users' budgets for auction (bidders panel)
const getAllUserBudgets = async (req, res) => {
  try {
    const { auctionId } = req.params;

    const allBudgets = await UserAuctionBudget.findAll({
      where: { auctionId },
      include: [
        {
          model: User,
          as: "user",
          attributes: ["name", "email"],
        },
      ],
      order: [["spentAmount", "DESC"]], // Order by spent amount
    });

    const formattedBudgets = allBudgets.map((budget) => ({
      userId: budget.userId,
      userName: budget.user.name,
      totalBudget: budget.totalBudget,
      spentAmount: budget.spentAmount,
      remainingBudget: budget.totalBudget - budget.spentAmount,
      playersCount: budget.playersCount,
      isActive: budget.isActive && budget.totalBudget - budget.spentAmount > 0,
      totalBidsPlaced: budget.totalBidsPlaced,
      playersWon: budget.playersWon,
      joinedAt: budget.joinedAt,
    }));

    res.json({ success: true, data: formattedBudgets });
  } catch (error) {
    console.error("Error fetching all budgets:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Get auction statistics
const getAuctionStats = async (req, res) => {
  try {
    const { auctionId } = req.params;

    // Get all auction results
    const auctionResults = await AuctionResult.findAll({
      where: { auctionId },
      include: [
        {
          model: Player,
          as: "player",
          attributes: ["name", "basePrice", "type"],
        },
        {
          model: User,
          as: "winner",
          attributes: ["name"],
        },
      ],
    });

    const soldPlayers = auctionResults.filter((r) => r.status === "sold");
    const unsoldPlayers = auctionResults.filter((r) => r.status === "unsold");

    const totalSpent = soldPlayers.reduce((sum, r) => sum + r.finalBid, 0);
    const averagePrice =
      soldPlayers.length > 0 ? totalSpent / soldPlayers.length : 0;
    const highestSale =
      soldPlayers.length > 0
        ? Math.max(...soldPlayers.map((r) => r.finalBid))
        : 0;

    // Get total participants
    const totalParticipants = await UserAuctionBudget.count({
      where: { auctionId },
    });

    // Get total bids placed
    const totalBids = await BidHistory.count({
      where: { auctionId },
    });

    const stats = {
      totalPlayers: auctionResults.length,
      soldPlayers: soldPlayers.length,
      unsoldPlayers: unsoldPlayers.length,
      averagePrice: Math.round(averagePrice),
      highestSale,
      totalSpent,
      totalParticipants,
      totalBids,
    };

    res.json({ success: true, data: stats });
  } catch (error) {
    console.error("Error fetching auction stats:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// Get auction history
const getAuctionHistory = async (req, res) => {
  try {
    const { auctionId } = req.params;

    const history = await AuctionResult.findAll({
      where: { auctionId },
      include: [
        {
          model: Player,
          as: "player",
          attributes: ["id", "name", "type", "team", "imageurl"],
        },
      ],
      order: [["createdAt", "DESC"]],
    });

    const formattedHistory = history.map((item) => ({
      id: item.id,
      player: item.player?.name || "Unknown Player",
      playerId: item.playerId,
      playerImage: item.player?.imageurl,
      playerType: item.player?.type,
      team: item.winnerName || "Unsold",
      winnerId: item.winnerId,
      price: item.finalBid || 0,
      basePrice: item.basePrice || 0,
      status: item.status,
      totalBids: item.totalBids || 0,
      auctionStartTime: item.auctionStartTime,
      auctionEndTime: item.auctionEndTime,
    }));

    res.json({
      success: true,
      history: formattedHistory,
    });
  } catch (error) {
    console.error("Error fetching auction history:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch auction history",
    });
  }
};

// Update user budget (for manual adjustments if needed)
const updateUserBudget = async (req, res) => {
  try {
    const { auctionId, userId } = req.params;
    const { totalBudget, spentAmount, playersCount } = req.body;

    const userBudget = await UserAuctionBudget.findOne({
      where: { userId, auctionId },
    });

    if (!userBudget) {
      return res
        .status(404)
        .json({ success: false, message: "User budget not found" });
    }

    // Update fields if provided
    if (totalBudget !== undefined) userBudget.totalBudget = totalBudget;
    if (spentAmount !== undefined) userBudget.spentAmount = spentAmount;
    if (playersCount !== undefined) userBudget.playersCount = playersCount;

    // Update active status
    userBudget.isActive = userBudget.totalBudget - userBudget.spentAmount > 0;

    await userBudget.save();

    res.json({
      success: true,
      data: {
        userId: userBudget.userId,
        totalBudget: userBudget.totalBudget,
        spentAmount: userBudget.spentAmount,
        remainingBudget: userBudget.totalBudget - userBudget.spentAmount,
        playersCount: userBudget.playersCount,
        isActive: userBudget.isActive,
      },
    });
  } catch (error) {
    console.error("Error updating user budget:", error);
    res.status(500).json({ success: false, message: "Server error" });
  }
};
const getbidofeachplayer = async (req, res) => {
  try {
    const { auctionId, playerId } = req.params;
    const { limit = 20 } = req.query;

    const bids = await BidHistory.findAll({
      where: {
        auctionId,
        playerId,
      },
      order: [["timestamp", "DESC"]],
      limit: parseInt(limit),
    });

    const formattedBids = bids.map((bid) => ({
      id: bid.id,
      bidder: bid.bidderName,
      bidderId: bid.bidderId,
      amount: bid.amount,
      previousBid: bid.previousBid,
      timestamp: bid.timestamp,
      timeDiff: new Date() - new Date(bid.timestamp),
    }));

    res.json({
      success: true,
      bids: formattedBids,
      totalBids: bids.length,
    });
  } catch (error) {
    console.error("Error fetching player bids:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch player bids",
    });
  }
};
const getteamsummary = async (req, res) => {
  try {
    const { auctionId } = req.params;

    const userBudgets = await UserAuctionBudget.findAll({
      where: { auctionId },
      include: [
        {
          model: User,
          as: "user",
          attributes: ["id", "name"],
        },
      ],
    });

    const teamsSummary = await Promise.all(
      userBudgets.map(async (budget) => {
        const wonPlayers = await AuctionResult.findAll({
          where: {
            auctionId,
            winnerId: budget.userId,
            status: "sold",
          },
          include: [
            {
              model: Player,
              as: "player",
              attributes: ["name", "type"],
            },
          ],
        });

        return {
          userId: budget.userId,
          userName: budget.user?.name,
          totalBudget: budget.totalBudget,
          spentAmount: budget.spentAmount,
          remainingBudget: budget.totalBudget - budget.spentAmount,
          playersCount: budget.playersCount,
          isActive: budget.isActive,
          totalBidsPlaced: budget.totalBidsPlaced,
          playersWon: budget.playersWon,
          players: wonPlayers.map((p) => ({
            name: p.player?.name,
            type: p.player?.type,
            price: p.finalBid,
          })),
        };
      })
    );

    res.json({
      success: true,
      teams: teamsSummary,
    });
  } catch (error) {
    console.error("Error fetching teams summary:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch teams summary",
    });
  }
};
const joinAuction = async (req, res) => {
  try {
    const { auctionId } = req.params;
    const { userId } = req.body;

    // Check if auction exists
    const auction = await Auction.findByPk(auctionId);
    if (!auction) {
      return res.status(404).json({
        success: false,
        message: "Auction not found",
      });
    }

    // Enforce registration capacity strictly by minPlayers (acts as max slots)
    const capacity = auction.minPlayers || null;
    if (capacity) {
      const activeCount = await AuctionParticipants.count({
        where: { auctionId, status: "active" },
      });
      if (activeCount >= capacity) {
        return res.status(400).json({
          success: false,
          message: "Registration full for this auction",
          data: {
            capacity,
            booked: activeCount,
          },
        });
      }
    }

    // Check if user already joined
    const existingParticipant = await AuctionParticipants.findOne({
      where: { auctionId, userId },
    });

    if (existingParticipant) {
      return res.status(400).json({
        success: false,
        message: "User already joined this auction",
      });
    }

    // Add participant
    const participant = await AuctionParticipants.create({
      auctionId,
      userId,
      status: "active",
    });

    res.status(201).json({
      success: true,
      message: "Successfully joined auction",
      data: participant,
    });
  } catch (error) {
    console.error("Error joining auction:", error);
    res.status(500).json({
      success: false,
      message: "Error joining auction",
      error: error.message,
    });
  }
};

// Leave an auction
const leaveAuction = async (req, res) => {
  try {
    const { auctionId } = req.params;
    const { userId } = req.body;

    const participant = await AuctionParticipants.findOne({
      where: { auctionId, userId },
    });

    if (!participant) {
      return res.status(404).json({
        success: false,
        message: "User not found in this auction",
      });
    }

    // Update status instead of deleting (for audit trail)
    await participant.update({ status: "left" });

    res.status(200).json({
      success: true,
      message: "Successfully left auction",
    });
  } catch (error) {
    console.error("Error leaving auction:", error);
    res.status(500).json({
      success: false,
      message: "Error leaving auction",
      error: error.message,
    });
  }
};
// Get auction participants
const getAuctionParticipants = async (req, res) => {
  try {
    const { auctionId } = req.params;
    const { status = "active" } = req.query;

    const participants = await AuctionParticipants.findAll({
      where: {
        auctionId,
        status,
      },
      include: [
        {
          model: User,
          as: "user",
          attributes: ["id", "name", "email"],
        },
      ],
      order: [["joinedAt", "ASC"]],
    });

    const auction = await Auction.findByPk(auctionId, {
      attributes: ["id", "minPlayers"],
    });
    const capacity = (auction && auction.minPlayers) || null;

    res.status(200).json({
      success: true,
      message: "Auction participants retrieved successfully",
      data: {
        auctionId,
        participants, // This should be an array
        totalCount: participants.length,
        capacity,
      },
    });
  } catch (error) {
    console.error("Error fetching auction participants:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching auction participants",
      error: error.message,
    });
  }
};

// Get user participated auctions - FIXED VERSION
const getUserParticipatedAuctions = async (req, res) => {
  try {
    const { userId } = req.params;
    const { status = "active", page = 1, limit = 10 } = req.query;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required",
      });
    }

    const offset = (page - 1) * limit;

    const participatedAuctions = await Auction.findAndCountAll({
      include: [
        {
          model: AuctionParticipants,
          as: "auctionParticipants",
          where: {
            userId,
            status: status,
          },
          required: true,
          attributes: ["joinedAt", "status"],
        },
      ],
      order: [["createdAt", "DESC"]],
      limit: parseInt(limit),
      offset: offset,
      distinct: true,
    });

    // Make sure we return the data in the expected format
    res.status(200).json({
      success: true,
      message: "User participated auctions retrieved successfully",
      data: participatedAuctions.rows, // ✅ Return the array directly
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(participatedAuctions.count / limit),
        totalEntries: participatedAuctions.count,
        hasNext: offset + limit < participatedAuctions.count,
        hasPrev: page > 1,
      },
    });
  } catch (error) {
    console.error("Error fetching user participated auctions:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching user participated auctions",
      error: error.message,
    });
  }
};
// Get detailed auction information including rules and scoring
const getAuctionDetails = async (req, res) => {
  try {
    const { id } = req.params;

    const auction = await Auction.findByPk(id, {
      attributes: [
        "id",
        "name",
        "category",
        "minPlayers",
        "entryAmount",
        "runPoint",
        "wicketPoint",
        "captainPoints",
        "viceCaptainPoints",
        "startTime",
        "status",
        "countedPlayers",
      ],
    });

    if (!auction) {
      return res.status(404).json({
        success: false,
        message: "Auction not found",
      });
    }

    // Calculate total pool (20% reduction from total entry fees)
    const totalPool =
      auction.entryAmount && auction.minPlayers
        ? auction.entryAmount * auction.minPlayers * 0.8
        : 0;

    const participantsCount = await AuctionParticipants.count({
      where: { auctionId: id, status: "active" },
    });
    const capacity = auction.minPlayers || null;

    const response = {
      success: true,
      data: {
        ...auction.toJSON(),
        totalPool: Math.round(totalPool),
        participantsCount,
        capacity,
      },
    };

    res.status(200).json(response);
  } catch (error) {
    console.error("Error fetching auction details:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching auction details",
      error: error.message,
    });
  }
};

const getAuctionParticipantsWithPlayers = async (req, res) => {
  try {
    const { auctionId } = req.params;

    // Get all participants with correct alias 'user'
    const participants = await UserAuctionBudget.findAll({
      where: { auctionId },
      include: [
        {
          model: User,
          as: "user", // Added the correct alias
          attributes: ["id", "name", "email"],
        },
      ],
    });

    const participantsWithPlayers = await Promise.all(
      participants.map(async (participant) => {
        const wonPlayers = await AuctionResult.findAll({
          where: {
            auctionId,
            winnerId: participant.userId,
            status: "sold",
          },
          include: [
            {
              model: Player,
              as: "player",
              attributes: ["id", "name", "type", "team", "imageurl"],
            },
          ],
          order: [["createdAt", "DESC"]],
        });

        return {
          userId: participant.userId,
          userName: participant.user.name, // Updated to use correct alias
          totalBudget: participant.totalBudget,
          spentAmount: participant.spentAmount,
          remainingBudget: participant.totalBudget - participant.spentAmount,
          playersCount: wonPlayers.length,
          players: wonPlayers.map((item) => ({
            id: item.player?.id,
            name: item.player?.name,
            role: item.player?.type,
            price: item.finalBid,
            team: item.player?.team,
            image: item.player?.imageurl,
            purchaseDate: item.createdAt,
          })),
        };
      })
    );

    res.json({
      success: true,
      data: participantsWithPlayers,
    });
  } catch (error) {
    console.error("Error fetching participants with players:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch participants with players",
    });
  }
};

// Bulk delete multiple auctions
const bulkDeleteAuctions = async (req, res) => {
  const transaction = await sequelize.transaction();
  try {
    const { auctionIds } = req.body;

    if (!Array.isArray(auctionIds) || auctionIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: "Please provide an array of auction IDs to delete",
      });
    }

    // Delete related records first to maintain referential integrity
    await Promise.all([
      AuctionParticipants.destroy({
        where: { auctionId: auctionIds },
        transaction,
      }),
      AuctionPlayers.destroy({
        where: { auctionId: auctionIds },
        transaction,
      }),
      AuctionResult.destroy({
        where: { auctionId: auctionIds },
        transaction,
      }),
      BidHistory.destroy({
        where: { auctionId: auctionIds },
        transaction,
      }),
      UserAuctionBudget.destroy({
        where: { auctionId: auctionIds },
        transaction,
      }),
      UserLeaderboard.destroy({
        where: { auctionId: auctionIds },
        transaction,
      }),
    ]);

    // Now delete the auctions
    const deletedCount = await Auction.destroy({
      where: { id: auctionIds },
      transaction,
    });

    await transaction.commit();

    res.status(200).json({
      success: true,
      message: `Successfully deleted ${deletedCount} auctions`,
      count: deletedCount,
    });
  } catch (error) {
    await transaction.rollback();
    console.error("Error in bulkDeleteAuctions:", error);
    res.status(500).json({
      success: false,
      message: "Failed to delete auctions",
      error: error.message,
    });
  }
};

// Get all teams for an auction
const getAuctionTeams = async (req, res) => {
  try {
    const { auctionId } = req.params;

    // First get all participants (user IDs) from AuctionParticipants
    const participants = await AuctionParticipants.findAll({
      where: { auctionId },
      attributes: ["userId"],
      group: ["userId"],
    });

    const teams = await Promise.all(
      participants.map(async ({ userId }) => {
        // Get user details
        const user = await User.findByPk(userId, {
          attributes: ["id", "name", "email"],
        });

        // Get user's team players
        const wonPlayers = await AuctionResult.findAll({
          where: {
            auctionId,
            winnerId: userId,
            status: "sold",
          },
          include: [
            {
              model: Player,
              as: "player",
              attributes: ["id", "name", "team", "imageurl"],
            },
          ],
          order: [["createdAt", "DESC"]],
        });

        // Get user's budget info
        const budget =
          (await UserAuctionBudget.findOne({
            where: { auctionId, userId },
            attributes: ["totalBudget", "spentAmount"],
            raw: true,
          })) || {};

        return {
          userId,
          userName: user?.name || "Unknown User",
          team: wonPlayers.map((item) => ({
            id: item.player?.id,
            name: item.player?.name,
            team: item.player?.team,
            image: item.player?.imageurl,
            soldPrice: item.finalBid || 0,
          })),
          budgetInfo: {
            totalBudget: budget.totalBudget || 0,
            remainingBudget:
              (budget.totalBudget || 0) - (budget.spentAmount || 0),
            totalSpent: budget.spentAmount || 0,
          },
        };
      })
    );

    res.json({
      success: true,
      data: teams,
    });
  } catch (error) {
    console.error("Error fetching auction teams:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch auction teams",
      error: error.message,
    });
  }
};

const getUserEnrichedAuctions = async (req, res) => {
  try {
    console.log("herere=>");
    const { userId } = req.params;
    if (!userId) {
      return res
        .status(400)
        .json({ success: false, message: "User ID required" });
    }

    // Step 1: Get participated auctions
    const participated = await Auction.findAll({
      include: [
        {
          model: AuctionParticipants,
          as: "auctionParticipants",
          where: { userId, status: "active" },
          required: true,
          attributes: ["joinedAt", "status"],
        },
      ],
      order: [["createdAt", "DESC"]],
    });

    // Step 2: Fetch team and budget for each auction in parallel
    const enriched = await Promise.all(
      participated.map(async (auction) => {
        try {
          const [wonPlayers, userBudget] = await Promise.all([
            AuctionResult.findAll({
              where: {
                auctionId: auction.id,
                winnerId: userId,
                status: "sold",
              },
              include: [
                {
                  model: Player,
                  as: "player",
                  attributes: [
                    "id",
                    "name",
                    "type",
                    "team",
                    "imageurl",
                    "matches",
                  ],
                },
              ],
              order: [["createdAt", "DESC"]],
            }),
            UserAuctionBudget.findOne({
              where: { userId, auctionId: auction.id },
              include: [
                { model: User, as: "user", attributes: ["name", "email"] },
              ],
            }),
          ]);

          const team = wonPlayers.map((p) => ({
            id: p.player?.id,
            name: p.player?.name,
            role: p.player?.type,
            team: p.player?.team,
            price: p.finalBid,
            image: p.player?.imageurl,
            matches: p.player?.matches,
          }));

          const budget = userBudget
            ? {
                totalBudget: userBudget.totalBudget,
                spentAmount: userBudget.spentAmount,
                remainingBudget:
                  userBudget.totalBudget - userBudget.spentAmount,
                playersCount: userBudget.playersCount,
                totalBidsPlaced: userBudget.totalBidsPlaced,
                playersWon: userBudget.playersWon,
                userName: userBudget.user?.name,
              }
            : null;

          return {
            ...auction.toJSON(),
            userTeam: team,
            userBudget: budget,
          };
        } catch (e) {
          console.error(`Error enriching auction ${auction.id}:`, e);
          return { ...auction.toJSON(), userTeam: [], userBudget: null };
        }
      })
    );

    res.json({
      success: true,
      message: "User enriched auctions retrieved successfully",
      data: enriched,
    });
  } catch (error) {
    console.error("Error fetching enriched auctions:", error);
    res.status(500).json({
      success: false,
      message: "Server error while fetching enriched auctions",
      error: error.message,
    });
  }
};

module.exports = {
  bulkDeleteAuctions,
  createAuction,
  getAuctionDetails,
  getAllAuctions,
  getAuctionById,
  updateAuction,
  deleteAuction,
  getAuctionsByStatus,
  addPlayerToAuction,
  removePlayerFromAuction,
  startAuctionmanualUpdate,
  getUserEnrichedAuctions,
  startAuctionManually,
  stopAuction,
  resetAuction,
  getAuctionStatus,
  getAuctionTeams,
  getUserBudget,
  getUserTeam,
  getAllUserBudgets,
  getAuctionStats,
  getAuctionHistory,
  updateUserBudget,
  getbidofeachplayer,
  getteamsummary,
  joinAuction,
  leaveAuction,
  getUserParticipatedAuctions,
  getAuctionParticipants,
  getAuctionParticipantsWithPlayers,
};
