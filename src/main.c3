module main;
import std::io;
import rl;
import imgui;
import rlgl;

fn int main(String[] args) {
  rl::initWindow(800, 600, "Hello, Raylib!");
  rl::rlImGuiSetup(true);

  while (!rl::windowShouldClose()) {
    rl::@drawing() {
      rl::clearBackground(rl::WHITE);

      rl::rlImGuiBegin();
      imgui::show_demo_window();
      rl::rlImGuiEnd();
    };
  }

  rl::rlImGuiShutdown();
  rl::closeWindow();
  return 0;
}
