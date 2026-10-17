#!/usr/bin/env bash
# Applies LabLedger's Android settings on top of the files `flutter create`
# generates in CI: app name, permissions and launcher icons.
set -euo pipefail

MANIFEST=android/app/src/main/AndroidManifest.xml

if ! grep -q "ACCESS_FINE_LOCATION" "$MANIFEST"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n    <uses-permission android:name="android.permission.VIBRATE"/>\n    <application#' "$MANIFEST"
fi

# App name shown under the icon
sed -i 's#android:label="[^"]*"#android:label="LabLedger"#' "$MANIFEST"

# Give every plugin project a compileSdkVersion. Some plugins (geolocator)
# read flutter.compileSdkVersion, which is null for plugins on Flutter 3.24,
# so AGP fails with "compileSdkVersion is not specified". The hook must be
# registered before `evaluationDependsOn(":app")` evaluates the plugins.
ROOT_GRADLE=android/build.gradle
if [ -f "$ROOT_GRADLE" ] && ! grep -q "TERRAPLOT_SDK_FIX" "$ROOT_GRADLE"; then
  python3 - "$ROOT_GRADLE" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
fix = '''// TERRAPLOT_SDK_FIX
subprojects { sp ->
    // Newer plugins read `flutter.compileSdkVersion` etc., which Flutter 3.24
    // only defines for the app module. Give plugin modules the same values.
    if (sp.name != "app" && !sp.hasProperty("flutter")) {
        sp.ext.flutter = [
            compileSdkVersion: 34,
            targetSdkVersion : 34,
            minSdkVersion    : 21,
            ndkVersion       : "23.1.7779620",
        ]
    }
    afterEvaluate { p ->
        if (p.hasProperty("android")) {
            p.android {
                if (compileSdkVersion == null) {
                    compileSdkVersion 34
                }
            }
        }
    }
}

'''
marker = "subprojects {\n    project.evaluationDependsOn"
i = src.find(marker)
if i < 0:
    i = src.find("subprojects")
src = src[:i] + fix + src[i:] if i >= 0 else src + "\n" + fix
open(path, "w").write(src)
PY
fi
echo "Root build.gradle:"
cat "$ROOT_GRADLE" || true

# Launcher icons
cp -r android_overrides/res/. android/app/src/main/res/

echo "Patched manifest:"
cat "$MANIFEST"
