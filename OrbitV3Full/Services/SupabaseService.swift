import Foundation
import Combine

/// Supabase Service for Orbit V3.1
/// Handles real-time database operations, authentication, and data sync
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    @Published var isConnected = false
    @Published var currentUser: SupabaseUser?
    @Published var syncStatus: SyncStatus = .idle
    
    // Configuration from environment
    private let supabaseURL: String
    private let supabaseKey: String
    
    enum SyncStatus {
        case idle, syncing, success, error(String)
    }
    
    struct SupabaseUser: Codable {
        let id: String
        let email: String?
        let createdAt: String?
    }
    
    init() {
        // Load from environment or use defaults
        self.supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] 
            ?? "https://qhotqwwssjuswyacmetd.supabase.co"
        self.supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_KEY"] 
            ?? "sb_publishable_T8ipwhxkYaADG9gWNGDumw_QfzTSAgX"
    }
    
    // MARK: - Connection
    
    func connect() {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/") else {
            print("❌ Invalid Supabase URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, 
                   (200...299).contains(httpResponse.statusCode) {
                    self?.isConnected = true
                    print("✅ Supabase connected")
                } else {
                    self?.isConnected = false
                    print("❌ Supabase connection failed: \(error?.localizedDescription ?? "Unknown")")
                }
            }
        }.resume()
    }
    
    // MARK: - Data Operations
    
    func fetchData<T: Codable>(table: String, completion: @escaping (Result<[T], Error>) -> Void) {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(table)?select=*") else {
            completion(.failure(SupabaseError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        syncStatus = .syncing
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.syncStatus = .error(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    self?.syncStatus = .error("No data")
                    completion(.failure(SupabaseError.noData))
                    return
                }
                
                do {
                    let decoded = try JSONDecoder().decode([T].self, from: data)
                    self?.syncStatus = .success
                    completion(.success(decoded))
                } catch {
                    self?.syncStatus = .error(error.localizedDescription)
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func insertData<T: Encodable>(table: String, data: T, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(table)") else {
            completion(.failure(SupabaseError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try JSONEncoder().encode(data)
        } catch {
            completion(.failure(error))
            return
        }
        
        syncStatus = .syncing
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.syncStatus = .error(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    self?.syncStatus = .success
                    completion(.success(()))
                } else {
                    self?.syncStatus = .error("Insert failed")
                    completion(.failure(SupabaseError.insertFailed))
                }
            }
        }.resume()
    }
    
    func updateData<T: Encodable>(table: String, id: String, data: T, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(table)?id=eq.\(id)") else {
            completion(.failure(SupabaseError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(data)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.syncStatus = .error(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    self?.syncStatus = .success
                    completion(.success(()))
                } else {
                    completion(.failure(SupabaseError.updateFailed))
                }
            }
        }.resume()
    }
    
    func deleteData(table: String, id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(table)?id=eq.\(id)") else {
            completion(.failure(SupabaseError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    completion(.success(()))
                } else {
                    completion(.failure(SupabaseError.deleteFailed))
                }
            }
        }.resume()
    }
}

// MARK: - Errors

enum SupabaseError: Error, LocalizedError {
    case invalidURL
    case noData
    case insertFailed
    case updateFailed
    case deleteFailed
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Supabase URL"
        case .noData: return "No data received"
        case .insertFailed: return "Failed to insert data"
        case .updateFailed: return "Failed to update data"
        case .deleteFailed: return "Failed to delete data"
        case .authenticationFailed: return "Authentication failed"
        }
    }
}
