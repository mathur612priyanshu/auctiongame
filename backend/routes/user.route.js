const express = require("express");
const router = express.Router();
const User = require("../models/user.model");

// Get all users
router.get("/", async (req, res) => {
  try {
    const users = await User.findAll({
      order: [["createdAt", "DESC"]],
    });

    res.status(200).json({
      success: true,
      data: users,
      message: "Users fetched successfully",
    });
  } catch (error) {
    console.error("Error fetching users:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch users",
      error: error.message,
    });
  }
});

// Get user by ID
router.get("/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const user = await User.findByPk(id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.status(200).json({
      success: true,
      data: user,
      message: "User fetched successfully",
    });
  } catch (error) {
    console.error("Error fetching user:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch user",
      error: error.message,
    });
  }
});

// Update user status (activate/deactivate)
router.patch("/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { isActive } = req.body;

    const user = await User.findByPk(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    await user.update({ isActive });

    res.status(200).json({
      success: true,
      data: user,
      message: `User ${isActive ? "activated" : "deactivated"} successfully`,
    });
  } catch (error) {
    console.error("Error updating user status:", error);
    res.status(500).json({
      success: false,
      message: "Failed to update user status",
      error: error.message,
    });
  }
});

// Delete user
router.delete("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const user = await User.findByPk(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    await user.destroy();

    res.status(200).json({
      success: true,
      message: "User deleted successfully",
    });
  } catch (error) {
    console.error("Error deleting user:", error);
    res.status(500).json({
      success: false,
      message: "Failed to delete user",
      error: error.message,
    });
  }
});

// Update user points
router.patch("/:id/points", async (req, res) => {
  try {
    const { id } = req.params;
    const { points } = req.body;

    const user = await User.findByPk(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    await user.update({ points });

    res.status(200).json({
      success: true,
      data: user,
      message: "User points updated successfully",
    });
  } catch (error) {
    console.error("Error updating user points:", error);
    res.status(500).json({
      success: false,
      message: "Failed to update user points",
      error: error.message,
    });
  }
});

module.exports = router;
