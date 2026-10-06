import UIKit
import COR

enum Colors {
	static let background = UIColor(red: 0.025, green: 0.035, blue: 0.045, alpha: 1)
	static let panel = UIColor(red: 0.055, green: 0.065, blue: 0.075, alpha: 0.96)
	static let gold = UIColor(red: 0.93, green: 0.73, blue: 0.36, alpha: 1)
	static let muted = UIColor(red: 0.57, green: 0.62, blue: 0.64, alpha: 1)
	static let scorpion = UIColor(red: 0.96, green: 0.64, blue: 0.12, alpha: 1)
	static let subZero = UIColor(red: 0.15, green: 0.62, blue: 0.96, alpha: 1)
	static let jade = UIColor(red: 0.25, green: 0.82, blue: 0.45, alpha: 1)
	static let sektor = UIColor(red: 0.91, green: 0.16, blue: 0.19, alpha: 1)
	static let cyrax = UIColor(red: 0.95, green: 0.82, blue: 0.16, alpha: 1)
	static let kitana = UIColor(red: 0.25, green: 0.36, blue: 0.95, alpha: 1)
	static let smoke = UIColor(red: 0.66, green: 0.70, blue: 0.76, alpha: 1)
	static let liuKang = UIColor(red: 0.95, green: 0.32, blue: 0.16, alpha: 1)
}

extension Character {
	@MainActor var color: UIColor {
		switch self {
		case .scorpion: Colors.scorpion
		case .subZero: Colors.subZero
		case .jade: Colors.jade
		case .sektor: Colors.sektor
		case .cyrax: Colors.cyrax
		case .kitana: Colors.kitana
		case .smoke: Colors.smoke
		case .liuKang: Colors.liuKang
		}
	}
}
