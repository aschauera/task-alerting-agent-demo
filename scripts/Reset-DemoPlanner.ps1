[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [string]$TenantId = 'bfc167e5-797b-4253-af74-4a32b0533996',

    [Parameter()]
    [string]$PlanId = 'DDjY51B1q0yenINc9Whg6mUAHVGH',

    [Parameter()]
    [string]$ExpectedUserPrincipalName = 'admin@M365x04582162.onmicrosoft.com',

    [Parameter()]
    [string]$DemoMarker = 'ANDRITZ-TASK-INTAKE-DEMO',

    [Parameter()]
    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$demoProjectCodes = @(
    'HP-KAR-2042',
    'HP-AMU2-2026'
)

$demoTitles = @(
    'Kaprun Unit 3 site-readiness review',
    'Missing supplier certificates for Nam Theun runner',
    'Revise Rio Madeira generator outage plan',
    'Kaprun Unit 3 actuator calibration',
    'Itaipu permit-to-work actions',
    'Xayaburi spare-parts summary',
    'Karuma II runner inspection follow-up',
    'Karuma II shaft-seal ring delivery',
    'Karuma II Unit 4 heavy-lift plan',
    'Alto Maipo Unit 2 SCADA I/O matrix',
    'Alto Maipo customer acceptance package',
    'Alto Maipo commissioning outage sequence'
)

$demoSourceSender = 'office@M365x04582162.onmicrosoft.com'

function Get-GraphCollection {
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $items = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    while ($nextLink) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink

        foreach ($item in $response.value) {
            $items.Add($item)
        }

        $nextLinkProperty = $response.PSObject.Properties['@odata.nextLink']
        $nextLink = if ($nextLinkProperty) { $nextLinkProperty.Value } else { $null }
    }

    return $items
}

function Get-DemoMatchReasons {
    param(
        [Parameter(Mandatory)]
        [object]$Task,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Description
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $title = [string]$Task.title
    $content = "$title`n$Description"

    if ($content -match [regex]::Escape($DemoMarker)) {
        $reasons.Add("marker:$DemoMarker")
    }

    if ($Description -match "(?im)^\s*SourceSender\s*:\s*$([regex]::Escape($demoSourceSender))\s*$") {
        $reasons.Add("source:$demoSourceSender")
    }

    foreach ($projectCode in $demoProjectCodes) {
        if ($content -match [regex]::Escape($projectCode)) {
            $reasons.Add("project:$projectCode")
        }
    }

    if ($demoTitles -contains $title) {
        $reasons.Add('seeded-title')
    }

    return $reasons
}

$module = Get-Module -ListAvailable Microsoft.Graph.Authentication |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $module) {
    throw 'Microsoft.Graph.Authentication is required. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
}

Import-Module Microsoft.Graph.Authentication -MinimumVersion $module.Version

$encodedPlanId = [uri]::EscapeDataString($PlanId)
$matchedTasks = [System.Collections.Generic.List[object]]::new()

try {
    Connect-MgGraph `
        -TenantId $TenantId `
        -Scopes 'Tasks.ReadWrite' `
        -ContextScope CurrentUser `
        -NoWelcome

    $context = Get-MgContext

    if (-not $context) {
        throw 'Microsoft Graph did not return an authenticated context.'
    }

    if ($context.TenantId -ne $TenantId) {
        throw "Authenticated tenant '$($context.TenantId)' does not match required tenant '$TenantId'."
    }

    if ($context.Account -ne $ExpectedUserPrincipalName) {
        throw "Authenticated account '$($context.Account)' does not match required account '$ExpectedUserPrincipalName'."
    }

    Write-Host "Connected as $($context.Account) in tenant $($context.TenantId)."
    Write-Host "Scanning Planner plan $PlanId for demo tasks..."

    $tasks = Get-GraphCollection -Uri "https://graph.microsoft.com/v1.0/planner/plans/$encodedPlanId/tasks"

    foreach ($task in $tasks) {
        $encodedTaskId = [uri]::EscapeDataString([string]$task.id)
        $details = Invoke-MgGraphRequest `
            -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/planner/tasks/$encodedTaskId/details"
        $description = [string]$details.description
        $reasons = @(Get-DemoMatchReasons -Task $task -Description $description)

        if ($reasons.Count -eq 0) {
            continue
        }

        $matchedTasks.Add([pscustomobject]@{
            Id = [string]$task.id
            Title = [string]$task.title
            DueDateTime = $task.dueDateTime
            MatchReasons = $reasons -join ', '
        })
    }

    if ($matchedTasks.Count -eq 0) {
        Write-Host 'No matching demo tasks were found. No changes were made.'
        return
    }

    $matchedTasks |
        Sort-Object Title |
        Format-Table Title, DueDateTime, MatchReasons, Id -AutoSize

    if (-not $Execute) {
        Write-Host ''
        Write-Host "Preview only: $($matchedTasks.Count) demo task(s) would be deleted."
        Write-Host 'Run again with -Execute to delete them.'
        return
    }

    $deletedCount = 0

    foreach ($task in $matchedTasks) {
        if (-not $PSCmdlet.ShouldProcess($task.Title, "Delete Planner task from plan $PlanId")) {
            continue
        }

        $encodedTaskId = [uri]::EscapeDataString($task.Id)
        $currentTask = Invoke-MgGraphRequest `
            -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/planner/tasks/$encodedTaskId"
        $etag = [string]$currentTask.'@odata.etag'

        if (-not $etag) {
            throw "Planner task '$($task.Id)' did not return an ETag and cannot be deleted safely."
        }

        Invoke-MgGraphRequest `
            -Method DELETE `
            -Uri "https://graph.microsoft.com/v1.0/planner/tasks/$encodedTaskId" `
            -Headers @{ 'If-Match' = $etag }

        $deletedCount++
        Write-Host "Deleted: $($task.Title)"
    }

    Write-Host "Cleanup complete. Deleted $deletedCount of $($matchedTasks.Count) matched demo task(s)."
}
finally {
    # Keep the CurrentUser Graph context cached so later runs can reuse authentication.
}
