# Systemwide Success/Failure Toasts + Signup Real-Time Validation Plan

## Goal
Implement a consistent app-wide status toast system for user-triggered actions and add real-time signup validation while users type.

## Part A: Systemwide Success/Failure Toast Plan

## A1) Current Codebase Audit (actions needing status toasts)
The following user actions are confirmed in code and should be covered by a unified success/failure toast policy.

### Authentication and account
1. Login submit
- File: lib/login.dart
- Action: POST /auth/login
- Current: failure toast exists, success toast missing
- Needed: success toast optional (or silent + navigation), standardized failure mapping

2. Signup Step 1 submit details
- File: lib/signup.dart
- Action: POST /auth/register/start
- Current: validation/failure toasts exist, success toast missing
- Needed: success toast ("Verification code sent") before navigation

3. Signup Step 2 verify OTP
- File: lib/accountAuth.dart
- Action: POST /auth/register/verify-otp
- Current: failure toast exists, success toast missing
- Needed: success toast ("Code verified")

4. Signup Step 3 set password
- File: lib/accountAuth.dart
- Action: POST /auth/register/set-password
- Current: failure toast exists, success toast missing
- Needed: success toast ("Account created")

5. Forgot password send code
- File: lib/forgotPassword.dart
- Action: POST /auth/forgot-password
- Current: failure toast exists, success toast missing
- Needed: success toast ("Reset code sent")

6. Forgot password confirm reset
- File: lib/forgotPassword.dart
- Action: POST /auth/reset-password
- Current: success/failure toasts exist
- Needed: migrate to central toast system

7. Logout
- File: lib/account.dart
- Action: POST /auth/logout
- Current: no success/failure toast
- Needed: info/success toast on logout, warning toast on network failure with local logout fallback message

### Bookmarks and saved items
8. Toggle bookmark from browse card
- File: lib/browse.dart
- Action: POST /bookmarks or DELETE /bookmarks
- Current: success toast exists, failure only reverts UI silently
- Needed: failure toast with rollback confirmation

9. Toggle bookmark from product details
- File: lib/productDetails.dart
- Action: POST /bookmarks or DELETE /bookmarks
- Current: success toast exists, failure mostly silent
- Needed: failure toast

10. Remove saved item
- File: lib/saved.dart
- Action: DELETE /bookmarks
- Current: silent success/failure
- Needed: success and failure toasts

### Chat and conversations
11. Start conversation from product card
- File: lib/browse.dart
- Action: POST /conversations
- Current: mostly silent failure
- Needed: failure toast and optional loading-info toast

12. Start conversation from product details
- File: lib/productDetails.dart
- Action: POST /conversations
- Current: failure toast exists
- Needed: migrate to central toast style + consistent message

13. Start conversation from saved screen
- File: lib/saved.dart
- Action: POST /conversations
- Current: silent failure
- Needed: failure toast

14. Start conversation from vendor profile
- File: lib/vendorProfile.dart
- Action: POST /conversations
- Current: silent failure
- Needed: failure toast

15. Send message in inbox
- File: lib/inbox.dart
- Action: POST /conversations/{id}/messages
- Current: failure toast exists
- Needed: standardize wording and dedupe repeated failures during reconnect periods

### Listings management
16. Create listing
- File: lib/sell.dart
- Action: POST /listings
- Current: mixed success/failure toasts
- Needed: standardized success message and richer error mapping

17. Update listing
- File: lib/sell.dart
- Action: PUT /listings/{id}
- Current: mixed success/failure toasts
- Needed: standardized success/failure messages

18. Remove existing listing image
- File: lib/sell.dart
- Action: DELETE /listings/{id}/images/{imageId}
- Current: silent failure
- Needed: success/failure toasts

19. Upload listing image signature request
- File: lib/sell.dart
- Action: POST /uploads/cloudinary/signature
- Current: partial feedback via generic image upload messages
- Needed: unify under upload toast flow

20. Attach listing image metadata
- File: lib/sell.dart
- Action: POST /listings/{id}/images
- Current: partial success/failure toast for batch
- Needed: standardized batch summary toast with retry affordance later

21. Restore listing
- File: lib/myListings.dart
- Action: POST /listings/{id}/restore
- Current: silent
- Needed: success/failure toasts

22. Purge listing
- File: lib/myListings.dart
- Action: POST /listings/{id}/purge
- Current: silent
- Needed: success/failure toasts (destructive warning style)

23. Delete listing (soft)
- File: lib/myListings.dart
- Action: POST /listings/{id}/delete
- Current: silent
- Needed: success/failure toasts

24. Mark listing sold
- File: lib/myListings.dart
- Action: POST /listings/{id}/sold
- Current: silent
- Needed: success/failure toasts

### Profile and media
25. Upload avatar signature request
- File: lib/userProfile.dart
- Action: POST /uploads/cloudinary/signature
- Current: covered indirectly in generic try/catch
- Needed: standardized staged upload toast progression

26. Confirm avatar with backend
- File: lib/userProfile.dart
- Action: PUT /users/profile/avatar
- Current: success/failure toasts exist
- Needed: central toast style + better error code mapping

27. Share listing
- File: lib/browse.dart
- Action: Share.share (non-API action)
- Current: failure toast exists
- Needed: optional success info toast if desired for consistency

## A2) Toast System Design

### Core principles
1. One centralized toast API (no direct ScaffoldMessenger calls from feature screens).
2. Consistent status types:
- success
- error
- warning
- info
3. Consistent duration and placement.
4. Deduplicate repeated identical errors within a short window.
5. Standard API-error-to-user-message mapping using ApiException code + status.
6. Toast visuals must match the existing app palette using AppColors tokens (no hardcoded one-off colors in screens).

### Proposed structure
1. New helper:
- lib/core/ui/app_toast.dart

2. API:
- AppToast.success(context, message)
- AppToast.error(context, message)
- AppToast.warning(context, message)
- AppToast.info(context, message)
- AppToast.fromApiException(context, ex, fallbackMessage)

3. Optional wrapper for async mutations:
- lib/core/network/mutation_runner.dart
- Handles loading flag, try/catch, and standard success/failure toasts.

### Toast palette spec (must follow app theme)
1. Use AppColors for background, text, and icon accents in all toast variants.
2. Define toast color mapping in one place inside app_toast.dart (success/error/warning/info).
3. If a semantic color is missing in AppColors, add it once in the shared theme file and reuse it everywhere.
4. Avoid direct use of Colors.red/green/orange in feature screens for status messaging.

## A3) Rollout phases (toasts)

### Phase T1: Foundation
1. Add AppToast helper and shared styling tokens.
2. Add error message mapper for common API codes.
3. Add lint guideline: avoid direct ScaffoldMessenger for status toasts.

### Phase T2: High-impact flows first
1. login.dart
2. signup.dart
3. accountAuth.dart
4. forgotPassword.dart
5. inbox.dart

### Phase T3: Commerce flows
1. browse.dart
2. productDetails.dart
3. saved.dart
4. sell.dart
5. myListings.dart
6. vendorProfile.dart

### Phase T4: Cleanup and consistency
1. Replace remaining ad hoc toasts.
2. Add optional action buttons for retry where relevant.
3. Validate message quality (short, actionable, non-technical).

## A4) Acceptance criteria (toasts)
1. Every user-triggered mutation has deterministic success/failure toast behavior.
2. No silent failures for mutation actions.
3. No duplicate spam toasts for repeated identical errors.
4. Existing optimistic UI flows roll back state and show failure toast when backend fails.

## Part B: Signup Real-Time Validation Plan

## B1) Signup entry fields and requirements (from code + API contract)

### Step 1 (signup.dart)
1. fullName
- Required
- Real-time checks: non-empty, minimum length (e.g. 2), trimmed multiple spaces

2. registrationNumber
- Required
- Real-time checks: non-empty, normalized uppercase, pattern guard (campus format hint)

3. email
- Required
- Must end with @must.ac.ug or @std.must.ac.ug (already enforced by AppConfig)
- Real-time checks: valid email shape + allowed domain

4. phoneNumber
- Required
- Real-time checks: numeric normalization, min/max length, +256-prefixed suggestion

5. location choice
- Optional in backend docs, but UI currently enforces one location mode
- Current UX rule in sell-like forms should be mirrored for signup clarity:
  - if current location selected, must resolve coordinates
  - else choose zone (optional fallback if backend allows)

### Step 2 (accountAuth.dart)
6. otp
- Required
- Exactly 5 digits (API doc)
- Real-time checks: numeric-only + length progress indicator

### Step 3 (accountAuth.dart)
7. password
- Required
- Must be 8 to 72 characters (API doc)
- Real-time checks: length meter, optional strength hints

8. confirmPassword
- Required
- Must match password
- Real-time check: mismatch appears immediately while typing

## B2) Current gaps
1. signup.dart validates only on submit; no inline per-field validation state.
2. accountAuth.dart validates OTP length and password match only at submit.
3. Password length (8-72) is not currently enforced client-side in real time.
4. Registration number and phone format feedback are minimal.

## B3) Implementation design for real-time validation

### Validation architecture
1. Add reusable validators:
- lib/core/validation/signup_validators.dart

2. Add lightweight field-state model:
- enum FieldStatus { pristine, valid, invalid }
- error text per field

3. Add listeners in initState for each TextEditingController.

4. Run validators on each change (with tiny debounce for expensive checks only).

### UI behavior
1. Inline helper/error text under each field.
2. Field border states:
- neutral (pristine)
- green (valid)
- red (invalid)
3. Submit button enablement:
- only enabled when required visible fields are valid.
4. OTP cells show per-digit validity and complete-state confirmation.
5. Password section shows checklist:
- length 8-72
- confirm matches
6. Validation visuals must use the same AppColors palette (no hardcoded colors for valid/invalid states).

### Backend error integration
1. Keep server validation as final authority.
2. Map fieldErrors from ApiException to the relevant field inline errors.
3. Also show a general error toast for non-field errors.

## B4) Rollout phases (validation)

### Phase V1: Validators + wiring
1. Implement validator functions and field state tracking.
2. Attach onChanged listeners in signup.dart and accountAuth.dart.

### Phase V2: Inline UX
1. Add per-field error/hint rendering.
2. Add dynamic border/icon states.
3. Disable submit buttons until valid.

### Phase V3: Server-error reconciliation
1. Parse ApiException.fieldErrors where available.
2. Route field-specific backend errors to inline field messages.
3. Preserve toast for global errors.

### Phase V4: Polish and QA
1. Verify typing performance and no jitter.
2. Ensure no stale errors after field correction.
3. Confirm smooth UX across keyboard open/close and screen rotation.

## B5) File-level implementation targets
1. lib/signup.dart
- add real-time validation state for fullName, registrationNumber, email, phone, location mode

2. lib/accountAuth.dart
- add real-time validation for OTP and password/confirmPassword

3. lib/core/validation/signup_validators.dart (new)
- shared validator rules and normalization helpers

4. lib/core/ui/app_toast.dart (new)
- central toast helper reused by signup/auth screens and later entire app

## B6) Acceptance criteria (validation)
1. User sees validation feedback while typing on all signup fields.
2. Invalid fields are clearly indicated before submit.
3. OTP submit blocked until exactly 5 digits.
4. Password submit blocked until 8-72 chars and confirm matches.
5. Server field errors render inline without losing local validation state.
6. All validation state colors and messages follow the shared app palette/theme tokens.

## Suggested execution order
1. Build shared AppToast helper.
2. Migrate auth/signup screens first (highest user impact).
3. Build signup real-time validators and inline UI states.
4. Migrate remaining mutation screens to AppToast.
5. Final pass for consistency and error-message quality.
