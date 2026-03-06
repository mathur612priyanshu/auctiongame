import React, { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams, Link } from "react-router-dom";
import axios from "axios";
import { API_URL } from "@/constants";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";

const EditAuction = () => {
  const { id } = useParams();
  const navigate = useNavigate();

  const [loading, setLoading] = useState(false);
  const [fetching, setFetching] = useState(true);
  const [auction, setAuction] = useState(null);
  const [form, setForm] = useState({
    name: "",
    category: "",
    startTime: "",
    minPlayers: "",
    entryAmount: "",
    maxPlayerAllowed: "",
    captain: "",
    vicecaptain: "",
    runPoint: 1,
    wicketPoint: 10,
  });

  const isEditable = useMemo(() => auction?.status === "upcoming", [auction]);

  useEffect(() => {
    const loadAuction = async () => {
      try {
        setFetching(true);
        const res = await axios.get(`${API_URL}/auction/${id}`);
        if (res.status === 200 && res.data?.success) {
          const a = res.data.data;
          setAuction(a);
          setForm({
            name: a.name || "",
            category: a.category || "",
            startTime: a.startTime ? toDateTimeLocal(a.startTime) : "",
            minPlayers: a.minPlayers ?? "",
            entryAmount: a.entryAmount ?? "",
            maxPlayerAllowed: a.maxPlayerAllowed ?? "",
            captain: a.captainPoints ?? "",
            vicecaptain: a.viceCaptainPoints ?? "",
            runPoint: a.runPoint ?? 1,
            wicketPoint: a.wicketPoint ?? 10,
          });
        }
      } catch (err) {
        console.error("Failed to load auction", err);
        alert("Failed to load auction details");
        navigate("/auctions");
      } finally {
        setFetching(false);
      }
    };
    loadAuction();
  }, [id, navigate]);

  const toDateTimeLocal = (iso) => {
    try {
      const d = new Date(iso);
      const pad = (n) => String(n).padStart(2, "0");
      const yyyy = d.getFullYear();
      const mm = pad(d.getMonth() + 1);
      const dd = pad(d.getDate());
      const hh = pad(d.getHours());
      const mi = pad(d.getMinutes());
      return `${yyyy}-${mm}-${dd}T${hh}:${mi}`;
    } catch {
      return "";
    }
  };

  const handleChange = (field, value) => setForm((p) => ({ ...p, [field]: value }));

  const handleSubmit = async () => {
    if (!isEditable) return;
    if (!form.name || !form.category) {
      alert("Please fill in required fields");
      return;
    }
    try {
      setLoading(true);
      const payload = {
        name: form.name,
        category: form.category,
        startTime: form.startTime || null,
        minPlayers: form.minPlayers ? parseInt(form.minPlayers) : undefined,
        entryAmount: form.entryAmount ? parseInt(form.entryAmount) : undefined,
        maxPlayerAllowed: form.maxPlayerAllowed
          ? parseInt(form.maxPlayerAllowed)
          : undefined,
        captainPoints: form.captain ? parseInt(form.captain) : undefined,
        viceCaptainPoints: form.vicecaptain
          ? parseInt(form.vicecaptain)
          : undefined,
        runPoint: form.runPoint ? parseInt(form.runPoint) : undefined,
        wicketPoint: form.wicketPoint ? parseInt(form.wicketPoint) : undefined,
      };
      const res = await axios.put(`${API_URL}/auction/${id}`, payload);
      if (res.status === 200 && res.data?.success) {
        alert("Auction updated successfully");
        navigate("/auctions");
      } else {
        alert(res.data?.message || "Failed to update auction");
      }
    } catch (err) {
      console.error("Failed to update auction", err);
      alert(err.response?.data?.message || "Failed to update auction");
    } finally {
      setLoading(false);
    }
  };

  if (fetching) {
    return (
      <div className="w-11/12 mx-auto mt-10">Loading auction...</div>
    );
  }

  return (
    <Card className="mx-auto p-6 space-y-6 border-none w-11/12 mt-6">
      <CardHeader>
        <CardTitle>
          <div>Edit Auction</div>
          {auction && (
            <div className="text-sm text-gray-500 mt-1">ID: {auction.id} • Status: {auction.status}</div>
          )}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {!isEditable && (
          <div className="p-3 rounded-md bg-yellow-50 text-yellow-800 text-sm">
            This auction is not editable because it has already started or completed.
          </div>
        )}
        <div>
          <Label htmlFor="name">Auction Name *</Label>
          <Input
            id="name"
            value={form.name}
            onChange={(e) => handleChange("name", e.target.value)}
            placeholder="Enter auction name"
            disabled={!isEditable}
          />
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <Label htmlFor="category">Category *</Label>
            <select
              id="category"
              className="w-full h-10 rounded-md border border-input bg-background px-3 py-2 text-sm"
              value={form.category}
              onChange={(e) => handleChange("category", e.target.value)}
              disabled={!isEditable}
            >
              <option value="">Select Category</option>
              <option value="cricket">Cricket</option>
              <option value="football">Football</option>
            </select>
          </div>
          <div>
            <Label htmlFor="startTime">Start Date & Time</Label>
            <Input
              id="startTime"
              type="datetime-local"
              value={form.startTime}
              onChange={(e) => handleChange("startTime", e.target.value)}
              disabled={!isEditable}
            />
          </div>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <Label htmlFor="minPlayers">Number of participants *</Label>
            <Input
              id="minPlayers"
              type="number"
              min="1"
              value={form.minPlayers}
              onChange={(e) => handleChange("minPlayers", e.target.value)}
              disabled={!isEditable}
            />
          </div>
          <div>
            <Label htmlFor="maxPlayerAllowed">Max players allowed to buy *</Label>
            <Input
              id="maxPlayerAllowed"
              type="number"
              min="1"
              value={form.maxPlayerAllowed}
              onChange={(e) => handleChange("maxPlayerAllowed", e.target.value)}
              disabled={!isEditable}
            />
          </div>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <Label htmlFor="entryAmount">Registration Fee *</Label>
            <Input
              id="entryAmount"
              type="number"
              min="0"
              value={form.entryAmount}
              onChange={(e) => handleChange("entryAmount", e.target.value)}
              disabled={!isEditable}
            />
          </div>
          <div>
            <Label htmlFor="captain">Captain Points</Label>
            <Input
              id="captain"
              type="number"
              min="0"
              value={form.captain}
              onChange={(e) => handleChange("captain", e.target.value)}
              disabled={!isEditable}
            />
          </div>
          <div>
            <Label htmlFor="vicecaptain">Vice Captain Points</Label>
            <Input
              id="vicecaptain"
              type="number"
              min="0"
              value={form.vicecaptain}
              onChange={(e) => handleChange("vicecaptain", e.target.value)}
              disabled={!isEditable}
            />
          </div>
          <div>
            <Label htmlFor="runPoint">Run Point</Label>
            <Input
              id="runPoint"
              type="number"
              min="0"
              value={form.runPoint}
              onChange={(e) => handleChange("runPoint", e.target.value)}
              disabled={!isEditable}
            />
          </div>
          <div>
            <Label htmlFor="wicketPoint">Wicket Point</Label>
            <Input
              id="wicketPoint"
              type="number"
              min="0"
              value={form.wicketPoint}
              onChange={(e) => handleChange("wicketPoint", e.target.value)}
              disabled={!isEditable}
            />
          </div>
        </div>
        <Separator />
        <div className="flex justify-between">
          <Link to="/auctions">
            <Button variant="outline">Back</Button>
          </Link>
          <Button onClick={handleSubmit} disabled={!isEditable || loading}>
            {loading ? "Saving..." : "Save Changes"}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
};

export default EditAuction;
