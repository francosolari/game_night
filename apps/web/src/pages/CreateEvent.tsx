import { useState, useRef, useCallback } from "react";
import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { ArrowLeft, Loader2 } from "lucide-react";
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
import { useCreateEvent } from "@/hooks/useCreateEvent";
import { StepIndicator } from "@/components/create-event/StepIndicator";
import { DetailsStep } from "@/components/create-event/DetailsStep";
import { GamesStep } from "@/components/create-event/GamesStep";
import { InvitesStep } from "@/components/create-event/InvitesStep";
import { ReviewStep } from "@/components/create-event/ReviewStep";

const CreateEvent = () => {
  const form = useCreateEvent();
  const [showCancel, setShowCancel] = useState(false);

  // Touch swipe handling
  const touchStartX = useRef(0);
  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartX.current = e.touches[0].clientX;
  };
  const handleTouchEnd = (e: React.TouchEvent) => {
    const diff = e.changedTouches[0].clientX - touchStartX.current;
    if (Math.abs(diff) > 50) {
      if (diff > 0) form.goBack();
      else if (form.canProceed) form.goNext();
    }
  };

  const stepContent = (() => {
    switch (form.currentStep) {
      case "details":
        return <DetailsStep form={form} />;
      case "games":
        return <GamesStep form={form} />;
      case "invites":
        return <InvitesStep form={form} />;
      case "review":
        return <ReviewStep form={form} />;
    }
  })();

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Header */}
      <header className="px-4 py-3 max-w-3xl mx-auto w-full flex items-center gap-3">
        <button onClick={() => setShowCancel(true)}>
          <div className="w-9 h-9 rounded-full flex items-center justify-center hover:bg-muted transition-colors">
            <ArrowLeft className="h-5 w-5" />
          </div>
        </button>
        <h1 className="text-base font-bold flex-1">
          {form.isEditing ? "Edit Event" : "Create Event"}
        </h1>
      </header>

      {/* Step Indicator */}
      <div className="px-4 pb-3 max-w-3xl mx-auto w-full">
        <StepIndicator
          current={form.currentStep}
          completed={form.completedSteps}
          onSelect={form.setCurrentStep}
          isEditing={form.isEditing && !form.isDraftEdit}
        />
      </div>

      {/* Step Content */}
      <main
        className="flex-1 px-4 pb-32 md:pb-8 max-w-3xl mx-auto w-full overflow-y-auto"
        onTouchStart={handleTouchStart}
        onTouchEnd={handleTouchEnd}
      >
        {stepContent}
      </main>

      {/* Bottom Action Bar */}
      <div className="fixed bottom-0 left-0 right-0 md:sticky md:bottom-0 bg-background/95 backdrop-blur-sm border-t border-border/60 p-4 z-30">
        <div className="max-w-3xl mx-auto flex gap-3">
          {!form.isEditing && (
            <Button
              variant="outline"
              className="flex-1 md:flex-none"
              onClick={form.saveDraft}
              disabled={form.isSaving || !form.title.trim()}
            >
              Save Draft
            </Button>
          )}
          {form.currentStep !== "details" && (
            <Button variant="ghost" onClick={form.goBack} disabled={form.isSaving}>
              Back
            </Button>
          )}
          <Button
            className="flex-1"
            onClick={form.handlePrimaryAction}
            disabled={form.isSaving || !form.canProceed}
          >
            {form.isSaving && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
            {form.nextButtonLabel}
          </Button>
        </div>
      </div>

      {/* Cancel Dialog */}
      <AlertDialog open={showCancel} onOpenChange={setShowCancel}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Discard changes?</AlertDialogTitle>
            <AlertDialogDescription>
              You'll lose any unsaved progress on this event.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Keep Editing</AlertDialogCancel>
            {!form.isEditing && form.title.trim() && (
              <AlertDialogAction
                onClick={() => {
                  form.saveDraft();
                }}
              >
                Save Draft
              </AlertDialogAction>
            )}
            <AlertDialogAction
              onClick={() => form.navigate("/dashboard")}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              Discard
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
};

export default CreateEvent;
