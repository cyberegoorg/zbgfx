/*
 * Copyright 2014-2015 Daniel Collin. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx/blob/master/LICENSE
 */

#include <bgfx/bgfx.h>
#include <bgfx/embedded_shader.h>
#include <bx/allocator.h>
#include <bx/math.h>
#include <bx/timer.h>

#include <imgui/imgui.h>

#include "imgui.h"
#include "../bgfx_utils.h"

#ifndef USE_ENTRY
#	define USE_ENTRY 0
#endif // USE_ENTRY

#ifndef USE_LOCAL_STB
#	define USE_LOCAL_STB 1
#endif // USE_LOCAL_STB

#if USE_ENTRY
#	include "../entry/entry.h"
#	include "../entry/input.h"
#endif // USE_ENTRY

#include "vs_ocornut_imgui.bin.h"
#include "fs_ocornut_imgui.bin.h"
#include "vs_imgui_image.bin.h"
#include "fs_imgui_image.bin.h"

static const bgfx::EmbeddedShader s_embeddedShaders[] =
{
	BGFX_EMBEDDED_SHADER(vs_ocornut_imgui),
	BGFX_EMBEDDED_SHADER(fs_ocornut_imgui),
	BGFX_EMBEDDED_SHADER(vs_imgui_image),
	BGFX_EMBEDDED_SHADER(fs_imgui_image),

	BGFX_EMBEDDED_SHADER_END()};

struct OcornutImguiContext
{
	void render(ImDrawData* _drawData)
	{
		if (NULL != _drawData->Textures)
		{
			for (ImTextureData* texData : *_drawData->Textures)
			{
				switch (texData->Status)
				{
				case ImTextureStatus_WantCreate:
					{
						ImGui::TextureBgfx tex =
						{
							.handle = bgfx::createTexture2D(
								  (uint16_t)texData->Width
								, (uint16_t)texData->Height
								, false
								, 1
								, bgfx::TextureFormat::BGRA8
								, 0
								),
							.flags  = IMGUI_FLAGS_ALPHA_BLEND,
							.mip    = 0,
							.unused = 0,
						};

						bgfx::setName(tex.handle, "ImGui Font Atlas");
						bgfx::updateTexture2D(tex.handle, 0, 0, 0, 0
							, bx::narrowCast<uint16_t>(texData->Width)
							, bx::narrowCast<uint16_t>(texData->Height)
							, bgfx::copy(texData->GetPixels(), texData->GetSizeInBytes() )
							);

						texData->SetTexID(bx::bitCast<ImTextureID>(tex) );
						texData->SetStatus(ImTextureStatus_OK);
					}
					break;

				case ImTextureStatus_WantDestroy:
					{
						ImGui::TextureBgfx tex = bx::bitCast<ImGui::TextureBgfx>(texData->GetTexID() );
						bgfx::destroy(tex.handle);
						texData->SetTexID(ImTextureID_Invalid);
						texData->SetStatus(ImTextureStatus_Destroyed);
					}
					break;

				case ImTextureStatus_WantUpdates:
					{
						ImGui::TextureBgfx tex = bx::bitCast<ImGui::TextureBgfx>(texData->GetTexID() );

						for (ImTextureRect& rect : texData->Updates)
						{
							const uint32_t bpp = texData->BytesPerPixel;
							const bgfx::Memory* pix = bgfx::alloc(rect.h * rect.w * bpp);
							bx::gather(pix->data, texData->GetPixelsAt(rect.x, rect.y), texData->GetPitch(), rect.w * bpp, rect.h);
							bgfx::updateTexture2D(tex.handle, 0, 0, rect.x, rect.y, rect.w, rect.h, pix);
						}
					}
					break;

				default:
					break;
				}
			}
		}

		// Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
		int32_t dispWidth  = int32_t(_drawData->DisplaySize.x * _drawData->FramebufferScale.x);
		int32_t dispHeight = int32_t(_drawData->DisplaySize.y * _drawData->FramebufferScale.y);
		if (dispWidth  <= 0
		||  dispHeight <= 0)
		{
			return;
		}

		bgfx::setViewName(m_viewId, "ImGui");
		bgfx::setViewMode(m_viewId, bgfx::ViewMode::Sequential);

		const bgfx::Caps* caps = bgfx::getCaps();
		{
			float ortho[16];
			float x = _drawData->DisplayPos.x;
			float y = _drawData->DisplayPos.y;
			float width = _drawData->DisplaySize.x;
			float height = _drawData->DisplaySize.y;

			bx::mtxOrtho(ortho, x, x + width, y + height, y, 0.0f, 1000.0f, 0.0f, caps->homogeneousDepth);
			bgfx::setViewTransform(m_viewId, NULL, ortho);
			bgfx::setViewRect(m_viewId, 0, 0, uint16_t(width), uint16_t(height) );
		}

		const ImVec2 clipPos   = _drawData->DisplayPos;       // (0,0) unless using multi-viewports
		const ImVec2 clipScale = _drawData->FramebufferScale; // (1,1) unless using retina display which are often (2,2)

		// Render command lists
		for (int32_t ii = 0, num = _drawData->CmdListsCount; ii < num; ++ii)
		{
			bgfx::TransientVertexBuffer tvb;
			bgfx::TransientIndexBuffer tib;

			const ImDrawList* drawList = _drawData->CmdLists[ii];
			uint32_t numVertices = (uint32_t)drawList->VtxBuffer.size();
			uint32_t numIndices  = (uint32_t)drawList->IdxBuffer.size();

			if (!checkAvailTransientBuffers(numVertices, m_layout, numIndices) )
			{
				// not enough space in transient buffer just quit drawing the rest...
				break;
			}

			bgfx::allocTransientVertexBuffer(&tvb, numVertices, m_layout);
			bgfx::allocTransientIndexBuffer(&tib, numIndices, sizeof(ImDrawIdx) == 4);

			ImDrawVert* verts = (ImDrawVert*)tvb.data;
			bx::memCopy(verts, drawList->VtxBuffer.begin(), numVertices * sizeof(ImDrawVert) );

			ImDrawIdx* indices = (ImDrawIdx*)tib.data;
			bx::memCopy(indices, drawList->IdxBuffer.begin(), numIndices * sizeof(ImDrawIdx) );

			bgfx::Encoder* encoder = bgfx::begin();

			for (const ImDrawCmd* cmd = drawList->CmdBuffer.begin(), *cmdEnd = drawList->CmdBuffer.end(); cmd != cmdEnd; ++cmd)
			{
				if (cmd->UserCallback)
				{
					cmd->UserCallback(drawList, cmd);
				}
				else if (0 != cmd->ElemCount)
				{
					uint64_t state = 0
						| BGFX_STATE_WRITE_RGB
						| BGFX_STATE_WRITE_A
						| BGFX_STATE_MSAA
						;

					bgfx::TextureHandle th = BGFX_INVALID_HANDLE;
					bgfx::ProgramHandle program = m_program;

					const ImTextureID texId = cmd->GetTexID();

					if (ImTextureID_Invalid != texId)
					{
						ImGui::TextureBgfx tex = bx::bitCast<ImGui::TextureBgfx>(texId);

						state |= 0 != (IMGUI_FLAGS_ALPHA_BLEND & tex.flags)
							? BGFX_STATE_BLEND_FUNC(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_INV_SRC_ALPHA)
							: BGFX_STATE_NONE
							;
						th = tex.handle;

						if (0 != tex.mip)
						{
							const float lodEnabled[4] = { float(tex.mip), 1.0f, 0.0f, 0.0f };
							bgfx::setUniform(u_imageLodEnabled, lodEnabled);
							program = m_imageProgram;
						}
					}
					else
					{
						state |= BGFX_STATE_BLEND_FUNC(BGFX_STATE_BLEND_SRC_ALPHA, BGFX_STATE_BLEND_INV_SRC_ALPHA);
					}

					// Project scissor/clipping rectangles into framebuffer space
					ImVec4 clipRect;
					clipRect.x = (cmd->ClipRect.x - clipPos.x) * clipScale.x;
					clipRect.y = (cmd->ClipRect.y - clipPos.y) * clipScale.y;
					clipRect.z = (cmd->ClipRect.z - clipPos.x) * clipScale.x;
					clipRect.w = (cmd->ClipRect.w - clipPos.y) * clipScale.y;

					if (clipRect.x <  dispWidth
					&&  clipRect.y <  dispHeight
					&&  clipRect.z >= 0.0f
					&&  clipRect.w >= 0.0f)
					{
						const uint16_t xx = uint16_t(bx::max(clipRect.x, 0.0f) );
						const uint16_t yy = uint16_t(bx::max(clipRect.y, 0.0f) );
						encoder->setScissor(xx, yy
							, uint16_t(bx::min(clipRect.z, 65535.0f)-xx)
							, uint16_t(bx::min(clipRect.w, 65535.0f)-yy)
							);

						encoder->setState(state);
						encoder->setTexture(0, s_tex, th);
						encoder->setVertexBuffer(0, &tvb, cmd->VtxOffset, numVertices);
						encoder->setIndexBuffer(&tib, cmd->IdxOffset, cmd->ElemCount);
						encoder->submit(m_viewId, program);
					}
				}
			}

			bgfx::end(encoder);
		}
	}

	void create(float _fontSize, bx::AllocatorI* _allocator)
	{
		IMGUI_CHECKVERSION();

		m_allocator = _allocator;

		if (NULL == _allocator)
		{
			static bx::DefaultAllocator allocator;
			m_allocator = &allocator;
		}

		m_viewId = 255;

		ImGuiIO &io = ImGui::GetIO();
		io.BackendFlags |= ImGuiBackendFlags_RendererHasVtxOffset;
		io.BackendFlags |= ImGuiBackendFlags_RendererHasTextures;

		bgfx::RendererType::Enum type = bgfx::getRendererType();
		m_program = bgfx::createProgram(
			  bgfx::createEmbeddedShader(s_embeddedShaders, type, "vs_ocornut_imgui")
			, bgfx::createEmbeddedShader(s_embeddedShaders, type, "fs_ocornut_imgui")
			, true
			);

		u_imageLodEnabled = bgfx::createUniform("u_imageLodEnabled", bgfx::UniformType::Vec4);
		m_imageProgram = bgfx::createProgram(
			  bgfx::createEmbeddedShader(s_embeddedShaders, type, "vs_imgui_image")
			, bgfx::createEmbeddedShader(s_embeddedShaders, type, "fs_imgui_image")
			, true
			);

		m_layout
			.begin()
			.add(bgfx::Attrib::Position,  2, bgfx::AttribType::Float)
			.add(bgfx::Attrib::TexCoord0, 2, bgfx::AttribType::Float)
			.add(bgfx::Attrib::Color0,    4, bgfx::AttribType::Uint8, true)
			.end();

		s_tex = bgfx::createUniform("s_tex", bgfx::UniformType::Sampler);
	}

	void destroy()
	{
		bgfx::destroy(s_tex);

		bgfx::destroy(u_imageLodEnabled);
		bgfx::destroy(m_imageProgram);
		bgfx::destroy(m_program);

		for (ImTextureData *tex : ImGui::GetPlatformIO().Textures)
		{
			const bgfx::TextureHandle t = bgfx::TextureHandle{.idx = (uint16_t)tex->GetTexID()};
			bgfx::destroy(t);
		}

		m_allocator = NULL;
	}

	void beginFrame(bgfx::ViewId _viewId)
	{
		m_viewId = _viewId;
		ImGui::NewFrame();
	}

	void endFrame()
	{
		ImGui::Render();
		render(ImGui::GetDrawData() );
	}

	ImGuiContext*       m_imgui;
	bx::AllocatorI*     m_allocator;
	bgfx::VertexLayout  m_layout;
	bgfx::ProgramHandle m_program;
	bgfx::ProgramHandle m_imageProgram;
	bgfx::TextureHandle m_texture;
	bgfx::UniformHandle s_tex;
	bgfx::UniformHandle u_imageLodEnabled;
	bgfx::ViewId m_viewId;
};

static OcornutImguiContext s_ctx;

extern "C"
{
	IMGUI_IMPL_API void ImGui_ImplBgfx_Init()
	{
		s_ctx.create(0, nullptr);
	}

	IMGUI_IMPL_API void ImGui_ImplBgfx_Shutdown()
	{
		s_ctx.destroy();
	}

	IMGUI_IMPL_API void ImGui_ImplBgfx_NewFrame(bgfx::ViewId _viewId)
	{
		s_ctx.beginFrame(_viewId);
	}

	IMGUI_IMPL_API void ImGui_ImplBgfx_RenderDrawData()
	{
		s_ctx.endFrame();
	}
}
