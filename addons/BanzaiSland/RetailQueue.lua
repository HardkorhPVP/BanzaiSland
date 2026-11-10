-- Mirror Dungeon Finder proposals through the existing secure game-button overlays.
local ADDON,ns=...
if ns.Blocked then return end -- BanzaiSland: the original Island is enabled (Guard.lua)
if not ns.ClientFeature("retail") then return end
local R,I,L,C=ns.Retail,ns.Island,ns.L,ns.C
local Call,Read=R.Call,R.Read
local Q={}
R.QueuePrompt=Q
local ID="retailDungeonProposal"
local GREEN={.36,.85,.45}
local function Combat() return InCombatLockdown and InCombatLockdown() end
local function Proposal()
    local exists,id,_,_,name,_,role,responded,_,_,_,_,_,_,silent=Call(GetLFGProposal)
    if exists~=true or not Read(id,"number") or responded==true or silent==true then return end
    return id,Read(name,"string") and name or L["Dungeon Finder is ready"],Read(role,"string") and role or nil
end
local function Restore(state)
    if state and state.frame and ns.PopupCard then ns.PopupCard.Restore(state.frame) end
end
function Q.Close()
    local state=Q.active
    Q.active=nil
    Restore(state)
    if I.RemoveRoll then I:RemoveRoll(ID,true) end
end
local function Targets(state)
    if Q.active~=state or Proposal()~=state.id then return end
    local popup=_G.LFGDungeonReadyPopup
    local dialog=_G.LFGDungeonReadyDialog
    if not popup or popup==UIParent or not dialog or Call(popup.IsShown,popup)~=true
        or Call(dialog.IsShown,dialog)~=true then return end
    local enter=dialog.enterButton or _G.LFGDungeonReadyDialogEnterDungeonButton
    local leave=dialog.leaveButton or _G.LFGDungeonReadyDialogLeaveQueueButton
    if not enter or not leave or Call(enter.IsEnabled,enter)~=true or Call(leave.IsEnabled,leave)~=true then return end
    return popup,enter,leave
end
local function RoleLine(role)
    local roles={TANK=L["Tank"],HEALER=L["Healer"],DAMAGER=L["Damage"]}
    return roles[role] and L["Your role: %s"]:format(roles[role]) or L["Your queue popped"]
end
local function ReadyLine(count)
    if not Read(count,"number") or count<1 or count>40 then return L["Waiting for group responses"] end
    local ready,waiting,declined,readable=0,0,0,0
    local roles={TANK={0,0},HEALER={0,0},DAMAGER={0,0}}
    for index=1,count do
        local _,role,_,answered,accepted=Call(GetLFGProposalMember,index)
        if Read(answered,"boolean") then
            readable=readable+1
            local yes=answered and accepted==true
            if yes then ready=ready+1 elseif answered and accepted==false then declined=declined+1 else waiting=waiting+1 end
            if Read(role,"string") and roles[role] then
                local totals=roles[role];totals[2]=totals[2]+1;if yes then totals[1]=totals[1]+1 end
            end
        end
    end
    if readable==0 then return L["Waiting for group responses"] end
    waiting=math.max(waiting,count-ready-declined)
    local line=L["%d ready · %d waiting"]:format(ready,waiting)
    if declined>0 then line=L["%s · %d declined"]:format(line,declined) end
    if roles.TANK[2]+roles.HEALER[2]+roles.DAMAGER[2]>0 then
        line=line.."\n"..L["Tank %d/%d · Healer %d/%d · Damage %d/%d"]:format(
            roles.TANK[1],roles.TANK[2],roles.HEALER[1],roles.HEALER[2],roles.DAMAGER[1],roles.DAMAGER[2])
    end
    return line
end
function Q.Wait(state,count)
    local line=ReadyLine(count)
    if not state.waiting then
        state.waiting=true;state.readyLine=line
        if I.DisarmSecure then I:DisarmSecure() end
        I:AddPrompt({id=ID,front=true,builderType="prompts",glyph="Check",tone=GREEN,cap=L["GROUP READY CHECK"],
            name=state.name,line=line,noTimer=true,buttons={},onRemoved=function()
                Restore(state);if Q.active==state then Q.active=nil end
            end})
    elseif state.readyLine~=line then state.readyLine=line;I:UpdatePrompt(ID,line) end
    local popup=_G.LFGDungeonReadyPopup
    if popup and popup~=UIParent then state.frame=popup end
    local top=I.rolls and I.rolls[1]
    if not Combat() and top and top.id==ID and I.state=="roll" and state.frame
        and Call(state.frame.IsShown,state.frame)==true and ns.PopupCard then ns.PopupCard.Hide(state.frame)
    else Restore(state) end
end

function Q.Show()
    if not ns.db or ns.db.retailQueues==false or not I.built then Q.Close() return end
    local exists,currentID=Call(GetLFGProposal)
    if Q.active and exists==true and currentID==Q.active.id then Q.Tick() return end
    local id,name,role=Proposal()
    if not id then Q.Close() return end
    if Q.active and Q.active.id==id then Q.Tick() return end
    Q.Close()
    local state={id=id,name=name}
    Q.active=state
    local enter,leave
    -- An unarmed ordinary click only returns the native dialog; it never accepts or rejects.
    enter={label=L["Enter"],done=L["Entering"],keep=true,
        secure=function() local _,button=Targets(state) return button end,
        fn=function() if not enter.armed then Restore(state) end end}
    leave={label=L["Leave queue"],done=L["Left queue"],muted=true,keep=true,
        secure=function() local _,_,button=Targets(state) return button end,
        fn=function() if not leave.armed then Restore(state) end end}
    state.enter,state.leave=enter,leave
    I:AddPrompt({id=ID,front=true,builderType="prompts",glyph="Person",tone=GREEN,cap=L["QUEUE READY"],
        name=name,line=RoleLine(role),noTimer=true,buttons={enter,leave},
        onRemoved=function()
            Restore(state)
            if Q.active==state then Q.active=nil end
        end})
    Q.Tick()
end
function Q.Tick()
    local state=Q.active
    if not state then return end
    local exists,id,_,_,_,_,_,responded,_,_,members,_,_,_,silent=Call(GetLFGProposal)
    if ns.db.retailQueues==false or exists~=true or id~=state.id or silent==true then Q.Close() return end
    if responded==true then Q.Wait(state,members) return end
    if state.frame and Call(state.frame.IsShown,state.frame)==false then Q.Close() return end
    local popup=Targets(state)
    if popup then state.frame=popup end
    local top=I.rolls and I.rolls[1]
    if Combat() or not popup or not top or top.id~=ID or I.state~="roll" then Restore(state) return end
    -- Late-created native buttons may need one more FillRoll pass to arm the secure overlays.
    if (not state.enter.armed or not state.leave.armed) and I.FillRoll then I:FillRoll() end
    if state.enter.armed and state.leave.armed and ns.PopupCard then ns.PopupCard.Hide(popup)
    else Restore(state) end
end
function Q.Apply()
    if not ns.db or ns.db.retailQueues==false then Q.Close() else Q.Tick() end
end
local ev=CreateFrame("Frame")
ev:SetScript("OnEvent",function(_,event)
    if event=="LFG_PROPOSAL_SHOW" then Q.Show()
    elseif event=="LFG_PROPOSAL_UPDATE" or event=="PLAYER_REGEN_ENABLED" then Q.Tick()
    elseif event=="PLAYER_REGEN_DISABLED" then Restore(Q.active)
    else Q.Close() end
end)
local elapsed=0
ev:SetScript("OnUpdate",function(_,dt)
    if not Q.active then return end
    elapsed=elapsed+dt
    if elapsed<.2 then return end
    elapsed=0;Q.Tick()
end)
for _,event in ipairs({"LFG_PROPOSAL_SHOW","LFG_PROPOSAL_UPDATE","LFG_PROPOSAL_DONE","LFG_PROPOSAL_FAILED",
    "LFG_PROPOSAL_SUCCEEDED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","LOADING_SCREEN_ENABLED","PLAYER_ENTERING_WORLD"}) do
    pcall(ev.RegisterEvent,ev,event)
end
