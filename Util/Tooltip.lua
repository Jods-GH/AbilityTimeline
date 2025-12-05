local _, private       = ...


private.AddFrameTooltip = function(frame, localisationKey)
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(frame, "ANCHOR_TOPRIGHT")
        GameTooltip:AddLine(private.getLocalisation(localisationKey))
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end