#!/bin/bash

# -------------------------------------------------------------------
# Script to build the release version of the app and create a DMG.
# -------------------------------------------------------------------

# --- Configuration ---
APP_NAME="mousezoom"
PROJECT_NAME="mousezoom"
CONFIGURATION="Release"
# Dynamically find the build directory
BUILD_DIR=$(xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${APP_NAME}" -showBuildSettings -configuration "${CONFIGURATION}" | grep -m 1 "BUILT_PRODUCTS_DIR" | awk '{print $3}')
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_STAGING_DIR="./dmg_staging"
DMG_NAME="moumou.dmg"

# --- Functions ---
function print_info() {
    echo "ℹ️  $1"
}

function print_success() {
    echo "✅ $1"
}

function print_error() {
    echo "❌ $1" >&2
    exit 1
}

# --- Main Script ---

# 1. Clean previous build and DMG
print_info "Cleaning previous builds and artifacts..."
rm -f "./${DMG_NAME}"
rm -rf "${DMG_STAGING_DIR}"
xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration "${CONFIGURATION}" clean || print_error "Clean failed."

# 2. Build the Release version of the app
print_info "Building the Release version of '${APP_NAME}'..."
xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration "${CONFIGURATION}" build || print_error "xcodebuild failed."

print_success "Build successful. App is located at: ${APP_PATH}"

# 3. Create staging directory
print_info "Creating DMG staging directory at '${DMG_STAGING_DIR}'..."
mkdir -p "${DMG_STAGING_DIR}"

# 4. Copy the .app to the staging directory
print_info "Copying .app to staging directory..."
cp -R "${APP_PATH}" "${DMG_STAGING_DIR}/" || print_error "Failed to copy .app to staging directory."

# 5. Create a symbolic link to the /Applications folder
print_info "Creating a symbolic link to /Applications..."
ln -s /Applications "${DMG_STAGING_DIR}/Applications"

# 6. Create the DMG file
print_info "Creating DMG file: '${DMG_NAME}'..."
hdiutil create -volname "mou mou" -srcfolder "${DMG_STAGING_DIR}" -ov -format UDBZ "${DMG_NAME}" || print_error "hdiutil failed to create DMG."

# 7. Clean up staging directory
print_info "Cleaning up staging directory..."
rm -rf "${DMG_STAGING_DIR}"

print_success "Successfully created '${DMG_NAME}'!"
