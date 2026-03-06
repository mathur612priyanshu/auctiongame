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
import { Badge } from "@/components/ui/badge";
import {
  Trash,
  Edit,
  Search,
  UserCheck,
  UserX,
  Plus,
  MoreHorizontal,
  Eye,
} from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Toaster } from "@/components/ui/toaster";
import axios from "axios";
import { API_URL } from "@/constants";
import { toast } from "sonner";

const AllUsers = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [deleteDialog, setDeleteDialog] = useState({
    isOpen: false,
    userId: null,
    userName: "",
  });
  const [editDialog, setEditDialog] = useState({ isOpen: false, user: null });
  const [editForm, setEditForm] = useState({
    name: "",
    email: "",
    points: 0,
    isActive: true,
  });

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/users`);
      if (response.data.success) {
        setUsers(response.data.data);
      }
    } catch (error) {
      console.error("Failed to fetch users:", error);
      toast.error("Sorry some error occured");
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteUser = async (userId) => {
    try {
      const response = await axios.delete(`${API_URL}/users/${userId}`);
      if (response.data.success) {
        setUsers(users.filter((user) => user.id !== userId));
        toast.success("updated successfully");
      }
    } catch (error) {
      console.error("Failed to delete user:", error);
      toast.error("Sorry some error occured");
    }
    setDeleteDialog({ isOpen: false, userId: null, userName: "" });
  };

  const handleStatusToggle = async (userId, currentStatus) => {
    try {
      const response = await axios.patch(`${API_URL}/users/${userId}/status`, {
        isActive: !currentStatus,
      });
      if (response.data.success) {
        setUsers(
          users.map((user) =>
            user.id === userId ? { ...user, isActive: !currentStatus } : user
          )
        );
        toast.success("updated successfully");
      }
    } catch (error) {
      console.error("Failed to update user status:", error);
      toast.error("Sorry some error occured");
    }
  };

  const handleEditUser = (user) => {
    setEditForm({
      name: user.name,
      email: user.email || "",
      points: user.points,
      isActive: user.isActive,
    });
    setEditDialog({ isOpen: true, user });
  };

  const handleUpdateUser = async () => {
    try {
      // Update user points
      await axios.patch(`${API_URL}/users/${editDialog.user.id}/points`, {
        points: parseInt(editForm.points),
      });

      // Update user status if changed
      if (editForm.isActive !== editDialog.user.isActive) {
        await axios.patch(`${API_URL}/users/${editDialog.user.id}/status`, {
          isActive: editForm.isActive,
        });
      }

      // Refresh users list
      fetchUsers();

      toast.success("updated user");

      setEditDialog({ isOpen: false, user: null });
    } catch (error) {
      console.error("Failed to update user:", error);
      toast.error("failed to update user");
    }
  };

  const filteredUsers = users.filter((user) => {
    const matchSearch =
      user.name?.toLowerCase().includes(search.toLowerCase()) ||
      user.email?.toLowerCase().includes(search.toLowerCase()) ||
      user.phone.toString().includes(search) ||
      user.id.toString().includes(search);

    const matchStatus =
      statusFilter === "" ||
      (statusFilter === "active" && user.isActive) ||
      (statusFilter === "inactive" && !user.isActive);

    return matchSearch && matchStatus;
  });

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  if (loading) {
    return (
      <div className="w-11/12 mx-auto h-screen mt-10 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading users...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="w-11/12 mx-auto h-screen mt-10 space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">All Users</h1>
          <p className="text-gray-600 mt-1">Manage and monitor user accounts</p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant="outline" className="text-sm">
            Total: {users.length}
          </Badge>
          <Badge variant="outline" className="text-sm text-green-600">
            Active: {users.filter((u) => u.isActive).length}
          </Badge>
          <Badge variant="outline" className="text-sm text-red-600">
            Inactive: {users.filter((u) => !u.isActive).length}
          </Badge>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-4 items-center justify-between">
        <div className="flex gap-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-4 w-4" />
            <Input
              placeholder="Search by name, email, phone, or ID..."
              className="pl-10 w-80"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <Select
            onValueChange={(val) => setStatusFilter(val)}
            value={statusFilter}
          >
            <SelectTrigger className="w-40">
              <SelectValue placeholder="Filter by Status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Status</SelectItem>
              <SelectItem value="active">Active</SelectItem>
              <SelectItem value="inactive">Inactive</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {/* <Button className="bg-blue-600 hover:bg-blue-700 text-white">
          <Plus className="h-4 w-4 mr-2" />
          Add User
        </Button> */}
      </div>

      {/* Table */}
      <div className="border rounded-lg">
        <Table>
          <TableCaption>
            A list of all registered users in the system.
          </TableCaption>
          <TableHeader>
            <TableRow>
              <TableHead>User ID</TableHead>
              <TableHead>Name</TableHead>
              <TableHead>Email</TableHead>
              <TableHead>Phone</TableHead>
              <TableHead>Points</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Joined</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredUsers.length > 0 ? (
              filteredUsers.map((user) => (
                <TableRow key={user.id}>
                  <TableCell className="font-medium">#{user.id}</TableCell>
                  <TableCell>
                    <div>
                      <div className="font-medium">{user.name}</div>
                      {user.dob && (
                        <div className="text-sm text-gray-500">
                          DOB: {user.dob}
                        </div>
                      )}
                    </div>
                  </TableCell>
                  <TableCell>
                    {user.email ? (
                      <span className="text-sm">{user.email}</span>
                    ) : (
                      <span className="text-gray-400 text-sm">
                        Not provided
                      </span>
                    )}
                  </TableCell>
                  <TableCell>
                    <span className="font-mono text-sm">{user.phone}</span>
                  </TableCell>
                  <TableCell>
                    <Badge variant="secondary" className="font-mono">
                      {user.points.toLocaleString()}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={user.isActive ? "default" : "destructive"}
                      className={
                        user.isActive ? "bg-green-100 text-green-800" : ""
                      }
                    >
                      {user.isActive ? "Active" : "Inactive"}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-sm text-gray-600">
                    {formatDate(user.createdAt)}
                  </TableCell>
                  <TableCell className="text-right">
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" className="h-8 w-8 p-0">
                          <MoreHorizontal className="h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuLabel>Actions</DropdownMenuLabel>
                        <DropdownMenuItem onClick={() => handleEditUser(user)}>
                          <Edit className="mr-2 h-4 w-4" />
                          Edit User
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          onClick={() =>
                            handleStatusToggle(user.id, user.isActive)
                          }
                        >
                          {user.isActive ? (
                            <>
                              <UserX className="mr-2 h-4 w-4" />
                              Deactivate
                            </>
                          ) : (
                            <>
                              <UserCheck className="mr-2 h-4 w-4" />
                              Activate
                            </>
                          )}
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem
                          className="text-red-600"
                          onClick={() =>
                            setDeleteDialog({
                              isOpen: true,
                              userId: user.id,
                              userName: user.name,
                            })
                          }
                        >
                          <Trash className="mr-2 h-4 w-4" />
                          Delete User
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={8} className="text-center py-8">
                  <div className="flex flex-col items-center gap-2">
                    <div className="text-gray-400">
                      <Search className="h-8 w-8" />
                    </div>
                    <p className="text-gray-500">
                      No users found matching your criteria.
                    </p>
                    {(search || statusFilter) && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          setSearch("");
                          setStatusFilter("");
                        }}
                      >
                        Clear Filters
                      </Button>
                    )}
                  </div>
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      {/* Delete Confirmation Dialog */}
      <AlertDialog
        open={deleteDialog.isOpen}
        onOpenChange={(open) =>
          setDeleteDialog({ ...deleteDialog, isOpen: open })
        }
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Are you absolutely sure?</AlertDialogTitle>
            <AlertDialogDescription>
              This action cannot be undone. This will permanently delete the
              user account for <strong>{deleteDialog.userName}</strong> and
              remove all their data from the system.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => handleDeleteUser(deleteDialog.userId)}
              className="bg-red-600 hover:bg-red-700"
            >
              Delete User
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Edit User Dialog */}
      <Dialog
        open={editDialog.isOpen}
        onOpenChange={(open) => setEditDialog({ ...editDialog, isOpen: open })}
      >
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Edit User</DialogTitle>
            <DialogDescription>
              Make changes to user account. Click save when you're done.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="name" className="text-right">
                Name
              </Label>
              <Input
                id="name"
                value={editForm.name}
                onChange={(e) =>
                  setEditForm({ ...editForm, name: e.target.value })
                }
                className="col-span-3"
                disabled
              />
            </div>
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="email" className="text-right">
                Email
              </Label>
              <Input
                id="email"
                value={editForm.email}
                onChange={(e) =>
                  setEditForm({ ...editForm, email: e.target.value })
                }
                className="col-span-3"
                disabled
              />
            </div>
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="points" className="text-right">
                Points
              </Label>
              <Input
                id="points"
                type="number"
                value={editForm.points}
                onChange={(e) =>
                  setEditForm({ ...editForm, points: e.target.value })
                }
                className="col-span-3"
                min="0"
              />
            </div>
            <div className="grid grid-cols-4 items-center gap-4">
              <Label htmlFor="status" className="text-right">
                Status
              </Label>
              <Select
                value={editForm.isActive ? "active" : "inactive"}
                onValueChange={(value) =>
                  setEditForm({ ...editForm, isActive: value === "active" })
                }
              >
                <SelectTrigger className="col-span-3">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="active">Active</SelectItem>
                  <SelectItem value="inactive">Inactive</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setEditDialog({ isOpen: false, user: null })}
            >
              Cancel
            </Button>
            <Button onClick={handleUpdateUser}>Save Changes</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default AllUsers;
