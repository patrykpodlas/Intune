# Intune

## Backup Intune

All of the functions are GET only, they do not change anything, they're used to get or export Intune Configurations to a Git repository.

1. Import the IntuneBackup module.
2. Use Backup-Intune.ps1 to backup your Intune to a Git repository, this was only tested with Azure Repos. You can use a managed identity inside Azure Automation to perform this task, how to set-up permissions is not included.

IMPORTANT: inside Get-AzureDevOpsRepoLatestCommit, for now you must edit the URI on line 43 accordingly.