---
name: task-creation-planner
description: |
  Creates or updates tasks in the Demo Todos Planner plan from resolved,
  categorized task candidates. Resolves or creates the requested project and
  category buckets, carries source, project, due-date, category, and priority
  information into Planner, and returns an explicit result for every input.
  Use only after task-categorization-prioritization.
metadata:
  author: ANDRITZ Hydropower Demo
  version: "1.3.0"
---

# Task Creation in Planner

Apply the resolved Task Categorization and Prioritization payload to Microsoft
Planner through the Planner connector.

## Input contract

Accept exactly one Task Categorization and Prioritization payload with
`schemaVersion` `1.1`.

Before any Planner mutation:

1. Confirm `targetPlan.name` is `Demo Todos`.
2. Confirm `targetPlan.id` is `DDjY51B1q0yenINc9Whg6mUAHVGH`.
3. Confirm `targetPlan.groupId` is
   `5c528c8f-bae5-48c7-81ba-ca4d5182c7a3`.
4. Confirm `summary.inputCount` equals the number of task entries.
5. Confirm every Create or Update entry has a non-null `classification`.
6. Confirm every Ignore entry has a null `classification`.
7. Confirm every Update entry has a non-empty `selectedPlannerTaskId`.
8. Reject malformed or unresolved input instead of guessing.

## Required Planner connector operations

Use native Planner connector actions for:

- listing buckets in a plan;
- creating a bucket;
- creating a task;
- retrieving a task and its details;
- updating a task;
- updating task details.

Use connector response identifiers exactly as returned. Use ETags when the
connector exposes them, but do not block this demo solely because a Planner
connector action manages concurrency internally and does not expose an ETag.
Never report a mutation as successful without a successful connector response.

For Planner V3 operations:

- use `groupId` = `5c528c8f-bae5-48c7-81ba-ca4d5182c7a3`;
- use plan `id` = `DDjY51B1q0yenINc9Whg6mUAHVGH`;
- let the connector supply `connectionId` automatically;
- inspect operation descriptions directly when confirming required inputs;
- do not run a script or call Office 365 Groups discovery to infer inputs.

## Non-negotiable scope

- Write only to the target plan in the input.
- Skip every task whose deduplication decision is `ignore`.
- Create only entries whose decision is `create`.
- Update only the exact `selectedPlannerTaskId` for entries whose decision is
  `update`.
- Never delete tasks, buckets, checklists, references, or assignments.
- Preserve candidate content, inferred project data, source metadata,
  classification, and routing values unchanged.
- Preserve existing completion, assignments, checklist, references, start
  date, and unrelated task-detail content during Update.
- Do not perform another duplicate search or change an upstream decision.

## Bucket resolution

Before processing tasks, call `ListBuckets_V3` with the grounded `groupId` and
plan `id`, then build a lookup of every returned bucket by its exact name.

For each Create or Update entry:

1. Read `classification.routing.bucketName`.
2. Reuse the bucket when an exact, case-sensitive name match exists.
3. If no exact match exists and `createBucketIfMissing` is `true`, create one
   bucket with that exact name in the target plan.
4. Add a newly created bucket to the lookup immediately so later entries reuse
   it.
5. If multiple existing buckets have the same exact name, stop before task
   mutation and report the ambiguous bucket IDs.

Expected bucket names are:

- the exact inferred project name for `Project WBS Task`;
- `Todo`;
- `Decision`;
- `Meeting request`.

Do not create an `Ignore` bucket or a bucket for an ignored item.

## Planner field mapping

Map every Create or Update entry as follows:

| Planner field | Source |
|---|---|
| Plan ID | `targetPlan.id` |
| Bucket ID | Resolved ID for `classification.routing.bucketName` |
| Title | `candidate.taskTitle` |
| Due date/time | `candidate.inferredDueDate.value`, when non-null |
| Priority | `classification.plannerPriority` |
| Description | Managed description defined below |
| Percent complete | `0` for Create; preserve existing value for Update |

For Create, omit the due-date property when the inferred due date is null.
For Update, preserve the existing Planner due date when the inferred due date
is null. Never clear an existing due date merely because extraction produced
no date.

Planner priority values are already resolved upstream:

- Urgent = `1`
- High = `3`
- Medium = `5`
- Low = `9`

Do not recalculate or downgrade priority.

## Managed Planner description

Carry the extracted information into the Planner task description using this
exact managed block:

```text
--- BEGIN ANDRITZ TASK INTAKE ---
DemoMarker: ANDRITZ-TASK-INTAKE-DEMO
CandidateId: {candidate.candidateId}
RequestedOutcome: {candidate.description}
Category: {classification.category}
Priority: {classification.priority}
ProjectCode: {candidate.inferredProject.code or blank}
ProjectName: {candidate.inferredProject.name or blank}
DueDate: {candidate.inferredDueDate.value or blank}
DueDateTimeZone: {candidate.inferredDueDate.timeZone or blank}
SourceChannel: {candidate.source.channel}
SourceSender: {candidate.source.sender}
SourceReceivedDateTime: {candidate.source.receivedDateTime}
SourceItemId: {candidate.source.itemId or blank}
SourceInternetMessageId: {candidate.source.internetMessageId or blank}
SourceConversationId: {candidate.source.conversationId or blank}
SourceSubject: {candidate.source.subject or blank}
SourceReferenceType: {candidate.source.referenceType}
SourceReference: {candidate.source.reference}
SourceEvidence: {candidate.source.evidence}
--- END ANDRITZ TASK INTAKE ---
```

Preserve line breaks in `RequestedOutcome` and `SourceEvidence`. Do not put
fabricated text such as `unknown` in blank fields.

For Create, use the managed block as the task description.

For Update:

1. Retrieve current task details.
2. If the description contains an existing managed block, replace that block
   and preserve all text outside it.
3. Otherwise append one blank line and the managed block to the existing
   description.
4. Submit the merged description using the current ETag when one is exposed.
   Otherwise let the Planner connector manage concurrency.

Planner task descriptions have a service limit. If the complete merged
description exceeds the connector limit, fail that item explicitly. Do not
silently truncate source data or existing user-authored text.

## Create workflow

For a `create` entry:

1. Resolve the bucket.
2. Create the task with plan ID, bucket ID, title, priority, percent complete
   `0`, and the inferred due date when present.
3. Retrieve the newly created task and task details when required by the
   connector's details-update action.
4. Update task details with the managed description.
5. Return the created task ID, bucket ID, bucket name, and source reference.

Do not report `created` until both the task and managed description are
written. If task creation succeeds but the details update fails, return
`failed` with the created task ID and state that manual cleanup may be needed.

## Update workflow

For an `update` entry:

1. Retrieve `selectedPlannerTaskId` and confirm its `planId` equals the target
   plan ID. Stop if it belongs to another plan.
2. Retrieve its current task and details data.
3. Resolve the requested bucket.
4. Patch only:
   - title;
   - bucket ID;
   - priority;
   - due date/time when the candidate has one.
5. Merge and update the managed description. Supply the current details ETag
   when exposed; otherwise use connector-managed concurrency.
6. Return the updated task ID, bucket ID, bucket name, and source reference.

For this demo:

- Do not perform a separate pre-write concurrency check.
- If an operation explicitly requires an `If-Match` value and no ETag is
  exposed, use `*` only for the already approved target task.
- If the connector reports a conflict, retrieve fresh task/details data,
  rebuild the intended patches once, and retry once.
- If the retry fails, return `failed` with the connector error.
- This relaxed behavior applies only to Demo Todos and must not be generalized
  to production plans.

## Processing and failure behavior

Process tasks in input order.

- Return `skipped` for Ignore without calling Planner for that entry.
- Return `created` only after the create workflow completes.
- Return `updated` only after the update workflow completes.
- Return `failed` with the connector operation and error for a failed entry.
- Stop processing subsequent entries after the first failed mutation because
  Planner writes are not transactional.
- Never claim rollback. Include IDs for resources created before a failure.
- Include all prior successful and skipped results in the final output.

## Output contract

Return exactly one JSON object that validates against
`references/task-creation-planner-output.schema.json`.

- Don't wrap the JSON in a Markdown code fence.
- Don't add commentary before or after the JSON.
- Use `schemaVersion` value `1.1`.
- Preserve input order for processed entries.
- Set summary counts from actual connector outcomes.
- Set `completed` to `true` only when no result is `failed` and every input has
  a corresponding result.
- Include created buckets once in `createdBuckets`.
- Include connector warnings in `warnings`; don't hide them.

## Additional resources

- `references/task-creation-planner-output.schema.json` - strict execution
  result contract.
