const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

const User = require("../models/User");
const { nextSequence } = require("../models/Counter");
const { JWT_SECRET, JWT_EXPIRES_IN } = require("../middleware/auth");

const router = express.Router();

// login.dart reads response.body directly as the JWT string (on success) or
// as a plain error message (on failure), then decodes the token client-side
// without verifying it — so this must send raw text, not JSON.
router.post("/login", async (req, res) => {
  try {
    const { username, password } = req.body || {};
    if (!username || !password) {
      return res.status(400).send("Username and password are required");
    }

    const user = await User.findOne({ username: username.trim() });
    if (!user) return res.status(401).send("Invalid username or password");

    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.status(401).send("Invalid username or password");

    const token = jwt.sign(
      {
        user_id: user.user_id,
        username: user.username,
        role: user.role,
        message: `Welcome back, ${user.username}!`,
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    res.status(200).send(token);
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).send("Server error, please try again later.");
  }
});

// register.dart only special-cases 200 and 409; every other status shows
// response.body as the error message, so plain text works there too.
router.post("/register", async (req, res) => {
  try {
    const { username, email, password, repassword } = req.body || {};

    if (!username || !email || !password || !repassword) {
      return res.status(400).send("All fields are required");
    }
    if (password !== repassword) {
      return res.status(400).send("Passwords do not match");
    }

    const existing = await User.findOne({
      $or: [{ username: username.trim() }, { email: email.trim().toLowerCase() }],
    });
    if (existing) {
      return res.status(409).json({ message: "Username or email already taken" });
    }

    const hashed = await bcrypt.hash(password, 10);
    const user_id = await nextSequence("user_id");

    // Public registration always creates a student account; staff/lender
    // accounts are provisioned via `npm run seed` (see scripts/seed.js).
    await User.create({
      user_id,
      username: username.trim(),
      email: email.trim().toLowerCase(),
      password: hashed,
      role: "student",
    });

    res.status(200).json({ message: "Registered successfully" });
  } catch (err) {
    console.error("Register error:", err);
    res.status(500).send("Server error, please try again later.");
  }
});

module.exports = router;
