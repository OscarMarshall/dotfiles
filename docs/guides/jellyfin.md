# Jellyfin

Jellyfin is the main way to watch the movies and shows here — like a private Netflix. It works in a web browser and has
apps for phones, tablets, smart TVs, and streaming sticks.

**Address:** <https://jellyfin.@domain@>

## Watching in a browser

1. Go to <https://jellyfin.@domain@>.
2. Click the **authentik** sign-in button under the login form. (Don't type into the username and password boxes — your
   account doesn't have a Jellyfin password.)
3. Sign in to Authentik if asked, and you'll land on Jellyfin's home screen.

## Watching on a phone, TV, or streaming stick

The apps don't have the Authentik button, so you sign them in with **Quick Connect**: the app shows a short code, and
you approve it from a browser where you're already signed in.

1. Install a Jellyfin app — the official **Jellyfin** app is on the iOS App Store, Google Play, Android TV/Google TV,
   Fire TV, Roku, and most smart TV app stores. (Also good: **Swiftfin** on iPhone and Apple TV, and **Moonfin** on
   Android TV, which can also browse and request from [Seerr](seerr.md).)
2. When it asks for a server, enter `https://jellyfin.@domain@`.
3. Choose **Quick Connect** (instead of typing a username and password). The app shows a six-character code.
4. In a browser, sign in to Jellyfin as above, then open your profile picture (top right) → **Quick Connect**.
5. Type in the code and click **Authorize**. The app signs in on its own a moment later.

You only need to do this once per device.

## What's in the library

- **Movies** and **Shows** — the whole collection.
- Missing something? Ask for it with [Seerr](seerr.md) — it shows up here automatically once it's ready.

## Good to know

- **Skip intro** — shows with a recognizable intro get a **Skip Intro** button.
- **Subtitles** — click the speech-bubble icon while playing. If the one you need is missing, [ask](../help.md).
- **Picking up where you left off** — your progress syncs across all your devices.
- **Buffering or poor quality?** In the player settings (the gear icon), lower the **Quality** to a smaller number. This
  matters most away from home on a slow connection.
