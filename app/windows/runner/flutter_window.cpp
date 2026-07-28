#include "flutter_window.h"

#include <algorithm>
#include <optional>

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr int kCompactSize = 170;
constexpr int kExpandedWidth = 390;
constexpr int kMinExpandedHeight = 320;
constexpr int kMaxExpandedHeight = 680;
constexpr int kWindowMargin = 24;

int ScaleLogical(HWND handle, int logical_pixels) {
  return MulDiv(logical_pixels, static_cast<int>(GetDpiForWindow(handle)), 96);
}

const flutter::EncodableMap* AsMap(const flutter::EncodableValue* value) {
  return value == nullptr ? nullptr : std::get_if<flutter::EncodableMap>(value);
}

const flutter::EncodableValue* FindValue(const flutter::EncodableMap* map,
                                         const char* key) {
  if (map == nullptr) {
    return nullptr;
  }
  const auto iterator = map->find(flutter::EncodableValue(key));
  return iterator == map->end() ? nullptr : &iterator->second;
}

bool BoolValue(const flutter::EncodableValue* value, bool fallback) {
  if (const auto bool_value = value == nullptr ? nullptr : std::get_if<bool>(value)) {
    return *bool_value;
  }
  return fallback;
}

double NumberValue(const flutter::EncodableValue* value, double fallback) {
  if (const auto double_value = value == nullptr ? nullptr : std::get_if<double>(value)) {
    return *double_value;
  }
  if (const auto int_value = value == nullptr ? nullptr : std::get_if<int32_t>(value)) {
    return *int_value;
  }
  if (const auto int64_value = value == nullptr ? nullptr : std::get_if<int64_t>(value)) {
    return static_cast<double>(*int64_value);
  }
  return fallback;
}

std::string StringValue(const flutter::EncodableValue* value,
                        const std::string& fallback) {
  if (const auto string_value = value == nullptr ? nullptr : std::get_if<std::string>(value)) {
    return *string_value;
  }
  return fallback;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  ConfigurePetWindow();
  ConfigureWindowChannel();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::ConfigurePetWindow() {
  const HWND handle = GetHandle();
  SetWindowLongPtr(handle, GWL_STYLE, WS_POPUP);
  SetWindowLongPtr(handle, GWL_EXSTYLE,
                   GetWindowLongPtr(handle, GWL_EXSTYLE) | WS_EX_TOOLWINDOW);
  SetWindowPos(handle, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);

  // Extending the DWM frame lets Flutter's transparent root canvas reveal the
  // desktop rather than the default opaque runner background.
  const MARGINS margins = {-1};
  DwmExtendFrameIntoClientArea(handle, &margins);

  const int compact_size = ScaleLogical(handle, kCompactSize);
  const int margin = ScaleLogical(handle, kWindowMargin);
  const int x = GetSystemMetrics(SM_CXSCREEN) - compact_size - margin;
  SetCompactFrame(x, margin);
}

void FlutterWindow::ConfigureWindowChannel() {
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "petfy/window",
      &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "beginDrag") {
          BeginDrag();
          result->Success();
        } else if (call.method_name() == "drag") {
          Drag();
          result->Success();
        } else if (call.method_name() == "setExpanded") {
          SetExpanded(call.arguments());
          result->Success();
        } else if (call.method_name() == "commitExpandedFrame") {
          CommitExpandedFrame();
          result->Success();
        } else if (call.method_name() == "popoverPlacement") {
          result->Success(flutter::EncodableValue(PopoverPlacement()));
        } else if (call.method_name() == "resetPosition") {
          ResetPosition();
          result->Success();
        } else if (call.method_name() == "setStartupPosition") {
          SetStartupPosition(call.arguments());
          result->Success();
        } else if (call.method_name() == "quitApp") {
          PostQuitMessage(0);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::BeginDrag() {
  GetCursorPos(&drag_origin_);
  GetWindowRect(GetHandle(), &drag_frame_);
}

void FlutterWindow::Drag() {
  POINT cursor;
  GetCursorPos(&cursor);
  const int x = drag_frame_.left + cursor.x - drag_origin_.x;
  const int y = drag_frame_.top + cursor.y - drag_origin_.y;
  SetCompactFrame(x, y);
}

void FlutterWindow::SetExpanded(const flutter::EncodableValue* arguments) {
  const auto* map = AsMap(arguments);
  if (!BoolValue(FindValue(map, "expanded"), false)) {
    SetCompactFrame(compact_frame_.left, compact_frame_.top);
    return;
  }

  const int logical_height = std::clamp(
      static_cast<int>(NumberValue(FindValue(map, "height"), kMinExpandedHeight)),
      kMinExpandedHeight, kMaxExpandedHeight);
  const int width = ScaleLogical(GetHandle(), kExpandedWidth);
  const int height = ScaleLogical(GetHandle(), logical_height);
  const bool defer_redraw = BoolValue(FindValue(map, "deferRedraw"), false);
  const std::string placement = StringValue(FindValue(map, "placement"), PopoverPlacement());
  int x = compact_frame_.right - width;
  int y = compact_frame_.top;

  if (placement == "rightDown") {
    x = compact_frame_.left;
  } else if (placement == "rightUp") {
    x = compact_frame_.left;
    y = compact_frame_.bottom - height;
  } else if (placement == "leftUp") {
    y = compact_frame_.bottom - height;
  }

  const int min_x = GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int min_y = GetSystemMetrics(SM_YVIRTUALSCREEN);
  const int max_x = min_x + GetSystemMetrics(SM_CXVIRTUALSCREEN) - width;
  const int max_y = min_y + GetSystemMetrics(SM_CYVIRTUALSCREEN) - height;
  x = std::clamp(x, min_x, max_x);
  y = std::clamp(y, min_y, max_y);

  UINT flags = SWP_NOACTIVATE;
  if (defer_redraw) {
    flags |= SWP_NOREDRAW | SWP_NOCOPYBITS;
  }
  SetWindowPos(GetHandle(), HWND_TOPMOST, x, y, width, height, flags);
}

void FlutterWindow::CommitExpandedFrame() {
  // The Flutter frame is ready by this point. Redraw only now so Windows does
  // not briefly show an empty expanded surface before the popover is mounted.
  RedrawWindow(GetHandle(), nullptr, nullptr,
               RDW_INVALIDATE | RDW_ALLCHILDREN);
  if (flutter_controller_) {
    flutter_controller_->ForceRedraw();
  }
}

void FlutterWindow::SetStartupPosition(const flutter::EncodableValue* arguments) {
  const auto* map = AsMap(arguments);
  if (!BoolValue(FindValue(map, "move"), false)) {
    return;
  }

  const std::string position = StringValue(FindValue(map, "position"), "topRight");
  const int width = GetSystemMetrics(SM_CXSCREEN);
  const int height = GetSystemMetrics(SM_CYSCREEN);
  const int compact_size = ScaleLogical(GetHandle(), kCompactSize);
  const int margin = ScaleLogical(GetHandle(), kWindowMargin);
  int x = width - compact_size - margin;
  int y = margin;

  if (position == "topLeft") {
    x = margin;
  } else if (position == "bottomRight") {
    y = height - compact_size - margin;
  } else if (position == "bottomLeft") {
    x = margin;
    y = height - compact_size - margin;
  }
  SetCompactFrame(x, y);
}

void FlutterWindow::ResetPosition() {
  const int compact_size = ScaleLogical(GetHandle(), kCompactSize);
  const int margin = ScaleLogical(GetHandle(), kWindowMargin);
  const int x = GetSystemMetrics(SM_CXSCREEN) - compact_size - margin;
  SetCompactFrame(x, margin);
}

std::string FlutterWindow::PopoverPlacement() const {
  const int center_x = (compact_frame_.left + compact_frame_.right) / 2;
  const int center_y = (compact_frame_.top + compact_frame_.bottom) / 2;
  const bool opens_right = center_x < GetSystemMetrics(SM_CXSCREEN) / 2;
  const bool opens_up = center_y > GetSystemMetrics(SM_CYSCREEN) / 2;

  if (opens_right && opens_up) return "rightUp";
  if (opens_right) return "rightDown";
  if (opens_up) return "leftUp";
  return "leftDown";
}

void FlutterWindow::SetCompactFrame(int x, int y) {
  const int compact_size = ScaleLogical(GetHandle(), kCompactSize);
  SetWindowPos(GetHandle(), HWND_TOPMOST, x, y, compact_size, compact_size,
               SWP_NOACTIVATE);
  GetWindowRect(GetHandle(), &compact_frame_);
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
