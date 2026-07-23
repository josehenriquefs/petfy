import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let compactSize = NSSize(width: 170, height: 170)
  private let expandedWidth: CGFloat = 390
  private let minExpandedHeight: CGFloat = 320
  private let maxExpandedHeight: CGFloat = 680
  private let anchorXKey = "petfy.window.anchorX"
  private let anchorYKey = "petfy.window.anchorY"
  private let startupPositionKey = "petfy.window.startupPosition"
  private var dragOffset = NSPoint.zero
  private var compactAnchorFrame: NSRect?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.configureFlutterTransparency(flutterViewController)
    self.configureFloatingPetWindow()
    self.configureWindowChannel(flutterViewController)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  private func configureFloatingPetWindow() {
    self.setFrame(compactFrameForSavedAnchor(), display: true)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask = [.borderless, .fullSizeContentView]
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = false
    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    self.isMovableByWindowBackground = true
    self.contentView?.wantsLayer = true
    self.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    self.contentView?.layer?.isOpaque = false
  }

  private func configureFlutterTransparency(_ flutterViewController: FlutterViewController) {
    flutterViewController.backgroundColor = .clear
    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.backgroundColor = NSColor.clear.cgColor
    flutterViewController.view.layer?.isOpaque = false
  }

  private func configureWindowChannel(_ flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "petfy/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "beginDrag":
        self.beginDrag()
        result(nil)
      case "drag":
        self.drag()
        result(nil)
      case "setExpanded":
        self.setPetExpanded(call.arguments)
        result(nil)
      case "popoverPlacement":
        result(self.popoverPlacement(for: self.frame))
      case "playSound":
        self.playSound(call.arguments as? String)
        result(nil)
      case "quitApp":
        NSApp.terminate(nil)
        result(nil)
      case "resetPosition":
        self.resetPosition()
        result(nil)
      case "setStartupPosition":
        self.setStartupPosition(call.arguments)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func beginDrag() {
    let mouse = NSEvent.mouseLocation
    let frame = self.frame
    dragOffset = NSPoint(x: mouse.x - frame.origin.x, y: mouse.y - frame.origin.y)
  }

  private func drag() {
    let mouse = NSEvent.mouseLocation
    var frame = self.frame
    frame.origin.x = mouse.x - dragOffset.x
    frame.origin.y = mouse.y - dragOffset.y
    self.setFrame(frame, display: true)
    self.compactAnchorFrame = frame
    self.saveCurrentAnchor()
  }

  private func setPetExpanded(_ arguments: Any?) {
    let expanded: Bool
    let requestedHeight: CGFloat?

    if let boolValue = arguments as? Bool {
      expanded = boolValue
      requestedHeight = nil
    } else if let dictionary = arguments as? [String: Any] {
      expanded = dictionary["expanded"] as? Bool ?? false
      if let height = dictionary["height"] as? NSNumber {
        requestedHeight = CGFloat(truncating: height)
      } else if let height = dictionary["height"] as? Double {
        requestedHeight = CGFloat(height)
      } else {
        requestedHeight = nil
      }
    } else {
      expanded = false
      requestedHeight = nil
    }

    let height = min(max(requestedHeight ?? minExpandedHeight, minExpandedHeight), maxExpandedHeight)
    let currentFrame = self.frame
    let anchorFrame = compactAnchorFrame ?? currentFrame

    if expanded {
      compactAnchorFrame = isCompactFrame(currentFrame) ? currentFrame : anchorFrame
      let placement = placementArgument(arguments) ?? popoverPlacement(for: anchorFrame)
      let size = NSSize(width: expandedWidth, height: height)
      self.setFrame(
        frameForPlacement(placement, compactFrame: anchorFrame, size: size),
        display: true,
        animate: false
      )
      return
    }

    let compactFrame = compactAnchorFrame ?? compactFrameFromExpanded(currentFrame)
    self.setFrame(frameForTopRight(NSPoint(x: compactFrame.maxX, y: compactFrame.maxY), size: compactSize), display: true, animate: false)
  }

  private func isCompactFrame(_ frame: NSRect) -> Bool {
    abs(frame.width - compactSize.width) < 2 && abs(frame.height - compactSize.height) < 2
  }

  private func placementArgument(_ arguments: Any?) -> String? {
    guard let dictionary = arguments as? [String: Any] else {
      return nil
    }
    return dictionary["placement"] as? String
  }

  private func popoverPlacement(for compactFrame: NSRect) -> String {
    guard let screenFrame = NSScreen.main?.visibleFrame else {
      return "leftDown"
    }

    let opensRight = compactFrame.midX < screenFrame.midX
    let opensUp = compactFrame.midY < screenFrame.midY

    switch (opensRight, opensUp) {
    case (true, true):
      return "rightUp"
    case (true, false):
      return "rightDown"
    case (false, true):
      return "leftUp"
    case (false, false):
      return "leftDown"
    }
  }

  private func frameForPlacement(_ placement: String, compactFrame: NSRect, size: NSSize) -> NSRect {
    let x: CGFloat
    let y: CGFloat

    switch placement {
    case "rightDown":
      x = compactFrame.minX
      y = compactFrame.maxY - size.height
    case "rightUp":
      x = compactFrame.minX
      y = compactFrame.minY
    case "leftUp":
      x = compactFrame.maxX - size.width
      y = compactFrame.minY
    default:
      x = compactFrame.maxX - size.width
      y = compactFrame.maxY - size.height
    }

    return clampedFrame(NSRect(x: x, y: y, width: size.width, height: size.height))
  }

  private func compactFrameFromExpanded(_ frame: NSRect) -> NSRect {
    let placement = popoverPlacement(for: frame)
    switch placement {
    case "rightDown":
      return NSRect(x: frame.minX, y: frame.maxY - compactSize.height, width: compactSize.width, height: compactSize.height)
    case "rightUp":
      return NSRect(x: frame.minX, y: frame.minY, width: compactSize.width, height: compactSize.height)
    case "leftUp":
      return NSRect(x: frame.maxX - compactSize.width, y: frame.minY, width: compactSize.width, height: compactSize.height)
    default:
      return NSRect(x: frame.maxX - compactSize.width, y: frame.maxY - compactSize.height, width: compactSize.width, height: compactSize.height)
    }
  }

  private func compactFrameForSavedAnchor() -> NSRect {
    let defaults = UserDefaults.standard
    let startupPosition = defaults.string(forKey: startupPositionKey) ?? "remember"
    if startupPosition != "remember" {
      return frameForStartupPosition(startupPosition, size: compactSize)
    }

    let hasSavedAnchor = defaults.object(forKey: anchorXKey) != nil &&
      defaults.object(forKey: anchorYKey) != nil

    guard hasSavedAnchor else {
      return frameForStartupPosition("topRight", size: compactSize)
    }

    let anchor = NSPoint(
      x: defaults.double(forKey: anchorXKey),
      y: defaults.double(forKey: anchorYKey)
    )

    return frameForTopRight(anchor, size: compactSize)
  }

  private func frameForTopRight(_ topRight: NSPoint, size: NSSize) -> NSRect {
    let frame = NSRect(
      x: topRight.x - size.width,
      y: topRight.y - size.height,
      width: size.width,
      height: size.height
    )

    return clampedFrame(frame)
  }

  private func frameForStartupPosition(_ position: String, size: NSSize) -> NSRect {
    guard let screenFrame = NSScreen.main?.visibleFrame else {
      return NSRect(x: 980, y: 620, width: size.width, height: size.height)
    }

    let margin: CGFloat = 24
    let x: CGFloat
    let y: CGFloat

    switch position {
    case "topLeft":
      x = screenFrame.minX + margin
      y = screenFrame.maxY - size.height - margin
    case "bottomRight":
      x = screenFrame.maxX - size.width - margin
      y = screenFrame.minY + margin
    case "bottomLeft":
      x = screenFrame.minX + margin
      y = screenFrame.minY + margin
    default:
      x = screenFrame.maxX - size.width - margin
      y = screenFrame.maxY - size.height - margin
    }

    return clampedFrame(NSRect(x: x, y: y, width: size.width, height: size.height))
  }

  private func clampedFrame(_ frame: NSRect) -> NSRect {
    var clamped = frame
    if let screenFrame = NSScreen.main?.visibleFrame {
      clamped.origin.x = min(max(clamped.origin.x, screenFrame.minX), screenFrame.maxX - clamped.width)
      clamped.origin.y = min(max(clamped.origin.y, screenFrame.minY), screenFrame.maxY - clamped.height)
    }

    return clamped
  }

  private func saveCurrentAnchor() {
    let frame = self.frame
    let defaults = UserDefaults.standard
    defaults.set(frame.maxX, forKey: anchorXKey)
    defaults.set(frame.maxY, forKey: anchorYKey)
  }

  private func resetPosition() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: anchorXKey)
    defaults.removeObject(forKey: anchorYKey)
    compactAnchorFrame = nil
    setFrame(compactFrameForSavedAnchor(), display: true, animate: true)
  }

  private func setStartupPosition(_ arguments: Any?) {
    let position: String
    let moveNow: Bool

    if let value = arguments as? String {
      position = value
      moveNow = true
    } else if let dictionary = arguments as? [String: Any] {
      position = dictionary["position"] as? String ?? "remember"
      moveNow = dictionary["move"] as? Bool ?? false
    } else {
      position = "remember"
      moveNow = false
    }

    let defaults = UserDefaults.standard
    defaults.set(position, forKey: startupPositionKey)
    if position != "remember" {
      defaults.removeObject(forKey: anchorXKey)
      defaults.removeObject(forKey: anchorYKey)
      compactAnchorFrame = nil
    }

    if moveNow {
      setFrame(compactFrameForSavedAnchor(), display: true, animate: true)
    }
  }

  private func playSound(_ sound: String?) {
    let soundName: String
    switch sound {
    case "attention":
      soundName = "Ping"
    case "completed":
      soundName = "Glass"
    default:
      soundName = "Pop"
    }

    NSSound(named: NSSound.Name(soundName))?.play()
  }
}
