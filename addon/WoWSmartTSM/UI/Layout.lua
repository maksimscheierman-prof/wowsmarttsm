local Smart = WoWSmartTSM
local Theme = Smart:Module("Theme")
local Layout = Smart:Module("Layout")

--[[
  Robust tab content layout:
  - Replace entire content root each render (no orphaned FontStrings)
  - Vertical stack with measured heights / wrapping
  - Header / body / footer regions
]]

local PADDING = 14
local GAP = 8

function Layout.ClearHost(host)
	if host._smartRoot then
		host._smartRoot:Hide()
		host._smartRoot:SetParent(nil)
		host._smartRoot = nil
	end
	-- Also hide leftover children/regions from older buggy renders
	local children = { host:GetChildren() }
	for _, child in ipairs(children) do
		child:Hide()
		child:SetParent(nil)
	end
	local regions = { host:GetRegions() }
	for _, region in ipairs(regions) do
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			region:SetText("")
			region:Hide()
		end
	end
end

---Create a fresh root with header/body/footer for a tab render.
function Layout.Begin(host)
	Layout.ClearHost(host)
	local root = CreateFrame("Frame", nil, host)
	root:SetAllPoints(host)
	host._smartRoot = root

	local header = CreateFrame("Frame", nil, root)
	header:SetPoint("TOPLEFT", PADDING, -PADDING)
	header:SetPoint("TOPRIGHT", -PADDING, -PADDING)
	header:SetHeight(36)

	local footer = CreateFrame("Frame", nil, root)
	footer:SetPoint("BOTTOMLEFT", PADDING, PADDING)
	footer:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
	footer:SetHeight(28)

	local body = CreateFrame("Frame", nil, root)
	body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -GAP)
	body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, GAP)

	root.header = header
	root.body = body
	root.footer = footer
	root._stackY = 0
	return root
end

function Layout.HeaderTitle(header, text)
	local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	fs:SetPoint("TOPLEFT", 0, 0)
	fs:SetPoint("RIGHT", header, "RIGHT", -160, 0)
	fs:SetJustifyH("LEFT")
	fs:SetText(text or "")
	fs:SetTextColor(Theme.COLORS.text[1], Theme.COLORS.text[2], Theme.COLORS.text[3], 1)
	return fs
end

function Layout.HeaderButton(header, text, onClick)
	local btn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
	btn:SetSize(150, 24)
	btn:SetPoint("TOPRIGHT", 0, 0)
	btn:SetText(text or "")
	if onClick then
		btn:SetScript("OnClick", onClick)
	end
	return btn
end

function Layout.FooterText(footer, text)
	local fs = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", 0, 0)
	fs:SetPoint("RIGHT", 0, 0)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	fs:SetText(text or "")
	fs:SetTextColor(Theme.COLORS.muted[1], Theme.COLORS.muted[2], Theme.COLORS.muted[3], 1)
	return fs
end

---Vertical stack helper on a parent frame.
function Layout.Stack(parent)
	return {
		parent = parent,
		y = 0,
		width = math.max(100, (parent:GetWidth() or 400) - 4),
	}
end

function Layout.StackEnsureWidth(stack)
	local w = stack.parent:GetWidth() or 0
	if w > 20 then
		stack.width = w - 4
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
	stack.y = stack.y + h + 4
	return fs, h
end

function Layout.AddGap(stack, px)
	stack.y = stack.y + (px or GAP)
end

function Layout.AddButtonRow(stack, buttons)
	Layout.StackEnsureWidth(stack)
	local row = CreateFrame("Frame", nil, stack.parent)
	row:SetPoint("TOPLEFT", stack.parent, "TOPLEFT", 0, -stack.y)
	row:SetSize(stack.width, 26)
	local x = 0
	for _, spec in ipairs(buttons or {}) do
		local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		btn:SetSize(spec.width or 120, 24)
		btn:SetPoint("LEFT", row, "LEFT", x, 0)
		btn:SetText(spec.text or "")
		if spec.onClick then
			btn:SetScript("OnClick", spec.onClick)
		end
		x = x + (spec.width or 120) + 6
	end
	stack.y = stack.y + 30
	return row
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

---Simple table: header + rows inside an optional scroll child.
function Layout.AddTable(stack, columns, rows, opts)
	opts = opts or {}
	Layout.StackEnsureWidth(stack)
	local rowH = opts.rowHeight or 22
	local headerH = 22
	local maxBody = opts.maxHeight or 280
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

	local bodyH = math.min(maxBody, math.max(rowH, #rows * rowH))
	local scroll = CreateFrame("ScrollFrame", nil, wrap, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -headerH - 2)
	scroll:SetSize(tableWidth - 22, bodyH)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(tableWidth - 24, math.max(bodyH, #rows * rowH))
	scroll:SetScrollChild(child)

	for i, row in ipairs(rows) do
		local line = CreateFrame("Frame", nil, child)
		line:SetSize(tableWidth - 24, rowH)
		line:SetPoint("TOPLEFT", 0, -((i - 1) * rowH))
		local cx = 0
		for ci, col in ipairs(columns) do
			local fs = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			fs:SetPoint("LEFT", line, "LEFT", cx + 2, 0)
			fs:SetWidth((col.width or 80) - 4)
			fs:SetJustifyH(col.align or "LEFT")
			fs:SetWordWrap(false)
			local val = row[ci]
			if type(val) == "table" then
				fs:SetText(tostring(val.text or ""))
				if val.color then
					fs:SetTextColor(val.color[1], val.color[2], val.color[3], 1)
				end
			else
				fs:SetText(tostring(val or ""))
			end
			cx = cx + (col.width or 80)
		end
		local needMouse = opts.onEnter or opts.onLeave or opts.onClick
		if needMouse then
			line:EnableMouse(true)
			if opts.onEnter then
				line:SetScript("OnEnter", function()
					opts.onEnter(row, i, line)
				end)
			end
			if opts.onLeave then
				line:SetScript("OnLeave", function()
					opts.onLeave(row, i, line)
				end)
			end
			if opts.onClick then
				line:SetScript("OnMouseUp", function(_, button)
					if button == "LeftButton" then
						opts.onClick(row, i, line)
					end
				end)
			end
		end
	end

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

function Layout.BodyStack(root)
	-- Body may need internal scroll for long content
	local body = root.body
	local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -4)
	scroll:SetPoint("BOTTOMRIGHT", -26, 4)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(math.max(100, (body:GetWidth() or 400) - 30), 10)
	scroll:SetScrollChild(child)
	root._bodyScroll = scroll
	root._bodyChild = child
	local stack = Layout.Stack(child)
	-- Width after layout
	child:SetScript("OnSizeChanged", function(self, w)
		if w and w > 40 then
			stack.width = w - 4
		end
	end)
	return stack
end
