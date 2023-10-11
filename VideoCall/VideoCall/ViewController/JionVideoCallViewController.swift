//
//  JionVideoCallViewController.swift
//  VideoCall
//
//  Created by macOS on 09/10/23.
//

import UIKit
import AgoraRtcKit
import AGEVideoLayout

class JionVideoCallViewController: UIViewController {
    
    @IBOutlet weak var localContainer: UIView!
    @IBOutlet weak var remoteContainer: UIView!
    @IBOutlet weak var remoteVideoMutedIndicator: UIImageView!
    @IBOutlet weak var localVideoMutedIndicator: UIView!
    @IBOutlet weak var micButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    
    var agoraKit: AgoraRtcEngineKit!
    var localVideo: AgoraRtcVideoCanvas?
    var remoteVideo: AgoraRtcVideoCanvas?
    var channelName = ""
    var isJoined = true
    var isRemoteVideoRender: Bool = true {
        didSet {
            if let it = localVideo, let view = it.view {
                if view.superview == localContainer {
                    remoteVideoMutedIndicator.isHidden = isRemoteVideoRender
                    remoteContainer.isHidden = !isRemoteVideoRender
                } else if view.superview == remoteContainer {
                    localVideoMutedIndicator.isHidden = isRemoteVideoRender
                }
            }
        }
    }
    
    var isLocalVideoRender: Bool = false {
        didSet {
            if let it = localVideo, let view = it.view {
                if view.superview == localContainer {
                    localVideoMutedIndicator.isHidden = isLocalVideoRender
                } else if view.superview == remoteContainer {
                    remoteVideoMutedIndicator.isHidden = isLocalVideoRender
                }
            }
        }
    }
    
    var isStartCalling: Bool = true {
        didSet {
            if isStartCalling {
                micButton.isSelected = false
            }
            micButton.isHidden = !isStartCalling
            cameraButton.isHidden = !isStartCalling
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeAgoraEngine()
        joinChannel()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
    }
    
    func initializeAgoraEngine() {
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: "b1af3503cb604b9aa28f5d2b50ed63e0", delegate: self)
    }

    func joinChannel() {
        let config = AgoraRtcEngineConfig()
        config.appId = KeyCenter.AppId
        config.areaCode = GlobalSettings.shared.area
        
        // setup log file path
        let logConfig = AgoraLogConfig()
        logConfig.level = .info
        config.logConfig = logConfig
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        // enable filters
        agoraKit.enableExtension(withVendor: "agora_video_filters_clear_vision", extension: "clear_vision", enabled: true, sourceType: .primaryCamera)
        // Configuring Privatization Parameters
        Util.configPrivatization(agoraKit: agoraKit)
        // make myself a broadcaster
        agoraKit.setChannelProfile(.liveBroadcasting)
        agoraKit.setClientRole(GlobalSettings.shared.getUserRole())
        
        agoraKit.enableVideo()
        agoraKit.enableAudio()
        agoraKit.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: AgoraVideoDimension640x360,
                                                                             frameRate: .fps15,
                                                                             bitrate: AgoraVideoBitrateStandard,
                                                                             orientationMode: .adaptative,
                                                                             mirrorMode: .auto))
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.renderMode = .hidden
        agoraKit.setupLocalVideo(videoCanvas)
        agoraKit.startPreview()
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        let option = AgoraRtcChannelMediaOptions()
        option.publishCameraTrack = GlobalSettings.shared.getUserRole() == .broadcaster
        option.publishMicrophoneTrack = GlobalSettings.shared.getUserRole() == .broadcaster
        option.clientRoleType = GlobalSettings.shared.getUserRole()
        NetworkManager.shared.generateToken(channelName: channelName, success: { token in
            let result = self.agoraKit.joinChannel(byToken: token, channelId: self.channelName, uid: 0, mediaOptions: option)
            if result != 0 {
                print("joinChannel call failed: \(result), please check your params")
            }
        })
        self.setUserDisplay()
    }
    
    func setUserDisplay() {
        let view = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: localContainer.frame.size))
        localVideo = AgoraRtcVideoCanvas()
        localVideo!.view = view
        localVideo!.renderMode = .hidden
        localVideo!.uid = 0
        localContainer.addSubview(localVideo!.view!)
        agoraKit.setupLocalVideo(localVideo)
        agoraKit.startPreview()
    }
    func leaveChannel() {
        agoraKit.leaveChannel(nil)
        isRemoteVideoRender = false
        isLocalVideoRender = false
        isStartCalling = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    @IBAction func didClickHangUpButton(_ sender: UIButton) {
        sender.isSelected.toggle()
        if sender.isSelected {
            leaveChannel()
            removeFromParent(localVideo)
            localVideo = nil
            removeFromParent(remoteVideo)
            remoteVideo = nil
            self.navigationController?.popViewController(animated: true)
        } else {
            setUserDisplay()
            joinChannel()
        }
    }
    
    @IBAction func didClickMuteButton(_ sender: UIButton) {
        sender.isSelected.toggle()
        agoraKit.muteLocalAudioStream(sender.isSelected)
    }
    
    @IBAction func didClickSwitchCameraButton(_ sender: UIButton) {
        sender.isSelected.toggle()
        agoraKit.switchCamera()
    }
    
    @IBAction func didClickLocalContainer(_ sender: Any) {
        switchView(localVideo)
        switchView(remoteVideo)
    }
    
    func removeFromParent(_ canvas: AgoraRtcVideoCanvas?) -> UIView? {
        if let it = canvas, let view = it.view {
            let parent = view.superview
            if parent != nil {
                view.removeFromSuperview()
                return parent
            }
        }
        return nil
    }
    
    func switchView(_ canvas: AgoraRtcVideoCanvas?) {
        let parent = removeFromParent(canvas)
        if parent == localContainer {
            canvas!.view!.frame.size = remoteContainer.frame.size
            remoteContainer.addSubview(canvas!.view!)
        } else if parent == remoteContainer {
            canvas!.view!.frame.size = localContainer.frame.size
            localContainer.addSubview(canvas!.view!)
        }
    }
}

extension JionVideoCallViewController: AgoraRtcEngineDelegate {

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        self.isJoined = true
        print("Join \(channel) with uid \(uid) elapsed \(elapsed)ms")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        isRemoteVideoRender = true

        var parent: UIView = remoteContainer
        if let it = localVideo, let view = it.view {
            if view.superview == parent {
                parent = localContainer
            }
        }
        
        if remoteVideo != nil {
            return
        }

        let view = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: parent.frame.size))
        remoteVideo = AgoraRtcVideoCanvas()
        remoteVideo!.view = view
        remoteVideo!.renderMode = .hidden
        remoteVideo!.uid = uid
        parent.addSubview(remoteVideo!.view!)
        agoraKit.setupRemoteVideo(remoteVideo!)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid:UInt, reason:AgoraUserOfflineReason) {
        isRemoteVideoRender = false
        if let it = remoteVideo, it.uid == uid {
            removeFromParent(it)
            remoteVideo = nil
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted:Bool, byUid:UInt) {
        isRemoteVideoRender = !muted
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
//        logVC?.log(type: .warning, content: "did occur warning, code: \(warningCode.rawValue)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
//        logVC?.log(type: .error, content: "did occur error, code: \(errorCode.rawValue)")
    }
}


extension Bundle {

    static func loadView<T>(fromNib name: String, withType type: T.Type) -> T {
        if let view = Bundle.main.loadNibNamed(name, owner: nil, options: nil)?.first as? T {
            return view
        }

        fatalError("Could not load view with type " + String(describing: type))
    }
    
}
