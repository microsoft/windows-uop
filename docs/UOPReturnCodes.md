# UOP Return Codes

## Provider Error Codes (0x8024A300+)

| Hex | Decimal | Symbol | Description |
|-----|---------|--------|-------------|
| 0x8024A300 | -2145082624 | UO_E_PROVIDER_ALREADY_REGISTERED | Update provider is already registered. |
| 0x8024A301 | -2145082623 | UO_E_PROVIDER_VALIDATION_FAILED | Update provider validation failed. |
| 0x8024A302 | -2145082622 | UO_E_PROVIDER_NOT_REGISTERED | Update provider is not registered. |
| 0x8024A303 | -2145082621 | UO_E_PROVIDER_REGISTRATION_FAILED | Update provider registration failed. |
| 0x8024A304 | -2145082620 | UO_E_PROVIDER_UNREGISTRATION_FAILED | Update provider unregistration failed. |
| 0x8024A305 | -2145082619 | UO_E_PROVIDER_OPERATION_NOT_SUPPORTED | Operation not supported for inbox providers. |
| 0x8024A306 | -2145082618 | UO_E_PROVIDER_STATUS_NOT_SUPPORTED | Provider status calls are not supported. |
| 0x8024A307 | -2145082617 | UO_E_PROVIDER_REGISTRATION_TYPE_INVALID | Registration type is invalid. |
| 0x8024A308 | -2145082616 | UO_E_PROVIDER_TYPE_INVALID | Provider specified an invalid type. |
| 0x8024A309 | -2145082615 | UO_E_PROVIDER_INSTALLATION_TYPE_INVALID | Installation type is not valid. |
| 0x8024A30A | -2145082614 | UO_E_PROVIDER_TRUST_STATE_INVALID | Provider has an invalid trust state. |
| 0x8024A30B | -2145082613 | UO_E_PROVIDER_FOLDER_PATH_NOT_FOUND | Provider folder path not found. |
| 0x8024A30C | -2145082612 | UO_E_PROVIDER_SCAN_EXE_FILE_NOT_FOUND | Provider scan executable file not found. |
| 0x8024A30D | -2145082611 | UO_E_PROVIDER_VALIDATION_ID_MISSING | Validation failed: missing provider ID. |
| 0x8024A30E | -2145082610 | UO_E_PROVIDER_VALIDATION_NAME_MISSING | Validation failed: missing provider name. |
| 0x8024A30F | -2145082609 | UO_E_PROVIDER_VALIDATION_VERSION_MISSING | Validation failed: missing registration version. |
| 0x8024A310 | -2145082608 | UO_E_PROVIDER_VALIDATION_TYPE_MISSING | Validation failed: missing provider type. |
| 0x8024A311 | -2145082607 | UO_E_PROVIDER_VALIDATION_CATALOG_FILE_MISSING | Validation failed: missing catalog file. |
| 0x8024A312 | -2145082606 | UO_E_PROVIDER_VALIDATION_SCAN_FILE_MISSING | Validation failed: missing scan file. |
| 0x8024A313 | -2145082605 | UO_E_PROVIDER_VALIDATION_SCAN_FILE_ARGUMENTS_MISSING | Validation failed: missing scan file arguments. |
| 0x8024A314 | -2145082604 | UO_E_PROVIDER_VALIDATION_PAYLOAD_FILES_MISSING | Validation failed: missing payload files. |
| 0x8024A315 | -2145082603 | UO_E_PROVIDER_VALIDATION_PAYLOADFILE_HASH_MISMATCH | Validation failed: payload file hash mismatch. |
| 0x8024A316 | -2145082602 | UO_E_PROVIDER_SCANRESULT_MISSING | Scan result is missing. |
| 0x8024A317 | -2145082601 | UO_E_PROVIDER_SCANRESULT_ALREADY_EXISTS | Scan result already exists. |
| 0x8024A318 | -2145082600 | UO_E_PROVIDER_SCANRESULT_RESULT_INVALID | Scan result has invalid result data. |
| 0x8024A319 | -2145082599 | UO_E_PROVIDER_SCANRESULT_UPDATE_INVALID | Scan result has an invalid update. |
| 0x8024A31A | -2145082598 | UO_E_PROVIDER_SCANRESULT_DUPLICATE_UPDATEID | Scan result has a duplicate update. |
| 0x8024A31B | -2145082597 | UO_E_PROVIDER_ACTIONRESULT_MISSING | Action completed without a result. |
| 0x8024A31C | -2145082596 | UO_E_PROVIDER_ACTIONRESULT_ALREADY_EXISTS | Action result already exists. |
| 0x8024A31D | -2145082595 | UO_E_PROVIDER_ACTIONRESULT_INVALID | Action result is invalid. |
| 0x8024A31E | -2145082594 | UO_E_PROVIDER_ACTIONPROGRESS_INVALID | Action progress data is invalid. |
| 0x8024A31F | -2145082593 | UO_E_PROVIDER_ACTION_FILE_INFO_MISSING | Action file information is missing. |
| 0x8024A320 | -2145082592 | UO_E_PROVIDER_ACTION_FILE_NOT_FOUND | Action file not found. |
| 0x8024A321 | -2145082591 | UO_E_PROVIDER_ACTION_TYPE_INVALID | Invalid action type. |
| 0x8024A322 | -2145082590 | UO_E_PROVIDER_UNSUPPORTED_RESTART_REASON | Unsupported or unrecognized restart reason. |
| 0x8024A323 | -2145082589 | UO_E_PROVIDER_DOWNLOAD_RESTART_NOT_SUPPORTED | Restart requested during download (not supported). |
| 0x8024A324 | -2145082588 | UO_E_PROVIDER_ACTIONRESULT_RESTART_REASON_INVALID | Invalid restart reason for ActionResult. |
| 0x8024A325 | -2145082587 | UO_E_PROVIDER_ACTIONRESULT_RESTART_COMBINATION_INVALID | Invalid ActionResult/RestartReason combination. |
| 0x8024A326 | -2145082586 | UO_E_PROVIDER_ACTIONRESULT_VALUE_INVALID | Invalid/Unexpected ActionResult enum value. |
| 0x8024A327 | -2145082585 | UO_E_PROVIDER_RESTARTREASON_VALUE_INVALID | Invalid/Unexpected RestartReason enum value. |
| 0x8024A328 | -2145082584 | UO_E_PROVIDER_ACTIONRESULT_SUCCESS_HRESULT_MISMATCH | Inconsistent success vs HRESULT values. |
| 0x8024A32A | -2145082582 | UO_E_PROVIDER_VALIDATION_INVALID_CATALOG | Catalog not signed or hash mismatch. |
| 0x8024A32B | -2145082581 | UO_E_PROVIDER_VALIDATION_INVALID_VERSION | Validation failed: invalid version. |
| 0x8024A32C | -2145082580 | UO_E_PROVIDER_VALIDATION_INVALID_TYPE | Validation failed: invalid type. |
| 0x8024A32D | -2145082579 | UO_E_PROVIDER_VALIDATION_CATALOG_CERT_UNTRUSTED | Catalog signing certificate not in trusted root. |
| 0x8024A32E | -2145082578 | UO_E_PROVIDER_VALIDATION_SCAN_FREQUENCY_INVALID | Validation failed: invalid scan frequency. |
| 0x8024A32F | -2145082577 | UO_E_PROVIDER_VALIDATION_SCAN_FREQUENCY_OUT_OF_RANGE | Validation failed: scan frequency out of range. |
| 0x8024A330 | -2145082576 | UO_E_PROVIDER_VALIDATION_MIGRATE_STATE_INVALID | Validation failed: invalid migrate state. |
| 0x8024A331 | -2145082575 | UO_E_PROVIDER_VALIDATION_ID_EXCEEDS_MAX_LENGTH | Validation failed: ID exceeds maximum length. |
| 0x8024A332 | -2145082574 | UO_E_PROVIDER_VALIDATION_VERSION_INVALID | Validation failed: invalid version. |
| 0x8024A333 | -2145082573 | UO_E_PROVIDER_VALIDATION_TYPE_INVALID | Validation failed: invalid type. |

## Selected USO Error Codes (0x8024A235 - 0x8024A23B)

| Hex | Decimal | Symbol | Description |
|-----|---------|--------|-------------|
| 0x8024A235 | -2145082827 | USO_E_ACTION_BLOCKED_BY_EXTERNAL_POLICY | Update action blocked due to an external policy. |
| 0x8024A238 | -2145082824 | USO_E_PROVIDER_NOT_FOUND | An expected provider was not found. |
| 0x8024A239 | -2145082823 | USO_E_INSUFFICIENT_PRIVILEGES | System or administrator privileges are required to perform this operation. |
| 0x8024A23A | -2145082822 | USO_E_UPDATE_MANAGER_NOT_INITIALIZED | Update manager is not initialized. |
| 0x8024A23B | -2145082821 | USO_E_MALFORMED_JSON | JSON is malformed. |