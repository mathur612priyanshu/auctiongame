const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const UserAuctionBudget = sequelize.define(
  "UserAuctionBudget",
  {
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: "Users",
        key: "id",
      },
    },
    auctionId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: "Auctions",
        key: "id",
      },
    },
    totalBudget: {
      type: DataTypes.INTEGER,
      defaultValue: 10000000, // 1 Cr default budget per auction
    },
    spentAmount: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    remainingBudget: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.totalBudget - this.spentAmount;
      },
    },
    playersCount: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    maxPlayers: {
      type: DataTypes.INTEGER,
      defaultValue: 25,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
    totalBidsPlaced: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    playersWon: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    lastBidAmount: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    joinedAt: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    indexes: [
      {
        unique: true,
        fields: ["userId", "auctionId"],
      },
    ],
  }
);

UserAuctionBudget.sync({ alter: false })
  .then(() => {
    console.log("UserAuctionBudget table created");
  })
  .catch((error) => {
    console.error("Error creating UserAuctionBudget table:", error);
  });

module.exports = UserAuctionBudget;
