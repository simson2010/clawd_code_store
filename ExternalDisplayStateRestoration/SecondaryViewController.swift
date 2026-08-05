import UIKit

/// 次级场景的 UI：展示它读到了 App 主体的共享数据，并提供「返回主场景」按钮。
class SecondaryViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemTeal
        title = "次级场景"
        setupUI()
    }

    private func setupUI() {
        let label = UILabel()
        label.text = "这是通知触发创建的次级场景\n\n共享 App 主体数据:\n\(AppData.shared.message)"
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 22, weight: .medium)

        let backButton = UIButton(type: .system)
        backButton.setTitle("返回主场景", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, backButton])
        stack.axis = .vertical
        stack.spacing = 28
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    @objc private func goBack() {
        // 发通知给 SecondarySceneDelegate，由它执行切回主场景的逻辑
        NotificationCenter.default.post(name: SceneSwitchNotification.backToMain, object: nil)
    }
}
