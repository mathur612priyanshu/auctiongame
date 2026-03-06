const jwt = require("jsonwebtoken");
const Admin = require("../models/admin.model");
const Role = require("../models/role.model");

// Middleware to authenticate admin JWT token
exports.authenticateAdmin = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ message: "Authentication required" });
    }

    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET_ADMIN || "your-secret-key"
    );

    // Check if admin exists and is active
    const admin = await Admin.findOne({
      where: { id: decoded.id, isActive: true },
      include: [{ model: Role }],
    });

    if (!admin) {
      return res
        .status(401)
        .json({ message: "Invalid token or inactive account" });
    }

    // Add admin info to request object
    req.user = decoded;
    req.user.isAdmin = true;

    next();
  } catch (error) {
    console.error("Admin authentication error:", error);
    if (error.name === "TokenExpiredError") {
      return res.status(401).json({ message: "Token expired" });
    }
    res.status(401).json({ message: "Authentication failed" });
  }
};

exports.hasPermission = (permissionName) => {
  return (req, res, next) => {
    if (!req.user || !req.user.isAdmin) {
      return res
        .status(403)
        .json({ message: "Forbidden: Admin access required" });
    }

    // Super admin has all permissions
    if (req.user.role === "super_admin") {
      return next();
    }

    // Check if admin has the required permission
    if (
      !req.user.permissions ||
      !req.user.permissions.includes(permissionName)
    ) {
      return res.status(403).json({
        message: `Forbidden: You don't have the required permission (${permissionName})`,
      });
    }

    next();
  };
};
exports.hasPermission = (permissionName) => {
  return (req, res, next) => {
    if (!req.user || !req.user.isAdmin) {
      return res
        .status(403)
        .json({ message: "Forbidden: Admin access required" });
    }

    // Super admin has all permissions
    if (req.user.role === "super_admin") {
      return next();
    }

    // Check if admin has the required permission
    if (
      !req.user.permissions ||
      !req.user.permissions.includes(permissionName)
    ) {
      return res.status(403).json({
        message: `Forbidden: You don't have the required permission (${permissionName})`,
      });
    }

    next();
  };
};
