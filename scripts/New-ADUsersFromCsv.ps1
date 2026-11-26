<#
.SYNOPSIS
    Crée des utilisateurs Active Directory à partir d'un fichier CSV.

.DESCRIPTION
    Pour chaque ligne du CSV (colonnes Prenom;Nom;Service), le script :
      - génère l'identifiant prenom.nom, sans accents ni espaces ;
      - crée l'OU du service sous l'OU de base si elle n'existe pas ;
      - crée le groupe de sécurité GG_<Service> s'il n'existe pas ;
      - crée le compte, activé, avec changement de mot de passe obligatoire à la première connexion ;
      - ajoute l'utilisateur au groupe de son service.
    Les comptes qui existent déjà sont ignorés.

.PARAMETER CsvPath
    Chemin du fichier CSV, séparé par des points-virgules.

.PARAMETER BaseOU
    Nom de l'OU racine sous laquelle les OU de service sont créées. Par défaut : Entreprise.

.EXAMPLE
    .\New-ADUsersFromCsv.ps1 -CsvPath .\utilisateurs-exemple.csv -WhatIf
    Simule la création sans rien modifier.

.EXAMPLE
    .\New-ADUsersFromCsv.ps1 -CsvPath .\utilisateurs-exemple.csv
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [string]$BaseOU = 'Entreprise'
)

Import-Module ActiveDirectory -ErrorAction Stop

function Remove-Accents([string]$Text) {
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $normalized.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
    }
    return $sb.ToString()
}

function Get-CleanName([string]$Text) {
    return ((Remove-Accents $Text).ToLower() -replace '[^a-z0-9-]', '')
}

$domain = Get-ADDomain
$baseDN = "OU=$BaseOU,$($domain.DistinguishedName)"

if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$BaseOU'" -SearchBase $domain.DistinguishedName -SearchScope OneLevel)) {
    if ($PSCmdlet.ShouldProcess($baseDN, 'Créer l''OU de base')) {
        New-ADOrganizationalUnit -Name $BaseOU -Path $domain.DistinguishedName
    }
}

$password = Read-Host -AsSecureString 'Mot de passe initial des nouveaux comptes'
$users = Import-Csv -Path $CsvPath -Delimiter ';' -Encoding UTF8
$created = 0

foreach ($u in $users) {
    $login = '{0}.{1}' -f (Get-CleanName $u.Prenom), (Get-CleanName $u.Nom)
    $serviceDN = "OU=$($u.Service),$baseDN"
    $group = 'GG_' + ((Remove-Accents $u.Service) -replace '[^A-Za-z0-9]', '')

    if (Get-ADUser -Filter "SamAccountName -eq '$login'") {
        Write-Warning "$login existe déjà : ignoré."
        continue
    }

    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$($u.Service)'" -SearchBase $baseDN -SearchScope OneLevel)) {
        if ($PSCmdlet.ShouldProcess($serviceDN, 'Créer l''OU du service')) {
            New-ADOrganizationalUnit -Name $u.Service -Path $baseDN
        }
    }

    if (-not (Get-ADGroup -Filter "Name -eq '$group'")) {
        if ($PSCmdlet.ShouldProcess($group, 'Créer le groupe de sécurité')) {
            New-ADGroup -Name $group -GroupScope Global -GroupCategory Security -Path $serviceDN
        }
    }

    if ($PSCmdlet.ShouldProcess($login, 'Créer l''utilisateur')) {
        New-ADUser -Name "$($u.Prenom) $($u.Nom)" `
            -GivenName $u.Prenom -Surname $u.Nom `
            -SamAccountName $login `
            -UserPrincipalName "$login@$($domain.DNSRoot)" `
            -Department $u.Service `
            -Path $serviceDN `
            -AccountPassword $password `
            -ChangePasswordAtLogon $true `
            -Enabled $true
        Add-ADGroupMember -Identity $group -Members $login
        Write-Host "Créé : $login ($($u.Service))" -ForegroundColor Green
        $created++
    }
}

Write-Host "$created compte(s) créé(s)."
