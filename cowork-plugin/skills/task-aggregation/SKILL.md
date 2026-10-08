---
name: task-aggregation
description: |
  Finds actionable task requests in the signed-in user's incoming Outlook email
  and Microsoft Teams messages from the last seven days using Work IQ. Produces
  a strict, source-grounded JSON payload for downstream deduplication,
  categorization, prioritization, and Planner creation. Use when the user asks
  to collect, scan, extract, aggregate, or identify tasks from email and Teams.
  Do not use to create Planner tasks or to categorize, prioritize, or
  semantically deduplicate requests.
metadata:
  author: ANDRITZ Hydropower Demo
  version: "1.1.0"
---

# Task Aggregation

Collect actionable requests from incoming Outlook email and Microsoft Teams
messages, normalize them, and return a machine-readable handoff for subsequent
skills.

## Non-negotiable scope

- Use Work IQ only for Microsoft 365 retrieval and grounding.
- Search the seven-day period ending at the current date and time.
- Analyze incoming messages only. Exclude messages authored by the signed-in
  user.
- Include requests with or without a due date or project.
- Do not create or update Planner tasks.
- Do not assign categories or priorities.
- Do not merge semantically similar requests from different source items. The
  Task Deduplication skill handles that later.
- Never invent a task, deadline, project, sender, source link, or source ID.

## Workflow

### 1. Resolve identity and time window

1. Use `GetMyDetails` to resolve the signed-in user's identity and email address.
2. Read the user's local time zone from system context.
3. Set `window.end` to the current date and time.
4. Set `window.start` to exactly seven days before `window.end`.
5. Convert the boundaries to ISO 8601 values while retaining the user's time
   zone in the output.

### 2. Retrieve incoming Work IQ signals

Run email and Teams retrieval in parallel.

#### Outlook email

1. Call `ListMessages` for the Inbox with:
   - `received_after` = `window.start`
   - `received_before` = `window.end`
   - `top` = `100`
2. Follow pagination until all messages in the window are collected, with a
   safety limit of 500 messages.
3. Use `GetMessage` for each message that might contain an actionable request
   so the full body and relevant metadata are available.
4. Exclude sent items, drafts, automated delivery reports, newsletters,
   marketing messages, and messages authored by the signed-in user.

#### Microsoft Teams

Use both retrieval paths for coverage:

1. Call `ListChats`, then call `ListChatMessages` for chats active during the
   seven-day window. Follow pagination and retain only messages whose timestamp
   falls inside the window.
2. Call `SearchM365` with `sources=["teams"]`, `after=window.start`, and
   `before=window.end`. Search broadly for action-oriented requests, including
   requests to prepare, review, send, confirm, update, resolve, obtain, submit,
   schedule, or follow up.
3. Exclude messages authored by the signed-in user.
4. Merge retrieval duplicates only when they have the same Teams message ID.

If one retrieval path fails, continue with the successful sources and add a
specific entry to the output `warnings` array. Do not return a success-shaped
empty result when all Work IQ retrieval fails.

### 3. Identify actionable requests

A message is a task candidate only when it contains a concrete action that the
signed-in user, or a team that includes the user, is expected to complete.

Include:

- Direct requests and assignments.
- Follow-ups with a clear deliverable.
- Requests for review, approval, investigation, preparation, confirmation,
  coordination, or an update.
- Requests whose owner is implied by a direct message to the user.

Exclude:

- Purely informational messages.
- Status updates without a requested next action.
- Social messages, acknowledgements, and automatic notifications.
- Requests explicitly assigned to another person when no action is expected
  from the signed-in user.
- Completed, canceled, or superseded requests.

When one source item contains multiple independent requests, emit one task
candidate per request. Use an ordinal suffix in `candidateId`, starting at 1.

### 4. Normalize each task candidate

#### Task title

- Write an imperative, action-oriented title of 4-12 words.
- Preserve important asset, plant, unit, or document names.
- Do not include the email prefix, sender name, or a due date in the title.

#### Description

- Write one to three factual sentences describing the requested outcome.
- Preserve important constraints, deliverables, and acceptance criteria.
- Do not add recommendations or information absent from the source.

#### Due date

- Infer a due date only when supported by explicit source text.
- Resolve relative phrases such as "tomorrow" against the source message's
  timestamp, not the aggregation run time.
- Resolve day names using the user's local time zone.
- Preserve explicit times. Use `12:00` for noon.
- Interpret "close of business" and "end of day" as `17:00` local time.
- When a date is supported but no time is stated, return a date-only ISO value.
- Return `null` when no defensible due date is available.
- Include the exact source phrase in `evidence`.

#### Project

- Prefer an explicit `Project:` label, project code, or clearly named project.
- Map `HP-KAR-2042` to `Karuma II Rehabilitation Program`.
- Map `HP-AMU2-2026` to `Alto Maipo Unit 2 Modernization`.
- Do not assign a project from a plant or asset name alone.
- Return `null` when no explicit or strongly grounded project reference exists.
- Include the exact source phrase in `evidence`.

#### Source metadata

- Preserve the source channel, item ID when available, Internet Message ID when
  available, conversation ID when available, sender, received timestamp,
  subject or conversation title, source URL when available, and a short
  evidence excerpt.
- Set `source.reference` using the first available value in this order:
  1. source item ID, with `referenceType` = `item-id`;
  2. Internet Message ID, with `referenceType` = `internet-message-id`;
  3. source URL, with `referenceType` = `web-url`;
  4. deterministic value
     `derived:<channel>:<lowercase-sender>:<receivedDateTime>:<normalized-subject-or-conversation-id>`,
     with `referenceType` = `derived`.
- Set unavailable `itemId` and `internetMessageId` values to `null`. Never put
  a derived value into either identifier field.
- Add a warning with the number of candidates using `derived` references.
- Set `candidateId` to
  `<channel>:<source-reference>:<request-ordinal>`.

### 5. Perform source-level quality checks

Before returning:

1. Remove retrieval duplicates with the same channel and source item ID when
   available; otherwise use an exact `source.reference` match.
2. Confirm every candidate has a non-empty `source.reference`,
   `source.referenceType`, and evidence excerpt. Do not fail merely because
   `source.itemId` is null.
3. Confirm every non-null due date and project includes evidence.
4. Confirm `taskCount` equals the number of objects in `tasks`.
5. Validate the payload against
   `references/task-aggregation-output.schema.json`.

Do not perform semantic deduplication across different source items.

## Output contract

Return exactly one JSON object that validates against
`references/task-aggregation-output.schema.json`.

- Do not wrap the JSON in a Markdown code fence.
- Do not add commentary before or after the JSON.
- Use `schemaVersion` value `1.1`.
- Sort tasks by `source.receivedDateTime` ascending, then by `candidateId`.
- Use an empty `tasks` array only when retrieval succeeded and no actionable
  requests were found.

## Failure behavior

- If all email and Teams retrieval fails, stop and report the Work IQ errors.
- If only one source fails, return candidates from the successful source and
  include a clear warning naming the failed source.
- If a source message cannot be opened, do not infer from an incomplete preview
  unless the preview itself contains the complete task request.
- Never replace retrieval errors with fabricated or cached task candidates.

## Additional resources

- `references/task-aggregation-output.schema.json` - machine-readable output
  contract for this skill and all downstream task-processing skills.
