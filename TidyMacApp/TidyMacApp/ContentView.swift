import SwiftUI

struct ContentView: View {
    @StateObject private var model = OrganizerModel()

    private var primaryTitle: String {
        if model.isScanning { return "Checking folder…" }
        if model.isSorting { return "Sorting files…" }
        if model.isComplete { return "All sorted — \(model.completedBatch?.records.count ?? 0) files" }
        if model.folderURL == nil { return "Choose Downloads folder" }
        if model.files.isEmpty { return "Nothing to sort" }
        return "Sort \(model.files.count) files"
    }

    private var primaryDisabled: Bool {
        model.isScanning || model.isSorting || model.isUndoing || (model.folderURL != nil && model.files.isEmpty) || model.isComplete
    }

    var body: some View {
        ZStack {
            TidyStyle.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    hero.padding(.bottom, 25)
                    HStack(alignment: .center, spacing: 22) {
                        SourcePanel(model: model).frame(maxWidth: .infinity, maxHeight: .infinity)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 25, weight: .regular))
                            .foregroundStyle(Color(hex: 0x989990))
                            .accessibilityHidden(true)
                        MovePlanPanel(model: model).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: 1360)
                    .frame(minHeight: 500)
                    footer.frame(maxWidth: 1360).padding(.top, 12)
                }
                .padding(.horizontal, 30)
                .padding(.top, 18)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 1040, minHeight: 760)
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Please try again.")
        }
    }

    private var hero: some View {
        VStack(spacing: 15) {
            HStack(spacing: 17) {
                Image("TidyLeaf")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 9, y: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tidy")
                        .font(.system(size: 31, weight: .bold))
                        .tracking(-1.1)
                        .foregroundStyle(TidyStyle.ink)
                    Text("Tame your Downloads folder in seconds.")
                        .font(.system(size: 14))
                        .foregroundStyle(TidyStyle.muted)
                }
            }

            Button {
                if model.folderURL == nil { model.chooseFolder() }
                else { model.sortFiles() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.isComplete ? "checkmark" : "arrow.right")
                        .font(.system(size: 17, weight: .bold))
                    Text(primaryTitle).font(.system(size: 15, weight: .semibold))
                }
                .frame(width: 290, height: 48)
                .foregroundStyle(.white)
                .background(model.isComplete ? Color(hex: 0x466E43) : TidyStyle.green, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(hex: 0x507448), lineWidth: 1) }
                .shadow(color: TidyStyle.green.opacity(0.15), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(primaryDisabled)
            .opacity(primaryDisabled && !model.isComplete ? 0.72 : 1)
            .accessibilityHint(model.folderURL == nil ? "Opens a folder picker. No files move until you choose Sort." : "Shows a preview before moving files into folders.")

            Label(
                model.isComplete ? "Everything stays on this Mac. Undo is available." : "Review the plan first. Nothing moves until you sort.",
                systemImage: model.isComplete ? "checkmark.circle.fill" : "info.circle.fill"
            )
            .font(.system(size: 11.5))
            .foregroundStyle(TidyStyle.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            Label(model.folderName, systemImage: "folder").lineLimit(1)
            Spacer()
            Text(model.isComplete ? "Undo returns files to their original locations." : "Folders and hidden files stay where they are.")
                .lineLimit(1)
        }
        .font(.system(size: 11))
        .foregroundStyle(Color(hex: 0x85867F))
    }
}

private struct SourcePanel: View {
    @ObservedObject var model: OrganizerModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.folderName)
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(TidyStyle.ink)
                    Text(sourceSubtitle).font(.system(size: 13)).foregroundStyle(TidyStyle.muted)
                }
                Spacer(minLength: 8)
                Button { model.chooseFolder() } label: {
                    Label(model.folderURL == nil ? "Choose folder" : "Change", systemImage: "folder")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TidyStyle.muted)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(TidyStyle.paperSoft, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Choose a folder to organize")
                Text("SOURCE")
                    .font(.system(size: 9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(Color(hex: 0x85867D))
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(Color(hex: 0xF4F3EE), in: RoundedRectangle(cornerRadius: 5))
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 13)

            if model.isScanning {
                ProgressView("Looking through this folder…")
                    .font(.system(size: 12)).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.folderURL == nil {
                EmptyPanelState(symbol: "folder.badge.questionmark", title: "Choose a folder to start", message: "Tidy will preview loose files before moving anything.")
            } else if model.files.isEmpty {
                EmptyPanelState(
                    symbol: model.isComplete ? "checkmark.circle" : "sparkles",
                    title: model.isComplete ? "All clear" : "Nothing to sort",
                    message: model.isComplete ? "The loose files are now in their folders." : "This folder has no loose files to organize."
                )
            } else {
                VStack(spacing: 0) {
                    FileTableHeader()
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.files) { file in FileRow(file: file) }
                        }
                    }
                }
                .padding(.horizontal, 15).padding(.bottom, 14)
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color(hex: 0xE8E6DF), lineWidth: 1) }
    }

    private var sourceSubtitle: String {
        if model.folderURL == nil { return "Choose a folder to preview" }
        if model.isComplete { return "0 loose files left" }
        if model.isScanning { return "Scanning folder" }
        return "\(model.files.count) loose files"
    }
}

private struct MovePlanPanel: View {
    @ObservedObject var model: OrganizerModel

    private var visibleGroups: [FolderGroup] { model.isComplete ? model.completedGroups : model.groups }
    private var itemCount: Int { model.isComplete ? (model.completedBatch?.records.count ?? 0) : model.files.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.isComplete ? "Sorted" : "Move plan")
                        .font(.system(size: 20, weight: .semibold)).tracking(-0.4).foregroundStyle(TidyStyle.ink)
                    Text(planSubtitle).font(.system(size: 13)).foregroundStyle(TidyStyle.muted)
                }
                Spacer(minLength: 4)
                Text(model.isComplete ? "COMPLETE" : "PREVIEW")
                    .font(.system(size: 9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(model.isComplete ? TidyStyle.greenDark : Color(hex: 0x85867D))
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(model.isComplete ? TidyStyle.greenWash : Color(hex: 0xF4F3EE), in: RoundedRectangle(cornerRadius: 5))
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 13)

            if visibleGroups.isEmpty {
                EmptyPanelState(symbol: "tray.2", title: "Your move plan will show here", message: "Files are grouped by type. Unknown types go into Other.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleGroups) { group in
                            FolderGroupRow(
                                group: group,
                                expanded: model.expandedCategories.contains(group.category),
                                onToggle: { model.toggle(group.category) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 15).padding(.bottom, model.isComplete ? 8 : 14)
            }

            if model.isComplete {
                SuccessBar(model: model).padding(.horizontal, 14).padding(.bottom, 14)
            } else {
                Label("Review your new folders before sorting.", systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(TidyStyle.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).frame(height: 45)
                    .background(TidyStyle.paperSoft, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 14).padding(.bottom, 14)
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(model.isComplete ? Color(hex: 0xD4E2CE) : Color(hex: 0xE8E6DF), lineWidth: 1)
        }
    }

    private var planSubtitle: String {
        if model.folderURL == nil { return "Waiting for a folder" }
        if model.isScanning { return "Checking file types…" }
        return "\(itemCount) files → \(visibleGroups.count) folders"
    }
}

private struct FileTableHeader: View {
    var body: some View {
        HStack {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Size").frame(width: 68, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium)).foregroundStyle(TidyStyle.muted)
        .padding(.horizontal, 12).frame(height: 30).background(TidyStyle.paperSoft)
        .overlay(alignment: .bottom) { TidyStyle.line.frame(height: 1) }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct FileRow: View {
    let file: OrganizableFile

    var body: some View {
        HStack(spacing: 9) {
            FileThumbnail(url: file.url, category: file.category).frame(width: 25, height: 25)
            Text(file.name)
                .font(.system(size: 12.5)).foregroundStyle(Color(hex: 0x30312E))
                .lineLimit(1).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading)
            Text(file.formattedSize)
                .font(.system(size: 11.5)).foregroundStyle(TidyStyle.muted).monospacedDigit()
                .frame(width: 68, alignment: .trailing)
        }
        .padding(.horizontal, 8).frame(height: 39)
        .overlay(alignment: .bottom) { TidyStyle.line.opacity(0.62).frame(height: 1) }
        .help(file.url.path)
    }
}

private struct FolderGroupRow: View {
    let group: FolderGroup
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 9) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(Color(hex: 0x65675F)).frame(width: 12)
                    Image(systemName: group.category.symbol)
                        .font(.system(size: 17, weight: .semibold)).symbolRenderingMode(.palette)
                        .foregroundStyle(TidyStyle.folderBlue, TidyStyle.folderBlue.opacity(0.7)).frame(width: 31, height: 29)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.category.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(TidyStyle.ink)
                        Text("\(group.files.count) \(group.files.count == 1 ? "file" : "files")")
                            .font(.system(size: 10.5)).foregroundStyle(Color(hex: 0x85867F))
                    }
                    Spacer(minLength: 4)
                    Text(group.formattedSize).font(.system(size: 10.5)).foregroundStyle(TidyStyle.muted).monospacedDigit()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium)).foregroundStyle(Color(hex: 0x92938C))
                }
                .padding(.horizontal, 10).frame(height: 49).contentShape(Rectangle())
            }
            .buttonStyle(.plain).background(.white)

            if expanded {
                VStack(spacing: 0) {
                    ForEach(group.files) { file in FileRow(file: file) }
                }
                .padding(.leading, 42).padding(.trailing, 8).padding(.bottom, 6)
            }
        }
        .overlay(alignment: .bottom) { TidyStyle.line.frame(height: 1) }
    }
}

private struct EmptyPanelState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 26, weight: .light)).foregroundStyle(TidyStyle.green.opacity(0.82))
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(TidyStyle.ink)
            Text(message).font(.system(size: 11.5)).foregroundStyle(TidyStyle.muted)
                .multilineTextAlignment(.center).frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(28)
    }
}

private struct SuccessBar: View {
    @ObservedObject var model: OrganizerModel

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                .frame(width: 29, height: 29).background(TidyStyle.green, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("All set.").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(TidyStyle.ink)
                Text("\(model.completedBatch?.records.count ?? 0) files are now in \(model.completedGroups.count) folders.")
                    .font(.system(size: 10)).foregroundStyle(Color(hex: 0x6F796A))
            }
            Spacer(minLength: 4)
            Button { model.undoLastSort() } label: {
                Label(model.isUndoing ? "Undoing…" : "Undo", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color(hex: 0x486440))
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 7))
                    .overlay { RoundedRectangle(cornerRadius: 7).stroke(Color(hex: 0xD2DFCC), lineWidth: 1) }
            }
            .buttonStyle(.plain).disabled(model.isUndoing)
        }
        .padding(9).background(TidyStyle.greenWash, in: RoundedRectangle(cornerRadius: 9))
    }
}
