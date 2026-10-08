# Connector requirements

The plugin expects Microsoft 365 data and Planner actions to be available in
Cowork. Connector names can vary by tenant and client version, so the skills
describe required capabilities rather than binding to custom connector IDs.

## Work IQ

Task Aggregation requires Work IQ access to:

- search incoming Outlook email;
- search direct Teams messages;
- retrieve source metadata, timestamps, senders, content, and source links;
- limit retrieval to the last seven days.

## Microsoft Planner

Task Deduplication requires:

- list tasks in a plan;
- retrieve task details.

Task Creation in Planner requires:

- list and create buckets;
- create and retrieve tasks;
- retrieve task details;
- update tasks and task details with current ETags.

The configured identity must have access to:

- Plan name: `Demo Todos`
- Plan ID: `DDjY51B1q0yenINc9Whg6mUAHVGH`
- Group name: `ANDRITZ Task Intake Demo`
- Group ID: `5c528c8f-bae5-48c7-81ba-ca4d5182c7a3`

Planner `ListTasks_V3` and `ListBuckets_V3` require both `groupId` and plan
`id`. Use the grounded values above. The connector supplies `connectionId`
automatically; do not include it as an operation input. Do not depend on the
Office 365 Groups discovery connector.

## Authentication

Connect with the intended demo identity and verify the tenant before running
the plugin. Do not rely on an existing cached profile.

For this demo, Planner writes are expected to run as:

`admin@M365x04582162.onmicrosoft.com`

Do not put access tokens, refresh tokens, client secrets, or exported connector
credentials in this plugin.
