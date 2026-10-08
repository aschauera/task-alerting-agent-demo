---
name: task-intake-workflow
description: |
  Runs the complete ANDRITZ Hydropower task-intake workflow in the required
  order: aggregate recent Outlook and Teams requests, check Planner
  duplicates, collect Ignore or Update decisions, categorize and prioritize
  tasks, obtain final approval, then create or update Planner tasks. Use when
  the user asks to run, start, execute, or demonstrate the complete task-intake
  process. Do not use for a single processing stage.
metadata:
  author: ANDRITZ Hydropower Demo
  version: "1.3.0"
---

# ANDRITZ Task Intake Workflow

Coordinate the four task-intake skills as one controlled, sequential workflow.
This skill owns stage order, handoff validation, user decision gates, and the
final Planner mutation approval. It does not replace the component skills.

## Component skills

Apply these skills in exactly this order:

1. `task-aggregation`
2. `task-deduplication`
3. `task-categorization-prioritization`
4. `task-creation-planner`

Never reorder, parallelize, or omit a stage.

## Target

- Planner plan: `Demo Todos`
- Planner plan ID: `DDjY51B1q0yenINc9Whg6mUAHVGH`
- Microsoft 365 group: `ANDRITZ Task Intake Demo`
- Microsoft 365 group ID: `5c528c8f-bae5-48c7-81ba-ca4d5182c7a3`
- Demo marker: `ANDRITZ-TASK-INTAKE-DEMO`
- Retrieval window: exactly the previous seven days

Stop if a component payload targets a different plan or retrieval window.

## Workflow state

Maintain one internal workflow state with:

- `phase`: `preflight`, `aggregation`, `deduplication`,
  `categorization-prioritization`, `approval`, `planner-mutation`, or
  `complete`;
- the exact JSON payload returned by each completed component skill;
- unresolved duplicate candidate IDs;
- final approval status;
- mutation results when Planner processing begins.

Do not summarize and reconstruct JSON between stages. Pass the complete prior
payload to the next component skill unchanged.

## Phase 1: Preflight

Before aggregation:

1. Confirm Work IQ can access the signed-in user's Outlook email and direct
   Teams messages.
2. Confirm the Planner connector can read and write Demo Todos using the
   grounded plan ID and group ID. Do not require Office 365 Groups discovery.
3. Confirm the user intends to run the complete workflow.
4. State that duplicate decisions and final Planner approval may be required.

If a connector is unavailable or authentication is required, stop and report
the missing capability. Never switch to an unrelated data-access method.

## Phase 2: Task Aggregation

Apply `task-aggregation`.

Validate its output before continuing:

- `schemaVersion` is `1.1`;
- `window.lookbackDays` is `7`;
- `window.start` is exactly seven days before `window.end`;
- top-level `taskCount` equals `tasks.length`;
- every candidate has a title, description, `source.reference`,
  `source.referenceType`, sender, received timestamp, and evidence;
- `source.itemId` and `source.internetMessageId` may be null;
- due dates and projects remain null when they cannot be supported by source
  evidence.

If validation fails, stop with the candidate ID and failed rule. Do not repair
the payload by guessing.

If no candidates are found, report that no actionable requests were found and
finish without calling Planner.

## Phase 3: Task Deduplication

Pass the complete aggregation payload to `task-deduplication`.

The component skill must:

- read all tasks and task details from Demo Todos;
- calculate the documented likeness score;
- automatically mark candidates without a qualifying match as Create;
- present every match scoring 70 or higher;
- collect an explicit Ignore or Update decision for every duplicate;
- collect the selected Planner task ID for every Update.

Pause the workflow while any duplicate remains unresolved. Do not continue on
the basis of a suggested or assumed decision.

Validate the resolved output:

- `schemaVersion` is `1.1`;
- every candidate appears exactly once;
- every decision is `create`, `ignore`, or `update`;
- Create has no duplicate matches or selected task ID;
- Ignore has no selected task ID;
- Update has a selected Planner task ID;
- likeness component scores add up to each reported total.

## Phase 4: Categorization and Prioritization

Pass the complete resolved deduplication payload to
`task-categorization-prioritization`.

Validate its output:

- `schemaVersion` is `1.1`;
- target plan name and ID match this workflow's target;
- `targetPlan.groupId` matches this workflow's Microsoft 365 group ID;
- every Create and Update has exactly one category and priority;
- every Ignore has a null classification;
- Planner priority is one of `1`, `3`, `5`, or `9`;
- project tasks route to the exact inferred project-name bucket;
- other tasks route to `Todo`, `Decision`, or `Meeting request`;
- source, project, due-date, and deduplication data remain unchanged.

Stop on any mismatch rather than silently correcting downstream data.

## Phase 5: Final approval

Before any Planner mutation, present a human-readable review. Do not use a
Markdown table, JSON, pipe-delimited text, or a single dense paragraph.

Use this layout:

1. Heading: `Planner change review`
2. Separate lines for:
   - seven-day scope in the user's time zone;
   - Create, Update, and Ignore counts;
   - statement that no Planner changes have been made.
3. Heading: `Buckets`
   - list existing destination buckets that will be reused;
   - list missing destination buckets that will be created.
4. Group Create and Update entries under one heading per destination bucket.
5. Within each bucket, show one numbered task per line:
   - `Action - Task title - Due date - Category - Priority`
   - add `Existing task: title (task ID)` on the next indented line only for
     Update.
6. Heading: `Warnings`
   - show each warning as a separate bullet;
   - use `None` when there are no warnings.
7. End with a standalone approval question and the two available choices.

Use localized, readable dates such as `16 Oct 2026, 12:00 CEST`. Clearly label
date-only deadlines. Do not repeat `Existing task: None` for Create entries.
Keep technical source and connector diagnostics out of task lines; place them
under Warnings.

Ask the user to choose:

- **Proceed** - create or update all reviewed entries;
- **Cancel** - make no Planner changes.

Do not interpret earlier duplicate decisions as final mutation approval.

If the user cancels:

1. Do not apply `task-creation-planner`.
2. Report the workflow as cancelled before mutation.
3. Preserve the categorized payload so the user can resume by approving it
   later in the same conversation.

Any change to a task after the preview invalidates approval. Rebuild and show
the preview again.

## Phase 6: Planner mutation

Only after explicit Proceed approval, pass the complete categorized payload to
`task-creation-planner`.

That component skill must:

- skip Ignore entries;
- create only Create entries;
- update only each explicitly selected Planner task;
- resolve or create the requested bucket;
- carry normalized task, project, source, due-date, category, priority, and
  demo-marker data into Planner;
- preserve unrelated Planner state during Update;
- use connector-managed concurrency and use ETags when the connector exposes
  them, without blocking solely because an ETag isn't exposed;
- stop after the first failed mutation and report partial completion.

Never retry the full workflow after a partial mutation. Use the returned task
IDs and statuses to determine the safe recovery action.

## Completion report

Return the complete `task-creation-planner` JSON result, then present a concise
human-readable summary with:

- created tasks;
- updated tasks;
- ignored candidates;
- created buckets;
- failed and unprocessed entries;
- warnings;
- whether manual cleanup is required.

Use task IDs and candidate IDs in error reporting.

## Resume behavior

The workflow may resume only from:

- unresolved duplicate decisions;
- final approval after a previously reviewed categorized payload;
- manual recovery after a Planner failure, using fresh Planner data.

If the source messages, target plan, or categorized payload changed, restart
from Task Aggregation.

## Failure behavior

- Fail closed when a stage output is malformed.
- Never fabricate missing fields or IDs.
- Never skip unresolved duplicates.
- Never write to Planner without final approval.
- Never claim success for a failed connector operation.
- Never claim rollback for successful Planner mutations.
- Never continue to later stages after a failed mutation.

## Example invocation

`Run the complete ANDRITZ task-intake workflow for requests from the last seven days.`
