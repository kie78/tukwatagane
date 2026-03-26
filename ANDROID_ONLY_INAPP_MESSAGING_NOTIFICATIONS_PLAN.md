# Android-Only In-App Messaging Notifications Plan (No FCM)

## Objective
Implement reliable new-message notifications for Android users without FCM by combining:
- foreground in-app alerts,
- a persistent Android foreground service for background socket listening,
- local notifications,
- periodic fallback sync.

## Scope
In scope:
- Android only
- WebSocket/STOMP-driven message events
- Local notifications for new unread messages
- Unread badge updates
- Mark-as-read flow

Out of scope:
- iOS support
- FCM/APNs integration
- complete backend redesign of conversation identity

## Architecture Summary
1. App Foreground Path
- Existing STOMP connection receives message events.
- If sender is not current user:
  - update unread counters,
  - show in-app banner/snackbar,
  - optionally post local notification when not in active chat screen.

2. App Background Path (Android)
- Start an Android foreground service after login.
- Service maintains WebSocket/STOMP connection.
- Service posts local notifications on incoming message events.
- Tapping notification routes user to chat thread.

3. Reliability Fallback
- WorkManager periodic task fetches unread summary.
- If new unread detected, create local notification.
- Use as backup when socket disconnects.

## Backend Contract Requirements
Required endpoints/events:
1. Conversation list includes unreadCount per conversation.
2. Mark read endpoint (example: POST /conversations/{id}/read).
3. Optional unread summary endpoint for lightweight sync.
4. STOMP payload includes:
- conversationId
- senderUserId
- body
- createdAt
- optional referencedListingId

## Implementation Phases

## Phase 1: Foundation and Data Model
Tasks:
1. Extend message model in Flutter:
- Add optional referencedListingId to MessageResponse.
- Add send request support for referencedListingId where needed.
2. Centralize unread state management:
- one notifier/service for total unread and per-conversation unread.
3. Add navigation payload schema:
- standard payload for notification taps (conversationId, counterpart metadata).

Deliverables:
- Updated models and unread state manager.
- No platform-specific service yet.

Acceptance criteria:
- Unread badge can be updated from incoming in-app events.
- Message model parses new fields safely.

## Phase 2: Foreground In-App Notification UX
Tasks:
1. Hook into STOMP message callback.
2. If incoming message is from other user:
- increment unread counters,
- show unobtrusive in-app notification.
3. Skip notification when user is currently viewing same conversation.
4. On opening conversation, call mark-read endpoint and decrement counts.

Deliverables:
- In-app alert behavior for open app sessions.

Acceptance criteria:
- User receives immediate in-app alert for new message.
- Badge reflects unread count correctly.
- Opening chat clears unread for that thread.

## Phase 3: Android Foreground Service Listener
Tasks:
1. Add local notification plugin setup and Android notification channels.
2. Implement Android foreground service (persistent notification required by OS).
3. Start service on login; stop on logout.
4. Service listens for new message events and posts local notifications.
5. Notification tap deep-links into app chat screen.

Deliverables:
- Background-capable message listener on Android.
- Local notifications shown when app is not in foreground.

Acceptance criteria:
- With app backgrounded, incoming messages trigger Android notification.
- Tapping notification opens correct conversation screen.
- Service restarts gracefully after temporary network loss.

## Phase 4: WorkManager Fallback Sync
Tasks:
1. Add periodic task (15 min minimum on Android) to sync unread state.
2. Detect newly unread conversations/messages since last sync.
3. Trigger local notifications for new unread items.
4. Store last-sync checkpoint locally.

Deliverables:
- Best-effort backup when socket/service is interrupted.

Acceptance criteria:
- If socket is down, unread sync eventually notifies user.
- No duplicate spam notifications for same message batch.

## Phase 5: Stabilization and Quality
Tasks:
1. Add throttling/de-duplication guard for repeated events.
2. Add network reconnection backoff policy.
3. Add battery optimization guidance screen for Android users.
4. Validate behavior across app states:
- foreground
- background
- task-swiped but service still active
- offline/online transitions

Deliverables:
- production-ready notification behavior with reduced false positives.

Acceptance criteria:
- No crash loops from service restarts.
- Notification delivery is consistent in background.
- Badge and thread unread counts remain correct after long sessions.

## Suggested File-Level Worklist (Flutter)
1. lib/models/models.dart
- Add referencedListingId to MessageResponse (optional).

2. lib/inbox.dart
- Send optional referencedListingId with message body when available.
- Mark thread read on open/resume.

3. lib/chat.dart
- Ensure total unread and per-thread unread reflect server values and local updates.

4. lib/core/stomp_service.dart
- Expose message stream/events for app-level notification coordinator.

5. lib/core/notifications/
- Add notification coordinator and Android local notification helper.

6. android/ (native integration)
- Add foreground service and notification channel wiring.

## Risks and Mitigations
1. Battery drain from persistent connection
- Mitigation: heartbeat tuning, reconnect backoff, user controls.

2. Duplicate notifications from socket + fallback sync
- Mitigation: message-id based de-duplication cache.

3. Android OEM background restrictions
- Mitigation: foreground service + battery optimization exemption guidance.

4. Backend event schema drift
- Mitigation: tolerant JSON parsing and telemetry logs.

## Rollout Strategy
1. Internal QA build with feature flag.
2. Dogfood with logging enabled.
3. Gradual rollout to subset of Android users.
4. Monitor:
- notification open rate,
- unread mismatch incidents,
- service restart frequency,
- battery complaints.

## Done Definition
Feature is complete when:
1. New messages reliably trigger alerts in foreground and background (Android).
2. Notification tap always opens the intended conversation.
3. Unread badge and thread counts stay accurate.
4. Logout fully stops listeners and clears notification side effects.
