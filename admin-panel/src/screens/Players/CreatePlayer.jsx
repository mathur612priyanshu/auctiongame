import React, { useState } from "react";
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

const allPlayers = [
  { id: "p1", name: "Virat Kohli" },
  { id: "p2", name: "Rohit Sharma" },
  { id: "p3", name: "MS Dhoni" },
  { id: "p4", name: "Hardik Pandya" },
  { id: "p5", name: "KL Rahul" },
];

const CreatePlayer = () => {
  const [form, setForm] = useState({
    name: "",
    category: "",
    type: "",
    maxPlayers: "",
    selectedPlayers: [],
  });

  const handleChange = (field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSubmit = () => {
    console.log("Auction Data:", form);
    // TODO: POST to backend
  };

  return (
    <Card className=" mx-auto p-6 space-y-6 border-none">
      <CardHeader>
        <CardTitle>Create New Auction</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <Label htmlFor="name">Auction Name</Label>
          <Input
            id="name"
            value={form.name}
            onChange={(e) => handleChange("name", e.target.value)}
          />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <Label htmlFor="category">Category</Label>
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
            <Label htmlFor="type">Type</Label>
            <Select onValueChange={(val) => handleChange("type", val)}>
              <SelectTrigger>
                <SelectValue placeholder="Select Type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="IPL">IPL</SelectItem>
                <SelectItem value="T20">T20</SelectItem>
                <SelectItem value="WorldCup">World Cup</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        <div>
          <Label htmlFor="maxPlayers">Max Players Allowed</Label>
          <Input
            type="number"
            min={1}
            id="maxPlayers"
            value={form.maxPlayers}
            onChange={(e) => handleChange("maxPlayers", e.target.value)}
          />
        </div>

        <div>
          <Label>Choose Players</Label>
          <MultiSelect
            options={allPlayers}
            selected={form.selectedPlayers}
            onChange={(selected) => handleChange("selectedPlayers", selected)}
          />
        </div>

        <Separator />

        <div className="flex justify-end gap-4">
          <Button
            variant="outline"
            onClick={() =>
              setForm({
                name: "",
                category: "",
                type: "",
                maxPlayers: "",
                selectedPlayers: [],
              })
            }
          >
            Reset
          </Button>
          <Button onClick={handleSubmit}>Create Auction</Button>
        </div>
      </CardContent>
    </Card>
  );
};

export default CreatePlayer;
