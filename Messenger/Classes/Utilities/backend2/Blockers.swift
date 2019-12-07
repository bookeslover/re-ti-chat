//
// Copyright (c) 2018 Related Code - http://relatedcode.com
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import RealmSwift

//-------------------------------------------------------------------------------------------------------------------------------------------------
class Blockers: NSObject {

	private var refreshUIBlockers = false
	private var firebase: DatabaseReference?

	//---------------------------------------------------------------------------------------------------------------------------------------------
	static let shared: Blockers = {
		let instance = Blockers()
		return instance
	} ()

	//---------------------------------------------------------------------------------------------------------------------------------------------
	override init() {

		super.init()

		NotificationCenter.addObserver(target: self, selector: #selector(initObservers), name: NOTIFICATION_APP_STARTED)
		NotificationCenter.addObserver(target: self, selector: #selector(initObservers), name: NOTIFICATION_USER_LOGGED_IN)
		NotificationCenter.addObserver(target: self, selector: #selector(actionCleanup), name: NOTIFICATION_USER_LOGGED_OUT)

		Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
			self.refreshUserInterface()
		}
	}

	// MARK: - Backend methods
	//---------------------------------------------------------------------------------------------------------------------------------------------
	@objc func initObservers() {

		if (FUser.currentId() != "") {
			if (firebase == nil) {
				createObservers()
			}
		}
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func createObservers() {

		let lastUpdatedAt = DBBlocker.lastUpdatedAt()

		firebase = Database.database().reference(withPath: FBLOCKER_PATH).child(FUser.currentId())
		let query = firebase?.queryOrdered(byChild: FBLOCKER_UPDATEDAT).queryStarting(atValue: lastUpdatedAt + 1)

		query?.observe(DataEventType.childAdded, with: { snapshot in
			if let blocker = snapshot.value as? [String: Any] {
				if (blocker[FBLOCKER_CREATEDAT] as? Int64 != nil) {
					DispatchQueue(label: "Blockers").async {
						self.updateRealm(blocker: blocker)
						self.refreshUIBlockers = true
					}
				}
			}
		})

		query?.observe(DataEventType.childChanged, with: { snapshot in
			if let blocker = snapshot.value as? [String: Any] {
				if (blocker[FBLOCKER_CREATEDAT] as? Int64 != nil) {
					DispatchQueue(label: "Blockers").async {
						self.updateRealm(blocker: blocker)
						self.refreshUIBlockers = true
					}
				}
			}
		})
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func updateRealm(blocker: [String: Any]) {

		let realm = try! Realm()
		try! realm.write {
			realm.create(DBBlocker.self, value: blocker, update: .modified)
		}
	}

	// MARK: - Cleanup methods
	//---------------------------------------------------------------------------------------------------------------------------------------------
	@objc func actionCleanup() {

		firebase?.removeAllObservers()
		firebase = nil
	}

	// MARK: - Notification methods
	//---------------------------------------------------------------------------------------------------------------------------------------------
	func refreshUserInterface() {

		if (refreshUIBlockers) {
			NotificationCenter.post(notification: NOTIFICATION_REFRESH_BLOCKERS)
			refreshUIBlockers = false
		}
	}
}
