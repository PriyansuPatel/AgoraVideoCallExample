//
//  VideoView.swift
//  VideoCall
//
//  Created by macOS on 09/10/23.
//

import Foundation
//extension Bundle {
//
//    static func loadView<T>(fromNib name: String, withType type: T.Type) -> T {
//        if let view = Bundle.main.loadNibNamed(name, owner: nil, options: nil)?.first as? T {
//            return view
//        }
//
//        fatalError("Could not load view with type " + String(describing: type))
//    }
//    
//    static func loadVideoView(type:VideoView.StreamType, audioOnly:Bool) -> VideoView {
//        let view = Bundle.loadView(fromNib: "VideoView", withType: VideoView.self)
//        view.audioOnly = audioOnly
//        view.type = type
//        if(type.isLocal()) {
//            view.statsInfo = StatisticsInfo(type: .local(StatisticsInfo.LocalInfo()))
//        } else {
//            view.statsInfo = StatisticsInfo(type: .remote(StatisticsInfo.RemoteInfo()))
//        }
//        return view
//    }
//}
