// One-off setup script: creates the staff/lender accounts (public /register
// always creates students — see routes/auth.js) and a few sample assets.
// Run with: npm run seed
require("dotenv").config();

const bcrypt = require("bcryptjs");
const connectDB = require("../config/db");
const User = require("../models/User");
const Asset = require("../models/Asset");
const { nextSequence } = require("../models/Counter");

const USERS = [
  { username: "staff1", email: "staff1@example.com", password: "staff123", role: "staff" },
  { username: "lender1", email: "lender1@example.com", password: "lender123", role: "lender" },
];

const ASSETS = [
  { name: "Football", description: "Sport Equipment" },
  { name: "Basketball", description: "Sport Equipment" },
  { name: "Badminton Set", description: "Sport Equipment" },
];

async function seedUsers() {
  for (const u of USERS) {
    const exists = await User.findOne({ username: u.username });
    if (exists) {
      console.log(`- user "${u.username}" already exists, skipping`);
      continue;
    }
    const user_id = await nextSequence("user_id");
    const hashed = await bcrypt.hash(u.password, 10);
    await User.create({ user_id, username: u.username, email: u.email, password: hashed, role: u.role });
    console.log(`+ created ${u.role} "${u.username}" (password: ${u.password})`);
  }
}

async function seedAssets() {
  for (const a of ASSETS) {
    const exists = await Asset.findOne({ name: a.name });
    if (exists) {
      console.log(`- asset "${a.name}" already exists, skipping`);
      continue;
    }
    const asset_id = await nextSequence("asset_id");
    await Asset.create({ asset_id, name: a.name, description: a.description });
    console.log(`+ created asset "${a.name}"`);
  }
}

(async () => {
  await connectDB();
  await seedUsers();
  await seedAssets();
  console.log("Seed complete.");
  process.exit(0);
})().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
