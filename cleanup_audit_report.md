# StartSmart Codebase Cleanup Audit Report

**Date**: December 19, 2024  
**Branch**: cleanup/remove-legacy-code  
**Phase**: 2 - Legacy UserNotifications Code Identification

## Executive Summary

After the AlarmKit migration, several legacy UserNotifications-based services and files are no longer needed and should be removed to clean up the codebase.

## Baseline Metrics (Before Cleanup)

- **Total Swift Files**: 5,518 files (including dependencies)
- **App Swift Files**: 85 files in StartSmart/ directory
- **Test Files**: 37 files in StartSmartTests/ directory
- **Total Lines of Code**: 32,847 (app) + 15,069 (tests) = 47,916 lines

## Files with Alarm-Related Notification Code (DELETE)

### 1. NotificationService.swift
- **Purpose**: Old alarm scheduling using UNUserNotificationCenter
- **Status**: DELETE ENTIRE FILE
- **Reason**: Replaced by AlarmKitManager
- **Lines**: 217 lines
- **Dependencies**: Used by DependencyContainer (but commented out)

### 2. NotificationCategoryService.swift  
- **Purpose**: Custom notification categories and actions for alarms
- **Status**: DELETE ENTIRE FILE
- **Reason**: AlarmKit handles notification categories natively
- **Lines**: 362 lines
- **Dependencies**: Used by StartSmartApp.swift

### 3. AlarmSchedulingService.swift
- **Purpose**: Legacy alarm scheduling service using UserNotifications
- **Status**: DELETE ENTIRE FILE  
- **Reason**: Replaced by AlarmKitManager
- **Lines**: 619 lines
- **Dependencies**: Used by AlarmRepository (but set to nil)

## Files with Non-Alarm Notification Code (KEEP)

### 1. StartSmartApp.swift
- **Purpose**: App initialization and notification category setup
- **Status**: REFACTOR - Remove notification category setup
- **Reason**: AlarmKit handles categories automatically
- **Lines to Remove**: ~10 lines (notification category setup)

### 2. PermissionPrimingView.swift
- **Purpose**: Onboarding permission requests
- **Status**: REFACTOR - Update to use AlarmKit permissions
- **Reason**: Still needed for onboarding flow
- **Lines to Update**: ~20 lines (permission request logic)

### 3. OnboardingFlowView.swift
- **Purpose**: Onboarding flow with permission requests
- **Status**: REFACTOR - Update permission logic
- **Reason**: Still needed for onboarding
- **Lines to Update**: ~15 lines

### 4. Models/OnboardingFlowView.swift
- **Purpose**: Onboarding state management
- **Status**: REFACTOR - Update permission logic
- **Reason**: Still needed for onboarding
- **Lines to Update**: ~10 lines

## Files with Alarm Model Updates (REFACTOR)

### 1. Models/Alarm.swift
- **Purpose**: Alarm data model with notification sound properties
- **Status**: REFACTOR - Remove UNNotificationSound properties
- **Reason**: AlarmKit handles sounds differently
- **Lines to Remove**: ~10 lines (systemSound property)

## Import Statements to Remove

### Files with unused UserNotifications imports:
1. **StartSmart/Services/NotificationService.swift** - DELETE FILE
2. **StartSmart/Services/AlarmSchedulingService.swift** - DELETE FILE  
3. **StartSmart/Services/NotificationCategoryService.swift** - DELETE FILE
4. **StartSmart/Models/Alarm.swift** - Remove UserNotifications import
5. **StartSmart/StartSmartApp.swift** - Remove UserNotifications import
6. **StartSmart/Views/Onboarding/PermissionPrimingView.swift** - Update to AlarmKit

## Dependencies to Clean Up

### 1. DependencyContainer.swift
- **Current**: NotificationService commented out, AlarmSchedulingService set to nil
- **Action**: Remove all references to deleted services
- **Lines to Remove**: ~5 lines

### 2. AlarmRepository.swift
- **Current**: schedulingService parameter set to nil
- **Action**: Remove schedulingService parameter entirely
- **Lines to Remove**: ~10 lines

## Estimated Cleanup Impact

### Files to Delete:
- NotificationService.swift (217 lines)
- NotificationCategoryService.swift (362 lines)  
- AlarmSchedulingService.swift (619 lines)
- **Total Deletion**: 1,198 lines

### Files to Refactor:
- StartSmartApp.swift (~10 lines)
- PermissionPrimingView.swift (~20 lines)
- OnboardingFlowView.swift (~15 lines)
- Models/OnboardingFlowView.swift (~10 lines)
- Models/Alarm.swift (~10 lines)
- DependencyContainer.swift (~5 lines)
- AlarmRepository.swift (~10 lines)
- **Total Refactor**: ~80 lines

### Net Reduction: ~1,278 lines of code

## Risk Assessment

### Low Risk (Safe to Delete):
- NotificationService.swift - No active references
- NotificationCategoryService.swift - Only used in StartSmartApp.swift
- AlarmSchedulingService.swift - Set to nil in DependencyContainer

### Medium Risk (Requires Careful Refactoring):
- Permission request flows in onboarding
- Alarm model sound properties

### High Risk (Requires Testing):
- StartSmartApp.swift notification setup removal
- DependencyContainer service registration cleanup

## Next Steps

1. **Phase 2 Complete**: Delete the 3 identified service files
2. **Phase 3**: Remove unused imports and refactor remaining files
3. **Phase 4**: Update onboarding permission flows
4. **Phase 5**: Test all functionality after cleanup

## Success Criteria

- [ ] All 3 service files deleted
- [ ] No compilation errors
- [ ] All tests pass
- [ ] Onboarding flow works correctly
- [ ] Alarm creation/management works correctly
- [ ] No UserNotifications imports remain in alarm-related code
