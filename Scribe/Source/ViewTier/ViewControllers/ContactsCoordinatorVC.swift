//
//  ContactsCoordinatorVC.swift
//  Scribe
//
//  Created by Mikael Son on 5/12/17.
//  Copyright © 2017 Mikael Son. All rights reserved.
//

import UIKit

import FontAwesomeKit
import FirebaseDatabase


public let defaultContatIndex = 0

public enum ContactType {
    case list
    case group
}

fileprivate let sectionInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
fileprivate let itemsPerRow: CGFloat = 2

class ContactsCoordinatorVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchResultsUpdating, UISearchBarDelegate, ContactSearchControllerDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    var contactSearchController: ContactSearchController!
    var searchController = UISearchController(searchResultsController: nil)
    
    public var contactDataSource = [ContactVOM]()
    internal var filteredDataSource = [ContactVOM]()
    internal var groupDataSource = [ContactGroupVOM]()
    internal var contactType: ContactType = .list
    
    let interactor = Interactor()
    
    @IBOutlet weak var contactListView: UIView!
    @IBOutlet weak var contactGroupView: UIView!
    @IBOutlet weak var groupButton: UIButton!
    @IBOutlet weak var barButton: UIBarButtonItem!
    
    // MARK: UIViewController 
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    override func viewDidLoad() {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.none
//        self.configureCustomSearchController()
        self.initSearchControl()
        self.initializeNavBarItems()
        self.initializeTabBarItems()
        
        self.initObservers()
        
        self.tableView.setContentOffset(CGPoint(x: 0, y: (self.tableView.tableHeaderView?.frame.size.height)!), animated: false)
        
//        self.fetchContactDataSource()
    }
    
    // MARK: Lifecycle Functions
    
    @IBAction func unwindToContactCoordinator(segue: UIStoryboardSegue) {
        
    }
    
    // MARK: Private Functions
    
    private func commonInit() {
        self.fetchGroupDataSource()
    }
    
    private func initializeNavBarItems() {
        self.barButton.tintColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
//        let item = self.navigationController?.navigationItem.rightBarButtonItems
//        item?.tintColor =
//        self.groupButton.setTitle("\u{f009}", for: .normal)
//        self.groupButton.setTitleColor(UIColor.scribePintInfoTitleColor, for: .normal)
    }
    
    private func initializeTabBarItems() {
        let settingsIcon = FAKMaterialIcons.settingsIcon(withSize: 27)
        let contactIcon = FAKIonIcons.iosContactIcon(withSize: 30)
        if let tabBarItems = self.tabBarController?.tabBar.items {
            tabBarItems[0].image = contactIcon?.image(with: CGSize(width: 30, height: 30))
            tabBarItems[1].image = settingsIcon?.image(with: CGSize(width: 30, height: 30))
        }
    }
    
    private func fetchContactDataSource() {
        
//        
//        let cmd = FetchContactsCommand()
//        cmd.onCompletion { result in
//            switch result {
//            case .success(let array):
////                callback(.success(array))
//                break
//            case .failure(let error):
////                callback(.failure(error))
//                break
//            }
//        }
//        cmd.execute()
    }
    
    // MARK : IBAction Methods
    
    @IBAction func buttonTapped(_ sender: UIBarButtonItem) {
        if sender.tintColor == #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1) {
            sender.tintColor = #colorLiteral(red: 0.3653209209, green: 0.3969068825, blue: 0.4392091632, alpha: 1)
            self.tableView.isHidden = true
            self.collectionView.isHidden = false
        } else {
            sender.tintColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
            self.tableView.isHidden = false
            self.collectionView.isHidden = true
        }
        
    }
    @IBAction func groupButtonTapped(_ sender: Any) {
        guard
            let button = sender as? UIButton
            else {
                return
        }
        
        button.isSelected = !button.isSelected
        
        print(button.state)
        if !button.isSelected {
            self.contactType = .list
            
            self.tableView.isHidden = false
            self.collectionView.isHidden = true
        } else {
            self.contactType = .group
            
            self.tableView.isHidden = true
            self.collectionView.isHidden = false
        }
    }
    
    // MARK: Firebase Related Functions
    
    private func initObservers() {
        let ref = Database.database().reference(fromURL: AppConfiguration.baseURL)
        let contactRef = ref.child("contacts")
        
        contactRef.observe(.childAdded, with: { snap in
            guard
                let json = snap.value as? JSONObject
                else {
                    return
            }
            
            let contactsNameRef = ref.child("contacts_name")
            let group = json["group"] as? String
            let teacher = json["teacher"] as? Bool
            let choir = json["choir"] as? Bool
            let translator = json["translator"] as? Bool
            let engName = json["name_eng"] as? String
            let korName = json["name_kor"] as? String
            contactsNameRef.child(snap.key).setValue(
                ["name_eng": engName as Any,
                 "name_kor": korName as Any,
                 "group": group as Any,
                 "teacher": teacher as Any,
                 "choir": choir as Any,
                 "translator": translator as Any
                ])
            
        })
        
        contactRef.observe(.childRemoved, with: { snap in
            let contactsNameRef = ref.child("contacts_name")
            contactsNameRef.child(snap.key).removeValue()
        })
    }
    
    // MARK: UITableViewDataSource Functions
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let contactModel: ContactVOM
        if self.filteredDataSource.count > 0 {
            print(indexPath.row)
            contactModel = self.filteredDataSource[indexPath.row]
        } else {
            contactModel = self.contactDataSource[indexPath.row]
        }
        
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as? ContactCell
            else {
                return UITableViewCell()
        }
        
        self.populate(cell, with: contactModel)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.searchController.isActive && self.searchController.searchBar.text != "" {
//        if self.contactSearchController.contactSearchBar.text != "" {
            return self.filteredDataSource.count
        }
        return self.contactDataSource.count
    }
    
    // MARK: CollectionViewController
    
    private func fetchGroupDataSource() {
        let cmd = FetchContactGroupCommand()
        cmd.onCompletion { result in
            switch result {
            case .success(let array):
                self.groupDataSource = array
                self.collectionView.reloadData()
            case .failure(_):
                //                callback(.failure(error))
                break
            }
        }
        cmd.execute()
    }
    
    //    override public func loadObjectDataSource(_ callback: @escaping (AsyncResult<ObjectDataSource<Any>>) -> Void) {
    //        let cmd = FetchContactGroupCommand()
    //        cmd.onCompletion(do: callback)
    //        cmd.execute()
    //    }
    
    // MARK: UICollectionViewDataSource Functions
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.groupDataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let groupModel = self.groupDataSource[indexPath.row]
        
        guard
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ContactGroupCell", for: indexPath) as? ContactGroupCell
            else {
                return UICollectionViewCell()
        }
        
        self.populate(cell, with: groupModel, and: self.contactDataSource)
        
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        return CGSize(width: widthPerItem, height: widthPerItem)
    }
    
    
    // MARK: Helper Function
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "coordinatorToContactList" {
            guard
                let vc = segue.destination as? ContactListVC
                else {
                    return
            }
            
            vc.contactDataSource = self.contactDataSource
        } else if segue.identifier == "coordinatorToContactGroup" {
            guard
                let vc = segue.destination as? ContactGroupVC
                else {
                    return
            }
            
            vc.contactDataSource = self.contactDataSource
        } else if segue.identifier == "coordinatorToGroupContacts" {
            guard
                let vc = segue.destination as? GroupContactListVC,
                let cell = sender as? ContactGroupCell
                else {
                    return
            }
            
            vc.contactDataSource = cell.contacts
            vc.lookupKey = cell.lookupKey
        } else if segue.identifier == "coordinatorToContactDetail" {
            guard
                let vc = segue.destination as? ContactDetailVC,
                let cell = sender as? ContactCell
                else {
                    return
            }
            
            vc.lookupKey = cell.lookupKey
            vc.parentVC = "ContactListVC"
        }
        
        if let destinationViewController = segue.destination as? ContactDetailVC {
            destinationViewController.transitioningDelegate = self
            destinationViewController.interactor = interactor
        }
    }
    
    private func populate(_ cell: ContactCell, with model: ContactVOM) {
        cell.commonInit()
        cell.lookupKey = model.id
        cell.nameLabel.text = model.name
    }
    
    private func populate(_ cell: ContactGroupCell, with model:ContactGroupVOM, and contacts:[ContactVOM]) {
        cell.lookupKey = model.type
        cell.commonInit()
        print(model.type)
        switch model.type {
        case .Fathers:
            cell.cellBackgroundImage.backgroundColor = UIColor.scribeColorGroup1
            cell.groupNameLabel.textColor = UIColor.scribeGray
            cell.groupNameLabel.text = GroupName.Fathers_Group
            
            let filtered = contacts.filter({ (vom) -> Bool in
                if vom.group != GroupName.Fathers_Group {
                    return false
                } else {
                    return true
                }
            })
            cell.countLabel.text = "\(filtered.count)"
            cell.contacts = filtered
            break
        case .YoungAdults:
            cell.cellBackgroundImage.backgroundColor = UIColor.scribeColorGroup5
            cell.groupNameLabel.textColor = UIColor.scribeGray
            cell.groupNameLabel.text = GroupName.YA_Group
            //            cell.cellBackgroundImage.image = UIImage(named: "YA_Group_Image")
            
            let filtered = contacts.filter({ (vom) -> Bool in
                if vom.group != GroupName.YA_Group {
                    return false
                } else {
                    return true
                }
            })
            cell.countLabel.text = "\(filtered.count)"
            cell.contacts = filtered
            break
        case .Mothers:
            cell.cellBackgroundImage.backgroundColor = UIColor.scribeColorGroup4
            cell.groupNameLabel.textColor = UIColor.scribeGray
            cell.groupNameLabel.text = GroupName.Mothers_Group
            //            cell.cellBackgroundImage.image = UIImage(named: "Mothers_Group_Image")
            
            let filtered = contacts.filter({ (vom) -> Bool in
                if vom.group != GroupName.Mothers_Group {
                    return false
                } else {
                    return true
                }
            })
            cell.countLabel.text = "\(filtered.count)"
            cell.contacts = filtered
            break
        case .Teachers:
            cell.cellBackgroundImage.backgroundColor = UIColor.scribeColorGroup2
            cell.groupNameLabel.textColor = UIColor.scribeGray
            cell.groupNameLabel.text = GroupName.Teachers_Group
            
            let filtered = contacts.filter({ (vom) -> Bool in
                let result = vom.teacher ? true : false
                return result
            })
            cell.countLabel.text = "\(filtered.count)"
            cell.contacts = filtered
            break
        case .Choir:
            cell.cellBackgroundImage.backgroundColor = UIColor.scribeColorGroup6
            cell.groupNameLabel.textColor = UIColor.scribeGray
            cell.groupNameLabel.text = GroupName.Choir_Group
            
            let filtered = contacts.filter({ (vom) -> Bool in
                let result = vom.choir ? true : false
                return result
            })
            cell.countLabel.text = "\(filtered.count)"
            cell.contacts = filtered
            break
        case .ChurchSchool:
            cell.cellBackgroundImage.backgroundColor = UIColor.scribeColorGroup3
            cell.groupNameLabel.textColor = UIColor.scribeGray
            cell.groupNameLabel.text = GroupName.Church_School
            
            let filtered = contacts.filter({ (vom) -> Bool in
                if vom.group != GroupName.Church_School {
                    return false
                } else {
                    return true
                }
            })
            cell.countLabel.text = "\(filtered.count)"
            cell.contacts = filtered
            break
        case .Translators:
            cell.cellBackgroundImage.backgroundColor = UIColor.scribeColorGroup7
            cell.groupNameLabel.textColor = UIColor.scribeGray
            cell.groupNameLabel.text = GroupName.Translators_Group
            
            let filtered = contacts.filter({ (vom) -> Bool in
                let result = vom.translator ? true : false
                return result
            })
            cell.countLabel.text = "\(filtered.count)"
            cell.contacts = filtered
            break
        }
    }
    
    func configureCustomSearchController() {
        guard let font = UIFont(name: "Futura", size: 16) else { return }
        self.contactSearchController = ContactSearchController(searchResultsController: self, searchBarFrame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 50), searchBarFont: font, searchBarTextColor: UIColor.orange, searchBarTintColor: UIColor.black)
        
        self.contactSearchController.hidesNavigationBarDuringPresentation = true
        self.contactSearchController.searchResultsUpdater = self
        definesPresentationContext = true
        self.contactSearchController.contactSearchBar.showsCancelButton = false
        self.contactSearchController.dimsBackgroundDuringPresentation = false
//        self.contactSearchController.customSearchBar.placeholder = "Search in this awesome bar..."
        self.contactSearchController.contactSearchBar.placeholder = "Search here..."
//        self.contactSearchController.contactSearchBar.delegate = self
        self.contactSearchController.customDelegate = self
        self.contactSearchController.contactSearchBar.sizeToFit()
        
        self.tableView.tableHeaderView = self.contactSearchController.contactSearchBar
    }
    
    private func initSearchControl() {
        self.searchController.searchResultsUpdater = self
        self.searchController.searchBar.delegate = self
        self.searchController.dimsBackgroundDuringPresentation = false
        self.searchController.searchBar.tintColor = UIColor.darkGray
        self.searchController.searchBar.barTintColor = UIColor.white
        self.searchController.searchBar.layer.borderWidth = 0

        
        definesPresentationContext = true
        
        self.searchController.searchBar.placeholder = "Find contacts here.."
        self.searchController.searchBar.sizeToFit()
        
        self.tableView.tableHeaderView = self.searchController.searchBar
    }
    
    // MARK: ConstactSearchController Delegate Functions
    
    func didStartSearching() {
        self.tableView.reloadData()
    }
    
    func didTapOnCancelButton() {
        
    }
    
    func didTapOnSearchButton() {
        
    }
    
    func didChangeSearchText(searchText: String) {
        self.filteredDataSource = self.contactDataSource.filter({ (model) -> Bool in
            return model.name.lowercased().contains(searchText.lowercased())
        })
        tableView.reloadData()
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }
    
    func filterContentForSearchText(_ searchText: String?) {
        guard let searchKeyword = searchText else { return }
        self.filteredDataSource = self.contactDataSource.filter({ (model) -> Bool in
            return model.name.lowercased().contains(searchKeyword.lowercased())
        })
        tableView.reloadData()
    }
}


extension ContactsCoordinatorVC: UIViewControllerTransitioningDelegate {
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissAnimator()
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactor.hasStarted ? interactor : nil
    }
}


