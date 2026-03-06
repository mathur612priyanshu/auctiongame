import {
  Group,
  Inbox,
  PersonStanding,
  User2,
  LogOut,
  Trophy,
  Plus,
} from "lucide-react";

import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarTrigger,
  SidebarHeader,
  SidebarFooter,
} from "@/components/ui/sidebar";
import { Link, useNavigate, useLocation } from "react-router-dom";
import { useContext } from "react";
import { AuthContext } from "@/contexts/AuthContext";

export default function Layout({ children }) {
  const { logout } = useContext(AuthContext);
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  const mainItems = [
    {
      title: "Users",
      url: "/allusers",
      icon: User2,
    },
    {
      title: "Auctions",
      url: "/auctions",
      icon: Inbox,
    },
    {
      title: "Create Auction",
      url: "/create-auction",
      icon: Plus,
    },
    {
      title: "Players",
      url: "/players",
      icon: PersonStanding,
    },
    {
      title: "Tournaments",
      url: "/player/groups",
      icon: Trophy,
    },
  ];

  return (
    <div className="flex h-screen bg-gray-50">
      <Sidebar collapsible="icon" className="border-r border-gray-200">
        <SidebarHeader className="border-b border-gray-200 px-4 py-6">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-gradient-to-br from-green-500 to-emerald-600 text-white font-bold text-lg shadow-lg">
              C
            </div>
            <div className="flex flex-col">
              <span className="text-2xl font-bold text-gray-900">CORE</span>
              <span className="text-sm text-gray-500">Auction Platform</span>
            </div>
          </div>
        </SidebarHeader>

        <SidebarContent className="px-2 py-4">
          <SidebarGroup>
            <SidebarGroupLabel className="px-3 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wider">
              Navigation
            </SidebarGroupLabel>
            <SidebarGroupContent>
              <SidebarMenu className="space-y-1">
                {mainItems.map((item) => {
                  const isActive = location.pathname === item.url;
                  return (
                    <SidebarMenuItem key={item.title}>
                      <SidebarMenuButton 
                        asChild 
                        className={`
                          relative h-11 px-3 rounded-lg transition-all duration-200 group
                          ${isActive 
                            ? 'bg-gradient-to-r from-green-500 to-emerald-600 text-white shadow-md' 
                            : 'text-gray-700 hover:bg-gray-100 hover:text-gray-900'
                          }
                        `}
                      >
                        <Link to={item.url}>
                          <item.icon className={`
                            h-5 w-5 transition-transform duration-200 group-hover:scale-110
                            ${isActive ? 'text-white' : 'text-gray-500'}
                          `} />
                          <span className="font-medium text-sm">{item.title}</span>
                          {isActive && (
                            <div className="absolute right-2 h-2 w-2 rounded-full bg-white opacity-80" />
                          )}
                        </Link>
                      </SidebarMenuButton>
                    </SidebarMenuItem>
                  );
                })}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        </SidebarContent>

        <SidebarFooter className="border-t border-gray-200 p-2">
          <SidebarMenuItem>
            <SidebarMenuButton
              onClick={handleLogout}
              className="h-11 px-3 rounded-lg text-red-600 hover:bg-red-50 hover:text-red-700 transition-all duration-200 group"
            >
              <LogOut className="h-5 w-5 transition-transform duration-200 group-hover:scale-110" />
              <span className="font-medium text-sm">Logout</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarFooter>
      </Sidebar>

      {/* Sidebar trigger for mobile */}
      <div className="lg:hidden">
        <SidebarTrigger className="fixed top-4 left-4 z-50 h-10 w-10 rounded-lg bg-white shadow-md border border-gray-200 hover:bg-gray-50" />
      </div>

      {/* Main content area */}
      <main className="flex-1 overflow-auto bg-white">
        <div className="h-full">
          {children}
        </div>
      </main>
    </div>
  );
}