import React, { useState, useEffect, useMemo } from "react";
import { useNavigate, useParams } from "react-router-dom";
import axios from "axios";
import { API_URL } from "@/constants";

// UI Components
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { Progress } from "@/components/ui/progress";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { 
  Table, 
  TableBody, 
  TableCell, 
  TableHead, 
  TableHeader, 
  TableRow 
} from "@/components/ui/table";
import { 
  Tabs, 
  TabsContent, 
  TabsList, 
  TabsTrigger 
} from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

// Icons
import { 
  Loader2, 
  Play, 
  Square, 
  RotateCcw, 
  RefreshCw, 
  Award, 
  Users, 
  DollarSign, 
  BarChart2, 
  UserCheck, 
  UserX, 
  Hash,
  ShoppingCart
} from "lucide-react";

// Charts
import { 
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip as RechartsTooltip,
  ResponsiveContainer
} from "recharts";

const AuctionDetail = () => {
  // Router hooks
  const { id } = useParams();
  const navigate = useNavigate();
  
  // State for auction data
  const [auctionData, setAuctionData] = useState(null);
  const [auctionStatus, setAuctionStatus] = useState(null);
  const [auctionStats, setAuctionStats] = useState(null);
  const [auctionHistory, setAuctionHistory] = useState([]);
  const [participantsData, setParticipantsData] = useState([]);
  const [participantsSummary, setParticipantsSummary] = useState({ totalCount: 0, capacity: null, participants: [] });
  
  // UI state
  const [showPlayers, setShowPlayers] = useState(true);
  const [showParticipantsModal, setShowParticipantsModal] = useState(false);
  const [activeTab, setActiveTab] = useState("roster");
  
  // Loading and error states
  const [loading, setLoading] = useState(true);
  const [statsLoading, setStatsLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState(null);
  const [retryCount, setRetryCount] = useState(0);

  const fetchParticipantsWithPlayers = async () => {
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

  // Map results by playerId for quick lookup (sold/unsold, price, buyer)
  const resultsByPlayerId = useMemo(() => {
    const map = new Map();
    auctionHistory.forEach((h) => {
      if (h && h.playerId) map.set(h.playerId, h);
    });
    return map;
  }, [auctionHistory]);

  useEffect(() => {
    fetchAuctionStatus();
    // Ensure we load the auction roster (players) as well
    fetchAuctionData();
    fetchAuctionHistory();
    const interval = setInterval(fetchAuctionStatus, 5000);
    return () => clearInterval(interval);
  }, [id]);

  const fetchAuctionStatus = async () => {
    try {
      const response = await axios.get(`${API_URL}/auction/${id}/status`);
      if (response.data.success) {
        setAuctionStatus(response.data.data);
        setError(null);
      }
    } catch (err) {
      console.error("Error fetching auction status:", err);
      setError("Failed to fetch auction status");
    } finally {
      setLoading(false);
    }
  };

  const fetchAuctionData = async () => {
    try {
      const response = await axios.get(`${API_URL}/auction/${id}`);
      if (response.data.success) {
        setAuctionData(response.data.data);
      }
      await Promise.all([
        fetchAuctionStats(),
        // fetchAuctionHistory(),
        fetchParticipantsWithPlayers(),
        fetchAuctionParticipants()
      ]);
    } catch (err) {
      console.error("Error fetching auction data:", err);
      setError("Failed to fetch auction data");
    } finally {
      setLoading(false);
    }
  };

  const fetchAuctionStats = async () => {
    setStatsLoading(true);
    try {
      const response = await axios.get(`${API_URL}/auction/${id}/stats`);
      if (response.data.success) {
        setAuctionStats(response.data.data);
      }
    } catch (err) {
      console.error("Error fetching auction stats:", err);
      setError("Failed to fetch auction statistics");
    } finally {
      setStatsLoading(false);
    }
  };

  const fetchAuctionHistory = async () => {
    try {
      const response = await axios.get(`${API_URL}/auction/${id}/history`);
      if (response.data.success) {
        setAuctionHistory(response.data.history);
      }
    } catch (err) {
      console.error("Error fetching auction history:", err);
      setError("Failed to fetch auction history");
    }
  };

  const fetchAuctionParticipants = async () => {
    try {
      const response = await axios.get(`${API_URL}/auction/${id}/participants`);
      if (response.data.success) {
        setParticipantsSummary(response.data.data || { totalCount: 0, capacity: null, participants: [] });
      }
    } catch (err) {
      console.error("Error fetching auction participants:", err);
    }
  };

  useEffect(() => {
    if (id) {
      fetchAuctionData();
    }
  }, [id]);

  const handleStartAuction = async () => {
    setActionLoading(true);
    setError(null);

    try {
      const response = await axios.post(`${API_URL}/auction/${id}/start`, {
        retryCount: 0,
      });

      if (response.data.success) {
        setRetryCount(0);
        await fetchAuctionStatus();
        // Show success message
        alert("Auction started successfully!");
      }
    } catch (err) {
      console.error("Error starting auction:", err);
      setError(err.response?.data?.message || "Failed to start auction");

      // Auto-retry logic
      if (retryCount < 2) {
        setRetryCount((prev) => prev + 1);
        setTimeout(() => {
          handleStartAuction();
        }, 3000);
      }
    } finally {
      setActionLoading(false);
    }
  };

  const handleStopAuction = async () => {
    if (!confirm("Are you sure you want to stop this auction?")) return;

    setActionLoading(true);
    setError(null);

    try {
      const response = await axios.post(`${API_URL}/auction/${id}/stop`);

      if (response.data.success) {
        await fetchAuctionStatus();
        alert("Auction stopped successfully!");
      }
    } catch (err) {
      console.error("Error stopping auction:", err);
      setError(err.response?.data?.message || "Failed to stop auction");
    } finally {
      setActionLoading(false);
    }
  };

  const handleResetAuction = async () => {
    if (
      !confirm(
        "Are you sure you want to reset this auction? This will clear all progress."
      )
    )
      return;

    setActionLoading(true);
    setError(null);

    try {
      const response = await axios.post(`${API_URL}/auction/${id}/reset`);

      if (response.data.success) {
        setRetryCount(0);
        await fetchAuctionStatus();
        alert("Auction reset successfully!");
      }
    } catch (err) {
      console.error("Error resetting auction:", err);
      setError(err.response?.data?.message || "Failed to reset auction");
    } finally {
      setActionLoading(false);
    }
  };

  const getStatusBadge = (status) => {
    const statusConfig = {
      upcoming: { variant: "secondary", text: "Upcoming" },
      ongoing: { variant: "default", text: "Live" },
      completed: { variant: "outline", text: "Completed" },
    };

    const config = statusConfig[status] || statusConfig.upcoming;
    return <Badge variant={config.variant}>{config.text}</Badge>;
  };

  const getStatusColor = (status) => {
    switch (status) {
      case "ongoing":
        return "text-green-600";
      case "completed":
        return "text-gray-600";
      default:
        return "text-blue-600";
    }
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0
    }).format(amount);
  };

  const renderStatsCard = (title, value, icon, description = '') => (
    <Card className="flex-1">
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">{title}</CardTitle>
        {icon}
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        {description && <p className="text-xs text-muted-foreground">{description}</p>}
      </CardContent>
    </Card>
  );

  const renderPlayerRow = (player, index) => {
    const isSold = player.status === 'sold';
    return (
      <TableRow key={player.id || index}>
        <TableCell className="font-medium">{player.player || player.player?.name || 'N/A'}</TableCell>
        <TableCell>{player.playerType || player.player?.type || 'N/A'}</TableCell>
        <TableCell className={isSold ? 'text-green-600' : 'text-red-600'}>
          {isSold ? 'Sold' : 'Unsold'}
        </TableCell>
        <TableCell>{isSold ? formatCurrency(player.price || player.finalBid || 0) : 'N/A'}</TableCell>
        <TableCell>{isSold ? (player.team || player.winner?.name || 'N/A') : 'N/A'}</TableCell>
      </TableRow>
    );
  };

  const renderParticipantPurchases = () => {
    const purchasesByParticipant = {};
    
    auctionHistory.forEach(item => {
      if (item.status === 'sold' && item.winner) {
        if (!purchasesByParticipant[item.winner.id]) {
          purchasesByParticipant[item.winner.id] = {
            name: item.winner.name,
            totalSpent: 0,
            players: []
          };
        }
        purchasesByParticipant[item.winner.id].totalSpent += item.finalBid || 0;
        purchasesByParticipant[item.winner.id].players.push({
          name: item.player?.name,
          type: item.player?.type,
          price: item.finalBid
        });
      }
    });

    return Object.values(purchasesByParticipant).map((participant, index) => (
      <Card key={index} className="mb-4">
        <CardHeader className="pb-2">
          <div className="flex justify-between items-center">
            <CardTitle className="text-lg">{participant.name}</CardTitle>
            <Badge variant="outline" className="text-sm">
              Total Spent: {formatCurrency(participant.totalSpent)}
            </Badge>
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Player</TableHead>
                <TableHead>Type</TableHead>
                <TableHead className="text-right">Price</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {participant.players.map((player, idx) => (
                <TableRow key={idx}>
                  <TableCell>{player.name}</TableCell>
                  <TableCell>{player.type}</TableCell>
                  <TableCell className="text-right">{formatCurrency(player.price)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    ));
  };

  if (loading || statsLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Loader2 className="h-8 w-8 animate-spin" />
        <span className="ml-2">Loading auction details...</span>
      </div>
    );
  }

  if (!auctionStatus) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <p className="text-red-600 mb-4">Failed to load auction details</p>
          <Button onClick={fetchAuctionStatus}>
            <RefreshCw className="h-4 w-4 mr-2" />
            Retry
          </Button>
        </div>
      </div>
    );
  }

  const {
    auction,
    currentState,
    connectedUsers,
    remainingPlayers,
    isActive,
    canStart,
  } = auctionStatus;

  return (
    <div className="flex w-full min-h-screen">
      {/* Sidebar for Players */}
      {showPlayers && (
        <div className="w-64 p-4 border-r bg-muted space-y-2">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold">Players</h2>
            <Badge variant="outline">{auction.totalPlayers}</Badge>
          </div>

          {auction.totalPlayers === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <p>No players added</p>
              <Button
                variant="outline"
                size="sm"
                className="mt-2"
                onClick={() => navigate(`/auctions/${id}/players`)}
              >
                Add Players
              </Button>
            </div>
          ) : (
            <div className="space-y-2">
              <div className="text-sm text-muted-foreground">
                Current: {auction.currentPlayerIndex || 0} /{" "}
                {auction.totalPlayers}
              </div>
              <div className="text-sm text-muted-foreground">
                Remaining: {remainingPlayers}
              </div>
              <Progress
                value={
                  ((auction.currentPlayerIndex || 0) / auction.totalPlayers) *
                  100
                }
                className="w-full"
              />
            </div>
          )}
        </div>
      )}

      {/* Main Content */}
      <div className="flex-1 p-6 space-y-6">
        {/* Header with Toggle and Status */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold">{auction.name}</h1>
            <p className="text-sm text-muted-foreground">
              Auction ID: {auction.id}
            </p>
          </div>
          <div className="flex items-center gap-4">
            <Button
              variant="secondary"
              onClick={() => setShowPlayers((prev) => !prev)}
            >
              {showPlayers ? "Hide Player List" : "Show Player List"}
            </Button>
            {getStatusBadge(auction.status)}
          </div>
        </div>
        {/* Error Alert */}
        {error && (
          <Alert variant="destructive">
            <AlertDescription>
              {error}
              {retryCount > 0 && (
                <span className="ml-2">(Retry attempt: {retryCount}/3)</span>
              )}
            </AlertDescription>
          </Alert>
        )}
        {/* Auction Control Panel */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              Auction Control Panel
              <div
                className={`w-2 h-2 rounded-full ${
                  isActive ? "bg-green-500" : "bg-gray-400"
                }`}
              />
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
              <div className="text-center">
                <div className="text-2xl font-bold">{connectedUsers}</div>
                <div className="text-sm text-muted-foreground">
                  Connected Users
                </div>
              </div>
              <div className="text-center">
                <div
                  className={`text-2xl font-bold ${getStatusColor(
                    auction.status
                  )}`}
                >
                  {auction.status.toUpperCase()}
                </div>
                <div className="text-sm text-muted-foreground">
                  Current Status
                </div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold">{remainingPlayers}</div>
                <div className="text-sm text-muted-foreground">
                  Players Remaining
                </div>
              </div>
            </div>

            <div className="flex flex-wrap gap-3">
              {/* Start Auction Button */}
              <Button
                onClick={handleStartAuction}
                disabled={!canStart || actionLoading}
                className="bg-green-600 hover:bg-green-700"
              >
                {actionLoading ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <Play className="h-4 w-4 mr-2" />
                )}
                {retryCount > 0
                  ? `Retrying... (${retryCount}/3)`
                  : "Start Auction"}
              </Button>

              {/* Stop Auction Button */}
              <Button
                onClick={handleStopAuction}
                disabled={!isActive || actionLoading}
                variant="destructive"
              >
                {actionLoading ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <Square className="h-4 w-4 mr-2" />
                )}
                Stop Auction
              </Button>

              {/* Reset Auction Button */}
              <Button
                onClick={handleResetAuction}
                disabled={actionLoading}
                variant="outline"
              >
                {actionLoading ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <RotateCcw className="h-4 w-4 mr-2" />
                )}
                Reset Auction
              </Button>

              {/* Refresh Status Button */}
              <Button onClick={fetchAuctionStatus} variant="outline" size="sm">
                <RefreshCw className="h-4 w-4 mr-2" />
                Refresh
              </Button>
            </div>

            {/* Start Requirements */}
            {!canStart && auction.status === "upcoming" && (
              <div className="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
                <p className="text-sm text-yellow-800">
                  <strong>Requirements to start:</strong>
                  {auction.totalPlayers === 0 &&
                    " • Add players to the auction"}
                  {connectedUsers === 0 && " • Wait for users to join"}
                </p>
              </div>
            )}
          </CardContent>
        </Card>
        <Separator />
        {/* Participants Summary */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <span>Participants</span>
              <div className="flex items-center gap-2">
                <Badge variant="outline">Registered: {participantsSummary.totalCount || participantsData?.length || 0}</Badge>
                {participantsSummary.capacity && (
                  <Badge variant="secondary">Capacity: {participantsSummary.capacity}</Badge>
                )}
              </div>
            </CardTitle>
          </CardHeader>
          <CardContent>
            {participantsData && participantsData.length > 0 ? (
              <div className="space-y-3">
                {participantsData.map((p) => (
                  <div key={p.userId} className="border rounded-md p-3">
                    <div className="flex items-center justify-between">
                      <div className="font-medium">{p.userName} <span className="text-xs text-muted-foreground">({p.userEmail})</span></div>
                      <Badge variant="outline">Players Won: {p.players?.length || 0}</Badge>
                    </div>
                    {p.players && p.players.length > 0 && (
                      <div className="mt-2 text-sm text-muted-foreground">
                        Bought: {p.players.map(pl => `${pl.name} (${pl.role}) - ${formatCurrency(pl.price)}`).join(', ')}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-muted-foreground">No participants loaded.</div>
            )}
          </CardContent>
        </Card>
        <Separator />
        
        {/* Players: All / Sold / Unsold and History */}
        <Card>
          <CardHeader className="flex items-center justify-between">
            <div className="w-full flex items-center justify-between">
              <CardTitle>Players Summary</CardTitle>
              <Button onClick={() => { fetchAuctionHistory(); fetchAuctionData(); }} variant="outline" size="sm">
                <RefreshCw className="h-4 w-4 mr-2" /> Refresh
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <Tabs defaultValue="all" value={activeTab} onValueChange={setActiveTab}>
              <TabsList>
                <TabsTrigger value="roster">All Players ({auctionData?.players?.length || 0})</TabsTrigger>
                <TabsTrigger value="all">All ({auctionHistory.length})</TabsTrigger>
                <TabsTrigger value="sold">Sold ({auctionHistory.filter(h => h.status === 'sold').length})</TabsTrigger>
                <TabsTrigger value="unsold">Unsold ({auctionHistory.filter(h => h.status === 'unsold').length})</TabsTrigger>
                <TabsTrigger value="timeline">Timeline</TabsTrigger>
              </TabsList>

              <TabsContent value="roster">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Player</TableHead>
                      <TableHead>Type</TableHead>
                      <TableHead>Base Price</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Final Price</TableHead>
                      <TableHead>Buyer</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {(!auctionData?.players || auctionData.players.length === 0) && (
                      <TableRow>
                        <TableCell colSpan={6} className="text-center text-muted-foreground">
                          No players found in this auction.
                        </TableCell>
                      </TableRow>
                    )}
                    {(auctionData?.players || []).map((p) => {
                      const res = resultsByPlayerId.get(p.id);
                      const status = res?.status || 'unsold';
                      const price = res?.price || 0;
                      const buyer = res?.team || null;
                      return (
                        <TableRow key={p.id}>
                          <TableCell className="font-medium">{p.name}</TableCell>
                          <TableCell>{p.type || 'N/A'}</TableCell>
                          <TableCell>{p.basePrice ? formatCurrency(p.basePrice) : 'N/A'}</TableCell>
                          <TableCell className={status === 'sold' ? 'text-green-600' : 'text-red-600'}>
                            {status === 'sold' ? 'Sold' : 'Unsold'}
                          </TableCell>
                          <TableCell>{status === 'sold' ? formatCurrency(price) : 'N/A'}</TableCell>
                          <TableCell>{status === 'sold' ? (buyer || 'N/A') : 'N/A'}</TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </TabsContent>

              <TabsContent value="all">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Player</TableHead>
                      <TableHead>Type</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Price</TableHead>
                      <TableHead>Buyer</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {auctionHistory.map((h, idx) => renderPlayerRow(h, idx))}
                  </TableBody>
                </Table>
              </TabsContent>

              <TabsContent value="sold">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Player</TableHead>
                      <TableHead>Type</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Price</TableHead>
                      <TableHead>Buyer</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {auctionHistory.filter(h => h.status === 'sold').map((h, idx) => renderPlayerRow(h, idx))}
                  </TableBody>
                </Table>
              </TabsContent>

              <TabsContent value="unsold">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Player</TableHead>
                      <TableHead>Type</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Price</TableHead>
                      <TableHead>Buyer</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {auctionHistory.filter(h => h.status === 'unsold').map((h, idx) => renderPlayerRow(h, idx))}
                  </TableBody>
                </Table>
              </TabsContent>

              <TabsContent value="timeline">
                <div className="space-y-2">
                  {auctionHistory.length > 0 ? (
                    <div className="border rounded-md divide-y">
                      {auctionHistory.map((item) => (
                        <div key={item.id} className="p-3 hover:bg-gray-50 transition-colors">
                          <div className="flex justify-between items-center">
                            <div className="font-medium">{item.player}</div>
                            <div className="text-sm text-muted-foreground">
                              {item.auctionEndTime ? new Date(item.auctionEndTime).toLocaleString() : ''}
                            </div>
                          </div>
                          <div className="mt-1 text-sm text-muted-foreground">
                            {(item.team || 'Unsold')} • {(item.playerType || '')} • ₹{((item.price || 0))}
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="text-center py-4 text-muted-foreground">
                      No auction history available
                    </div>
                  )}
                </div>
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
        <Separator />
        {/* Current Player on Bid */}
        {currentState && currentState.currentPlayer && (
          <Card>
            <CardHeader>
              <CardTitle>Current Player on Bid</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center gap-4">
                <div className="w-16 h-16 bg-gray-200 rounded-full flex items-center justify-center">
                  {currentState.currentPlayer.image ? (
                    <img
                      src={currentState.currentPlayer.image}
                      alt={currentState.currentPlayer.name}
                      className="w-full h-full rounded-full object-cover"
                    />
                  ) : (
                    <span className="text-lg font-bold">
                      {currentState.currentPlayer.name.charAt(0)}
                    </span>
                  )}
                </div>
                <div>
                  <div className="text-xl font-semibold">
                    {currentState.currentPlayer.name}
                  </div>
                  <div className="text-sm text-muted-foreground">
                    {currentState.currentPlayer.type} •{" "}
                    {currentState.currentPlayer.team}
                  </div>
                  <div className="text-sm text-muted-foreground">
                    Base Price: ₹
                    {(currentState.currentPlayer.basePrice / 10000000).toFixed(
                      1
                    )}{" "}
                    Cr
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div className="text-center">
                  <div className="text-lg font-bold text-green-600">
                    ₹{(currentState.currentBid / 10000000).toFixed(1)} Cr
                  </div>
                  <div className="text-sm text-muted-foreground">
                    Current Bid
                  </div>
                </div>
                <div className="text-center">
                  <div className="text-lg font-bold">
                    {currentState.highestBidder}
                  </div>
                  <div className="text-sm text-muted-foreground">
                    Highest Bidder
                  </div>
                </div>
                <div className="text-center">
                  <div className="text-lg font-bold text-red-600">
                    {currentState.timeRemaining}s
                  </div>
                  <div className="text-sm text-muted-foreground">
                    Time Remaining
                  </div>
                </div>
              </div>

              <Progress value={(currentState.timeRemaining / 20) * 100} />
            </CardContent>
          </Card>
        )}
        {/* Info Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card>
            <CardHeader>
              <CardTitle>Total Players</CardTitle>
            </CardHeader>
            <CardContent>{auction.totalPlayers}</CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Connected Users</CardTitle>
            </CardHeader>
            <CardContent>{connectedUsers}</CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Current Player</CardTitle>
            </CardHeader>
            <CardContent>{auction.currentPlayerIndex || 0}</CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Remaining</CardTitle>
            </CardHeader>
            <CardContent>{remainingPlayers}</CardContent>
          </Card>
        </div>
        {/* Auction Timeline */}
        <Card>
          <CardHeader>
            <CardTitle>Auction Timeline</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <div
                  className={`w-3 h-3 rounded-full ${
                    auction.status === "upcoming"
                      ? "bg-blue-500"
                      : "bg-gray-300"
                  }`}
                />
                <div>
                  <div className="font-medium">Auction Created</div>
                  <div className="text-sm text-muted-foreground">
                    Ready to start
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-3">
                <div
                  className={`w-3 h-3 rounded-full ${
                    auction.status === "ongoing"
                      ? "bg-green-500"
                      : auction.startTime
                      ? "bg-gray-300"
                      : "bg-gray-200"
                  }`}
                />
                <div>
                  <div className="font-medium">Auction Started</div>
                  <div className="text-sm text-muted-foreground">
                    {auction.startTime
                      ? new Date(auction.startTime).toLocaleString()
                      : "Not started yet"}
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-3">
                <div
                  className={`w-3 h-3 rounded-full ${
                    auction.status === "completed"
                      ? "bg-gray-500"
                      : "bg-gray-200"
                  }`}
                />
                <div>
                  <div className="font-medium">Auction Completed</div>
                  <div className="text-sm text-muted-foreground">
                    {auction.status === "completed"
                      ? "Finished"
                      : "In progress..."}
                  </div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
        {/* Live Statistics */}
        {currentState && (
          <Card>
            <CardHeader>
              <CardTitle>Live Auction Statistics</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="text-center p-4 bg-blue-50 rounded-lg">
                  <div className="text-2xl font-bold text-blue-600">
                    {auction.currentPlayerIndex || 0}
                  </div>
                  <div className="text-sm text-blue-600">Players Auctioned</div>
                </div>
                <div className="text-center p-4 bg-green-50 rounded-lg">
                  <div className="text-2xl font-bold text-green-600">
                    {remainingPlayers}
                  </div>
                  <div className="text-sm text-green-600">
                    Players Remaining
                  </div>
                </div>
                <div className="text-center p-4 bg-purple-50 rounded-lg">
                  <div className="text-2xl font-bold text-purple-600">
                    {connectedUsers}
                  </div>
                  <div className="text-sm text-purple-600">Active Bidders</div>
                </div>
                <div className="text-center p-4 bg-orange-50 rounded-lg">
                  <div className="text-2xl font-bold text-orange-600">
                    ₹
                    {currentState.currentBid
                      ? (currentState.currentBid / 10000000).toFixed(1)
                      : "0"}{" "}
                    Cr
                  </div>
                  <div className="text-sm text-orange-600">
                    Current Highest Bid
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        )}
        {/* System Status */}
        <Card>
          <CardHeader>
            <CardTitle>System Status</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <div className="flex justify-between">
                  <span>Auction Engine:</span>
                  <Badge variant={isActive ? "default" : "secondary"}>
                    {isActive ? "Running" : "Stopped"}
                  </Badge>
                </div>
                <div className="flex justify-between">
                  <span>Database Status:</span>
                  <Badge variant="default">Connected</Badge>
                </div>
                <div className="flex justify-between">
                  <span>Redis Cache:</span>
                  <Badge variant="default">Active</Badge>
                </div>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between">
                  <span>Socket Connections:</span>
                  <Badge variant="outline">{connectedUsers} Active</Badge>
                </div>
                <div className="flex justify-between">
                  <span>Auto-retry:</span>
                  <Badge variant={retryCount > 0 ? "destructive" : "secondary"}>
                    {retryCount > 0 ? `${retryCount}/3 Attempts` : "Ready"}
                  </Badge>
                </div>
                <div className="flex justify-between">
                  <span>Last Updated:</span>
                  <span className="text-sm text-muted-foreground">
                    {new Date().toLocaleTimeString()}
                  </span>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
        {/* Quick Actions */}
        {/* <Card>
          <CardHeader>
            <CardTitle>Quick Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <Button
                variant="outline"
                onClick={() => navigate(`/auctions/${id}/players`)}
              >
                Manage Players
              </Button>
              <Button onClick={fetchParticipantsWithPlayers}>
                View Participants & Players
              </Button>
              <Button
                variant="outline"
                onClick={() => navigate(`/auctions/${id}/results`)}
              >
                Auction Results
              </Button>
              <Button
                variant="outline"
                onClick={() => navigate(`/auctions/${id}/logs`)}
              >
                View Logs
              </Button>
            </div>
          </CardContent>
        </Card> */}
        {/* Debug Information (only in development) */}
        {/* <Card>
          <CardHeader>
            <CardTitle>Debug Information</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2 text-sm">
              <div>
                <strong>Auction ID:</strong> {auction.id}
              </div>
              <div>
                <strong>Status:</strong> {auction.status}
              </div>
              <div>
                <strong>Can Start:</strong> {canStart ? "Yes" : "No"}
              </div>
              <div>
                <strong>Is Active:</strong> {isActive ? "Yes" : "No"}
              </div>
              <div>
                <strong>Current State:</strong>{" "}
                {currentState ? "Available" : "Not Available"}
              </div>
              <div>
                <strong>Retry Count:</strong> {retryCount}
              </div>
              {currentState && (
                <details className="mt-4">
                  <summary className="cursor-pointer font-medium">
                    Current State JSON
                  </summary>
                  <pre className="mt-2 p-2 bg-gray-100 rounded text-xs overflow-auto">
                    {JSON.stringify(currentState, null, 2)}
                  </pre>
                </details>
              )}
            </div>
          </CardContent>
        </Card> */}
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
                                <div className="font-semibold">
                                  {player.name}
                                </div>
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
      </div>
    </div>
  );
};

export default AuctionDetail;
