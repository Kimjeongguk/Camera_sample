//
//  ViewController.swift
//  Camera_Sample
//
//  Created by jeongguk on 2021/11/12.
//
//
//추가해야할거 단일촬영 할지 연속촬영 할지 근데 이거는 가져다 붙일때 구현해도 될듯????
//가이드라인 그리는거 이것도 필요하면 할거임
//사진첩접근은 안함 ~~~ 필요하면 할거임
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
    var picture = true //사진 연속으로 찍는거 방지
    var zoomScaleRange: ClosedRange<CGFloat> = 1...10
    var videoOrientation: AVCaptureVideoOrientation = .portrait
    let currentDevice = UIDevice.current
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
    @IBOutlet weak var showImageView: UIView!
    @IBOutlet weak var showImage: UIImageView!
    
    
    override var prefersStatusBarHidden: Bool{
        return true
    }
    override func viewDidAppear(_ animated: Bool) {
        checkCameraPermission() //alert 띄우는거는 viewDidAppear안에서 실행해 줘야함
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
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))//zoom관련
        previewView.addGestureRecognizer(pinch)
        
        setVideoOrientationForDeviceOrientation(currentDevice.orientation)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deviceOrientationChanged(_:)),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
    }
    //TODO: 카메라 접근권한 확인
    func checkCameraPermission(){
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch status {
        case .restricted:
            print("액세스 불가 상태")
        case .authorized:
            print("권한 허용 상태")
        case .denied:
            let alert = UIAlertController(title: "카메라 접근권한", message: "설정->해당앱->카메라 접근권한을 설정해주세요.", preferredStyle: UIAlertController.Style.alert)
            let okAction = UIAlertAction(title: "확인", style: .default, handler: nil)
            alert.addAction(okAction)
            self.present(alert, animated: true, completion: nil)
        default:
            break
        }
    }
    //TODO: 그냥 UI설정임..
    func setupUI(){
        
        photoLibraryButton.layer.cornerRadius = 10
        photoLibraryButton.layer.masksToBounds = true
        photoLibraryButton.layer.borderColor = UIColor.white.cgColor
        photoLibraryButton.layer.borderWidth = 1
        
        switchButton.layer.cornerRadius = 10
        switchButton.layer.masksToBounds = true
        switchButton.layer.borderColor = UIColor.white.cgColor
        switchButton.layer.borderWidth = 1
        
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
        if picture {
            picture = false
//            let videoPreviewLayerOrientation = self.previewView.videoPreviewLayer.connection?.videoOrientation
            let videoPreviewLayerOrientation = videoOrientation //현재 화면방향
            sessionQueue.async {
                let connection = self.photoOutput.connection(with: .video)
                connection?.videoOrientation = videoPreviewLayerOrientation
                
                //사진찍는거 요청
                let setting = AVCapturePhotoSettings()
                setting.flashMode = self.flash ? .on : .off
                self.photoOutput.capturePhoto(with: setting, delegate: self)
            }
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
    // MARK: Zoom 기능 관련
    private func configCamera(_ camera: AVCaptureDevice?, _ config: @escaping (AVCaptureDevice) -> ()) {//zoom관련임
            guard let device = camera else { return }

            sessionQueue.async { [device] in
                do {
                    try device.lockForConfiguration()
                } catch {
                    return
                }
                config(device)
                device.unlockForConfiguration()
            }
        }
    
    private var initialScale: CGFloat = 0 //zoom
    
    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        guard let device = videoDeviceDiscoverySession.devices.first else { return }

        switch pinch.state {
        case .began:
            initialScale = device.videoZoomFactor
        case .changed:
            let minAvailableZoomScale = device.minAvailableVideoZoomFactor
            let maxAvailableZoomScale = device.maxAvailableVideoZoomFactor
            let availableZoomScaleRange = minAvailableZoomScale...maxAvailableZoomScale
            let resolvedZoomScaleRange = zoomScaleRange.clamped(to: availableZoomScaleRange)

            let resolvedScale = max(resolvedZoomScaleRange.lowerBound, min(pinch.scale * initialScale, resolvedZoomScaleRange.upperBound))

            configCamera(device) { device in
                device.videoZoomFactor = resolvedScale
            }
        default:
            return
        }
    }
    
    //MARK: 화면방향에 관련
    @objc private func deviceOrientationChanged(_ note: Notification) {
        setVideoOrientationForDeviceOrientation(currentDevice.orientation)
    }
    
    private func setVideoOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait:
            videoOrientation = .portrait
            buttonAnimated(button: photoLibraryButton, rotationAngle: CGFloat.pi*2, duration: 0.25)
            buttonAnimated(button: switchButton, rotationAngle: CGFloat.pi*2, duration: 0.25)
            
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
            buttonAnimated(button: photoLibraryButton, rotationAngle: CGFloat.pi, duration: 0.25)
            buttonAnimated(button: switchButton, rotationAngle: CGFloat.pi, duration: 0.25)
            
        case .landscapeLeft:
            videoOrientation = .landscapeRight
            buttonAnimated(button: photoLibraryButton, rotationAngle: CGFloat.pi/2, duration: 0.25)
            buttonAnimated(button: switchButton, rotationAngle: CGFloat.pi/2, duration: 0.25)
            
            
        case .landscapeRight:
            videoOrientation = .landscapeLeft
            buttonAnimated(button: photoLibraryButton, rotationAngle: -CGFloat.pi/2, duration: 0.25)
            buttonAnimated(button: switchButton, rotationAngle: -CGFloat.pi/2, duration: 0.25)
            
            
        default:
            break
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
            picture = true
        }
        photoLibraryButton.isHidden = !photoLibraryButton.isHidden
        switchButton.isHidden = !switchButton.isHidden
        deleteButton.isHidden = !deleteButton.isHidden
        saveButton.isHidden = !saveButton.isHidden
        showImage.isHidden = !showImage.isHidden
        showImageView.isHidden = !showImageView.isHidden
    }
    //TODO: 버튼 animation관련 이미지나 이런거 응용할수있을듯
    func buttonAnimated( button:UIButton, rotationAngle:CGFloat, duration:TimeInterval){
        UIView.animate(withDuration: duration) {
            button.transform = CGAffineTransform(rotationAngle: rotationAngle)
        }
    }

}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        //TODO: capturePhoto delegate method 구현
        
        guard error == nil else { return }
        guard let imageData = photo.fileDataRepresentation() else { return }
        
        guard let image = UIImage(data: imageData) else { return }
        showImage.image = image
        setImage = image
        self.toggleButton()
    }
}


