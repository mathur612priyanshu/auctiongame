const Player = require("../models/player.model");
const PlayerGroup = require("../models/playerGroup.model");
const xlsx = require("xlsx");
const path = require("path");
const { Op } = require("sequelize");
const { sequelize: dbSequelize } = require("../config/database");

// Configure multer for file upload

// Create a new player
const createPlayer = async (req, res) => {
  try {
    const {
      name,
      basePrice,
      role,
      team,
      category,
      type,
      statistics,
      metadata,
    } = req.body;

    if (!name || !basePrice || !category || !type) {
      return res.status(400).json({
        success: false,
        message: "Name, basePrice, category, and type are required",
      });
    }

    const player = await Player.create({
      name,
      basePrice,
      role,
      team,
      category,
      type,
      statistics: statistics || {},
      metadata: metadata || {},
    });

    res.status(201).json({
      success: true,
      message: "Player created successfully",
      data: player,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error creating player",
      error: error.message,
    });
  }
};

// Bulk upload players from Excel

const bulkUploadPlayers = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "Excel file is required",
      });
    }

    // Get group name from request body
    const { playerGroup } = req.body;

    const workbook = xlsx.read(req.file.buffer, { type: "buffer" });
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const rows = xlsx.utils.sheet_to_json(worksheet, { header: 1 });

    if (rows.length < 2) {
      return res.status(400).json({
        success: false,
        message: "Excel file doesn't have enough data",
      });
    }

    const headers = rows[0];
    const playersToCreate = [];
    const errors = [];

    for (let i = 1; i < rows.length; i++) {
      const row = rows[i];
      const name = row[0];

      try {
        const playerData = {};
        for (let j = 1; j < headers.length; j++) {
          playerData[headers[j]] = row[j];
        }

        if (
          !name ||
          !playerData.price ||
          !playerData.category ||
          !playerData.type
        ) {
          errors.push({
            row: i + 1,
            error: "Missing required fields: name, price, category, or type",
            data: { name, ...playerData },
          });
          continue;
        }

        const statistics = buildStatistics(playerData, playerData.category);

        const player = {
          name: name,
          basePrice: parseFloat(playerData.price) || 100000,
          role: playerData.type || null,
          team: playerData.team || null,
          category: playerData.category,
          type: playerData.type,
          playerGroup: playerGroup || null, // Add group to each player
          statistics: statistics,
          imageurl: playerData.imageurl,
          matches: playerData.matches || 0,
          metadata: {
            average: playerData.average || null,
            uploadedAt: new Date(),
            source: "bulk_upload",
            group: playerGroup || null,
          },
        };

        playersToCreate.push(player);
      } catch (error) {
        errors.push({
          row: i + 1,
          error: error.message,
          data: row,
        });
      }
    }

    let createdPlayers = [];
    if (playersToCreate.length > 0) {
      createdPlayers = await Player.bulkCreate(playersToCreate, {
        validate: true,
        ignoreDuplicates: false,
      });
    }

    res.status(201).json({
      success: true,
      message: `Bulk upload completed. ${
        createdPlayers.length
      } players created${playerGroup ? ` in group "${playerGroup}"` : ""}.`,
      data: {
        created: createdPlayers.length,
        errors: errors.length,
        errorDetails: errors,
        group: playerGroup,
      },
    });
  } catch (error) {
    console.log("Bulk upload error =>", error);
    res.status(500).json({
      success: false,
      message: "Error in bulk upload",
      error: error.message,
    });
  }
};

// Helper function to build statistics based on sport category
const buildStatistics = (data, category) => {
  const statistics = {};

  switch (category.toLowerCase()) {
    case "cricket":
      if (data["2024 RUNS"])
        statistics.runs2024 = parseInt(data["2024 RUNS"]) || 0;
      if (data["2024 WKTS"])
        statistics.wickets2024 = parseInt(data["2024 WKTS"]) || 0;
      if (data["2023 RUNS"])
        statistics.runs2023 = parseInt(data["2023 RUNS"]) || 0;
      if (data["2023 WKTS"])
        statistics.wickets2023 = parseInt(data["2023 WKTS"]) || 0;
      break;

    case "football":
      if (data["2024 GOALS"])
        statistics.goals2024 = parseInt(data["2024 GOALS"]) || 0;
      if (data["2024 ASSISTS"])
        statistics.assists2024 = parseInt(data["2024 ASSISTS"]) || 0;
      if (data["2023 GOALS"])
        statistics.goals2023 = parseInt(data["2023 GOALS"]) || 0;
      if (data["2023 ASSISTS"])
        statistics.assists2023 = parseInt(data["2023 ASSISTS"]) || 0;
      break;

    case "basketball":
      if (data["2024 POINTS"])
        statistics.points2024 = parseInt(data["2024 POINTS"]) || 0;
      if (data["2024 REBOUNDS"])
        statistics.rebounds2024 = parseInt(data["2024 REBOUNDS"]) || 0;
      if (data["2023 POINTS"])
        statistics.points2023 = parseInt(data["2023 POINTS"]) || 0;
      if (data["2023 REBOUNDS"])
        statistics.rebounds2023 = parseInt(data["2023 REBOUNDS"]) || 0;
      break;

    default:
      // For unknown sports, store all numeric fields as statistics
      Object.keys(data).forEach((key) => {
        if (typeof data[key] === "number" || !isNaN(data[key])) {
          statistics[key.toLowerCase().replace(/\s+/g, "_")] =
            parseFloat(data[key]) || 0;
        }
      });
  }

  return statistics;
};

// Get all players (with optional pagination/search)
const getAllPlayers = async (req, res) => {
  try {
    const {
      category = "",
      type = "",
      team = "",
      search = "",
      page = 1,
      limit = 10,
      sort = "name_asc", // name_asc | name_desc | created_desc | created_asc
      paginated = "false", // preserve old array response by default
    } = req.query;

    // Build where clause
    const whereClause = {};
    if (category && category !== "all") whereClause.category = category;
    if (type && type !== "all") whereClause.type = type;
    if (team && team !== "all") whereClause.team = team;

    if (search && String(search).trim().length > 0) {
      const s = String(search).trim();
      const orConds = [{ name: { [Op.like]: `%${s}%` } }];
      const idNum = Number(s);
      if (!Number.isNaN(idNum)) {
        orConds.push({ id: idNum });
      }
      // Optionally allow team LIKE search too
      orConds.push({ team: { [Op.like]: `%${s}%` } });
      whereClause[Op.or] = orConds;
    }

    // Determine order
    let order;
    switch (sort) {
      case "name_desc":
        order = [["name", "DESC"]];
        break;
      case "created_desc":
        order = [["createdAt", "DESC"]];
        break;
      case "created_asc":
        order = [["createdAt", "ASC"]];
        break;
      case "name_asc":
      default:
        order = [["name", "ASC"]];
        break;
    }

    if (paginated !== "true") {
      // Backward compatible: return simple array
      const players = await Player.findAll({ where: whereClause, order });

      return res.status(200).json({
        success: true,
        message: "Players retrieved successfully",
        data: players,
      });
    }

    // Paginated path
    const pageNum = Math.max(parseInt(page) || 1, 1);
    const pageSize = Math.min(Math.max(parseInt(limit) || 10, 1), 100);
    const offset = (pageNum - 1) * pageSize;

    const result = await Player.findAndCountAll({
      where: whereClause,
      order,
      offset,
      limit: pageSize,
    });

    const total = result.count;
    const totalPages = Math.max(Math.ceil(total / pageSize), 1);

    res.status(200).json({
      success: true,
      message: "Players retrieved successfully",
      data: {
        items: result.rows,
        pagination: {
          total,
          page: pageNum,
          limit: pageSize,
          totalPages,
          hasNext: pageNum < totalPages,
          hasPrev: pageNum > 1,
        },
      },
    });
  } catch (error) {
    console.log("Error retrieving players =>", error);
    res.status(500).json({
      success: false,
      message: "Error retrieving players",
      error: error.message,
    });
  }
};

// Get player by ID
const getPlayerById = async (req, res) => {
  try {
    const { id } = req.params;
    const player = await Player.findByPk(id);

    if (!player) {
      return res.status(404).json({
        success: false,
        message: "Player not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Player retrieved successfully",
      data: player,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving player",
      error: error.message,
    });
  }
};

// Update player
const updatePlayer = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    const player = await Player.findByPk(id);

    if (!player) {
      return res.status(404).json({
        success: false,
        message: "Player not found",
      });
    }

    await player.update(updateData);

    res.status(200).json({
      success: true,
      message: "Player updated successfully",
      data: player,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error updating player",
      error: error.message,
    });
  }
};

// Delete player
const deletePlayer = async (req, res) => {
  try {
    const { id } = req.params;
    const player = await Player.findByPk(id);

    if (!player) {
      return res.status(404).json({
        success: false,
        message: "Player not found",
      });
    }

    await player.destroy();

    res.status(200).json({
      success: true,
      message: "Player deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error deleting player",
      error: error.message,
    });
  }
};

// Get players by role
const getPlayersByRole = async (req, res) => {
  try {
    const { role } = req.params;
    const players = await Player.findAll({
      where: { role },
    });

    res.status(200).json({
      success: true,
      message: `Players with role ${role} retrieved successfully`,
      data: players,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving players by role",
      error: error.message,
    });
  }
};

// Get players by team
const getPlayersByTeam = async (req, res) => {
  try {
    const { team } = req.params;
    const players = await Player.findAll({
      where: { team },
    });

    res.status(200).json({
      success: true,
      message: `Players from team ${team} retrieved successfully`,
      data: players,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving players by team",
      error: error.message,
    });
  }
};

// Get players by category (sport)
const getPlayersByCategory = async (req, res) => {
  try {
    const { category } = req.params;
    const players = await Player.findAll({
      where: { category },
    });

    res.status(200).json({
      success: true,
      message: `Players from category ${category} retrieved successfully`,
      data: players,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving players by category",
      error: error.message,
    });
  }
};
const getPlayerGroups = async (req, res) => {
  try {
    const { category } = req.query;

    const whereClause = { playerGroup: { [Op.ne]: null } };
    if (category) whereClause.category = category;

    // Use a single query with COUNT to get groups and their player counts
    const groupsWithCount = await Player.findAll({
      where: whereClause,
      attributes: [
        "playerGroup",
        "category",
        [dbSequelize.fn("COUNT", dbSequelize.col("id")), "playerCount"],
      ],
      group: ["playerGroup", "category"],
      raw: true,
    });

    const formattedGroups = groupsWithCount.map((group) => ({
      groupName: group.playerGroup,
      category: group.category,
      playerCount: parseInt(group.playerCount) || 0,
    }));

    res.status(200).json({
      success: true,
      message: "Player groups retrieved successfully",
      data: formattedGroups,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving player groups",
      error: error.message,
    });
  }
};

// New optimized endpoint to get groups with their auctions and registration status
const getPlayerGroupsWithAuctions = async (req, res) => {
  try {
    const { category, userId } = req.query;
    const Auction = require("../models/auction.model");
    const AuctionParticipants = require("../models/auctionParticipants.model");
    const AuctionPlayers = require("../models/auctionPlayers.model");

    console.log(
      "🔍 Fetching player groups with auctions - category:",
      category,
      "userId:",
      userId
    );

    const whereClause = { playerGroup: { [Op.ne]: null } };
    if (category) whereClause.category = category;

    // Get groups with player counts
    const groupsWithCount = await Player.findAll({
      where: whereClause,
      attributes: [
        "playerGroup",
        "category",
        [dbSequelize.fn("COUNT", dbSequelize.col("id")), "playerCount"],
      ],
      group: ["playerGroup", "category"],
      raw: true,
    });

    console.log("📊 Found groups:", groupsWithCount.length);

    // Get all PlayerGroup records to check status
    const allPlayerGroupRecords = await PlayerGroup.findAll({
      attributes: ["groupName", "isActive"],
      raw: true,
    });

    // Filter groups to only include active ones
    const activeGroups = groupsWithCount.filter((group) => {
      // If group doesn't exist in PlayerGroup table, consider it active (backward compatibility)
      // If it exists, check isActive status
      const playerGroupRecord = allPlayerGroupRecords.find(
        (pg) => pg.groupName === group.playerGroup
      );
      return playerGroupRecord ? playerGroupRecord.isActive : true;
    });

    console.log("📊 Active groups after filtering:", activeGroups.length);

    // Get user's registrations if userId provided
    let userRegistrations = [];
    if (userId) {
      userRegistrations = await AuctionParticipants.findAll({
        where: { userId, status: "active" },
        attributes: ["auctionId"],
        raw: true,
      });
    }

    const userRegisteredAuctions = new Set(
      userRegistrations.map((reg) => reg.auctionId)
    );

    // Use a more efficient query with joins to get group-specific auctions
    const formattedGroups = await Promise.all(
      activeGroups.map(async (group) => {
        console.log(
          `🔍 Processing group: ${group.playerGroup} (${group.category})`
        );

        // Get auctions that contain players from this specific group using a single query
        const groupAuctions = await dbSequelize.query(
          `
          SELECT DISTINCT 
            a.id, 
            a.name, 
            a.status, 
            a.category, 
            a.type, 
            a.startTime,
            a.entryAmount
          FROM Auctions a
          INNER JOIN AuctionPlayers ap ON a.id = ap.auctionId
          INNER JOIN Players p ON ap.playerId = p.id
          WHERE p.playerGroup = :playerGroup 
            AND p.category = :category
          ORDER BY a.startTime ASC
        `,
          {
            replacements: {
              playerGroup: group.playerGroup,
              category: group.category,
            },
            type: dbSequelize.QueryTypes.SELECT,
          }
        );

        console.log(
          `📋 Group ${group.playerGroup} has ${groupAuctions.length} auctions`
        );

        const formattedAuctions = groupAuctions.map((auction) => ({
          id: auction.id,
          name: auction.name,
          status: auction.status,
          category: auction.category,
          type: auction.type,
          startTime: auction.startTime,
          entryAmount: auction.entryAmount || "NA",

          isRegistered: userRegisteredAuctions.has(auction.id),
        }));
        console.log(
          `✅ Formatted ${formattedAuctions} auctions for group ${group.playerGroup}`
        );
        const liveAuctions = formattedAuctions.filter(
          (a) => a.status === "ongoing"
        ).length;

        return {
          groupName: group.playerGroup,
          category: group.category,
          playerCount: parseInt(group.playerCount) || 0,
          auctions: formattedAuctions,
          auctionCount: formattedAuctions.length,
          liveAuctions,
        };
      })
    );

    console.log("✅ Successfully processed all groups");

    res.status(200).json({
      success: true,
      message: "Player groups with auctions retrieved successfully",
      data: formattedGroups,
    });
  } catch (error) {
    console.error("❌ Error retrieving player groups with auctions:", error);
    res.status(500).json({
      success: false,
      message: "Error retrieving player groups with auctions",
      error: error.message,
    });
  }
};

// Get players by group
const getPlayersByGroup = async (req, res) => {
  try {
    const { groupName } = req.params;
    const players = await Player.findAll({
      where: { playerGroup: groupName },
      order: [["name", "ASC"]],
    });

    res.status(200).json({
      success: true,
      message: `Players from group ${groupName} retrieved successfully`,
      data: players,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving players by group",
      error: error.message,
    });
  }
};

// Get all player groups for admin panel (including disabled ones)
const getAllPlayerGroupsForAdmin = async (req, res) => {
  try {
    const { category } = req.query;

    const whereClause = { playerGroup: { [Op.ne]: null } };
    if (category) whereClause.category = category;

    // Get groups with player counts
    const groupsWithCount = await Player.findAll({
      where: whereClause,
      attributes: [
        "playerGroup",
        "category",
        [dbSequelize.fn("COUNT", dbSequelize.col("id")), "playerCount"],
      ],
      group: ["playerGroup", "category"],
      raw: true,
    });

    // Get PlayerGroup records to check status
    const playerGroupRecords = await PlayerGroup.findAll({
      attributes: [
        "groupName",
        "isActive",
        "description",
        "disabledAt",
        "disabledBy",
      ],
      raw: true,
    });

    const playerGroupMap = new Map(
      playerGroupRecords.map((pg) => [pg.groupName, pg])
    );

    const formattedGroups = groupsWithCount.map((group) => {
      const groupRecord = playerGroupMap.get(group.playerGroup);
      return {
        playergroup: group.playerGroup,
        playerGroup: group.playerGroup,
        category: group.category,
        playerCount: parseInt(group.playerCount) || 0,
        isActive: groupRecord ? groupRecord.isActive : true, // Default to active if no record
        description: groupRecord?.description || null,
        disabledAt: groupRecord?.disabledAt || null,
        disabledBy: groupRecord?.disabledBy || null,
      };
    });

    res.status(200).json({
      success: true,
      message: "Player groups retrieved successfully",
      data: formattedGroups,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving player groups",
      error: error.message,
    });
  }
};

const getAllPlayerGroupsForAdminActive = async (req, res) => {
  try {
    const { category } = req.query;

    try {
      // Log the query for debugging
      console.log("Fetching active player groups with category:", category);

      // First, check if we have any active groups
      const activeGroups = await PlayerGroup.findAll({
        where: { isActive: true },
        raw: true,
      });

      console.log("Active groups found:", activeGroups.length);

      if (activeGroups.length === 0) {
        console.log("No active groups found in the database");
        return res.status(200).json({
          success: true,
          message: "No active player groups found",
          data: [],
        });
      }

      // Build the WHERE clause based on category
      let whereClause = "WHERE p.playerGroup IS NOT NULL";
      if (category) {
        whereClause += ` AND p.category = '${category.replace(/'/g, "''")}'`;
      }

      // Get the table names from the models
      const playerTableName = Player.tableName || "Players";
      const groupTableName = PlayerGroup.tableName || "PlayerGroups";

      // Use raw query to get active player groups with counts
      const query = `
        SELECT 
          p.playerGroup as groupName,
          p.category,
          COUNT(p.id) as playerCount
        FROM ${playerTableName} p
        INNER JOIN ${groupTableName} pg 
          ON p.playerGroup = pg.groupName
        WHERE pg.isActive = 1 OR pg.isActive = true

        ${category ? `AND p.category = '${category.replace(/'/g, "''")}'` : ""}
        GROUP BY p.playerGroup, p.category
      `;

      console.log("Executing query:", query);

      const results = await dbSequelize.query(query, {
        type: dbSequelize.QueryTypes.SELECT,
      });

      console.log("Query results:", JSON.stringify(results, null, 2));

      const formattedGroups = results.map((group) => ({
        groupName: group.groupName,
        category: group.category,
        playerCount: parseInt(group.playerCount) || 0,
      }));

      return res.status(200).json({
        success: true,
        message: "Active player groups retrieved successfully",
        data: formattedGroups,
      });
    } catch (error) {
      console.error("Error in getAllPlayerGroupsForAdminActive:", error);
      return res.status(500).json({
        success: false,
        message: "Error retrieving player groups",
        error: error.message,
      });
    }
  } catch (error) {
    console.error("Outer error in getAllPlayerGroupsForAdminActive:", error);
    return res.status(500).json({
      success: false,
      message: "Error retrieving player groups",
      error: error.message,
    });
  }
};
// Disable/Enable a player group
const togglePlayerGroupStatus = async (req, res) => {
  try {
    const { groupName } = req.params;
    const { isActive, disabledBy } = req.body;

    // Check if group exists in Player table
    const groupExists = await Player.findOne({
      where: { playerGroup: groupName },
    });

    if (!groupExists) {
      return res.status(404).json({
        success: false,
        message: "Player group not found",
      });
    }

    // Find or create PlayerGroup record
    let playerGroup = await PlayerGroup.findOne({
      where: { groupName },
    });

    if (!playerGroup) {
      // Create new PlayerGroup record
      playerGroup = await PlayerGroup.create({
        groupName,
        category: groupExists.category,
        isActive: isActive !== undefined ? isActive : true,
        disabledAt: isActive === false ? new Date() : null,
        disabledBy: isActive === false ? disabledBy : null,
      });
    } else {
      // Update existing record
      await playerGroup.update({
        isActive: isActive !== undefined ? isActive : !playerGroup.isActive,
        disabledAt: isActive === false ? new Date() : null,
        disabledBy: isActive === false ? disabledBy : null,
      });
    }

    res.status(200).json({
      success: true,
      message: `Player group ${
        isActive === false ? "disabled" : "enabled"
      } successfully`,
      data: playerGroup,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error updating player group status",
      error: error.message,
    });
  }
};

// Sync PlayerGroup records with existing player groups
const syncPlayerGroups = async (req, res) => {
  try {
    // Get all unique player groups from Player table
    const playerGroups = await Player.findAll({
      where: { playerGroup: { [Op.ne]: null } },
      attributes: [
        "playerGroup",
        "category",
        [dbSequelize.fn("COUNT", dbSequelize.col("id")), "playerCount"],
      ],
      group: ["playerGroup", "category"],
      raw: true,
    });

    let created = 0;
    let updated = 0;

    for (const group of playerGroups) {
      const [playerGroup, wasCreated] = await PlayerGroup.findOrCreate({
        where: { groupName: group.playerGroup },
        defaults: {
          groupName: group.playerGroup,
          category: group.category,
          isActive: true,
          playerCount: parseInt(group.playerCount) || 0,
        },
      });

      if (wasCreated) {
        created++;
      } else {
        // Update player count
        await playerGroup.update({
          playerCount: parseInt(group.playerCount) || 0,
        });
        updated++;
      }
    }

    res.status(200).json({
      success: true,
      message: `Sync completed. Created: ${created}, Updated: ${updated}`,
      data: { created, updated },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error syncing player groups",
      error: error.message,
    });
  }
};

module.exports = {
  createPlayer,
  bulkUploadPlayers,
  getAllPlayers,
  getPlayerById,
  updatePlayer,
  deletePlayer,
  getPlayersByRole,
  getPlayersByTeam,
  getPlayersByCategory,
  getPlayerGroups,
  getPlayerGroupsWithAuctions,
  getPlayersByGroup,
  getAllPlayerGroupsForAdmin,
  togglePlayerGroupStatus,
  syncPlayerGroups,
  getAllPlayerGroupsForAdminActive,
};
