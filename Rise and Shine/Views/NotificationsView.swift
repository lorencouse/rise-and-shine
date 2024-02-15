//
//  NotificationsView.swift
//  Rise and Shine
//
//  Created by loren on 2/1/24.
//

import Foundation
import SwiftUI
import UIKit


struct NotificationsView: View {
    
    var body: some View {
        
        VStack {
            Section {
                Button("See Scheduled Notifications") {

                        seeScheduledNotifications()
                
                }
            }
            
            Section {
                NotificationsViewMain()
            }
            
        }
        
    }
    
}
    
    
class NotificationsViewController: UIViewController, UITableViewDataSource {
    
    var notificationRequests: [UNNotificationRequest] = []
    
    private let tableView: UITableView = {
        let table = UITableView()
        // Register the custom cell class
        table.register(NotificationTableViewCell.self, forCellReuseIdentifier: "NotificationCell")
        return table
    }()
        
        
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.addSubview(tableView)
            tableView.dataSource = self
            tableView.frame = view.bounds
            
            NotificationManager.fetchScheduledNotifications { [weak self] requests in
                DispatchQueue.main.async {
                    self?.notificationRequests = requests
                    self?.tableView.reloadData()
                }
            }
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return notificationRequests.count
        }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as! NotificationTableViewCell
        let request = notificationRequests[indexPath.row]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let triggerDate = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
        let triggerDateString = triggerDate != nil ? dateFormatter.string(from: triggerDate!) : "N/A"
        
        cell.textLabel?.text = "\(request.content.title) - \(request.content.body)"
        cell.detailTextLabel?.text = "Scheduled for: \(triggerDateString)"
        return cell
    }
    }
    
    
struct NotificationsViewMain: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> NotificationsViewController {
        return NotificationsViewController()
    }
    
    func updateUIViewController(_ uiViewController: NotificationsViewController, context: Context) {
        // Update the view controller when the SwiftUI state changes, if necessary
    }
}

class NotificationTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        // Allow for multiple lines
        textLabel?.numberOfLines = 0
        detailTextLabel?.numberOfLines = 0
    }
}

func seeScheduledNotifications() {
    UNUserNotificationCenter.current().getPendingNotificationRequests { (notificationRequests) in
        for request in notificationRequests {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let nextTriggerDate = trigger.nextTriggerDate() {
                print("Notification ID: \(request.identifier), Title: \(request.content.title), Scheduled for: \(nextTriggerDate)")
            }
        }
    }

}
