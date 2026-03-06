import React, { useState, useEffect } from "react";
import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Trash } from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Link } from "react-router-dom";

import {
  Dialog,
  DialogTrigger,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogDescription,
} from "@/components/ui/dialog";
import axios from "axios";
import { API_URL } from "@/constants";
import { Label } from "@/components/ui/label";

const PlayerList = () => {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [category, setCategory] = useState("all");
  const [type, setType] = useState("all");
  const [selectedFile, setSelectedFile] = useState(null);
  const [playerGroup, setPlayerGroup] = useState(""); // Add group state
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(10);
  const [pagination, setPagination] = useState({ total: 0, totalPages: 1, page: 1, limit: 10, hasNext: false, hasPrev: false });

  // Fetch players data from API
  // Debounce search input
  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(search), 400);
    return () => clearTimeout(t);
  }, [search]);

  useEffect(() => {
    fetchPlayers();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debouncedSearch, category, type, page, limit]);

  const fetchPlayers = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/player`, {
        params: {
          page,
          limit,
          search: debouncedSearch,
          category,
          type,
          sort: "name_asc",
          paginated: true,
        },
      });

      if (response.data.success) {
        const { items: rows, pagination: meta } = response.data.data || {};
        setItems(rows || []);
        setPagination(meta || { total: 0, totalPages: 1, page: 1, limit, hasNext: false, hasPrev: false });
      } else {
        setError("Failed to fetch players");
      }
    } catch (error) {
      console.error("Error fetching players:", error);
      setError("Error fetching players data");
    } finally {
      setLoading(false);
    }
  };

  const isEmpty = !loading && (!items || items.length === 0);

  const handleFileChange = (e) => {
    if (e.target.files && e.target.files[0]) {
      setSelectedFile(e.target.files[0]);
    }
  };

  const handleUpload = async () => {
    if (!selectedFile) {
      alert("Please select a file.");
      return;
    }

    if (!playerGroup.trim()) {
      alert("Please enter a group name for these players.");
      return;
    }

    const formData = new FormData();
    formData.append("file", selectedFile);
    formData.append("playerGroup", playerGroup.trim()); // Add group to form data

    try {
      console.log("Uploading file:", selectedFile.name, "Group:", playerGroup);

      const response = await axios.post(
        `${API_URL}/player/bulk-upload`,
        formData,
        {
          headers: {
            "Content-Type": "multipart/form-data",
          },
        }
      );

      console.log("Upload success:", response.data);
      alert(
        `File uploaded successfully! ${response.data.data.created} players added to group "${playerGroup}"`
      );

      fetchPlayers();
      setSelectedFile(null);
      setPlayerGroup(""); // Reset group name
    } catch (error) {
      console.error("Upload failed:", error);
      alert("File upload failed!");
    }
  };

  const handleDeletePlayer = async (playerId) => {
    if (window.confirm("Are you sure you want to delete this player?")) {
      try {
        await axios.delete(`${API_URL}/player/${playerId}`);
        alert("Player deleted successfully!");
        // Refresh the players list after deletion
        fetchPlayers();
      } catch (error) {
        console.error("Error deleting player:", error);
        alert("Failed to delete player!");
      }
    }
  };

  // Format price for display
  const formatPrice = (price) => {
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      maximumFractionDigits: 0,
    }).format(price);
  };

  if (loading) {
    return (
      <div className="w-11/12 mx-auto h-screen mt-10 flex items-center justify-center">
        <div className="text-lg">Loading players...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="w-11/12 mx-auto h-screen mt-10 flex items-center justify-center">
        <div className="text-lg text-red-600">{error}</div>
      </div>
    );
  }

  return (
    <div className="w-11/12 mx-auto h-screen mt-10 space-y-6">
      {/* Filters */}
      <div className="flex flex-wrap gap-4 items-center justify-between">
        <div className="flex gap-4">
          <Input
            placeholder="Search by Player Name or ID..."
            className="w-full sm:w-1/3"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
          <Select value={category} onValueChange={(val) => { setCategory(val); setPage(1); }}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="Filter by Category" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Categories</SelectItem>
              <SelectItem value="cricket">Cricket</SelectItem>
              <SelectItem value="football">Football</SelectItem>
              <SelectItem value="basketball">Basketball</SelectItem>
            </SelectContent>
          </Select>
          <Select value={type} onValueChange={(val) => { setType(val); setPage(1); }}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="Filter by Type" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Types</SelectItem>
              <SelectItem value="batsman">Batsman</SelectItem>
              <SelectItem value="bowler">Bowler</SelectItem>
              <SelectItem value="allrounder">All Rounder</SelectItem>
              <SelectItem value="wicketkeeper">Wicket Keeper</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="flex gap-4">
          {/* <Link to="/create-Player">
            <Button className="w-40 bg-green-600 text-white">Add Player</Button>
          </Link> */}

          {/* Bulk Upload Button with Dialog */}
          <Dialog>
            <DialogTrigger asChild>
              <Button className="w-40 bg-green-700 text-white">
                Bulk Add Player
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Upload Bulk Player File</DialogTitle>
                <DialogDescription>
                  Upload a CSV or Excel file containing player data.
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-4">
                <div>
                  <Label htmlFor="groupName">Group Name *</Label>
                  <Input
                    id="groupName"
                    value={playerGroup}
                    onChange={(e) => setPlayerGroup(e.target.value)}
                    placeholder="e.g., IPL_2024_BATCH_1"
                  />
                </div>
                <div>
                  <Label htmlFor="file">Excel File *</Label>
                  <Input id="file" type="file" onChange={handleFileChange} />
                </div>
              </div>
              <DialogFooter>
                <Button onClick={handleUpload} disabled={!selectedFile}>
                  Upload
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* Table */}
      <Table className="w-full">
        <TableCaption>
          A list of your Players (Total {pagination.total}).
        </TableCaption>
        <TableHeader>
          <TableRow>
            <TableHead>Player Id</TableHead>
            <TableHead>Player Name</TableHead>
            <TableHead>Base Price</TableHead>
            <TableHead>Team</TableHead>
            <TableHead className="text-right">Category</TableHead>
            <TableHead className="text-right">Type</TableHead>
            <TableHead className="text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {loading ? (
            <TableRow>
              <TableCell colSpan={8} className="text-center py-6">
                Loading players...
              </TableCell>
            </TableRow>
          ) : items.length > 0 ? (
            items.map((player) => (
              <TableRow key={player.id}>
                <TableCell className="font-medium">{player.id}</TableCell>
                <TableCell>{player.name}</TableCell>
                <TableCell>{formatPrice(player.basePrice)}</TableCell>
                <TableCell>{player.team || "-"}</TableCell>
                <TableCell className="text-right capitalize">
                  {player.category}
                </TableCell>
                <TableCell className="text-right capitalize">
                  {player.type}
                </TableCell>
                <TableCell className="text-right space-x-2">
                  <Link to={`/player/${player.id}`}>
                    <Button variant="outline">View</Button>
                  </Link>
                  <Button
                    className="bg-red-600"
                    size="icon"
                    onClick={() => handleDeletePlayer(player.id)}
                  >
                    <Trash className="h-4 w-4 text-white" />
                  </Button>
                </TableCell>
              </TableRow>
            ))
          ) : (
            <TableRow>
              <TableCell colSpan={8} className="text-center py-6">
                No Players found.
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      {/* Pagination Controls */}
      <div className="flex items-center justify-between mt-4">
        <div className="text-sm text-muted-foreground">
          Showing page {pagination.page} of {pagination.totalPages} • Total {pagination.total}
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            disabled={!pagination.hasPrev || loading}
            onClick={() => setPage((p) => Math.max(p - 1, 1))}
          >
            Prev
          </Button>
          <Button
            variant="outline"
            size="sm"
            disabled={!pagination.hasNext || loading}
            onClick={() => setPage((p) => p + 1)}
          >
            Next
          </Button>
        </div>
      </div>
    </div>
  );
};

export default PlayerList;
