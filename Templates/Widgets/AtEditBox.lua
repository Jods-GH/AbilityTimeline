local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- AceGUI's EditBox and MultiLineEditBox in the theme: rounded fields whose edge lights up while focused

---gives an edit box's field its hover and focus states
---@param editbox EditBox
---@param field table
local hookField = function(editbox, field)
    ThemedWidgets.HookHover(editbox, field, function()
        ThemedWidgets.DrawField(field)
    end)
    editbox:HookScript("OnEditFocusGained", function()
        private.TweenMotion(field, "Hover", field.focus or 0, 1, function(progress)
            field.focus = progress
            ThemedWidgets.DrawField(field)
        end)
    end)
    editbox:HookScript("OnEditFocusLost", function()
        private.TweenMotion(field, "Hover", field.focus or 1, 0, function(progress)
            field.focus = progress
            ThemedWidgets.DrawField(field)
        end)
    end)
end

---@param self AtEditBox
local function ApplyEditSettings(self)
    ThemeApply.FontRole(self.label, "Label")
    self.editbox:SetFontObject(ThemeApply.FontObject("Control"))
    self.editbox:SetTextColor(ThemeApply.FontObject("Control"):GetTextColor())
    ThemedWidgets.DrawField(self.editbox.AtField)
    ThemedWidgets.DrawButton(self.button)
    self.frame:SetAlpha(self.disabled and 0.5 or 1)
end

---@param widget AtEditBox
local function SkinEdit(widget)
    local editbox = widget.editbox
    ThemedWidgets.DiscardTextures(editbox)
    editbox:SetTextInsets(6, 6, 3, 3)
    editbox:SetJustifyH("CENTER")
    editbox.AtField = ThemedWidgets.CreateField(editbox, editbox, 6, 0, 0, 0)
    hookField(editbox, editbox.AtField)
    ThemedWidgets.SkinButton(widget.button)
end

ThemedWidgets.Register("AtEditBox", "EditBox", 1, SkinEdit, ApplyEditSettings, { "OnAcquire", "SetDisabled" })

---@param self AtMultiLineEditBox
local function ApplyMultiLineSettings(self)
    ThemeApply.FontRole(self.label, "Label")
    self.editBox:SetFontObject(ThemeApply.FontObject("Control"))
    self.editBox:SetTextColor(ThemeApply.FontObject("Control"):GetTextColor())
    ThemedWidgets.DrawField(self.scrollBG.AtField)
    ThemedWidgets.DrawButton(self.button)
    self.scrollBar.AtDraw()
    self.frame:SetAlpha(self.disabled and 0.5 or 1)
end

---@param widget AtMultiLineEditBox
local function SkinMultiLine(widget)
    widget.scrollBG:SetBackdrop(nil)
    ThemedWidgets.DiscardTextures(widget.scrollBG)
    widget.scrollBG.AtField = ThemedWidgets.CreateField(widget.scrollBG, widget.scrollBG, 0, 0, 0, 0)
    hookField(widget.editBox, widget.scrollBG.AtField)
    ThemedWidgets.SkinButton(widget.button)
    ThemedWidgets.SkinScrollBar(widget.scrollBar)
end

ThemedWidgets.Register("AtMultiLineEditBox", "MultiLineEditBox", 1, SkinMultiLine, ApplyMultiLineSettings,
    { "OnAcquire", "SetDisabled" })
