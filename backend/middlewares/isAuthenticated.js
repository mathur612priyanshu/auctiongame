const jwt = require("jsonwebtoken");

const isAuthenticated = (req, res, next) => {
  try {
    const token = req.headers.authorization.split(" ")[1];
    const secret = process.env.JWT_SECRET || "secretKey";
    jwt.verify(token, secret, (err, user) => {
      if (err) {
        res.status(404).json(err);
      } else {
        req.user = user;
        next();
      }
    });
  } catch (err) {
    return res.status(404).json(err);
  }
};

module.exports = {
  isAuthenticated,
};
