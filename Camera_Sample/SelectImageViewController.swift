//
//  SelectImageViewController.swift
//  Camera_Sample
//
//  Created by jeongguk on 2021/11/22.
//

import UIKit

class SelectImageViewController: UIViewController {

    var images = [UIImage]()
    var throwImages = [UIImage]()
    @IBOutlet weak var resultCollectionview: UICollectionView!
    @IBOutlet weak var saveButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.resultCollectionview.reloadData()
        
    }
    @IBAction func save(_ sender: Any) {
        guard let vc = self.presentingViewController as? ViewController else {
            return
        }
        vc.continuousImages = throwImages
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}

extension SelectImageViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ResultCell", for: indexPath) as? ResultCell else {
            return UICollectionViewCell()
        }
        cell.imageView.image = images[indexPath.item]
        return cell
    }
    
    
}
extension SelectImageViewController: UICollectionViewDelegate{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("눌러짐??==>\(indexPath.item)")
        guard let cell = collectionView.cellForItem(at: indexPath) as? ResultCell else {
            return
        }
        cell.isSelectedImage = !cell.isSelectedImage
        if cell.isSelectedImage {
            cell.backgroundColor = .systemBlue
        }else {
            cell.backgroundColor = .clear
        }
        
        guard let allCell = collectionView.visibleCells as? [ResultCell] else {
            return
        }
        throwImages = allCell.filter{ $0.isSelectedImage }.map{ $0.imageView.image! }
        saveButton.setTitle("(\(throwImages.count))저장", for: .normal)
        
    }
    
}
extension SelectImageViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let margin: CGFloat = 8
        let itemSpacing: CGFloat = 8
        
        let width = (collectionView.bounds.width - margin * 2 - itemSpacing * 2 ) / 3
        let height = width
        return CGSize(width: width, height: height)
    }
}

class ResultCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    var isSelectedImage: Bool = false
}
