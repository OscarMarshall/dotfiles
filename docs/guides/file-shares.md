# File shares

When you're **on the home network**, you can browse the server's media folders directly from your computer, as if they
were a network drive. This is handy for copying a movie or album to a laptop before a trip.

- No sign-in needed — connect as a **guest**.
- Everything is **read-only**: you can open and copy files, but not change or delete them.
- This doesn't work away from home. Use [Nextcloud](nextcloud.md) for files you need everywhere.

## Shares

--8<-- "samba-shares.md"

## Connecting

=== "Windows"

    1. Open **File Explorer**.
    2. Type `\\@host@` into the address bar and press **Enter**. (It may also appear by itself under **Network** in
       the sidebar.)
    3. If asked for a username and password, type `guest` as the username and leave the password empty.
    4. To keep a share handy, right-click it and choose **Map network drive**.

=== "macOS"

    1. In **Finder**, choose **Go → Connect to Server…** (⌘K).
    2. Enter `smb://@lan-ip@` and click **Connect**.
    3. Choose **Guest** and click **Connect**, then pick a share.

=== "Linux"

    In your file manager, open **Other Locations** (GNOME) or **Network** and enter `smb://@lan-ip@`. Choose
    **Anonymous** / **Guest** when asked.
