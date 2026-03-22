Local notification summary: 


Implementation Details
## Initialization:
- Initialize notifications and time zones in the main function during app startup.
- Use tz.initializeTimeZones() from the timezone package to support local device time zones.

## Scheduling Method:
- Create a method accepting:
      = Title (String)
      = Body (String)
      = Hour (0≤h≤23)
      = Minute (0≤m≤59)
- Retrieve the current local date and time on the device using timezone-aware datetime.
- Construct a TZDateTime object for the scheduled notification using the current year, month, day, and specified hour and minute.

## Notification Scheduling:
- Use the plugin's schedule method with:
      = Notification details (title, body, etc.)
      = TZDateTime for the scheduled time
      = iOS-specific options like absoluteTime scheduling.
      = Android-specific options, including allowing notifications during low power mode.
- Option to set recurring daily notifications by matching time components (e.g., hour and minute).

## Additional Features:
- Ability to cancel all scheduled notifications if needed.
- Print debug statements to confirm scheduling execution.

## UI Setup: (simple setup for tutorial purpose)
- Two buttons on the home screen:
      = One to show an immediate notification.
      = One to schedule a notification at a user-specified time.
- Example scheduling done at 11:00 PM (23:00) or a few minutes later for demonstration.

## Testing and Behavior
After adding new packages, the app requires a full restart:
Commands: flutter clean → flutter run to rebuild and link dependencies.
On iOS, pod install runs automatically to integrate packages.
The scheduled notification triggers on time, including when the app is in the background or closed.
Simulator system time can be adjusted to test notifications at different times.
Demonstrated scheduling a notification 2 minutes after current time and successfully received alert.

