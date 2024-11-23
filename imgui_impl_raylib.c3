/**********************************************************************************************
*
*   raylibExtras * Utilities and Shared Components for Raylib
*
*   rlImGui * basic ImGui integration
*
*   LICENSE: ZLIB
*
*   Copyright (c) 2024 Jeffery Myers
*
*   Permission is hereby granted, free of charge, to any person obtaining a copy
*   of this software and associated documentation files (the "Software"), to deal
*   in the Software without restriction, including without limitation the rights
*   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
*   copies of the Software, and to permit persons to whom the Software is
*   furnished to do so, subject to the following conditions:
*
*   The above copyright notice and this permission notice shall be included in all
*   copies or substantial portions of the Software.
*
*   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
*   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
*   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
*   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
*   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
*   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*   SOFTWARE.
*
**********************************************************************************************/
module impl;

import imgui;
import rl;
import rlgl;

import std::math;
import std::collections::map;

//#ifndef NO_FONT_AWESOME
//#include "extras/FA6FreeSolidFontData.h"
//#endif

tlocal ImGuiMouseCursor current_mouse_cursor = imgui::MOUSE_CURSOR_COUNT;
tlocal ImGuiMouseCursor[(int)imgui::MOUSE_CURSOR_COUNT] mouse_cursor_map;

ImGuiContext* global_context = null;

tlocal map::Map(<KeyboardKey, ImGuiKey>) raylib_keymap;

tlocal bool last_frame_focused = false;

tlocal bool last_control_pressed = false;
tlocal bool last_shift_pressed = false;
tlocal bool last_alt_pressed = false;
tlocal bool last_super_pressed = false;

// internal only functions
fn bool rlImGuiIsControlDown() { return rl::isKeyDown(rl::KEY_RIGHT_CONTROL) || rl::isKeyDown(rl::KEY_LEFT_CONTROL); }
fn bool rlImGuiIsShiftDown() { return rl::isKeyDown(rl::KEY_RIGHT_SHIFT) || rl::isKeyDown(rl::KEY_LEFT_SHIFT); }
fn bool rlImGuiIsAltDown() { return rl::isKeyDown(rl::KEY_RIGHT_ALT) || rl::isKeyDown(rl::KEY_LEFT_ALT); }
fn bool rlImGuiIsSuperDown() { return rl::isKeyDown(rl::KEY_RIGHT_SUPER) || rl::isKeyDown(rl::KEY_LEFT_SUPER); }

fn void reload_fonts()
{
    ImGuiIO* io = imgui::get_io();
    char* pixels = null;

    int width;
    int height;
    io.fonts.get_tex_data_as_rgba32(&pixels, &width, &height, null);
    Image image = rl::genImageColor(width, height, rl::BLANK);
    mem::copy(image.data, pixels, (usz)(width * height * 4));

    Texture2D* fontTexture = (Texture2D*)io.fonts.tex_id;
    if (fontTexture && fontTexture.id != 0)
    {
        fontTexture.unload();
        rl::memFree(fontTexture);
    }

    fontTexture = (Texture2D*)rl::memAlloc(Texture2D.sizeof);
    *fontTexture = rl::loadTextureFromImage(image);
    image.unload();
    io.fonts.tex_id = (ImTextureID)fontTexture;
}

fn ZString getClipTextCallback(ImGuiContext*) @private
{
    return rl::getClipboardText();
}

fn void setClipTextCallback(ImGuiContext*, ZString text) @private
{
    rl::setClipboardText(text);
}

fn void imGuiNewFrame(float deltaTime) @private
{
    ImGuiIO* io = imgui::get_io();

    Vector2 resolutionScale = rl::getWindowScaleDpi();

//#ifndef PLATFORM_DRM
    if (rl::isWindowFullscreen())
    {
        int monitor = rl::getCurrentMonitor();
        io.display_size.x = (float)(rl::getMonitorWidth(monitor));
        io.display_size.y = (float)(rl::getMonitorHeight(monitor));
    }
    else
    {
        io.display_size.x = (float)(rl::getScreenWidth());
        io.display_size.y = (float)(rl::getScreenHeight());
    }

$if $defined(env::DARWIN):
    if (!rl::isWindowState(rl::FLAG_WINDOW_HIGHDPI)) {
        resolutionScale = Vector2{ 1,1 };
    }
$endif
//#else
//    io.display_size.x = (float)(rl::getScreenWidth());
//    io.display_size.y = (float)(rl::getScreenHeight());
//#endif

    io.display_framebuffer_scale = ImVec2{resolutionScale.x, resolutionScale.y};

    if (deltaTime <= 0) {
        deltaTime = 0.001f;
    }

    io.delta_time = deltaTime;

    if (io.backend_flags & imgui::BACKEND_FLAGS_HAS_MOUSE_CURSORS)
    {
        if ((io.config_flags & imgui::CONFIG_FLAGS_NO_MOUSE_CURSOR_CHANGE) == 0)
        {
            ImGuiMouseCursor imgui_cursor = imgui::get_mouse_cursor();
            if (imgui_cursor != current_mouse_cursor || io.mouse_draw_cursor)
            {
                current_mouse_cursor = imgui_cursor;
                if (io.mouse_draw_cursor || imgui_cursor == imgui::MOUSE_CURSOR_NONE)
                {
                    rl::hideCursor();
                }
                else
                {
                    rl::showCursor();

                    if (!(io.config_flags & imgui::CONFIG_FLAGS_NO_MOUSE_CURSOR_CHANGE))
                    {
                        rl::setMouseCursor((imgui_cursor > -1 && imgui_cursor < imgui::MOUSE_CURSOR_COUNT) ? mouse_cursor_map[imgui_cursor] : rl::MOUSE_CURSOR_DEFAULT);
                    }
                }
            }
        }
    }
}

fn void imGuiTriangleVert(ImDrawVert* idx_vert) @private
{
    Color* c;
    c = (Color*)&idx_vert.col;
    rlgl::color4ub(c.r, c.g, c.b, c.a);
    rlgl::texCoord2f(idx_vert.uv.x, idx_vert.uv.y);
    rlgl::vertex2f(idx_vert.pos.x, idx_vert.pos.y);
}

fn void imGuiRenderTriangles(uint count, int indexStart, vector::ImVector(<ImDrawIdx>)* indexBuffer, vector::ImVector(<ImDrawVert>)* vertBuffer, void* texturePtr) @private
{
    if (count < 3) {
        return;
    }

    Texture* texture = (Texture*)texturePtr;

    uint textureId = (texture == null) ? 0 : texture.id;

    rlgl::begin(rlgl::TRIANGLES);
    rlgl::setTexture(textureId);

    for (uint i = 0; i <= (count - 3); i += 3)
    {
        ImDrawIdx indexA = indexBuffer.list()[indexStart + i];
        ImDrawIdx indexB = indexBuffer.list()[indexStart + i + 1];
        ImDrawIdx indexC = indexBuffer.list()[indexStart + i + 2];

        ImDrawVert vertexA = vertBuffer.list()[indexA];
        ImDrawVert vertexB = vertBuffer.list()[indexB];
        ImDrawVert vertexC = vertBuffer.list()[indexC];

        imGuiTriangleVert(&vertexA);
        imGuiTriangleVert(&vertexB);
        imGuiTriangleVert(&vertexC);
    }
    rlgl::end();
}

fn void enableScissor(float x, float y, float width, float height) @private
{
    rlgl::enableScissorTest();
    ImGuiIO* io = imgui::get_io();

    ImVec2 scale = io.display_framebuffer_scale;
$if !$defined(env::DARWIN):
    if (!rl::isWindowState(rl::FLAG_WINDOW_HIGHDPI))
    {
        scale.x = 1;
        scale.y = 1;
    }
$endif

    rlgl::scissor((int)(x * scale.x),
        (int)((io.display_size.y - (int)(y + height)) * scale.y),
        (int)(width * scale.x),
        (int)(height * scale.y));
}

fn void setupMouseCursors() @private
{
    mouse_cursor_map[imgui::MOUSE_CURSOR_ARROW] = rl::MOUSE_CURSOR_ARROW;
    mouse_cursor_map[imgui::MOUSE_CURSOR_TEXT_INPUT] = rl::MOUSE_CURSOR_IBEAM;
    mouse_cursor_map[imgui::MOUSE_CURSOR_HAND] = rl::MOUSE_CURSOR_POINTING_HAND;
    mouse_cursor_map[imgui::MOUSE_CURSOR_RESIZE_ALL] = rl::MOUSE_CURSOR_RESIZE_ALL;
    mouse_cursor_map[imgui::MOUSE_CURSOR_RESIZE_EW] = rl::MOUSE_CURSOR_RESIZE_EW;
    mouse_cursor_map[imgui::MOUSE_CURSOR_RESIZE_NESW] = rl::MOUSE_CURSOR_RESIZE_NESW;
    mouse_cursor_map[imgui::MOUSE_CURSOR_RESIZE_NS] = rl::MOUSE_CURSOR_RESIZE_NS;
    mouse_cursor_map[imgui::MOUSE_CURSOR_RESIZE_NWSE] = rl::MOUSE_CURSOR_RESIZE_NWSE;
    mouse_cursor_map[imgui::MOUSE_CURSOR_NOT_ALLOWED] = rl::MOUSE_CURSOR_NOT_ALLOWED;
}

//fn void setupFontAwesome()
//{
//$if !$define(NO_FONT_AWESOME):
//    ImWchar[] icons_ranges = { ICON_MIN_FA, ICON_MAX_FA, 0 };
//    ImFontConfig icons_config;
//    icons_config.merge_mode = true;
//    icons_config.pixel_snap_h = true;
//    icons_config.font_data_owned_by_atlas = false;
//
//    icons_config.glyph_max_advance_x = float.max;
//    icons_config.rasterizer_multiply = 1.0f;
//    icons_config.oversample_h = 2;
//    icons_config.oversample_v = 1;
//
//    icons_config.glyph_ranges = icons_ranges;
//
//    ImGuiIO* io = imgui::get_io();
//
//    io.fonts.add_font_from_memory_compressed_ttf((void*)fa_solid_900_compressed_data, fa_solid_900_compressed_size, FONT_AWESOME_ICON_SIZE, &icons_config, icons_ranges);
//$endif
//
//}

fn void setupBackend()
{
    ImGuiIO* io = imgui::get_io();
    io.backend_platform_name = "imgui_impl_raylib";
    io.backend_flags |= imgui::BACKEND_FLAGS_HAS_GAMEPAD | imgui::BACKEND_FLAGS_HAS_SET_MOUSE_POS;

$if !$defined(PLATFORM_DRM):
    io.backend_flags |= imgui::BACKEND_FLAGS_HAS_MOUSE_CURSORS;
$endif

    io.mouse_pos = ImVec2{0, 0};

    ImGuiPlatformIO* platformIO = imgui::get_platform_io();

    platformIO.platform_set_clipboard_text_fn = &setClipTextCallback;
    platformIO.platform_get_clipboard_text_fn = &getClipTextCallback;

    platformIO.platform_clipboard_user_data = null;
}

fn void rlImGuiEndInitImGui()
{
    imgui::set_current_context(global_context);

    //setupFontAwesome();

    setupMouseCursors();

    setupBackend();

    reload_fonts();
}

fn void setupKeymap() @private
{
    if (!raylib_keymap.is_empty()) {
        return;
    }

    // build up a map of raylib keys to ImGuiKeys
    raylib_keymap[rl::KEY_APOSTROPHE] = imgui::KEY_APOSTROPHE;
    raylib_keymap[rl::KEY_COMMA] = imgui::KEY_COMMA;
    raylib_keymap[rl::KEY_MINUS] = imgui::KEY_MINUS;
    raylib_keymap[rl::KEY_PERIOD] = imgui::KEY_PERIOD;
    raylib_keymap[rl::KEY_SLASH] = imgui::KEY_SLASH;
    raylib_keymap[rl::KEY_ZERO] = imgui::KEY_0;
    raylib_keymap[rl::KEY_ONE] = imgui::KEY_1;
    raylib_keymap[rl::KEY_TWO] = imgui::KEY_2;
    raylib_keymap[rl::KEY_THREE] = imgui::KEY_3;
    raylib_keymap[rl::KEY_FOUR] = imgui::KEY_4;
    raylib_keymap[rl::KEY_FIVE] = imgui::KEY_5;
    raylib_keymap[rl::KEY_SIX] = imgui::KEY_6;
    raylib_keymap[rl::KEY_SEVEN] = imgui::KEY_7;
    raylib_keymap[rl::KEY_EIGHT] = imgui::KEY_8;
    raylib_keymap[rl::KEY_NINE] = imgui::KEY_9;
    raylib_keymap[rl::KEY_SEMICOLON] = imgui::KEY_SEMICOLON;
    raylib_keymap[rl::KEY_EQUAL] = imgui::KEY_EQUAL;
    raylib_keymap[rl::KEY_A] = imgui::KEY_A;
    raylib_keymap[rl::KEY_B] = imgui::KEY_B;
    raylib_keymap[rl::KEY_C] = imgui::KEY_C;
    raylib_keymap[rl::KEY_D] = imgui::KEY_D;
    raylib_keymap[rl::KEY_E] = imgui::KEY_E;
    raylib_keymap[rl::KEY_F] = imgui::KEY_F;
    raylib_keymap[rl::KEY_G] = imgui::KEY_G;
    raylib_keymap[rl::KEY_H] = imgui::KEY_H;
    raylib_keymap[rl::KEY_I] = imgui::KEY_I;
    raylib_keymap[rl::KEY_J] = imgui::KEY_J;
    raylib_keymap[rl::KEY_K] = imgui::KEY_K;
    raylib_keymap[rl::KEY_L] = imgui::KEY_L;
    raylib_keymap[rl::KEY_M] = imgui::KEY_M;
    raylib_keymap[rl::KEY_N] = imgui::KEY_N;
    raylib_keymap[rl::KEY_O] = imgui::KEY_O;
    raylib_keymap[rl::KEY_P] = imgui::KEY_P;
    raylib_keymap[rl::KEY_Q] = imgui::KEY_Q;
    raylib_keymap[rl::KEY_R] = imgui::KEY_R;
    raylib_keymap[rl::KEY_S] = imgui::KEY_S;
    raylib_keymap[rl::KEY_T] = imgui::KEY_T;
    raylib_keymap[rl::KEY_U] = imgui::KEY_U;
    raylib_keymap[rl::KEY_V] = imgui::KEY_V;
    raylib_keymap[rl::KEY_W] = imgui::KEY_W;
    raylib_keymap[rl::KEY_X] = imgui::KEY_X;
    raylib_keymap[rl::KEY_Y] = imgui::KEY_Y;
    raylib_keymap[rl::KEY_Z] = imgui::KEY_Z;
    raylib_keymap[rl::KEY_SPACE] = imgui::KEY_SPACE;
    raylib_keymap[rl::KEY_ESCAPE] = imgui::KEY_ESCAPE;
    raylib_keymap[rl::KEY_ENTER] = imgui::KEY_ENTER;
    raylib_keymap[rl::KEY_TAB] = imgui::KEY_TAB;
    raylib_keymap[rl::KEY_BACKSPACE] = imgui::KEY_BACKSPACE;
    raylib_keymap[rl::KEY_INSERT] = imgui::KEY_INSERT;
    raylib_keymap[rl::KEY_DELETE] = imgui::KEY_DELETE;
    raylib_keymap[rl::KEY_RIGHT] = imgui::KEY_RIGHT_ARROW;
    raylib_keymap[rl::KEY_LEFT] = imgui::KEY_LEFT_ARROW;
    raylib_keymap[rl::KEY_DOWN] = imgui::KEY_DOWN_ARROW;
    raylib_keymap[rl::KEY_UP] = imgui::KEY_UP_ARROW;
    raylib_keymap[rl::KEY_PAGE_UP] = imgui::KEY_PAGE_UP;
    raylib_keymap[rl::KEY_PAGE_DOWN] = imgui::KEY_PAGE_DOWN;
    raylib_keymap[rl::KEY_HOME] = imgui::KEY_HOME;
    raylib_keymap[rl::KEY_END] = imgui::KEY_END;
    raylib_keymap[rl::KEY_CAPS_LOCK] = imgui::KEY_CAPS_LOCK;
    raylib_keymap[rl::KEY_SCROLL_LOCK] = imgui::KEY_SCROLL_LOCK;
    raylib_keymap[rl::KEY_NUM_LOCK] = imgui::KEY_NUM_LOCK;
    raylib_keymap[rl::KEY_PRINT_SCREEN] = imgui::KEY_PRINT_SCREEN;
    raylib_keymap[rl::KEY_PAUSE] = imgui::KEY_PAUSE;
    raylib_keymap[rl::KEY_F1] = imgui::KEY_F1;
    raylib_keymap[rl::KEY_F2] = imgui::KEY_F2;
    raylib_keymap[rl::KEY_F3] = imgui::KEY_F3;
    raylib_keymap[rl::KEY_F4] = imgui::KEY_F4;
    raylib_keymap[rl::KEY_F5] = imgui::KEY_F5;
    raylib_keymap[rl::KEY_F6] = imgui::KEY_F6;
    raylib_keymap[rl::KEY_F7] = imgui::KEY_F7;
    raylib_keymap[rl::KEY_F8] = imgui::KEY_F8;
    raylib_keymap[rl::KEY_F9] = imgui::KEY_F9;
    raylib_keymap[rl::KEY_F10] = imgui::KEY_F10;
    raylib_keymap[rl::KEY_F11] = imgui::KEY_F11;
    raylib_keymap[rl::KEY_F12] = imgui::KEY_F12;
    raylib_keymap[rl::KEY_LEFT_SHIFT] = imgui::KEY_LEFT_SHIFT;
    raylib_keymap[rl::KEY_LEFT_CONTROL] = imgui::KEY_LEFT_CTRL;
    raylib_keymap[rl::KEY_LEFT_ALT] = imgui::KEY_LEFT_ALT;
    raylib_keymap[rl::KEY_LEFT_SUPER] = imgui::KEY_LEFT_SUPER;
    raylib_keymap[rl::KEY_RIGHT_SHIFT] = imgui::KEY_RIGHT_SHIFT;
    raylib_keymap[rl::KEY_RIGHT_CONTROL] = imgui::KEY_RIGHT_CTRL;
    raylib_keymap[rl::KEY_RIGHT_ALT] = imgui::KEY_RIGHT_ALT;
    raylib_keymap[rl::KEY_RIGHT_SUPER] = imgui::KEY_RIGHT_SUPER;
    raylib_keymap[rl::KEY_KB_MENU] = imgui::KEY_MENU;
    raylib_keymap[rl::KEY_LEFT_BRACKET] = imgui::KEY_LEFT_BRACKET;
    raylib_keymap[rl::KEY_BACKSLASH] = imgui::KEY_BACKSLASH;
    raylib_keymap[rl::KEY_RIGHT_BRACKET] = imgui::KEY_RIGHT_BRACKET;
    raylib_keymap[rl::KEY_GRAVE] = imgui::KEY_GRAVE_ACCENT;
    raylib_keymap[rl::KEY_KP_0] = imgui::KEY_KEYPAD0;
    raylib_keymap[rl::KEY_KP_1] = imgui::KEY_KEYPAD1;
    raylib_keymap[rl::KEY_KP_2] = imgui::KEY_KEYPAD2;
    raylib_keymap[rl::KEY_KP_3] = imgui::KEY_KEYPAD3;
    raylib_keymap[rl::KEY_KP_4] = imgui::KEY_KEYPAD4;
    raylib_keymap[rl::KEY_KP_5] = imgui::KEY_KEYPAD5;
    raylib_keymap[rl::KEY_KP_6] = imgui::KEY_KEYPAD6;
    raylib_keymap[rl::KEY_KP_7] = imgui::KEY_KEYPAD7;
    raylib_keymap[rl::KEY_KP_8] = imgui::KEY_KEYPAD8;
    raylib_keymap[rl::KEY_KP_9] = imgui::KEY_KEYPAD9;
    raylib_keymap[rl::KEY_KP_DECIMAL] = imgui::KEY_KEYPAD_DECIMAL;
    raylib_keymap[rl::KEY_KP_DIVIDE] = imgui::KEY_KEYPAD_DIVIDE;
    raylib_keymap[rl::KEY_KP_MULTIPLY] = imgui::KEY_KEYPAD_MULTIPLY;
    raylib_keymap[rl::KEY_KP_SUBTRACT] = imgui::KEY_KEYPAD_SUBTRACT;
    raylib_keymap[rl::KEY_KP_ADD] = imgui::KEY_KEYPAD_ADD;
    raylib_keymap[rl::KEY_KP_ENTER] = imgui::KEY_KEYPAD_ENTER;
    raylib_keymap[rl::KEY_KP_EQUAL] = imgui::KEY_KEYPAD_EQUAL;
}

fn void setupGlobals() @private
{
    last_frame_focused = rl::isWindowFocused();
    last_control_pressed = false;
    last_shift_pressed = false;
    last_alt_pressed = false;
    last_super_pressed = false;
}

fn void rlImGuiBeginInitImGui()
{
    setupGlobals();
    if (global_context == null) {
        global_context = imgui::create_context();
    }
    setupKeymap();

    ImGuiIO* io = imgui::get_io();
    io.fonts.add_font_default();
}

fn void rlImGuiSetup(bool dark)
{
    rlImGuiBeginInitImGui();

    if (dark) {
        imgui::style_colors_dark();
    } else {
        imgui::style_colors_light();
    }

    rlImGuiEndInitImGui();
}

fn void rlImGuiReloadFonts()
{
    imgui::set_current_context(global_context);

    reload_fonts();
}

fn void rlImGuiBegin()
{
    imgui::set_current_context(global_context);
    rlImGuiBeginDelta(rl::getFrameTime());
}

fn void rlImGuiBeginDelta(float deltaTime)
{
    imgui::set_current_context(global_context);

    imGuiNewFrame(deltaTime);
    imGui_ImplRaylib_ProcessEvents();
    imgui::new_frame();
}

fn void rlImGuiEnd()
{
    imgui::set_current_context(global_context);
    imgui::render();
    imGui_ImplRaylib_RenderDrawData(imgui::get_draw_data());
}

fn void rlImGuiShutdown()
{
    if (global_context == null) {
        return;
    }

    imgui::set_current_context(global_context);
    imGui_ImplRaylib_Shutdown();

    imgui::destroy_context(global_context);
    global_context = null;
}

fn void rlImGuiImage(Texture* image)
{
    if (!image) {
        return;
    }
    
    if (global_context) {
        imgui::set_current_context(global_context);
    }
    
    imgui::image((ImTextureID)image, ImVec2{(float)(image.width), (float)(image.height)});
}

fn bool rlImGuiImageButton(ZString name, Texture* image)
{
    if (!image) {
        return false;
    }
    
    if (global_context) {
        imgui::set_current_context(global_context);
    }
    
    return imgui::image_button(name, (ImTextureID)image, ImVec2{(float)(image.width), (float)(image.height)});
}

fn bool rlImGuiImageButtonSize(ZString name, Texture* image, ImVec2 size)
{
    if (!image) {
        return false;
    }

    if (global_context) {
        imgui::set_current_context(global_context);
    }
   
    return imgui::image_button(name, (ImTextureID)image, size);
}

fn void rlImGuiImageSize(Texture* image, int width, int height)
{
    if (!image) {
        return;
    }
    
    if (global_context) {
        imgui::set_current_context(global_context);
    }
    
    imgui::image((ImTextureID)image, ImVec2{(float)(width), (float)(height)});
}

fn void rlImGuiImageSizeV(Texture* image, Vector2 size)
{
    if (!image) {
        return;
    }
    
    if (global_context) {
        imgui::set_current_context(global_context);
    }
    
    imgui::image((ImTextureID)image, ImVec2{size.x, size.y});
}

fn void rlImGuiImageRect(Texture* image, int destWidth, int destHeight, Rectangle sourceRect)
{
    if (!image) {
        return;
    }
    
    if (global_context) {
        imgui::set_current_context(global_context);
    }
    
    ImVec2 uv0;
    ImVec2 uv1;

    if (sourceRect.width < 0)
    {
        uv0.x = -((float)sourceRect.x / image.width);
        uv1.x = (uv0.x - (float)(math::abs(sourceRect.width) / image.width));
    }
    else
    {
        uv0.x = (float)sourceRect.x / image.width;
        uv1.x = uv0.x + (float)(sourceRect.width / image.width);
    }

    if (sourceRect.height < 0)
    {
        uv0.y = -((float)sourceRect.y / image.height);
        uv1.y = (uv0.y - (float)(math::abs(sourceRect.height) / image.height));
    }
    else
    {
        uv0.y = (float)sourceRect.y / image.height;
        uv1.y = uv0.y + (float)(sourceRect.height / image.height);
    }

    imgui::image((ImTextureID)image, ImVec2{(float)(destWidth), (float)(destHeight)}, uv0, uv1);
}

fn void rlImGuiImageRenderTexture(RenderTexture* image)
{
    if (!image) {
        return;
    }
    
    if (global_context) {
        imgui::set_current_context(global_context);
    }
    
    rlImGuiImageRect(&image.texture, image.texture.width, image.texture.height, Rectangle{ 0,0, (float)(image.texture.width), -(float)(image.texture.height) });
}

fn void rlImGuiImageRenderTextureFit(RenderTexture* image, bool center)
{
    if (!image) {
        return;
    }
    
    if (global_context) {
        imgui::set_current_context(global_context);
    }

    ImVec2 area = imgui::get_content_region_avail();

    float scale =  area.x / image.texture.width;

    float y = image.texture.height * scale;
    if (y > area.y)
    {
        scale = area.y / image.texture.height;
    }

    int sizeX = (int)(image.texture.width * scale);
    int sizeY = (int)(image.texture.height * scale);

    if (center)
    {
        imgui::set_cursor_pos_x(0);
        imgui::set_cursor_pos_x(area.x/2.0f - sizeX/2.0f);
        imgui::set_cursor_pos_y(imgui::get_cursor_pos_y() + (area.y / 2.0f - sizeY / 2.0f));
    }

    rlImGuiImageRect(&image.texture, sizeX, sizeY, Rectangle{ 0,0, (float)(image.texture.width), -(float)(image.texture.height) });
}

// raw ImGui backend API
fn bool imGui_ImplRaylib_Init()
{
    setupGlobals();

    setupKeymap();

    setupMouseCursors();

    setupBackend();

    return true;
}

fn void imGui_ImplRaylib_BuildFontAtlas()
{
    reload_fonts();
}

fn void imGui_ImplRaylib_Shutdown()
{
    ImGuiIO* io =imgui::get_io();
    Texture2D* fontTexture = (Texture2D*)io.fonts.tex_id;

    if (fontTexture)
    {
        fontTexture.unload();
        rl::memFree(fontTexture);
    }

    io.fonts.tex_id = 0;
}

fn void imGui_ImplRaylib_NewFrame()
{
    imGuiNewFrame(rl::getFrameTime());
}

fn void imGui_ImplRaylib_RenderDrawData(ImDrawData* draw_data)
{
    rlgl::drawRenderBatchActive();
    rlgl::disableBackfaceCulling();

    for (int l = 0; l < draw_data.cmd_lists_count; ++l)
    {
        ImDrawList* commandList = draw_data.cmd_lists.list()[l];

        foreach (cmd : commandList.cmd_buffer.list())
        {
            enableScissor(cmd.clip_rect.x - draw_data.display_pos.x, cmd.clip_rect.y - draw_data.display_pos.y, cmd.clip_rect.z - (cmd.clip_rect.x - draw_data.display_pos.x), cmd.clip_rect.w - (cmd.clip_rect.y - draw_data.display_pos.y));
            if (cmd.user_callback != null)
            {
                cmd.user_callback(commandList, &cmd);

                continue;
            }

            imGuiRenderTriangles(cmd.elem_count, cmd.idx_offset, &commandList.idx_buffer,  &commandList.vtx_buffer, (Texture2D*)cmd.texture_id);
            rlgl::drawRenderBatchActive();
        }
    }

    rlgl::setTexture(0);
    rlgl::disableScissorTest();
    rlgl::enableBackfaceCulling();
}

fn void handleGamepadButtonEvent(ImGuiIO* io, GamepadButton button, ImGuiKey key)
{
    if (rl::isGamepadButtonPressed(0, button)) {
        io.add_key_event(key, true);
    } else if (rl::isGamepadButtonReleased(0, button)) {
        io.add_key_event(key, false);
    }
}

fn void handleGamepadStickEvent(ImGuiIO* io, GamepadAxis axis, ImGuiKey negKey, ImGuiKey posKey)
{
    float deadZone = 0.20f;

    float axisValue = rl::getGamepadAxisMovement(0, axis);

    io.add_key_analog_event(negKey, axisValue < -deadZone, axisValue < -deadZone ? -axisValue : 0);
    io.add_key_analog_event(posKey, axisValue > deadZone, axisValue > deadZone ? axisValue : 0);
}

fn void setMouseEvent(int rayMouse, int imGuiMouse)
{
    ImGuiIO* io = imgui::get_io();
    if (rl::isMouseButtonPressed(rayMouse)) {
        io.add_mouse_button_event(imGuiMouse, true);
    } else if (rl::isMouseButtonReleased(rayMouse)) {
        io.add_mouse_button_event(imGuiMouse, false);
    }
}

fn bool imGui_ImplRaylib_ProcessEvents()
{
    ImGuiIO* io = imgui::get_io();

    bool focused = rl::isWindowFocused();
    if (focused != last_frame_focused) {
        io.add_focus_event(focused);
    }
    last_frame_focused = focused;

    // handle the modifyer key events so that shortcuts work
    bool ctrlDown = rlImGuiIsControlDown();
    if (ctrlDown != last_control_pressed) {
        io.add_key_event(imgui::MOD_CTRL, ctrlDown);
    }
    last_control_pressed = ctrlDown;

    bool shiftDown = rlImGuiIsShiftDown();
    if (shiftDown != last_shift_pressed) {
        io.add_key_event(imgui::MOD_SHIFT, shiftDown);
    }
    last_shift_pressed = shiftDown;

    bool altDown = rlImGuiIsAltDown();
    if (altDown != last_alt_pressed) {
        io.add_key_event(imgui::MOD_ALT, altDown);
    }
    last_alt_pressed = altDown;

    bool superDown = rlImGuiIsSuperDown();
    if (superDown != last_super_pressed) {
        io.add_key_event(imgui::MOD_SUPER, superDown);
    }
    last_super_pressed = superDown;

    // walk the keymap and check for up and down events
    raylib_keymap.@each(; KeyboardKey first, ImGuiKey second)
    {
        if (rl::isKeyReleased(first)) {
            io.add_key_event(second, false);
        } else if(rl::isKeyPressed(first)) {
            io.add_key_event(second, true);
        }
    };

    if (io.want_capture_keyboard)
    {
        // add the text input in order
        uint pressed = rl::getCharPressed();
        while (pressed != 0)
        {
            io.add_input_character(pressed);
            pressed = rl::getCharPressed();
        }
    }

    if (!io.want_set_mouse_pos)
    {
        io.add_mouse_pos_event((float)rl::getMouseX(), (float)rl::getMouseY());
    }

    setMouseEvent(rl::MOUSE_BUTTON_LEFT, imgui::MOUSE_BUTTON_LEFT);
    setMouseEvent(rl::MOUSE_BUTTON_RIGHT, imgui::MOUSE_BUTTON_RIGHT);
    setMouseEvent(rl::MOUSE_BUTTON_MIDDLE, imgui::MOUSE_BUTTON_MIDDLE);
    setMouseEvent(rl::MOUSE_BUTTON_FORWARD, imgui::MOUSE_BUTTON_MIDDLE + 1);
    setMouseEvent(rl::MOUSE_BUTTON_BACK, imgui::MOUSE_BUTTON_MIDDLE + 2);

    {
        Vector2 mouseWheel = rl::getMouseWheelMoveV();
        io.add_mouse_wheel_event(mouseWheel.x, mouseWheel.y);
    }

    if (io.config_flags & imgui::CONFIG_FLAGS_NAV_ENABLE_GAMEPAD && rl::isGamepadAvailable(0))
    {
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_LEFT_FACE_UP, imgui::KEY_GAMEPAD_DPAD_UP);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_LEFT_FACE_RIGHT, imgui::KEY_GAMEPAD_DPAD_RIGHT);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_LEFT_FACE_DOWN, imgui::KEY_GAMEPAD_DPAD_DOWN);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_LEFT_FACE_LEFT, imgui::KEY_GAMEPAD_DPAD_LEFT);

        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_RIGHT_FACE_UP, imgui::KEY_GAMEPAD_FACE_UP);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_RIGHT_FACE_RIGHT, imgui::KEY_GAMEPAD_FACE_LEFT);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_RIGHT_FACE_DOWN, imgui::KEY_GAMEPAD_FACE_DOWN);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_RIGHT_FACE_LEFT, imgui::KEY_GAMEPAD_FACE_RIGHT);

        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_LEFT_TRIGGER_1, imgui::KEY_GAMEPAD_L1);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_LEFT_TRIGGER_2, imgui::KEY_GAMEPAD_L2);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_RIGHT_TRIGGER_1, imgui::KEY_GAMEPAD_R1);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_RIGHT_TRIGGER_2, imgui::KEY_GAMEPAD_R2);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_LEFT_THUMB, imgui::KEY_GAMEPAD_L3);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_RIGHT_THUMB, imgui::KEY_GAMEPAD_R3);

        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_MIDDLE_LEFT, imgui::KEY_GAMEPAD_START);
        handleGamepadButtonEvent(io, rl::GAMEPAD_BUTTON_MIDDLE_RIGHT, imgui::KEY_GAMEPAD_BACK);

        // left stick
        handleGamepadStickEvent(io, rl::GAMEPAD_AXIS_LEFT_X, imgui::KEY_GAMEPAD_L_STICK_LEFT, imgui::KEY_GAMEPAD_L_STICK_RIGHT);
        handleGamepadStickEvent(io, rl::GAMEPAD_AXIS_LEFT_Y, imgui::KEY_GAMEPAD_L_STICK_UP, imgui::KEY_GAMEPAD_L_STICK_DOWN);

        // right stick
        handleGamepadStickEvent(io, rl::GAMEPAD_AXIS_RIGHT_X, imgui::KEY_GAMEPAD_R_STICK_LEFT, imgui::KEY_GAMEPAD_R_STICK_RIGHT);
        handleGamepadStickEvent(io, rl::GAMEPAD_AXIS_RIGHT_Y, imgui::KEY_GAMEPAD_R_STICK_UP, imgui::KEY_GAMEPAD_R_STICK_DOWN);
    }

    return true;
}

