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
class Blockeds: NSObject {

	private var refreshUIBlockeds = false
	private var firebase: DatabaseReference?

	//---------------------------------------------------------------------------------------------------------------------------------------------
	static let shared: Blockeds = {
		let instance = Blockeds()
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

		let lastUpdatedAt = DBBlocked.lastUpdatedAt()

		firebase = Database.database().reference(withPath: FBLOCKED_PATH).child(FUser.currentId())
		let query = firebase?.queryOrdered(byChild: FBLOCKED_UPDATEDAT).queryStarting(atValue: lastUpdatedAt + 1)

		query?.observe(DataEventType.childAdded, with: { snapshot in
			if let blocked = snapshot.value as? [String: Any] {
				if (blocked[FBLOCKED_CREATEDAT] as? Int64 != nil) {
					DispatchQueue(label: "Blockeds").async {
						self.updateRealm(blocked: blocked)
						self.refreshUIBlockeds = true
					}
				}
			}
		})

		query?.observe(DataEventType.childChanged, with: { snapshot in
			if let blocked = snapshot.value as? [String: Any] {
				if (blocked[FBLOCKED_CREATEDAT] as? Int64 != nil) {
					DispatchQueue(label: "Blockeds").async {
						self.updateRealm(blocked: blocked)
						self.refreshUIBlockeds = true
					}
				}
			}
		})
	}

	//---------------------------------------------------------------------------------------------------------------------------------------------
	func updateRealm(blocked: [String: Any]) {

		let realm = try! Realm()
		try! realm.write {
			realm.create(DBBlocked.self, value: blocked, update: .modified)
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

		if (refreshUIBlockeds) {
			NotificationCenter.post(notification: NOTIFICATION_REFRESH_BLOCKEDS)
			refreshUIBlockeds = false
		}
	}
}
