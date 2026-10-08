# ANDRITZ Task Alerting Agent Demo

Demo project for collecting task requests from Outlook email and Microsoft
Teams, deduplicating and prioritizing them, and creating tasks in Microsoft
Planner through Microsoft Copilot Cowork.

## Contents

- `cowork-plugin/` - Microsoft Copilot Cowork plugin with the complete workflow
  and four standalone processing skills.
- `dist/` - Installable Cowork plugin package.
- `scripts/Reset-DemoPlanner.ps1` - Preview-first Planner cleanup script.
- `DEMO-GUIDE.md` - Setup, seeded scenarios, walkthrough, and expected results.
- `agent.mcs.yml` - Copilot Studio agent export used by the broader demo.

## Cowork workflow

The bundled workflow runs these stages in order:

1. Aggregate actionable requests from the previous seven days.
2. Check the target Planner plan for duplicates.
3. Categorize and prioritize approved candidates.
4. Preview and create or update Planner tasks after explicit approval.

Use this prompt in Microsoft Copilot Cowork:

> Run the complete ANDRITZ task-intake workflow for requests from the last seven days.

See [DEMO-GUIDE.md](./DEMO-GUIDE.md) for prerequisites and the complete demo
procedure.

## Cleanup

Preview cleanup without changing Planner:

```powershell
.\scripts\Reset-DemoPlanner.ps1
```

After reviewing the preview, execute cleanup:

```powershell
.\scripts\Reset-DemoPlanner.ps1 -Execute
```

The script targets only tasks carrying the demo marker or matching the seeded
demo data.
