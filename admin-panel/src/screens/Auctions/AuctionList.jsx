import React, { useEffect, useState } from "react";
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
import { Trash, Trophy, Check, X, Pencil } from "lucide-react";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Progress } from "@/components/ui/progress";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Loader2, Play, Square, RotateCcw, RefreshCw } from "lucide-react";

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Link } from "react-router-dom";
import axios from "axios";
import { API_URL } from "@/constants";
import AuctionLeaderboard from "@/components/AuctionLeaderboard";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const AuctionList = () => {
  const [items, setItems] = useState([]);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [category, setCategory] = useState("all");
  const [type, setType] = useState("all");
  const [selectedAuctions, setSelectedAuctions] = useState([]);
  const [selectAll, setSelectAll] = useState(false);
  const [isBulkDeleting, setIsBulkDeleting] = useState(false);
  const [participantsData, setParticipantsData] = useState([]);
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(10);
  const [pagination, setPagination] = useState({
    total: 0,
    totalPages: 1,
    page: 1,
    limit: 10,
    hasNext: false,
    hasPrev: false,
  });
  const [loading, setLoading] = useState(false);

  const [leaderboardModal, setLeaderboardModal] = useState({
    isOpen: false,
    auctionId: null,
    auctionName: "",
  });
  const [showParticipantsModal, setShowParticipantsModal] = useState(false);

  const fetchParticipantsWithPlayers = async (id) => {
    try {
      const response = await axios.get(
        `${API_URL}/auction/${id}/participants-with-players`
      );
      if (response.data.success) {
        setParticipantsData(response.data.data);
        setShowParticipantsModal(true);
      }
    } catch (error) {
      console.error("Error fetching participants data:", error);
    }
  };

  // Debounce search input to reduce API calls
  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(search), 400);
    return () => clearTimeout(t);
  }, [search]);

  useEffect(() => {
    fetchauctionData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debouncedSearch, category, type, page, limit]);

  const fetchauctionData = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/auction`, {
        params: {
          page,
          limit,
          search: debouncedSearch,
          category,
          type,
          sort: "latest",
          paginated: true,
        },
      });
      if (response.status === 200) {
        const { items: rows, pagination: meta } = response.data.data;
        setItems(rows || []);
        setPagination(
          meta || {
            total: 0,
            totalPages: 1,
            page: 1,
            limit,
            hasNext: false,
            hasPrev: false,
          }
        );
        // Reset selections when data changes
        setSelectedAuctions([]);
        setSelectAll(false);
      }
    } catch (error) {
      console.log("Failed to fetch auction data:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleShowLeaderboard = (auctionId, auctionName) => {
    setLeaderboardModal({
      isOpen: true,
      auctionId: auctionId,
      auctionName: auctionName,
    });
  };

  const handleCloseLeaderboard = () => {
    setLeaderboardModal({
      isOpen: false,
      auctionId: null,
      auctionName: "",
    });
  };

  const handleDeleteAuction = async (auctionId, auctionName) => {
    if (
      window.confirm(
        `Are you sure you want to delete "${auctionName}"? This action cannot be undone.`
      )
    ) {
      try {
        const response = await axios.delete(`${API_URL}/auction/${auctionId}`);
        if (response.status === 200) {
          // Refetch the current page
          fetchauctionData();
          // Remove from selected auctions if it was selected
          setSelectedAuctions((prev) => prev.filter((id) => id !== auctionId));
          alert("Auction deleted successfully!");
        }
      } catch (error) {
        console.error("Failed to delete auction:", error);
        alert("Failed to delete auction. Please try again.");
      }
    }
  };

  const handleBulkDelete = async () => {
    if (selectedAuctions.length === 0) {
      alert("Please select at least one auction to delete.");
      return;
    }

    const auctionNames = items
      .filter((auction) => selectedAuctions.includes(auction.id))
      .map((auction) => `"${auction.name}"`)
      .join(", ");

    if (
      window.confirm(
        `Are you sure you want to delete the following auctions? This action cannot be undone.\n\n${auctionNames}`
      )
    ) {
      try {
        setIsBulkDeleting(true);
        const response = await axios.post(`${API_URL}/auction/bulk-delete`, {
          auctionIds: selectedAuctions,
        });

        if (response.data.success) {
          // Refetch the current page
          fetchauctionData();
          setSelectedAuctions([]);
          setSelectAll(false);
          alert(response.data.message);
        }
      } catch (error) {
        console.error("Failed to delete auctions:", error);
        alert("Failed to delete auctions. Please try again.");
      } finally {
        setIsBulkDeleting(false);
      }
    }
  };

  const toggleAuctionSelection = (auctionId) => {
    setSelectedAuctions((prev) =>
      prev.includes(auctionId)
        ? prev.filter((id) => id !== auctionId)
        : [...prev, auctionId]
    );
  };

  const toggleSelectAll = () => {
    if (selectAll) {
      setSelectedAuctions([]);
    } else {
      setSelectedAuctions(items.map((auction) => auction.id));
    }
    setSelectAll(!selectAll);
  };

  const isEmpty = !loading && (!items || items.length === 0);

  return (
    <div className="w-11/12 mx-auto h-screen mt-10 space-y-6">
      {showParticipantsModal && (
        <Dialog
          open={showParticipantsModal}
          onOpenChange={setShowParticipantsModal}
        >
          <DialogContent className="max-w-4xl">
            <DialogHeader>
              <DialogTitle>Auction Participants & Their Players</DialogTitle>
            </DialogHeader>
            <div className="max-h-[70vh] overflow-y-auto">
              {participantsData.map((participant) => (
                <Card key={participant.userId} className="mb-4">
                  <CardHeader>
                    <CardTitle className="flex justify-between">
                      <span>{participant.userName}</span>
                      <Badge>
                        Budget: ₹
                        {(participant.remainingBudget / 10000000).toFixed(1)}
                        Cr
                      </Badge>
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                      {participant.players.map((player) => (
                        <div key={player.id} className="border p-3 rounded">
                          <div className="flex items-center gap-2">
                            {player.image && (
                              <img
                                src={player.image}
                                alt={player.name}
                                className="w-10 h-10 rounded-full object-cover"
                              />
                            )}
                            <div>
                              <div className="font-semibold">{player.name}</div>
                              <div className="text-sm text-muted-foreground">
                                {player.role} • ₹
                                {(player.price / 10000000).toFixed(1)}Cr
                              </div>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </DialogContent>
        </Dialog>
      )}
      {/* Filters */}
      <div className="flex flex-wrap gap-4 items-center justify-between">
        <div className="flex flex-wrap gap-4 items-center">
          {selectedAuctions.length > 0 && (
            <div className="flex items-center gap-2 bg-gray-100 dark:bg-gray-800 px-3 py-1.5 rounded-md">
              <span className="text-sm font-medium">
                {selectedAuctions.length} selected
              </span>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setSelectedAuctions([])}
                className="h-8 px-2"
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          )}

          <Input
            placeholder="Search by Auction Name or ID..."
            className="w-full sm:w-64"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
          <Select
            value={category}
            onValueChange={(val) => {
              setCategory(val);
              setPage(1);
            }}
          >
            <SelectTrigger className="w-40">
              <SelectValue placeholder="Filter by Category" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Categories</SelectItem>
              <SelectItem value="Cricket">Cricket</SelectItem>
              <SelectItem value="Football">Football</SelectItem>
            </SelectContent>
          </Select>

          {/* <Select onValueChange={(val) => setType(val)}>
            <SelectTrigger className="w-40">
              <SelectValue placeholder="Filter by Type" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="IPL">IPL</SelectItem>
              <SelectItem value="Modern">Modern</SelectItem>
            </SelectContent>
          </Select> */}
        </div>

        <div className="flex gap-2">
          {selectedAuctions.length > 0 && (
            <Button
              variant="destructive"
              onClick={handleBulkDelete}
              disabled={isBulkDeleting}
              className="w-auto"
            >
              {isBulkDeleting ? (
                "Deleting..."
              ) : (
                <>
                  <Trash className="h-4 w-4 mr-2" />
                  Delete Selected ({selectedAuctions.length})
                </>
              )}
            </Button>
          )}
          <Link to="/create-auction">
            <Button className="bg-green-600 text-white hover:bg-green-700">
              Create Auction
            </Button>
          </Link>
        </div>
      </div>

      {/* Table */}
      <Table className="w-full">
        <TableCaption>A list of your Auctions.</TableCaption>
        <TableHeader>
          <TableRow>
            <TableHead className="w-12">
              <Checkbox
                checked={selectAll}
                onCheckedChange={toggleSelectAll}
                className="h-4 w-4"
              />
            </TableHead>
            <TableHead>Auction Id</TableHead>
            <TableHead>Auction Name</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="text-right">Category</TableHead>
            <TableHead className="text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {loading ? (
            <TableRow>
              <TableCell colSpan={6} className="text-center py-6">
                Loading auctions...
              </TableCell>
            </TableRow>
          ) : items.length > 0 ? (
            items.map((auction) => {
              const isSelected = selectedAuctions.includes(auction.id);
              return (
                <TableRow
                  key={auction.id}
                  className={isSelected ? "bg-gray-50 dark:bg-gray-800" : ""}
                >
                  <TableCell>
                    <Checkbox
                      checked={isSelected}
                      onCheckedChange={() => toggleAuctionSelection(auction.id)}
                      className="h-4 w-4"
                    />
                  </TableCell>
                  <TableCell className="font-medium">{auction.id}</TableCell>
                  <TableCell>{auction.name}</TableCell>
                  <TableCell>{auction.status}</TableCell>
                  <TableCell className="text-right">
                    {auction.category}
                  </TableCell>

                  {/* <TableCell className="text-right">{auction.type}</TableCell> */}
                  <TableCell className="text-right space-x-2">
                    <Button
                      onClick={() => fetchParticipantsWithPlayers(auction.id)}
                    >
                      Participants
                    </Button>
                    <Link to={`/auctions/${auction.id}`}>
                      <Button variant="outline" size="sm">
                        View
                      </Button>
                    </Link>
                    {auction.status === "upcoming" && (
                      <Link to={`/auctions/${auction.id}/edit`}>
                        <Button
                          variant="outline"
                          size="sm"
                          className="text-blue-600"
                        >
                          <Pencil className="h-4 w-4 mr-1" /> Edit
                        </Button>
                      </Link>
                    )}
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() =>
                        handleShowLeaderboard(auction.id, auction.name)
                      }
                      className="bg-yellow-500 hover:bg-yellow-600 text-white"
                    >
                      <Trophy className="h-4 w-4 mr-1" />
                      Leaderboard
                    </Button>
                    <Button
                      variant="destructive"
                      size="sm"
                      onClick={() =>
                        handleDeleteAuction(auction.id, auction.name)
                      }
                    >
                      <Trash className="h-4 w-4" />
                    </Button>
                  </TableCell>
                </TableRow>
              );
            })
          ) : (
            <TableRow>
              <TableCell colSpan={6} className="text-center py-6">
                No auctions found.
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      {/* Pagination Controls */}
      <div className="flex items-center justify-between mt-4">
        <div className="text-sm text-muted-foreground">
          Showing page {pagination.page} of {pagination.totalPages} • Total{" "}
          {pagination.total}
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

      {/* Leaderboard Modal */}
      <AuctionLeaderboard
        isOpen={leaderboardModal.isOpen}
        onClose={handleCloseLeaderboard}
        auctionId={leaderboardModal.auctionId}
        auctionName={leaderboardModal.auctionName}
      />
    </div>
  );
};

export default AuctionList;
