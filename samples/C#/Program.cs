//
// Copyright (c) Microsoft Corporation.  All rights reserved.
//
// Version: 1.0.0.0
// Revision: 2025.10.31
//

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading;
using Windows.Foundation;
using Windows.Management.Update;

namespace SampleProvider;

internal class Program
{
    private static bool s_enableLogging = false;
    private static bool s_forceClose = false;
    private static bool s_verboseMode = false;
    private static StreamWriter? s_logWriter = null;

    static int Main(string[] args)
    {
        try
        {
            bool printUsage = false;
            string providerId = "SampleProvider"; // Default provider ID
            string updateId = ""; // Optional update ID

            if (args.Length < 1)
            {
                printUsage = true;
                Console.WriteLine("Expected at least 1 argument");
            }
            else
            {
                // Parse --providerId, --updateId, --log, --forceClose, and --verbose arguments if present
                for (int i = 0; i < args.Length; i++)
                {
                    if (string.Equals(args[i], "--providerId", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                    {
                        providerId = args[i + 1];
                        Console.WriteLine($"Using provider ID: {providerId}");
                        i++;
                    }
                    else if (string.Equals(args[i], "--updateId", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                    {
                        updateId = args[i + 1];
                        Console.WriteLine($"Using update ID: {updateId}");
                        i++;
                    }
                    else if (string.Equals(args[i], "--log", StringComparison.OrdinalIgnoreCase))
                    {
                        s_enableLogging = true;
                    }
                    else if (string.Equals(args[i], "--forceClose", StringComparison.OrdinalIgnoreCase))
                    {
                        s_forceClose = true;
                        Console.WriteLine("Force close applications: Enabled");
                    }
                    else if (string.Equals(args[i], "--verbose", StringComparison.OrdinalIgnoreCase))
                    {
                        s_verboseMode = true;
                        Console.WriteLine("Verbose mode: Enabled");
                    }
                }

                // Set up logging if requested (do this early, before any other output)
                if (s_enableLogging)
                {
                    if (!EnableLogging())
                    {
                        Console.Error.WriteLine("Failed to set up logging, continuing with console output");
                    }
                    else
                    {
                        Console.WriteLine("Logging enabled");
                    }
                }

                string command = args[0].ToLowerInvariant();
                switch (command)
                {
                    case "scan":
                        PerformScan(providerId);
                        break;
                    case "download":
                        PerformAction(providerId, "download", updateId);
                        break;
                    case "install":
                        PerformAction(providerId, "install", updateId);
                        break;
                    case "deploy":
                        PerformAction(providerId, "deploy", updateId);
                        break;
                    case "restart":
                        PerformAction(providerId, "restart", updateId);
                        break;
                    default:
                        printUsage = true;
                        break;
                }
            }

            if (printUsage)
            {
                PrintUsage();
            }

            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error: {ex.Message}");
            Console.Error.WriteLine($"Stack trace: {ex.StackTrace}");
            return 1;
        }
        finally
        {
            s_logWriter?.Dispose();
        }
    }

    private static void PrintUsage()
    {
        Console.WriteLine("Usage: [] denotes optional argument, <> denotes required argument");
        Console.WriteLine("    scan [--providerId <ProviderID>] [--log] [--verbose] - report scan result with available updates");
        Console.WriteLine("    download [--providerId <ProviderID>] [--updateId <UpdateID>] [--log] [--verbose] - perform download action");
        Console.WriteLine("    install [--providerId <ProviderID>] [--updateId <UpdateID>] [--log] [--forceClose] [--verbose] - perform install action");
        Console.WriteLine("    deploy [--providerId <ProviderID>] [--updateId <UpdateID>] [--log] [--forceClose] [--verbose] - perform deploy action");
        Console.WriteLine("    restart [--providerId <ProviderID>] [--updateId <UpdateID>] [--log] [--verbose] - perform app close and relaunch action");
        Console.WriteLine();
        Console.WriteLine("Options:");
        Console.WriteLine("    --providerId <ProviderID> - Specify the provider ID (defaults to 'SampleProvider')");
        Console.WriteLine("    --updateId <UpdateID> - Specify the update ID for the action");
        Console.WriteLine("    --log - Redirect console output to SampleProvider.log in State subfolder");
        Console.WriteLine("    --forceClose - Force close applications during install/deploy actions");
        Console.WriteLine("    --verbose - Display detailed update information for each update object created");
    }

    private static bool EnableLogging()
    {
        try
        {
            // Get the directory containing the executable (use AppContext.BaseDirectory for single-file compatibility)
            string? exeDir = AppContext.BaseDirectory;
            if (string.IsNullOrEmpty(exeDir))
            {
                Console.Error.WriteLine("Failed to get executable directory");
                return false;
            }
            if (string.IsNullOrEmpty(exeDir))
            {
                Console.Error.WriteLine("Failed to get executable directory");
                return false;
            }

            string stateDir = Path.Combine(exeDir, "State");
            string logPath = Path.Combine(stateDir, "SampleProvider.log");

            // Create the State directory if it doesn't exist
            Directory.CreateDirectory(stateDir);

            // Open the log file for writing (append mode)
            s_logWriter = new StreamWriter(logPath, append: true)
            {
                AutoFlush = true
            };

            // Redirect console output to the log file
            Console.SetOut(s_logWriter);
            Console.SetError(s_logWriter);

            // Write a timestamp to the log
            Console.WriteLine($"=== SampleProvider Log Started at {DateTime.Now:yyyy-MM-dd HH:mm:ss} ===");

            return true;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Exception setting up logging: {ex.Message}");
            return false;
        }
    }

    private static void PerformScan(string providerId)
    {
        Console.WriteLine("=== SCAN RESULTS ===");
        Console.WriteLine($"Provider ID: {providerId}");
        Console.WriteLine();

        var executableDeployUpdate = UpdateHelper.CreateExecutableDeployUpdate(providerId, s_enableLogging, s_verboseMode);
        Console.WriteLine("Update Type: Executable Deploy");
        Console.WriteLine($"Update ID: {executableDeployUpdate.UpdateId}");
        Console.WriteLine($"Title: {executableDeployUpdate.Title}");
        Console.WriteLine($"Version: {executableDeployUpdate.TargetVersion.Major}.{executableDeployUpdate.TargetVersion.Minor}.{executableDeployUpdate.TargetVersion.RevisionMajor}.{executableDeployUpdate.TargetVersion.RevisionMinor}");
        Console.WriteLine();

        var executableDownloadInstallUpdate = UpdateHelper.CreateExecutableDownloadInstallUpdate(providerId, s_enableLogging, s_verboseMode);
        Console.WriteLine("Update Type: Executable Download/Install");
        Console.WriteLine($"Update ID: {executableDownloadInstallUpdate.UpdateId}");
        Console.WriteLine($"Title: {executableDownloadInstallUpdate.Title}");
        Console.WriteLine($"Version: {executableDownloadInstallUpdate.TargetVersion.Major}.{executableDownloadInstallUpdate.TargetVersion.Minor}.{executableDownloadInstallUpdate.TargetVersion.RevisionMajor}.{executableDownloadInstallUpdate.TargetVersion.RevisionMinor}");
        Console.WriteLine();

        var appPackageUpdate = UpdateHelper.CreateAppPackageUpdate(providerId, s_enableLogging, s_verboseMode);
        Console.WriteLine("Update Type: AppPackage");
        Console.WriteLine($"Update ID: {appPackageUpdate.UpdateId}");
        Console.WriteLine($"Title: {appPackageUpdate.Title}");
        Console.WriteLine($"Version: {appPackageUpdate.TargetVersion.Major}.{appPackageUpdate.TargetVersion.Minor}.{appPackageUpdate.TargetVersion.RevisionMajor}.{appPackageUpdate.TargetVersion.RevisionMinor}");
        Console.WriteLine();

        Console.WriteLine("Creating empty software update collection...");
        var updateCollection = new List<WindowsSoftwareUpdate>
        {
            executableDeployUpdate,
            executableDownloadInstallUpdate,
            appPackageUpdate
        };

        Console.WriteLine("Creating provider status...");
        var providerStatus = new WindowsSoftwareUpdateProviderStatus(providerId);

        Console.WriteLine("Setting scan result...");
        var statusResult = providerStatus.SetScanResult(true, 0, 0, updateCollection);
        Console.WriteLine($"SetScanResult() -> {UpdateHelper.ToString(statusResult)}");
    }

    private static void PerformAction(
        string providerId,
        string action,
        string updateId,
        WindowsSoftwareUpdateActionResult result = WindowsSoftwareUpdateActionResult.Succeeded,
        WindowsSoftwareUpdateRestartReason reason = WindowsSoftwareUpdateRestartReason.None,
        int resultCode = 0,
        ulong extendedError = 0)
    {
        Console.WriteLine("Creating provider status...");
        var providerStatus = new WindowsSoftwareUpdateProviderStatus(providerId);

        try
        {
            // Send an initial progress tick
            var progressResult = providerStatus.SetActionProgress(0, 100);
            Console.WriteLine($"SetActionProgress() -> {UpdateHelper.ToString(progressResult)}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Initial SetActionProgress() -> Failed: {ex.Message}");
        }

        Console.WriteLine($"Action: {action}");
        if (s_forceClose && (action == "install" || action == "deploy"))
        {
            Console.WriteLine("Force close mode: Would close conflicting applications before action");
        }

        if (!string.IsNullOrEmpty(updateId))
        {
            Console.WriteLine($"Update ID: {updateId}");

            // Parse the WinGet-style updateId (packageId_packageVersion format)
            int underscorePos = updateId.LastIndexOf('_');
            if (underscorePos >= 0)
            {
                string packageId = updateId.Substring(0, underscorePos);
                string packageVersion = updateId.Substring(underscorePos + 1);

                Console.WriteLine($"Package ID: {packageId}");
                Console.WriteLine($"Package Version: {packageVersion}");
            }
            else
            {
                Console.WriteLine("Note: Update ID doesn't follow packageId_packageVersion format");
            }
        }

        if (action == "deploy" || action == "download" || action == "install" || action == "restart")
        {
            // Send some progress ticks
            for (int i = 0; i < 100; i += 10)
            {
                Thread.Sleep(500); // Faster for demo purposes
                Console.WriteLine($"Setting action progress: {i} / 100");
                try
                {
                    // Send a progress tick based on the current iteration
                    var progressResult = providerStatus.SetActionProgress((ulong)i, 100);
                    Console.WriteLine($"SetActionProgress() -> {UpdateHelper.ToString(progressResult)}");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Loop SetActionProgress() -> Failed: {ex.Message}");
                }
            }

            try
            {
                // Send a final progress tick
                var progressResult = providerStatus.SetActionProgress(100, 100);
                Console.WriteLine($"SetActionProgress() -> {UpdateHelper.ToString(progressResult)}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Final SetActionProgress() -> Failed: {ex.Message}");
            }
        }
        else
        {
            Console.WriteLine("Error: Unexpected action");

            // Unexpected action value
            result = WindowsSoftwareUpdateActionResult.Failed;
            reason = WindowsSoftwareUpdateRestartReason.None;
            resultCode = unchecked((int)0x8000FFFF); // E_UNEXPECTED
            extendedError = 18446744071562133503;
        }

        // Send the requested result
        Console.WriteLine("Creating provider action result...");
        var actionResult = new WindowsSoftwareUpdateProviderActionResult(result, reason, (uint)resultCode, extendedError);
        Console.WriteLine("Setting action result...");
        try
        {
            var statusResult = providerStatus.SetActionResult(actionResult);
            Console.WriteLine($"SetActionResult() -> {UpdateHelper.ToString(statusResult)}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"SetActionResult() -> Failed: {ex.Message}");
        }
    }
}
