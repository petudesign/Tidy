# Tidy

Tidy sorts loose files in a folder you choose into clear groups by file type. Review the plan before anything moves. Your files stay on your Mac, and you can undo your last sort while Tidy is open.

## What it does

- Scans loose files at the top level of a folder you select.
- Groups them into Images, Installers, Documents, Archives, and Other.
- Shows the destination folders before you start sorting.
- Keeps hidden files and subfolders where they are.
- Renames a conflicting destination file with a number instead of overwriting it.
- Supports undo for the latest sort while the app remains open.
- Works locally and does not connect to a server.

## Run from Xcode

1. Open [`TidyMacApp/TidyMacApp.xcodeproj`](TidyMacApp/TidyMacApp.xcodeproj).
2. Select the `TidyMacApp` scheme and **My Mac** as the run destination.
3. Press **Run**.
4. Choose a folder with copies of files to try the workflow. Review the move plan before selecting **Sort**.

The in-app description is available from **Tidy → About Tidy…**.

An Apple Developer Program membership is not needed to build and run Tidy locally. It is needed for App Store distribution.

## Notes

Undo history currently lasts for the current app session. The app only processes top-level loose files in the selected folder; it does not scan nested folders.
