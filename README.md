# rl_imgui.c3l

This library is a integration to ImGui for Raylib.

*NOTE: This is a ported version of [rlImGui](https://github.com/raylib-extras/rlImGui), so its usage is essentially the same is this library.*

All available functions is place within `rl` module, so importing `rl` is essentially all functions of rlimgui is already available.

# Setup

You **must** have [c3-imgui](https://github.com/NexushasTaken/c3-imgui) and [imgui.c3l](https://github.com/NexushasTaken/raylib.c3l) in your `lib` folder of your root project directory.

Using this library is fairly easy, once you import `rl` in your code, you can simple do this:
```c3
module main;
import rl;
import imgui;

fn int main(String[] args) {
  rl::initWindow(800, 600, "Hello, Raylib!");
  // call rl::rlImGuiSetup() after rl::initWindow().
  rl::rlImGuiSetup(true);

  while (!rl::windowShouldClose()) {
    rl::beginDrawing();
      rl::clearBackground(rl::WHITE);

      // call rl::rlImGuiBegin() and rl::rlImGuiEnd() between rl::beginDrawing() and rl::endDrawing(), or inside rl::@drawing() {};.
      rl::rlImGuiBegin(); // starts the ImGui content mode. Make all ImGui calls after this.

      imgui::show_demo_window();

      rl::rlImGuiEnd(); // ends the ImGui content mode. Make all ImGui calls before this.
    rl::endDrawing();
  }

  // call rl::rlImGuiShutdown() after your game loop is over, before you close the window.
  rl::rlImGuiShutdown();
  rl::closeWindow();
  return 0;
}
```
