import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { Button } from "@/components/ui/button.tsx";
import { Input } from "@/components/ui/input.tsx";
import { Label } from "@/components/ui/label.tsx";
import { Dice5, ArrowLeft, Lock, Phone, KeyRound, User } from "lucide-react";
import { useState } from "react";
import { useAuth } from "@/contexts/AuthContext.tsx";
import { useToast } from "@/hooks/use-toast.ts";
import { supabase } from "@/lib/supabase.ts";

const BETA_PASSWORD = "francosfriend";
const BETA_SHARED_SECRET = "YwxGHvb)MX1pV0eG";

type Step = "beta-password" | "phone" | "account-password" | "display-name";

function normalizePhone(countryCode: string, raw: string): string {
  const digits = raw.replace(/\D/g, "");
  return `${countryCode}${digits}`;
}

const Login = () => {
  const [step, setStep] = useState<Step>("beta-password");
  const [betaPassword, setBetaPassword] = useState("");
  const [countryCode, setCountryCode] = useState("+1");
  const [phoneNumber, setPhoneNumber] = useState("");
  const [accountPassword, setAccountPassword] = useState("");
  const [accountExists, setAccountExists] = useState(false);
  const [displayName, setDisplayName] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { toast } = useToast();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const returnTo = searchParams.get("returnTo");
  const inviteToken = searchParams.get("inviteToken");

  const fullPhone = normalizePhone(countryCode, phoneNumber);
  const phoneDigits = phoneNumber.replace(/\D/g, "");
  const isPhoneValid = phoneDigits.length >= 7;

  const stepIndex = { "beta-password": 0, phone: 1, "account-password": 2, "display-name": 3 }[step];

  const goBack = () => {
    setError(null);
    if (step === "phone") setStep("beta-password");
    else if (step === "account-password") setStep("phone");
    else if (step === "display-name") setStep("account-password");
  };

  // Step 1: Check beta password
  const checkBetaPassword = () => {
    if (betaPassword === BETA_PASSWORD) {
      setError(null);
      setStep("phone");
    } else {
      setError("Wrong password.");
      setBetaPassword("");
    }
  };

  // Step 2: Probe if account exists
  const probePhone = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(
        `https://irhidoryicawwlwrilbb.supabase.co/functions/v1/beta-ensure-user`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-beta-secret": BETA_SHARED_SECRET,
          },
          body: JSON.stringify({ phone: fullPhone, mode: "probe" }),
        }
      );
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Probe failed");
      setAccountExists(data.exists);
      setAccountPassword("");
      setStep("account-password");
    } catch {
      setError("Couldn't check this account. Please try again.");
    }
    setLoading(false);
  };

  // Step 3: Sign in or create account
  const signInOrCreate = async () => {
    setLoading(true);
    setError(null);
    try {
      if (!accountExists) {
        // Create user via edge function first
        const res = await fetch(
          `https://irhidoryicawwlwrilbb.supabase.co/functions/v1/beta-ensure-user`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-beta-secret": BETA_SHARED_SECRET,
            },
            body: JSON.stringify({ phone: fullPhone, password: accountPassword, mode: "ensure" }),
          }
        );
        const data = await res.json();
        if (!res.ok) throw new Error(data.error ?? "Account creation failed");
      }

      // Sign in with phone + password
      const { error: signInError } = await supabase.auth.signInWithPassword({
        phone: fullPhone,
        password: accountPassword,
      });
      if (signInError) throw signInError;

      // Check if user has a profile
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("No user after sign in");

      const { data: profile } = await supabase
        .from("users")
        .select("id")
        .eq("id", user.id)
        .maybeSingle();

      if (profile) {
        navigate(returnTo ?? "/dashboard");
      } else {
        setStep("display-name");
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Something went wrong";
      if (accountExists) {
        setError("Wrong password for this account.");
      } else {
        setError(msg);
      }
    }
    setLoading(false);
  };

  // Step 4: Create profile
  const createProfile = async () => {
    setLoading(true);
    setError(null);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Not signed in");

      const { error: insertError } = await supabase.from("users").upsert({
        id: user.id,
        phone_number: fullPhone,
        display_name: displayName.trim(),
        phone_visible: false,
        discoverable_by_phone: true,
        marketing_opt_in: false,
        contacts_synced: false,
        phone_verified: false,
        privacy_accepted_at: new Date().toISOString(),
      });
      if (insertError) throw insertError;

      toast({ title: "Welcome!", description: "Your account is ready." });
      navigate(returnTo ?? "/dashboard");
    } catch {
      setError("Something went wrong. Please try again.");
    }
    setLoading(false);
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 bg-background">
      <div className="w-full max-w-sm flex flex-col gap-8">
        {/* Logo */}
        <Link to="/" className="flex items-center gap-2 justify-center">
          <Dice5 className="h-7 w-7 text-primary" />
          <span className="text-xl font-bold tracking-tight">CardboardWithMe</span>
        </Link>

        <div className="rounded-xl bg-card p-6 shadow-sm space-y-6">
          {/* Progress bar */}
          <div className="flex gap-1">
            {[0, 1, 2, 3].map((i) => (
              <div
                key={i}
                className={`h-[3px] flex-1 rounded-full transition-colors ${
                  stepIndex >= i ? "bg-primary" : "bg-border"
                }`}
              />
            ))}
          </div>

          {/* Back button */}
          {step !== "beta-password" && (
            <button onClick={goBack} className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
              <ArrowLeft className="h-4 w-4" />
              Back
            </button>
          )}

          {/* Step: Beta Password — NOT a real login, suppress password managers */}
          {step === "beta-password" && (
            <div className="space-y-6">
              <div className="text-center space-y-2">
                <Lock className="h-10 w-10 text-accent mx-auto" />
                <h1 className="text-xl font-bold">Beta Access</h1>
                <p className="text-sm text-muted-foreground">Enter the passphrase Franco gave you.</p>
              </div>
              <form
                className="space-y-4"
                onSubmit={(e) => { e.preventDefault(); checkBetaPassword(); }}
                autoComplete="off"
              >
                <Input
                  type="text"
                  placeholder="Passphrase"
                  value={betaPassword}
                  onChange={(e) => setBetaPassword(e.target.value)}
                  autoFocus
                  autoComplete="off"
                  data-1p-ignore
                  data-lpignore="true"
                  data-form-type="other"
                  className="text-center text-lg"
                />
                {error && <p className="text-sm text-destructive text-center">{error}</p>}
                <Button className="w-full" type="submit" disabled={!betaPassword}>
                  Continue
                </Button>
              </form>
            </div>
          )}

          {/* Step: Phone Number — triggers browser "username" save */}
          {step === "phone" && (
            <div className="space-y-6">
              <div className="text-center space-y-2">
                <Phone className="h-10 w-10 text-primary mx-auto" />
                <h1 className="text-xl font-bold">What's your number?</h1>
                <p className="text-sm text-muted-foreground">
                  We'll use this to identify your account.<br />No verification code needed.
                </p>
              </div>
              <form
                className="space-y-4"
                onSubmit={(e) => { e.preventDefault(); probePhone(); }}
                autoComplete="on"
              >
                <div className="flex gap-2">
                  <select
                    value={countryCode}
                    onChange={(e) => setCountryCode(e.target.value)}
                    className="rounded-lg bg-muted px-3 py-2 text-sm font-medium border-0"
                  >
                    <option value="+1">+1 US</option>
                    <option value="+44">+44 UK</option>
                    <option value="+61">+61 AU</option>
                    <option value="+49">+49 DE</option>
                    <option value="+33">+33 FR</option>
                    <option value="+81">+81 JP</option>
                  </select>
                  <Input
                    type="tel"
                    name="username"
                    placeholder="(555) 123-4567"
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value)}
                    autoFocus
                    autoComplete="username"
                    className="flex-1"
                  />
                </div>
                {error && <p className="text-sm text-destructive text-center">{error}</p>}
                <Button className="w-full" type="submit" disabled={!isPhoneValid || loading}>
                  {loading ? "Checking…" : "Continue"}
                </Button>
              </form>
              <p className="text-xs text-muted-foreground text-center flex items-center justify-center gap-1">
                <Lock className="h-3 w-3" />
                Your number is never shared with other users
              </p>
            </div>
          )}

          {/* Step: Account Password */}
          {step === "account-password" && (
            <div className="space-y-6">
              <div className="text-center space-y-2">
                <KeyRound className="h-10 w-10 text-accent mx-auto" />
                <h1 className="text-xl font-bold">
                  {accountExists ? "Enter account password" : "Create account password"}
                </h1>
                <p className="text-sm text-muted-foreground">
                  {accountExists
                    ? "Use your own account password to sign in."
                    : "Set your own password for beta login."}
                </p>
              </div>
              <form
                className="space-y-4"
                onSubmit={(e) => { e.preventDefault(); signInOrCreate(); }}
                autoComplete="on"
              >
                {/* Hidden username field so browser links password to phone */}
                <input
                  type="hidden"
                  name="username"
                  value={fullPhone}
                  autoComplete="username"
                />
                <Input
                  type="password"
                  name="password"
                  placeholder="Account Password"
                  value={accountPassword}
                  onChange={(e) => setAccountPassword(e.target.value)}
                  autoFocus
                  autoComplete={accountExists ? "current-password" : "new-password"}
                  className="text-center text-lg"
                />
                {error && <p className="text-sm text-destructive text-center">{error}</p>}
                <Button className="w-full" type="submit" disabled={!accountPassword || loading}>
                  {loading ? "Loading…" : accountExists ? "Sign In" : "Create Account"}
                </Button>
              </form>
            </div>
          )}

          {/* Step: Display Name */}
          {step === "display-name" && (
            <div className="space-y-6">
              <div className="text-center space-y-2">
                <User className="h-10 w-10 text-primary mx-auto" />
                <h1 className="text-xl font-bold">What should we call you?</h1>
                <p className="text-sm text-muted-foreground">
                  Pick any name, nickname, or alias.<br />This is what friends see on invites.
                </p>
              </div>
              <form
                className="space-y-4"
                onSubmit={(e) => { e.preventDefault(); createProfile(); }}
              >
                <Input
                  placeholder="e.g. Alex, GameMaster, A."
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  autoFocus
                  className="text-center"
                />
                {error && <p className="text-sm text-destructive text-center">{error}</p>}
                <Button className="w-full" type="submit" disabled={!displayName.trim() || loading}>
                  {loading ? "Loading…" : "Let's Play!"}
                </Button>
              </form>
              <p className="text-xs text-muted-foreground text-center">
                🎭 No real name required — use whatever you like
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Login;
