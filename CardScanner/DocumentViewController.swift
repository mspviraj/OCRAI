//
//  DocumentViewController.swift
//  CardScanner
//
//  Created by Luke Van In on 2017/02/15.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit
import MapKit
import CoreData
import Contacts

private let basicCellIdentifier = "BasicCell"
private let addressCellIdentifier = "AddressCell"
private let imageCellIdentifier = "ImageCell"

class DocumentViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, TextCellDelegate {
    
    class Section {
        let title: String
        let type: FragmentType
        var values: [Fragment]
        
        init(title: String, type: FragmentType, values: [Fragment]) {
            self.title = title
            self.type = type
            self.values = values
        }
        
        @discardableResult func remove(at: Int) -> Fragment {
            let output = values.remove(at: at)
            updateOrdering(from: at)
            return output
        }
        
        func append(_ fragment: Fragment) {
            insert(fragment, at: values.count)
        }
        
        func insert(_ fragment: Fragment, at: Int) {
            fragment.type = type
            fragment.ordinality = Int32(at)
            values.insert(fragment, at: at)
            updateOrdering(from: at)
        }
        
        func updateOrdering() {
            updateOrdering(from: 0)
        }
        
        func updateOrdering(from: Int) {
            for i in from ..< values.count {
                values[i].ordinality = Int32(i)
            }
        }
    }

    var documentIdentifier: String!
    var coreData: CoreDataStack!
    
    private lazy var scanner: ScannerService = {
        let factory = DefaultServiceFactory()
        return ScannerService(
            factory: factory,
            coreData: self.coreData
        )
    }()
    
    private var document: Document?
    private var sections = [Section]()
    private var activeSections = [Int]()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var documentView: DocumentView!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var activityOverlayView: UIView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var actionsButtonItem: UIBarButtonItem!
    @IBOutlet weak var emptyContentPlaceholderView: UIView!
    
    @IBAction func onActionsAction(_ sender: Any) {
        document?.presentActions(from: self)
    }
    
    @IBAction func onScanAction(_ sender: Any) {
        if isEditing {
            setEditing(false, animated: true)
        }
        
        clearDocument() {
            DispatchQueue.main.async {
                self.scanDocument()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableViewAutomaticDimension
        navigationItem.rightBarButtonItems = [editButtonItem, actionsButtonItem]
        
        let headerHeight: CGFloat = 300
        
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: headerHeight))
        tableView.addSubview(headerView)
        
        headerView.translatesAutoresizingMaskIntoConstraints = false

        let heightConstraint = headerView.heightAnchor.constraint(equalToConstant: headerHeight)
        heightConstraint.priority = UILayoutPriorityRequired - 1

        NSLayoutConstraint.activate([
            heightConstraint,
            headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: headerHeight),
            headerView.topAnchor.constraint(lessThanOrEqualTo: topLayoutGuide.bottomAnchor),
            headerView.bottomAnchor.constraint(equalTo: tableView.topAnchor, constant: headerHeight),
            headerView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            headerView.widthAnchor.constraint(equalTo: tableView.widthAnchor)
            ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: false)
        loadDocument()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        tableView.setEditing(editing, animated: animated)

        // Disable all buttons except for edit/done button when editing.
        if let buttonItems = navigationItem.rightBarButtonItems {
            for buttonItem in buttonItems {
                if buttonItem != editButtonItem {
                    buttonItem.isEnabled = !editing
                }
            }
        }
        
        // Show scan button in edit mode.
//        scanButton.isHidden = !editing
        
        // Rows
        activeSections.removeAll()
        
        tableView.beginUpdates()
        
        if editing {
            
            // Edit mode.
            // Insert one additional row for each section.
            var indexPaths = [IndexPath]()
            var sectionIndices = IndexSet()
            for i in 0 ..< sections.count {
                let section = sections[i]
                activeSections.append(i)
                
                let count = section.values.count
                
                if count == 0 {
                    sectionIndices.insert(i)
                }
                else {
                    
                }
                
                let indexPath = IndexPath(row: count, section: i)
                indexPaths.append(indexPath)
            }
            tableView.insertSections(sectionIndices, with: .automatic)
            tableView.insertRows(at: indexPaths, with: .automatic)
        }
        else {
            // Non-edit mode.
            // Remove additional row for each section.
            var indexPaths = [IndexPath]()
            var sectionIndices = IndexSet()
            for i in 0 ..< sections.count {
                let section = sections[i]
                let count = section.values.count
                
                if count == 0 {
                    sectionIndices.insert(i)
                }
                else {
                    activeSections.append(i)
                }
                
                let indexPath = IndexPath(row: count, section: i)
                indexPaths.append(indexPath)
            }
            tableView.deleteRows(at: indexPaths, with: .automatic)
            tableView.deleteSections(sectionIndices, with: .automatic)
        }
        
        tableView.endUpdates()
        
        
        if let indexPaths = tableView.indexPathsForVisibleRows {
            for indexPath in indexPaths {
                let section = self.section(at: indexPath)
                if let cell = tableView.cellForRow(at: indexPath) as? BasicFragmentCell {
                    cell.editingEnabled = editing
                    configureCell(cell, withType: section.type)
                }
            }
        }
     
        updateContentState()
    }
    
    // MARK: Document
    
    private func clearDocument(completion: @escaping () -> Void) {
        sections.removeAll()
        activeSections.removeAll()
        tableView.reloadData()
        
        coreData.performBackgroundChanges { [documentIdentifier] (context) in
            
            let document = try context.documents(withIdentifier: documentIdentifier!).first
            
            if let fragments = document?.fragments?.allObjects as? [Fragment] {
                for fragment in fragments {
                    context.delete(fragment)
                }
            }
            
            do {
                try context.save()
            }
            catch {
                print("Cannot remove fragments from document: \(error)")
            }
            
            completion()
        }
    }
    
    private func loadDocument() {
        do {
            var sections = [Section]()
            
            let document = try coreData.mainContext.documents(withIdentifier: documentIdentifier).first
            self.document = document
            
            if let imageData = document?.thumbnailImageData {
                let image = UIImage(data: imageData as Data, scale: UIScreen.main.scale)
                documentView.image = image
            }
            else {
                documentView.image = nil
            }
            
            documentView.document = document
            
            func makeSection(title: String, type: FragmentType) -> Section {
                return Section(
                    title: title,
                    type: type,
                    values: document?.fragments(ofType: type) ?? []
                )
            }
            
            sections.append(makeSection(title: "Person", type: .person))
            sections.append(makeSection(title: "Organization", type: .organization))
            sections.append(makeSection(title: "Phone Number", type: .phoneNumber))
            sections.append(makeSection(title: "Email", type: .email))
            sections.append(makeSection(title: "URL", type: .url))
            sections.append(makeSection(title: "Address", type: .address))
            // FIXME: Add images
            // FIXME: Add dates
            
            self.sections = sections
            
            for i in 0 ..< sections.count {
                if sections[i].values.count > 0 {
                    self.activeSections.append(i)
                }
            }
            
            tableView.reloadData()
            updateContentState()
            
            if let document = document {
                if !document.didCompleteScan {
                    clearDocument() {
                        self.scanDocument()
                    }
                }
            }
        }
        catch {
            print("Cannot fetch document: \(error)")
        }
    }
    
    private func saveDocument() {
        
        // FIXME: Fetch and update fragments on background context to maintain synchronization.
        coreData.saveNow()
    }
    
    private func scanDocument() {
        scanner.scan(document: documentIdentifier) { (state) in
            DispatchQueue.main.async {
                self.handleScannerState(state)
            }
        }
    }
    
    private func handleScannerState(_ state: ScannerService.State) {
        switch state {
        case .pending:
            print("pending")
            
        case .active:
            print("active")
            scanButton.isHidden = true
            activityIndicatorView.startAnimating()
            activityOverlayView.isHidden = false
            
        case .completed:
            print("completed")
            scanButton.isHidden = false
            activityIndicatorView.stopAnimating()
            activityOverlayView.isHidden = true
            loadDocument()
        }
    }
    
    fileprivate func updateContentState() {
        let totalRows = countFragments()
        if totalRows == 0 {
            showPlaceholder()
        }
        else {
            hidePlaceholder()
        }
    }
    
    private func countFragments() -> Int {
        var count = 0
        for section in sections {
            count += section.values.count
        }
        return count
    }
    
    private func showPlaceholder() {
//        tableView.addSubview(emptyContentPlaceholderView)
//        NSLayoutConstraint.activate([
//            emptyContentPlaceholderView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
//            emptyContentPlaceholderView.widthAnchor.constraint(equalTo: view.widthAnchor),
//            emptyContentPlaceholderView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            emptyContentPlaceholderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            ])
    }
    
    private func hidePlaceholder() {
        emptyContentPlaceholderView.removeFromSuperview()
    }
    
    // MARK: Table view
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return activeSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfItems = self.section(at: section).values.count
        
        if isEditing {
            return numberOfItems + 1
        }
        else {
            return numberOfItems
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.section(at: section).title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = self.section(at: indexPath.section)
        
        if isEditing && (indexPath.row == section.values.count) {
            return self.tableView(tableView, cellForBlankTextFragmentOfType: section.type, at: indexPath)
        }
        
        let fragment = section.values[indexPath.row]
        
        switch fragment.type {
            
        case .face, .logo:
            return self.tableView(tableView, cellForImageFragment:fragment, at: indexPath)
            
        default:
            return self.tableView(tableView, cellForTextFragment:fragment, at: indexPath)
        }
    }
    
    private func tableView(_ tableView: UITableView, cellForBlankTextFragmentOfType type: FragmentType, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: basicCellIdentifier, for: indexPath) as! BasicFragmentCell
        
        let title: String
        switch type {
        case .address:
            title = "Address"
            
        case .email:
            title = "Email"
            
        case .face:
            title = "Name"
            
        case .logo:
            title = "Brand"
            
        case .note:
            title = "Note"
            
        case .organization:
            title = "Organization"
            
        case .person:
            title = "Name"
            
        case .phoneNumber:
            title = "Phone Number"
            
        case .url:
            title = "URL"
            
        case .unknown:
            title = "Text"
        }
        cell.contentTextField.placeholder = title
        cell.editingEnabled = true
        configureCell(cell, withType: type)
        cell.accessoryType = .none
        cell.editingAccessoryType = .none
        cell.delegate = self
        
        return cell
    }
    
    private func tableView(_ tableView: UITableView, cellForTextFragment fragment: Fragment, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: basicCellIdentifier, for: indexPath) as! BasicFragmentCell
        cell.delegate = self
        cell.contentTextField.text = fragment.value
        cell.editingEnabled = isEditing
        configureCell(cell, withType: fragment.type)
        cell.showsReorderControl = true
        
        cell.accessoryType = .none
        cell.editingAccessoryType = .none
        
        return cell
    }
    
    private func tableView(_ tableView: UITableView, cellForImageFragment fragment: Fragment, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: imageCellIdentifier, for: indexPath) as! ImageFragmentCell
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        let section = self.section(at: indexPath)
        if indexPath.row == section.values.count {
            return false
        }
        else {
            return true
        }
    }
    
    private func configureCell(_ cell: BasicFragmentCell, withType type: FragmentType) {
        cell.colorView.backgroundColor = isEditing ? UIColor(white: 0.90, alpha: 1.0) : UIColor.clear
        cell.colorAccentView.backgroundColor = type.accentColor //withAlphaComponent(0.95)
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        if isEditing {
            let section = self.section(at: indexPath.section)
            if indexPath.row == section.values.count {
                return .insert
            }
            else {
                return .delete
            }
        }
        else {
            return .none
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var output = [UITableViewRowAction]()
        
        let section = self.section(at: indexPath.section)
        let fragment = section.values[indexPath.row]
        
        output.append(
            UITableViewRowAction(
                style: .destructive,
                title: "Delete",
                handler: { (action, indexPath) in
                    self.delete(at: indexPath)
            })
        )
        
        if output.count == 0 {
            return nil
        }
        
        return output
    }
    
    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        let sourceSection = self.section(at: sourceIndexPath.section)
        let destinationSection = self.section(at: proposedDestinationIndexPath.section)
        
        let limit: Int
        
        if sourceIndexPath.section == proposedDestinationIndexPath.section {
            // Moving within same section
            limit = destinationSection.values.count - 1
        }
        else {
            // Moving to a different section
            limit = destinationSection.values.count
        }
        
        let index = min(limit, proposedDestinationIndexPath.row)
        return IndexPath(row: index, section: proposedDestinationIndexPath.section)
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let sourceSection = self.section(at: sourceIndexPath.section)
        let destinationSection = self.section(at: destinationIndexPath.section)
        let fragment = sourceSection.values.remove(at: sourceIndexPath.row)
        fragment.type = destinationSection.type
        destinationSection.values.insert(fragment, at: destinationIndexPath.row)
        sourceSection.updateOrdering()
        destinationSection.updateOrdering()
        saveDocument()
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let section = self.section(at: indexPath.section)
        
        switch editingStyle {
            
        case .none:
            break
            
        case .delete:
            delete(at: indexPath)
            
        case .insert:
            if let cell = tableView.cellForRow(at: indexPath) as? BasicFragmentCell, let text = cell.contentTextField.text, !text.isEmpty {
                cell.contentTextField.text = nil
                insert(value: text, at: indexPath)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else {
            return
        }
        
        headerView.backgroundView?.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
    }
    
    func textCell(cell: BasicFragmentCell, textDidChange text: String?) {

        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        
        let section = self.section(at: indexPath.section)
        
        if indexPath.row == section.values.count {
            insert(value: text, at: indexPath)
            cell.contentTextField.text = nil
        }
        else {
            if text?.isEmpty ?? true {
                delete(at: indexPath)
            }
            else {
                update(value: text, at: indexPath)
            }
        }
        
        coreData.saveNow()
    }
    
    func delete(at indexPath: IndexPath) {
        let section = self.section(at: indexPath.section)
        let context = coreData.mainContext
        let fragment = section.values[indexPath.row]
        context.delete(fragment)
        coreData.saveNow() { success in
            if success {
                section.remove(at: indexPath.row)
                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                self.tableView.endUpdates()
            }
        }
    }
    
    func update(value: String?, at indexPath: IndexPath) {
        let section = self.section(at: indexPath.section)
        let fragment = section.values[indexPath.row]
        fragment.value = value
        coreData.saveNow()
    }
    
    func insert(value: String?, at indexPath: IndexPath) {
        let section = self.section(at: indexPath.section)
        let context = coreData.mainContext
        do {
            let fragment = Fragment(type: section.type, value: value, context: context)
            fragment.document = try context.documents(withIdentifier: documentIdentifier).first
            try context.save()
            coreData.saveNow() { success in
                if success {
                    section.append(fragment)
                    self.tableView.beginUpdates()
                    self.tableView.insertRows(at: [indexPath], with: .automatic)
                    self.tableView.endUpdates()
                }
            }
        }
        catch {
            print("Cannot insert item: \(error)")
        }
    }
    
    func section(at indexPath: IndexPath) -> Section {
        return section(at: indexPath.section)
    }
    
    func section(at index: Int) -> Section {
        return sections[activeSections[index]]
    }
}
