const setupAssociations = () => {
  const Auction = require("../models/auction.model");
  const Player = require("../models/player.model");
  const AuctionPlayers = require("../models/auctionPlayers.model");
  const BidHistory = require("../models/bidHistory.model");
  const AuctionResult = require("../models/auctionresult.model");
const User = require("../models/user.model");

  // Many-to-many relationship
  Auction.belongsToMany(Player, {
    through: AuctionPlayers,
    foreignKey: "auctionId",
    otherKey: "playerId",
    as: "players",
    onDelete: "CASCADE",
  });

  Player.belongsToMany(Auction, {
    through: AuctionPlayers,
    foreignKey: "playerId",
    otherKey: "auctionId",
    as: "auctions",
    onDelete: "CASCADE",
  });

  // Junction table associations
  Auction.hasMany(AuctionPlayers, {
    foreignKey: "auctionId",
    onDelete: "CASCADE",
  });

  Player.hasMany(AuctionPlayers, {
    foreignKey: "playerId",
    onDelete: "CASCADE",
  });

  AuctionPlayers.belongsTo(Auction, {
    foreignKey: "auctionId",
    onDelete: "CASCADE",
  });

  AuctionPlayers.belongsTo(Player, {
    foreignKey: "playerId",
    onDelete: "CASCADE",
  });

  // Other associations
  Auction.hasMany(BidHistory, {
    foreignKey: "auctionId",
    as: "bidHistory",
    onDelete: "CASCADE",
  });

  Auction.hasMany(AuctionResult, {
    foreignKey: "auctionId",
    as: "results",
    onDelete: "CASCADE",
  });

  Player.hasMany(BidHistory, {
    foreignKey: "playerId",
    as: "bidHistory",
    onDelete: "CASCADE",
  });

  Player.hasMany(AuctionResult, {
    foreignKey: "playerId",
    as: "auctionResults",
    onDelete: "CASCADE",
  });

  BidHistory.belongsTo(Auction, {
    foreignKey: "auctionId",
    as: "auction",
    onDelete: "CASCADE",
  });

  BidHistory.belongsTo(Player, {
    foreignKey: "playerId",
    as: "player",
    onDelete: "CASCADE",
  });

  AuctionResult.belongsTo(Auction, {
    foreignKey: "auctionId",
    as: "auction",
    onDelete: "CASCADE",
  });

  AuctionResult.belongsTo(Player, {
    foreignKey: "playerId",
    as: "player",
    onDelete: "CASCADE",
  });

  // Add association for winner
  AuctionResult.belongsTo(User, {
    foreignKey: "winnerId",
    as: "winner",
    onDelete: "SET NULL",
  });

  console.log("All associations have been set up successfully.");
};

module.exports = { setupAssociations };
