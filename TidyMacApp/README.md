# Tidy — macOS file organizer

Tidy sorts loose files in a folder you choose into clear groups by file type. Review the plan before anything moves. Your files stay on your Mac, and you can undo your last sort while Tidy is open.

The app uses the Tidy leaf mark and visual direction shared by the Tidy family of utilities.

## Run in Xcode

1. Open `TidyMacApp.xcodeproj`.
2. Select the `TidyMacApp` scheme and `My Mac` as the run destination.
3. Press **Run**.
4. Choose a folder containing copies of files to try the workflow. Review the move plan, select **Sort**, then use **Undo** while the app remains open.

Open **Tidy → About Tidy…** in the menu bar to read the in-app description.

The app scans loose files at the top level of the folder selected in the macOS file picker. It skips hidden files and folders, groups unknown extensions under `Other`, and adds a number when a destination filename already exists. Sorting is local; the app has no network access. Undo history currently lives for the current app session only.

An Apple Developer Program membership is not required to build and run this app locally in Xcode. Membership is required for App Store distribution.
