//
// Copyright (c) Microsoft Corporation.  All rights reserved.
//
// Version: 1.0.0.0
// Revision: 2025.10.31
//

using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using Windows.Foundation;
using Windows.Management.Update;

namespace SampleProvider;

internal static class UpdateHelper
{
    /// <summary>
    /// Converts a WindowsSoftwareUpdateResult to a string representation.
    /// </summary>
    public static string ToString(WindowsSoftwareUpdateResult result)
    {
        return $"Succeeded: {result.Succeeded}, CancelRequested: {result.CancelRequested}, ResultCode: {result.ResultCode}, ExtendedError: {result.ExtendedError}";
    }

    /// <summary>
    /// Gets the current executable filename.
    /// </summary>
    private static string GetCurrentModuleFileName()
    {
        // Use AppContext.BaseDirectory for single-file compatibility
        string? exePath = Environment.ProcessPath;
        if (string.IsNullOrEmpty(exePath))
        {
            return "SampleProvider.exe"; // Fallback
        }
        return Path.GetFileName(exePath);
    }

    /// <summary>
    /// Generates a hash-based update ID from package information.
    /// </summary>
    private static string GenerateUpdateId(string input)
    {
        using (var sha256 = SHA256.Create())
        {
            byte[] hashBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(input));

            // Convert to hex string (32 characters)
            StringBuilder hexString = new StringBuilder(32);
            for (int i = 0; i < Math.Min(16, hashBytes.Length); i++)
            {
                hexString.Append(hashBytes[i].ToString("X2"));
            }

            return hexString.ToString();
        }
    }

    /// <summary>
    /// Creates an executable deploy update object.
    /// </summary>
    public static WindowsSoftwareUpdate CreateExecutableDeployUpdate(string providerId, bool enableLogging, bool verboseMode)
    {
        // Set the package ID and version for this update type
        string packageId = "SampleApp.Deploy";
        string packageVersion = "1.2.3.4";

        // Create the command line parameter: packageId_packageVersion
        string packageIdVersion = $"{packageId}_{packageVersion}";

        // Generate updateId by hashing the packageId_packageVersion
        string updateId = GenerateUpdateId(packageIdVersion);

        string title = "Executable Deploy Update (1.2.3.4)";
        string description = "Executable Deploy Update Description";

        // Localization Info
        var localizationInfo = new List<WindowsSoftwareUpdateLocalizationInfo>
        {
            new WindowsSoftwareUpdateLocalizationInfo(
                3082, // es-ES
                "Executable Deploy Actualización 1234 Título (es-ES)",
                "Executable Deploy Actualización 1234 Descripción (es-ES)",
                new Uri($"http://contoso.com/es-ES/updateId={updateId}")
            ),
            new WindowsSoftwareUpdateLocalizationInfo(
                1036, // fr-FR
                "Executable Deploy Mise à jour 1234 Titre (fr-FR)",
                "Executable Deploy Mise à jour 1234 Description (fr-FR)",
                new Uri($"http://contoso.com/fr-FR/updateId={updateId}")
            )
        };

        // Create command strings for readability
        string deployCmd = $"deploy --providerId {providerId} --updateId {packageIdVersion}";
        string deployForceCloseCmd = $"{deployCmd} --forceClose";
        string restartCmd = $"restart --providerId {providerId} --updateId {packageIdVersion}";

        // Add --log flag to commands if logging is enabled
        if (enableLogging)
        {
            deployCmd += " --log";
            deployForceCloseCmd += " --log";
            restartCmd += " --log";
        }

        // Add --verbose flag to commands if verbose is enabled
        if (verboseMode)
        {
            deployCmd += " --verbose";
            deployForceCloseCmd += " --verbose";
            restartCmd += " --verbose";
        }

        // Get the current module filename
        string moduleFileName = GetCurrentModuleFileName();

        // Optional Actions Info (for deploy, we only need closeAndDeploy, closeAndRestart)
        var optionalActionsInfo = new WindowsSoftwareUpdateOptionalActionInfo(
            new WindowsSoftwareUpdateActionInfo(
                moduleFileName,
                deployForceCloseCmd,
                WindowsSoftwareUpdateActionType.Deploy),
            null, // No closeAndInstall for deploy-only updates
            new WindowsSoftwareUpdateActionInfo(
                moduleFileName,
                restartCmd,
                WindowsSoftwareUpdateActionType.AppRestart));

        if (verboseMode)
        {
            Console.WriteLine("Creating Executable Deploy software update...");
            Console.WriteLine($"Package ID: {packageId}");
            Console.WriteLine($"Package Version: {packageVersion}");
            Console.WriteLine($"Command Line ID: {packageIdVersion}");
            Console.WriteLine($"Generated UpdateId: {updateId}");
        }

        var update = new WindowsSoftwareUpdate(
            providerId,
            WindowsSoftwareUpdateInstallationType.Executable,
            updateId,
            title,
            description,
            new Uri($"http://contoso.com/updateId={updateId}"),
            1024 * 1024,
            2 * 1024 * 1024,
            null, // WindowsSoftwareUpdateSourceVersion
            new WindowsSoftwareUpdateVersion(1, 2, 3, 4),
            null, // WindowsSoftwareUpdateAppPackageInfo
            new WindowsSoftwareUpdateExecutionInfo(
                new WindowsSoftwareUpdateActionInfo(
                    moduleFileName,
                    deployCmd,
                    WindowsSoftwareUpdateActionType.Deploy),
                optionalActionsInfo),
            new WindowsSoftwareUpdateOptionalInfo(localizationInfo, null, null));

        if (verboseMode)
        {
            Console.WriteLine(ToDetailedString(update));
        }

        return update;
    }

    /// <summary>
    /// Creates an executable download/install update object.
    /// </summary>
    public static WindowsSoftwareUpdate CreateExecutableDownloadInstallUpdate(string providerId, bool enableLogging, bool verboseMode)
    {
        // Set the package ID and version for this update type
        string packageId = "SampleApp.DownloadInstall";
        string packageVersion = "5.6.7.8";

        // Create the command line parameter: packageId_packageVersion
        string packageIdVersion = $"{packageId}_{packageVersion}";

        // Generate updateId by hashing the packageId_packageVersion
        string updateId = GenerateUpdateId(packageIdVersion);

        string title = "Executable Download/Install Update (5.6.7.8)";
        string description = "Executable Download/Install Update Description";

        // Localization Info
        var localizationInfo = new List<WindowsSoftwareUpdateLocalizationInfo>
        {
            new WindowsSoftwareUpdateLocalizationInfo(
                3082, // es-ES
                "Executable Download/Install Actualización 1234 Título (es-ES)",
                "Executable Download/Install Actualización 1234 Descripción (es-ES)",
                new Uri($"http://contoso.com/es-ES/updateId={updateId}")
            ),
            new WindowsSoftwareUpdateLocalizationInfo(
                1036, // fr-FR
                "Executable Download/Install Mise à jour 1234 Titre (fr-FR)",
                "Executable Download/Install Mise à jour 1234 Description (fr-FR)",
                new Uri($"http://contoso.com/fr-FR/updateId={updateId}")
            )
        };

        // Create command strings for readability
        string downloadCmd = $"download --providerId {providerId} --updateId {packageIdVersion}";
        string installCmd = $"install --providerId {providerId} --updateId {packageIdVersion}";
        string installForceCloseCmd = $"{installCmd} --forceClose";
        string restartCmd = $"restart --providerId {providerId} --updateId {packageIdVersion}";

        // Add --log flag to commands if logging is enabled
        if (enableLogging)
        {
            downloadCmd += " --log";
            installCmd += " --log";
            installForceCloseCmd += " --log";
            restartCmd += " --log";
        }

        // Add --verbose flag to commands if verbose is enabled
        if (verboseMode)
        {
            downloadCmd += " --verbose";
            installCmd += " --verbose";
            installForceCloseCmd += " --verbose";
            restartCmd += " --verbose";
        }

        // Get the current module filename
        string moduleFileName = GetCurrentModuleFileName();

        // Optional Actions Info (for download/install, we include closeAndInstall and closeAndRestart)
        var optionalActionsInfo = new WindowsSoftwareUpdateOptionalActionInfo(
            null, // No closeAndDeploy for download/install updates
            new WindowsSoftwareUpdateActionInfo(
                moduleFileName,
                installForceCloseCmd,
                WindowsSoftwareUpdateActionType.Install),
            new WindowsSoftwareUpdateActionInfo(
                moduleFileName,
                restartCmd,
                WindowsSoftwareUpdateActionType.AppRestart));

        if (verboseMode)
        {
            Console.WriteLine("Creating Executable Download/Install software update...");
            Console.WriteLine($"Package ID: {packageId}");
            Console.WriteLine($"Package Version: {packageVersion}");
            Console.WriteLine($"Command Line ID: {packageIdVersion}");
            Console.WriteLine($"Generated UpdateId: {updateId}");
        }

        var update = new WindowsSoftwareUpdate(
            providerId,
            WindowsSoftwareUpdateInstallationType.Executable,
            updateId,
            title,
            description,
            new Uri($"http://contoso.com/updateId={updateId}"),
            1024 * 1024,
            2 * 1024 * 1024,
            null, // WindowsSoftwareUpdateSourceVersion
            new WindowsSoftwareUpdateVersion(5, 6, 7, 8),
            null, // WindowsSoftwareUpdateAppPackageInfo
            new WindowsSoftwareUpdateExecutionInfo(
                new WindowsSoftwareUpdateActionInfo(
                    moduleFileName,
                    downloadCmd,
                    WindowsSoftwareUpdateActionType.Download),
                new WindowsSoftwareUpdateActionInfo(
                    moduleFileName,
                    installCmd,
                    WindowsSoftwareUpdateActionType.Install),
                optionalActionsInfo),
            new WindowsSoftwareUpdateOptionalInfo(localizationInfo, null, null));

        if (verboseMode)
        {
            Console.WriteLine(ToDetailedString(update));
        }

        return update;
    }

    /// <summary>
    /// Creates an app package update object.
    /// </summary>
    public static WindowsSoftwareUpdate CreateAppPackageUpdate(string providerId, bool verboseMode)
    {
        // Set the title for this update type
        string title = "AppPackage Update (2.3.4.5)";

        // Use package family name and architecture for update ID generation
        string packageFamilyName = "Microsoft.OutlookForWindows_8wekyb3d8bbwe";
        string architecture = "X64";
        string packageInfo = $"{packageFamilyName}_{architecture}";
        string updateId = GenerateUpdateId(packageInfo);

        if (verboseMode)
        {
            Console.WriteLine("Creating AppPackage software update...");
            Console.WriteLine($"Package Family Name: {packageFamilyName}");
            Console.WriteLine($"Architecture: {architecture}");
            Console.WriteLine($"Generated UpdateId: {updateId}");
        }

        var appPackageInfo = new WindowsSoftwareUpdateAppPackageInfo(
            packageFamilyName,
            WindowsSoftwareUpdateArchitecture.X64,
            new Uri("https://go.microsoft.com/fwlink/?linkid=2195164"));

        var update = new WindowsSoftwareUpdate(
            providerId,
            WindowsSoftwareUpdateInstallationType.AppPackage,
            updateId,
            title,
            "AppPackage Update (2.3.4.5) Description",
            new Uri($"http://contoso.com/updateId={updateId}"),
            1024 * 1024,
            2 * 1024 * 1024,
            null, // WindowsSoftwareUpdateSourceVersion
            new WindowsSoftwareUpdateVersion(2, 3, 4, 5),
            appPackageInfo,
            null, // WindowsSoftwareUpdateExecutionInfo
            null); // WindowsSoftwareUpdateOptionalInfo

        if (verboseMode)
        {
            Console.WriteLine(ToDetailedString(update));
        }

        return update;
    }

    /// <summary>
    /// Converts a WindowsSoftwareUpdate to a detailed string representation.
    /// </summary>
    private static string ToDetailedString(WindowsSoftwareUpdate update)
    {
        var sb = new StringBuilder();
        sb.AppendLine("======================================");
        sb.AppendLine($"Update Id: {update.UpdateId}");
        sb.AppendLine($"Title: {update.Title}");
        sb.AppendLine($"Description: {update.Description}");
        sb.AppendLine($"More Info URL: {update.MoreInfoUrl}");
        sb.AppendLine($"Download Size: {update.DownloadSizeInBytes} bytes");
        sb.AppendLine($"Install Size: {update.InstallSizeInBytes} bytes");
        sb.AppendLine($"Provider Id: {update.ProviderId}");
        sb.AppendLine($"Installation Type: {(int)update.InstallationType}");
        sb.AppendLine($"Product Code: {(update.ProductCode.HasValue ? update.ProductCode.Value.ToString() : "[empty]")}");
        sb.AppendLine($"Package Family Name: {update.PackageFamilyName ?? "[empty]"}");

        // Update Source Version
        var sourceVersion = update.SourceVersion;
        if (sourceVersion != null)
        {
            sb.AppendLine($"Source Version: {sourceVersion.Major}.{sourceVersion.Minor}.{sourceVersion.RevisionMajor}.{sourceVersion.RevisionMinor}");
        }
        else
        {
            sb.AppendLine("Source Version: [empty]");
        }

        // Update Target Version
        var targetVersion = update.TargetVersion;
        sb.AppendLine($"Target Version: {targetVersion.Major}.{targetVersion.Minor}.{targetVersion.RevisionMajor}.{targetVersion.RevisionMinor}");

        // App Package Information
        var appPackageInfo = update.AppPackageInfo;
        if (appPackageInfo != null)
        {
            sb.AppendLine("App Package Information:");
            sb.AppendLine($"  PackageFamilyName: {appPackageInfo.PackageFamilyName}");
            sb.AppendLine($"  InstallUri: {appPackageInfo.InstallUri}");
            sb.AppendLine($"  Architecture: {(int)appPackageInfo.PackageArchitecture}");
        }
        else
        {
            sb.AppendLine("App Package Information: [empty]");
        }

        // Optional Information
        var optInfo = update.OptionalInfo;
        if (optInfo != null)
        {
            sb.AppendLine("Optional Information:");
            sb.AppendLine(optInfo.ComplianceDeadlineInDays.HasValue
                ? $"  ComplianceDeadlineInDays: {optInfo.ComplianceDeadlineInDays.Value}"
                : "  ComplianceDeadlineInDays: [empty]");

            sb.AppendLine(optInfo.ComplianceGracePeriodInDays.HasValue
                ? $"  ComplianceGracePeriodInDays: {optInfo.ComplianceGracePeriodInDays.Value}"
                : "  ComplianceGracePeriodInDays: [empty]");

            if (optInfo.LocalizationInfo != null && optInfo.LocalizationInfo.Count > 0)
            {
                sb.AppendLine("  LocalizationInfo:");
                foreach (var loc in optInfo.LocalizationInfo)
                {
                    sb.AppendLine($"    LanguageId: {loc.LanguageId}");
                    sb.AppendLine($"    Title: {loc.Title}");
                    sb.AppendLine($"    Description: {loc.Description}");
                    sb.AppendLine($"    MoreInfoUrl: {(loc.MoreInfoUrl != null ? loc.MoreInfoUrl.ToString() : "[empty]")}");
                }
            }
        }
        else
        {
            sb.AppendLine("Optional Information: [empty]");
        }

        // Executable Information
        if (update.ExecutionInfo != null)
        {
            var downloadActionInfo = update.ExecutionInfo.DownloadInfo;
            if (downloadActionInfo != null)
            {
                sb.AppendLine("Executable Information (Download):");
                sb.AppendLine($"  FileName: {downloadActionInfo.FileName}");
                sb.AppendLine($"  FileArguments: {downloadActionInfo.FileArguments}");
                sb.AppendLine($"  ActionType: {(int)downloadActionInfo.ActionType}");
            }
            else
            {
                sb.AppendLine("Executable Information (Download): [empty]");
            }

            var installActionInfo = update.ExecutionInfo.InstallInfo;
            if (installActionInfo != null)
            {
                sb.AppendLine("Executable Information (Install):");
                sb.AppendLine($"  FileName: {installActionInfo.FileName}");
                sb.AppendLine($"  FileArguments: {installActionInfo.FileArguments}");
                sb.AppendLine($"  ActionType: {(int)installActionInfo.ActionType}");
            }
            else
            {
                sb.AppendLine("Executable Information (Install): [empty]");
            }

            var deployActionInfo = update.ExecutionInfo.DeployInfo;
            if (deployActionInfo != null)
            {
                sb.AppendLine("Executable Information (Deploy):");
                sb.AppendLine($"  FileName: {deployActionInfo.FileName}");
                sb.AppendLine($"  FileArguments: {deployActionInfo.FileArguments}");
                sb.AppendLine($"  ActionType: {(int)deployActionInfo.ActionType}");
            }
            else
            {
                sb.AppendLine("Executable Information (Deploy): [empty]");
            }

            // Optional Action Executable Information
            if (update.ExecutionInfo.OptionalActionInfo != null)
            {
                var closeAndDeployActionInfo = update.ExecutionInfo.OptionalActionInfo.CloseAndDeployInfo;
                if (closeAndDeployActionInfo != null)
                {
                    sb.AppendLine("Executable Information (CloseAndDeploy):");
                    sb.AppendLine($"  FileName: {closeAndDeployActionInfo.FileName}");
                    sb.AppendLine($"  FileArguments: {closeAndDeployActionInfo.FileArguments}");
                    sb.AppendLine($"  ActionType: {(int)closeAndDeployActionInfo.ActionType}");
                }
                else
                {
                    sb.AppendLine("Executable Information (CloseAndDeploy): [empty]");
                }

                var closeAndInstallActionInfo = update.ExecutionInfo.OptionalActionInfo.CloseAndInstallInfo;
                if (closeAndInstallActionInfo != null)
                {
                    sb.AppendLine("Executable Information (CloseAndInstall):");
                    sb.AppendLine($"  FileName: {closeAndInstallActionInfo.FileName}");
                    sb.AppendLine($"  FileArguments: {closeAndInstallActionInfo.FileArguments}");
                    sb.AppendLine($"  ActionType: {(int)closeAndInstallActionInfo.ActionType}");
                }
                else
                {
                    sb.AppendLine("Executable Information (CloseAndInstall): [empty]");
                }

                var closeAndRestartActionInfo = update.ExecutionInfo.OptionalActionInfo.CloseAndRestartInfo;
                if (closeAndRestartActionInfo != null)
                {
                    sb.AppendLine("Executable Information (CloseAndRestart):");
                    sb.AppendLine($"  FileName: {closeAndRestartActionInfo.FileName}");
                    sb.AppendLine($"  FileArguments: {closeAndRestartActionInfo.FileArguments}");
                    sb.AppendLine($"  ActionType: {(int)closeAndRestartActionInfo.ActionType}");
                }
                else
                {
                    sb.AppendLine("Executable Information (CloseAndRestart): [empty]");
                }
            }
            else
            {
                sb.AppendLine("Executable Information (Optional Actions): [empty]");
            }
        }
        else
        {
            sb.AppendLine("Executable Information: [empty]");
        }

        sb.AppendLine("======================================");

        return sb.ToString();
    }
}
