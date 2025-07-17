//
//  GameViewController.swift
//  Chinese Poker
//

import UIKit
import FirebaseFirestore
import FirebaseDatabase

final class GameViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet private weak var deckImageView: UIImageView!
    @IBOutlet private weak var nextCardImageView: UIImageView!
    @IBOutlet private weak var playerStackView: UIStackView!
    @IBOutlet private weak var botStackView: UIStackView!

    // MARK: - Card Model ------------------------------------------------------

    struct Card {
        let rank: Int      // 2 … 14 (ace = 14)
        let suit: String   // H, D, C, S

        var imageName: String {
            let rankStr: String = switch rank {
            case 11: "jack"
            case 12: "queen"
            case 13: "king"
            case 14: "ace"
            default: "\(rank)"
            }

            let suitStr: String = switch suit {
            case "H": "hearts"
            case "D": "diamonds"
            case "C": "clubs"
            case "S": "spades"
            default:
                fatalError("💥 Invalid suit \(suit)")
            }

            return "\(rankStr)_of_\(suitStr)"
        }
    }

    // MARK: - Game State ------------------------------------------------------

    private var deck: [Card] = []
    private var currentCard: Card?

    private var isPlayerTurn       = true
    private var playerCardCounts   = [0, 0, 0, 0, 0]
    private var botCardCounts      = [0, 0, 0, 0, 0]
    private var turnNumber         = 0                   // 0-49

    private var playerCardImageViews: [[UIImageView]] = []
    private var botCardImageViews:    [[UIImageView]] = []

    private var playerCards: [[Card?]] = .init(repeating: .init(repeating: nil, count: 5), count: 5)
    private var botCards:    [[Card?]] = .init(repeating: .init(repeating: nil, count: 5), count: 5)

    // MARK: - Lifecycle -------------------------------------------------------

    override func viewDidLoad() {
        super.viewDidLoad()

        addTableBackground()

        setupCardViews()          // build empty 5×5 grids
        setupDeck()               // fill & shuffle → shows upside-down pile

        styleCardContainer(deckImageView)
        styleCardContainer(nextCardImageView)
        placeDeckAndNextSideBySide()


        dealInitialCards()
        drawNextCard()
    }

    // MARK: - UI Styling Helpers ---------------------------------------------

    /// Gives any card-shaped UIImageView the same opaque bg + border.
    private func styleCardContainer(_ iv: UIImageView) {
        iv.isOpaque           = true
        iv.layer.cornerRadius = 4
        iv.layer.borderWidth  = 1
        iv.clipsToBounds      = true
        iv.contentMode        = .scaleAspectFit

        if traitCollection.userInterfaceStyle == .dark {
            iv.backgroundColor  = UIColor(white: 0.80, alpha: 0.8)
            iv.layer.borderColor = UIColor.white.cgColor
        } else {
            iv.backgroundColor  = .white
            iv.layer.borderColor = UIColor.black.cgColor
        }
    }

    /// Felt-green background pattern behind everything.
    private func addTableBackground() {
        let bg = UIImageView(frame: view.bounds)
        bg.image = UIImage(named: "background")      // your asset
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

    // Restyle instantly if user toggles Light/Dark while in game.
    override func traitCollectionDidChange(_ prev: UITraitCollection?) {
        super.traitCollectionDidChange(prev)

        styleCardContainer(deckImageView)
        styleCardContainer(nextCardImageView)
        playerCardImageViews.flatMap { $0 }.forEach(styleCardContainer)
        botCardImageViews.flatMap    { $0 }.forEach(styleCardContainer)
    }

    // MARK: - Deck / Next-card ------------------------------------------------

    private func setupDeck() {
        var fresh: [Card] = []
        for suit in ["H", "D", "C", "S"] {
            for rank in 2...14 { fresh.append(.init(rank: rank, suit: suit)) }
        }
        deck = fresh.shuffled()

        deckImageView.image = UIImage(named: "back")   // upside-down pile
        styleCardContainer(deckImageView)              // always restyle
    }

    private func drawNextCard() {
        guard !deck.isEmpty else {
            currentCard = nil
            nextCardImageView.image = nil
            deckImageView.image     = nil              // hide empty pile
            return
        }

        currentCard = deck.removeFirst()

        deckImageView.image = UIImage(named: "back")
        styleCardContainer(deckImageView)              // keep border if trait flips

        nextCardImageView.image =
            (turnNumber >= 40 && !isPlayerTurn)
            ? UIImage(named: "placeholder")
            : UIImage(named: currentCard!.imageName)
    }

    // MARK: - Build 5×5 card grids -------------------------------------------

    private func setupCardViews() {
        playerCardImageViews.removeAll()
        botCardImageViews.removeAll()

        for col in 0..<5 {
            guard
                let playerCol = playerStackView.arrangedSubviews[col] as? UIStackView,
                let botCol    = botStackView.arrangedSubviews[col]    as? UIStackView
            else { continue }

            // allow taps on player columns
            playerCol.isUserInteractionEnabled = true
            playerCol.tag = col
            playerCol.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                  action: #selector(handlePlayerColumnTap(_:))))

            playerCol.spacing = 8
            botCol.spacing    = 8

            var playerImgs: [UIImageView] = []
            var botImgs:    [UIImageView] = []

            for _ in 0..<5 {
                // player cell
                let p = UIImageView(image: UIImage(named: "placeholder"))
                p.translatesAutoresizingMaskIntoConstraints = false
                p.widthAnchor .constraint(equalToConstant: 40).isActive = true
                p.heightAnchor.constraint(equalToConstant: 60).isActive = true
                styleCardContainer(p)

                // bot cell
                let b = UIImageView(image: UIImage(named: "placeholder"))
                b.translatesAutoresizingMaskIntoConstraints = false
                b.widthAnchor .constraint(equalToConstant: 40).isActive = true
                b.heightAnchor.constraint(equalToConstant: 60).isActive = true
                styleCardContainer(b)

                playerCol.addArrangedSubview(p)
                botCol.addArrangedSubview(b)

                playerImgs.append(p)
                botImgs.append(b)
            }

            playerCardImageViews.append(playerImgs)
            botCardImageViews.append(botImgs)
        }
    }

    // MARK: - Player turn ------------------------------------------------------

    @objc private func handlePlayerColumnTap(_ gr: UITapGestureRecognizer) {
        guard isPlayerTurn,
              let column = gr.view?.tag,
              let card   = currentCard else { return }

        // rule: must place in column(s) with fewest cards
        let minCount = playerCardCounts.min() ?? 0
        guard playerCardCounts[column] == minCount else {
            showAlert("⚠️ Invalid Move",
                      "Place the card in one of the columns with the fewest cards.")
            return
        }

        let row = playerCardCounts[column]
        guard row < 5 else {
            showAlert("⚠️ Column Full", "This column already has 5 cards.")
            return
        }

        // place card
        playerCardImageViews[column][row].image = UIImage(named: card.imageName)
        playerCards[column][row] = card
        playerCardCounts[column] += 1
        turnNumber += 1

        isPlayerTurn = false
        drawNextCard()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.botTurn() }
    }

    // MARK: - Bot logic -------------------------------------------------------

    private func botTurn() {
        guard let card = currentCard else { return }

        let minCount  = botCardCounts.min() ?? 0
        let validCols = (0..<5).filter { botCardCounts[$0] == minCount && botCardCounts[$0] < 5 }
        guard let chosen = validCols.min(by: { averageRank(botCards[$0]) < averageRank(botCards[$1]) }) else {
            isPlayerTurn = true; return
        }

        let row = botCardCounts[chosen]
        botCardImageViews[chosen][row].image =
            (row == 4 || turnNumber >= 40) ? UIImage(named: "back")
                                           : UIImage(named: card.imageName)

        botCards[chosen][row] = card
        botCardCounts[chosen] += 1
        turnNumber += 1

        if turnNumber == 50 {
            revealAllCards()
            compareHandsAndScore()
        } else {
            isPlayerTurn = true
            drawNextCard()
        }
    }

    private func averageRank(_ hand: [Card?]) -> Double {
        let vals = hand.compactMap { $0?.rank }
        return vals.isEmpty ? 0 : Double(vals.reduce(0, +)) / Double(vals.count)
    }

    // MARK: - Reveal Cards ----------------------------------------------------

    private func revealAllCards() {
        for c in 0..<5 {
            for r in 0..<5 {
                if let card = botCards[c][r] {
                    botCardImageViews[c][r].image = UIImage(named: card.imageName)
                }
                if r == 4, let card = playerCards[c][r] {
                    playerCardImageViews[c][r].image = UIImage(named: card.imageName)
                }
            }
        }
    }

    // MARK: - Scoring / Endgame ----------------------------------------------

    private func compareHandsAndScore() {
        var playerWins = 0
        var botWins    = 0

        for col in 0..<5 {
            let pHand = playerCards[col].compactMap { $0 }
            let bHand = botCards[col].compactMap { $0 }

            switch comparePokerHands(pHand, bHand) {
            case  1: playerWins += 1
            case -1: botWins    += 1
            default: break
            }
        }

        if playerWins > botWins { updateScore(winner: "player") }
        else if botWins > playerWins { updateScore(winner: "bot") }

        let title = playerWins > botWins ? "🏆 You Win!"
                  : botWins    > playerWins ? "💀 Bot Wins!"
                  : "🤝 It's a Tie!"

        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(.init(title: "Play Again", style: .default) { _ in self.restartGame() })
        alert.addAction(.init(title: "Scoreboard", style: .default) { _ in
            let sb = UIStoryboard(name: "Main", bundle: nil)
            if let vc = sb.instantiateViewController(withIdentifier: "ScoreboardViewController") as? ScoreboardViewController {
                vc.modalPresentationStyle = .fullScreen
                self.present(vc, animated: true)
            }
        })
        present(alert, animated: true)
    }

    private func comparePokerHands(_ h1: [Card], _ h2: [Card]) -> Int {
        let s1 = evaluateHand(h1)
        let s2 = evaluateHand(h2)
        return (s1 > s2) ? 1 : (s1 < s2 ? -1 : 0)
    }

    // MARK: - Firebase score --------------------------------------------------

    private func updateScore(winner: String) {
        guard let user = UserDefaults.standard.string(forKey: "userName") else { return }

        let ref  = Database.database().reference().child("users").child(user)
        ref.observeSingleEvent(of: .value) { snap in
            var wins   = 0
            var losses = 0
            if let d = snap.value as? [String: Any] {
                wins   = d["wins"]   as? Int ?? 0
                losses = d["losses"] as? Int ?? 0
            }
            winner == "player" ? (wins += 1) : (losses += 1)
            ref.setValue(["wins": wins, "losses": losses])
        }
    }

    // MARK: - Restart ---------------------------------------------------------

    private func restartGame() {
        deck.removeAll()
        currentCard = nil
        isPlayerTurn = true
        playerCardCounts = [0,0,0,0,0]
        botCardCounts    = [0,0,0,0,0]
        turnNumber       = 0
        playerCards      = .init(repeating: .init(repeating: nil, count: 5), count: 5)
        botCards         = .init(repeating: .init(repeating: nil, count: 5), count: 5)

        for c in 0..<5 { for r in 0..<5 {
            playerCardImageViews[c][r].image = UIImage(named: "placeholder")
            botCardImageViews[c][r].image    = UIImage(named: "placeholder")
        }}

        setupDeck()
        drawNextCard()
    }

    // MARK: - Poker hand evaluation (unchanged) ------------------------------

    private func evaluateHand(_ hand: [Card]) -> Int {
        let ranks = hand.map(\.rank)
        let suits = hand.map(\.suit)

        let rankCounts = Dictionary(grouping: ranks, by: { $0 }).mapValues(\.count)
        let counts     = Array(rankCounts.values).sorted(by: >)

        let isFlush    = Set(suits).count == 1
        let sorted     = ranks.sorted()
        let isStraight = Set(sorted).count == 5 && (sorted.last! - sorted.first! == 4)

        // score hierarchy
        if isFlush && isStraight { return 8000 + sorted.max()! } // Straight Flush
        if counts == [4,1]       { return 7000 + maxRank(rankCounts, 4) } // Four
        if counts == [3,2]       { return 6000 + maxRank(rankCounts, 3) } // Full House
        if isFlush               { return 5000 + sorted.max()! }          // Flush
        if isStraight            { return 4000 + sorted.max()! }          // Straight
        if counts == [3,1,1]     { return 3000 + maxRank(rankCounts, 3) } // Three
        if counts == [2,2,1]     { return 2000 + maxRank(rankCounts, 2) } // Two Pair
        if counts == [2,1,1,1]   { return 1000 + maxRank(rankCounts, 2) } // Pair
        return sorted.max() ?? 0                                           // High Card
    }

    private func maxRank(_ dict: [Int:Int], _ count: Int) -> Int {
        dict.filter { $0.value == count }.map(\.key).max() ?? 0
    }

    // MARK: - Deal initial cards ---------------------------------------------

    private func dealInitialCards() {
        // 5 to player
        for _ in 0..<5 {
            guard let card = deck.popLast() else { break }
            let min = playerCardCounts.min() ?? 0
            let cols = (0..<5).filter { playerCardCounts[$0] == min && playerCardCounts[$0] < 5 }
            let col = cols.randomElement()!
            let row = playerCardCounts[col]

            playerCardImageViews[col][row].image = UIImage(named: card.imageName)
            playerCards[col][row] = card
            playerCardCounts[col] += 1
            turnNumber += 1
        }

        // 5 to bot
        for _ in 0..<5 {
            guard let card = deck.popLast() else { break }
            let min = botCardCounts.min() ?? 0
            let cols = (0..<5).filter { botCardCounts[$0] == min && botCardCounts[$0] < 5 }
            let col = cols.randomElement()!
            let row = botCardCounts[col]

            botCardImageViews[col][row].image = UIImage(named: card.imageName)
            botCards[col][row] = card
            botCardCounts[col] += 1
            turnNumber += 1
        }
    }

    // MARK: - Tiny helper -----------------------------------------------------

    private func showAlert(_ title: String, _ msg: String) {
        let a = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        a.addAction(.init(title: "OK", style: .default))
        present(a, animated: true)
    }
    
    
    // MARK: - Deck + next-card layout  (center of the screen)
    private func placeDeckAndNextSideBySide() {

        // 1. Remove any constraints the two image-views came with
        deckImageView.removeConstraints(deckImageView.constraints)
        nextCardImageView.removeConstraints(nextCardImageView.constraints)

        // 2. Tell Auto-Layout we’ll drive the frames manually
        deckImageView.translatesAutoresizingMaskIntoConstraints     = false
        nextCardImageView.translatesAutoresizingMaskIntoConstraints = false

        // 3. Horizontal stack:  [ pile | next-card ]
        let hStack = UIStackView(arrangedSubviews: [deckImageView, nextCardImageView])
        hStack.axis         = .horizontal
        hStack.alignment    = .center
        hStack.distribution = .fill
        hStack.spacing      = 8
        hStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hStack)

        // 4.  **Center the stack in BOTH directions**
        NSLayoutConstraint.activate([
            hStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hStack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // 5.  Give each image-view its explicit size (same as grid cells)
        NSLayoutConstraint.activate([
            deckImageView.widthAnchor .constraint(equalToConstant: 40),
            deckImageView.heightAnchor.constraint(equalToConstant: 60),
            nextCardImageView.widthAnchor .constraint(equalTo: deckImageView.widthAnchor),
            nextCardImageView.heightAnchor.constraint(equalTo: deckImageView.heightAnchor)
        ])
    }

}
