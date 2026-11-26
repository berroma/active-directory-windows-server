# Infrastructure Windows Server : Active Directory, GPO, partage de fichiers et DHCP

Projets réalisés dans le cadre du **BTS SIO option SISR** (ITIC Paris), en laboratoire virtualisé.

## 🎯 Objectif

Mettre en place l'infrastructure Windows d'une entreprise fictive, **Sam Tech**, organisée en trois sites (Londres, Berlin, Paris) et six secteurs (Accounting, Direction, Sales, Traders, Secretary, Finance-Consultant) :
- centraliser les comptes dans un domaine **Active Directory** ;
- donner à chaque secteur l'accès à ses seuls dossiers partagés ;
- appliquer automatiquement des règles de sécurité avec des **GPO** ;
- distribuer automatiquement les adresses IP avec un serveur **DHCP**.

## 🧰 Environnement

| Élément | Détail |
|---|---|
| Serveur | Windows Server 2019 Standard, virtualisé sous VMware |
| Rôles | AD DS (contrôleur de domaine), DNS, DHCP, serveur de fichiers |
| Domaine | `iticsio.fr` |
| Postes clients | Windows 10 joints au domaine |
| Passerelle | pfSense |

## 📋 Réalisations

### 1. Annuaire Active Directory
- Création d'une OU `Employés`, avec une sous-OU par site : **Londres, Berlin, Paris**.
- Un **groupe de sécurité par secteur et par site** (ex. : `AccountingBerlin`, `SalesParis`, `DirectionLondres`).
- Création des utilisateurs et ajout à leurs groupes **avec un script PowerShell**, au lieu de les créer un par un.
- Jonction des postes Windows 10 au domaine et vérification de la résolution DNS (`ping iticsio.fr`).

### 2. Partage de fichiers et droits d'accès
- Arborescence `Employe\<Site>\<Secteur>` sur le serveur, partagée en chemin UNC.
- **Droits de partage et droits NTFS** attribués par groupe de sécurité : chaque secteur n'accède qu'à ses dossiers.
- **Héritage désactivé** sur les sous-dossiers pour contrôler précisément les accès.
- Tests de connexion avec des comptes de chaque secteur : accès autorisés et refusés vérifiés.

### 3. Stratégies de groupe (GPO)
| GPO | Rôle |
|---|---|
| Verrouillage automatique | Verrouille la session après **120 secondes** d'inactivité |
| Fond d'écran imposé | Papier peint d'entreprise déployé depuis un partage réseau, non modifiable par l'utilisateur |
| Administrateur local ciblé | Via les **groupes restreints**, un groupe de sécurité AD devient administrateur local d'un poste précis, sans aucun droit sur le domaine ni les serveurs |

Vérification sur les postes avec `gpupdate /force`, puis contrôle des membres du groupe Administrateurs local.

### 4. Serveur DHCP
- Installation du rôle DHCP et création d'une étendue `10.75.20.100` – `10.75.20.200` (/24), bail de 8 jours.
- Options distribuées : passerelle (pfSense) et serveur DNS.
- Vérification des baux attribués dans la console DHCP, et de la configuration reçue par les clients (`ipconfig`, `ping`).

## 📄 Rapports détaillés (avec captures d'écran)

| Rapport | Contenu |
|---|---|
| [Active Directory et partage de fichiers](rapports/active-directory-et-partage-de-fichiers.pdf) | OU par site, groupes par secteur, utilisateurs, partages et droits NTFS, tests |
| [GPO : administrateur local ciblé](rapports/gpo-administrateur-local.pdf) | Groupe de sécurité, groupes restreints, vérification sur le poste |
| [Épreuve E6 : AD et GPO](rapports/epreuve-e6-ad-gpo.pdf) | OU, groupes, jonction au domaine, GPO de verrouillage et de fond d'écran |
| [Serveur DHCP](rapports/serveur-dhcp.pdf) | Installation du rôle, étendue, bail, tests clients |
| [Dossier partagé et droits NTFS](rapports/dossier-partage-ntfs.pdf) | Partage, permissions NTFS, accès depuis un poste client |

## ⚙️ Script PowerShell : création d'utilisateurs en masse

Le script [`scripts/New-ADUsersFromCsv.ps1`](scripts/New-ADUsersFromCsv.ps1) automatise la création des comptes à partir d'un fichier CSV ([exemple](scripts/utilisateurs-exemple.csv)). Pour chaque ligne, il :
- génère l'identifiant `prenom.nom`, sans accents ;
- crée l'OU du service si elle n'existe pas ;
- crée le compte et oblige l'utilisateur à changer son mot de passe à la première connexion ;
- ajoute l'utilisateur au groupe de son service (`GG_<Service>`), créé si besoin.

```powershell
# Simulation, sans rien créer
.\New-ADUsersFromCsv.ps1 -CsvPath .\utilisateurs-exemple.csv -WhatIf

# Création réelle (le mot de passe initial est demandé de façon masquée)
.\New-ADUsersFromCsv.ps1 -CsvPath .\utilisateurs-exemple.csv
```

## 🧠 Ce que j'ai appris

- Le rôle central du **DNS** dans un domaine Active Directory : sans lui, les postes ne trouvent pas le contrôleur de domaine.
- Gérer les droits **par groupe** plutôt que par utilisateur, et combiner droits de partage et droits NTFS.
- Donner des droits d'administration **au plus juste**, sur un seul poste, sans exposer le domaine.
- Automatiser les tâches répétitives avec **PowerShell**.

## 🛠️ Compétences mobilisées

`Windows Server 2019` · `Active Directory` · `GPO` · `DNS` · `DHCP` · `NTFS` · `PowerShell` · `VMware` · `pfSense`
