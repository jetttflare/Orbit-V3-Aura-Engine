#if os(macOS)
import SwiftUI

struct FileBrowserPanel: View {
    @EnvironmentObject var backendService: BackendService
    
    // State
    @State private var selectedFiles: Set<String> = []
    @State private var filterText: String = ""
    @State private var filterType: String = "All" // All, App, Picture, Data
    @State private var isGridView: Bool = true
    
    // Grid Setup
    let gridColumns = [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 12)]
    
    var body: some View {
        GlassPanelView(title: "DATA EXPLORER") {
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    // Back Button
                    if !backendService.currentPath.isEmpty {
                        Button(action: goUp) {
                            Image(systemName: "arrow.turn.up.left")
                                .foregroundColor(Theme.Colors.cyanPrimary)
                        }
                    } else {
                        Image(systemName: "internaldrive")
                           .foregroundColor(.gray)
                    }
                    
                    // Path Breadcrumbs (Simplified)
                    Text(backendService.currentPath.isEmpty ? "ROOT" : backendService.currentPath)
                        .font(Theme.Fonts.codeMono(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.head)
                    
                    Spacer()
                    
                    // View Toggle
                    Button(action: { isGridView.toggle() }) {
                        Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                            .foregroundColor(.white)
                    }
                }
                .padding(8)
                .background(Theme.Colors.panelBackground.opacity(0.5))
                
                // Filters
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search...", text: $filterText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(Theme.Fonts.rajdhani(14))
                        .foregroundColor(.white)
                    
                    Picker("Type", selection: $filterType) {
                        Text("All").tag("All")
                        Text("Apps").tag("app")
                        Text("Pics").tag("picture")
                        Text("Data").tag("data")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .labelsHidden()
                    .accentColor(Theme.Colors.cyanPrimary)
                }
                .padding(8)
                
                // Main Content
                ScrollView {
                    if isGridView {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            fileContent
                        }
                        .padding(8)
                    } else {
                        LazyVStack(spacing: 4) {
                            fileContent
                        }
                        .padding(8)
                    }
                }
                
                // Footer / Batch Actions
                if !selectedFiles.isEmpty {
                    HStack {
                        Text("\(selectedFiles.count) SELECTED")
                            .font(Theme.Fonts.codeMono(size: 12))
                            .foregroundColor(Theme.Colors.cyanPrimary)
                        
                        Spacer()
                        
                        Button(action: downloadSelected) {
                            Label("BATCH DOWNLOAD", systemImage: "arrow.down.circle.fill")
                                .font(Theme.Fonts.techBold(size: 12))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.cyanPrimary.opacity(0.2))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.Colors.cyanPrimary, lineWidth: 1))
                        }
                    }
                    .padding(8)
                    .background(Theme.Colors.panelBackground)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .onAppear {
            if backendService.fileList.isEmpty {
                 backendService.listFiles() // Load Root
            }
        }
        .onChange(of: backendService.downloadURL) { url in
            if let url = url {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    var fileContent: some View {
        ForEach(filteredFiles) { file in
            if isGridView {
                 FileGridItem(file: file, isSelected: selectedFiles.contains(file.path))
                    .onTapGesture {
                        if file.is_dir {
                             backendService.listFiles(file.path)
                             selectedFiles.removeAll()
                        } else {
                             toggleSelection(file)
                        }
                    }
            } else {
                FileListItem(file: file, isSelected: selectedFiles.contains(file.path))
                   .onTapGesture {
                       if file.is_dir {
                            backendService.listFiles(file.path)
                            selectedFiles.removeAll()
                       } else {
                            toggleSelection(file)
                       }
                   }
            }
        }
    }
    
    var filteredFiles: [FileItem] {
        backendService.fileList.filter { file in
            let matchText = filterText.isEmpty || file.name.localizedCaseInsensitiveContains(filterText)
            let matchType = filterType == "All" || file.category == filterType
            return matchText && matchType
        }
    }
    
    func goUp() {
        let parent = (backendService.currentPath as NSString).deletingLastPathComponent
        backendService.listFiles(parent == "/" || parent == "." ? "" : parent)
        selectedFiles.removeAll()
    }
    
    func toggleSelection(_ file: FileItem) {
        if selectedFiles.contains(file.path) {
            selectedFiles.remove(file.path)
        } else {
            selectedFiles.insert(file.path)
        }
    }
    
    func downloadSelected() {
        backendService.downloadBatch(Array(selectedFiles))
    }
}

// Subcomponents
struct FileGridItem: View {
    let file: FileItem
    let isSelected: Bool
    
    var body: some View {
        VStack {
            Image(systemName: iconFor(file))
                .font(.system(size: 32))
                .foregroundColor(colorFor(file))
                .padding(8)
            
            Text(file.name)
                .font(Theme.Fonts.rajdhani(10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(isSelected ? Theme.Colors.cyanPrimary.opacity(0.3) : Color.clear)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Theme.Colors.cyanPrimary : Color.clear, lineWidth: 1))
        .overlay(
            Group {
                if let risk = file.analysis?.risk_score, risk > 0 {
                    ZStack {
                        Circle()
                            .fill(risk > 70 ? Color.red : Color.orange)
                            .frame(width: 20, height: 20)
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(4)
                }
            },
            alignment: .topTrailing
        )
    }
}

struct FileListItem: View {
    let file: FileItem
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: iconFor(file))
                .foregroundColor(colorFor(file))
                .font(Theme.Fonts.rajdhani(14))
            
            // AI Analysis Badges
            if let tags = file.analysis?.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(tag == "SECRET" ? Color.red : (tag == "PII" ? Color.orange : Color.gray))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                .padding(.leading, 8)
            }
            
            Spacer()
            if !file.is_dir {
                Text(formatBytes(file.size))
                    .font(Theme.Fonts.codeMono(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(isSelected ? Theme.Colors.cyanPrimary.opacity(0.3) : Color.clear)
    }
}

// Helpers
func iconFor(_ file: FileItem) -> String {
    if file.is_dir { return "folder.fill" }
    switch file.type {
        case "ios_app", "ipa": return "cube.box.fill"
        case "android_app", "apk": return "android"
        case "ios_image", "picture": return "photo"
        case "video": return "film"
        case "text": return "doc.text"
        case "data", "database", "plist", "xml": return "cylinder.split.1x2"
        default: return "doc"
    }
}

func colorFor(_ file: FileItem) -> Color {
    if file.is_dir { return Theme.Colors.purplePrimary }
    switch file.category {
        case "app": return .green
        case "picture": return .blue
        case "data": return .orange
        case "text": return .gray
        default: return .white
    }
}

func formatBytes(_ bytes: Int) -> String {
    let b = Double(bytes)
    if b < 1024 { return "\(bytes) B" }
    if b < 1024*1024 { return String(format: "%.1f KB", b/1024) }
    return String(format: "%.1f MB", b/(1024*1024))
}
#endif
