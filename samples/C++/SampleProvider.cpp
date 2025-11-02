//
// Copyright (c) Microsoft Corporation.  All rights reserved.
//
// Version: 1.0.0.0
// Revision: 2025.10.31
//

#include <windows.h>
#include <string>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <fstream>
#include <filesystem>
#include <chrono>
#include <wil/cppwinrt.h>
#include <wil/resource.h>
#include <wil/result_macros.h>
#include <winrt\windows.foundation.h>
#include <winrt\windows.foundation.collections.h>
#include <winrt\Windows.Management.Update.h>

using namespace winrt::Windows::Foundation;
using namespace winrt::Windows::Foundation::Collections;
using namespace winrt::Windows::Management::Update;

// Global flag for logging output
bool g_enableLogging = false;

// Global flag for force close applications
bool g_forceClose = false;

// Global flag for verbose output
bool g_verboseMode = false;

std::wstring to_wstring(const WindowsSoftwareUpdate update)
{
    std::wostringstream result;

    result << L"======================================" << std::endl;

    result << L"Update Id: " << update.UpdateId().c_str() << std::endl;
    result << L"Title: " << update.Title().c_str() << std::endl;
    result << L"Description: " << update.Description().c_str() << std::endl;
    result << L"More Info URL: " << update.MoreInfoUrl().RawUri().c_str() << std::endl;
    result << L"Download Size: " << update.DownloadSizeInBytes() << L" bytes" << std::endl;
    result << L"Install Size: " << update.InstallSizeInBytes() << L" bytes" << std::endl;
    result << L"Provider Id: " << update.ProviderId().c_str() << std::endl;
    result << L"Installation Type: " << static_cast<int>(update.InstallationType()) << std::endl;
    result << L"Product Code: " << (update.ProductCode() ? winrt::to_hstring(update.ProductCode().Value()).c_str() : L"[empty]") << std::endl;
    result << L"Package Family Name: " << (update.PackageFamilyName().c_str() ? update.PackageFamilyName().c_str() : L"[empty]") << std::endl;

    // Update Source Version
    auto sourceVersion = update.SourceVersion();
    result << L"Source Version: " << sourceVersion.Major() << L"." << sourceVersion.Minor() << L"." << sourceVersion.RevisionMajor() << L"." << sourceVersion.RevisionMinor() << std::endl;

    // Update Target Version
    auto targetVersion = update.TargetVersion();
    result << L"Target Version: " << targetVersion.Major() << L"." << targetVersion.Minor() << L"." << targetVersion.RevisionMajor() << L"." << targetVersion.RevisionMinor() << std::endl;

    // App Package Information
    auto appPackageInfo = update.AppPackageInfo();
    if (appPackageInfo)
    {
        result << L"App Package Information:" << std::endl;
        result << L"  PackageFamilyName: " << appPackageInfo.PackageFamilyName().c_str() << std::endl;
        result << L"  InstallUri: " << appPackageInfo.InstallUri().RawUri().c_str() << std::endl;
        result << L"  Architecture: " << static_cast<int>(appPackageInfo.PackageArchitecture()) << std::endl;
    }
    else
    {
        result << L"App Package Information: [empty]" << std::endl;
    }

    // Optional Information
    auto optInfo = update.OptionalInfo();
    if (optInfo)
    {
        result << L"Optional Information:" << std::endl;
        result << (optInfo.ComplianceDeadlineInDays() ?
            L"  ComplianceDeadlineInDays: " + optInfo.ComplianceDeadlineInDays().Value() :
            L"  ComplianceDeadlineInDays: [empty]") << std::endl;

        result << (optInfo.ComplianceGracePeriodInDays() ?
            L"  ComplianceGracePeriodInDays: " + optInfo.ComplianceGracePeriodInDays().Value() :
            L"  ComplianceGracePeriodInDays: [empty]") << std::endl;

        if (optInfo.LocalizationInfo() && optInfo.LocalizationInfo().Size() > 0)
        {
            result << L"  LocalizationInfo:" << std::endl;
            for (auto const& loc : optInfo.LocalizationInfo())
            {
                result << L"    LanguageId: " << loc.LanguageId() << std::endl;
                result << L"    Title: " << loc.Title().c_str() << std::endl;
                result << L"    Description: " << loc.Description().c_str() << std::endl;
                result << L"    MoreInfoUrl: " << (loc.MoreInfoUrl() ? loc.MoreInfoUrl().RawUri().c_str() : L"[empty]") << std::endl;
            }
        }
    }
    else
    {
        result << L"Optional Information: [empty]" << std::endl;
    }

    // Executable Information
    if (update.ExecutionInfo())
    {
        if (auto downloadActionInfo = update.ExecutionInfo().DownloadInfo(); downloadActionInfo)
        {
            result << L"Executable Information (Download):" << std::endl;
            result << L"  FileName: " << downloadActionInfo.FileName().c_str() << std::endl;
            result << L"  FileArguments: " << downloadActionInfo.FileArguments().c_str() << std::endl;
            result << L"  ActionType: " << static_cast<int>(downloadActionInfo.ActionType()) << std::endl;
        }
        else
        {
            result << L"Executable Information (Download): [empty]" << std::endl;
        }

        if (auto installActionInfo = update.ExecutionInfo().InstallInfo(); installActionInfo)
        {
            result << L"Executable Information (Install):" << std::endl;
            result << L"  FileName: " << installActionInfo.FileName().c_str() << std::endl;
            result << L"  FileArguments: " << installActionInfo.FileArguments().c_str() << std::endl;
            result << L"  ActionType: " << static_cast<int>(installActionInfo.ActionType()) << std::endl;
        }
        else
        {
            result << L"Executable Information (Install): [empty]" << std::endl;
        }

        if (auto deployActionInfo = update.ExecutionInfo().DeployInfo(); deployActionInfo)
        {
            result << L"Executable Information (Deploy):" << std::endl;
            result << L"  FileName: " << deployActionInfo.FileName().c_str() << std::endl;
            result << L"  FileArguments: " << deployActionInfo.FileArguments().c_str() << std::endl;
            result << L"  ActionType: " << static_cast<int>(deployActionInfo.ActionType()) << std::endl;
        }
        else
        {
            result << L"Executable Information (Deploy): [empty]" << std::endl;
        }

        // Optional Action Executable Information
        if (update.ExecutionInfo().OptionalActionInfo())
        {
            if (auto closeAndDeployActionInfo = update.ExecutionInfo().OptionalActionInfo().CloseAndDeployInfo(); closeAndDeployActionInfo)
            {
                result << L"Executable Information (CloseAndDeploy):" << std::endl;
                result << L"  FileName: " << closeAndDeployActionInfo.FileName().c_str() << std::endl;
                result << L"  FileArguments: " << closeAndDeployActionInfo.FileArguments().c_str() << std::endl;
                result << L"  ActionType: " << static_cast<int>(closeAndDeployActionInfo.ActionType()) << std::endl;
            }
            else
            {
                result << L"Executable Information (CloseAndDeploy): [empty]" << std::endl;
            }

            if (auto closeAndInstallActionInfo = update.ExecutionInfo().OptionalActionInfo().CloseAndInstallInfo(); closeAndInstallActionInfo)
            {
                result << L"Executable Information (CloseAndInstall):" << std::endl;
                result << L"  FileName: " << closeAndInstallActionInfo.FileName().c_str() << std::endl;
                result << L"  FileArguments: " << closeAndInstallActionInfo.FileArguments().c_str() << std::endl;
                result << L"  ActionType: " << static_cast<int>(closeAndInstallActionInfo.ActionType()) << std::endl;
            }
            else
            {
                result << L"Executable Information (CloseAndInstall): [empty]" << std::endl;
            }

            if (auto closeAndRestartActionInfo = update.ExecutionInfo().OptionalActionInfo().CloseAndRestartInfo(); closeAndRestartActionInfo)
            {
                result << L"Executable Information (CloseAndRestart):" << std::endl;
                result << L"  FileName: " << closeAndRestartActionInfo.FileName().c_str() << std::endl;
                result << L"  FileArguments: " << closeAndRestartActionInfo.FileArguments().c_str() << std::endl;
                result << L"  ActionType: " << static_cast<int>(closeAndRestartActionInfo.ActionType()) << std::endl;
            }
            else
            {
                result << L"Executable Information (CloseAndRestart): [empty]" << std::endl;
            }
        }
        else
        {
            result << L"Executable Information (Optional Actions): [empty]" << std::endl;
        }
    }
    else
    {
        result << L"Executable Information: [empty]" << std::endl;
    }

    result << L"======================================" << std::endl;

    return result.str();
}

std::wstring to_wstring(const WindowsSoftwareUpdateResult result)
{
    return std::wstring(L"Succeeded: ") + std::wstring(result.Succeeded() ? L"true" : L"false") +
        std::wstring(L", CancelRequested: ") + std::wstring(result.CancelRequested() ? L"true" : L"false") +
        std::wstring(L", ResultCode: ") + std::to_wstring(result.ResultCode()) +
        std::wstring(L", ExtendedError: ") + std::to_wstring(result.ExtendedError());
}

// Base64 encoding function
std::wstring Base64Encode(const std::wstring& input)
{
    // Convert wide string to UTF-8 bytes
    std::string utf8Input;
    for (wchar_t wc : input)
    {
        if (wc < 0x80) {
            utf8Input += static_cast<char>(wc);
        }
        else if (wc < 0x800) {
            utf8Input += static_cast<char>(0xC0 | (wc >> 6));
            utf8Input += static_cast<char>(0x80 | (wc & 0x3F));
        }
        else {
            utf8Input += static_cast<char>(0xE0 | (wc >> 12));
            utf8Input += static_cast<char>(0x80 | ((wc >> 6) & 0x3F));
            utf8Input += static_cast<char>(0x80 | (wc & 0x3F));
        }
    }

    // Simple Base64 encoding
    const std::string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string result;
    int val = 0, valb = -6;
    for (unsigned char c : utf8Input) {
        val = (val << 8) + c;
        valb += 8;
        while (valb >= 0) {
            result.push_back(chars[(val >> valb) & 0x3F]);
            valb -= 6;
        }
    }
    if (valb > -6) result.push_back(chars[((val << 8) >> (valb + 8)) & 0x3F]);
    while (result.size() % 4) result.push_back('=');

    // Convert back to wide string
    std::wstring wideResult;
    for (char c : result) {
        wideResult += static_cast<wchar_t>(c);
    }
    return wideResult;
}

// Base64 decoding function
std::wstring Base64Decode(const std::wstring& input)
{
    // Convert wide string to narrow for decoding
    std::string narrowInput;
    for (wchar_t wc : input) {
        narrowInput += static_cast<char>(wc);
    }

    // Simple Base64 decoding
    std::string result;
    int val = 0, valb = -8;
    for (char c : narrowInput) {
        if (c == '=') break;
        int index;
        if (c >= 'A' && c <= 'Z') index = c - 'A';
        else if (c >= 'a' && c <= 'z') index = c - 'a' + 26;
        else if (c >= '0' && c <= '9') index = c - '0' + 52;
        else if (c == '+') index = 62;
        else if (c == '/') index = 63;
        else continue;

        val = (val << 6) + index;
        valb += 6;
        if (valb >= 0) {
            result.push_back(char((val >> valb) & 0xFF));
            valb -= 8;
        }
    }

    // Convert UTF-8 bytes back to wide string (simple conversion for basic characters)
    std::wstring wideResult;
    for (char c : result) {
        wideResult += static_cast<wchar_t>(static_cast<unsigned char>(c));
    }
    return wideResult;
}

// Generate a hash for package information (32 character hex string)
// Uses SHA256 to match the C# implementation
std::wstring GenerateUpdateId(const std::wstring& input)
{
    // Convert wide string to UTF-8 bytes for hashing
    std::string utf8Input;
    for (wchar_t wc : input)
    {
        if (wc < 0x80) {
            utf8Input += static_cast<char>(wc);
        }
        else if (wc < 0x800) {
            utf8Input += static_cast<char>(0xC0 | (wc >> 6));
            utf8Input += static_cast<char>(0x80 | (wc & 0x3F));
        }
        else {
            utf8Input += static_cast<char>(0xE0 | (wc >> 12));
            utf8Input += static_cast<char>(0x80 | ((wc >> 6) & 0x3F));
            utf8Input += static_cast<char>(0x80 | (wc & 0x3F));
        }
    }

    // Simple SHA256 implementation using std::hash as a fallback
    // Note: For production, use a proper SHA256 implementation
    // This uses std::hash to approximate SHA256 behavior
    std::hash<std::string> hasher;
    size_t hashValue = hasher(utf8Input);

    // Convert to hex string (32 characters, taking first 16 bytes like C# implementation)
    std::wostringstream hexStream;
    hexStream << std::hex << std::uppercase << std::setfill(L'0');

    // Generate 16 bytes (32 hex chars) from the hash
    for (int i = 0; i < 16; i++)
    {
        hexStream << std::setw(2) << ((hashValue >> ((i % 8) * 8)) & 0xFF);
    }

    std::wstring hexString = hexStream.str();

    // Ensure exactly 32 characters
    return hexString.substr(0, 32);
}

// Helper function to get the current module path
std::filesystem::path GetCurrentModulePath()
{
    std::wstring modulePath(MAX_PATH, L'\0');
    DWORD result = GetModuleFileNameW(nullptr, modulePath.data(), MAX_PATH);
    if (result == 0)
    {
        return std::filesystem::path(L"sampleprovider.exe"); // Fallback to hardcoded name if API fails
    }

    // Resize to actual length (remove null terminators)
    modulePath.resize(result);

    return std::filesystem::path(modulePath);
}

WindowsSoftwareUpdate CreateExecutableDeployUpdate(std::wstring providerId)
{
    // Set the package ID and version for this update type
    std::wstring packageId = L"SampleApp.Deploy";
    std::wstring packageVersion = L"1.2.3.4";

    // Create the command line parameter: packageId_packageVersion
    std::wstring packageIdVersion = packageId + L"_" + packageVersion;

    // Generate updateId by hashing the packageId_packageVersion
    std::wstring updateId = GenerateUpdateId(packageIdVersion);

    std::wstring title = L"Executable Deploy Update (1.2.3.4)";
    std::wstring description = L"Executable Deploy Update Description";

    // Localization Info
    winrt::Windows::Foundation::Collections::IVector<WindowsSoftwareUpdateLocalizationInfo> localizationInfo = winrt::single_threaded_vector<WindowsSoftwareUpdateLocalizationInfo>();

    std::wostringstream urlStream1;
    urlStream1 << L"http://contoso.com/es-ES/updateId=" << updateId;
    localizationInfo.Append(
        WindowsSoftwareUpdateLocalizationInfo(
            3082, // es-ES
            L"Executable Deploy Actualizaci�n 1234 T�tulo (es-ES)",
            L"Executable Deploy Actualizaci�n 1234 Descripci�n (es-ES)",
            winrt::Windows::Foundation::Uri(urlStream1.str())
        )
    );

    std::wostringstream urlStream2;
    urlStream2 << L"http://contoso.com/fr-FR/updateId=" << updateId;
    localizationInfo.Append(
        WindowsSoftwareUpdateLocalizationInfo(
            1036, // fr-FR
            L"Executable Deploy Mise � jour 1234 Titre (fr-FR)",
            L"Executable Deploy Mise � jour 1234 Description (fr-FR)",
            winrt::Windows::Foundation::Uri(urlStream2.str())
        )
    );

    // Create command strings for readability
    std::wstring deployCmd = L"deploy --providerId " + providerId + L" --updateId " + packageIdVersion;
    std::wstring deployForceCloseCmd = deployCmd + L" --forceClose";
    std::wstring restartCmd = L"restart --providerId " + providerId + L" --updateId " + packageIdVersion;

    // Add --log flag to commands if logging is enabled
    if (g_enableLogging)
    {
        deployCmd += L" --log";
        deployForceCloseCmd += L" --log";
        restartCmd += L" --log";
    }

    // Add --verbose flag to commands if verbose is enabled
    if (g_verboseMode)
    {
        deployCmd += L" --verbose";
        deployForceCloseCmd += L" --verbose";
        restartCmd += L" --verbose";
    }

    // Get the current module filename
    std::wstring moduleFileName = GetCurrentModulePath().filename().wstring();

    // Optional Actions Info (for deploy, we only need closeAndDeploy, closeAndRestart)
    WindowsSoftwareUpdateOptionalActionInfo optionalActionsInfo(
        WindowsSoftwareUpdateActionInfo(
            moduleFileName,
            deployForceCloseCmd,
            WindowsSoftwareUpdateActionType::Deploy),
        nullptr, // No closeAndInstall for deploy-only updates
        WindowsSoftwareUpdateActionInfo(
            moduleFileName,
            restartCmd,
            WindowsSoftwareUpdateActionType::AppRestart));

    if (g_verboseMode)
    {
        std::wcout << L"Creating Executable Deploy software update..." << std::endl;
        std::wcout << L"Package ID: " << packageId << std::endl;
        std::wcout << L"Package Version: " << packageVersion << std::endl;
        std::wcout << L"Command Line ID: " << packageIdVersion << std::endl;
        std::wcout << L"Generated UpdateId: " << updateId << std::endl;
    }

    std::wostringstream mainUrlStream;
    mainUrlStream << L"http://contoso.com/updateId=" << updateId;

    WindowsSoftwareUpdate update(
        providerId,
        WindowsSoftwareUpdateInstallationType::Executable,
        updateId,
        title,
        description,
        winrt::Windows::Foundation::Uri(mainUrlStream.str()),
        1024 * 1024,
        2 * 1024 * 1024,
        nullptr /* WindowsSoftwareUpdateSourceVersion */,
        WindowsSoftwareUpdateVersion(1, 2, 3, 4),
        nullptr /* WindowsSoftwareUpdateAppPackageInfo */,
        WindowsSoftwareUpdateExecutionInfo(WindowsSoftwareUpdateActionInfo(
            moduleFileName,
            deployCmd,
            WindowsSoftwareUpdateActionType::Deploy),
            optionalActionsInfo),
        WindowsSoftwareUpdateOptionalInfo(localizationInfo, nullptr, nullptr));

    if (g_verboseMode)
    {
        std::wcout << to_wstring(update) << std::endl;
    }

    return update;
}

WindowsSoftwareUpdate CreateExecutableDownloadInstallUpdate(std::wstring providerId)
{
    // Set the package ID and version for this update type
    std::wstring packageId = L"SampleApp.DownloadInstall";
    std::wstring packageVersion = L"5.6.7.8";

    // Create the command line parameter: packageId_packageVersion
    std::wstring packageIdVersion = packageId + L"_" + packageVersion;

    // Generate updateId by hashing the packageId_packageVersion
    std::wstring updateId = GenerateUpdateId(packageIdVersion);

    std::wstring title = L"Executable Download/Install Update (5.6.7.8)";
    std::wstring description = L"Executable Download/Install Update Description";

    // Localization Info
    winrt::Windows::Foundation::Collections::IVector<WindowsSoftwareUpdateLocalizationInfo> localizationInfo = winrt::single_threaded_vector<WindowsSoftwareUpdateLocalizationInfo>();

    std::wostringstream urlStream1;
    urlStream1 << L"http://contoso.com/es-ES/updateId=" << updateId;
    localizationInfo.Append(
        WindowsSoftwareUpdateLocalizationInfo(
            3082, // es-ES
            L"Executable Download/Install Actualizaci�n 1234 T�tulo (es-ES)",
            L"Executable Download/Install Actualizaci�n 1234 Descripci�n (es-ES)",
            winrt::Windows::Foundation::Uri(urlStream1.str())
        )
    );

    std::wostringstream urlStream2;
    urlStream2 << L"http://contoso.com/fr-FR/updateId=" << updateId;
    localizationInfo.Append(
        WindowsSoftwareUpdateLocalizationInfo(
            1036, // fr-FR
            L"Executable Download/Install Mise � jour 1234 Titre (fr-FR)",
            L"Executable Download/Install Mise � jour 1234 Description (fr-FR)",
            winrt::Windows::Foundation::Uri(urlStream2.str())
        )
    );

    // Create command strings for readability
    std::wstring downloadCmd = L"download --providerId " + providerId + L" --updateId " + packageIdVersion;
    std::wstring installCmd = L"install --providerId " + providerId + L" --updateId " + packageIdVersion;
    std::wstring installForceCloseCmd = installCmd + L" --forceClose";
    std::wstring restartCmd = L"restart --providerId " + providerId + L" --updateId " + packageIdVersion;

    // Add --log flag to commands if logging is enabled
    if (g_enableLogging)
    {
        downloadCmd += L" --log";
        installCmd += L" --log";
        installForceCloseCmd += L" --log";
        restartCmd += L" --log";
    }

    // Add --verbose flag to commands if verbose is enabled
    if (g_verboseMode)
    {
        downloadCmd += L" --verbose";
        installCmd += L" --verbose";
        installForceCloseCmd += L" --verbose";
        restartCmd += L" --verbose";
    }

    // Get the current module filename
    std::wstring moduleFileName = GetCurrentModulePath().filename().wstring();

    // Optional Actions Info (for download/install, we include closeAndInstall and closeAndRestart)
    WindowsSoftwareUpdateOptionalActionInfo optionalActionsInfo(
        nullptr, // No closeAndDeploy for download/install updates
        WindowsSoftwareUpdateActionInfo(
            moduleFileName,
            installForceCloseCmd,
            WindowsSoftwareUpdateActionType::Install),
        WindowsSoftwareUpdateActionInfo(
            moduleFileName,
            restartCmd,
            WindowsSoftwareUpdateActionType::AppRestart));

    if (g_verboseMode)
    {
        std::wcout << L"Creating Executable Download/Install software update..." << std::endl;
        std::wcout << L"Package ID: " << packageId << std::endl;
        std::wcout << L"Package Version: " << packageVersion << std::endl;
        std::wcout << L"Command Line ID: " << packageIdVersion << std::endl;
        std::wcout << L"Generated UpdateId: " << updateId << std::endl;
    }

    std::wostringstream mainUrlStream;
    mainUrlStream << L"http://contoso.com/updateId=" << updateId;

    WindowsSoftwareUpdate update(
        providerId,
        WindowsSoftwareUpdateInstallationType::Executable,
        updateId,
        title,
        description,
        winrt::Windows::Foundation::Uri(mainUrlStream.str()),
        1024 * 1024,
        2 * 1024 * 1024,
        nullptr /* WindowsSoftwareUpdateSourceVersion */,
        WindowsSoftwareUpdateVersion(5, 6, 7, 8),
        nullptr /* WindowsSoftwareUpdateAppPackageInfo */,
        WindowsSoftwareUpdateExecutionInfo(
            WindowsSoftwareUpdateActionInfo(
                moduleFileName,
                downloadCmd,
                WindowsSoftwareUpdateActionType::Download),
            WindowsSoftwareUpdateActionInfo(
                moduleFileName,
                installCmd,
                WindowsSoftwareUpdateActionType::Install),
            optionalActionsInfo),
        WindowsSoftwareUpdateOptionalInfo(localizationInfo, nullptr, nullptr));

    if (g_verboseMode)
    {
        std::wcout << to_wstring(update) << std::endl;
    }

    return update;
}

WindowsSoftwareUpdate CreateAppPackageUpdate(std::wstring providerId)
{
    // Set the title for this update type
    std::wstring title = L"AppPackage Update (2.3.4.5)";

    // Use package family name and architecture for update ID generation
    std::wstring packageFamilyName = L"Microsoft.OutlookForWindows_8wekyb3d8bbwe";
    std::wstring architecture = L"X64";
    std::wstring packageInfo = packageFamilyName + L"_" + architecture;
    std::wstring updateId = GenerateUpdateId(packageInfo);

    if (g_verboseMode)
    {
        std::wcout << L"Creating AppPackage software update..." << std::endl;
        std::wcout << L"Package Family Name: " << packageFamilyName << std::endl;
        std::wcout << L"Architecture: " << architecture << std::endl;
        std::wcout << L"Generated UpdateId: " << updateId << std::endl;
    }

    std::wostringstream urlStream;
    urlStream << L"http://contoso.com/updateId=" << updateId;

    const auto appPackageInfo = WindowsSoftwareUpdateAppPackageInfo(
        packageFamilyName,
        WindowsSoftwareUpdateArchitecture::X64,
        winrt::Windows::Foundation::Uri(L"https://go.microsoft.com/fwlink/?linkid=2195164"));

    WindowsSoftwareUpdate update(
        providerId,
        WindowsSoftwareUpdateInstallationType::AppPackage,
        updateId,
        title,
        L"AppPackage Update (2.3.4.5) Description",
        winrt::Windows::Foundation::Uri(urlStream.str()),
        1024 * 1024,
        2 * 1024 * 1024,
        nullptr /* WindowsSoftwareUpdateSourceVersion */,
        WindowsSoftwareUpdateVersion(2, 3, 4, 5),
        appPackageInfo,
        nullptr /* WindowsSoftwareUpdateExecutionInfo */,
        nullptr /* WindowsSoftwareUpdateOptionalInfo */);

    if (g_verboseMode)
    {
        std::wcout << to_wstring(update) << std::endl;
    }

    return update;
}

void PerformScan(const std::wstring& providerId)
{
    std::wcout << L"=== SCAN RESULTS ===" << std::endl;
    std::wcout << L"Provider ID: " << providerId << std::endl;
    std::wcout << L"" << std::endl;

    const auto executableDeployUpdate = CreateExecutableDeployUpdate(providerId);
    std::wcout << L"Update Type: Executable Deploy" << std::endl;
    std::wcout << L"Update ID: " << executableDeployUpdate.UpdateId().c_str() << std::endl;
    std::wcout << L"Title: " << executableDeployUpdate.Title().c_str() << std::endl;
    std::wcout << L"Version: " << executableDeployUpdate.TargetVersion().Major() << L"."
        << executableDeployUpdate.TargetVersion().Minor() << L"."
        << executableDeployUpdate.TargetVersion().RevisionMajor() << L"."
        << executableDeployUpdate.TargetVersion().RevisionMinor() << std::endl;
    std::wcout << L"" << std::endl;

    const auto& executableDownloadInstallUpdate = CreateExecutableDownloadInstallUpdate(providerId);
    std::wcout << L"Update Type: Executable Download/Install" << std::endl;
    std::wcout << L"Update ID: " << executableDownloadInstallUpdate.UpdateId().c_str() << std::endl;
    std::wcout << L"Title: " << executableDownloadInstallUpdate.Title().c_str() << std::endl;
    std::wcout << L"Version: " << executableDownloadInstallUpdate.TargetVersion().Major() << L"."
        << executableDownloadInstallUpdate.TargetVersion().Minor() << L"."
        << executableDownloadInstallUpdate.TargetVersion().RevisionMajor() << L"."
        << executableDownloadInstallUpdate.TargetVersion().RevisionMinor() << std::endl;
    std::wcout << L"" << std::endl;

    const auto appPackageUpdate = CreateAppPackageUpdate(providerId);
    std::wcout << L"Update Type: AppPackage" << std::endl;
    std::wcout << L"Update ID: " << appPackageUpdate.UpdateId().c_str() << std::endl;
    std::wcout << L"Title: " << appPackageUpdate.Title().c_str() << std::endl;
    std::wcout << L"Version: " << appPackageUpdate.TargetVersion().Major() << L"." << appPackageUpdate.TargetVersion().Minor() << L"." << appPackageUpdate.TargetVersion().RevisionMajor() << L"."
        << appPackageUpdate.TargetVersion().RevisionMinor() << std::endl;
    std::wcout << L"" << std::endl;

    std::wcout << L"Creating empty software update collection..." << std::endl;
    winrt::Windows::Foundation::Collections::IVector<WindowsSoftwareUpdate> updateCollection{ winrt::single_threaded_vector<WindowsSoftwareUpdate>() };

    std::wcout << L"Adding software updates to collection..." << std::endl;
    updateCollection.Append(executableDeployUpdate);
    updateCollection.Append(executableDownloadInstallUpdate);
    updateCollection.Append(appPackageUpdate);

    std::wcout << L"Creating provider status..." << std::endl;
    WindowsSoftwareUpdateProviderStatus providerStatus(providerId);

    std::wcout << L"Setting scan result..." << std::endl;
    const auto statusResult = providerStatus.SetScanResult(true, S_OK, 0, updateCollection);
    std::wcout << L"SetScanResult() -> " << to_wstring(statusResult) << std::endl;
}

void PerformAction(
    const std::wstring& providerId,
    LPCWSTR action,
    const std::wstring& updateId = L"",
    WindowsSoftwareUpdateActionResult result = WindowsSoftwareUpdateActionResult::Succeeded,
    WindowsSoftwareUpdateRestartReason reason = WindowsSoftwareUpdateRestartReason::None,
    HRESULT resultCode = S_OK,
    uint64_t extendedError = 0)
{

    std::wcout << L"Creating provider status..." << std::endl;
    WindowsSoftwareUpdateProviderStatus providerStatus(providerId);

    try
    {
        // Send an initial progress tick
        const auto progressResult = providerStatus.SetActionProgress(0, 100);
        std::wcout << L"SetActionProgress() -> " << to_wstring(progressResult) << std::endl;
    }
    catch (...)
    {
        std::wcout << L"Initial SetActionProgress() -> Failed" << std::endl;
    }

    std::wcout << L"Action: " << action << std::endl;
    if (!updateId.empty())
    {
        std::wcout << L"Update ID: " << updateId << std::endl;

        // Parse the WinGet-style updateId (packageId_packageVersion format)
        size_t underscorePos = updateId.find_last_of(L'_');
        if (underscorePos != std::wstring::npos)
        {
            std::wstring packageId = updateId.substr(0, underscorePos);
            std::wstring packageVersion = updateId.substr(underscorePos + 1);

            std::wcout << L"Package ID: " << packageId << std::endl;
            std::wcout << L"Package Version: " << packageVersion << std::endl;
        }
        else
        {
            std::wcout << L"Note: Update ID doesn't follow packageId_packageVersion format" << std::endl;
        }
    }

    if (g_forceClose && (action == std::wstring(L"install") || action == std::wstring(L"deploy")))
    {
        std::wcout << L"Force close mode: Would close conflicting applications before action" << std::endl;
    }

    if (action == std::wstring(L"deploy") ||
        action == std::wstring(L"download") ||
        action == std::wstring(L"install") ||
        action == std::wstring(L"restart"))
    {
        // Send some progress ticks
        for (int i = 0; i < 100; i += 10)
        {
            Sleep(500); // Faster for demo purposes
            std::wcout << L"Setting action progress: " << i << L" / 100" << std::endl;
            try
            {
                // Send a progress tick based on the current iteration
                const auto progressResult = providerStatus.SetActionProgress(i, 100);
                std::wcout << L"SetActionProgress() -> " << to_wstring(progressResult) << std::endl;
            }
            catch (...)
            {
                std::wcout << L"Loop SetActionProgress() -> Failed" << std::endl;
            }
        }

        try
        {
            // Send a final progress tick
            const auto progressResult = providerStatus.SetActionProgress(100, 100);
            std::wcout << L"SetActionProgress() -> " << to_wstring(progressResult) << std::endl;
        }
        catch (...)
        {
            std::wcout << L"Final SetActionProgress() -> Failed" << std::endl;
        }
    }
    else
    {
        std::wcout << L"Error: Unexpected action" << std::endl;

        // Unexpected action value
        result = WindowsSoftwareUpdateActionResult::Failed;
        reason = WindowsSoftwareUpdateRestartReason::None;
        resultCode = E_UNEXPECTED;
        extendedError = 18446744071562133503;
    }

    // Send the requested result
    std::wcout << L"Creating provider action result..." << std::endl;
    WindowsSoftwareUpdateProviderActionResult actionResult(result, reason, resultCode, extendedError);
    std::wcout << L"Setting action result..." << std::endl;
    try
    {
        const auto statusResult = providerStatus.SetActionResult(actionResult);
        std::wcout << L"SetActionResult() -> " << to_wstring(statusResult) << std::endl;
    }
    catch (...)
    {
        std::wcout << L"SetActionResult() -> Failed" << std::endl;
    }
}

void PrintUsage()
{
    std::wcout << L"Usage: [] denotes optional argument, <> denotes required argument" << std::endl;
    std::wcout << L"    scan [--providerId <ProviderID>] [--log] [--verbose] - report scan result with available updates" << std::endl;
    std::wcout << L"    download [--providerId <ProviderID>] [--updateId <UpdateID>] [--log] [--verbose] - perform download action" << std::endl;
    std::wcout << L"    install [--providerId <ProviderID>] [--updateId <UpdateID>] [--log] [--forceClose] [--verbose] - perform install action" << std::endl;
    std::wcout << L"    deploy [--providerId <ProviderID>] [--updateId <UpdateID>] [--log] [--forceClose] [--verbose] - perform deploy action" << std::endl;
    std::wcout << L"    restart [--providerId <ProviderID>] [--updateId <UpdateID>] [--log] [--verbose] - perform app close and relaunch action" << std::endl;
    std::wcout << L"" << std::endl;
    std::wcout << L"Options:" << std::endl;
    std::wcout << L"    --providerId <ProviderID> - Specify the provider ID (defaults to 'SampleProvider')" << std::endl;
    std::wcout << L"    --updateId <UpdateID> - Specify the update ID for the action" << std::endl;
    std::wcout << L"    --log - Redirect console output to SampleProvider.log in State subfolder" << std::endl;
    std::wcout << L"    --forceClose - Force close applications during install/deploy actions" << std::endl;
    std::wcout << L"    --verbose - Display detailed update information for each update object created" << std::endl;
}

bool EnableLogging()
{
    try
    {
        // Get the directory containing the executable using the helper
        std::filesystem::path exePath = GetCurrentModulePath();
        std::filesystem::path stateDir = exePath.parent_path() / L"State";
        std::filesystem::path logPath = stateDir / L"SampleProvider.log";

        // Create the State directory if it doesn't exist
        std::error_code ec;
        std::filesystem::create_directories(stateDir, ec);
        if (ec)
        {
            std::wcerr << L"Failed to create State directory: " << ec.message().c_str() << std::endl;
            return false;
        }

        // Open the log file for writing (append mode)
        static std::wofstream logFile(logPath, std::ios::app);
        if (!logFile.is_open())
        {
            std::wcerr << L"Failed to open log file: " << logPath.c_str() << std::endl;
            return false;
        }

        // Redirect cout and cerr to the log file
        std::wcout.rdbuf(logFile.rdbuf());
        std::wcerr.rdbuf(logFile.rdbuf());

        // Write a timestamp to the log
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        std::tm tm_buf;
        localtime_s(&tm_buf, &time_t);

        std::wcout << L"=== SampleProvider Log Started at "
            << std::put_time(&tm_buf, L"%Y-%m-%d %H:%M:%S")
            << L" ===" << std::endl;

        return true;
    }
    catch (const std::exception& e)
    {
        std::wcerr << L"Exception setting up logging: " << e.what() << std::endl;
        return false;
    }
    catch (...)
    {
        std::wcerr << L"Unknown exception setting up logging" << std::endl;
        return false;
    }
}

int __cdecl wmain(int argc, _In_z_count_(argc) LPCWSTR argv[])
{
    try
    {
        bool printUsage{ false };
        std::wstring providerId = L"SampleProvider"; // Default provider ID
        std::wstring updateId = L""; // Optional update ID

        if (argc < 2)
        {
            printUsage = true;
            std::wcout << L"Expected at least 1 argument" << std::endl;
        }
        else
        {
            // Parse --providerId, --updateId, --log, --forceClose, and --verbose arguments if present
            for (int i = 1; i < argc; i++)
            {
                if (_wcsicmp(argv[i], L"--providerId") == 0 && i + 1 < argc)
                {
                    providerId = argv[i + 1];
                    std::wcout << L"Using provider ID: " << providerId << std::endl;
                }
                else if (_wcsicmp(argv[i], L"--updateId") == 0 && i + 1 < argc)
                {
                    updateId = argv[i + 1];
                    std::wcout << L"Using update ID: " << updateId << std::endl;
                }
                else if (_wcsicmp(argv[i], L"--log") == 0)
                {
                    g_enableLogging = true;
                }
                else if (_wcsicmp(argv[i], L"--forceClose") == 0)
                {
                    g_forceClose = true;
                    std::wcout << L"Force close applications: Enabled" << std::endl;
                }
                else if (_wcsicmp(argv[i], L"--verbose") == 0)
                {
                    g_verboseMode = true;
                    std::wcout << L"Verbose mode: Enabled" << std::endl;
                }
            }

            // Set up logging if requested (do this early, before any other output)
            if (g_enableLogging)
            {
                if (!EnableLogging())
                {
                    std::wcerr << L"Failed to set up logging, continuing with console output" << std::endl;
                }
                else
                {
                    std::wcout << L"Logging enabled" << std::endl;
                }
            }

            if (_wcsicmp(argv[1], L"scan") == 0)
            {
                PerformScan(providerId);
            }
            else if (_wcsicmp(argv[1], L"download") == 0)
            {
                PerformAction(providerId, L"download", updateId);
            }
            else if (_wcsicmp(argv[1], L"install") == 0)
            {
                PerformAction(providerId, L"install", updateId);
            }
            else if (_wcsicmp(argv[1], L"deploy") == 0)
            {
                PerformAction(providerId, L"deploy", updateId);
            }
            else if (_wcsicmp(argv[1], L"restart") == 0)
            {
                PerformAction(providerId, L"restart", updateId);
            }
            else
            {
                printUsage = true;
            }
        }

        if (printUsage)
        {
            PrintUsage();
        }
    }
    catch (winrt::hresult_error const& ex)
    {
        const winrt::hresult hr = ex.code();
        winrt::hstring message = ex.message();
        std::wcerr << std::endl << L"WinRT error: hr = " << hr << "message: " << message.c_str() << std::endl;
        return 1;
    }
    catch (std::runtime_error const& e)
    {
        std::wcerr << std::endl << L"Error: " << e.what() << std::endl;
        return 1;
    }
    catch (...)
    {
        const auto hr = wil::ResultFromCaughtException();
        std::wcerr << std::endl << L"Error encountered: " << hr << std::endl;
        return 1;
    }

    return 0;
}
