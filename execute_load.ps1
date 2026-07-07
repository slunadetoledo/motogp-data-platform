param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtractorArgs
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RootDir

$RawJsonDir = Join-Path $RootDir "data/raw/motogp"
$ArchiveDir = Join-Path $RawJsonDir "archive"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ArchiveFile = Join-Path $ArchiveDir "motogp_raw_json_$Timestamp.zip"

function Invoke-Docker {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$DockerArgs
    )

    & docker @DockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "El comando fallo: docker $($DockerArgs -join ' ')"
    }
}

function Invoke-Compose {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ComposeArgs
    )

    if ($script:UseDockerComposePlugin) {
        & docker compose @ComposeArgs
        $CommandName = "docker compose"
    } else {
        & docker-compose @ComposeArgs
        $CommandName = "docker-compose"
    }

    if ($LASTEXITCODE -ne 0) {
        throw "El comando fallo: $CommandName $($ComposeArgs -join ' ')"
    }
}

function Get-ComposeContainerIds {
    if ($script:UseDockerComposePlugin) {
        $ContainerIds = @(& docker compose ps --all --quiet)
        $CommandName = "docker compose ps --all --quiet"
    } else {
        $ContainerIds = @(& docker-compose ps --all --quiet)
        $CommandName = "docker-compose ps --all --quiet"
    }

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo ejecutar $CommandName"
    }

    return @($ContainerIds | Where-Object { $_ })
}

$DockerComposePlugin = Get-Command docker -ErrorAction SilentlyContinue
$DockerComposeStandalone = Get-Command docker-compose -ErrorAction SilentlyContinue
$HasDockerComposePlugin = $false

if ($DockerComposePlugin) {
    & docker compose version *> $null
    $HasDockerComposePlugin = $LASTEXITCODE -eq 0
}

if ($HasDockerComposePlugin) {
    $script:UseDockerComposePlugin = $true
} elseif ($DockerComposeStandalone) {
    & docker-compose version *> $null
    if ($LASTEXITCODE -eq 0) {
        $script:UseDockerComposePlugin = $false
    } else {
        Write-Error "No se encontro Docker Compose. Instala el plugin 'docker compose' o el binario 'docker-compose'."
        exit 1
    }
} else {
    Write-Error "No se encontro Docker Compose. Instala el plugin 'docker compose' o el binario 'docker-compose'."
    exit 1
}

if (-not (Test-Path ".env" -PathType Leaf)) {
    if (Test-Path ".env.example" -PathType Leaf) {
        Copy-Item ".env.example" ".env"
        Write-Host "Creado .env desde .env.example"
    } else {
        Write-Error "No existe .env ni .env.example. Crea .env antes de continuar."
        exit 1
    }
}

$ExistingContainers = Get-ComposeContainerIds
if ($ExistingContainers.Count -gt 0) {
    Write-Host "Destruyendo contenedores existentes..."
    try {
        Invoke-Compose down --remove-orphans
    } catch {
        Write-Host "docker compose down fallo. Forzando eliminacion de contenedores..."
        $RemainingContainers = Get-ComposeContainerIds
        if ($RemainingContainers.Count -gt 0) {
            Invoke-Docker rm -f @RemainingContainers
        }
    }
}

Write-Host "Levantando contenedores..."
Invoke-Compose up -d --build

Write-Host "Esperando a PostgreSQL..."
$MaxWait = 30
$Elapsed = 0
while ($true) {
    if ($script:UseDockerComposePlugin) {
        & docker compose exec -T postgres pg_isready -U motogp_user -d motogp *> $null
    } else {
        & docker-compose exec -T postgres pg_isready -U motogp_user -d motogp *> $null
    }
    if ($LASTEXITCODE -eq 0) {
        break
    }

    if ($Elapsed -ge $MaxWait) {
        Write-Error "PostgreSQL no estuvo listo en $MaxWait segundos. Abortando."
        exit 1
    }

    Start-Sleep -Seconds 2
    $Elapsed += 2
}

Write-Host "Ejecutando ingesta MotoGP..."
Invoke-Compose exec -T app python src/extract_motogp.py @ExtractorArgs

if (Test-Path $RawJsonDir -PathType Container) {
    $ArchiveRoot = [System.IO.Path]::GetFullPath($ArchiveDir).TrimEnd("\", "/")
    $RawJsonFiles = @(
        Get-ChildItem -Path $RawJsonDir -Recurse -File -Filter "*.json" |
            Where-Object {
                -not [System.IO.Path]::GetFullPath($_.FullName).StartsWith(
                    $ArchiveRoot,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
    )
} else {
    $RawJsonFiles = @()
}

if ($RawJsonFiles.Count -gt 0) {
    Write-Host "Archivando JSON crudos en $ArchiveFile..."
    New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null
    Compress-Archive -Path $RawJsonFiles.FullName -DestinationPath $ArchiveFile -Force
    Remove-Item -Path $RawJsonFiles.FullName -Force
} else {
    Write-Host "No hay JSON crudos para archivar en $RawJsonDir."
}

Write-Host "Ejecutando dbt run..."
Invoke-Compose exec -T app dbt run --profiles-dir .

Write-Host "Carga completa finalizada."
