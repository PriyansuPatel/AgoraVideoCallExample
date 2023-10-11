//
//  ViewController.swift
//  VideoCall
//
//  Created by macOS on 09/10/23.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var jionButton: UIButton!
    @IBOutlet weak var chanelIDTextFiled: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


    @IBAction func jionButtonClick(_ sender: UIButton) {
        self.view.endEditing(true)
        let JionCallVC = JionVideoCallViewController.initialize(from: .main)
        JionCallVC.channelName = self.chanelIDTextFiled.text ?? "1"
        navigationController?.pushViewController(JionCallVC, animated: true)
    }
}
