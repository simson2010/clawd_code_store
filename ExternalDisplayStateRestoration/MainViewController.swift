import UIKit

class MainViewController: UIViewController {
    private let counterLabel = UILabel()
    private let draftTextView = UITextView()
    private let segment = UISegmentedControl(items: ["红", "绿", "蓝"])
    private let incrementButton = UIButton(type: .system)
    private var counter = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "主场景 · 状态恢复 Demo"
        setupUI()
    }

    private func setupUI() {
        counterLabel.font = .systemFont(ofSize: 32, weight: .bold)
        counterLabel.text = "计数: \(counter)"
        incrementButton.setTitle("+1", for: .normal)
        incrementButton.titleLabel?.font = .systemFont(ofSize: 20)
        incrementButton.addTarget(self, action: #selector(increment), for: .touchUpInside)
        draftTextView.backgroundColor = .secondarySystemBackground
        draftTextView.layer.cornerRadius = 8
        draftTextView.text = "输入文字，杀掉 App 再回来，文字还在"
        draftTextView.frame = CGRect(x: 0, y: 0, width: 300, height: 120)
        segment.selectedSegmentIndex = 0

        let stack = UIStackView(arrangedSubviews: [counterLabel, incrementButton, draftTextView, segment])
        stack.axis = .vertical; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    @objc private func increment() { counter += 1; counterLabel.text = "计数: \(counter)" }

    func restore(from activity: NSUserActivity) {
        guard let info = activity.userInfo else { return }
        if let c = info["counter"] as? Int { counter = c; counterLabel.text = "计数: \(counter)" }
        if let t = info["draftText"] as? String { draftTextView.text = t }
        if let s = info["selectedSegment"] as? Int { segment.selectedSegmentIndex = s }
    }

    func snapshot() -> [String: Any] {
        ["counter": counter, "draftText": draftTextView.text ?? "", "selectedSegment": segment.selectedSegmentIndex]
    }
}
