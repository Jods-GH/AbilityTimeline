$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$image = 'abilitytimeline-validation:local'

docker build --tag $image (Join-Path $PSScriptRoot '.')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

docker run --rm --network none --read-only --tmpfs /tmp --mount "type=bind,source=$repoRoot,target=/addon,readonly" $image
exit $LASTEXITCODE
