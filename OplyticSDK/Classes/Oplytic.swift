//
//  Oplytic.swift
//  Oplytic
//
//  Copyright © 2017 Oplytic. All rights reserved.
////
import UIKit
import AdSupport

let OPLYTIC_DEVICE_TOKEN = "OplyticDeviceToken"
let OPLYTIC_CLICK_TOKEN = "OplyticClickToken"
let OPLYTIC_EVENT_CACHE = "OplyticEventCache"
let INSTALL_ACTION_KEY = "Install"
let ATTRIBUTE_ACTION_KEY = "Attribute"
let PURCHASE_ACTION_KEY = "Purchase"
let OPLYTIC_UNIVERSAL_LINK_NOTIFICATION = "oplunivlink"
let API_KEY = "ak"
let DEVICETOKEN_KEY = "dt"
let APPID_KEY = "aid"
let CLIENTEVENTTOKEN_KEY = "cet"
let CLICKTOKEN_KEY = "ct"
let EVENTID_KEY = "eid"
let EVENTACTION_KEY = "ea"
let EVENTOBJECT_KEY = "eo"
let STR1_KEY = "s1"
let STR2_KEY = "s2"
let STR3_KEY = "s3"
let NUM1_KEY = "n1"
let NUM2_KEY = "n2"
let TIMESTAMP_KEY = "ts"

public protocol OplyticAttributionHandler {
    func onAttribution(clickUrl: String, data: [String: String])
}

public class Oplytic
{
    private static var _apiKey : String = ""
    private static var _appLink : String = ".oplct.com"
    private static var _appId : String = ""
    private static var _deviceToken : String?
    private static var _clickToken : String?
    private static var _cache : OPLDBCache?
    private static var _deferredClickUrl : String?
    private static var _oplyticAttributionHandler: OplyticAttributionHandler?
    
    public static func start(apiKey : String)
    {
        let oplyticQueue = DispatchQueue(label: "oplytic")
        oplyticQueue.sync
        {
            _apiKey = apiKey
            _appId = Bundle.main.bundleIdentifier!
            
            _cache = OPLDBCache.sharedInstance
            
            subscribeToBackgroundEvents()
            
            _clickToken = (UserDefaults.standard.object(forKey: OPLYTIC_CLICK_TOKEN) as? String)
            if(_clickToken == nil){
                _clickToken = ""
            }
            
            _deviceToken = (UserDefaults.standard.object(forKey: OPLYTIC_DEVICE_TOKEN) as? String)
            if(_deviceToken == nil){
                _deviceToken = createDeviceToken()
                addInstallEvent();
            }
            
            let clickUrl = getInstallClickUrl()
            if(clickUrl != nil){
                tryAttribute(clickUrl:clickUrl!)
            }
        }
    }
    
    public static func registerAttributionHandler(oplyticAttributionHandler: OplyticAttributionHandler){
        _oplyticAttributionHandler = oplyticAttributionHandler
        if(_deferredClickUrl != nil){
            attribute(clickUrl: _deferredClickUrl!)
            _deferredClickUrl = nil
        }
    }
    
    private static func subscribeToBackgroundEvents() {
        NotificationCenter.default.addObserver(Oplytic.self,
                                               selector: #selector(Oplytic.onEnterForeground),
                                               name: NSNotification.Name.UIApplicationWillEnterForeground,
                                               object: nil)
    }
    
    @objc static func onEnterForeground(notification : NSNotification) {
        let serialQueue = DispatchQueue(label: "oplytic")
        serialQueue.sync
            {
                _cache?.sendCachedEvents()
        }
    }
    
    private static func createDeviceToken() -> String {
        var token : String?
        if ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
            token = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }
        if (token == nil)
        {
            token = UUID().uuidString
        }
        UserDefaults.standard.set(token, forKey: OPLYTIC_DEVICE_TOKEN)
        return token!
    }
    
    private static func setClickToken(clickToken : String) {
        UserDefaults.standard.set(clickToken, forKey: OPLYTIC_CLICK_TOKEN)
    }
    
    public static func handleUniversalLink(userActivity : NSUserActivity) {
        let serialQueue = DispatchQueue(label: "oplytic")
        serialQueue.sync
            {
                processUniversalLink(userActivity: userActivity)
        }
    }
    
    private static func processUniversalLink(userActivity: NSUserActivity) {
        if (userActivity.activityType == NSUserActivityTypeBrowsingWeb)
        {
            let webPageURL = userActivity.webpageURL
            if(webPageURL != nil) {
                let clickUrl = "\(webPageURL!)"
                if (clickUrl.contains(_appLink)){
                    tryAttribute(clickUrl:clickUrl)
                }
            }
        }
    }
    
    public static func addPurchaseEvent(item : String,
                                        itemId: String,
                                        quantity: Double,
                                        price: Double,
                                        currency_unit : String) {
        addEvent(eventAction: PURCHASE_ACTION_KEY,
                 eventObject: item,
                 eventId: itemId,
                 str1: currency_unit,
                 str2: nil,
                 str3: nil,
                 num1: quantity,
                 num2: price)
    }
    
    
    private static func addInstallEvent() {
        var adidString : String? = nil
        if ASIdentifierManager.shared().isAdvertisingTrackingEnabled
        {
            adidString = "ADID"
        }
        addEvent(eventAction: INSTALL_ACTION_KEY,
                 eventObject: adidString,
                 eventId: nil,
                 str1: nil,
                 str2: nil,
                 str3: nil,
                 num1: nil,
                 num2: nil)
    }
    
    private static func getInstallClickUrl() -> String? {
        guard let text = UIPasteboard.general.string else { return nil }
        guard let data = Data(base64Encoded: text) else { return nil }
        guard let clickUrl = String(data: data, encoding: .utf8) else { return nil}
        if (clickUrl.contains(_appLink)){
            UIPasteboard.general.strings = []
            return clickUrl
        }
        return nil
    }
    
    private static func tryAttribute(clickUrl:String){
        var pushClickUrl = false
        var clickToken = extractClickToken(clickUrl: clickUrl)
        if(clickToken == nil){
            clickToken = UUID().uuidString
            pushClickUrl = true
        }
        if(clickToken == _clickToken) { return; } //no dupe
        _clickToken = clickToken!
        setClickToken(clickToken: _clickToken!)
        addAttributeEvent(clickToken: clickToken!, clickUrl: clickUrl, pushClickUrl: pushClickUrl)
    }
    
    private static func extractClickToken(clickUrl:String)->String?{
        if (clickUrl.contains(_appLink)) {
            var clickToken: String? = nil
            if clickUrl.count > 40 {
                let s1 = clickUrl.index(clickUrl.endIndex, offsetBy: -40)
                let e1 = clickUrl.index(clickUrl.endIndex, offsetBy: -37)
                let s2 = clickUrl.index(clickUrl.endIndex, offsetBy: -36)
                let e2 = clickUrl.index(clickUrl.endIndex, offsetBy: -1)
                let ct = clickUrl[s1...e1]
                if(ct == "&ct=" || ct == "?ct="){
                    clickToken = String(clickUrl[s2...e2])
                    return clickToken
                }
            }
        }
        return nil
    }
    
    private static func addAttributeEvent(clickToken: String, clickUrl : String, pushClickUrl: Bool)
    {
        var eventObject:String? = nil
        if(pushClickUrl){
            eventObject = clickUrl
        }
        
        addEvent(eventAction: ATTRIBUTE_ACTION_KEY,
                 eventObject: eventObject,
                 eventId: nil,
                 str1: nil,
                 str2: nil,
                 str3: nil,
                 num1: nil,
                 num2: nil)
        
        if(_oplyticAttributionHandler == nil){
            _deferredClickUrl = clickUrl
        }else {
            attribute(clickUrl: clickUrl)
        }
    }
    
    private static func attribute(clickUrl: String){
        var data = [String: String]()
        let queryItems = URLComponents(string: clickUrl)?.queryItems
        if(queryItems != nil){
            for qi in queryItems! {
                let paramName = qi.name.lowercased()
                let paramValue = qi.value
                data[paramName] = paramValue
            }
        }
        _oplyticAttributionHandler?.onAttribution(clickUrl: clickUrl, data: data)
    }
    
    public static func addEvent(eventAction: String? = nil,
                                eventObject: String? = nil,
                                eventId : String? = nil,
                                str1: String? = nil, str2: String? = nil, str3: String? = nil,
                                num1 : Double? = nil, num2: Double? = nil)
    {
        let oplyticQueue = DispatchQueue(label: "oplytic")
        oplyticQueue.sync
            {
                var data : [String : Any] = [:]
                data[API_KEY] = _apiKey
                data[CLIENTEVENTTOKEN_KEY] = UUID().uuidString
                data[DEVICETOKEN_KEY] = _deviceToken
                data[CLICKTOKEN_KEY] = _clickToken
                data[APPID_KEY] = _appId
                
                if eventAction != nil {
                    data[EVENTACTION_KEY] = eventAction!
                }
                if eventObject != nil {
                    data[EVENTOBJECT_KEY] = eventObject!
                }
                if eventId != nil {
                    data[EVENTID_KEY] = eventId!
                }
                if str1 != nil {
                    data[STR1_KEY] = str1!
                }
                if str2 != nil {
                    data[STR2_KEY] = str2!
                }
                if str3 != nil {
                    data[STR3_KEY] = str3!
                }
                if num1 != nil {
                    data[NUM1_KEY] = num1!
                }
                if num2 != nil {
                    data[NUM2_KEY] = num2!
                }
                _cache?.addEvent(data: data)
        }
    }
}
