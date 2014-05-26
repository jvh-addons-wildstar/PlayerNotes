require "Window"
 
local PlayerNotes = {}
local clrNeutral = {a=1,r=1,g=1,b=1}
local clrPositive = {a=1,r=0.4,g=1,b=0.4}
local clrNegative = {a=1,r=2,g=0,b=0}


-- Player rating
PlayerNotes.NEUTRAL = "PN:neutral"
PlayerNotes.POSITIVE = "PN:happy"
PlayerNotes.NEGATIVE = "PN:sad"

 
function PlayerNotes:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    self.notes = {}
    self.settings = {}

    return o
end

function PlayerNotes:Init()
    Apollo.RegisterAddon(self, false, "", {"Gemini:Logging-1.2", "ContextMenuPlayer", "GroupDisplay"})
    Apollo.RegisterSlashCommand("playernotes", "OnPlayerNotesOn", self)
end

function PlayerNotes:OnLoad()
    local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
    glog = GeminiLogging:GetLogger({
        level = GeminiLogging.DEBUG,
        pattern = "%d %n %c %l - %m",
        appender = "GeminiConsole"
    })

    self.wndMain = Apollo.LoadForm("PlayerNotes.xml", "PlayerNoteForm", nil, self)
    
    self.contextMenu = Apollo.GetAddon("ContextMenuPlayer")
    self.groupDisplay = Apollo.GetAddon("GroupFrame")
    self.selectionBox = self.wndMain:FindChild("wndSelectionBox")
    self.wndSelected = self.wndMain:FindChild("wndSelected")

    self.wndMain:FindChild("btnNeutral"):SetBGColor(clrNeutral)
    self.wndMain:FindChild("btnPositive"):SetBGColor(clrPositive)
    self.wndMain:FindChild("btnNegative"):SetBGColor(clrNegative)

    self.currentPlayer = ""

    -- Add an extra button to the player context menu
    local oldRedrawAll = self.contextMenu.RedrawAll
    self.contextMenu.RedrawAll = function(context)
        if self.contextMenu.wndMain ~= nil then
            local wndButtonList = self.contextMenu.wndMain:FindChild("ButtonList")
            if wndButtonList ~= nil then
                local wndNew = wndButtonList:FindChildByUserData("BtnPlayerNotes")
                if not wndNew then
                    wndNew = Apollo.LoadForm(self.contextMenu.xmlDoc, "BtnRegular", wndButtonList, self.contextMenu)
                    wndNew:SetData("BtnPlayerNotes")
                end
                wndNew:FindChild("BtnText"):SetText("Player Notes")
            end
        end
        oldRedrawAll(context)
    end

    -- catch the event fired when the player clicks the context menu
    local oldContextClick = self.contextMenu.ProcessContextClick
    self.contextMenu.ProcessContextClick = function(context, eButtonType)
        if eButtonType == "BtnPlayerNotes" then
            self:OpenPlayerNotes(self.contextMenu.strTarget)
        else
            oldContextClick(context, eButtonType)
        end
    end

    -- Color playernote info in group frame
    local oldOnGroupUpdated = self.groupDisplay.OnGroupUpdated
    self.groupDisplay.OnGroupUpdated = function(groupdisplay)
        oldOnGroupUpdated(groupdisplay)
        if self.groupDisplay.nGroupMemberCount ~= nil then
            if self.groupDisplay.nGroupMemberCount > 1 then
                for idx = 1, self.groupDisplay.nGroupMemberCount do
                    local tMemberInfo = GroupLib.GetGroupMember(idx)
                    if tMemberInfo ~= nil then
                        local memberName = tMemberInfo.strCharacterName
                        local note = self.notes[memberName] or {}
                        local color = clrNeutral
                        if note.score == PlayerNotes.POSITIVE then color = clrPositive end
                        if note.score == PlayerNotes.NEGATIVE then color = clrNegative end
                        self.groupDisplay.tGroupWndPortraits[idx].wndHud:FindChild("Class"):SetBGColor(color, true)
                    end
                end
            end
        end
    end
end

function PlayerNotes:OnSave(eLevel)
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Realm then
        return nil
    end
    local mainPosLeft, mainPosTop = self.wndMain:GetPos()
    self.settings.windowPosition = { left = mainPosLeft, top = mainPosTop }
    return { notes = self.notes, settings = self.settings }
end

function PlayerNotes:OnRestore(eLevel, tData)
    self.notes = tData.notes or {}
    self.settings = tData.settings or {}
    if self.settings.windowPosition ~= nil then
        self.wndMain:Move(self.settings.windowPosition.left, self.settings.windowPosition.top, self.wndMain:GetWidth(), self.wndMain:GetHeight())
    end
end

function PlayerNotes:OpenPlayerNotes(strTarget)
    self.currentPlayer = strTarget
    self.wndMain:FindChild("txtPlayerName"):SetText(strTarget)
    if self.notes[self.currentPlayer] ~= nil then
        local note = self.notes[self.currentPlayer]
        self:SetCurrentRating(note.score)
        self.wndMain:FindChild("txtInput"):SetText(note.message)
    else
        self:SetCurrentRating(PlayerNotes.NEUTRAL)
        self.wndMain:FindChild('txtInput'):SetText("")
    end
    self.wndMain:Show(true)
end

function PlayerNotes:SetCurrentRating(rating)
    self.wndSelected:SetSprite(rating)
    if rating == PlayerNotes.NEUTRAL then self.wndSelected:SetBGColor(clrNeutral) end
    if rating == PlayerNotes.POSITIVE then self.wndSelected:SetBGColor(clrPositive) end
    if rating == PlayerNotes.NEGATIVE then self.wndSelected:SetBGColor(clrNegative) end
end


function PlayerNotes:OnPlayerNotesOn(sCommand, sArgs)
    if sArgs ~= nil then
        self:OpenPlayerNotes(sArgs)
    end
end


---------------------------------------------------------------------------------------------------
-- PlayerNoteForm Functions
---------------------------------------------------------------------------------------------------

function PlayerNotes:ChangePlayerRating( wndHandler, wndControl, eMouseButton )
    if not self.selectionBox:IsVisible() then
        self.selectionBox:Show(true)
        self.wndSelected:Show(false)
    else
        local sender = wndHandler:GetName()
        if sender == "btnNeutral" then
            self:SetCurrentRating(PlayerNotes.NEUTRAL)
        end
        if sender == "btnPositive" then
            self:SetCurrentRating(PlayerNotes.POSITIVE)
        end
        if sender == "btnNegative" then
            self:SetCurrentRating(PlayerNotes.NEGATIVE)
        end

        self.wndSelected:Show(true)
        self.selectionBox:Show(false)
    end
end

function PlayerNotes:SaveCurrentNote( wndHandler, wndControl, eMouseButton )
    local note = {}
    local currentScore = self.wndSelected:GetSprite()
    if currentScore == "happy" then note.score = PlayerNotes.POSITIVE end
    if currentScore == "neutral" then note.score = PlayerNotes.NEUTRAL end
    if currentScore == "sad" then note.score = PlayerNotes.NEGATIVE end
    note.message = self.wndMain:FindChild("txtInput"):GetText()
    self.notes[self.currentPlayer] = note

    self.wndMain:Show(false)
end

function PlayerNotes:OnWindowCancel( wndHandler, wndControl, eMouseButton )
	self.wndMain:Show(false)
end

local PlayerNotesInst = PlayerNotes:new()
PlayerNotesInst:Init()