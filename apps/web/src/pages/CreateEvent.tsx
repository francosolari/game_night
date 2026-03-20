import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button.tsx";
import { ArrowLeft } from "lucide-react";

const CreateEvent = () => {
  return (
    <div className="min-h-screen bg-background">
      <header className="px-6 py-4 max-w-3xl mx-auto flex items-center gap-3">
        <Link to="/dashboard">
          <Button variant="ghost" size="icon" className="rounded-full">
            <ArrowLeft className="h-5 w-5" />
          </Button>
        </Link>
        <h1 className="text-lg font-bold">Create Event</h1>
      </header>

      <main className="px-6 pb-12 max-w-3xl mx-auto">
        <div className="rounded-xl bg-card p-8 text-center space-y-3">
          <h2 className="text-lg font-semibold">Event creation coming soon</h2>
          <p className="text-sm text-muted-foreground">
            This will mirror the iOS create event flow with steps for details, games, and invites.
          </p>
        </div>
      </main>
    </div>
  );
};

export default CreateEvent;
