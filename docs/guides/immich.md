# Immich

Immich backs up the photos and videos from your phone, like a private Google Photos or iCloud Photos. It can search your
photos by what's in them ("beach", "dog", "birthday cake"), recognizes faces, and makes it easy to share albums.

**Address:** <https://immich.@domain@>

## In a browser

Go to <https://immich.@domain@>. You're sent to Authentik to sign in, then straight back to your photos.

## On your phone

1. Install **Immich** from the iOS App Store or Google Play.
2. For the **Server Endpoint URL**, enter `https://immich.@domain@` and tap **Next**.
3. Tap **Login with OAuth** (not the email and password boxes — there aren't any passwords here). Sign in to Authentik
   when it opens.
4. Allow Immich to access your photos when asked. Choose **Allow Full Access** / **All Photos** so it can back up
   everything.

### Turn on automatic backup

1. Tap the **cloud icon** (top right).
2. Under **Backup Albums**, pick what to back up — usually **Recents** (iPhone) or **Camera** (Android).
3. Turn on **Enable Backup**.

Your phone uploads everything in those albums, then keeps backing up new photos whenever the app runs.

!!! tip "Keep backups running in the background"

    On the backup screen, turn on **background backup** and, on iPhone, allow **Background App Refresh** for Immich in
    the iPhone Settings app. Phones limit what apps can do in the background, so opening Immich now and then helps it
    catch up.

!!! warning "Deleting photos"

    Immich is a backup, but deleting a photo **in Immich** deletes it from the server too — and, if you allow it,
    from your phone. To free up space on your phone, use **Free Up Space** in the app, which only removes photos that
    are safely backed up.

## Sharing

- **Share an album with someone else here:** open the album → **Share** → choose people.
- **Share with anyone** (no account needed): select photos or an album → **Share** → **Create link**. You can set an
  expiry date and a password.
- **Partner sharing:** in **Account Settings → Partner Sharing**, you can let a partner see your whole library in their
  timeline.
