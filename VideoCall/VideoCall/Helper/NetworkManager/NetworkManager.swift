//
//  NetworkManager.swift
//  VideoCall
//
//  Created by macOS on 09/10/23.
//

import UIKit

@objc
class NetworkManager: NSObject {
    enum HTTPMethods: String {
        case GET = "GET"
        case POST = "POST"
    }
        
    typealias SuccessClosure = ([String: Any]) -> Void
    typealias FailClosure = (String) -> Void
    
    private lazy var sessionConfig: URLSessionConfiguration = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Content-Type": "application/json",
                                        "X-LC-Id": "fkUjxadPMmvYF3F3BI4uvmjo-gzGzoHsz",
                                        "X-LC-Key": "QAvFS62IOR28GfSFQO5ze45s",
                                        "X-LC-Session": "qmdj8pdidnmyzp0c7yqil91oc"]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return config
    }()
    
    @objc
    static let shared = NetworkManager()
    private override init() { }
    private let baseUrl = "https://test-toolbox.bj2.agoralab.co/v1/token/generate"
    
    @objc
    func generateToken(channelName: String, uid: UInt = 0, success: @escaping (String?) -> Void) {
        if KeyCenter.Certificate == nil || KeyCenter.Certificate?.isEmpty == true {
            success(nil)
            return
        }
        let params = ["appCertificate": KeyCenter.Certificate ?? "",
                      "appId": KeyCenter.AppId,
                      "channelName": channelName,
                      "expire": 900,
                      "src": "iOS",
                      "ts": "".timeStamp,
                      "type": 1,
                      "uid": "\(uid)"] as [String : Any]
//        ToastView.showWait(text: "loading...", view: nil)
        NetworkManager.shared.postRequest(urlString: "https://toolbox.bj2.agoralab.co/v1/token/generate", params: params, success: { response in
            let data = response["data"] as? [String: String]
            let token = data?["token"]
            print(response)
            success(token)
//            ToastView.hidden()
        }, failure: { error in
            print(error)
            success(nil)
//            ToastView.hidden()
        })
    }
    
    func getRequest(urlString: String, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: nil, method: .GET, success: success, failure: failure)
        }
    }
    
    func download(urlString: String, success: SuccessClosure?, failure: FailClosure?) {
        let session = URLSession(configuration: sessionConfig)
        let request = URLRequest(url: URL(string: urlString) ?? URL(fileURLWithPath: urlString))
        let fileName = urlString.components(separatedBy: "/").last ?? ""
        let documnets = NSTemporaryDirectory() + fileName
        if FileManager.default.fileExists(atPath: documnets) {
            success?(["fileName": fileName, "path": documnets])
            return
        }
        DispatchQueue.global().async {
            let downloadTask = session.downloadTask(with: request) { location, response, error in
                let locationPath = location!.path
                let fileManager = FileManager.default
                try? fileManager.moveItem(atPath: locationPath, toPath: documnets)
                success?(["fileName": fileName, "path": documnets])
            }
            downloadTask.resume()
        }
    }
    
    func postRequest(urlString: String, params: [String: Any]?, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: params, method: .POST, success: success, failure: failure)
        }
    }
    
    private func request(urlString: String,
                         params: [String: Any]?,
                         method: HTTPMethods,
                         success: SuccessClosure?,
                         failure: FailClosure?) {
        let session = URLSession(configuration: sessionConfig)
        guard let request = getRequest(urlString: urlString,
                                       params: params,
                                       method: method,
                                       success: success,
                                       failure: failure) else { return }
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.checkResponse(response: response, data: data, success: success, failure: failure)
            }
        }.resume()
    }
    
    private func getRequest(urlString: String,
                            params: [String: Any]?,
                            method: HTTPMethods,
                            success: SuccessClosure?,
                            failure: FailClosure?) -> URLRequest? {
        
        let string = urlString.hasPrefix("http") ? urlString : baseUrl.appending(urlString)
        guard let url = URL(string: string) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if method == .POST {
            request.httpBody = try? JSONSerialization.data(withJSONObject: params ?? [], options: .sortedKeys)//convertParams(params: params).data(using: .utf8)
        }
        let curl = request.cURL(pretty: true)
        debugPrint("curl == \(curl)")
        return request
    }
    
    private func convertParams(params: [String: Any]?) -> String {
        guard let params = params else { return "" }
        let value = params.map({ String(format: "%@=%@", $0.key, "\($0.value)") }).joined(separator: "&")
        return value
    }
    
    private func checkResponse(response: URLResponse?, data: Data?, success: SuccessClosure?, failure: FailClosure?) {
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...201:
                if let resultData = data {
                    let result = String(data: resultData, encoding: .utf8)
                    print(result ?? "")
                    success?(JSONObject.toDictionary(jsonString: result ?? ""))
                } else {
                    failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response))")
                }
            default:
                failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response))")
            }
        }
    }
}

extension URLRequest {
    public func cURL(pretty: Bool = false) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\'\(url?.absoluteString ?? "")\' \(newLine)"
        
        var cURL = "curl "
        var header = ""
        var data: String = ""
        
        if let httpHeaders = allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key,value) in httpHeaders {
                header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
            }
        }
        
        if let bodyData = httpBody, let bodyString = String(data: bodyData, encoding: .utf8), !bodyString.isEmpty {
            data = "--data '\(bodyString)'"
        }
        
        cURL += method + url + header + data
        
        return cURL
    }
}

extension String {
    var timeStamp: String {
        let date = Date()
        let timeInterval = date.timeIntervalSince1970
        let millisecond = CLongLong(timeInterval * 1000)
        return "\(millisecond)"
    }
}

class KeyCenter: NSObject {
    
    /**
     Agora APP ID.
     Agora assigns App IDs to app developers to identify projects and organizations.
     If you have multiple completely separate apps in your organization, for example built by different teams,
     you should use different App IDs.
     If applications need to communicate with each other, they should use the same App ID.
     In order to get the APP ID, you can open the agora console (https://console.agora.io/) to create a project,
     then the APP ID can be found in the project detail page.
     声网APP ID
     Agora 给应用程序开发人员分配 App ID，以识别项目和组织。如果组织中有多个完全分开的应用程序，例如由不同的团队构建，
     则应使用不同的 App ID。如果应用程序需要相互通信，则应使用同一个App ID。
     进入声网控制台(https://console.agora.io/)，创建一个项目，进入项目配置页，即可看到APP ID。
     */
    @objc
    static let AppId: String = "b1af3503cb604b9aa28f5d2b50ed63e0"
    
    /**
     Certificate.
     Agora provides App certificate to generate Token. You can deploy and generate a token on your server,
     or use the console to generate a temporary token.
     In order to get the APP ID, you can open the agora console (https://console.agora.io/) to create a project with the App Certificate enabled,
     then the APP Certificate can be found in the project detail page.
     PS: If the project does not have certificates enabled, leave this field blank.
     声网APP证书
     Agora 提供 App certificate 用以生成 Token。您可以在您的服务器部署并生成 Token，或者使用控制台生成临时的 Token。
     进入声网控制台(https://console.agora.io/)，创建一个带证书鉴权的项目，进入项目配置页，即可看到APP证书。
     注意：如果项目没有开启证书鉴权，这个字段留空。
     */
    static let Certificate: String? = ""
}
