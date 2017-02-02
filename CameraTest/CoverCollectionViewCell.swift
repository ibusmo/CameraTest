//
//  CoverCollectionViewCell.swift
//  CameraTest
//
//  Created by Cpt. Omsub Sukkhee on 1/30/17.
//  Copyright © 2017 omsubusmo. All rights reserved.
//

import UIKit

class CoverCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var sequenceLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func prepareForReuse() {
        self.imageView.image = nil
        self.sequenceLabel.text = ""
    }

}
