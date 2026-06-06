# iOS TestFlight Setup

Use this checklist to upload Downsview SDA to TestFlight from Codemagic.

## Apple Developer

1. Enroll or sign in to the Apple Developer Program.
2. In Certificates, Identifiers & Profiles, create an App ID:
   - Bundle ID: `org.downsviewsda.downsviewSda`
   - Capabilities: Push Notifications
3. In App Store Connect, create the app:
   - Name: `Downsview SDA`
   - Bundle ID: `org.downsviewsda.downsviewSda`
   - SKU: any stable internal value, for example `downsview-sda-ios`
4. Add internal testers in App Store Connect > Users and Access.

## Firebase

1. Add an iOS app to the `downsviewapp` Firebase project.
2. Use bundle ID `org.downsviewsda.downsviewSda`.
3. Download `GoogleService-Info.plist`.
4. Add it to `ios/Runner/GoogleService-Info.plist` before building.
5. In Firebase Cloud Messaging, configure APNs for the Apple team.

## Codemagic

1. Keep the `app_config` environment group with:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
2. Add iOS code signing in Codemagic for bundle ID `org.downsviewsda.downsviewSda`.
3. Run the `iOS Signed IPA` workflow.
4. Upload the generated IPA to App Store Connect.

## TestFlight

1. Wait for App Store Connect to finish processing the build.
2. Add the build to an internal testing group.
3. Install the TestFlight app on a real iPhone.
4. Accept the invite and install Downsview SDA.
5. Grant notification permission and confirm the device appears in Supabase.
6. Send a test push notification from the dashboard.

External testing for members and visitors requires Apple Beta App Review.
