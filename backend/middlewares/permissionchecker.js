const Admin = require("../models/admin.model");

const checkPermission = (requiredPermission) => {
  return async (req, res, next) => {
    try {
      // Find the admin user
      const adminUser = await Admin.findByPk(req.user.id);

      // Super admin has all permissions
      if (adminUser.userId === "superadmin") {
        return next();
      }

      // Check if user has the required permission
      const userPermissions = adminUser.permissions || [];
      if (!userPermissions.includes(requiredPermission)) {
        return res.status(403).json({
          message: "Insufficient permissions",
        });
      }

      next();
    } catch (error) {
      console.error("Permission check error:", error);
      return res.status(500).json({
        message: "Error checking permissions",
      });
    }
  };
};

module.exports = { checkPermission };
