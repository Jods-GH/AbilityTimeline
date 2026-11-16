param(
    # Spec files to run instead of the whole suite (skips the coverage gate), e.g. -Spec spec/manager_spec.lua
    [string[]]$Spec = @(),
    # Reuse the dependencies of the last run instead of fetching the latest
    [switch]$NoFetch
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$image = 'abilitytimeline-validation:local'
$deps = 'abilitytimeline-deps'

docker build --quiet --tag $image (Join-Path $PSScriptRoot '.') | Out-Null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $NoFetch) {
    docker volume create $deps | Out-Null
    docker run --rm --mount "type=bind,source=$repoRoot,target=/addon,readonly" --mount "type=volume,source=$deps,target=/deps" $image fetch
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

docker run --rm --network none --read-only --tmpfs /tmp --mount "type=bind,source=$repoRoot,target=/addon,readonly" --mount "type=volume,source=$deps,target=/deps,readonly" $image test @Spec
exit $LASTEXITCODE
