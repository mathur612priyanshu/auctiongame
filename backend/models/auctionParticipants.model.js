const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const AuctionParticipants = sequelize.define(
  "AuctionParticipants",
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    auctionId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: "Auctions",
        key: "id",
      },
      onDelete: "CASCADE",
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: "Users",
        key: "id",
      },
      onDelete: "CASCADE",
    },
    joinedAt: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
    status: {
      type: DataTypes.ENUM("active", "left", "banned"),
      defaultValue: "active",
    },
  },
  {
    tableName: "AuctionParticipants",
    timestamps: true,
    indexes: [
      {
        unique: true,
        fields: ["auctionId", "userId"], // Prevent duplicate entries
      },
    ],
  }
);

module.exports = AuctionParticipants;
