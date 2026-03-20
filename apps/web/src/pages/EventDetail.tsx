import { useParams, Link } from "react-router-dom";
import { Button } from "@/components/ui/button.tsx";
import { ArrowLeft, CalendarDays, MapPin, Users } from "lucide-react";

const EventDetail = () => {
  const { id } = useParams();

  return (
    <div className="min-h-screen bg-background">
      <header className="px-6 py-4 max-w-3xl mx-auto flex items-center gap-3">
        <Link to="/dashboard">
          <Button variant="ghost" size="icon" className="rounded-full">
            <ArrowLeft className="h-5 w-5" />
          </Button>
        </Link>
        <h1 className="text-lg font-bold">Event Details</h1>
      </header>

      <main className="px-6 pb-12 max-w-3xl mx-auto space-y-6">
        <div className="rounded-xl bg-card p-6 space-y-4">
          <h2 className="text-xl font-bold">Game Night</h2>
          <div className="space-y-2 text-sm text-muted-foreground">
            <div className="flex items-center gap-2">
              <CalendarDays className="h-4 w-4 text-accent" />
              <span>Saturday, March 22 · 7:00 PM</span>
            </div>
            <div className="flex items-center gap-2">
              <MapPin className="h-4 w-4 text-accent" />
              <span>123 Board Game Blvd</span>
            </div>
            <div className="flex items-center gap-2">
              <Users className="h-4 w-4 text-accent" />
              <span>4 guests invited</span>
            </div>
          </div>
        </div>

        <p className="text-center text-sm text-muted-foreground">
          Event ID: {id}
        </p>
      </main>
    </div>
  );
};

export default EventDetail;
