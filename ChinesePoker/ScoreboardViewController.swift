import UIKit
import FirebaseFirestore
import FirebaseDatabase


struct PlayerRecord {
    let name: String
    let wins: Int
    let losses: Int
}

class ScoreboardViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBAction func backToMainMenuTapped(_ sender: UIButton) {
        self.view.window?.rootViewController?.dismiss(animated: true, completion: nil)
    }



    var playerRecords: [PlayerRecord] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        addTableBackground()
        fetchScoreboard()
    }

    func fetchScoreboard() {
        let dbRef = Database.database().reference()
        print("📡 Fetching scoreboard from Realtime Database...")

        dbRef.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let usersData = snapshot.value as? [String: [String: Any]] else {
                print("⚠️ No user data found or bad format")
                return
            }

            self.playerRecords = usersData.map { (key, value) in
                let name = key
                let wins = value["wins"] as? Int ?? 0
                let losses = value["losses"] as? Int ?? 0
                return PlayerRecord(name: name, wins: wins, losses: losses)
            }
            .sorted(by: { $0.wins > $1.wins })

            DispatchQueue.main.async {
                print("🔁 Reloading table with \(self.playerRecords.count) records")
                self.tableView.reloadData()
            }
        }
    }




    // MARK: - Table View DataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playerRecords.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let record = playerRecords[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreboardCell", for: indexPath)
        cell.textLabel?.text = record.name
        cell.detailTextLabel?.text = "W: \(record.wins) | L: \(record.losses)"
        return cell
    }
    // MARK: - Background
    private func addTableBackground() {
        let bg = UIImageView(frame: view.bounds)
        bg.image = UIImage(named: "background")     // use the same asset name
        bg.contentMode = .scaleAspectFill
        bg.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(bg, at: 0)                // send to back

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: view.topAnchor),
            bg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

}
