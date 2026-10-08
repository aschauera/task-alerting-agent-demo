# ANDRITZ Task Intake

![ANDRITZ Task Intake plugin logo](assets/plugin-logo.png)

A Cowork plugin for the ANDRITZ Hydropower task-intake demo. It turns
actionable requests from recent Outlook email and Teams messages into
structured Microsoft Planner tasks.

## Plugin logo

The Microsoft 365 app package includes:

- `color.png`: a 192-by-192-pixel PNG with the mark inside the 120-by-120 safe
  area;
- `outline.png`: a 32-by-32-pixel PNG that uses only white and transparency.

Both use an original stylized letter A. The larger
`assets/plugin-logo.png` file is retained for documentation and other
promotional uses.

## Cowork description

The name, short description, and full catalog-style description shown by
Copilot Cowork are defined in `manifest.json`. The full description covers key
capabilities, requirements, limitations, support, and language behavior.

## Included skills

The plugin bundles five independently discoverable skills:

| Skill | Purpose |
|---|---|
| `task-aggregation` | Uses Work IQ to find actionable incoming email and Teams requests from the last seven days. |
| `task-deduplication` | Compares candidates with the Demo Todos plan and asks whether likely duplicates should be ignored or updated. |
| `task-categorization-prioritization` | Assigns category, priority, and project/category bucket routing. |
| `task-creation-planner` | Resolves or creates buckets and creates or updates Planner tasks. |
| `task-intake-workflow` | Coordinates the complete flow in order, enforces duplicate and validation gates, previews Planner changes, and requires final approval. |

The skills remain separate under `skills/` so they can be invoked, inspected,
or maintained independently. Their JSON Schemas remain beside each skill under
its `references/` directory.

## Recommended sequence

For the complete demo, invoke `task-intake-workflow`. It applies the other four
skills sequentially, pauses for duplicate decisions, previews proposed Planner
changes, and requires final approval before mutation.

The four component skills can still be run separately:

1. Run `task-aggregation`.
2. Pass its JSON output to `task-deduplication`.
3. Resolve every duplicate decision as Ignore or Update.
4. Pass the resolved JSON output to `task-categorization-prioritization`.
5. Review the classifications and pass its JSON output to
   `task-creation-planner`.

Each skill defines a strict JSON handoff contract for the next step.

The handoff contract uses a normalized source reference. Permanent item IDs are
preferred but aren't required when Work IQ exposes only an Internet Message ID,
source URL, or stable message metadata. A deterministic fallback keeps the
demo traceable without inventing an item ID.

## Requirements

- Microsoft 365 access for the signed-in demo user.
- Work IQ access to Outlook email and Teams messages.
- Microsoft Planner connector access with permission to read and write tasks
  and buckets.
- Access to the Demo Todos plan:
  `DDjY51B1q0yenINc9Whg6mUAHVGH`.
- Access to its owning Microsoft 365 group, ANDRITZ Task Intake Demo:
  `5c528c8f-bae5-48c7-81ba-ca4d5182c7a3`.

Review [CONNECTORS.md](CONNECTORS.md) before running the plugin.

## Installation

Install or upload the plugin from this directory, or use the packaged ZIP from
the repository's `dist/` directory. The Microsoft 365 app package contains
`manifest.json`, `color.png`, `outline.png`, and `skills/` at its root.

After installation, verify that Cowork discovers all five skills before
starting the demo.

## Safety

- Task creation is limited to the Demo Todos plan.
- Duplicate decisions require explicit user input.
- The final Planner approval review is grouped by bucket and presented as
  readable numbered task lines rather than a Markdown table.
- Ignored items never mutate Planner.
- Created demo tasks include the marker
  `ANDRITZ-TASK-INTAKE-DEMO`.
- The Planner creation skill stops after the first failed mutation and reports
  partial completion explicitly.
- Demo Todos uses connector-managed concurrency when Planner actions don't
  expose ETags. Production use should require strict concurrency controls.
