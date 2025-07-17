
import UIKit

class WelcomeViewController: UIViewController {
    @IBOutlet weak var scoreboardButtonTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var stackVerticalConstraint: NSLayoutConstraint!
    @IBAction func scoreboardButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let scoreboardVC = storyboard.instantiateViewController(withIdentifier: "ScoreboardViewController") as? ScoreboardViewController {
            scoreboardVC.modalPresentationStyle = .fullScreen
            present(scoreboardVC, animated: true)
        }
    }
    // MARK: - Life-cycle
        override func viewDidLoad() {
            super.viewDidLoad()
            addTableBackground()
        }


    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if UIDevice.current.orientation.isLandscape {
                stackVerticalConstraint.constant = -100
                scoreboardButtonTopConstraint.constant = 100
            } else {
                stackVerticalConstraint.constant = -100
                scoreboardButtonTopConstraint.constant = 200
            }
    }
    @IBAction func startGameTapped(_ sender: UIButton) {
        guard let name = nameTextField.text, !name.isEmpty else {
            // Optionally show an alert to enter a name
            return
        }

        UserDefaults.standard.set(name, forKey: "userName") // ✅ Save name for GameViewController

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let gameVC = storyboard.instantiateViewController(withIdentifier: "GameViewController") as? GameViewController {
            gameVC.modalPresentationStyle = .fullScreen
            self.present(gameVC, animated: true)
        }
    }

    // MARK: - Background
    private func addTableBackground() {
        let bg = UIImageView(frame: view.bounds)
        bg.image = UIImage(named: "background")
        bg.contentMode = .scaleAspectFill
        bg.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(bg, at: 0)

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: view.topAnchor),
            bg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

}
