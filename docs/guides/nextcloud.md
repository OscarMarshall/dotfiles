# Nextcloud

Nextcloud is private file storage, like Dropbox or Google Drive. It keeps your files in sync between your computer and
phone, lets you share them with a link, and can open Word, Excel, and PowerPoint files right in the browser.

**Address:** <https://nextcloud.@domain@>

!!! note "Looking for your photos?"

    Photos belong in [Immich](immich.md), which is much better at them. Nextcloud's own Photos app is turned off.

## In a browser

Go to <https://nextcloud.@domain@>. You're sent to Authentik to sign in, then back to your files.

## On your computer

1. Download the **Nextcloud Desktop** app from [nextcloud.com/install](https://nextcloud.com/install/#install-clients)
   (Windows, macOS, Linux).
2. Open it and choose **Log in**. For the server address, enter `https://nextcloud.@domain@`.
3. Your browser opens. Sign in to Authentik, then click **Grant access**.
4. Choose which folders to sync. The app makes a **Nextcloud** folder on your computer — anything you put in it is
   uploaded, and changes from your other devices show up there.

!!! tip "Save disk space with virtual files"

    On Windows and macOS, turn on **virtual files** in the app's settings. Your files show up in the Nextcloud folder
    but only download when you open them.

## On your phone

1. Install **Nextcloud** from the iOS App Store or Google Play.
2. Tap **Log in** and enter `https://nextcloud.@domain@`.
3. Sign in to Authentik in the page that opens, then tap **Grant access**.

The app lets you browse, upload, and share files, and make files available offline.

## Editing documents

Click any Word (`.docx`), Excel (`.xlsx`), or PowerPoint (`.pptx`) file — or an OpenDocument file — and it opens in
**Nextcloud Office** right in your browser. To start a new one, click **+ New** and choose **New document**, **New
spreadsheet**, or **New presentation**.

Several people can edit the same document at once; you'll see each other's cursors.

## Sharing

- **With someone who has an account here:** click the **share icon** next to a file or folder and type their name.
- **With anyone:** click the **share icon** → **+** next to **Share link**. Anyone with the link can view (or, if you
  allow it, edit or upload). Under the link's **⋯** menu you can set a password and an expiry date.
