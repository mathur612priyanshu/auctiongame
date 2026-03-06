const { Server } = require("socket.io");
const Player = require("../models/player.model");
const Auction = require("../models/auction.model");
const BidHistory = require("../models/bidHistory.model");
const { getRedisClient } = require("../config/redis");
const AuctionResult = require("../models/auctionresult.model");
const UserAuctionBudget = require("../models/userAuctionBudget.model");
const User = require("../models/user.model");
const AuctionPlayers = require("../models/auctionPlayers.model");

function createAuctionSocketController(io) {
  const auctionTimers = new Map();
  const redis = getRedisClient();
  const auctionChats = new Map();

  // Budget Management Functions
  async function initializeUserBudget(userId, auctionId) {
    try {
      let userBudget = await UserAuctionBudget.findOne({
        where: { userId, auctionId },
      });

      if (!userBudget) {
        userBudget = await UserAuctionBudget.create({
          userId,
          auctionId,
          totalBudget: 10000000, // 1 Cr
          spentAmount: 0,
          playersCount: 0,
          isActive: true,
        });
        console.log(
          `💰 Initialized budget for user ${userId} in auction ${auctionId}`
        );
      }

      return userBudget;
    } catch (error) {
      console.error("Error initializing user budget:", error);
      return null;
    }
  }

  async function updateUserBudgetOnBid(userId, auctionId, bidAmount) {
    try {
      const userBudget = await UserAuctionBudget.findOne({
        where: { userId, auctionId },
      });

      if (!userBudget) {
        throw new Error("User budget not found");
      }

      // Check if user has enough budget
      const remainingBudget = userBudget.totalBudget - userBudget.spentAmount;
      if (remainingBudget < bidAmount) {
        throw new Error("Insufficient budget");
      }

      // Update bid statistics
      userBudget.lastBidAmount = bidAmount;
      userBudget.totalBidsPlaced += 1;
      await userBudget.save();

      return userBudget;
    } catch (error) {
      console.error("Error updating budget on bid:", error);
      throw error;
    }
  }

  async function finalizeBudgetOnWin(userId, auctionId, finalBidAmount) {
    try {
      const userBudget = await UserAuctionBudget.findOne({
        where: { userId, auctionId },
      });

      if (!userBudget) {
        throw new Error("User budget not found");
      }

      // Deduct the final bid amount from budget
      userBudget.spentAmount += finalBidAmount;
      userBudget.playersCount += 1;
      userBudget.playersWon += 1;

      // Check if user is still active (has budget for minimum bid)
      const remainingBudget = userBudget.totalBudget - userBudget.spentAmount;
      userBudget.isActive = remainingBudget > 0;

      await userBudget.save();

      console.log(
        `💰 Finalized budget for user ${userId}: spent ${finalBidAmount}, remaining ${remainingBudget}`
      );
      return userBudget;
    } catch (error) {
      console.error("Error finalizing budget on win:", error);
      throw error;
    }
  }

  async function emitBudgetUpdates(auctionId) {
    try {
      // Get all user budgets for this auction
      const allBudgets = await UserAuctionBudget.findAll({
        where: { auctionId },
        include: [
          {
            model: User,
            as: "user",
            attributes: ["name"],
          },
        ],
      });

      const formattedBudgets = allBudgets.map((budget) => ({
        userId: budget.userId,
        userName: budget.user.name,
        totalBudget: budget.totalBudget,
        spentAmount: budget.spentAmount,
        remainingBudget: budget.totalBudget - budget.spentAmount,
        playersCount: budget.playersCount,
        isActive: budget.isActive,
        totalBidsPlaced: budget.totalBidsPlaced,
        playersWon: budget.playersWon,
      }));

      // Emit to all users in the auction
      io.to(`auction_${auctionId}`).emit("budgetUpdated", {
        budgets: formattedBudgets,
        timestamp: new Date(),
      });

      console.log(`📊 Emitted budget updates for auction ${auctionId}`);
    } catch (error) {
      console.error("Error emitting budget updates:", error);
    }
  }

  async function cleanupAuctionChat(auctionId) {
    if (auctionChats.has(auctionId)) {
      auctionChats.delete(auctionId);
      console.log(`🧹 Cleaned up chat data for auction ${auctionId}`);
    }
  }
  async function emitAuctionStats(auctionId) {
    try {
      // 1. Get all auction results with player details
      const auctionResults = await AuctionResult.findAll({
        where: { auctionId },
        include: [
          {
            model: Player,
            as: "player",
            attributes: ["id", "name", "type", "team", "imageurl", "matches"],
          },
        ],
      });

      // 2. Get ALL players registered for this auction
      const allAuctionPlayers = await AuctionPlayers.findAll({
        where: { auctionId },
        attributes: ["playerId"],
      });
      const totalPlayersCount = allAuctionPlayers.length;

      // 3. Calculate basic stats
      const soldPlayers = auctionResults.filter((r) => r.status === "sold");
      const unsoldPlayers = auctionResults.filter((r) => r.status === "unsold");
      const auctionedPlayersCount = auctionResults.length;
      const remainingPlayersCount = totalPlayersCount - auctionedPlayersCount;

      const totalSpent = soldPlayers.reduce((sum, r) => sum + r.finalBid, 0);
      const averagePrice =
        soldPlayers.length > 0
          ? Math.round(totalSpent / soldPlayers.length)
          : 0;
      const highestSale =
        soldPlayers.length > 0
          ? Math.max(...soldPlayers.map((r) => r.finalBid))
          : 0;

      const totalParticipants = await UserAuctionBudget.count({
        where: { auctionId },
      });

      // 4. Get remaining players details (if needed)
      const auctionedPlayerIds = auctionResults.map((r) => r.playerId);
      const remainingPlayerIds = allAuctionPlayers
        .map((p) => p.playerId)
        .filter((id) => !auctionedPlayerIds.includes(id));

      const remainingPlayers = await Player.findAll({
        where: { id: remainingPlayerIds },
        attributes: ["id", "name", "type", "team", "imageurl", "matches"],
      });

      // 5. Prepare stats
      const stats = {
        totalPlayers: auctionedPlayersCount,
        soldPlayers: soldPlayers.length,
        unsoldPlayers: unsoldPlayers.length,
        averagePrice,
        highestSale,
        totalSpent,
        totalParticipants,
        remainingPlayers: remainingPlayers,
        remainingPlayerslength: remainingPlayersCount,
        totalplayers: totalPlayersCount,
      };

      // Debug logs
      console.log("Debug Stats:", {
        totalAuctioned: auctionedPlayersCount,
        totalRegistered: totalPlayersCount,
        remaining: remainingPlayersCount,
        calculatedRemaining: remainingPlayers,
      });

      io.to(`auction_${auctionId}`).emit("auctionStatsUpdated", {
        stats,
        timestamp: new Date(),
      });

      console.log(`📈 Emitted auction stats for auction ${auctionId}`);
    } catch (error) {
      console.error("Error emitting auction stats:", error);
    }
  }

  async function emitAuctionHistory(auctionId) {
    try {
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
        limit: 50, // Limit to last 50 results
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

      io.to(`auction_${auctionId}`).emit("auctionHistory", {
        history: formattedHistory,
        timestamp: new Date(),
      });

      console.log(
        `📜 Emitted auction history for auction ${auctionId}: ${formattedHistory.length} items`
      );
    } catch (error) {
      console.error("Error emitting auction history:", error);
    }
  }

  async function emitUserTeam(userId, auctionId) {
    try {
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
            attributes: [
              "id",
              "name",
              "type",
              "team",
              "imageurl",
              // "age",
              "matches",
              // "runs",
              // "average",
              // "strikeRate",
            ],
          },
        ],
        order: [["createdAt", "DESC"]],
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

      // Emit to specific user
      const users = await redis.sMembers(`auction:${auctionId}:users`);
      for (const userStr of users) {
        const user = JSON.parse(userStr);
        if (user.userId === userId) {
          io.to(user.socketId).emit("userTeam", {
            team,
            timestamp: new Date(),
          });
          break;
        }
      }

      console.log(
        `👥 Emitted user team for user ${userId}: ${team.length} players`
      );
    } catch (error) {
      console.error("Error emitting user team:", error);
    }
  }
  async function emitSpecificUserTeam(targetUserId, auctionId) {
    try {
      const wonPlayers = await AuctionResult.findAll({
        where: {
          auctionId,
          winnerId: targetUserId,
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

      const team = wonPlayers.map((item) => ({
        id: item.player?.id,
        name: item.player?.name,
        role: item.player?.type,
        price: item.finalBid,
        team: item.player?.team,
        image: item.player?.imageurl,
        matches: item.player?.matches,
        purchaseDate: item.createdAt,
      }));
      console.log("i am here...");
      io.to(`auction_${auctionId}`).emit("specificUserTeam", {
        userId: targetUserId,
        team,
        timestamp: new Date(),
      });

      console.log(
        `👥 Emitted specific user team for user ${targetUserId}: ${team.length} players`
      );
    } catch (error) {
      console.error("Error emitting specific user team:", error);
    }
  }

  async function emitCurrentPlayerBids(auctionId, playerId) {
    try {
      const bids = await BidHistory.findAll({
        where: {
          auctionId,
          playerId,
        },
        order: [["timestamp", "DESC"]],
        limit: 20,
      });

      const formattedBids = bids.map((bid) => ({
        id: bid.id,
        bidder: bid.bidderName,
        bidderId: bid.bidderId,
        amount: bid.amount,
        previousBid: bid.previousBid,
        timestamp: bid.timestamp,
      }));

      io.to(`auction_${auctionId}`).emit("currentPlayerBids", {
        playerId,
        bids: formattedBids,
        timestamp: new Date(),
      });

      console.log(
        `💰 Emitted current player bids for player ${playerId}: ${formattedBids.length} bids`
      );
    } catch (error) {
      console.error("Error emitting current player bids:", error);
    }
  }

  function handleConnection(socket) {
    console.log(`User connected: ${socket.id}`);
    socket.on("requestUserTeam", async (data) => {
      const { targetUserId, auctionId } = data;
      await emitSpecificUserTeam(targetUserId, auctionId);
    });

    socket.on("sendChatMessage", async (data) => {
      const { auctionId, userId, userName, message, timestamp } = data;

      console.log(
        `💬 Chat message from ${userName} in auction ${auctionId}: ${message}`
      );

      // Validate message
      if (!message || message.trim().length === 0) {
        return socket.emit("chatError", { message: "Message cannot be empty" });
      }

      if (message.length > 500) {
        return socket.emit("chatError", {
          message: "Message too long (max 500 characters)",
        });
      }

      // Check if user is in the auction
      const users = await redis.sMembers(`auction:${auctionId}:users`);
      const userExists = users.some((userStr) => {
        const user = JSON.parse(userStr);
        return user.userId === userId;
      });

      if (!userExists) {
        return socket.emit("chatError", {
          message: "You are not in this auction",
        });
      }

      // Create chat message object
      const chatMessage = {
        id: Date.now() + Math.random(), // Simple ID generation
        userId,
        userName,
        message: message.trim(),
        timestamp: timestamp || new Date().toISOString(),
        auctionId,
      };

      // Store in memory (initialize if doesn't exist)
      if (!auctionChats.has(auctionId)) {
        auctionChats.set(auctionId, []);
      }

      const messages = auctionChats.get(auctionId);
      messages.push(chatMessage);

      // Keep only last 100 messages per auction
      if (messages.length > 100) {
        messages.splice(0, messages.length - 100);
      }

      // Broadcast to all users in the auction
      io.to(`auction_${auctionId}`).emit("newChatMessage", chatMessage);

      console.log(`📤 Broadcasted chat message to auction_${auctionId}`);
    });

    // Chat history handler
    socket.on("getChatHistory", async (data) => {
      const { auctionId, userId } = data;

      console.log(
        `📜 Chat history requested by user ${userId} for auction ${auctionId}`
      );

      // Check if user is in the auction
      const users = await redis.sMembers(`auction:${auctionId}:users`);
      const userExists = users.some((userStr) => {
        const user = JSON.parse(userStr);
        return user.userId === userId;
      });

      if (!userExists) {
        return socket.emit("chatError", {
          message: "You are not in this auction",
        });
      }

      // Get chat history for this auction
      const messages = auctionChats.get(auctionId) || [];

      // Send last 50 messages
      const recentMessages = messages.slice(-50);

      socket.emit("chatHistory", {
        auctionId,
        messages: recentMessages,
        timestamp: new Date().toISOString(),
      });

      console.log(
        `📤 Sent ${recentMessages.length} chat messages to user ${userId}`
      );
    });
    socket.on("userTyping", async (data) => {
      const { auctionId, userId, userName, isTyping } = data;

      // Broadcast typing status to others (not to sender)
      socket.to(`auction_${auctionId}`).emit("userTypingStatus", {
        userId,
        userName,
        isTyping,
        timestamp: new Date().toISOString(),
      });
    });

    // Broadcast typing status to others (not to sender)

    socket.on("joinAuction", async (data) => {
      const { auctionId, userId, userName, profilepic } = data;
      const roomName = `auction_${auctionId}`;

      console.log(`User ${userName} (${userId}) joining auction ${auctionId}`);

      socket.join(roomName);

      // Initialize user budget when they join
      await initializeUserBudget(userId, auctionId);

      // Get auction details including maxPlayerAllowed
      const auctionDetails = await Auction.findByPk(auctionId, {
        attributes: ['id', 'name', 'maxPlayerAllowed', 'minPlayers', 'status']
      });

      if (auctionDetails) {
        socket.emit("auctionDetails", {
          id: auctionDetails.id,
          name: auctionDetails.name,
          maxPlayerAllowed: auctionDetails.maxPlayerAllowed,
          minPlayers: auctionDetails.minPlayers,
          status: auctionDetails.status,
          timestamp: new Date()
        });
      }

      // Remove any existing connections for this user to prevent duplicates
      const existingUsers = await redis.sMembers(`auction:${auctionId}:users`);
      for (const userStr of existingUsers) {
        const user = JSON.parse(userStr);
        if (user.userId === userId) {
          await redis.sRem(`auction:${auctionId}:users`, userStr);
          console.log(
            `Removed duplicate user ${userName} from auction ${auctionId}`
          );
        }
      }

      // Store user info in Redis
      await redis.sAdd(
        `auction:${auctionId}:users`,
        JSON.stringify({ socketId: socket.id, userId, userName, profilepic })
      );

      // Get current auction state
      const auctionStateStr = await redis.get(`auction:${auctionId}:state`);
      const currentPlayerId = await redis.get(
        `auction:${auctionId}:current_player`
      );

      if (currentPlayerId) {
        try {
          const player = await Player.findByPk(currentPlayerId);

          if (player) {
            if (!auctionTimers.has(auctionId)) {
              console.log(
                `⏰ No timer found for auction ${auctionId}, starting timer`
              );
              resetAuctionTimer(auctionId);
            }

            // Get highest bid for current player
            const highestBidJSON = await redis.get(
              `auction:${auctionId}:player:${currentPlayerId}:high_bid`
            );

            let highestBid = null;
            let currentBid = player.basePrice;
            let highestBidder = "No bids yet";

            if (highestBidJSON) {
              highestBid = JSON.parse(highestBidJSON);
              currentBid = highestBid.amount;
              highestBidder = highestBid.bidderName;
            }

            // Get recent bids for this player (last 20 bids)
            const recentBids = await BidHistory.findAll({
              where: {
                auctionId: auctionId,
                playerId: currentPlayerId,
              },
              order: [["timestamp", "DESC"]],
              limit: 20,
            });

            console.log(
              `📊 Found ${recentBids.length} bids for player ${currentPlayerId} in auction ${auctionId}`
            );

            // Format recent bids for frontend
            const liveBids = recentBids.map((bid) => ({
              bidder: bid.bidderName,
              bidderId: bid.bidderId,
              amount: bid.amount,
              timestamp: bid.timestamp,
            }));

            // Send current player data to the joining user
            socket.emit("current-player", {
              player: {
                id: player.id,
                name: player.name,
                basePrice: player.basePrice,
                team: player.team,
                type: player.type,
                age: player?.age,
                matches: player.matches,
                runs: player.runs,
                average: player.average,
                strikeRate: player.strikeRate,
                previousTeam: player.previousTeam,
                previousPrice: player.previousPrice,
                metadata: player.metadata,
                image: player.imageurl,
              },
              highestBid: highestBid,
              currentBid: currentBid,
              highestBidder: highestBidder,
              liveBids: liveBids,
              timeRemaining: 12, // Add this
            });

            // Also emit current player bids separately
            setTimeout(() => {
              socket.emit("currentPlayerBids", {
                playerId: currentPlayerId,
                bids: liveBids,
                timestamp: new Date(),
              });
            }, 500);

            console.log(
              `✅ Sent current player ${player.name} with ${liveBids.length} recent bids to ${userName}`
            );
          }
        } catch (error) {
          console.error("Error fetching current player:", error);
        }
      }

      // Send auction state if available
      if (auctionStateStr) {
        const auctionState = JSON.parse(auctionStateStr);
        socket.emit("auctionState", auctionState);
        console.log(`Sent auction state to ${userName}`);
      }

      // Send user's budget info
      try {
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

        if (userBudget) {
          socket.emit("userBudget", {
            totalBudget: userBudget.totalBudget,
            spentAmount: userBudget.spentAmount,
            remainingBudget: userBudget.totalBudget - userBudget.spentAmount,
            playersCount: userBudget.playersCount,
            isActive: userBudget.isActive,
          });
        }
      } catch (error) {
        console.error("Error sending user budget:", error);
      }

      // Notify other users that someone joined
      socket.to(roomName).emit("userJoined", {
        userId,
        userName,
        profilepic,
        timestamp: new Date(),
      });

      // Get all connected users and send to everyone in the room
      const allUsers = await redis.sMembers(`auction:${auctionId}:users`);
      const connectedUsers = allUsers.map((userStr) => {
        const user = JSON.parse(userStr);
        return {
          userId: user.userId,
          userName: user.userName,
          profilepic: user.profilepic || '',
        };
      });

      // Send updated user list to everyone in the room
      io.to(roomName).emit("connectedUsers", { users: connectedUsers });

      // Send budget updates to all users
      await emitBudgetUpdates(auctionId);

      // Send auction stats
      await emitAuctionStats(auctionId);
      await emitAuctionHistory(auctionId);

      // Send user's team
      await emitUserTeam(userId, auctionId);

      console.log(
        `✅ User ${userName} successfully joined auction ${auctionId}. Total users: ${connectedUsers.length}`
      );
    });

    socket.on("placeBid", async (data) => {
      const { auctionId, userId, userName, bidAmount, playerId } = data;
      try {
        console.log(
          `📥 Received bid from ${userName}: ₹${bidAmount} for player ${playerId}`
        );

        const stateStr = await redis.get(`auction:${auctionId}:state`);

        if (!stateStr) {
          console.log("❌ No auction state found");
          return socket.emit("bidError", { message: "No auction in progress" });
        }

        const currentAuction = JSON.parse(stateStr);

        if (bidAmount <= currentAuction.currentBid) {
          console.log(
            `❌ Invalid bid amount: ${bidAmount} <= ${currentAuction.currentBid}`
          );
          return socket.emit("bidError", {
            message: "Bid amount must be higher than current bid",
          });
        }

        // Check user's budget before allowing bid
        try {
          await updateUserBudgetOnBid(userId, auctionId, bidAmount);
        } catch (budgetError) {
          console.log(
            `❌ Budget error for ${userName}: ${budgetError.message}`
          );
          return socket.emit("bidError", {
            message: budgetError.message,
          });
        }

        console.log(`✅ Valid bid from ${userName}: ₹${bidAmount}`);

        // Save bid to database
        await saveBidToDatabase({
          auctionId,
          playerId: currentAuction.currentPlayer.id,
          bidderId: userId,
          bidderName: userName,
          amount: bidAmount,
          previousBid: currentAuction.currentBid,
        });

        // Store highest bid in Redis
        await redis.set(
          `auction:${auctionId}:player:${playerId}:high_bid`,
          JSON.stringify({
            amount: bidAmount,
            bidderId: userId,
            bidderName: userName,
            timestamp: new Date(),
          })
        );

        const updatedAuction = {
          ...currentAuction,
          currentBid: bidAmount,
          highestBidder: userName,
          highestBidderId: userId,
          lastBidTime: new Date(),
          timeRemaining: 12,
        };

        await redis.set(
          `auction:${auctionId}:state`,
          JSON.stringify(updatedAuction)
        );

        // Broadcast new bid to all users in the auction
        io.to(`auction_${auctionId}`).emit("newBid", {
          auctionId,
          playerId,
          bidAmount,
          bidder: userName,
          bidderId: userId,
          timeRemaining: 12,
          timestamp: new Date(),
        });

        // Emit updated budget information
        await emitBudgetUpdates(auctionId);

        console.log(`📤 Broadcasted bid to auction_${auctionId}`);

        // Reset timer
        // Reset timer
        resetAuctionTimer(auctionId);
      } catch (error) {
        console.error("❌ Error placing bid:", error);
        socket.emit("bidError", { message: "Error placing bid" });
      }
    });

    socket.on("leaveAuction", async (data) => {
      const { auctionId, userId, userName } = data;
      console.log(`User ${userName} leaving auction ${auctionId}`);

      socket.leave(`auction_${auctionId}`);

      // Remove user from Redis
      const users = await redis.sMembers(`auction:${auctionId}:users`);
      for (const userStr of users) {
        const user = JSON.parse(userStr);
        if (user.socketId === socket.id || user.userId === userId) {
          await redis.sRem(`auction:${auctionId}:users`, userStr);
        }
      }

      // Get updated user list
      const remainingUsers = await redis.sMembers(`auction:${auctionId}:users`);
      const connectedUsers = remainingUsers.map((userStr) => {
        const user = JSON.parse(userStr);
        return {
          userId: user.userId,
          userName: user.userName,
          profilepic: user.profilepic || '',
        };
      });

      // Notify others and send updated user list
      socket.to(`auction_${auctionId}`).emit("userLeft", {
        userId,
        userName,
        timestamp: new Date(),
      });

      // Send updated user list to remaining users
      socket
        .to(`auction_${auctionId}`)
        .emit("connectedUsers", { users: connectedUsers });

      console.log(
        `✅ User ${userName} left auction ${auctionId}. Remaining users: ${connectedUsers.length}`
      );
    });

    socket.on("disconnect", async () => {
      console.log(`User disconnected: ${socket.id}`);

      // Find and remove user from all auctions
      const keys = await redis.keys("auction:*:users");
      for (const key of keys) {
        const users = await redis.sMembers(key);
        for (const uStr of users) {
          const user = JSON.parse(uStr);
          if (user.socketId === socket.id) {
            await redis.sRem(key, uStr);
            const auctionId = key.split(":")[1];

            // Get updated user list
            const remainingUsers = await redis.sMembers(key);
            const connectedUsers = remainingUsers.map((userStr) => {
              const u = JSON.parse(userStr);
              return {
                userId: u.userId,
                userName: u.userName,
                profilepic: u.profilepic || '',
              };
            });

            // Notify remaining users
            io.to(`auction_${auctionId}`).emit("userLeft", {
              userId: user.userId,
              userName: user.userName,
              timestamp: new Date(),
            });

            // Send updated user list
            io.to(`auction_${auctionId}`).emit("connectedUsers", {
              users: connectedUsers,
            });

            console.log(
              `Removed disconnected user ${user.userName} from auction ${auctionId}. Remaining: ${connectedUsers.length}`
            );
            break;
          }
        }
      }
    });
  }

  function resetAuctionTimer(auctionId) {
    console.log(`🔄 Resetting timer for auction ${auctionId}`);

    if (auctionTimers.has(auctionId)) {
      clearInterval(auctionTimers.get(auctionId));
    }

    let timeRemaining = 12;
    const timer = setInterval(async () => {
      timeRemaining--;

      io.to(`auction_${auctionId}`).emit("timerUpdate", {
        auctionId,
        timeRemaining,
      });

      const stateStr = await redis.get(`auction:${auctionId}:state`);
      if (stateStr) {
        const state = JSON.parse(stateStr);
        state.timeRemaining = timeRemaining;
        await redis.set(`auction:${auctionId}:state`, JSON.stringify(state));
      }

      if (timeRemaining <= 0) {
        console.log(`⏰ Timer expired for auction ${auctionId}`);
        clearInterval(timer);
        auctionTimers.delete(auctionId);
        endAuction(auctionId);
      }
    }, 1000);

    auctionTimers.set(auctionId, timer);
  }

  async function endAuction(auctionId) {
    console.log(`🏁 Ending auction for auction ${auctionId}`);

    const stateStr = await redis.get(`auction:${auctionId}:state`);
    if (!stateStr) return;

    const auction = JSON.parse(stateStr);

    // Save auction result
    await saveAuctionResult({
      auctionId,
      playerId: auction.currentPlayer.id,
      winnerId: auction.highestBidderId,
      winnerName: auction.highestBidder,
      finalBid: auction.currentBid,
      basePrice: auction.currentPlayer.basePrice,
      auctionStartTime: auction.startTime,
      auctionEndTime: new Date(),
      status: auction.highestBidderId ? "sold" : "unsold",
    });

    // Update winner's budget if player was sold
    if (auction.highestBidderId) {
      await finalizeBudgetOnWin(
        auction.highestBidderId,
        auctionId,
        auction.currentBid
      );
    }

    // Update auction status
    await updateAuctionStatus(auctionId, {
      currentBid: auction.currentBid,
      highestBidder: auction.highestBidder,
      highestBidderId: auction.highestBidderId,
      winnerId: auction.highestBidderId,
      finalBid: auction.currentBid,
    });

    // Broadcast auction end
    io.to(`auction_${auctionId}`).emit("auctionEnded", {
      auctionId,
      winner: auction.highestBidder,
      winnerId: auction.highestBidderId,
      finalBid: auction.currentBid,
      playerId: auction.currentPlayer.id,
      playerName: auction.currentPlayer.name,
      timestamp: new Date(),
    });

    // Emit updated budgets and stats
    await emitBudgetUpdates(auctionId);
    await emitAuctionStats(auctionId);
    await emitAuctionHistory(auctionId);
    if (auction.highestBidderId) {
      await emitUserTeam(auction.highestBidderId, auctionId);
    }

    console.log(`📤 Broadcasted auction end for ${auction.currentPlayer.name}`);

    setTimeout(() => {
      startNextPlayer(auctionId);
    }, 3000);
  }

  async function startNextPlayer(auctionId) {
    console.log(`🔄 Starting next player for auction ${auctionId}`);

    const nextPlayerId = await redis.lPop(`auction:${auctionId}:player_queue`);

    if (!nextPlayerId) {
      await Auction.update(
        { status: "completed" },
        { where: { id: auctionId } }
      );

      io.to(`auction_${auctionId}`).emit("auctionCompleted", {
        message: "All players have been auctioned.",
      });

      // Send final stats
      await emitAuctionStats(auctionId);
      await emitBudgetUpdates(auctionId);

      console.log(`🎉 Auction ${auctionId} completed`);
      return;
    }

    const nextPlayer = await Player.findByPk(nextPlayerId);

    await redis.set(`auction:${auctionId}:current_player`, nextPlayerId);

    const newAuctionState = {
      currentPlayer: {
        id: nextPlayer.id,
        name: nextPlayer.name,
        basePrice: nextPlayer.basePrice,
        type: nextPlayer.type,
        team: nextPlayer.team,
        age: nextPlayer.age,
        matches: nextPlayer.matches,
        runs: nextPlayer.runs,
        average: nextPlayer.average,
        strikeRate: nextPlayer.strikeRate,
        previousTeam: nextPlayer.previousTeam,
        previousPrice: nextPlayer.previousPrice,
        metadata: nextPlayer.metadata,
        image: nextPlayer.imageurl,
      },
      currentBid: nextPlayer.basePrice,
      highestBidder: "No bids yet",
      highestBidderId: null,
      timeRemaining: 12,
      startTime: new Date(),
    };

    await redis.set(
      `auction:${auctionId}:state`,
      JSON.stringify(newAuctionState)
    );

    io.to(`auction_${auctionId}`).emit("newPlayerAuction", newAuctionState);

    console.log(`📤 Started auction for ${nextPlayer.name}`);

    resetAuctionTimer(auctionId);
  }

  async function saveBidToDatabase(bidData) {
    try {
      await BidHistory.create({
        auctionId: bidData.auctionId,
        playerId: bidData.playerId,
        bidderId: bidData.bidderId,
        bidderName: bidData.bidderName,
        amount: bidData.amount,
        previousBid: bidData.previousBid,
        timestamp: new Date(),
      });
      console.log(`💾 Bid saved: ₹${bidData.amount} by ${bidData.bidderName}`);
    } catch (error) {
      console.error("❌ Error saving bid:", error);
    }
  }

  async function saveAuctionResult(resultData) {
    try {
      const totalBids = await BidHistory.count({
        where: {
          auctionId: resultData.auctionId,
          playerId: resultData.playerId,
        },
      });

      await AuctionResult.create({
        ...resultData,
        totalBids,
      });
      console.log(`💾 Auction result saved for player ${resultData.playerId}`);
    } catch (error) {
      console.error("❌ Error saving auction result:", error);
    }
  }

  async function updateAuctionStatus(auctionId, updateData) {
    try {
      await Auction.update(updateData, {
        where: { id: auctionId },
      });
      console.log(`💾 Auction ${auctionId} status updated`);
    } catch (error) {
      console.error("❌ Error updating auction status:", error);
    }
  }

  async function initializeAuction(auctionId, initialData) {
    console.log(`🚀 Initializing auction ${auctionId}`);

    await redis.set(`auction:${auctionId}:state`, JSON.stringify(initialData));

    if (initialData.currentPlayer) {
      await redis.set(
        `auction:${auctionId}:current_player`,
        initialData.currentPlayer.id
      );
    }

    try {
      await Auction.update(
        {
          status: "ongoing",
          startTime: new Date(),
        },
        { where: { id: auctionId } }
      );
      if (initialData.currentPlayer) {
        resetAuctionTimer(auctionId);
        console.log(
          `⏰ Timer started for initial player: ${initialData.currentPlayer.name}`
        );
      }

      console.log(`✅ Auction ${auctionId} initialized and marked as ongoing`);
    } catch (error) {
      console.error("❌ Error updating auction status to ongoing:", error);
    }
  }

  return {
    handleConnection,
    initializeAuction,
    startNextPlayer,
    resetAuctionTimer,
    emitBudgetUpdates,
    emitAuctionStats,
    cleanupAuctionChat, // Export cleanup function
  };
}

module.exports = createAuctionSocketController;
