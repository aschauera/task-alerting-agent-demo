---
name: task-deduplication
description: |
  Compares Task Aggregation candidates with tasks in the Demo Todos Microsoft
  Planner plan, calculates a 0-100 likeness score, and asks the user whether
  each possible duplicate should be ignored or used to update the existing
  task. Produces a strict JSON handoff for categorization and Planner creation.
  Use after task-aggregation or when the user asks to check aggregated tasks
  for Planner duplicates. Do not create, update, or delete Planner tasks.
metadata:
  author: ANDRITZ Hydropower Demo
  version: "1.2.0"
---

# Task Deduplication

Compare aggregated task candidates with the target Planner plan, identify
possible duplicates, calculate explainable likeness scores, and capture the
user's Ignore or Update decision.

## Input contract

Accept exactly one Task Aggregation payload that validates against the
Task Aggregation `schemaVersion` `1.1` contract.

Reject the input when:

- `schemaVersion` isn't `1.1`.
- `taskCount` doesn't equal the number of objects in `tasks`.
- A task lacks `candidateId`, `taskTitle`, `description`, or source metadata.
- The payload contains ungrounded placeholder values.

Do not silently repair malformed input. Report the invalid fields and stop.

## Target Planner plan

Use the Microsoft Planner Power Platform connector.

| Setting | Value |
|---|---|
| Plan name | Demo Todos |
| Plan ID | `DDjY51B1q0yenINc9Whg6mUAHVGH` |
| Group name | ANDRITZ Task Intake Demo |
| Group ID | `5c528c8f-bae5-48c7-81ba-ca4d5182c7a3` |

Use the Planner connector's `ListTasks_V3` action with the grounded group ID
and plan ID, then use **Get task details** for every returned task so
descriptions and source metadata are included in comparison.

The connector supplies `connectionId` automatically. Never include it in the
operation input or ask the user for it.

If the plan can't be read, stop and report the connector error. Do not return
all candidates as unique when Planner retrieval fails.

## Non-negotiable scope

- Read Planner tasks; do not create, update, complete, or delete them.
- Compare every aggregation candidate with every task in Demo Todos.
- Calculate likeness using the rubric below; don't invent a score.
- Ask the user before resolving every possible or likely duplicate.
- `Ignore` means skip the incoming candidate and leave the existing Planner
  task unchanged.
- `Update` means retain the incoming candidate and target the selected existing
  Planner task for update by the later Task Creation in Planner skill.
- Do not categorize or prioritize tasks.
- Preserve all aggregation fields and source references unchanged.

## Workflow

### 1. Validate and prepare the aggregation payload

1. Validate the Task Aggregation payload.
2. Preserve the original task ordering and every source field.
3. Normalize text for comparison only:
   - convert to lowercase,
   - collapse whitespace,
   - remove punctuation that doesn't change meaning,
   - ignore email prefixes such as `re:` and `fw:`,
   - retain plant, asset, unit, document, and project identifiers.
4. Never write normalized comparison text back into the task candidate.

### 2. Read the Demo Todos plan

1. Inspect the Planner connector operation description and confirm
   `ListTasks_V3` requires `groupId` and `id`.
2. Call `ListTasks_V3` with:
   - `groupId` = `5c528c8f-bae5-48c7-81ba-ca4d5182c7a3`;
   - `id` = `DDjY51B1q0yenINc9Whg6mUAHVGH`.
3. Do not call Office 365 Groups discovery. The owning group was resolved from
   the plan's Microsoft Graph owner/container when this plugin was configured.
4. Follow pagination until all tasks are collected.
5. Call **Get task details** for each task.
6. Preserve at least:
   - Planner task ID,
   - title,
   - description,
   - due date,
   - priority,
   - percent complete,
   - bucket ID,
   - applied categories,
   - ETag or version metadata when the connector exposes it.

### 3. Calculate pairwise likeness

Score every incoming candidate against every existing Planner task from 0 to
100. Add the five component scores; don't use an unexplainable single model
score.

#### A. Title likeness: 0-40 points

| Points | Criteria |
|---|---|
| 40 | Same action and same asset, deliverable, or document; wording is exact or nearly exact. |
| 30 | Same action and object with minor scope or wording differences. |
| 15 | Same asset or object but a materially different action. |
| 0 | Unrelated action and object. |

#### B. Outcome and description likeness: 0-25 points

| Points | Criteria |
|---|---|
| 25 | Same requested outcome, constraints, and acceptance criteria. |
| 18 | Same primary outcome with partial detail differences. |
| 8 | Related context but a different deliverable. |
| 0 | Unrelated outcome. |

#### C. Project likeness: 0-15 points

| Points | Criteria |
|---|---|
| 15 | Same explicit project code or same explicit project name. |
| 8 | One side lacks a project, but the remaining evidence strongly supports the same project. |
| 0 | Projects conflict or there is no project evidence on either side. |

Project mappings:

- `HP-KAR-2042` = `Karuma II Rehabilitation Program`
- `HP-AMU2-2026` = `Alto Maipo Unit 2 Modernization`

#### D. Due-date likeness: 0-10 points

| Points | Criteria |
|---|---|
| 10 | Same date and time. |
| 8 | Due dates are within one calendar day. |
| 5 | Due dates are within three calendar days. |
| 2 | One task has no due date. |
| 0 | Due dates differ by more than three days or conflict materially. |

#### E. Source likeness: 0-10 points

| Points | Criteria |
|---|---|
| 10 | Same normalized `source.reference`. |
| 6 | Same sender and same email thread or Teams conversation. |
| 3 | Source metadata is missing on one side, but other fields strongly match. |
| 0 | Source metadata conflicts or both sides lack usable source evidence. |

For each scored pair, record the five component scores and short factual match
reasons. The component total must equal `likenessScore`.

### 4. Classify matches

For each incoming candidate, sort Planner matches by score descending.

| Likeness score | Classification | Action |
|---|---|---|
| 85-100 | `likely-duplicate` | Ask the user to Ignore or Update. |
| 70-84 | `possible-duplicate` | Ask the user to Ignore or Update. |
| 0-69 | `not-duplicate` | Don't interrupt the user; mark the candidate for Create. |

Retain all matches scoring 70 or higher in `duplicateMatches`. Don't present
low-scoring pairs as duplicates.

If multiple Planner tasks score 70 or higher:

1. Present all matches in score order.
2. If the user chooses Update, ask which Planner task to update.
3. Never choose between matches whose scores are within five points without
   user confirmation.

### 5. Notify the user and capture decisions

When duplicates exist, present a concise review table before producing the
final JSON:

| Incoming candidate | Existing Planner task | Likeness | Classification | Key reasons |
|---|---|---:|---|---|

Display likeness as both a number and percentage, for example `87/100 (87%)`.
Show the component breakdown on request or when two matches are within five
points.

For every candidate with a score of 70 or higher, ask the user to choose:

- **Ignore** - skip the incoming candidate and leave Planner unchanged.
- **Update** - pass the candidate and selected Planner task ID to the later
  Task Creation in Planner skill.

Do not offer Create for a candidate classified as a duplicate. Do not continue
until every duplicate candidate has an explicit user decision.

Candidates without a duplicate automatically receive decision `create`.

### 6. Produce the handoff

Return one JSON object that validates against
`references/task-deduplication-output.schema.json`.

For each candidate:

- Preserve the complete aggregation candidate in `candidate`.
- Set `decision` to `create`, `ignore`, or `update`.
- Include all matches scoring 70 or higher.
- For `update`, set `selectedPlannerTaskId` to the user-selected task.
- For `ignore`, retain the highest-scoring match for auditability and set
  `selectedPlannerTaskId` to `null`.
- For `create`, use an empty `duplicateMatches` array and a null
  `selectedPlannerTaskId`.

Sort output tasks in the same order as the aggregation input.

## Output rules

- After user decisions are complete, return exactly one JSON object.
- Don't wrap the JSON in a Markdown code fence.
- Don't add commentary before or after the JSON.
- Use `schemaVersion` value `1.1`.
- Set summary counts from the final decisions.
- Subsequent skills must skip entries whose decision is `ignore`.

## Failure behavior

- If Planner retrieval fails, report the connector error and stop.
- If one task's details can't be retrieved, report the task ID and stop rather
  than scoring incomplete data.
- If the user doesn't resolve all duplicates, don't emit a final handoff.
- Never convert an unresolved duplicate into Create.
- Never modify Planner from this skill.

## Additional resources

- `references/task-deduplication-output.schema.json` - strict handoff contract
  for downstream categorization and Planner creation.
