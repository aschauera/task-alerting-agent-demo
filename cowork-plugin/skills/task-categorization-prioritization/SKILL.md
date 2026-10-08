---
name: task-categorization-prioritization
description: |
  Classifies resolved task candidates as Project WBS Task, Todo, Decision, or
  Meeting request and assigns Urgent, High, Medium, or Low priority. Routes
  project tasks to per-project Planner buckets and other tasks to category
  buckets, preserving deduplication decisions for later Planner creation. Use
  after task-deduplication. Do not create buckets or modify Planner tasks.
metadata:
  author: ANDRITZ Hydropower Demo
  version: "1.2.0"
---

# Task Categorization and Prioritization

Apply deterministic category, priority, and Planner bucket-routing rules to the
resolved Task Deduplication output.

## Input contract

Accept exactly one Task Deduplication payload with `schemaVersion` `1.1`.

Before processing:

1. Confirm all duplicate candidates have decision `ignore` or `update`.
2. Confirm unique candidates have decision `create`.
3. Confirm every `update` entry has `selectedPlannerTaskId`.
4. Confirm `summary.inputCount` equals the number of task entries.
5. Confirm `targetPlan.id` is `DDjY51B1q0yenINc9Whg6mUAHVGH` and
   `targetPlan.groupId` is `5c528c8f-bae5-48c7-81ba-ca4d5182c7a3`.
6. Reject unresolved or malformed input instead of guessing.

## Non-negotiable scope

- Use only the task candidate and resolved deduplication data.
- Preserve candidate content and source metadata unchanged.
- Preserve `create`, `ignore`, and `update` decisions unchanged.
- Don't classify ignored tasks; set their `classification` to `null`.
- Assign exactly one category and one priority to every Create or Update task.
- Don't call Planner or create buckets. Produce routing instructions for the
  Task Creation in Planner skill.
- Don't change inferred projects or due dates.

## Categories and precedence

Apply the first matching category in this order.

### 1. Project WBS Task

Use `Project WBS Task` whenever `candidate.inferredProject` is non-null.

- Project classification overrides every other category.
- Set `routing.bucketName` to the exact extracted project name.
- Set `routing.createBucketIfMissing` to `true`.
- Carry the project name and project code forward unchanged.

Known project mappings:

- `HP-KAR-2042` = `Karuma II Rehabilitation Program`
- `HP-AMU2-2026` = `Alto Maipo Unit 2 Modernization`

### 2. Meeting request

Use `Meeting request` when the primary requested action is to schedule,
reschedule, arrange, organize, or send invitations for a meeting.

Don't use this category merely because a task:

- is due before a meeting,
- prepares content for a meeting,
- mentions a review meeting, or
- asks for meeting notes or follow-up actions.

Set `routing.bucketName` to `Meeting request`.

### 3. Decision

Use `Decision` when the primary requested outcome is a choice, approval,
rejection, authorization, sign-off, go/no-go decision, or documented decision.

Preparing analysis for someone else's later decision is a `Todo` unless the
user is also asked to make or obtain the decision.

Set `routing.bucketName` to `Decision`.

### 4. Todo

Use `Todo` for every other actionable request, including preparation, review,
investigation, coordination, confirmation, documentation, and follow-up.

Set `routing.bucketName` to `Todo`.

For all non-project categories, set `routing.createBucketIfMissing` to `true`.

## Priority rules

Evaluate priority at `generatedAt` in the task's due-date time zone. Apply the
first matching level.

### Urgent

Assign `Urgent` when any condition is true:

- The task is overdue and incomplete.
- The task is due within the next 24 hours.
- The source explicitly says `urgent`, `ASAP`, `immediately`, `critical`, or
  identifies the task as a current blocker.
- A safety, outage, production, commissioning, or customer-acceptance blocker
  is due within 48 hours.

Set `plannerPriority` to `1`.

### High

Assign `High` when any condition is true and Urgent doesn't apply:

- The task is due more than 24 hours but no more than 72 hours away.
- A customer, contractual, regulatory, safety, or critical-path deliverable is
  due within seven days.
- The source explicitly identifies the request as high priority.

Set `plannerPriority` to `3`, Planner's native `important` value.

### Medium

Assign `Medium` when any condition is true and no higher rule applies:

- The task is due in four to seven days.
- It is a normal committed business request with a clear deliverable.
- It has no due date but has a concrete expected outcome and no evidence for
  High or Urgent.

Set `plannerPriority` to `5`.

### Low

Assign `Low` when no higher rule applies and:

- The task is due more than seven days away, or
- the request is routine, optional, informational follow-up, or explicitly
  low priority.

Set `plannerPriority` to `9`.

## Priority guardrails

- Don't infer urgency from emphatic wording alone.
- Don't promote every project task to High.
- Don't lower an existing Planner task's priority during Update:
  - Planner values `0-1` map to Urgent.
  - Planner values `2-4` map to High.
  - Planner values `5-7` map to Medium.
  - Planner values `8-10` map to Low.
  - Keep the more urgent of the computed priority and existing Planner
    priority.
- Record the source phrase, due-date calculation, or business-impact rule in
  `priorityEvidence`.

## Workflow

For each task entry:

1. If decision is `ignore`, copy the candidate and deduplication summary,
   set `classification` to `null`, and continue.
2. Build the compact `deduplication` summary:
   - preserve `decision` and `selectedPlannerTaskId`;
   - set `highestLikenessScore` to the maximum score in `duplicateMatches`, or
     `null` when the list is empty;
   - for Update, set `existingPlannerPriority` from the selected Planner task;
   - for Ignore, set it from the highest-scoring Planner match;
   - for Create, set it to `null`.
3. Apply the category precedence rules.
4. Create routing instructions:
   - project name bucket for Project WBS Task,
   - otherwise the exact category name bucket.
5. Apply priority rules relative to `generatedAt`.
6. For Update, preserve a more urgent existing Planner priority.
7. Record concise category and priority evidence.
8. Set confidence:
   - `high` for explicit project codes, explicit meeting/decision language,
     explicit urgency, or clear due-date thresholds;
   - `medium` for strong intent or impact inference;
   - `low` only when classification is still defensible but indirect.

## Output contract

Return exactly one JSON object that validates against
`references/task-categorization-prioritization-output.schema.json`.

- Don't wrap the JSON in a Markdown code fence.
- Don't add commentary before or after the JSON.
- Use `schemaVersion` value `1.1`.
- Preserve input task order.
- Set all summary counts from the final output.
- Subsequent skills must skip entries whose decision is `ignore`.

## Failure behavior

- Stop when any duplicate decision is unresolved.
- Stop when an Update entry lacks a selected Planner task ID.
- Don't replace missing due dates or projects with fabricated values.
- If a category or priority can't be defended, report the candidate ID and the
  missing evidence rather than silently defaulting.
- Never modify Planner from this skill.

## Additional resources

- `references/task-categorization-prioritization-output.schema.json` - strict
  handoff contract for Task Creation in Planner.
