import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { Progress } from "@/components/ui/progress";

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

const bidData = [
  { name: "User A", amount: 120 },
  { name: "User B", amount: 180 },
  { name: "User C", amount: 220 },
  { name: "User D", amount: 275 },
];

const players = [
  { id: "virat", name: "Virat Kohli", basePrice: "₹1.5 Cr" },
  { id: "rohit", name: "Rohit Sharma", basePrice: "₹1.4 Cr" },
  { id: "rahul", name: "KL Rahul", basePrice: "₹1.3 Cr" },
];

const PlayerDetail = () => {
  const [showPlayers, setShowPlayers] = useState(true);
  const navigate = useNavigate();

  return (
    <div className="flex w-full min-h-screen">
      {/* Sidebar for Players */}
      {showPlayers && (
        <div className="w-64 p-4 border-r bg-muted space-y-2">
          <h2 className="text-xl font-semibold mb-4">All Players</h2>
          {players.map((player) => (
            <div
              key={player.id}
              className="p-2 bg-white rounded shadow hover:bg-primary/10 cursor-pointer"
              onClick={() => navigate(`/player/details/${player.id}`)}
            >
              <div className="font-medium">{player.name}</div>
              <div className="text-sm text-muted-foreground">
                Base Price: {player.basePrice}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Main Content */}
      <div className="flex-1 p-6 space-y-6">
        {/* Header with Toggle */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold">Auction: KKR vs LSG</h1>
            <p className="text-sm text-muted-foreground">Auction ID: SPZV001</p>
          </div>
          <div className="flex items-center gap-4">
            <Button
              variant="secondary"
              onClick={() => setShowPlayers((prev) => !prev)}
            >
              {showPlayers ? "Hide Player List" : "Show Player List"}
            </Button>
            <Badge variant="default">Ongoing</Badge>
          </div>
        </div>

        <Separator />

        {/* Info Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card>
            <CardHeader>
              <CardTitle>Category</CardTitle>
            </CardHeader>
            <CardContent>Cricket</CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Type</CardTitle>
            </CardHeader>
            <CardContent>IPL</CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Total Participants</CardTitle>
            </CardHeader>
            <CardContent>12</CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Ends In</CardTitle>
            </CardHeader>
            <CardContent>00:12:37</CardContent>
          </Card>
        </div>

        {/* Current Bid Item */}
        <Card>
          <CardHeader>
            <CardTitle>Current Player on Bid</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <div className="text-lg font-semibold">Virat Kohli</div>
            <div className="text-sm text-muted-foreground">
              Base Price: ₹1.5 Cr
            </div>
            <Progress value={70} />
            <div className="flex justify-between text-sm text-muted-foreground">
              <span>Starting</span>
              <span>₹2.5 Cr</span>
            </div>
          </CardContent>
        </Card>

        {/* Bid Graph */}
        <Card>
          <CardHeader>
            <CardTitle>Current Bids Overview</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={bidData}>
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="amount" fill="#4f46e5" />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Participants Table */}
        <Card>
          <CardHeader>
            <CardTitle>Participants</CardTitle>
          </CardHeader>
          <CardContent className="overflow-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-muted-foreground">
                  <th className="py-2">User</th>
                  <th>Bid Amount</th>
                  <th>Time</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td className="py-2">User A</td>
                  <td>₹2.0 Cr</td>
                  <td>12:01:35</td>
                </tr>
                <tr>
                  <td className="py-2">User B</td>
                  <td>₹2.2 Cr</td>
                  <td>12:01:50</td>
                </tr>
                <tr>
                  <td className="py-2">User C</td>
                  <td>₹2.5 Cr</td>
                  <td>12:02:10</td>
                </tr>
              </tbody>
            </table>
          </CardContent>
        </Card>

        {/* Actions */}
        <div className="flex justify-end gap-4">
          <Button variant="outline">Pause Auction</Button>
          <Button variant="destructive">End Auction</Button>
        </div>
      </div>
    </div>
  );
};

export default PlayerDetail;
