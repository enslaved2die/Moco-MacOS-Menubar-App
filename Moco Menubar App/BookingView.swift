import Cocoa
import SwiftUI
import AppKit

// 1. Define a delegate protocol in BookingView
protocol BookingDelegate: AnyObject {
    func didUpdateLastBookingDate(date: Date)
}

struct BookingView: View {
    @State private var selectedProject: String = ""
    @State private var selectedTask: String = ""
    @State private var descriptionText: String = ""
    @State private var hours: Double = 0.0
    @State private var projects: [Project] = []
    @State private var tasks: [Task] = []
    @State private var isLoading: Bool = false
    @State private var bookingSuccess: Bool = false
    @State private var showingSetup: Bool = false
    @State private var errorMessage: String?
    @State private var isPopoverVisible: Bool = false
    @State private var storedProjectId: String = ""
    
    @AppStorage("mocoDomain") private var mocoDomain: String = ""
    @AppStorage("mocoApiKey") private var apiKey: String = ""
    
    // 2. Add a delegate property
    weak var delegate: BookingDelegate?
    
    // Computed property for displaying time in HH:mm format
    private var displayTime: String {
        let totalMinutes = Int(hours * 60)
        let hour = totalMinutes / 60
        let minute = totalMinutes % 60
        return String(format: "%d:%02d", hour, minute)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 16) {
                Text(Date.now, style: .date)
                    .font(.title2)
                
                // Project picker
                Picker("Project", selection: $selectedProject) {
                    Text("select project").tag("")
                    ForEach(projects, id: \.id) { project in
                        Text(project.name).tag("\(project.id)")
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedProject) { newValue in
                    // Update selectedTask
                    selectedTask = ""
                    if let selectedProject = projects.first(where: { $0.id == Int(newValue) ?? 0 }) {
                        tasks = selectedProject.tasks
                    } else {
                        tasks = []
                    }
                    storedProjectId = newValue
                }
                
                // Task picker
                Picker("Task", selection: $selectedTask) {
                    Text("select task").tag("")
                    ForEach(tasks, id: \.id) { task in
                        Text(task.name).tag("\(task.id)")
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                TextField("Description", text: $descriptionText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Button("-") {
                        if hours > 0 { hours -= 0.25 }
                    }
                    Text(displayTime) // Use the computed property here
                    Button("+") { hours += 0.25 }
                }
                
                if isLoading {
                    ProgressView()
                } else {
                    Button(action: bookTime) {
                        Image(systemName: "clock")
                            .foregroundColor(.white)
                            .padding(10)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.borderedProminent)
                    .cornerRadius(50)
                }
                
                // Show only the error message when popover is visible
                if isPopoverVisible {
                    if let errorMessage = errorMessage {
                        Text((errorMessage))
                            .foregroundColor(.red)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    self.errorMessage = nil // Reset after 3 seconds
                                }
                            }
                    }
                }
            }
            .padding()
            .frame(width: 300)
            .onAppear {
                // Fetch projects and tasks when the view appears
                fetchProjectsAndTasks()
                isPopoverVisible = true
                //check lastBookingDate on appear
                if let lastBookingDate = UserDefaults.standard.value(forKey: "lastBookingDate") as? Date {
                    print("OnAppear - Last Booking Date: \(lastBookingDate)")
                } else {
                    print("OnAppear - No lastBookingDate found")
                }
            }
            .onDisappear {
                isPopoverVisible = false
                bookingSuccess = false // Not used, but kept for consistency
                errorMessage = nil
            }
            
            // Settings button in top-right corner
            Button(action: { showingSetup = true }) {
                Image(systemName: "gearshape")
                    .foregroundColor(.gray)
            }
            .sheet(isPresented: $showingSetup) {
                SetupView()
            }
            .padding(.top, 15)
            .padding(.trailing, 15)
        }
    }
    
    func fetchProjectsAndTasks() {
        guard !mocoDomain.isEmpty else {
            errorMessage = "Moco Domain is not set. Please configure in Setup."
            return
        }
        
        guard !apiKey.isEmpty else {
            errorMessage = "Moco API Key is not set. Please configure in Setup."
            return
        }
        
        guard let url = URL(string: "https://\(mocoDomain).mocoapp.com/api/v1/projects/assigned") else {
            print("Invalid MOCO domain")
            errorMessage = "Invalid MOCO domain"
            return
        }
        var request = URLRequest(url: url)
        request.addValue("Token token=\(apiKey)", forHTTPHeaderField: "Authorization")
        
        isLoading = true
        errorMessage = nil
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("Error fetching projects: \(error)")
                    errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    print("No data received for projects")
                    errorMessage = "No data received from server"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    print("Error: HTTP status code \(httpResponse.statusCode) for projects")
                    errorMessage = "HTTP error: \(httpResponse.statusCode)"
                    return
                }
                
                if let decodedResponse = try? JSONDecoder().decode([Project].self, from: data) {
                    
                    var fetchedProjects = decodedResponse
                    
                    let group = DispatchGroup()
                    for index in 0..<fetchedProjects.count {
                        group.enter()
                        self.fetchTasks(for: fetchedProjects[index].id) { fetchedTasks in
                            defer { group.leave() }
                            if let fetchedTasks = fetchedTasks {
                                fetchedProjects[index].tasks = fetchedTasks
                            }
                        }
                    }
                    
                    group.notify(queue: .main) {
                        // Filter out projects with no tasks
                        self.projects = fetchedProjects.filter { $0.tasks.count > 0 }
                        
                        // Restore the selected project, if any, AFTER projects are loaded
                        if let storedProjectInt = Int(storedProjectId),
                           let project = self.projects.first(where: { $0.id == storedProjectInt }) {
                            self.selectedProject = "\(project.id)"
                            self.tasks = project.tasks
                        } else if let firstProject = self.projects.first {
                            self.selectedProject = "\(firstProject.id)"
                            self.tasks = firstProject.tasks
                        }
                    }
                    
                } else {
                    print("Failed to decode projects data")
                    errorMessage = "Failed to decode project data"
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Response JSON: \(jsonString)")
                    }
                }
            }
        }.resume()
    }
    
    func fetchTasks(for projectId: Int, completion: @escaping ([Task]?) -> Void) {
        guard !mocoDomain.isEmpty else{
            completion(nil)
            return
        }
        guard !apiKey.isEmpty else{
            completion(nil)
            return
        }
        
        guard let url = URL(string: "https://\(mocoDomain).mocoapp.com/api/v1/tasks?project_id=\(projectId)") else {
            print("Invalid project ID or MOCO domain")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("Token token=\(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching tasks: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received for tasks")
                completion(nil)
                return
            }
            
            // Check the response status code
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Error: HTTP status code \(httpResponse.statusCode) for tasks. Project ID: \(projectId)")
                completion(nil)
                return
            }
            
            if let decodedResponse = try? JSONDecoder().decode([Task].self, from: data) {
                DispatchQueue.main.async {
                    completion(decodedResponse)
                }
            } else {
                print("Failed to decode tasks data")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Response JSON: \(jsonString)")
                }
                completion(nil)
            }
        }.resume()
    }
    
    func bookTime() {
        guard hours > 0 else {
            errorMessage = "Hours must be greater than 0"
            return
        }
        
        guard !mocoDomain.isEmpty else {
            errorMessage = "Moco Domain is not set. Please configure in Setup."
            return
        }
        
        guard !apiKey.isEmpty else {
            errorMessage = "Moco API Key is not set. Please configure in Setup."
            return
        }
        
        guard let url = URL(string: "https://\(mocoDomain).mocoapp.com/api/v1/activities") else {
            print("Invalid MOCO domain for booking")
            errorMessage = "Invalid MOCO domain"
            return
        }
        
        guard let projectId = Int(selectedProject), let taskId = Int(selectedTask) else {
            print("Invalid project or task ID")
            errorMessage = "Invalid project or task ID"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Token token=\(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Construct the JSON payload according to the API documentation for /activities
        let bookingData: [String: Any] = [
            "date": DateFormatter.yyyyMMdd.string(from: Date()),
            "hours": hours,
            "project_id": projectId,
            "task_id": taskId,
            "description": descriptionText
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bookingData)
        } catch {
            print("Error serializing JSON: \(error)")
            errorMessage = "Error creating booking data"
            isLoading = false
            return
        }
        
        isLoading = true
        bookingSuccess = false
        errorMessage = nil
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("Error booking time: \(error)")
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response")
                    self.errorMessage = "Invalid server response"
                    return
                }
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("Booking successful!")
                    let bookingDate = Date()
                    UserDefaults.standard.set(bookingDate, forKey: "lastBookingDate")
                    // 3. Notify the delegate!
                    self.delegate?.didUpdateLastBookingDate(date: bookingDate)
                    
                    //Clear the form
                    hours = 0.0
                    descriptionText = ""
                    selectedTask = ""
                    selectedProject = ""
                    
                } else {
                    print("Booking failed with status code: \(httpResponse.statusCode)")
                    self.errorMessage = "Booking failed: \(httpResponse.statusCode)"
                    if let data = data, let message = String(data: data, encoding: .utf8) {
                        print("Error message from server: \(message)")
                        self.errorMessage = "Booking failed: \(httpResponse.statusCode) - \(message)"
                    }
                }
            }
        }.resume()
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct Project: Codable, Identifiable {
    let id: Int
    let name: String
    var tasks: [Task] = []
}

struct Task: Codable, Identifiable {
    let id: Int
    let name: String
}
