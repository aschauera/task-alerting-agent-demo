# ANDRITZ Hydropower Task Intake Demo Guide

## Demo objective

Demonstrate two implementations of the same ANDRITZ Hydropower task-intake scenario, using the same seeded email and Teams data:

1. Collect task requests from Outlook and Microsoft Teams.
2. Normalize requests into a common task format.
3. Infer due dates from natural-language text.
4. Apply predefined categorization rules.
5. Associate requests with a project when a project reference is present.
6. Create a new Planner task or update a matching existing task.

## Demo flows

### Flow 1: Microsoft Cowork

The current demo uses Microsoft Cowork and Power Platform connectors to collect and process requests interactively. This flow is documented and ready to prepare.

Cowork skill implementation status:

| Skill | Status | Purpose |
|---|---|---|
| Task Aggregation | Implemented | Uses Work IQ to extract actionable requests from incoming email and Teams messages from the last seven days. |
| Task Deduplication | Implemented | Compares candidates with Demo Todos, calculates an explainable likeness score, and captures Ignore or Update decisions. |
| Task Categorization and Prioritization | Implemented | Assigns one category and priority, routing project work to per-project buckets and other work to category buckets. |
| Task Creation in Planner | Implemented | Resolves or creates project/category buckets, then creates or updates Planner tasks with normalized source, project, due-date, category, and priority data. |
| Task Intake Workflow | Implemented | Coordinates all four processing skills in order, enforces handoff validation and duplicate decisions, and requires final approval before Planner mutation. |

The four standalone processing skills and the orchestration skill are bundled
as the **ANDRITZ Task Intake**
Cowork plugin in `cowork-plugin/`. Its Microsoft 365 app manifest is
`cowork-plugin/manifest.json`, and the distributable archive is
`dist/andritz-task-intake-cowork-plugin.zip`.

### Flow 2: Copilot Studio M365 Agent Workflow

This flow is not yet built. It will implement the same collection, normalization, categorization, project assignment, and Planner create-or-update behavior as a trigger-based M365 Agent Workflow.

Use the existing Copilot Studio assets:

| Asset | Value |
|---|---|
| Environment | DemoPRE |
| Solution | Task Alerting Agent Demo |
| Agent | Task Alerting Agent |

Both flows must use the same seeded demo data, normalized task format, categorization rules, project-assignment rules, and success criteria in this guide.

## Demo identities

| Role | Account |
|---|---|
| Request sender | `office@M365x04582162.onmicrosoft.com` |
| Task recipient | `admin@M365x04582162.onmicrosoft.com` |

## Demo projects

| Project code | Project name |
|---|---|
| `HP-KAR-2042` | Karuma II Rehabilitation Program |
| `HP-AMU2-2026` | Alto Maipo Unit 2 Modernization |

Requests without a project code should remain unassigned or be placed in a general operations plan.

## Seeded demo data

All dates are in 2026.

| ID | Channel | Project | Request title | Requested outcome | Due date | Suggested category |
|---|---|---|---|---|---|---|
| E-01 | Email | Unassigned | Kaprun Unit 3 site-readiness review | Consolidate crane access, penstock inspection sign-off, control-room network readiness, and commissioning blockers. | Fri, 9 Oct, close of business | Commissioning |
| E-02 | Email | Unassigned | Missing supplier certificates for Nam Theun runner | Obtain material certificates and the final dimensional inspection report, then update Procurement. | Tue, 13 Oct, before supplier review | Procurement / Documentation |
| E-03 | Email | Unassigned | Revise Rio Madeira generator outage plan | Update the rotor-lift sequence, specialist availability, isolation window, and schedule risks. | Fri, 16 Oct, 12:00 PM | Project Planning |
| T-01 | Teams | Unassigned | Kaprun Unit 3 actuator calibration | Verify calibration results and record deviations in the engineering issue log. | Thu, 8 Oct, 3:00 PM | Engineering / Quality |
| T-02 | Teams | Unassigned | Itaipu permit-to-work actions | Close three open safety actions, update the tracker, and assign responsible supervisors. | Mon, 12 Oct, 10:00 AM | HSE |
| T-03 | Teams | Unassigned | Xayaburi spare-parts summary | Prepare customer-facing stock status, lead times, and critical-spares recommendations. | Wed, 14 Oct, end of day | Service / Procurement |
| E-04 | Email | `HP-KAR-2042` | Karuma II runner inspection follow-up | Review Unit 4 runner-blade ultrasonic findings and publish the signed engineering disposition. | Mon, 19 Oct, 11:00 AM | Engineering / Quality |
| T-04 | Teams | `HP-KAR-2042` | Karuma II shaft-seal ring delivery | Confirm delivery status, site-arrival forecast, and logistics blockers. | Mon, 12 Oct, 4:00 PM | Procurement / Logistics |
| T-05 | Teams | `HP-KAR-2042` | Karuma II Unit 4 heavy-lift plan | Finalize the crane load chart, exclusion zone, lifting supervisor, and permit owner. | Wed, 14 Oct, 12:00 PM | Site Execution / HSE |
| E-05 | Email | `HP-AMU2-2026` | Alto Maipo Unit 2 SCADA I/O matrix | Reconcile signal tags, missing alarm points, and approved protection and control drawings. | Thu, 15 Oct, close of business | Automation / Engineering |
| E-06 | Email | `HP-AMU2-2026` | Alto Maipo customer acceptance package | Complete and index test certificates, approved deviations, training records, and final parameters. | Tue, 20 Oct, 2:00 PM | Quality / Documentation |
| T-06 | Teams | `HP-AMU2-2026` | Alto Maipo commissioning outage sequence | Align the outage sequence with the grid operator and contractor, then update the integrated schedule. | Tue, 13 Oct, 10:00 AM | Project Controls / Scheduling |

## Suggested normalized task format

Cowork should normalize every request into the following structure before calling Planner:

| Field | Expected value |
|---|---|
| `Title` | Concise action-oriented title |
| `Description` | Full requested outcome and relevant source context |
| `DueDate` | Inferred date and time in ISO 8601 format |
| `Category` | Category produced by the predefined rules |
| `ProjectCode` | Explicit project code, or blank when none is present |
| `ProjectName` | Project resolved from the project code |
| `SourceChannel` | `Email` or `Teams` |
| `SourceSender` | `office@M365x04582162.onmicrosoft.com` |
| `SourceRecipient` | `admin@M365x04582162.onmicrosoft.com` |
| `SourceReference` | Link or identifier for the original email or Teams message |
| `DemoMarker` | `ANDRITZ-TASK-INTAKE-DEMO` |
| `Status` | `Not started` for a newly created Planner task |

Source references use the first value Work IQ makes available:

1. Source item ID
2. Internet Message ID
3. Source URL
4. Deterministic reference built from channel, sender, received timestamp, and
   normalized subject or conversation ID

The internal source item ID may be blank. The normalized `SourceReference` and
its reference type are mandatory and pass unchanged through every skill.

## Suggested categorization rules

Apply the first matching rule:

| Keywords or intent | Category |
|---|---|
| permit, safety, HSE, exclusion zone | HSE |
| supplier, delivery, certificate, material, spare parts, logistics | Procurement / Logistics |
| calibration, inspection, engineering disposition, I/O matrix | Engineering / Quality |
| commissioning, site readiness, energization | Commissioning |
| outage plan, integrated schedule, switching window | Project Controls / Scheduling |
| acceptance package, test certificate, approval record | Quality / Documentation |

## Project-assignment rules

1. Search the subject and body for a project code.
2. If `HP-KAR-2042` is present, assign the task to **Karuma II Rehabilitation Program**.
3. If `HP-AMU2-2026` is present, assign the task to **Alto Maipo Unit 2 Modernization**.
4. If no project code is present, leave the project blank or use the general operations plan.
5. Do not infer a project solely from a plant name when no explicit project code is present.

## Suggested create-or-update logic

Before creating a Planner task, search for an existing task with:

- the same project code,
- a substantially similar title, and
- the same source request or source reference.

If a match exists, update its description, due date, category, and source metadata. Otherwise, create a new task.

Every created or updated demo task must include these lines in its Planner description:

```text
DemoMarker: ANDRITZ-TASK-INTAKE-DEMO
SourceSender: office@M365x04582162.onmicrosoft.com
```

The Task Creation in Planner skill writes these values in a managed description
block so repeated updates replace the skill-owned metadata without overwriting
unrelated user-authored task details. New tasks start at zero percent complete.
Updates preserve completion, assignments, checklists, references, and existing
due dates when no new due date was inferred.

Before Planner mutation, Cowork presents a review grouped by destination
bucket. Each task appears on its own numbered line with action, title, due date,
category, and priority. Cowork does not use Markdown tables for this approval
screen because some clients render table markup as raw pipe-delimited text.

For this demo plan only, Planner actions may use connector-managed concurrency
when the connector does not expose ETags. If an operation requires an
`If-Match` value without exposing an ETag, the skill may use `*` for the
explicitly approved target task. Production implementations should use strict
ETag checks.

## Resetting the Planner demo

The cleanup script targets the group-owned Planner plan **Demo Todos**, plan ID
`DDjY51B1q0yenINc9Whg6mUAHVGH`, in Microsoft 365 group **ANDRITZ Task Intake
Demo**, group ID `5c528c8f-bae5-48c7-81ba-ca4d5182c7a3`. It uses Microsoft
Graph with an explicit device-code sign-in for
`admin@M365x04582162.onmicrosoft.com`.

Preview the tasks that match the demo marker, source metadata, project codes, or seeded titles:

```powershell
.\scripts\Reset-DemoPlanner.ps1
```

Delete the matched tasks after reviewing the preview:

```powershell
.\scripts\Reset-DemoPlanner.ps1 -Execute
```

To run non-interactively after reviewing the preview:

```powershell
.\scripts\Reset-DemoPlanner.ps1 -Execute -Confirm:$false
```

The script never deletes unrelated tasks from the plan.

## Flow 1: Cowork demo walkthrough

Start the orchestration skill with this prompt:

> Run the complete ANDRITZ task-intake workflow for requests from the last seven days.

1. Enter the suggested prompt in Cowork.
2. Have Cowork extract only messages that contain a concrete action and an inferable due date.
3. Review the normalized requests before writing to Planner.
4. Confirm that project codes map to the correct projects.
5. Confirm that requests without codes remain unassigned.
6. Let Cowork create or update the corresponding Planner tasks.
7. Compare the resulting tasks with the seeded-data table above.

## Flow 2: Copilot Studio workflow target

Build the trigger-based M365 Agent Workflow in the existing **Task Alerting Agent** within the **Task Alerting Agent Demo** solution in the **DemoPRE** environment.

The workflow should:

1. Trigger when a relevant email or direct Teams message is received.
2. Reject messages that do not contain a concrete task request or inferable due date.
3. Normalize accepted requests into the common task format.
4. Apply the same categorization and project-assignment rules as the Cowork flow.
5. Search Planner for a matching task.
6. Update the matching task or create a new task.
7. Preserve a reference to the source email or Teams message.

## Success criteria

- Both demo flows produce equivalent Planner task data from the same source requests.
- All 12 requests are detected.
- Email and Teams requests use the same normalized structure.
- Every due date is inferred correctly.
- The six project-linked requests are assigned to the correct project.
- The six requests without project codes remain unassigned.
- Categories follow the predefined rules.
- Re-running the process updates matching tasks instead of creating duplicates.
