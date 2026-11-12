local Smart = WoWSmartTSM
local Theme = Smart:Module("Theme")
local Widgets = Smart:Module("Widgets")

function Widgets.AddBackdrop(frame, bg)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	local c = bg or Theme.COLORS.panel
	frame:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
	frame:SetBackdropBorderColor(0.25, 0.35, 0.38, 1)
end

function Widgets.Button(parent, text, width, height, onClick)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width or 120, height or 24)
	btn:SetText(text or "")
	if onClick then
		btn:SetScript("OnClick", onClick)
	end
	return btn
end

function Widgets.Label(parent, text, size)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	if size then
		fs:SetFont(fs:GetFont(), size)
	end
	fs:SetText(text or "")
	fs:SetTextColor(Theme.COLORS.text[1], Theme.COLORS.text[2], Theme.COLORS.text[3], 1)
	return fs
end

function Widgets.ScrollList(parent, name)
	local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	scroll.child = child
	scroll.rows = {}
	return scroll
end
