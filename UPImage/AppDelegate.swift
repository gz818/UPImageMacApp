//
//  AppDelegate.swift
//  UPImage
//
//  Created by Pro.chen on 16/7/10.
//  Copyright © 2016年 chenxt. All rights reserved.
//

import Cocoa
import MASPreferences
import TMCache
import Carbon

func checkImageFile(_ pboard: NSPasteboard) -> Bool {
	
	let files: NSArray = pboard.propertyList(forType: NSFilenamesPboardType) as! NSArray
	let image = NSImage(contentsOfFile: files.firstObject as! String)
	guard let _ = image else {
		return false
	}
	return true
}

var autoUp: Bool {
	get {
		if let autoUp = UserDefaults.standard.value(forKey: "autoUp") {
			return autoUp as! Bool
		}
		return false
	}
	set {
		UserDefaults.standard.setValue(newValue, forKey: "autoUp")
	}
}

var appDelegate: NSObject?

var statusItem: NSStatusItem!

var imagesCacheArr: [[String: AnyObject]] = Array()

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	let pasteboardObserver = PasteboardObserver()
	
	@IBOutlet weak var MarkdownItem: NSMenuItem!//markdown
	@IBOutlet weak var window: NSWindow!//更新界面
	
	@IBOutlet weak var statusMenu: NSMenu! // 图标菜单
	@IBOutlet weak var cacheImageMenu: NSMenu!//历史
	
	@IBOutlet weak var autoUpItem: NSMenuItem!//自动上传
	@IBOutlet weak var uploadMenuItem: NSMenuItem!//上传
	
	@IBOutlet weak var cacheImageMenuItem: NSMenuItem!//历史
    //“设置”界面
	lazy var preferencesWindowController: NSWindowController = {
		
		let imageViewController = ImagePreferencesViewController()//七牛云设置界面
		let generalViewController = GeneralViewController()//基本 “捐赠界面”
		let controllers = [generalViewController, imageViewController]
		let wc = MASPreferencesWindowController(viewControllers: controllers, title: "设置")
//        注释掉貌似也没有问题
		imageViewController.window = wc?.window
		return wc!
	}()
	// APP 启动后
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		//注册快捷键
		registerHotKeys()
		
		// 重置Token
//		神马意思
		if linkType == 0 {
			MarkdownItem.state = 1
		} else {
			MarkdownItem.state = 0
		}
		
		pasteboardObserver.addSubscriber(self)
		
		if autoUp {
			
			pasteboardObserver.startObserving()
			autoUpItem.state = 1
			
		}
		
		NotificationCenter.default.addObserver(self, selector: #selector(notification), name: NSNotification.Name(rawValue: "MarkdownState"), object: nil)
		
		window.center()
		appDelegate = self
		statusItem = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
		let statusBarButton = DragDestinationView(frame: (statusItem.button?.bounds)!)
		statusItem.button?.superview?.addSubview(statusBarButton, positioned: .below, relativeTo: statusItem.button)
		let iconImage = NSImage(named: "StatusIcon")
		iconImage?.isTemplate = true
		statusItem.button?.image = iconImage
		statusItem.button?.action = #selector(showMenu)
		statusItem.button?.target = self
		
	}
	
	func notification(_ notification: Notification) {
		
        
		if (notification.object as AnyObject).int64Value == 0 {
			MarkdownItem.state = 1
		}
		else {
			MarkdownItem.state = 0
		}
		
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
//	显示菜单
	func showMenu() {
		
		let pboard = NSPasteboard.general()
		let files: NSArray? = pboard.propertyList(forType: NSFilenamesPboardType) as? NSArray
		
		if let files = files {
			let i = NSImage(contentsOfFile: files.firstObject as! String)
			i?.scalingImage()
			uploadMenuItem.image = i
			
		} else {
			let i = NSImage(pasteboard: pboard)
			i?.scalingImage()
			uploadMenuItem.image = i
			
		}
		
		let object = TMCache.shared().object(forKey: "imageCache")
		if let obj = object as? [[String: AnyObject]] {
			imagesCacheArr = obj
			
		}
		cacheImageMenuItem.submenu = makeCacheImageMenu(imagesCacheArr)
		
		statusItem.popUpMenu(statusMenu)
	}
    
	// 点击状态栏
	@IBAction func statusMenuClicked(_ sender: NSMenuItem) {
		switch sender.tag {
			
		case 1:
            // 上传
			let pboard = NSPasteboard.general()
			QiniuUpload(pboard)
			
		case 2:
            // 设置
			preferencesWindowController.showWindow(nil)
			preferencesWindowController.window?.center()
			NSApp.activate(ignoringOtherApps: true)
		case 3:
			// 退出
			NSApp.terminate(nil)
			
		case 4:
            //使用说明
			NSWorkspace.shared().open(URL(string: "http://lzqup.com")!)
		case 5:
			break
			
		case 6:
			//自动上传
			if sender.state == 0 {
				sender.state = 1
				pasteboardObserver.startObserving()
				autoUp = true
			}
			else {
				sender.state = 0
				pasteboardObserver.stopObserving()
				autoUp = false
			}
			
		case 7:
            //markdown
			if sender.state == 0 {
				sender.state = 1
				linkType = 0
				guard let imagesCache = imagesCacheArr.first else {
					return
				}
				NSPasteboard.general().clearContents()
				var picUrl = imagesCache["url"] as! String
				let fileName = NSString(string: picUrl).lastPathComponent
				picUrl = "![" + fileName + "](" + picUrl + ")"
				NSPasteboard.general().setString(picUrl, forType: NSStringPboardType)
				
			}
			else {
				sender.state = 0
				linkType = 1
				guard let imagesCache = imagesCacheArr.first else {
					return
				}
				NSPasteboard.general().clearContents()
				let picUrl = imagesCache["url"] as! String
				NSPasteboard.general().setString(picUrl, forType: NSStringPboardType)
				
			}
			
		default:
			break
		}
		
	}
	//有新版本 提示界面 按钮“去下载” “取消”
	@IBAction func btnClick(_ sender: NSButton) {
		switch sender.tag {
		case 1:
			NSWorkspace.shared().open(URL(string: "http://blog.lzqup.com/tools/2016/07/10/Tools-UPImage.html")!)
			self.window.close()
		case 2:
			self.window.close()
			
		default:
			break
		}
	}
	
    //历史
	func makeCacheImageMenu(_ imagesArr: [[String: AnyObject]]) -> NSMenu {
		let menu = NSMenu()
		if imagesArr.count == 0 {
			let item = NSMenuItem(title: "没有历史", action: nil, keyEquivalent: "")
			menu.addItem(item)
		} else {
			for index in 0..<imagesArr.count {
				let item = NSMenuItem(title: "", action: #selector(cacheImageClick(_:)), keyEquivalent: "")
				item.tag = index
				let i = imagesArr[index]["image"] as? NSImage
				i?.scalingImage()
				item.image = i
				menu.insertItem(item, at: 0)
			}
		}
		
		return menu
	}
	//历史- 图片
	func cacheImageClick(_ sender: NSMenuItem) {
		
		NSPasteboard.general().clearContents()
		
		var picUrl = imagesCacheArr[sender.tag]["url"] as! String
		
		let fileName = NSString(string: picUrl).lastPathComponent
		
		if linkType == 0 {
			picUrl = "![" + fileName + "](" + picUrl + ")"
		}
		
		NSPasteboard.general().setString(picUrl, forType: NSStringPboardType)
		NotificationMessage("图片链接获取成功", isSuccess: true)
		
	}
	
}

extension AppDelegate: NSUserNotificationCenterDelegate, PasteboardObserverSubscriber {
	// 强行通知
	func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
		return true
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
		
		print(change)
		
	}
	//粘贴板变化
	func pasteboardChanged(_ pasteboard: NSPasteboard) {
		QiniuUpload(pasteboard)
		
	}
	//注册快捷键
	func registerHotKeys() {
		
		var gMyHotKeyRef: EventHotKeyRef? = nil
		var gMyHotKeyIDU = EventHotKeyID()
		var gMyHotKeyIDM = EventHotKeyID()
		var eventType = EventTypeSpec()
		
		eventType.eventClass = OSType(kEventClassKeyboard)
		eventType.eventKind = OSType(kEventHotKeyPressed)
		gMyHotKeyIDU.signature = OSType(32)
		gMyHotKeyIDU.id = UInt32(kVK_ANSI_U);
		gMyHotKeyIDM.signature = OSType(46);
		gMyHotKeyIDM.id = UInt32(kVK_ANSI_M);
		
		RegisterEventHotKey(UInt32(kVK_ANSI_U), UInt32(cmdKey), gMyHotKeyIDU, GetApplicationEventTarget(), 0, &gMyHotKeyRef)
		
		RegisterEventHotKey(UInt32(kVK_ANSI_M), UInt32(controlKey), gMyHotKeyIDM, GetApplicationEventTarget(), 0, &gMyHotKeyRef)
		
		// Install handler.
		InstallEventHandler(GetApplicationEventTarget(), { (nextHanlder, theEvent, userData) -> OSStatus in
			var hkCom = EventHotKeyID()
			GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkCom)
			switch hkCom.id {
			case UInt32(kVK_ANSI_U):
				let pboard = NSPasteboard.general()
				QiniuUpload(pboard)
			case UInt32(kVK_ANSI_M):
				if linkType == 0 {
					linkType = 1
					NotificationCenter.default.post(name: Notification.Name(rawValue: "MarkdownState"), object: 1)
					guard let imagesCache = imagesCacheArr.last else {
						return 33
					}
					NSPasteboard.general().clearContents()
					let picUrl = imagesCache["url"] as! String
					NSPasteboard.general().setString(picUrl, forType: NSStringPboardType)
					
				}
				else {
					linkType = 0
					NotificationCenter.default.post(name: Notification.Name(rawValue: "MarkdownState"), object: 0)
					guard let imagesCache = imagesCacheArr.last else {
						return 33
					}
					NSPasteboard.general().clearContents()
					var picUrl = imagesCache["url"] as! String
					let fileName = NSString(string: picUrl).lastPathComponent
					picUrl = "![" + fileName + "](" + picUrl + ")"
					NSPasteboard.general().setString(picUrl, forType: NSStringPboardType)
				}
			default:
				break
			}
			
			return 33
			/// Check that hkCom in indeed your hotkey ID and handle it.
			}, 1, &eventType, nil, nil)
		
	}
	
}

