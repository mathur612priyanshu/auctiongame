import React, { useState, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Trophy, Medal, Award } from "lucide-react";
import axios from "axios";
import { API_URL } from "@/constants";

const AuctionLeaderboard = ({ isOpen, onClose, auctionId, auctionName }) => {
  const [leaderboardData, setLeaderboardData] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (isOpen && auctionId) {
      fetchLeaderboardData();
    }
  }, [isOpen, auctionId]);

  const fetchLeaderboardData = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(
        `${API_URL}/leaderboard/auction/${auctionId}`
      );
      if (response.status === 200) {
        setLeaderboardData(response.data.data || []);
      }
    } catch (error) {
      console.error("Failed to fetch leaderboard data:", error);
      setError("Failed to load leaderboard data");
    } finally {
      setLoading(false);
    }
  };

  const getRankIcon = (rank) => {
    switch (rank) {
      case 1:
        return <Trophy className="h-5 w-5 text-yellow-500" />;
      case 2:
        return <Medal className="h-5 w-5 text-gray-400" />;
      case 3:
        return <Award className="h-5 w-5 text-amber-600" />;
      default:
        return <span className="font-bold text-lg">{rank}</span>;
    }
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      minimumFractionDigits: 0,
    }).format(amount);
  };

  const getTopPlayers = (playerDetails, count = 3) => {
    if (!playerDetails || !Array.isArray(playerDetails)) return [];

    return playerDetails.sort((a, b) => b.points - a.points).slice(0, count);
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="max-w-6xl max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="text-2xl font-bold text-center">
            🏆 {auctionName} - Leaderboard
          </DialogTitle>
        </DialogHeader>

        {loading && (
          <div className="flex justify-center items-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
        )}

        {error && <div className="text-center py-8 text-red-600">{error}</div>}

        {!loading && !error && leaderboardData.length === 0 && (
          <div className="text-center py-8 text-gray-500">
            No leaderboard data available for this auction.
          </div>
        )}

        {!loading && !error && leaderboardData.length > 0 && (
          <div className="space-y-6">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-16">Rank</TableHead>
                  <TableHead>User ID</TableHead>
                  <TableHead>Group</TableHead>
                  <TableHead className="text-right">Total Points</TableHead>
                  <TableHead className="text-right">Players Count</TableHead>
                  <TableHead className="text-right">Total Spent</TableHead>
                  <TableHead>Top Players</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {leaderboardData.map((entry) => {
                  const topPlayers = getTopPlayers(entry.playerDetails);

                  return (
                    <TableRow
                      key={`${entry.userId}-${entry.auctionId}`}
                      className="hover:bg-gray-50"
                    >
                      <TableCell className="font-medium">
                        <div className="flex items-center justify-center">
                          {getRankIcon(entry.rank)}
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline">User {entry.userId}</Badge>
                      </TableCell>
                      <TableCell>
                        <Badge variant="secondary">{entry.playerGroup}</Badge>
                      </TableCell>
                      <TableCell className="text-right font-bold text-green-600">
                        {entry.totalPoints}
                      </TableCell>
                      <TableCell className="text-right">
                        {entry.playersCount}
                      </TableCell>
                      <TableCell className="text-right text-red-600">
                        {formatCurrency(entry.totalSpent)}
                      </TableCell>
                      <TableCell>
                        <div className="space-y-1">
                          {topPlayers.map((player, index) => (
                            <div
                              key={`${player.playerId}-${index}`}
                              className="text-sm"
                            >
                              <span className="font-medium">
                                {player.playerName}
                              </span>
                              <span className="text-green-600 ml-2">
                                ({player.points} pts)
                              </span>
                            </div>
                          ))}
                        </div>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
};

export default AuctionLeaderboard;
