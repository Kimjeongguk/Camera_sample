//
//  PreviewView.swift
//  Camera_Sample
//
//  Created by jeongguk on 2021/11/12.
//

import UIKit
import AVFoundation
// TODO: AVCaptureSession에서 나오는 데이터를 보여주기위해 AVCaptureVideoPreviewLayer를 이용해서 보여줘야함 근데 UIView타입이 아니라서 따로 클레스 만들어준거임 apple document 어딘가에 있는 소스코드임.
//https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/avcam_building_a_camera_app?language=objc 참고!!
class PreviewView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer{
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implemetation.")
        }
        
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        layer.connection?.videoOrientation = .portrait
        
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set{
            videoPreviewLayer.session = newValue
        }
    }
    
    
    //MARK: UIView
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
