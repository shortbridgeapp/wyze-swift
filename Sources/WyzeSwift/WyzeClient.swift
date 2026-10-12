//
//  WyzeClient.swift
//  WyzeSwift
//
//  A native Swift client for Wyze Cloud API interactions.
//  Created for the open-source community by ShortBridge (https://shortbridge.app).
//

import Foundation
import CryptoKit

/// Standalone, asynchronous client for Wyze API interactions.
public struct WyzeClient: Sendable {
    
    public let session: URLSession
    public let authURL: String
    public let baseURL: String
    
    public init(
        session: URLSession? = nil,
        authURL: String = "https://auth-prod.api.wyze.com",
        baseURL: String = "https://api.wyzecam.com"
    ) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10.0
            config.timeoutIntervalForResource = 10.0
            self.session = URLSession(configuration: config)
        }
        self.authURL = authURL
        self.baseURL = baseURL
    }
    
    // MARK: - Errors
    
    public enum WyzeError: LocalizedError, Sendable {
        case invalidURL(String)
        case httpError(statusCode: Int, responseBody: String)
        case apiError(code: String, message: String)
        case missingToken
        case decodingFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL(let url):
                return "Invalid URL: \(url)"
            case .httpError(let code, let body):
                return "HTTP \(code) error from Wyze: \(body)"
            case .apiError(let code, let msg):
                return "Wyze API error (\(code)): \(msg)"
            case .missingToken:
                return "No access token found in response."
            case .decodingFailed(let reason):
                return "Failed to decode Wyze response: \(reason)"
            }
        }
    }
    
    // MARK: - Models
    
    public struct LoginRequest: Codable, Sendable {
        public let email: String
        public let password: String
        public let nonce: String
    }
    
    public struct LoginResponse: Codable, Sendable {
        public let accessToken: String?
        public let errorCode: String?
        public let description: String?
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case errorCode = "error_code"
            case description
        }
    }
    
    public struct DeviceListBaseResponse: Codable, Sendable {
        public let code: String?
        public let msg: String?
        public let data: DeviceListData?
    }
    
    public struct DeviceListData: Codable, Sendable {
        public let deviceList: [WyzeDeviceItem]?
        
        enum CodingKeys: String, CodingKey {
            case deviceList = "device_list"
        }
    }
    
    public struct WyzeDeviceItem: Codable, Sendable, Identifiable {
        public let mac: String
        public let nickname: String
        public let productModel: String
        public let productType: String
        
        public var id: String { mac }
        public var name: String { nickname.isEmpty ? productModel : nickname }
        
        enum CodingKeys: String, CodingKey {
            case mac
            case nickname
            case productModel = "product_model"
            case productType = "product_type"
        }
    }
    
    public struct SetStateRequest: Codable, Sendable {
        public let accessToken: String
        public let appName: String
        public let appVer: String
        public let appVersion: String
        public let phoneId: String
        public let phoneSystemType: String
        public let sc: String
        public let ts: Int
        public let sv: String
        public let deviceMac: String?
        public let deviceModel: String?
        public let pid: String?
        public let pvalue: String?
        public let actionList: [ActionItem]?
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case appName = "app_name"
            case appVer = "app_ver"
            case appVersion = "app_version"
            case phoneId = "phone_id"
            case phoneSystemType = "phone_system_type"
            case sc, ts, sv
            case deviceMac = "device_mac"
            case deviceModel = "device_model"
            case pid, pvalue
            case actionList = "action_list"
        }
    }
    
    public struct ActionItem: Codable, Sendable {
        public let actionKey: String
        public let actionParams: ActionParams
        public let instanceId: String
        public let providerKey: String
        
        enum CodingKeys: String, CodingKey {
            case actionKey = "action_key"
            case actionParams = "action_params"
            case instanceId = "instance_id"
            case providerKey = "provider_key"
        }
    }
    
    public struct ActionParams: Codable, Sendable {
        public let list: [ActionParamItem]
    }
    
    public struct ActionParamItem: Codable, Sendable {
        public let mac: String
        public let plist: [PlistItem]
    }
    
    public struct PlistItem: Codable, Sendable {
        public let pid: String
        public let pvalue: String
    }
    
    public struct CommandResponse: Codable, Sendable {
        public let code: String?
        public let msg: String?
    }
    
    // MARK: - API Methods
    
    /// Authenticate against Wyze Auth API and return access token.
    public func login(email: String, password: String) async throws -> String {
        guard let url = URL(string: "\(authURL)/user/login") else {
            throw WyzeError.invalidURL("\(authURL)/user/login")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let md5Pass = Insecure.MD5.hash(data: Data(password.utf8))
            .map { String(format: "%02hhx", $0) }
            .joined()
        let nonce = String(Int(Date().timeIntervalSince1970 * 1000))
        
        let payload = LoginRequest(email: email, password: md5Pass, nonce: nonce)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        let respStr = String(data: data, encoding: .utf8) ?? ""
        
        guard statusCode == 200 else {
            throw WyzeError.httpError(statusCode: statusCode, responseBody: respStr)
        }
        
        let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
        if let err = decoded.errorCode, err != "1" && err != "0000" && err != "100" {
            throw WyzeError.apiError(code: err, message: decoded.description ?? "Login failed")
        }
        
        guard let token = decoded.accessToken else {
            throw WyzeError.missingToken
        }
        return token
    }
    
    /// Fetch all registered devices for this Wyze account.
    public func getDevices(accessToken: String) async throws -> [WyzeDeviceItem] {
        guard let url = URL(string: "\(baseURL)/app/v2/home_page/get_object_list") else {
            throw WyzeError.invalidURL("\(baseURL)/app/v2/home_page/get_object_list")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let nonce = Int(Date().timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "access_token": accessToken,
            "app_name": "com.hualai.WyzeCam",
            "app_ver": "com.hualai.WyzeCam___2.3.8",
            "app_version": "2.3.8",
            "phone_id": UUID().uuidString,
            "phone_system_type": "1",
            "sc": "9f275790cabfaa04cbc9650e608eefcd",
            "sv": "5e02224ae0c64d328154737602d28833",
            "ts": nonce
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        let respStr = String(data: data, encoding: .utf8) ?? ""
        
        guard statusCode == 200 else {
            throw WyzeError.httpError(statusCode: statusCode, responseBody: respStr)
        }
        
        let decoded = try JSONDecoder().decode(DeviceListBaseResponse.self, from: data)
        return decoded.data?.deviceList ?? []
    }
    
    /// Set power state for a Wyze switch, plug, or bulb.
    public func setDeviceState(mac: String, model: String, isOn: Bool, accessToken: String) async throws -> String {
        let isMesh = ["WLPA19C", "HL_BR30C", "HL_LSL", "HL_LSLP"].contains(model)
        let urlPath = isMesh ? "/app/v2/auto/run_action_list" : "/app/v2/device/set_property"
        guard let url = URL(string: "\(baseURL)\(urlPath)") else {
            throw WyzeError.invalidURL("\(baseURL)\(urlPath)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let nonce = Int(Date().timeIntervalSince1970 * 1000)
        let payload: SetStateRequest
        
        if isMesh {
            let actionItem = ActionItem(
                actionKey: "set_mesh_property",
                actionParams: ActionParams(list: [
                    ActionParamItem(mac: mac, plist: [
                        PlistItem(pid: "P3", pvalue: isOn ? "1" : "0")
                    ])
                ]),
                instanceId: mac,
                providerKey: model
            )
            payload = SetStateRequest(
                accessToken: accessToken,
                appName: "com.hualai.WyzeCam",
                appVer: "com.hualai.WyzeCam___2.3.8",
                appVersion: "2.3.8",
                phoneId: UUID().uuidString,
                phoneSystemType: "1",
                sc: "9f275790cabfaa04cbc9650e608eefcd",
                ts: nonce,
                sv: "5e02224ae0c64d328154737602d28833",
                deviceMac: nil,
                deviceModel: nil,
                pid: nil,
                pvalue: nil,
                actionList: [actionItem]
            )
        } else {
            payload = SetStateRequest(
                accessToken: accessToken,
                appName: "com.hualai.WyzeCam",
                appVer: "com.hualai.WyzeCam___2.3.8",
                appVersion: "2.3.8",
                phoneId: UUID().uuidString,
                phoneSystemType: "1",
                sc: "9f275790cabfaa04cbc9650e608eefcd",
                ts: nonce,
                sv: "5e02224ae0c64d328154737602d28833",
                deviceMac: mac,
                deviceModel: model,
                pid: "P3",
                pvalue: isOn ? "1" : "0",
                actionList: nil
            )
        }
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        let respStr = String(data: data, encoding: .utf8) ?? ""
        
        guard statusCode == 200 else {
            throw WyzeError.httpError(statusCode: statusCode, responseBody: respStr)
        }
        
        let decoded = try JSONDecoder().decode(CommandResponse.self, from: data)
        if let code = decoded.code, code != "1" && code != "0000" && code != "100" {
            throw WyzeError.apiError(code: code, message: decoded.msg ?? "Failed to toggle device")
        }
        return "Success"
    }
}
