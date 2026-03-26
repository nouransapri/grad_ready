# GradReady: deploy Firestore rules + indexes (and optionally functions).
# Requires: npm i -g firebase-tools, firebase login, project selected (firebase use).
Set-Location $PSScriptRoot\..
firebase deploy --only firestore:rules,firestore:indexes
# Uncomment to deploy Cloud Functions as well:
# firebase deploy --only functions
