import "./App.css";
import { SidebarProvider } from "./components/ui/sidebar";
import AuctionList from "./screens/Auctions/AuctionList";
import Home from "./screens/Home";
import Layout from "./screens/layout";
import {
  BrowserRouter as Router,
  Routes,
  Route,
  useLocation,
  Navigate,
} from "react-router-dom";
import AuctionDetail from "./screens/Auctions/AuctionDetail";
import Navbar from "./components/navbar";
import CreateAuction from "./screens/Auctions/CreateAuction";
import EditAuction from "./screens/Auctions/EditAuction";
import PlayerList from "./screens/Players/PlayerList";
import CreatePlayer from "./screens/Players/CreatePlayer";
import PlayerDetail from "./screens/Players/PlayerDetail";
import { Toaster } from "./components/ui/sonner";
import Playergroups from "./screens/playergroups/playergroups";
import AllUsers from "./screens/AllUsers";
import Login from "./screens/login/login";
import { AuthProvider, useAuth } from "./contexts/AuthContext";
import { ProtectedRoute, PublicRoute } from "./components/ProtectedRoute";
const RouteNavigation = () => {
  const location = useLocation();
  const noSidebarRoutes = ["/login", "/signup"];
  const { isAuthenticated } = useAuth();

  return (
    <div className="flex w-full h-screen">
      {!noSidebarRoutes.includes(location.pathname) && isAuthenticated && (
        <Layout />
      )}
      <div className="flex-1 h-screen flex justify-center items-start">
        <div className="w-full h-full flex flex-col">
          {isAuthenticated && <Navbar />}
          <div
            className={`flex-1 h-full overflow-y-auto ${
              isAuthenticated ? "sm:p-4" : ""
            }`}
          >
            <Routes>
              <Route
                path="/login"
                element={
                  <PublicRoute>
                    <Login />
                  </PublicRoute>
                }
              />
              <Route
                path="/"
                element={
                  <ProtectedRoute>
                    <Home />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/allusers"
                element={
                  <ProtectedRoute>
                    <AllUsers />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/auctions"
                element={
                  <ProtectedRoute>
                    <AuctionList />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/create-auction"
                element={
                  <ProtectedRoute>
                    <CreateAuction />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/auctions/:id"
                element={
                  <ProtectedRoute>
                    <AuctionDetail />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/auctions/:id/edit"
                element={
                  <ProtectedRoute>
                    <EditAuction />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/players"
                element={
                  <ProtectedRoute>
                    <PlayerList />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/create-player"
                element={
                  <ProtectedRoute>
                    <CreatePlayer />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/player/:id"
                element={
                  <ProtectedRoute>
                    <PlayerDetail />
                  </ProtectedRoute>
                }
              />{" "}
              <Route
                path="/player/groups"
                element={
                  <ProtectedRoute>
                    <Playergroups />
                  </ProtectedRoute>
                }
              />
              <Route
                path="*"
                element={
                  <ProtectedRoute>
                    <div className="flex items-center justify-center h-full">
                      <div className="text-center">
                        <h1 className="text-4xl font-bold text-gray-800">
                          404
                        </h1>
                        <p className="text-xl text-gray-600">Page not found</p>
                      </div>
                    </div>
                  </ProtectedRoute>
                }
              />
            </Routes>
          </div>
        </div>
      </div>
    </div>
  );
};

function App() {
  return (
    <Router>
      <AuthProvider>
        <SidebarProvider>
          <Toaster />
          <RouteNavigation />
        </SidebarProvider>
      </AuthProvider>
    </Router>
  );
}

export default App;
