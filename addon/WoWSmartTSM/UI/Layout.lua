local Smart = WoWSmartTSM
local Theme = Smart:Module("Theme")
local Layout = Smart:Module("Layout")

--[[
  Robust tab content layout (v0.2.2):
  - Replace managed _smartRoot each render
  - Never mass-unparent host children (BackdropTemplate NineSlice must stay)
  - Explicit size fallbacks when host reports 0x0 while hidden
  - Header / body / footer regions with measured stacks
  - Existence checks use '.' not ':' (':' is call-only in Lua)
]]

local PADDING = 14
local GAP = 8

local discardHost

local function getDiscardHost()
	if discardHost then
		return discardHost
	end
	if not UIParent then
		return nil
	end
	discardHost = CreateFrame("Frame", "WoWSmartTSMLayoutDiscard", UIParent)
	discardHost:Hide()
	discardHost:SetSize(1, 1)
	discardHost:SetAlpha(0)
	return discardHost
end

---Resolve usable width/height even when the host has not laid out yet.
function Layout.ResolveHostSize(host)
	local w = (host and host.GetWidth and host:GetWidth()) or 0
	local h = (host and host.GetHeight and host:GetHeight()) or 0
	if (w < 20 or h < 20) and host and host.GetParent then
		local p = host:GetParent()
		local depth = 0
		while p and depth < 6 do
			local pw = (p.GetWidth and p:GetWidth()) or 0
			local ph = (p.GetHeight and p:GetHeight()) or 0
			if pw > 40 and ph > 40 then
				if w < 20 then
					w = math.max(120, pw - 24)
				end
				if h < 20 then
					h = math.max(120, ph - 120)
				end
				break
			end
			p = p.GetParent and p:GetParent() or nil
			depth = depth + 1
		end
	end
	if w < 20 then
		w = 900
	end
	if h < 20 then
		h = 520
	end
	return w, h
end

function Layout.ClearHost(host)
	if not host then
		return
	end
	local old = host._smartRoot
	host._smartRoot = nil
	if not old then
		return
	end
	old:Hide()
	old:SetAlpha(0)
	if old.ClearAllPoints then
		old:ClearAllPoints()
	end
	local discard = getDiscardHost()
	if discard and old.SetParent then
		-- Never SetParent(nil): Forever/Backdrop hosts can break; keep discard bin.
		pcall(old.SetParent, old, discard)
	end
end

---Create a fresh root with header/body/footer for a tab render.
function Layout.Begin(host)
	Layout.ClearHost(host)
	local w, h = Layout.ResolveHostSize(host)
	local root = CreateFrame("Frame", nil, host)
	root:SetSize(w, h)
	root:SetAllPoints(host)
	local hostLevel = (host.GetFrameLevel and host:GetFrameLevel()) or 0
	root:SetFrameLevel(hostLevel + 20)
	root:SetAlpha(1)
	root:Show()
	root._smartManaged = true
	host._smartRoot = root

	local header = CreateFrame("Frame", nil, root)
	header:SetPoint("TOPLEFT", PADDING, -PADDING)
	header:SetPoint("TOPRIGHT", -PADDING, -PADDING)
	header:SetHeight(36)
	header:Show()

	local footer = CreateFrame("Frame", nil, root)
	footer:SetPoint("BOTTOMLEFT", PADDING, PADDING)
	footer:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
	footer:SetHeight(28)
	footer:Show()

	local body = CreateFrame("Frame", nil, root)
	body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -GAP)
	body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, GAP)
	body:Show()

	root.header = header
	root.body = body
	root.footer = footer
	root._stackY = 0
	root._hostWidth = w
	root._hostHeight = h
	return root
end

---True if the managed root has at least one visible text/button child.
function Layout.HasVisibleContent(host)
	local root = host and host._smartRoot
	if not root or (root.IsShown and not root:IsShown()) then
		return false
	end
	local function scan(frame, depth)
		if not frame or depth > 8 then
			return false
		end
		if frame.GetRegions then
			local regions = { frame:GetRegions() }
			for _, region in ipairs(regions) do
				if region.GetObjectType and region:GetObjectType() == "FontString" then
					local text = region.GetText and region:GetText() or ""
					if text and text ~= "" and (not region.IsShown or region:IsShown()) then
						return true
					end
				end
			end
		end
		if frame.GetChildren then
			local children = { frame:GetChildren() }
			for _, child in ipairs(children) do
				if child.IsObjectType and child:IsObjectType("Button") then
					if not child.IsShown or child:IsShown() then
						return true
					end
				end
				if scan(child, depth + 1) then
					return true
				end
			end
		end
		return false
	end
	return scan(root, 0)
end

function Layout.HeaderTitle(header, text, rightReserve)
	local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	fs:SetPoint("TOPLEFT", 0, 0)
	fs:SetPoint("RIGHT", header, "RIGHT", -(rightReserve or 200), 0)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	fs:SetText(text or "")
	fs:SetTextColor(Theme.COLORS.text[1], Theme.COLORS.text[2], Theme.COLORS.text[3], 1)
	fs:Show()
	return fs
end

---Header action button sized to fit its label. Returns button, width.
function Layout.HeaderButton(header, text, onClick)
	local label = text or ""
	local w = Layout.MeasureButtonWidth(label, 140, 300)
	local btn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
	btn:SetSize(w, 24)
	btn:SetPoint("TOPRIGHT", 0, 0)
	btn:SetText(label)
	if onClick then
		btn:SetScript("OnClick", onClick)
	end
	btn:Show()
	return btn, w
end

function Layout.FooterText(footer, text)
	local fs = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", 0, 0)
	fs:SetPoint("RIGHT", 0, 0)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	fs:SetText(text or "")
	fs:SetTextColor(Theme.COLORS.muted[1], Theme.COLORS.muted[2], Theme.COLORS.muted[3], 1)
	fs:Show()
	return fs
end

---Vertical stack helper on a parent frame.
function Layout.Stack(parent)
	local pw = (parent and parent.GetWidth and parent:GetWidth()) or 0
	if pw < 20 then
		pw = 400
	end
	return {
		parent = parent,
		y = 0,
		width = math.max(100, pw - 4),
	}
end

function Layout.StackEnsureWidth(stack)
	local w = stack.parent:GetWidth() or 0
	if w > 20 then
		stack.width = w - 4
	elseif stack.width < 100 then
		stack.width = 400
	end
	return stack.width
end

function Layout.AddText(stack, text, template, color)
	Layout.StackEnsureWidth(stack)
	local fs = stack.parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
	fs:SetPoint("TOPLEFT", stack.parent, "TOPLEFT", 0, -stack.y)
	fs:SetWidth(stack.width)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetWordWrap(true)
	fs:SetNonSpaceWrap(true)
	fs:SetText(text or "")
	local c = color or Theme.COLORS.text
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	local h = math.max(14, fs:GetStringHeight() or 14)
	fs:SetHeight(h)
	fs:Show()
	stack.y = stack.y + h + 4
	return fs, h
end

function Layout.AddGap(stack, px)
	stack.y = stack.y + (px or GAP)
end

local BTN_PAD_X = 24
local BTN_GAP = 8
local BTN_HEIGHT = 24
local BTN_MIN_W = 72
local BTN_MAX_W = 220

---Measure preferred button width from label text.
function Layout.MeasureButtonWidth(text, minW, maxW)
	minW = minW or BTN_MIN_W
	maxW = maxW or BTN_MAX_W
	local w = minW
	if UIParent and UIParent.CreateFontString then
		local probe = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		probe:SetText(text or "")
		w = math.ceil((probe:GetStringWidth() or 0) + BTN_PAD_X)
		probe:SetText("")
		probe:Hide()
	else
		-- Offline / no UIParent: approximate 7px per char + padding
		w = math.ceil(#(text or "") * 7 + BTN_PAD_X)
	end
	if w < minW then
		w = minW
	end
	if w > maxW then
		w = maxW
	end
	return w
end

local function shortenLabel(text, maxW)
	local full = text or ""
	local w = Layout.MeasureButtonWidth(full, BTN_MIN_W, 1000)
	if w <= maxW then
		return full, false
	end
	local s = full
	while #s > 3 do
		s = s:sub(1, #s - 1)
		local candidate = s .. "…"
		if Layout.MeasureButtonWidth(candidate, BTN_MIN_W, 1000) <= maxW then
			return candidate, true
		end
	end
	return "…", true
end

function Layout.AddButtonRow(stack, buttons)
	Layout.StackEnsureWidth(stack)
	local wrap = CreateFrame("Frame", nil, stack.parent)
	wrap:SetPoint("TOPLEFT", stack.parent, "TOPLEFT", 0, -stack.y)
	wrap:SetWidth(stack.width)

	local rowY = 0
	local x = 0
	local currentRow = CreateFrame("Frame", nil, wrap)
	currentRow:SetPoint("TOPLEFT", 0, 0)
	currentRow:SetSize(stack.width, BTN_HEIGHT)

	for _, spec in ipairs(buttons or {}) do
		local fullText = spec.text or ""
		local tip = spec.tooltip or fullText
		local minW = spec.minWidth or BTN_MIN_W
		local maxW = spec.maxWidth or BTN_MAX_W
		local avail = stack.width - x
		local natural = Layout.MeasureButtonWidth(fullText, minW, maxW)
		if x > 0 and (natural + BTN_GAP) > avail and avail < (minW + BTN_GAP) then
			rowY = rowY + BTN_HEIGHT + 6
			x = 0
			avail = stack.width
			currentRow = CreateFrame("Frame", nil, wrap)
			currentRow:SetPoint("TOPLEFT", 0, -rowY)
			currentRow:SetSize(stack.width, BTN_HEIGHT)
		end
		local useW = natural
		if useW > avail and avail >= minW then
			useW = avail
		elseif useW > stack.width then
			useW = stack.width
		end
		local label, truncated = shortenLabel(fullText, useW)
		local btn = CreateFrame("Button", nil, currentRow, "UIPanelButtonTemplate")
		btn:SetSize(useW, BTN_HEIGHT)
		btn:SetPoint("TOPLEFT", currentRow, "TOPLEFT", x, 0)
		btn:SetText(label)
		if truncated or (tip and tip ~= label) then
			btn:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:SetText(tip, 1, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			btn:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		end
		if spec.onClick then
			btn:SetScript("OnClick", spec.onClick)
		end
		x = x + useW + BTN_GAP
	end

	local totalH = rowY + BTN_HEIGHT
	wrap:SetHeight(totalH)
	stack.y = stack.y + totalH + 6
	return wrap
end

function Layout.AddMetricGrid(stack, metrics, cols)
	cols = cols or 4
	Layout.StackEnsureWidth(stack)
	local cardW = math.floor((stack.width - (cols - 1) * 8) / cols)
	local cardH = 58
	local rows = math.ceil(#metrics / cols)
	local grid = CreateFrame("Frame", nil, stack.parent)
	grid:SetPoint("TOPLEFT", stack.parent, "TOPLEFT", 0, -stack.y)
	grid:SetSize(stack.width, rows * (cardH + 8))

	for i, m in ipairs(metrics) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local card = CreateFrame("Frame", nil, grid, BackdropTemplateMixin and "BackdropTemplate" or nil)
		card:SetSize(cardW, cardH)
		card:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (cardW + 8), -row * (cardH + 8))
		if card.SetBackdrop then
			card:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				edgeSize = 10,
				insets = { left = 2, right = 2, top = 2, bottom = 2 },
			})
			local p = Theme.COLORS.panel
			card:SetBackdropColor(p[1], p[2], p[3], 0.9)
			card:SetBackdropBorderColor(0.25, 0.35, 0.38, 1)
		end
		local k = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		k:SetPoint("TOPLEFT", 8, -8)
		k:SetPoint("TOPRIGHT", -8, -8)
		k:SetJustifyH("LEFT")
		k:SetText(m[1] or "")
		k:SetTextColor(Theme.COLORS.muted[1], Theme.COLORS.muted[2], Theme.COLORS.muted[3], 1)
		local v = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		v:SetPoint("BOTTOMLEFT", 8, 10)
		v:SetPoint("BOTTOMRIGHT", -8, 10)
		v:SetJustifyH("LEFT")
		v:SetText(tostring(m[2] or ""))
		local colr = m[3] or Theme.COLORS.text
		v:SetTextColor(colr[1], colr[2], colr[3], 1)
	end
	stack.y = stack.y + rows * (cardH + 8) + 4
	return grid
end

local function truncateTextToWidth(fs, fullText, maxWidth)
	local text = tostring(fullText or "")
	fs:SetText(text)
	-- Use '.' for existence check; ':' is only valid as a call in Lua.
	local sw = (fs.GetStringWidth and fs:GetStringWidth()) or (#text * 7)
	if not maxWidth or maxWidth <= 8 or sw <= maxWidth then
		return text, false
	end
	local ell = "…"
	local lo, hi = 1, #text
	local best = ell
	while lo <= hi do
		local mid = math.floor((lo + hi) / 2)
		local candidate = text:sub(1, mid) .. ell
		fs:SetText(candidate)
		local cw = (fs.GetStringWidth and fs:GetStringWidth()) or (#candidate * 7)
		if cw <= maxWidth then
			best = candidate
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
	fs:SetText(best)
	return best, true
end

---Table without nested ScrollFrame — body scroll (BodyStack) handles overflow.
---Avoids duplicate scroll buttons when tables sit inside a scrolling body.
function Layout.AddTable(stack, columns, rows, opts)
	opts = opts or {}
	Layout.StackEnsureWidth(stack)
	local rowH = opts.rowHeight or 22
	local headerH = 22
	local tableWidth = stack.width

	local wrap = CreateFrame("Frame", nil, stack.parent)
	wrap:SetPoint("TOPLEFT", stack.parent, "TOPLEFT", 0, -stack.y)
	wrap:SetWidth(tableWidth)

	local header = CreateFrame("Frame", nil, wrap)
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetSize(tableWidth, headerH)
	local x = 0
	for _, col in ipairs(columns) do
		local fs = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("LEFT", header, "LEFT", x + 2, 0)
		fs:SetWidth((col.width or 80) - 4)
		fs:SetJustifyH(col.align or "LEFT")
		fs:SetText(col.title or "")
		fs:SetTextColor(Theme.COLORS.muted[1], Theme.COLORS.muted[2], Theme.COLORS.muted[3], 1)
		x = x + (col.width or 80)
	end

	local body = CreateFrame("Frame", nil, wrap)
	body:SetPoint("TOPLEFT", 0, -headerH - 2)
	body:SetSize(tableWidth, math.max(rowH, #rows * rowH))

	for i, row in ipairs(rows) do
		local line = CreateFrame("Frame", nil, body)
		line:SetSize(tableWidth, rowH)
		line:SetPoint("TOPLEFT", 0, -((i - 1) * rowH))
		local cx = 0
		local cellTips = {}
		for ci, col in ipairs(columns) do
			local fs = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			local colW = (col.width or 80) - 4
			fs:SetPoint("LEFT", line, "LEFT", cx + 2, 0)
			fs:SetWidth(colW)
			fs:SetJustifyH(col.align or "LEFT")
			fs:SetWordWrap(false)
			local val = row[ci]
			local fullText
			if type(val) == "table" then
				fullText = tostring(val.fullText or val.text or "")
				local shown, truncated = truncateTextToWidth(fs, fullText, colW)
				if val.color then
					fs:SetTextColor(val.color[1], val.color[2], val.color[3], 1)
				end
				if truncated or val.tooltip then
					cellTips[#cellTips + 1] = val.tooltip or fullText
				end
			else
				fullText = tostring(val or "")
				local _, truncated = truncateTextToWidth(fs, fullText, colW)
				if truncated then
					cellTips[#cellTips + 1] = fullText
				end
			end
			cx = cx + (col.width or 80)
		end
		local needMouse = opts.onEnter or opts.onLeave or opts.onClick or opts.onRightClick or #cellTips > 0
		if needMouse then
			line:EnableMouse(true)
			if opts.isSelected and opts.isSelected(row) then
				local hl = line:CreateTexture(nil, "BACKGROUND")
				hl:SetAllPoints(line)
				hl:SetTexture("Interface\\Buttons\\WHITE8X8")
				hl:SetVertexColor(0.2, 0.35, 0.4, 0.5)
			end
			line:SetScript("OnEnter", function()
				if opts.onEnter then
					opts.onEnter(row, i, line)
				elseif #cellTips > 0 then
					GameTooltip:SetOwner(line, "ANCHOR_CURSOR")
					for _, tip in ipairs(cellTips) do
						GameTooltip:AddLine(tip, 1, 1, 1, true)
					end
					GameTooltip:Show()
				end
			end)
			line:SetScript("OnLeave", function()
				if opts.onLeave then
					opts.onLeave(row, i, line)
				else
					GameTooltip:Hide()
				end
			end)
			if opts.onClick or opts.onRightClick then
				line:SetScript("OnMouseUp", function(_, button)
					if button == "LeftButton" and opts.onClick then
						opts.onClick(row, i, line, IsShiftKeyDown and IsShiftKeyDown(), IsControlKeyDown and IsControlKeyDown())
					elseif button == "RightButton" and opts.onRightClick then
						opts.onRightClick(row, i, line)
					end
				end)
			end
		end
	end

	local bodyH = math.max(rowH, #rows * rowH)
	local totalH = headerH + 2 + bodyH + 4
	wrap:SetHeight(totalH)
	stack.y = stack.y + totalH + 4
	return wrap
end

function Layout.FinishStack(stack)
	-- Expand parent height if it's a scroll child
	if stack.parent.SetHeight then
		stack.parent:SetHeight(math.max(10, stack.y))
	end
	return stack.y
end

---Body content stack. Single ScrollFrame only (no nested table scrollbars).
function Layout.BodyStack(root, opts)
	opts = opts or {}
	local body = root.body
	local bodyW = (body.GetWidth and body:GetWidth()) or 0
	if bodyW < 20 then
		bodyW = math.max(100, (root._hostWidth or 900) - (PADDING * 2))
	end
	local child
	if opts.scroll == false then
		child = CreateFrame("Frame", nil, body)
		child:SetPoint("TOPLEFT", 4, -4)
		child:SetPoint("BOTTOMRIGHT", -4, 4)
		child:Show()
		root._bodyScroll = nil
		root._bodyChild = child
	else
		local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 4, -4)
		scroll:SetPoint("BOTTOMRIGHT", -26, 4)
		scroll:Show()
		child = CreateFrame("Frame", nil, scroll)
		child:SetSize(math.max(100, bodyW - 30), 10)
		scroll:SetScrollChild(child)
		child:Show()
		root._bodyScroll = scroll
		root._bodyChild = child
	end
	local stack = Layout.Stack(child)
	stack.width = math.max(100, bodyW - 30)
	child:SetScript("OnSizeChanged", function(self, w)
		if w and w > 40 then
			stack.width = w - 4
		end
	end)
	return stack
end
