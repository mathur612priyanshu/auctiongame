const cron = require("node-cron");
const { Op } = require("sequelize");
const Auction = require("../models/auction.model");

// Simple function to update auction statuses
const updateAuctionStatuses = async () => {
  try {
    const now = new Date();

    // Check if there are any auctions that need status updates
    const upcomingCount = await Auction.count({
      where: {
        status: "upcoming",
        startTime: {
          [Op.lte]: now,
        },
      },
    });

    // Only proceed if there are auctions to update
    if (upcomingCount === 0) {
      // Uncomment this line if you want to see when no updates are needed
      // console.log("No auction status updates needed");
      return;
    }

    console.log("Checking for auctions to update...");

    // Update auctions that should start
    if (upcomingCount > 0) {
      const startedAuctions = await Auction.update(
        { status: "ongoing" },
        {
          where: {
            status: "upcoming",
            startTime: {
              [Op.lte]: now,
            },
          },
        }
      );

      if (startedAuctions[0] > 0) {
        console.log(`✅ checking auctions cron`);
      }
    }

    // Update auctions that should end
    // if (ongoingWithEndTimeCount > 0) {
    //   const endedAuctions = await Auction.update(
    //     { status: "completed" },
    //     {
    //       where: {
    //         status: "ongoing",
    //         endTime: {
    //           [Op.lte]: now,
    //           [Op.not]: null,
    //         },
    //       },
    //     }
    //   );

    //   if (endedAuctions[0] > 0) {
    //     console.log(`✅ Completed ${endedAuctions[0]} auctions`);
    //   }
    // }
  } catch (error) {
    console.error("❌ Error updating auction statuses:", error);
  }
};

// Start the cron job - runs every minute
const startAuctionCron = () => {
  cron.schedule("* * * * *", updateAuctionStatuses);
  console.log("🕐 Auction status cron job started - runs every minute");
};

// Manual trigger function for testing
const manualUpdate = async () => {
  await updateAuctionStatuses();
};

module.exports = {
  startAuctionCron,
  manualUpdate,
};
