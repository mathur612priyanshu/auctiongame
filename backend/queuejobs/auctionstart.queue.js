const Queue = require("bull");
const Auction = require("../models/auction.model");
const AuctionPlayers = require("../models/auctionPlayers.model");
const { getRedisClient } = require("../config/redis");
const Player = require("../models/player.model");
const auctionStartQueue = new Queue("auction-start", {
  redis: { host: "localhost", port: 6379 },
});

auctionStartQueue.process(async (job) => {
  const { auctionId } = job.data;
  console.log(`Processing auction start job for auction ${auctionId}`);
  
  try {
    const auction = await Auction.findByPk(auctionId);
    if (!auction) {
      console.error(`Auction ${auctionId} not found`);
      return;
    }
    
    if (auction.status !== "upcoming") {
      console.log(`Auction ${auctionId} is not in 'upcoming' status (current status: ${auction.status})`);
      return;
    }
    
    console.log(`Starting auction ${auctionId}`);
    await auction.update({ status: "ongoing" });
    await startAuction(auctionId);
    console.log(`✅ Successfully started auction ${auctionId}`);
  } catch (error) {
    console.error(
      `❌ Error processing auction start for ${job.data.auctionId}:`,
      error
    );
  }
});

const scheduleAuctionStart = async (auction) => {
  try {
    const startTime = new Date(auction.startTime);
    const delay = startTime - Date.now();
    
    console.log(`Scheduling auction ${auction.id} to start at ${startTime} (in ${delay}ms)`);
    
    if (delay <= 0) {
      console.log(`Auction ${auction.id} start time is in the past, starting immediately`);
      await auction.update({ status: "ongoing" });
      await startAuction(auction.id);
      return;
    }

    await auctionStartQueue.add(
      { auctionId: auction.id },
      {
        delay,
        jobId: `${auction.id}`, // Important to identify for removal
      }
    );
  } catch (err) {
    console.log(err);
  }
};

const cancelAuctionStart = async (auctionId) => {
  await auctionStartQueue.removeJobs(auctionId);
};

const startAuction = async (auctionId) => {
  try {
    const players = await AuctionPlayers.findAll({
      where: { auctionId },
      order: [["createdAt", "ASC"]],
    });

    const redis = getRedisClient();

    // Shuffle function to randomize player order
    const shuffleArray = (array) => {
      const newArray = [...array];
      for (let i = newArray.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [newArray[i], newArray[j]] = [newArray[j], newArray[i]];
      }
      return newArray;
    };

    // Get player IDs and shuffle them
    let realplayerid = players.map((p) => p.playerId.toString());
    realplayerid = shuffleArray(realplayerid);

    for (const playerId of realplayerid) {
      await redis.rPush(`auction:${auctionId}:player_queue`, playerId);
    }

    const firstPlayerId = await redis.lPop(`auction:${auctionId}:player_queue`);
    await redis.set(`auction:${auctionId}:current_player`, firstPlayerId);

    // ✅ Fetch full player details
    const playerDetails = await Player.findByPk(firstPlayerId);
    if (!playerDetails) throw new Error("Player not found");

    // ✅ Initialize auction state
    const initialState = {
      currentPlayer: {
        id: playerDetails.id,
        name: playerDetails.name,
        basePrice: playerDetails.basePrice,
        type: playerDetails.type,
      },
      currentBid: playerDetails.basePrice,
      highestBidder: "No bids yet",
      highestBidderId: null,
      timeRemaining: 12,
      startTime: new Date(),
    };

    await redis.set(`auction:${auctionId}:state`, JSON.stringify(initialState));

    console.log(
      `✅ Auction ${auctionId} started with player ${playerDetails.name}`
    );
  } catch (error) {
    console.log(`❌ Error starting auction ${auctionId}:`, error);
    throw error;
  }
};
module.exports = {
  auctionStartQueue,
  scheduleAuctionStart,
  startAuction,
  cancelAuctionStart,
};
