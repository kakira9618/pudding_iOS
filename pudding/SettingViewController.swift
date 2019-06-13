//
//  SettingViewController.swift
//  pudding
//
//  Created by kakira on 2015/09/10.
//  Copyright © 2015年 kakira. All rights reserved.
//

import UIKit

class SettingViewController: UIViewController {
    
    var gvcl: GameViewController?
    
    @IBOutlet weak var slider1: UISlider!
    @IBOutlet weak var slider2: UISlider!
    @IBOutlet weak var slider3: UISlider!
    
    @IBOutlet weak var kSpring: UILabel!
    @IBOutlet weak var puddingStrength: UILabel!
    @IBOutlet weak var forceStrength: UILabel!
    
    @IBOutlet weak var back: UIBarButtonItem!
    
    @IBOutlet weak var def: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        slider1.value = gvcl!.kSpring
        slider2.value = gvcl!.puddingStrength
        slider3.value = gvcl!.forceStrength
        updateTexts()
    }
    
    @IBAction func slider1Changed(_ sender: AnyObject) {
        updateTexts()
    }
    @IBAction func slider2Changed(_ sender: AnyObject) {
        updateTexts()
    }
    @IBAction func slider3Changed(_ sender: AnyObject) {
        updateTexts()
    }
    
    @IBAction func setToDefault(_ sender: AnyObject) {
        slider1.value = 0.12
        slider2.value = 0.95
        slider3.value = 0.10
        updateTexts()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        gvcl!.kSpring = slider1.value
        gvcl!.puddingStrength = slider2.value
        gvcl!.forceStrength = slider3.value
    }
    
    @IBAction func backPressed(_ sender: Any) {
        gvcl!.kSpring = slider1.value
        gvcl!.puddingStrength = slider2.value
        gvcl!.forceStrength = slider3.value
        dismiss(animated: true)
    }
    
    
    func updateTexts() {
        kSpring.text = "\(slider1.value)"
        puddingStrength.text = "\(slider2.value)"
        forceStrength.text = "\(slider3.value)"
    }
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}
