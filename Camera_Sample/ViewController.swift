//
//  ViewController.swift
//  Camera_Sample
//
//  Created by jeongguk on 2021/11/12.
//
// 참고 : AVFoundation 관련해서 공부하고 싶으면 learning avfoundation 책 으로 공부하라고하는데 영문 서적인듯... 개정 별로 안해서 오래된듯..

//추가해야할거 단일촬영 할지 연속촬영 할지 근데 이거는 가져다 붙일때 알아서 구현해도 될듯????
//landscape모드 도 생각해봐야함
//카메라 하단 뷰 따로만들어서 관리할수있도록 수정
//가이드라인 그리는거
//배율 적용도 해야함~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController {
    //TODO: 초기설정 1
    // -captureSession
    //-AVCaptureDeviceInput
    //-AVCapturePhotoOutput
    //-Queue
    //-AVCaptureDevice DiscoverySession
    
    let captureSession = AVCaptureSession()
    var videoDeviceInput: AVCaptureDeviceInput! //전면, 후면 카메라에따라 달라질 수 있어서 var로 선언함
    let photoOutput = AVCapturePhotoOutput()
    var flash = false
    var setImage = UIImage()
    let sessionQueue = DispatchQueue(label: "session Queue")
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified) // 디바이스를 찾는 객체, 첫번쩨인자값 에는 카매라뒷면 종류(아이폰 기종에따라 카메라 달린개수 그런거)에따라 가져오는게 다름 그래서 종류별로 넣어주는게 좋음 //posision에는 카메라 방향 설정임 앞,뒤,둘다사용하도록 설정할수있음
    
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var photoLibraryButton: UIButton!
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var blurBGView: UIVisualEffectView!
    @IBOutlet weak var switchButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var showImage: UIImageView!
    
    
    override var prefersStatusBarHidden: Bool{
        return true
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // TODO: 초기설정 2
        previewView.session = captureSession //세션 연결해줌
        sessionQueue.async {
            self.setUpSession() //UI가 메모리에 올라오는 시점
            self.startSession()
        }
        setupUI()
    }
    
    func setupUI(){
        
        photoLibraryButton.layer.cornerRadius = 10
        photoLibraryButton.layer.masksToBounds = true
        photoLibraryButton.layer.borderColor = UIColor.white.cgColor
        photoLibraryButton.layer.borderWidth = 1
        
        captureButton.layer.cornerRadius = captureButton.bounds.height/2
        captureButton.layer.masksToBounds = true
        
        blurBGView.layer.cornerRadius = captureButton.bounds.height/2
        blurBGView.layer.masksToBounds = true
        
        
    }
    @IBAction func deleteImage(_ sender: Any) {
        self.toggleButton()
    }
    @IBAction func saveImage(_ sender: Any) {
        self.savePhotoLibrary(image: setImage)
        self.toggleButton()
    }
    @IBAction func flashMode(_ sender: Any) {
        flash = !flash
        if flash {
            flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
            print("flash")
        }else {
            flashButton.setImage(UIImage(systemName: "bolt"), for: .normal)
            print("not flash")
        }
    }
    
    @IBAction func switchCamera(_ sender: Any) {
        //TODO: 카메라는 1개 이상이어야함
        guard videoDeviceDiscoverySession.devices.count > 1 else {
            return
        }
        
        //TODO: 반대 카메라 찾아서 재설정 해야함
        // - 반대 카메라 찾고 새로운 디바이스를 가지고 세션을 업데이트
        // - 카메라 토글 버튼 업데이트
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device //현재 잡혀있는 카메라임
            let currentPosition = currentVideoDevice.position
            let isFront = currentPosition == .front
            let preferredPosition: AVCaptureDevice.Position = isFront ? .back : .front
            
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice?
            
            newVideoDevice = devices.first(where: {device in
                return preferredPosition == device.position
            })
            
            // update capture session
            if let newDevice = newVideoDevice {
                do{
                    let videoDeviceInput = try AVCaptureDeviceInput(device: newDevice)
                    self.captureSession.beginConfiguration()
                    self.captureSession.removeInput(self.videoDeviceInput)
                    
                    //add new device input
                    if self.captureSession.canAddInput(videoDeviceInput) {
                        self.captureSession.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.captureSession.addInput(self.videoDeviceInput)
                    }
                    
                    self.captureSession.commitConfiguration()
                    
                    DispatchQueue.main.async {
                        self.updateSwitchCameraIcon(position: preferredPosition)//새로운 포지션받아서 업데이트 시켜줌 메인 스레드에서 작업시켜줘야함
                    }
                    
                } catch let error {
                    print("error===>\(error.localizedDescription)")
                }
            }
        }
        
        
    }
    
    func updateSwitchCameraIcon(position: AVCaptureDevice.Position){
        switch position {
        case .front:
            let image = UIImage(named: "ic_camera_front")
            switchButton.setImage(image, for: .normal)
        case .back:
            let image = UIImage(named: "ic_camera_rear")
            switchButton.setImage(image, for: .normal)
        default:
            break
        }
    }
    
    @IBAction func capturePhoto(_ sender: Any) {
        //TODO: photoOutput의 capturePhoto 메소드
        //orientation
        //photoOutput
        
        let videoPreviewLayerOrientation = self.previewView.videoPreviewLayer.connection?.videoOrientation
        sessionQueue.async {
            let connection = self.photoOutput.connection(with: .video)
            connection?.videoOrientation = videoPreviewLayerOrientation!
            
            //사진찍는거 요청
            let setting = AVCapturePhotoSettings()
            setting.flashMode = self.flash ? .on : .off
            self.photoOutput.capturePhoto(with: setting, delegate: self)
        }
        
    }
    
    func savePhotoLibrary(image: UIImage){
        // TODO: capture한 이미지 포토라이브러리에 저장
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized{
                //저장
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)//이미지를 포토라이브러이에 넣음
                }) { success, error in
                    print("-->이미지 저장 완료여부 : \(success)")
                }
            } else {
                //다시 요청 나중에 alert창띄워서 설정가서 권한 주라고 하면 될듯?
                print("--->권한을 받지 못함")
            }
        }
    }
    
}


extension ViewController {
    // MARK: Setup session and preview
    
    func setUpSession(){
        //presetSetting - 사진,영상,해상도,비율 설정하는거임
        captureSession.sessionPreset = .photo
        captureSession.beginConfiguration()//구성시작
        
        // Add video input
        var defaultVideoDevice: AVCaptureDevice?
        
        guard let camera = videoDeviceDiscoverySession.devices.first else{ //카메라 못찾으면
            print("====>error")
            captureSession.commitConfiguration()
            return
        }
        
        do{
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            guard captureSession.canAddInput(videoDeviceInput) else {
                print("====>error")
                captureSession.commitConfiguration()
                return
            }
            captureSession.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
        }catch let error {
            print("====>error : \(error.localizedDescription)")
            captureSession.commitConfiguration()
            return
        }
        // Add photo Output
        photoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey:AVVideoCodecType.jpeg])], completionHandler: nil)//어떤형식으로 저장할지 지정
        guard captureSession.canAddOutput(photoOutput) else {
            print("====>error")
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(photoOutput)
        captureSession.commitConfiguration()//구성적용?
    }
    
    func startSession(){
         //TODO: session Start
        sessionQueue.async {
            if !self.captureSession.isRunning{
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopSession(){
        //TODO: session Stop
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    func toggleButton(){
        if previewView.session!.isRunning {
            previewView.session?.stopRunning()
        }else {
            previewView.session?.startRunning()
        }
        photoLibraryButton.isHidden = !photoLibraryButton.isHidden
        switchButton.isHidden = !switchButton.isHidden
        deleteButton.isHidden = !deleteButton.isHidden
        saveButton.isHidden = !saveButton.isHidden
        showImage.isHidden = !showImage.isHidden
    }
    

}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        //TODO: capturePhoto delegate method 구현
        //여기서저장해줌
        
        guard error == nil else { return }
        guard let imageData = photo.fileDataRepresentation() else { return }
        
        guard let image = UIImage(data: imageData) else { return }
        showImage.image = image
        setImage = image
        self.toggleButton()
    }
}


