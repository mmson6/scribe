//
//  DataAccessor.swift
//  Scribe
//
//  Created by Mikael Son on 5/13/17.
//  Copyright © 2017 Mikael Son. All rights reserved.
//

import Foundation

import FirebaseDatabase


public typealias DataAccessorDMCallback<T> = (AsyncResult<T>) -> Void

fileprivate enum ClientError: Error {
    case FailedToLoadData
}

public final class DataAccessor {
    
    private let scribeClient = NetworkScribeClient(baseURL: AppConfiguration.baseURL)
    private let defaultStore = UserDefaultsStore()
    private let dataStore = LevelDBStore()
    var rootRef: DatabaseReference!
    
    // MARK: Global Functions
    
    public func clear() {
        self.defaultStore.clearAll()
        self.dataStore.clear()
    }
    
    internal func loadBiblePlannerData(callback: @escaping DataAccessorDMCallback<[PlannerDataDM]>) {
        let store = self.dataStore
        if let jsonArray = store.loadBiblePlannerData() {
            let modelArray = jsonArray.map({ (json) -> PlannerDataDM in
                let dm = PlannerDataDM(from: json)
                return dm
            })
            callback(.success(modelArray))
        } else {
            let modelArray = [PlannerDataDM]()
            callback(.success(modelArray))
        }
    }
    
    internal func loadContactDetails(_ request: FetchContactDetailRequest, callback: @escaping DataAccessorDMCallback<ContactInfoDM>) {
        let loadFromDataStore = { (store: LevelDBStore) -> JSONObject? in
            let id = request.id as Any
            return store.loadContact(with: id)
        }
        let loadFromScribeClient = { (client: ScribeClient, resultHandler: @escaping DataAccessorDMCallback<ContactInfoDM>) in
            client.fetchContactDetail(request, callback: resultHandler)
        }
        let save = { (store: LevelDBStore, object: JSONObject?) in
            store.save(contact: object)
        }
        
        self.loadDomainModelObject(
            loadFromDataStore: loadFromDataStore,
            loadFromScribeClient: loadFromScribeClient,
            save: save,
            callback: callback
        )
    }
    
    internal func loadContactGroups(callback: @escaping DataAccessorDMCallback<[ContactGroupDM]>) {
        let client = self.scribeClient
        client.fetchContactGroups { result in
            switch result {
            case .success(let array):
                callback(.success(array))
            case .failure(let error):
                callback(.failure(error))
            }
        }
    }
    
    internal func loadContacts(with ver: Int64 ,callback: @escaping DataAccessorDMCallback<[ContactDM]>) {
        let loadFromDataStore = { (store: LevelDBStore) -> JSONArray? in
            let defaultsStore = UserDefaultsStore()
            if defaultsStore.contactsNeedUpdate(ver) {
                return nil
            } else {
                return store.loadContacts()
            }
        }
        let loadFromScribeClient = { (client: ScribeClient, resultHandler: @escaping DataAccessorDMCallback<[ContactDM]>) in
            client.fetchContacts(callback: resultHandler)
        }
        let save = { (store: LevelDBStore, array: JSONArray?) in
            if let array = array {
                for object in array {
                    store.save(contact: object)
                }
            }
            store.save(contacts: array)
            
            // Update Local ContactsVer
            let defaultsStore = UserDefaultsStore()
            defaultsStore.saveContactsVer(ver)
        }

        self.loadDomainModelArray(
            loadFromDataStore: loadFromDataStore,
            loadFromScribeClient: loadFromScribeClient,
            save: save,
            callback: callback
        )
    }
    
    internal func loadContactsVersion(callback: @escaping DataAccessorDMCallback<Int64>) {
        let client = self.scribeClient
        client.fetchContactsVersion { result in
            switch result {
            case.success(let ver):
                callback(.success(ver))
            case .failure(let error):
                NSLog("Error occurred while fetching contactsVer:: \(error)")
                callback(.success(0))
            }
        }
    }
    
    internal func loadGroupContacts(_ request: FetchGroupContactsRequest, callback: @escaping DataAccessorDMCallback<[ContactDM]>) {
        let client = self.scribeClient
        client.fetchGroupContacts(request) { result in
            switch result {
            case .success(let array):
                callback(.success(array))
            case .failure(let error):
                callback(.failure(error))
            }
        }
    }
    
    internal func loadPlannerActivities(callback: @escaping DataAccessorDMCallback<[PlannerActivityDM]>) {
        let store = self.dataStore
        if let jsonArray = store.loadPlannerActivities() {
            let modelArray = jsonArray.map({ (json) -> PlannerActivityDM in
                let dm = PlannerActivityDM(from: json)
                return dm
            })
            callback(.success(modelArray))
        } else {
            let modelArray = [PlannerActivityDM]()
            callback(.success(modelArray))
        }
    }
    
    internal func loadPlannerLastActivity(callback: @escaping DataAccessorDMCallback<PlannerActivityDM>) {
        let store = self.dataStore
        if let jsonArray = store.loadPlannerActivities() {
            if let last = jsonArray.last {
                let dm = PlannerActivityDM(from: last)
                callback(.success(dm))
            } else {
                let error = ClientError.FailedToLoadData
                callback(.failure(error))
            }
        } else {
            let error = ClientError.FailedToLoadData
            callback(.failure(error))
        }
    }
    
    internal func loadPlannerGoal(callback: @escaping DataAccessorDMCallback<PlannerGoalDM>) {
        let store = self.dataStore
        if let json = store.loadPlannerGoal() {
            let dm = PlannerGoalDM(from: json)
            callback(.success(dm))
        } else {
            let error = ClientError.FailedToLoadData
            callback(.failure(error))
        }
    }
    
    internal func loadReadingPlanners(callback: @escaping DataAccessorDMCallback<[ReadingPlannerDM]>) {
        let store = self.dataStore
        // Wipe bible planner data
        store.save(plannerData: nil)
        
        if let jsonArray = store.loadReadingPlanners() {
            let modelArray = jsonArray.map({ json -> ReadingPlannerDM in
                let dm = ReadingPlannerDM(from: json)
                return dm
            })
            callback(.success(modelArray))
        } else {
            let error = ClientError.FailedToLoadData
            callback(.failure(error))
        }
    }
    
    internal func loadSignUpRequests(callback: @escaping DataAccessorDMCallback<[SignUpRequestDM]>) {
        let client = self.scribeClient
        client.fetchSignUpRequests { result in
            switch result {
            case.success(let array):
                callback(.success(array))
            case .failure(let error):
                callback(.failure(error))
            }
        }
    }
    
    internal func loadUserRequestsCount(callback: @escaping DataAccessorDMCallback<Int64>) {
        let client = self.scribeClient
        client.fetchUserRequestsCount { result in
            switch result {
            case.success(let count):
                callback(.success(count))
            case .failure:
                break
            }
        }
    }
    
    internal func removeBiblePlannerData(dm: PlannerActivityDM, callback: @escaping DataAccessorDMCallback<Bool>) {
        let store = self.dataStore
        if let jsonArray = store.loadBiblePlannerData() {
            let newArray = jsonArray.map({ (json) -> JSONObject in
                var plannerDataDM = PlannerDataDM(from: json)
                if plannerDataDM.bookName == dm.bookName {
                    for (key, _) in dm.chapterDict {
                        guard let count = plannerDataDM.chaptersReadCount[key] as? Int else { continue }
                        plannerDataDM.chaptersReadCount[key] = count - 1
                    }
                }
                return plannerDataDM.asJSON()
            })
            store.save(plannerData: newArray)
        }
        callback(.success(true))
    }
    
    internal func removePlannerActivity(dmArray: [PlannerActivityDM], callback: @escaping DataAccessorDMCallback<Bool>) {
        let store = self.dataStore
        let jsonArray = dmArray.map { (dm) -> JSONObject in
            return dm.asJSON()
        }
        store.save(plannerActivities: jsonArray)
        callback(.success(true))
    }
    
    internal func saveBiblePlannerData(dmArray: [PlannerDataDM], callback: @escaping DataAccessorDMCallback<Bool>) {
        let store = self.dataStore
        let jsonArray = dmArray.map { (dm) -> JSONObject in
            let json = dm.asJSON()
            return json
        }
        store.save(plannerData: jsonArray)
        callback(.success(true))
    }
    
    internal func savePlannerActivities(dmArray: [PlannerActivityDM], callback: @escaping DataAccessorDMCallback<Bool>) {
        let store = self.dataStore
        if let jsonArray = store.loadPlannerActivities() {
            var newArray = jsonArray
            let newJSONArray = dmArray.map({ (dm) -> JSONObject in
                return dm.asJSON()
            })
            newArray.append(contentsOf: newJSONArray)
            store.save(plannerActivities: newArray)
        } else {
            let newArray = dmArray.map({ (dm) -> JSONObject in
                return dm.asJSON()
            })
            store.save(plannerActivities: newArray)
        }
    }
    
    internal func savePlannerActivity(dm: PlannerActivityDM, callback: @escaping DataAccessorDMCallback<Bool>) {
        let store = self.dataStore
        if let jsonArray = store.loadPlannerActivities() {
            var newArray = jsonArray
            newArray.append(dm.asJSON())
            store.save(plannerActivities: newArray)
        } else {
            var jsonArray = [JSONObject]()
            jsonArray.append(dm.asJSON())
            store.save(plannerActivities: jsonArray)
        }
        callback(.success(true))
    }
    
    internal func savePlannerGoal(dm: PlannerGoalDM, callback: @escaping DataAccessorDMCallback<Bool>) {
        let store = self.dataStore
        let json = dm.asJSON()
        store.save(plannerGoal: json)
        callback(.success(true))
    }
    
    internal func saveReadingPlanners(dmArray: [ReadingPlannerDM], callback: @escaping DataAccessorDMCallback<Bool>) {
        let store = self.dataStore
        let jsonArray = dmArray.map { dm -> JSONObject in
            let json = dm.asJSON()
            return json
        }
        store.save(readingPlanners: jsonArray)
        callback(.success(true))
    }
    
    // MARK: Private Helper Funcitons
    
    private func loadDomainModelArray<T: JSONTransformable>(
        loadFromDataStore: (LevelDBStore) -> JSONArray?,
        loadFromScribeClient: (ScribeClient, @escaping DataAccessorDMCallback<[T]>) -> Void,
        save: @escaping (LevelDBStore, JSONArray) -> Void,
        callback: @escaping (AsyncResult<[T]>) -> Void
    ) {
        let store = self.dataStore
        let client = self.scribeClient
        if let jsonArray = loadFromDataStore(store) {
            let modelArray: [T] = jsonArray.map({ (jsonObject: JSONObject) -> T in
                let domainModel = T(from: jsonObject)
                return domainModel
            })
            callback(AsyncResult.success(modelArray))
        } else {
            loadFromScribeClient(client) { result in
                switch result {
                case .success(let modelArray):
                    let jsonArray = modelArray.map({ (model: T) -> JSONObject in
                        let jsonObject = model.asJSON()
                        return jsonObject
                    })
                    save(store, jsonArray)
                    callback(AsyncResult.success(modelArray))
                case .failure(let error):
                    callback(AsyncResult.failure(error))
                }
            }
        }
    }
    
    private func loadDomainModelObject<T: JSONTransformable>(
        loadFromDataStore: (LevelDBStore) -> JSONObject?,
        loadFromScribeClient: (ScribeClient, @escaping DataAccessorDMCallback<T>) -> Void,
        save: @escaping (LevelDBStore, JSONObject) -> Void,
        callback: @escaping (AsyncResult<T>) -> Void
        ) {
        let store = self.dataStore
        let client = self.scribeClient
        if let jsonObject = loadFromDataStore(store) {
            let domainModel = T(from: jsonObject)
            callback(AsyncResult.success(domainModel))
        } else {
            loadFromScribeClient(client) { result in
                switch result {
                case .success(let modelObject):
                    let jsonObject = modelObject.asJSON()
                    save(store, jsonObject)
                    callback(AsyncResult.success(modelObject))
                case .failure(let error):
                    callback(AsyncResult.failure(error))
                }
            }
        }
    }
}
