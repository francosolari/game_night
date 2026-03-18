# I'm using the writing-plans skill to create the implementation plan.

# Beta Auth Bypass Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the hidden beta flow create or reconcile verified phone accounts (with individual passwords) without triggering SMS, while leaving the production OTP path untouched.

**Architecture:**  Introduce a supabase Edge Function that uses the service role key to ensure the beta phone exists, has `phone_confirmed=true`, and retains its own password, then update the beta UI flow to call that function before calling the normal password sign-in. The regular OTP onboarding keeps calling Supabase’s phone OTP endpoints, so nothing else changes.

**Tech Stack:** Supabase Edge Functions (Deno + supabase-js), SupabaseService Swift wrapper, SwiftUI onboarding views, Supabase SQL trigger for user row creation.

---

### Task 1: Create `beta-ensure-user` Edge Function

**Files:**
- Create: `Supabase/functions/beta-ensure-user/index.ts`
- Modify: `Supabase/functions/_shared/auth.ts` (if needed to expose helper)

- [ ] **Step 1: Draft the new function skeleton**
  ```ts
  import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
  import { createServiceClient } from "../_shared/auth.ts";
  ```
  Expected: responds 401 when header missing and 400 when payload incomplete.

- [ ] **Step 2: Implement logic**
  ```ts
  const reqSecret = req.headers.get("x-beta-secret");
  if (reqSecret !== Deno.env.get("BETA_SHARED_SECRET")) return 403;
  const { phone, password } = await req.json();
  const supabase = createServiceClient();
  await supabase.auth.admin.upsertUser({ phone, password, phone_confirmed: true });
  ```
  Expected: returns 200 + user id regardless whether user already existed.

- [ ] **Step 3: Add error handling + logging**
  Include try/catch, log errors, and return descriptive JSON errors so the client can differentiate missing secret vs Supabase failure.

- [ ] **Step 4: Deploy & list function in docs**
  Run: `supabase functions deploy beta-ensure-user` (requires service role key).  Confirm environment var `BETA_SHARED_SECRET` is set in the Supabase dashboard.  Expect: function deploys with `public` visibility (unless secret mode required).

- [ ] **Step 5: Manual sanity check**
  Use `curl` with the shared secret to POST a test phone/password; ensure response 200 even when the phone already exists.

### Task 2: Extend `SupabaseService` with beta helper

**Files:**
- Modify: `GameNight/GameNight/Services/SupabaseService.swift:60-120`

- [ ] **Step 1: Add helper struct for beta payload**
  ```swift
  struct BetaUserPayload: Encodable {
      let phone: String
      let password: String
  }
  ```

- [ ] **Step 2: Add `ensureBetaUser` method**
  Should POST to `Secrets.supabaseURL/functions/v1/beta-ensure-user` with header `x-beta-secret: Secrets.betaSharedSecret`, body `BetaUserPayload`, and throw if the function returns a non-200 status.

- [ ] **Step 3: Wire Secret**
  Add `static let betaSharedSecret = Secrets.betaSharedSecret` in `Secrets` (if not already defined) and ensure it is injected from env/config.

- [ ] **Step 4: Document the flow in SupabaseServiceTests (if applicable)**
  If there’s a test suite, add a new test that mocks the HTTP client to verify the helper calls the correct URL/headers.

- [ ] **Step 5: Manual verification**
  Build the app and run the beta login flow with the helper stubbed (or hitting a local preview of the function) to confirm we never reach the OTP path.

### Task 3: Update beta onboarding to call helper

**Files:**
- Modify: `GameNight/GameNight/Views/Onboarding/OnboardingView.swift:975-1016`

- [ ] **Step 1: Invoke `ensureBetaUser` before `signInWithPassword`**
  Replace the current `signUpWithPassword` attempt with a call to `SupabaseService.shared.ensureBetaUser(phoneNumber: fullPhoneNumber, password: correctPassword)` (can be awaited). This ensures the user exists and is confirmed before we sign in.

- [ ] **Step 2: Keep existing password & display name handling**
  After the helper and the `signInWithPassword` call succeed, proceed to the `.name` step exactly as today (the helper should not mutate `displayName`).

- [ ] **Step 3: Handle helper errors gracefully**
  If ensuring the beta user fails (wrong secret, Supabase down), show an error message in the UI and keep `isLoading` false.

- [ ] **Step 4: Manual regression**
  Run the beta flow in the simulator/device, tap the lock three times, enter `francosfriend`, provide a real test phone, and ensure you land on the name screen without an SMS being sent. Validate the invite and single-password requirement by switching between test numbers.

### Task 4: Update secrets/config

**Files:**
- Modify: `docs/superpowers/specs/...` or `GameNight/GameNight/Secrets.swift` (where secrets stored)

- [ ] **Step 1: Add `betaSharedSecret` to the Secrets helper**
  Ensure the Swift `Secrets` struct exposes the new value and the config file/environment exports it.

- [ ] **Step 2: Add instructions**
  Document in the README or docs how to set `BETA_SHARED_SECRET` in Supabase and `Secrets.betaSharedSecret` locally.

- [ ] **Step 3: Manual check**
  Confirm that both the app and the deployed function read the same secret value by logging (or printing) the retrieved secret when hitting the function (be careful not to log in production). Ensure the secret is consistent across dev, staging, and release environments.

### Task 5: Validation sweep

**Files:**
- Manual (no files)

- [ ] **Step 1:** With two real phones (or sims) create events, invite one from the other, and verify the new beta accounts behave like real accounts (display name, privacy settings, searchability by phone).
- [ ] **Step 2:** Monitor Supabase logs for the new function to ensure it always returns 200/201 and doesn’t accidentally send OTPs.
- [ ] **Step 3:** Keep the regular OTP onboarding path working by running that flow separately and confirming SMS still dispatches when Twilio is reachable.

**Plan complete. Ready to execute?**
