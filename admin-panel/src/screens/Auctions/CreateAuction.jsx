import React, { useEffect, useState } from "react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "@/components/ui/select";
import { MultiSelect } from "@/components/multi-select";
import axios from "axios";
import { API_URL } from "@/constants";
import { toast } from "sonner";
import { useNavigate } from "react-router-dom";
import { Tabs } from "@radix-ui/react-tabs";
import { TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Checkbox } from "@/components/ui/checkbox";

const CreateAuction = () => {
  const navigate = useNavigate();

  const [allPlayers, setAllplayers] = useState([]);
  const [playerGroups, setPlayerGroups] = useState([]);

  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({
    name: "",
    category: "",
    type: "",
    minPlayers: "",
    selectedPlayers: [], // This will store player objects
    startTime: "",
    selectedGroups: [], // Add selected groups
    captain: "",
    vicecaptain: "",
    runPoint: 1, // Default value for run point
    wicketPoint: 10, // Default value for wicket point
    countedPlayers: 0,
    // endTime: "",
  });

  useEffect(() => {
    if (form.category) {
      fetchPlayers();
      fetchPlayerGroups();
    } else {
      setAllplayers([]);
      setPlayerGroups([]);
      setForm((prev) => ({
        ...prev,
        selectedPlayers: [],
        selectedGroups: [],
      }));
    }
  }, [form.category]);

  const fetchPlayerGroups = async () => {
    try {
      const res = await axios.get(
        `${API_URL}/player/groups-admin-isActive?category=${form.category}`
      );

      if (res.status === 200 && res.data.success) {
        setPlayerGroups(res.data.data);
      }
    } catch (error) {
      console.log("Error fetching player groups:", error);
      toast.error("Failed to fetch player groups");
    }
  };

  const fetchPlayers = async () => {
    try {
      const res = await axios.get(
        `${API_URL}/player/category/${form.category}`
      );

      if (res.status === 200 && res.data.success) {
        const players = res.data.data.map((player) => ({
          id: player.id.toString(), // Ensure ID is string for consistency
          name: `${player.name} (${
            player.role || player.type
          }) - ₹${formatPrice(player.basePrice)}`,
          originalName: player.name,
          role: player.role,
          type: player.type,
          basePrice: player.basePrice,
          category: player.category,
        }));
        setAllplayers(players);
      }
    } catch (error) {
      console.log("Error fetching players:", error);
      toast.error("Failed to fetch players");
    }
  };
  const handleGroupSelection = async (groupName, isSelected) => {
    try {
      if (isSelected) {
        // Add group to selected groups
        setForm((prev) => ({
          ...prev,
          selectedGroups: [...prev.selectedGroups, groupName],
        }));

        // Fetch players from this group and add to selected players
        const res = await axios.get(`${API_URL}/player/group/${groupName}`);

        if (res.status === 200 && res.data.success) {
          const groupPlayers = res.data.data.map((player) => ({
            id: player.id.toString(),
            name: `${player.name} (${
              player.role || player.type
            }) - ₹${formatPrice(player.basePrice)}`,
            originalName: player.name,
            role: player.role,
            type: player.type,
            basePrice: player.basePrice,
            category: player.category,
            playerGroup: player.playerGroup,
          }));

          setForm((prev) => {
            const existingPlayerIds = prev.selectedPlayers.map((p) => p.id);
            const newPlayers = groupPlayers.filter(
              (p) => !existingPlayerIds.includes(p.id)
            );

            return {
              ...prev,
              selectedPlayers: [...prev.selectedPlayers, ...newPlayers],
            };
          });
        }
      } else {
        // Remove group from selected groups
        setForm((prev) => ({
          ...prev,
          selectedGroups: prev.selectedGroups.filter((g) => g !== groupName),
        }));

        // Remove all players from this group from selected players
        setForm((prev) => ({
          ...prev,
          selectedPlayers: prev.selectedPlayers.filter(
            (p) => p.playerGroup !== groupName
          ),
        }));
      }
    } catch (error) {
      console.log("Error handling group selection:", error);
      toast.error("Failed to handle group selection");
    }
  };

  const formatPrice = (price) => {
    return new Intl.NumberFormat("en-IN", {
      maximumFractionDigits: 0,
    }).format(price);
  };

  const handleChange = (field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSubmit = async () => {
    try {
      // Validation
      if (!form.name || !form.category) {
        alert("Please fill in all required fields");
        return;
      }

      // if (form.minPlayers) {
      //   alert("Minimum players cannot be greater than maximum players");
      //   return;
      // }

      if (form.selectedPlayers.length < 3) {
        alert(`Cannot select less than 3 players`);
        return;
      }

      setLoading(true);

      // Extract player IDs from selected players
      const selectedPlayerIds = form.selectedPlayers.map((player) => {
        const playerId = typeof player === "object" ? player.id : player;
        return parseInt(playerId);
      });

      console.log("Selected Player IDs:", selectedPlayerIds);

      // Prepare data for API
      const auctionData = {
        name: form.name,
        category: form.category,
        // type: form.type,
        // maxPlayers: parseInt(form.maxPlayers),
        minPlayers: form.minPlayers ? parseInt(form.minPlayers) : null,
        startTime: form.startTime || null,
        endTime: form.endTime || null,
        selectedPlayers: selectedPlayerIds,
        runPoint: form.runPoint ? parseInt(form.runPoint) : 1,
        wicketPoint: form.wicketPoint ? parseInt(form.wicketPoint) : 10,
        maxPlayerAllowed: form.maxPlayerAllowed ? parseInt(form.maxPlayerAllowed) : null,
        entryAmount: form.entryAmount ? parseInt(form.entryAmount) : null,
        captain: form.captain ? parseInt(form.captain) : null,
        vicecaptain: form.vicecaptain ? parseInt(form.vicecaptain) : null,
        countedPlayers: form.countedPlayers ? parseInt(form.countedPlayers) : null,

      };

      console.log("Creating auction with data:", auctionData);

      const response = await axios.post(`${API_URL}/auction`, auctionData);

      if (response.data.success) {
        toast.success("Auction has been created successfully!");
        navigate("/auctions");
      } else {
        alert("Failed to create auction");
      }
    } catch (error) {
      console.error("Error creating auction:", error);
      alert(error.response?.data?.message || "Failed to create auction");
    } finally {
      setLoading(false);
    }
  };
  const [totalPool, setTotalPool] = useState();
  useEffect(() => {
    let finalamount = form.minPlayers * form.entryAmount;
    const finalafterReduction = finalamount - (finalamount * 20) / 100;
    setTotalPool(finalafterReduction);
  }, [form]);
  return (
    <Card className="mx-auto p-6 space-y-6 border-none">
      <CardHeader>
        <CardTitle>
          <div>Create New Auction</div>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <Label htmlFor="name">Auction Name *</Label>
          <Input
            id="name"
            value={form.name}
            onChange={(e) => handleChange("name", e.target.value)}
            placeholder="Enter auction name"
          />
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <Label htmlFor="category">Category *</Label>
            <Select onValueChange={(val) => handleChange("category", val)}>
              <SelectTrigger>
                <SelectValue placeholder="Select Category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="cricket">Cricket</SelectItem>
                <SelectItem value="football">Football</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <Label htmlFor="name">Registration Fee * </Label>
            <Input
              id="entryAmount"
              required
              value={form.entryAmount}
              onChange={(e) => handleChange("entryAmount", e.target.value)}
              placeholder="Enter amount"
              type="number"
              min="0"
            />
          </div>
          <div>
            <Label htmlFor="name">Counted Players * </Label>
            <Input
              id="countedPlayers"
              required
              value={form.countedPlayers}
              onChange={(e) => handleChange("countedPlayers", e.target.value)}
              placeholder="player to be counted"
              type="number"
              min="0"
            />
          </div>
          {/* <div>
            <Label htmlFor="type">Type *</Label>
            <Select onValueChange={(val) => handleChange("type", val)}>
              <SelectTrigger>
                <SelectValue placeholder="Select Type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="IPL">IPL</SelectItem>
                <SelectItem value="TEST">TEST</SelectItem>

                <SelectItem value="T20">T20</SelectItem>
                <SelectItem value="WorldCup">World Cup</SelectItem>
              </SelectContent>
            </Select>
          </div> */}
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {/* <div>
            <Label htmlFor="maxPlayers">Max Players Allowed *</Label>
            <Input
              type="number"
              min={1}
              id="maxPlayers"
              value={form.maxPlayers}
              onChange={(e) => handleChange("maxPlayers", e.target.value)}
              placeholder="Enter max players"
            />
          </div> */}
          <div>
            <Label htmlFor="minPlayers">Number of participants *</Label>
            <Input
              type="number"
              min={1}
              required
              id="minPlayers"
              value={form.minPlayers}
              onChange={(e) => handleChange("minPlayers", e.target.value)}
              placeholder="Enter participants"
            />
          </div>{" "}
          <div>
            <Label htmlFor="name">Number of max player allowed to buy * </Label>
            <Input
              id="maxPlayerAllowed"
              required
              value={form.maxPlayerAllowed}
              onChange={(e) => handleChange("maxPlayerAllowed", e.target.value)}
              placeholder="Enter amount"
            />
          </div>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <Label htmlFor="startTime">Start Date & Time</Label>
            <Input
              id="startTime"
              type="datetime-local"
              value={form.startTime}
              onChange={(e) => handleChange("startTime", e.target.value)}
            />
          </div>
          <div>
            <Label htmlFor="startTime">Captain Points</Label>
            <Input
              id="captain"
              type="text"
              value={form.captain}
              onChange={(e) => handleChange("captain", e.target.value)}
            />
          </div>
          <div>
            <Label htmlFor="vicecaptain">Vice Captain Points</Label>
            <Input
              id="vicecaptain"
              type="text"
              value={form.vicecaptain}
              onChange={(e) => handleChange("vicecaptain", e.target.value)}
            />
          </div>
          <div>
            <Label htmlFor="runPoint">Run Point Value</Label>
            <Input
              id="runPoint"
              type="number"
              min="0"
              value={form.runPoint}
              onChange={(e) => handleChange("runPoint", e.target.value)}
              placeholder="Points per run"
            />
          </div>
          <div>
            <Label htmlFor="wicketPoint">Wicket Point Value</Label>
            <Input
              id="wicketPoint"
              type="number"
              min="0"
              value={form.wicketPoint}
              onChange={(e) => handleChange("wicketPoint", e.target.value)}
              placeholder="Points per wicket"
            />
          </div>
        </div>
        {/* Enhanced Player Selection with Tabs */}
        <div>
          <Label>Choose Players</Label>
          {form.category ? (
            <Tabs defaultValue="groups" className="w-full">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="groups">Select by Groups</TabsTrigger>
                {/* <TabsTrigger value="individual">Select Individual</TabsTrigger> */}
              </TabsList>

              <TabsContent value="groups" className="space-y-4">
                <div className="border rounded-md p-4">
                  <h4 className="font-medium mb-3">Available Player Groups</h4>
                  {playerGroups.length > 0 ? (
                    <div className="space-y-2">
                      {playerGroups.map((group) => (
                        <div
                          key={group.groupName}
                          className="flex items-center space-x-2"
                        >
                          <Checkbox
                            id={group.groupName}
                            checked={form.selectedGroups.includes(
                              group.groupName
                            )}
                            onCheckedChange={(checked) =>
                              handleGroupSelection(group.groupName, checked)
                            }
                          />
                          <Label htmlFor={group.groupName} className="flex-1">
                            <span className="font-medium">
                              {group.groupName}
                            </span>
                            <span className="text-sm text-gray-500 ml-2">
                              ({group.playerCount} players)
                            </span>
                          </Label>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="text-center text-gray-500 py-4">
                      No player groups found for this category
                    </div>
                  )}
                </div>
              </TabsContent>
              {/* 
              <TabsContent value="individual">
                <MultiSelect
                  options={allPlayers}
                  selected={form.selectedPlayers}
                  onChange={(selected) =>
                    handleChange("selectedPlayers", selected)
                  }
                />
              </TabsContent> */}
            </Tabs>
          ) : (
            <div className="p-4 border border-dashed rounded-md text-center text-gray-500">
              Please select a category first to load players
            </div>
          )}

          {/* Selected Players Summary */}
          {form.selectedPlayers.length > 0 && (
            <div className="mt-4 p-4 bg-gray-50 rounded-md">
              <div className="flex justify-between items-center mb-2">
                <span className="font-medium">Selected Players Summary</span>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() =>
                    setForm((prev) => ({
                      ...prev,
                      selectedPlayers: [],
                      selectedGroups: [],
                    }))
                  }
                >
                  Clear All
                </Button>
              </div>
              <div className="text-sm text-gray-600">
                <div>Total Players: {form.selectedPlayers.length}</div>
                {form.selectedGroups.length > 0 && (
                  <div>Selected Groups: {form.selectedGroups.join(", ")}</div>
                )}
              </div>

              {/* Show selected players in a scrollable area */}
              <div className="mt-2 max-h-32 overflow-y-auto">
                <div className="text-xs text-gray-500 space-y-1">
                  {form.selectedPlayers.map((player) => (
                    <div key={player.id} className="flex justify-between">
                      <span>{player.originalName}</span>
                      <span>
                        {player.playerGroup && `(${player.playerGroup})`}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
        <Separator />
        <div className="flex justify-end gap-4 items-center">
          <div>
            {" "}
            {!isNaN(totalPool) && (
              <span className="font-2xl font-bold text-green-700">
                Total Pool: {totalPool}
              </span>
            )}
          </div>
          <Button
            variant="outline"
            onClick={() =>
              setForm({
                name: "",
                category: "",
                type: "",
                maxPlayers: "",
                minPlayers: "",
                selectedPlayers: [],
                startTime: "",
                endTime: "",
                runPoint: 1,
                wicketPoint: 10,
              })
            }
          >
            Reset
          </Button>
          <Button onClick={handleSubmit} disabled={loading}>
            {loading ? "Creating..." : "Create Auction"}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
};

export default CreateAuction;
