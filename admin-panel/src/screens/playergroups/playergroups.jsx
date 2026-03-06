import React, { useState, useEffect } from "react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Upload,
  FileSpreadsheet,
  Users,
  Trophy,
  Target,
  CheckCircle,
  AlertCircle,
  Loader2,
  Download,
  Eye,
  HardDriveDownload,
} from "lucide-react";
import { API_URL } from "@/constants";
import { toast } from "sonner";

const Playergroups = () => {
  const [playerGroups, setPlayerGroups] = useState([]);
  const [selectedGroup, setSelectedGroup] = useState(null);
  const [selectedFile, setSelectedFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploadResult, setUploadResult] = useState(null);
  const [scoringRules, setScoringRules] = useState({});

  // Fetch player groups on component mount
  useEffect(() => {
    fetchPlayerGroups();
    fetchScoringRules();
  }, []);

  const fetchPlayerGroups = async () => {
    setLoading(true);
    try {
      const response = await fetch(`${API_URL}/player/groups-admin`);
      const data = await response.json();

      if (data.success) {
        setPlayerGroups(data.data);
      } else {
        toast.error("some error occured...!");
      }
    } catch (error) {
      console.error("Error fetching player groups:", error);
      toast.error("some error!");
    } finally {
      setLoading(false);
    }
  };

  const handleToggleGroupStatus = async (groupName, currentStatus) => {
    try {
      const response = await fetch(
        `${API_URL}/player/groups/${groupName}/toggle`,
        {
          method: "PUT",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            isActive: !currentStatus,
            disabledBy: "admin", // You can get this from user context
          }),
        }
      );

      const data = await response.json();

      if (data.success) {
        toast.success(
          `Group ${!currentStatus ? "enabled" : "disabled"} successfully!`
        );
        fetchPlayerGroups(); // Refresh the list
      } else {
        toast.error(data.message || "Failed to update group status");
      }
    } catch (error) {
      console.error("Error toggling group status:", error);
      toast.error("Error updating group status");
    }
  };

  const fetchScoringRules = async () => {
    try {
      const response = await fetch(`${API_URL}/points/scoring-rules`);
      const data = await response.json();

      if (data.success) {
        setScoringRules(data.data);
      }
    } catch (error) {
      console.error("Error fetching scoring rules:", error);
    }
  };

  const handleFileSelect = (event) => {
    const file = event.target.files[0];
    if (file) {
      // Validate file type
      const validTypes = [
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/vnd.ms-excel",
        "text/csv",
      ];

      if (
        !validTypes.includes(file.type) &&
        !file.name.endsWith(".xlsx") &&
        !file.name.endsWith(".xls")
      ) {
        toast({
          title: "Invalid File",
          description: "Please select a valid Excel file (.xlsx or .xls)",
          variant: "destructive",
        });
        return;
      }

      if (file.size > 5 * 1024 * 1024) {
        // 5MB limit
        toast({
          title: "File Too Large",
          description: "File size should be less than 5MB",
          variant: "destructive",
        });
        return;
      }

      setSelectedFile(file);
      setUploadResult(null);
    }
  };

  const handleUpload = async () => {
    console.log(selectedGroup);

    if (!selectedGroup || !selectedFile) {
      toast({
        title: "Missing Information",
        description: "Please select a player group and file",
        variant: "destructive",
      });
      return;
    }

    setUploading(true);
    setUploadProgress(0);

    const formData = new FormData();
    formData.append("file", selectedFile);
    formData.append("playerGroup", selectedGroup.playerGroup);

    try {
      // Simulate progress
      const progressInterval = setInterval(() => {
        setUploadProgress((prev) => {
          if (prev >= 90) {
            clearInterval(progressInterval);
            return prev;
          }
          return prev + 10;
        });
      }, 200);

      const response = await fetch(`${API_URL}/points/upload-points`, {
        method: "POST",
        body: formData,
      });

      clearInterval(progressInterval);
      setUploadProgress(100);

      const data = await response.json();

      if (data.success) {
        setUploadResult(data.data);

        toast.success("uploaded successfully!");

        // Reset form
        setSelectedFile(null);
        const fileInput = document.getElementById("file-upload");
        if (fileInput) fileInput.value = "";

        // Refresh player groups
        fetchPlayerGroups();
      } else {
        toast.error("upload failed!");

        setUploadResult(
          data.data || { errors: 1, errorDetails: [{ error: data.message }] }
        );
      }
    } catch (error) {
      console.error("Error uploading file:", error);
      toast.error("some error occured!");
    } finally {
      setUploading(false);
      setTimeout(() => setUploadProgress(0), 2000);
    }
  };

  const downloadSampleFile = (category) => {
    const rules = scoringRules[category.toLowerCase()] || {};
    const headers = ["name", ...Object.keys(rules)];

    // Create sample data
    const sampleData = [
      headers,
      ["Player 1", ...Object.keys(rules).map(() => "0")],
      ["Player 2", ...Object.keys(rules).map(() => "0")],
    ];

    const csvContent = sampleData.map((row) => row.join(",")).join("\n");
    const blob = new Blob([csvContent], { type: "text/csv" });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${category}_sample_stats.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
  };

  const getScoringRulesForCategory = (category) => {
    return scoringRules[category.toLowerCase()] || {};
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="h-8 w-8 animate-spin" />
        <span className="ml-2">Loading player groups...</span>
      </div>
    );
  }

  return (
    <div className="container mx-auto p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Player Groups Management</h1>
          <p className="text-muted-foreground">
            Upload player statistics and manage leaderboards
          </p>
        </div>
        <Button onClick={fetchPlayerGroups} variant="outline">
          Refresh
        </Button>
      </div>

      <Tabs defaultValue="groups" className="space-y-6">
        <TabsList>
          <TabsTrigger value="groups">View Groups</TabsTrigger>
          <TabsTrigger value="upload">Upload LeaderBoard</TabsTrigger>
        </TabsList>

        <TabsContent value="upload" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Upload className="h-5 w-5" />
                Upload Player Statistics
              </CardTitle>
              <CardDescription>
                Select a player group and upload an Excel file with player
                statistics
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="group-select">Select Player Group</Label>
                <Select
                  value={selectedGroup?.playergroup || ""}
                  onValueChange={(value) => {
                    const group = playerGroups.find(
                      (g) => g.playergroup === value
                    );
                    setSelectedGroup(group);
                  }}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Choose a player group" />
                  </SelectTrigger>
                  <SelectContent>
                    {playerGroups.map((group) => (
                      <SelectItem
                        key={group.playergroup}
                        value={group.playergroup}
                      >
                        <div className="flex items-center justify-between w-full">
                          <span>{group.playerGroup}</span>
                          <div className="flex items-center gap-2 ml-4">
                            <Badge variant="secondary">{group.category}</Badge>
                            <span className="text-sm text-muted-foreground">
                              {group.playerCount} players
                            </span>
                          </div>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {selectedGroup && (
                <Alert>
                  <Target className="h-4 w-4" />
                  <AlertDescription>
                    <div className="space-y-2">
                      <p className="font-medium">
                        Scoring Rules decided based on each auction points
                        defined by admin
                      </p>
                      {/* <div className="flex flex-wrap gap-2">
                        {Object.entries(
                          getScoringRulesForCategory(selectedGroup.category)
                        ).map(([stat, points]) => (
                          <Badge key={stat} variant="outline">
                            {stat}: {points} {points === 1 ? "point" : "points"}
                          </Badge>
                        ))}
                      </div> */}
                      <Button
                        variant="link"
                        size="sm"
                        onClick={() =>
                          downloadSampleFile(selectedGroup.category)
                        }
                        className="p-0 h-auto"
                      >
                        <Download className="h-3 w-3 mr-1" />
                        Download Sample File
                      </Button>
                    </div>
                  </AlertDescription>
                </Alert>
              )}

              <div className="space-y-2">
                <Label htmlFor="file-upload">Upload Excel File</Label>
                <div className="flex items-center gap-4">
                  <Input
                    id="file-upload"
                    type="file"
                    accept=".xlsx,.xls,.csv"
                    onChange={handleFileSelect}
                    disabled={!selectedGroup}
                    className="flex-1"
                  />
                  <Button
                    onClick={handleUpload}
                    disabled={!selectedGroup || !selectedFile || uploading}
                    className="min-w-[120px]"
                  >
                    {uploading ? (
                      <>
                        <Loader2 className="h-4 w-4 animate-spin mr-2" />
                        Uploading...
                      </>
                    ) : (
                      <>
                        <Upload className="h-4 w-4 mr-2" />
                        Upload
                      </>
                    )}
                  </Button>
                </div>
                {selectedFile && (
                  <p className="text-sm text-muted-foreground">
                    Selected: {selectedFile.name} (
                    {(selectedFile.size / 1024).toFixed(1)} KB)
                  </p>
                )}
              </div>

              {uploading && (
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">Upload Progress</span>
                    <span className="text-sm text-muted-foreground">
                      {uploadProgress}%
                    </span>
                  </div>
                  <Progress value={uploadProgress} className="w-full" />
                </div>
              )}

              {uploadResult && (
                <Alert
                  className={
                    uploadResult.errors > 0
                      ? "border-yellow-500"
                      : "border-green-500"
                  }
                >
                  {uploadResult.errors > 0 ? (
                    <AlertCircle className="h-4 w-4" />
                  ) : (
                    <CheckCircle className="h-4 w-4" />
                  )}
                  <AlertDescription>
                    <div className="space-y-2">
                      <p className="font-medium">Upload Results:</p>
                      <div className="grid grid-cols-2 gap-4 text-sm">
                        <div>
                          ✅ Successfully updated: {uploadResult.updated || 0}{" "}
                          players
                        </div>
                        <div>❌ Errors: {uploadResult.errors || 0}</div>
                      </div>
                      {uploadResult.errorDetails &&
                        uploadResult.errorDetails.length > 0 && (
                          <details className="mt-2">
                            <summary className="cursor-pointer font-medium">
                              View Error Details
                            </summary>
                            <div className="mt-2 space-y-1 text-sm">
                              {uploadResult.errorDetails
                                .slice(0, 5)
                                .map((error, index) => (
                                  <div key={index} className="text-red-600">
                                    Row {error.row}: {error.error}
                                  </div>
                                ))}
                              {uploadResult.errorDetails.length > 5 && (
                                <div className="text-muted-foreground">
                                  ... and {uploadResult.errorDetails.length - 5}{" "}
                                  more errors
                                </div>
                              )}
                            </div>
                          </details>
                        )}
                    </div>
                  </AlertDescription>
                </Alert>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="groups" className="space-y-6">
          {/* Player Groups Table */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users className="h-5 w-5" />
                Player Groups Overview
              </CardTitle>
              <CardDescription>
                View all player groups and their associated auctions
              </CardDescription>
            </CardHeader>
            <CardContent>
              {playerGroups.length === 0 ? (
                <div className="text-center py-8">
                  <FileSpreadsheet className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                  <p className="text-muted-foreground">
                    No player groups found
                  </p>
                </div>
              ) : (
                <div className="space-y-4">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Group Name</TableHead>
                        <TableHead>Category</TableHead>
                        <TableHead>Players</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead>Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {playerGroups.map((group) => (
                        <TableRow
                          key={group.playergroup}
                          className={!group.isActive ? "opacity-60" : ""}
                        >
                          <TableCell className="font-medium">
                            {group.playerGroup}
                          </TableCell>
                          <TableCell>
                            <Badge variant="secondary">{group.category}</Badge>
                          </TableCell>
                          <TableCell>
                            <div className="flex items-center gap-2">
                              <Users className="h-4 w-4" />
                              {group.playerCount}
                            </div>
                          </TableCell>
                          <TableCell>
                            <Badge
                              variant={
                                group.isActive ? "default" : "destructive"
                              }
                            >
                              {group.isActive ? "Active" : "Disabled"}
                            </Badge>
                          </TableCell>
                          <TableCell>
                            <div className="flex items-center gap-2">
                              {/* <Button
                                variant="outline"
                                size="sm"
                                onClick={() => setSelectedGroup(group)}
                                disabled={!group.isActive}
                              >
                                <Upload className="h-3 w-3 mr-1" />
                                Upload Stats
                              </Button> */}
                              {/* <Button
                                variant="outline"
                                size="sm"
                                onClick={() => {
                                  // Navigate to leaderboard view
                                  window.open(
                                    `/leaderboard/${group.playergroup}`,
                                    "_blank"
                                  );
                                }}
                              >
                                <Eye className="h-3 w-3 mr-1" />
                                View
                              </Button> */}
                              <Button
                                variant="outline"
                                className={
                                  group.isActive
                                    ? "bg-red-400 hover:bg-red-500"
                                    : "bg-green-400 hover:bg-green-500"
                                }
                                size="sm"
                                onClick={() =>
                                  handleToggleGroupStatus(
                                    group.playergroup,
                                    group.isActive
                                  )
                                }
                              >
                                {group.isActive ? "Disable" : "Enable"}
                              </Button>
                            </div>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Detailed Group Information */}
          {/* {selectedGroup && (
            <Card>
              <CardHeader>
                <CardTitle>
                  Group Details: {selectedGroup.playergroup}
                </CardTitle>
                <CardDescription>
                  Detailed information about the selected player group
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
                  <div className="bg-blue-50 p-4 rounded-lg">
                    <div className="flex items-center gap-2">
                      <Users className="h-5 w-5 text-blue-600" />
                      <span className="font-medium">Total Players</span>
                    </div>
                    <p className="text-2xl font-bold text-blue-600 mt-2">
                      {selectedGroup.playercount}
                    </p>
                  </div>

                  <div className="bg-green-50 p-4 rounded-lg">
                    <div className="flex items-center gap-2">
                      <Trophy className="h-5 w-5 text-green-600" />
                      <span className="font-medium">Auctions</span>
                    </div>
                    <p className="text-2xl font-bold text-green-600 mt-2">
                      {selectedGroup.auctioncount || 0}
                    </p>
                  </div>

                  <div className="bg-purple-50 p-4 rounded-lg">
                    <div className="flex items-center gap-2">
                      <Target className="h-5 w-5 text-purple-600" />
                      <span className="font-medium">Category</span>
                    </div>
                    <p className="text-lg font-bold text-purple-600 mt-2 capitalize">
                      {selectedGroup.category}
                    </p>
                  </div>

                  <div className="bg-orange-50 p-4 rounded-lg">
                    <div className="flex items-center gap-2">
                      <FileSpreadsheet className="h-5 w-5 text-orange-600" />
                      <span className="font-medium">Status</span>
                    </div>
                    <p className="text-lg font-bold text-orange-600 mt-2">
                      Active
                    </p>
                  </div>
                </div>

                {selectedGroup.auctions &&
                  selectedGroup.auctions.length > 0 && (
                    <div className="space-y-4">
                      <h3 className="text-lg font-semibold">
                        Associated Auctions
                      </h3>
                      <div className="grid gap-4">
                        {selectedGroup.auctions.map((auction) => (
                          <div
                            key={auction.id}
                            className="border rounded-lg p-4 hover:bg-gray-50 transition-colors"
                          >
                            <div className="flex items-center justify-between">
                              <div>
                                <h4 className="font-medium">{auction.name}</h4>
                                <div className="flex items-center gap-2 mt-1">
                                  <Badge variant="outline">
                                    {auction.category}
                                  </Badge>
                                  <Badge variant="outline">
                                    {auction.type}
                                  </Badge>
                                  <Badge
                                    variant={
                                      auction.status === "completed"
                                        ? "default"
                                        : auction.status === "ongoing"
                                        ? "destructive"
                                        : "secondary"
                                    }
                                  >
                                    {auction.status}
                                  </Badge>
                                </div>
                              </div>
                              <div className="flex items-center gap-2">
                                <Button
                                  variant="outline"
                                  size="sm"
                                  onClick={() => {
                                    // Navigate to auction leaderboard
                                    window.open(
                                      `/leaderboard/${auction.id}/${selectedGroup.playergroup}`,
                                      "_blank"
                                    );
                                  }}
                                >
                                  <Trophy className="h-3 w-3 mr-1" />
                                  Leaderboard
                                </Button>
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                <div className="mt-6 space-y-4">
                  <h3 className="text-lg font-semibold">Scoring Rules</h3>
                  <div className="bg-gray-50 p-4 rounded-lg">
                    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                      {Object.entries(
                        getScoringRulesForCategory(selectedGroup.category)
                      ).map(([stat, points]) => (
                        <div key={stat} className="text-center">
                          <div className="font-medium capitalize">{stat}</div>
                          <div className="text-2xl font-bold text-blue-600">
                            {points > 0 ? "+" : ""}
                            {points}
                          </div>
                          <div className="text-sm text-muted-foreground">
                            {Math.abs(points) === 1 ? "point" : "points"}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="mt-6 flex items-center gap-4">
                  <Button
                    onClick={() => downloadSampleFile(selectedGroup.category)}
                    variant="outline"
                  >
                    <Download className="h-4 w-4 mr-2" />
                    Download Sample File
                  </Button>
                  <Button
                    onClick={() => {
                      const uploadTab =
                        document.querySelector('[value="upload"]');
                      if (uploadTab) uploadTab.click();
                    }}
                  >
                    <Upload className="h-4 w-4 mr-2" />
                    Upload Stats
                  </Button>
                </div>
              </CardContent>
            </Card>
          )} */}
        </TabsContent>
      </Tabs>

      {/* Help Section */}
      {/* <Card>
        <CardHeader>
          <CardTitle>How to Upload Player Statistics</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="grid md:grid-cols-2 gap-6">
              <div>
                <h4 className="font-medium mb-2">📋 Step-by-Step Guide:</h4>
                <ol className="list-decimal list-inside space-y-1 text-sm">
                  <li>Select a player group from the dropdown</li>
                  <li>Download the sample file to see the required format</li>
                  <li>
                    Fill in your Excel file with player names and statistics
                  </li>
                  <li>Upload the file and wait for processing</li>
                  <li>Check the results and fix any errors if needed</li>
                </ol>
              </div>

              <div>
                <h4 className="font-medium mb-2">
                  📊 File Format Requirements:
                </h4>
                <ul className="list-disc list-inside space-y-1 text-sm">
                  <li>Excel format (.xlsx or .xls) or CSV</li>
                  <li>First column must be 'name' or 'player_name'</li>
                  <li>Other columns should match scoring rule names</li>
                  <li>File size should be less than 5MB</li>
                  <li>
                    Player names should match existing players in the group
                  </li>
                </ul>
              </div>
            </div>

            <Alert>
              <AlertCircle className="h-4 w-4" />
              <AlertDescription>
                <strong>Important:</strong> Make sure player names in your Excel
                file exactly match the names in the database. The system will
                try to find partial matches, but exact matches work best.
              </AlertDescription>
            </Alert>
          </div>
        </CardContent>
      </Card> */}
    </div>
  );
};

export default Playergroups;
