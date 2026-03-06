const { Sequelize, DataTypes } = require("sequelize");
const { setupAssociations } = require("./association");
const sequelize = new Sequelize(
  process.env.DB_NAME,
  process.env.DBUSER,
  process.env.DBPASS,
  {
    host: process.env.DB_HOST,
    dialect: "mysql",
    timezone: "+05:30",
    // logging: console.log, // Enable query logging
    logging: false, // 👈 disables console SQL logs

    dialectOptions: {
      ssl: {
        require: true,
        rejectUnauthorized: false,
      },
    },
  }
);

const connectToDatabase = async () => {
  try {
    await sequelize.authenticate();
    console.log("Connection has been established successfully.");
    setupAssociations();
    await sequelize.sync({ force: false });
    console.log("All models were synchronized successfully.");
    const UserAuctionBudget = require("../models/userAuctionBudget.model");
    const Auction = require("../models/auction.model");
    const Player = require("../models/player.model");
    const User = require("../models/user.model");
    const AuctionResult = require("../models/auctionresult.model");
    const BidHistory = require("../models/bidHistory.model");
    const AuctionPlayers = require("../models/auctionPlayers.model");
    const PlayerPoints = require("../models/playerspoint.model");
    const UserLeaderboard = require("../models/userLeaderboard.model");
    const AuctionParticipants = require("../models/auctionParticipants.model"); // NEW

    // // Import models

    // // Set up associations
    // Auction.belongsToMany(Player, {
    //   through: AuctionPlayers,
    //   foreignKey: "auctionId",
    //   otherKey: "playerId",
    //   as: "players",
    //   onDelete: "CASCADE", // ✅
    // });

    // Player.belongsToMany(Auction, {
    //   through: AuctionPlayers,
    //   foreignKey: "playerId",
    //   otherKey: "auctionId",
    //   as: "auctions",
    //   onDelete: "CASCADE", // ✅
    // });

    // // Direct associations with the junction table
    // Auction.hasMany(AuctionPlayers, {
    //   foreignKey: "auctionId",
    //   onDelete: "CASCADE", // 👈 important
    // });
    // Player.hasMany(AuctionPlayers, {
    //   foreignKey: "playerId",
    //   onDelete: "CASCADE", // 👈 important
    // });
    // AuctionPlayers.belongsTo(Auction, {
    //   foreignKey: "auctionId",
    //   onDelete: "CASCADE", // 👈 important
    // });
    // AuctionPlayers.belongsTo(Player, {
    //   foreignKey: "playerId",
    //   onDelete: "CASCADE",
    // });
    // Auction.hasMany(BidHistory, {
    //   foreignKey: "auctionId",
    //   as: "bidHistory",
    //   onDelete: "CASCADE", // ✅
    // });
    // Auction.hasMany(AuctionResult, {
    //   foreignKey: "auctionId",
    //   as: "results",
    //   onDelete: "CASCADE", // ✅
    // });

    // // Player associations
    // Player.hasMany(BidHistory, {
    //   foreignKey: "playerId",
    //   as: "bidHistory",
    //   onDelete: "CASCADE", // ✅
    // });
    // Player.hasMany(AuctionResult, {
    //   foreignKey: "playerId",
    //   as: "auctionResults",
    //   onDelete: "CASCADE", // ✅
    // });

    // // BidHistory associations
    // BidHistory.belongsTo(Auction, {
    //   foreignKey: "auctionId",
    //   as: "auction",
    //   onDelete: "CASCADE",
    // });
    // BidHistory.belongsTo(Player, {
    //   foreignKey: "playerId",
    //   as: "player",
    //   onDelete: "CASCADE",
    // });

    // // AuctionResult associations
    // AuctionResult.belongsTo(Auction, {
    //   foreignKey: "auctionId",
    //   as: "auction",
    //   onDelete: "CASCADE",
    // });
    // AuctionResult.belongsTo(Player, {
    //   foreignKey: "playerId",
    //   as: "player",
    //   onDelete: "CASCADE", // ✅
    // });
    // User and UserAuctionBudget associations
    Auction.belongsToMany(User, {
      through: AuctionParticipants,
      foreignKey: "auctionId",
      otherKey: "userId",
      as: "participants",
      onDelete: "CASCADE",
    });
    User.belongsToMany(Auction, {
      through: AuctionParticipants,
      foreignKey: "userId",
      otherKey: "auctionId",
      as: "participatedAuctions",
      onDelete: "CASCADE",
    });
    Auction.hasMany(AuctionParticipants, {
      foreignKey: "auctionId",
      as: "auctionParticipants",
      onDelete: "CASCADE",
    });

    User.hasMany(AuctionParticipants, {
      foreignKey: "userId",
      as: "userParticipations",
      onDelete: "CASCADE",
    });

    AuctionParticipants.belongsTo(Auction, {
      foreignKey: "auctionId",
      as: "auction",
    });

    AuctionParticipants.belongsTo(User, {
      foreignKey: "userId",
      as: "user",
    });
    User.hasMany(UserAuctionBudget, {
      foreignKey: "userId",
      as: "auctionBudgets",
      onDelete: "CASCADE",
    });

    UserAuctionBudget.belongsTo(User, {
      foreignKey: "userId",
      as: "user",
    });

    // // Auction and UserAuctionBudget associations
    Auction.hasMany(UserAuctionBudget, {
      foreignKey: "auctionId",
      as: "userBudgets",
      onDelete: "CASCADE",
    });

    UserAuctionBudget.belongsTo(Auction, {
      foreignKey: "auctionId",
      as: "auction",
    });

    // Player Points associations
    PlayerPoints.belongsTo(Player, { foreignKey: "playerId" });
    Player.hasMany(PlayerPoints, { foreignKey: "playerId" });

    // User Leaderboard associations
    UserLeaderboard.belongsTo(User, { foreignKey: "userId" });
    User.hasMany(UserLeaderboard, { foreignKey: "userId" });

    UserLeaderboard.belongsTo(Auction, { foreignKey: "auctionId" });
    Auction.hasMany(UserLeaderboard, { foreignKey: "auctionId" });

    // AuctionResult associations

    // Sync all models (create tables if they don't exist)
    await sequelize.sync({ alter: false });
    // console.log("All models were synchronized successfully.");
  } catch (err) {
    console.log("--->", process.env.DBUSER);
    console.error("Unable to connect to the database:", err);
  }
};

module.exports = { sequelize, connectToDatabase };
