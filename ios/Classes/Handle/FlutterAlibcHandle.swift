//
//  FlutterAlibcHandle.swift
//  flutter_alibc
//
//  Created by xing.wu on 2021/5/15.
//

import Foundation

class FlutterAlibcHandle: NSObject, AlibcWkWebViewDelegate {
    func noticeToken(result: String) {
        let array : Array = result.components(separatedBy: "=")
        let token:String = array[1]
        channel?.invokeMethod("AlibcTaokeLogin", arguments: [
            FlutterAlibcConstKey.ErrorCode : "0",
                    FlutterAlibcConstKey.ErrorMessage:"success",
                    FlutterAlibcConstKey.Data :[
                        "accessToken":token]
        ])
    }
    
    var channel : FlutterMethodChannel? = nil;
    
    init(channel:FlutterMethodChannel) {
        super.init()
        self.channel = channel
    }
    
    //    MARK: - 对flutter暴露的方法
    
    //    MARK:  初始化阿里百川
    public func initAlibc(call : FlutterMethodCall , result : @escaping FlutterResult){
        //        线上环境
        AlibcTradeSDK.sharedInstance()?.setEnv(AlibcEnvironment.release)
        let version : String = getStringFromCall(key: "version", call: call);
        let appName : String = getStringFromCall(key: "appName", call: call);
        //        判断是否存在
        if version != ""{
            AlibcTradeSDK.sharedInstance()?.setIsvVersion(version)//设置三方App版本,可用于标识App版本
        }
        if appName != ""{
            AlibcTradeSDK.sharedInstance()?.setIsvAppName(appName)//设置三方App名称,可用于标识App
        }
        //        开发阶段打开日志开关
        AlibcTradeSDK.sharedInstance()?.setDebugLogOpen(true)
        
        //        初始化
        AlibcTradeSDK.sharedInstance()?.asyncInit(success: {
            let dic = [FlutterAlibcConstKey.ErrorCode :"0",FlutterAlibcConstKey.ErrorMessage:"success"]
            result(dic);
        }, failure: { (error) in
            let dic = [FlutterAlibcConstKey.ErrorCode :String((error! as NSError).code) ,FlutterAlibcConstKey.ErrorMessage:error?.localizedDescription] as! Dictionary<String,String>
            result(dic);
        })
    }
    
    //    MARK:  淘宝登录
    public func loginTaoBao(call : FlutterMethodCall , result : @escaping FlutterResult){
        //        判断是否登录
        if(!ALBBCompatibleSession.sharedInstance().isLogin()){
            // 登陆
            let rootViewController : UIViewController = UIApplication.shared.windows.last!.rootViewController!
            ALBBSDK.sharedInstance().auth(rootViewController) {
                let userInfo : ALBBUser = ALBBCompatibleSession.sharedInstance().getUser()
                self.channel?.invokeMethod("AlibcTaobaoLogin", arguments: [
                    FlutterAlibcConstKey.ErrorCode : "0",
                            FlutterAlibcConstKey.ErrorMessage:"success",
                            FlutterAlibcConstKey.Data :[
                                //                        昵称
                                "nick":userInfo.nick,
                                //                        头像地址
                                "avatarUrl":userInfo.avatarUrl,
                                "openId":userInfo.openId,
                                "openSid":userInfo.openSid,
                                "topAccessToken":userInfo.topAccessToken,
                                "topAuthCode":userInfo.topAuthCode,]
                ])
            } failureCallback: { error in
                let dic = [FlutterAlibcConstKey.ErrorCode :String((error! as NSError).code) ,FlutterAlibcConstKey.ErrorMessage: String(error!.localizedDescription)]
                result(dic);
                self.channel?.invokeMethod("AlibcTaobaoLogin", arguments: [dic])
            }
        }else{
            // 返回数据
            let userInfo : ALBBUser = ALBBCompatibleSession.sharedInstance().getUser()
            
            channel?.invokeMethod("AlibcTaobaoLogin", arguments: [
                FlutterAlibcConstKey.ErrorCode : "0",
                        FlutterAlibcConstKey.ErrorMessage:"success",
                        FlutterAlibcConstKey.Data :[
                            //                        昵称
                            "nick":userInfo.nick,
                            //                        头像地址
                            "avatarUrl":userInfo.avatarUrl,
                            "openId":userInfo.openId,
                            "openSid":userInfo.openSid,
                            "topAccessToken":userInfo.topAccessToken,
                            "topAuthCode":userInfo.topAuthCode,]
            ])
        }
    }
    
    //    MARK:  退出登陆
    public func loginOut(call : FlutterMethodCall , result : @escaping FlutterResult){
        ALBBSDK.sharedInstance()?.logout()
    }
    
    //        MARK:  淘客授权，拿token
    
    public func taoKeLogin(call: FlutterMethodCall, result : @escaping FlutterResult){
        let rootViewController : UIViewController = UIApplication.shared.windows.last!.rootViewController!
        //            获取url
        let url : String = getStringFromCall(key: "url", call: call);
        
        //            设置showParams
        let showParams = AlibcTradeShowParams.init()
        showParams.backUrl =  getStringFromCall(key: "backUrl", call: call)
        showParams.isNeedPush = true
        showParams.isNeedCustomNativeFailMode = getBoolFromCall(key: "isNeedCustomNativeFailMode", call: call)
        //            设置openType
        let tmpType : Int = (getNumberFromCall(key: "openType", call: call)).intValue;
        showParams.openType = self.openType(mode: tmpType)
        //            降级处理措施
        let failMode : Int = (getNumberFromCall(key: "nativeFailMode", call: call)).intValue;
        showParams.nativeFailMode =  NativeFailMode(mode: failMode)
        
        //            设置打开app
        let tmpSchemeType : Int = (getNumberFromCall(key: "schemeType", call: call)).intValue;
        showParams.linkKey = schemeType(mode: tmpSchemeType)
        //            设置taokeParams
        let taokeParam = getTaokeParams(call: call) ?? nil
        
        
        //            新建一个controller去承载
        let wkvc = AlibcWkWebView()
//        wkvc.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        wkvc.delegate = self
        let res : NSInteger = AlibcTradeSDK.sharedInstance().tradeService().open(byUrl: url, identity: "trade", webView: wkvc.webview, parentController: rootViewController, showParams: showParams, taoKeParams: taokeParam, trackParam: nil) { result in
            
        } tradeProcessFailedCallback: { error in
            
        }
        //        判断
        if res == 1 {
            let nav = UINavigationController.init(rootViewController: wkvc)
            nav.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            rootViewController.present(nav, animated: false) {
                
            };
        }
        
    }
    
    //    MARK: 通过url打开，包括h5唤起手机淘宝等
    public func openByUrl(call : FlutterMethodCall , result : @escaping FlutterResult){
        let type1 : Int = (getNumberFromCall(key: "openType", call: call)).intValue;
        let openType : AlibcOpenType = self.openType(mode: type1)
        let isNeedCustomNativeFailMode : Bool = getBoolFromCall(key: "isNeedCustomNativeFailMode", call: call)
        //    不用push了，没有nav，默认都present
        //    BOOL isNeedPush = [call.arguments[@"isNeedPush"] boolValue];
        let isNeedPush : Bool = true;
        let failMode : Int = (getNumberFromCall(key: "nativeFailMode", call: call)).intValue;
        let nativeFailMode : AlibcNativeFailMode = NativeFailMode(mode: failMode)
        let schemeType1 : Int = (getNumberFromCall(key: "schemeType", call: call)).intValue;
        let linkKey : String = schemeType(mode: schemeType1)
        let url : String = getStringFromCall(key: "url", call: call);
        let taokeParam : AlibcTradeTaokeParams = getTaokeParams(call: call)!
        let trackParam : Dictionary<String,Any> = getDicFromCall(key: "trackParam", call: call)!
        let backUrl : String = getStringFromCall(key: "backUrl", call: call)
        
        
        let rootViewController : UIViewController = UIApplication.shared.windows.last!.rootViewController!
        let showParam : AlibcTradeShowParams = AlibcTradeShowParams.init()
        showParam.openType = openType
        showParam.isNeedCustomNativeFailMode = isNeedCustomNativeFailMode
        showParam.isNeedPush = isNeedPush
        showParam.nativeFailMode = nativeFailMode
        //        showParam.nativeFailMode = nativeFailMode
        showParam.linkKey = linkKey
        showParam.backUrl = backUrl
        
        AlibcTradeSDK.sharedInstance()?.tradeService()?.open(byUrl: url, identity: "trade", webView: nil, parentController: rootViewController, showParams: showParam, taoKeParams: taokeParam, trackParam: trackParam, tradeProcessSuccessCallback: { (alibcTradeResult) in
            //             交易成功，判断是付款成功还是加入购物车
            if alibcTradeResult?.result == AlibcTradeResultType.paySuccess {
                //                付款成功
                result([
                    FlutterAlibcConstKey.ErrorCode:"0",
                    FlutterAlibcConstKey.ErrorMessage:"付款成功",
                    FlutterAlibcConstKey.Data:[
                        "type":0,
                        "paySuccessOrders":alibcTradeResult?.payResult?.paySuccessOrders as Any,
                        "payFailedOrders":alibcTradeResult?.payResult?.payFailedOrders as Any,
                    ]
                ]);
            }else if alibcTradeResult?.result == AlibcTradeResultType.addCard {
                //                加入购物车
                result([
                    FlutterAlibcConstKey.ErrorCode:"0",
                    FlutterAlibcConstKey.ErrorMessage:"加入购物车成功",
                    FlutterAlibcConstKey.Data:[
                        "type":1,
                    ]
                ]);
            }
        }, tradeProcessFailedCallback: { (error) in
            let dic = [FlutterAlibcConstKey.ErrorCode :String((error! as NSError).code) ,FlutterAlibcConstKey.ErrorMessage:error?.localizedDescription] as! Dictionary<String,String>
            result(dic);
        })
    }
    
    
    //    MARK: - 私有方法
    //    MARK: - 转换
    //    MARK: 唤起类型
    private func openType(mode: Int) -> AlibcOpenType{
        var openType : AlibcOpenType = AlibcOpenType.auto
        switch mode {
        case 0:
            openType = AlibcOpenType.auto
            break
        case 1 :
            openType = AlibcOpenType.native
        default:
            break
        }
        return openType
    }
    //    MARK: 唤起端失败的策略转换
    private func NativeFailMode(mode: Int) -> AlibcNativeFailMode{
        var failType = AlibcNativeFailMode.jumpH5
        switch mode {
        case 0:
            failType = AlibcNativeFailMode.jumpH5
            break
        case 1 :
            failType = AlibcNativeFailMode.jumpDownloadPage
            break
        case 2 :
            failType = AlibcNativeFailMode.none
            break
        default:
            break
        }
        return failType
    }
    private func schemeType(mode: Int) -> String{
        var linkKey = "tmall"
        switch mode {
        case 0:
            linkKey = "tmall"
            break
        case 1 :
            linkKey = "taobao"
            break
        default:
            break
        }
        return linkKey
    }
    //    MARK: - 获取参数
    private func getStringFromCall(key:String,call : FlutterMethodCall) -> String{
        guard let result = (call.arguments as? Dictionary<String, Any>)?[key] as? String else {
            //            result(FlutterError(code: "参数异常", message: "参数url不能为空", details: nil))
            return ""
        }
        
        return result
    }
    private func getNumberFromCall(key:String,call : FlutterMethodCall) -> NSNumber{
        guard let result = (call.arguments as? Dictionary<String, Any>)?[key] as? NSNumber else {
            //            随便定个数字，如果没有，就是这个数字
            return FlutterAlibcConstKey.EmptyNum
        }
        return result
    }
    private func getBoolFromCall(key:String,call : FlutterMethodCall) -> Bool{
        guard let result = (call.arguments as? Dictionary<String, Any>)?[key] as? Bool else {
            return false
        }
        return result
    }
    
    private func getDicFromCall(key:String,call : FlutterMethodCall) -> Dictionary<String, Any>?{
        guard let result = (call.arguments as? Dictionary<String, Any>)?[key] as? Dictionary<String, Any> else {
            return nil
        }
        return result
    }
    
    //    MARK: - 设置淘客参数
    private func getTaokeParams(call : FlutterMethodCall) -> AlibcTradeTaokeParams?{
        let taoke : AlibcTradeTaokeParams = AlibcTradeTaokeParams.init()
        if getDicFromCall(key: "taoKeParams", call: call) == nil {
            return nil
        }
        let taokeParams = getDicFromCall(key: "taoKeParams", call: call)
        //        taoke.adzoneId =
        taoke.adzoneId = (taokeParams!["adzoneId"] is NSNull) ? nil : taokeParams!["adzoneId"] as? String
        taoke.pid = (taokeParams!["pid"] is NSNull) ? nil : taokeParams!["pid"] as? String
        taoke.unionId = (taokeParams!["unionId"] is NSNull) ? nil : taokeParams!["unionId"] as? String
        taoke.subPid = (taokeParams!["subPid"] is NSNull) ? nil : taokeParams!["subPid"] as? String
        taoke.extParams = (taokeParams!["extParams"] is NSNull) ? nil : taokeParams!["extParams"] as? [AnyHashable : Any]
        
        //    判断这玩意是什么格式，dic就直接赋值，jsoÏn需要转dic
        //    if ([extParams isKindOfClass:[NSDictionary class]]) {
        //        taoke.extParams = extParams;
        //    }else{
        //        解析字符串
        //        taoke.extParams = [FlutterAlibcTools dictionaryWithJsonString:extParams];
        //    }
        
        return taoke
        
    }
    private func isNil(){
        
    }
    
    
    private func openPageByNewWay(url:String,showParams:AlibcTradeShowParams,taoKeParams:AlibcTradeTaokeParams,
                                  trackParam:[AnyHashable:Any]?){
        let rootViewController : UIViewController = UIApplication.shared.windows.last!.rootViewController!
        AlibcTradeSDK.sharedInstance().tradeService().open(byUrl: url, identity: "trade", webView: nil, parentController: rootViewController, showParams: showParams, taoKeParams: taoKeParams, trackParam: trackParam) { tradeProcessResult in
            
        } tradeProcessFailedCallback: { error in
            
        }
        
    }
}
