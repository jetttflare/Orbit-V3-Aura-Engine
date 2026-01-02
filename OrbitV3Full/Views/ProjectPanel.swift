import SwiftUI

struct ProjectPanel: View {
    @EnvironmentObject var backendService: BackendService
    
    var body: some View {
        GlassPanelView(title: "Project Status") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let status = backendService.projectStatus {
                    // Progress Bar
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OVERALL PROGRESS")
                            .font(Theme.Fonts.rajdhani(10))
                            .foregroundColor(Theme.Colors.cyanDim)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.Colors.cyanPrimary.opacity(0.1))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.Colors.cyanPrimary)
                                    .frame(width: geometry.size.width * status.progress, height: 4)
                                    .shadow(color: Theme.Colors.cyanGlow, radius: 4)
                            }
                        }
                        .frame(height: 4)
                        
                        Text("\(Int(status.progress * 100))%")
                            .font(Theme.Fonts.system(10))
                            .foregroundColor(Theme.Colors.cyanPrimary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    // Active Tasks
                    if !status.tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(status.tasks.prefix(5)) { task in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(statusColor(for: task.status))
                                        .frame(width: 6, height: 6)
                                        .shadow(color: statusColor(for: task.status), radius: 3)
                                    
                                    Text(task.text)
                                        .font(Theme.Fonts.system(11))
                                        .foregroundColor(Theme.Colors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                } else {
                    Text("Loading Project Data...")
                         .font(Theme.Fonts.codeMono(size: 12))
                         .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "completed", "done": return Theme.Colors.success
        case "inprogress", "in_progress": return Theme.Colors.warning
        case "pending", "todo": return Theme.Colors.cyanDim
        default: return Theme.Colors.cyanDim
        }
    }
}

#Preview {
    ProjectPanel()
        .frame(width: 300)
        .padding()
        .background(Theme.Colors.background)
        .environmentObject(ProjectManager())
}
