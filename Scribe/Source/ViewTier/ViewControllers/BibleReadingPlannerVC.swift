//
//  BibleReadingPlannerVC.swift
//  Scribe
//
//  Created by Mikael Son on 9/8/17.
//  Copyright © 2017 Mikael Son. All rights reserved.
//

import UIKit

fileprivate let sectionInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

class BibleReadingPlannerVC: UITableViewController, BibleMarkChaptersVCDelegate {
    
    var bibleDataSource = [BibleVOM]()
    var plannerDataSource = [PlannerDataVOM]()
    var markChapterWindow: UIWindow?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super .init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.addObservers()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.addObservers()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        self.commonInit()
        self.fetchData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: Helper Functions
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateReadChapters), name: bibleChaptersUpdated, object: nil)
    }
    
    private func commonInit() {
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 70
        self.tableView.separatorStyle = .none
        
        let bottomView = UIView()
        bottomView.frame = CGRect(x: 0, y: 0, width: self.tableView.frame.width, height: 1)
        bottomView.backgroundColor = UIColor.bookCellSeparatorColor
        self.tableView.tableFooterView = bottomView
    }
    
    private func fetchData() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.bibleDataSource = BibleFactory.getAllList()
            self.fetchChapterCounterData()
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    private func fetchChapterCounterData() {
        let cmd = FetchBiblePlannerDataCommand()
        cmd.onCompletion { result in
            switch result {
            case .success(let array):
                if array.count > 0 {
                    self.plannerDataSource = array
                } else {
                    var fetchingData = [PlannerDataVOM]()
                    for model in self.bibleDataSource {
                        fetchingData.append(PlannerDataVOM(bookName: model.engName, chaptersReadCount: [Int](repeating: 0, count: model.chapters)))
                    }
                    self.plannerDataSource = fetchingData
                }
            case .failure:
                break
            }
        }
        cmd.execute()
    }
    
    @objc private func updateReadChapters(notification: Notification) {
        guard
            let dict = notification.object as? [Int: Bool],
            let userInfo = notification.userInfo as? [String: Int],
            let identifier = userInfo["identifier"]
        else {
            return
        }
        
        var plannerDataVOM = self.plannerDataSource[identifier]
        var chapterDataArray = plannerDataVOM.chaptersReadCount
        
        for object in dict {
            chapterDataArray[object.key] = chapterDataArray[object.key] + 1
        }
        plannerDataVOM.chaptersReadCount = chapterDataArray
        self.plannerDataSource[identifier] = plannerDataVOM
        
        let indexPath = IndexPath(row: identifier, section: 0)
        self.tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    private func presentMarkingWindow(with bookModel: BibleVOM, plannerDataVOM: PlannerDataVOM, identifier: Int) {
        let storyboard = UIStoryboard(name: "BibleReadingPlanner", bundle: nil)
        
        guard
            let vc = storyboard.instantiateViewController(withIdentifier: "BibleMarkChaptersVC") as? BibleMarkChaptersVC
        else {
            return
        }
        vc.delegate = self
        vc.bookModel = bookModel
        vc.bookIdentifier = identifier
        vc.plannerDataVOM = plannerDataVOM
        
        let window = UIWindow()
        window.windowLevel = window.windowLevel + 10
        window.backgroundColor = .clear
        window.rootViewController = vc
        window.makeKeyAndVisible()
        window.alpha = 0
        self.markChapterWindow = window
        UIView.animate(withDuration: 0.3) {
            window.alpha = 1
        }
    }
    
    // MARK: - Table view data source
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.bibleDataSource.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            self.bibleDataSource.count > 0,
            self.plannerDataSource.count > 0
        else {
            return UITableViewCell()
        }
        
        let model = self.bibleDataSource[indexPath.row]
        let chapterCounter = self.plannerDataSource[indexPath.row]
        
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: "BookCell", for: indexPath) as? BookCell
            else {
                return UITableViewCell()
        }
        
        cell.populate(with: model, and: chapterCounter)
        cell.selectionStyle = .none
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let bookModel = self.bibleDataSource[indexPath.row]
        let chapterCounterModel = self.plannerDataSource[indexPath.row]
        self.presentMarkingWindow(with: bookModel, plannerDataVOM: chapterCounterModel, identifier: indexPath.row)
    }
    
    
    // MARK: IBAction Functions
    
    func backgroundTappedToDismiss() {
        UIView.animate(withDuration: 0.3, animations: { 
            self.markChapterWindow?.alpha = 0
        }) { (_) in
            self.markChapterWindow = nil
        }
        
    }
}
