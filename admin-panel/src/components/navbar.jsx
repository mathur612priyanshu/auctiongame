import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

export default function Navbar() {
  return (
    <nav className="w-full h-16 flex items-center justify-between px-6 border-b shadow-sm bg-white">
      <div className="text-xl font-bold">CORE</div>
      <div className="flex items-center gap-4">
        {/* <Input placeholder="Search..." className="w-64" /> */}
        {/* <Avatar>
          <AvatarFallback>AK</AvatarFallback>
        </Avatar> */}
      </div>
    </nav>
  );
}
