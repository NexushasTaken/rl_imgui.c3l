module main;
import std::io;
import rl;
import impl;
import imgui;
import rlgl;

fn int main(String[] args) {
  rl::initWindow(800, 600, "Hello, Raylib!");
  impl::rlImGuiSetup(true);

  while (!rl::windowShouldClose()) {
    rl::@drawing() {
      rl::clearBackground(rl::WHITE);

      impl::rlImGuiBegin();
      imgui::show_demo_window();
      impl::rlImGuiEnd();
    };
  }

  impl::rlImGuiShutdown();
  rl::closeWindow();
  return 0;
}
