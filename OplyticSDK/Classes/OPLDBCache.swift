//
//  OPLDBCache.swift
//  Oplytic
//
//  Copyright © 2017 Oplytic. All rights reserved.
//

import UIKit

let APPEVENTURL = URL(string: "https://api.oplct.com/appevent")
let DISABLEHOURS_KEY = "disablehours"
let LASTDISABLED_KEY = "lastdisabled"
let REQUESTTIMEOUT = 10.0
let MAX_EVENTS = 20

public class OPLDBCache: NSObject
{
    private var _lastDisabled : NSDate? = nil
    private var _disableHours : Double? = nil
    public static let sharedInstance = OPLDBCache()
    
    override init()
    {
        super.init()
        
        //TODO::remove from production, just for testing
        reset();
        
        initEventCache();
        
        _disableHours = UserDefaults.standard.object(forKey: DISABLEHOURS_KEY) as? Double
        _lastDisabled = UserDefaults.standard.object(forKey: LASTDISABLED_KEY) as? NSDate
    }
    
    private func reset(){
        
        UserDefaults.standard.set(nil, forKey: OPLYTIC_EVENT_CACHE)
        UserDefaults.standard.set(nil, forKey: DEVICETOKEN_KEY)
        UserDefaults.standard.set(nil, forKey: CLICKTOKEN_KEY)
    }
    
    private func initEventCache() {
        let eventCache = getEventCache();
        if(eventCache == nil){
            let newEventCache : [[String : Any]] = []
            setEventCache(eventCache: newEventCache)
        }else {
            sendCachedEvents()
        }
    }
    
    private func getEventCache() -> [[String : Any]]? {
        return (UserDefaults.standard.object(forKey: OPLYTIC_EVENT_CACHE) as? [[String : Any]])
    }
    
    private func setEventCache(eventCache : [[String : Any]]) {
        UserDefaults.standard.set(eventCache, forKey: OPLYTIC_EVENT_CACHE)
    }
    
    public func addEvent(data: [String: Any])
    {
        if(eventsDisabled()) {
            return
        }
        sendEvent(data: data)
    }
    
    public func sendCachedEvents()
    {
        if(eventsDisabled()){
            return
        }
        let event = popEvent()
        if(event != nil){
            sendEvent(data: event!)
        }
    }
    
    private func popEvent() -> ([String : Any]?)
    {
        var eventCache = getEventCache();
        if(eventCache != nil && !eventCache!.isEmpty){
            let data = eventCache!.removeFirst()
            setEventCache(eventCache: eventCache!)
            return data
        }
        return nil
    }
    
    private func cacheEvent(data: [String : Any])
    {
        var eventCache = getEventCache();
        if(eventCache != nil){
            if(eventCache!.count >= MAX_EVENTS){
                _ = popEvent()
            }
            eventCache!.append(data)
            setEventCache(eventCache: eventCache!)
        }
    }
    
    private func disableEvents(hours: Double)
    {
        if(hours > 0){
            _disableHours = hours
            _lastDisabled = NSDate()
            UserDefaults.standard.set(_disableHours, forKey: DISABLEHOURS_KEY)
            UserDefaults.standard.set(_lastDisabled, forKey: LASTDISABLED_KEY)
        }
    }
    
    private func eventsDisabled() -> Bool
    {
        if(_disableHours != nil && _disableHours! > 0 && _lastDisabled != nil){
            let secondsDisabled = NSDate().timeIntervalSinceReferenceDate - (_lastDisabled?.timeIntervalSinceReferenceDate)!
            let hoursDisabled = secondsDisabled / 3600;
            if(_disableHours! > hoursDisabled){
                return true;
            }
            else{
                _disableHours = nil;
                _lastDisabled = nil
                UserDefaults.standard.set(_disableHours, forKey: DISABLEHOURS_KEY)
                UserDefaults.standard.set(_lastDisabled, forKey: LASTDISABLED_KEY)
            }
        }
        return false
    }
    
    private func sendEvent(data: [String:Any])
    {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            let jsonStr = String(data: jsonData, encoding: .utf8)
            print("Sending event request to \(APPEVENTURL!)")
            print("JSON Payload: \(jsonStr!)")
            
            var request = URLRequest(url: APPEVENTURL!,
                                     cachePolicy: .reloadIgnoringCacheData,
                                     timeoutInterval: REQUESTTIMEOUT)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request) { respData, response, error in
                if let httpStatus = response as? HTTPURLResponse{
                    let status = httpStatus.statusCode
                    let serialQueue = DispatchQueue(label: "oplytic")
                    serialQueue.sync
                    {
                        self.handleResponse(data: data, status: status, respData: respData, error: error)
                    }
                }
            }
            task.resume()
        }
        catch{}
    }
    
    private func handleResponse(data: [String: Any], status: Int, respData: Data?, error: Error?)
    {
        if(status != 200){
            //network error, maybe offline or server-side issue, cache to be resent later
            cacheEvent(data: data)
            
            var msg = "Oplytic | Network Error \(status) : "
            if(error != nil){
                msg += " \(String(describing: error?.localizedDescription))"
            }
            NSLog(msg)
            return
        }
    
        if(respData != nil){
            do {
                let json = try JSONSerialization.jsonObject(with: respData!, options: .allowFragments) as! [String:Any]
                if let statusText = json["status"] as! String?{
                    if let message = json["message"] as! String?{
                        if(statusText.lowercased() == "freeze"){
                            if let hours = Double(message){
                                disableEvents(hours: hours)
                                NSLog("Oplytic | Freezing app events for \(hours) hours")
                            }
                        }
                        else if(statusText.lowercased() == "error"){
                            NSLog("Oplytic | Error removing event from cache")
                        }
                    }
                }
            } catch let error as NSError {
                NSLog("Oplytic | Error serializing response \(error)")
            }
            
            sendCachedEvents();
        }
    }
}
