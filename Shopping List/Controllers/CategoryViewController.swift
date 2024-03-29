//
//  CategoryViewController.swift
//  Shopping List
//
//  Created by Admin on 30/11/2022.
//  Copyright © 2022 Pavel Moroz. All rights reserved.
//

import UIKit
import CoreData

let cellReuseIdentifier = "CategoryCell"

enum SectionCategory: Int, CaseIterable {
    
    case categorySection
    
    func desription(categoryCount: Int) -> String {
        switch self {
            
        case .categorySection:
            return "\(categoryCount) category"
        }
    }
}

class CategoryViewController: UIViewController {
    
    // MARK: - Properties
    @IBOutlet weak var addCategoryButton: UIBarButtonItem!
    
    private let searchController = UISearchController(searchResultsController: nil)
    private var categoryItems: [CategoryItem] = []
    private var categories: [Category] = []
    private var styleDark: Bool = false
    private let viewContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<SectionCategory, CategoryItem>!
    
    let appID = "1512179736" // Идентификатор вашего приложения в App Store
    var timer: Timer?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if  myDefaults.bool(forKey: "ratingLaterTimer") == false  {
            scheduleRatingAlert(timeInterval: 3) // почти сразу
        } else if  myDefaults.bool(forKey: "ratingLaterTimer") == true && myDefaults.integer(forKey: "sessionCount") % 5 == 0 {
            scheduleRatingAlert(timeInterval: 3) // Почти сразу
        }
        
        setupSearchBar()

        fetchData()
        setupCollectionView()
        setupUI()
        createDataSourse()
        reloadData(with: nil)
        
        showLastList()
        NotificationCenter.default.addObserver(self,
                                                     selector: #selector(didBecomeActive),
                                                     name: UIApplication.didBecomeActiveNotification,
                                                     object: nil)
        
    }
    
    
    // MARK: - Action
    
    
    @IBAction func addButtonPressed(_ sender: UIBarButtonItem) {
        
        showAlert(title: NSLocalizedString("AddingCategory", comment: ""), message: NSLocalizedString("EnterName", comment: ""))
    }
    
    @objc func handleLongPressGesture(_ gesture: UILongPressGestureRecognizer) {
        guard let collectionView = collectionView else { return }
        
        switch gesture.state {
        case .began:
            
            Vibration.success.vibrate()
            guard let targetIndexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else  { return }
            
            let index = targetIndexPath.row
            showEditAlert(title: NSLocalizedString("EditCaterogy", comment: ""), message: NSLocalizedString("WhatToChange", comment: ""), category: categories[index])
            
            
            collectionView.beginInteractiveMovementForItem(at: targetIndexPath)
        case .changed:
            
            collectionView.updateInteractiveMovementTargetPosition(gesture.location(in: collectionView))
            
        case .ended:
            
            collectionView.endInteractiveMovement()
        default:
            collectionView.cancelInteractiveMovement()
        }
    }
    
    @objc func didBecomeActive(_ notification: Notification) {
        DispatchQueue.main.async {
            self.setupUI()
        }
    }
        
    
    // MARK: - Helper
    
    private func showLastList() {
        
        if categories.count > 0 {
            self.performSegue(withIdentifier: "showLastList", sender: self)
        }
    }
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createCompositionalLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(CategoryCell.self, forCellWithReuseIdentifier: CategoryCell.reuseId)
        collectionView.delegate = self
        //collectionView.dragDelegate = self
        
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
    
        collectionView.addGestureRecognizer(gesture)
        
        view.addSubview(collectionView)
    }
    
    private func setupSearchBar() {
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self

    }
    
    private func reloadData(with searchText: String?) {
        
        fetchData()
        
        let filtered = categoryItems.filter { (category) -> Bool in
            category.contains(filter: searchText)
        }
        var snapshot = NSDiffableDataSourceSnapshot<SectionCategory, CategoryItem>()
        snapshot.appendSections([.categorySection])
        snapshot.appendItems(filtered, toSection: .categorySection)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }
    
    
    private func setupUI() {
        
        title = NSLocalizedString("Categories", comment: "")
        // navigationController?.navigationBar.
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        if self.traitCollection.userInterfaceStyle  == .dark {
            styleDark = true
        } else {
            styleDark = false
        }
        
        if styleDark {
            navigationController?.navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
            addCategoryButton.tintColor = .white
            navigationController?.navigationBar.tintColor = .white
            tabBarController?.tabBar.unselectedItemTintColor = .white
           // tabBarController?.tabBar.tintColor = .systemOrange
            //collectionView.backgroundColor = .black
            
            
        } else {
            navigationController?.navigationBar.barStyle = .default
            navigationController?.navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.systemOrange]
            addCategoryButton.tintColor = .black
            navigationController?.navigationBar.tintColor = .black
            tabBarController?.tabBar.unselectedItemTintColor = .black
            //tabBarController?.tabBar.tintColor = .systemOrange
            //collectionView.backgroundColor = .white
        }
    }
}


// MARK: - Setup layout
extension CategoryViewController {
    
    private func createCompositionalLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            
            guard let section = SectionCategory(rawValue: sectionIndex) else { fatalError("Unknown section kind") }
            
            switch section {
                
            case .categorySection:
                return self.createCategorySection()
            }
        }
        
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 20
        layout.configuration = config
        
        return layout
    }
    
    private func createCategorySection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(0.6))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
        
        let spacing = CGFloat(15)
        group.interItemSpacing = .fixed(spacing)
        
        let section = NSCollectionLayoutSection(group: group)
        
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets.init(top: 16, leading: 15, bottom: 0, trailing: 15)
        
        return section
    }
}

// MARK: - UICollectionViewDiffableDataSource
extension CategoryViewController {
    private func createDataSourse() {
        
        dataSource = UICollectionViewDiffableDataSource<SectionCategory, CategoryItem>(collectionView: collectionView, cellProvider: { (collectionView, indexPath, category) -> UICollectionViewCell? in
            
            guard let section = SectionCategory(rawValue: indexPath.section) else { fatalError("Unknown section kind") }
            
            switch section {
                
            case .categorySection:
                
                return self.configure(collectionView: collectionView, cellType: CategoryCell.self, with: category, for: indexPath)
            }
        })
    }
}

//MARK: - UISearchBarDelegate
extension CategoryViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        reloadData(with: searchText)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        reloadData(with: nil)
    }
}

//MARK: - CategoryViewController Configure
extension CategoryViewController {
    
    func configure<T: SelfConfiguringCell, U: Hashable>(collectionView: UICollectionView, cellType: T.Type, with value: U, for indexPath: IndexPath) -> T {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellType.reuseId, for: indexPath) as? T else { fatalError("Unable to dequeue \(cellType)") }
        cell.configure(with: value)
        return cell
    }
}

// MARK: - CoreData

extension CategoryViewController {
    
    private func fetchData() {
        
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        
        let sort = NSSortDescriptor(key: "order", ascending: true)
        fetchRequest.sortDescriptors = [sort]
        do {
            categories = try viewContext.fetch(fetchRequest)
            
            categoryItems = categories.map { CategoryItem(categoryStorage: $0) }
            
            
        } catch let error {
            print(error)
        }
    }
    
    private func save(_ categoryName: String) {
        guard let entityDescription = NSEntityDescription.entity(
            forEntityName: "Category",
            in: viewContext
        )
        else { return }
        
        let categor = NSManagedObject(entity: entityDescription, insertInto: viewContext) as! Category
        categor.name = categoryName.capitalizingFirstLetter()
        let minList = categories.max { a, b in a.order < b.order }
        
        categor.order = (minList?.order ?? 0) + 1
        
        do {
            try viewContext.save()
            categories.append(categor)
        } catch let error {
            print(error)
        }
        DispatchQueue.main.async {
            self.reloadData(with: nil)
        }
    }
    
    private func delete(_ categoryName: Category) {
        
        viewContext.delete(categoryName)
        
        let myLastListId = UserDefaults.standard.integer(forKey: "lastList")
        
        if myLastListId == categoryName.order - 1  {
            myDefaults.removeObject(forKey: "lastList")
        }
        
        
        do {
            try viewContext.save()
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.reloadData(with: nil)
        }
    }
}

// MARK: - Alert controller
extension CategoryViewController {
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let saveAction = UIAlertAction(title: NSLocalizedString("Add", comment: ""), style: .default) { _ in
            guard let task = alert.textFields?.first?.text, !task.isEmpty else {
                print("The text field is empty")
                return
            }
            self.save(task)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .destructive)
        alert.addTextField { [weak self] (textFeild) in
            textFeild.delegate = self
        }
        alert.addAction(cancelAction)
        alert.addAction(saveAction)
        present(alert, animated: true)
    }
}

extension CategoryViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxLength = 30
        let currentString: NSString = textField.text! as NSString
        let newString: NSString =
        currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }
}

extension CategoryViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            myDefaults.set(indexPath.row, forKey: "lastList")
                performSegue(withIdentifier: "goToItems", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    
        let destinationVC = segue.destination as! ShoppingListTableViewController
        
        if segue.identifier ==  "goToItems" {
            
            if let indexPath = collectionView.indexPathsForSelectedItems?.first?.row {
                destinationVC.selectedCategory = categories[indexPath]
            }
            
        } else if segue.identifier == "showLastList" {
            let lastListID = UserDefaults.standard.integer(forKey: "lastList")
            destinationVC.selectedCategory = categories[lastListID]
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.5) {
            cell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.5) {
            cell?.transform = .identity
        }
    }
}


extension CategoryViewController {
    
    private func showEditAlert(title: String, message: String, category: Category) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let saveAction = UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .default) { _ in
            guard let task = alert.textFields?.first?.text, !task.isEmpty else {
                
                return
            }
                                    
            self.updateCategory(task, order: Int(category.order))
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        
        
        let deleteAction = UIAlertAction(title: NSLocalizedString("DeletingCategory", comment: ""), style: .destructive) { _ in

            self.deleteListInBusketAleft(category: category)
        }
        
        
        alert.addTextField { [weak self] (textFeild) in
            textFeild.delegate = self
        }
        alert.textFields?.first?.text = category.name

        
        alert.addAction(cancelAction)
        alert.addAction(saveAction)
        alert.addAction(deleteAction)

        present(alert, animated: true)
    
    }
    
    private func updateCategory(_ categoryName: String?, order: Int) {
        
        viewContext.setValue(categoryName, forKey: "name")
        
        for (_,list) in categories.enumerated() {
            
            if list.order == Int32(order) {
                list.name = categoryName
                
                DispatchQueue.main.async {
                    self.reloadData(with: nil)
                }
            }
        }
        do {
            try viewContext.save()
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.reloadData(with: nil)
        }
    }

    private func deleteListInBusketAleft(category: Category) {
        let alert = UIAlertController(title: NSLocalizedString("DeletingCategory", comment: ""), message: NSLocalizedString("AreYouSureDeleteCategory", comment: ""), preferredStyle: .alert)
        let saveAction = UIAlertAction(title: NSLocalizedString("Del", comment: ""), style: .default) { _ in

            self.delete(category)
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .destructive)
        alert.addAction(cancelAction)
        alert.addAction(saveAction)
        present(alert, animated: true)
    }
}


// MARK: - Rating
extension CategoryViewController {
    
    func scheduleRatingAlert(timeInterval: TimeInterval) {
        
        
        timer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(promptForRating), userInfo: nil, repeats: false)
        
    }
    
    
    
    @objc func promptForRating() {
        let alertController = UIAlertController(title: NSLocalizedString("EvaluateApp", comment: ""), message: NSLocalizedString("IfYouLike", comment: ""), preferredStyle: .alert)
        
        let rateAction = UIAlertAction(title: NSLocalizedString("RateIt", comment: ""), style: .default) { [weak self] _  in
            guard let self = self else { return }
            self.rateApp(id: self.appID)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("NotNow", comment: ""), style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            myDefaults.set(true, forKey: "ratingLaterTimer")
            print("myDefaults \(myDefaults.bool(forKey: "ratingLaterTimer"))")
        }

        
        alertController.addAction(cancelAction)
        alertController.addAction(rateAction)
        
        present(alertController, animated: true, completion: nil)
    }

    func rateApp(id: String) {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id\(id)?mt=8&action=write-review") else { return }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }
}
