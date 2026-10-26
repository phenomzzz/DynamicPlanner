local _, A = ...
local U=A.UI
local classIds={WARRIOR=1,PALADIN=2,HUNTER=3,ROGUE=4,PRIEST=5,DEATHKNIGHT=6,SHAMAN=7,MAGE=8,WARLOCK=9,MONK=10,DRUID=11,DEMONHUNTER=12,EVOKER=13}
U.INSPECT_GAP=1.6
local function groupUnits()
 local units={}
 if IsInRaid and IsInRaid() then
  for i=1,GetNumGroupMembers() do
   local name,_,group,_,_,classToken,_,_,_,_,_,role=GetRaidRosterInfo(i)
   if name and A.Public(name) and A.Public(group) and A.Public(classToken) then units[#units+1]={unit='raid'..i,name=name,group=group,classToken=classToken,role=role} end
  end
 else
  local n=GetNumGroupMembers and GetNumGroupMembers() or 0
  local list={'player'};for i=1,math.max(0,n-1) do list[#list+1]='party'..i end
  for i,unit in ipairs(list) do
   local name=UnitName and UnitName(unit)
   if name and A.Public(name) then
    local _,token=UnitClass(unit);local role=UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if role=='NONE' then role=nil end
    units[#units+1]={unit=unit,name=name,group=1,classToken=A.Public(token) and token or nil,role=role}
   end
  end
 end
 return units
end
local function setSpec(p,id)
 local s=A.SpecByID and A.SpecByID[id];if not s then return end
 p.specId=id;if s.class then p.classToken=s.class:upper();p.classId=classIds[p.classToken] end;if s.role then p.role=s.role end
end
local function inspectNext(queue)
 local job=table.remove(queue,1);if not job then U.inspecting=false;if A.model then A.Save();U.Render() end;return end
 if not A.Allowed() or not (CanInspect and CanInspect(job.unit)) or not NotifyInspect then return inspectNext(queue) end
 NotifyInspect(job.unit)
 C_Timer.After(U.INSPECT_GAP,function()
  if A.Allowed() and UnitExists and UnitExists(job.unit) then
   local id=GetInspectSpecialization and GetInspectSpecialization(job.unit)
   if id and A.Public(id) and id>0 then local ok=pcall(function() A.Edit(function() setSpec(job.p,id) end) end) end
  end
  if ClearInspectPlayer then ClearInspectPlayer() end
  inspectNext(queue)
 end)
end
function U.MergeGroup()
 if not A.Allowed() then return end
 local units=groupUnits();local queue,present={}, {}
 A.Edit(function(plan)
  local byName={};for _,p in ipairs(plan.roster) do byName[p.name:lower():gsub('%-.*','')]=p end
  for _,u in ipairs(units) do
   local short=u.name:gsub('%-.*','');local p=byName[short:lower()]
   if not p then p={name=short,active=#plan.roster<20};plan.roster[#plan.roster+1]=p;byName[short:lower()]=p end
   present[short:lower()]=true
   p.group=u.group;if u.classToken then p.classToken=u.classToken;p.classId=classIds[u.classToken] end;if u.role then p.role=u.role end
   if UnitIsUnit and UnitIsUnit(u.unit,'player') then
    local spec=GetSpecialization and GetSpecialization();if spec then local id=GetSpecializationInfo(spec);if A.Public(id) then p.specId=id end end
   elseif not p.specId then queue[#queue+1]={unit=u.unit,p=p} end
  end
 end)
 U.groupPresent=present
 if U.RefreshRosterNote then U.RefreshRosterNote() end
 if #queue>0 and not U.inspecting then U.inspecting=true;inspectNext(queue) end
end
function U.NotInGroupCount()
 if not U.groupPresent or not A.model then return 0 end
 local has={};for _,a in ipairs(A.model.plan.lines) do for tok in a.tag:gmatch('%S+') do has[tok:lower()]=true end end
 local n=0;for _,p in ipairs(A.model.plan.roster or {}) do if has[p.name:lower()] and not U.groupPresent[p.name:lower():gsub('%-.*','')] then n=n+1 end end
 return n
end
function U.RefreshRosterNote()
 if not U.rosterOut then return end
 local n=U.NotInGroupCount();U.rosterOut:SetText(n>0 and ('+'..A.T('addon.notInRaid',{n=n})) or '')
end
local function playerMenu(button,p)
 local items={
  {p.active and A.T('ro.off',{n=''}) or A.T('op.swapIn'),function() A.Edit(function(plan)
   local n=0;for _,r in ipairs(plan.roster) do if r.active then n=n+1 end end
   if p.active or n<20 then p.active=not p.active else A.Message('Raid is full. Swap with a player instead.') end
  end) end},
  {A.T('ro.spec'),function()
   local specs={};for _,s in ipairs(A.Specs) do specs[#specs+1]={s.className..' '..s.name,function() A.Edit(function() p.specId=s.id;local token=s.class:upper();p.classToken=token;p.classId=classIds[token];p.role=s.role end) end} end;U.Menu(button,specs)
  end},
  {A.T('addon.rename'),function() U.PlayerEditor(p) end},
  {A.T('spells'),function() U.Spells(button,p) end}}
 for _,q in ipairs(A.model.plan.roster) do if q~=p then items[#items+1]={A.T('op.swapWith')..' '..q.name,function() A.Edit(function(plan)
  if p.active==q.active then p.group,q.group=q.group,p.group;p.slot,q.slot=q.slot,p.slot
  else A.Model.swap(plan,p.active and p or q,p.active and q or p,A.CD) end
 end) end} end end
 U.Menu(button,items)
end
U.PlayerMenu=function(b,p) playerMenu(b,p) end
local ROLE_ORDER={{'tank','addon.roleTank'},{'healer','addon.roleHealer'},{'melee','addon.roleMelee'},{'ranged','addon.roleRanged'}}
local CELL_W,CELL_H,GAP=121,22,4
local function classKey(p) return p.classToken and 'class-'..p.classToken or 'ink-3' end
local function benchCount() local n=0;for _,r in ipairs(A.model.plan.roster) do if not r.active then n=n+1 end end;return n end
local function activeCount() local n=0;for _,r in ipairs(A.model.plan.roster) do if r.active then n=n+1 end end;return n end
local function drop(p,target,zone,seat)
 A.Edit(function(plan)
  if seat and not target then
   if p.active or activeCount()<20 then p.active=true;p.group=seat.g;p.slot=seat.s else A.Message(A.T('addon.raidFull')) end
  elseif target and target~=p then
   if p.active~=target.active then A.Model.swap(plan,p.active and p or target,p.active and target or p,A.CD)
   else p.group,target.group=target.group,p.group;p.slot,target.slot=target.slot,p.slot end
   A.Message(A.T('addon.swapped',{a=p.name,b=target.name}))
  elseif zone=='bench' then p.active=false
  elseif zone=='raid' and not p.active then
   if activeCount()<20 then p.active=true else A.Message(A.T('addon.raidFull')) end
  end
  A.Model.seat(plan)
 end)
end
U.RosterDrop=function(p,target,zone,seat) drop(p,target,zone,seat) end
local function startDrag(cell,p)
 if not A.Allowed() then return end
 local g=U.rosterGhost
 if not g then
  g=CreateFrame('Frame',nil,U.window);U.Surface(g,'panel','accent',4);g:SetSize(CELL_W,CELL_H);g:SetFrameStrata('TOOLTIP');g:EnableMouse(false)
  g.icon=g:CreateTexture(nil,'ARTWORK');g.icon:SetSize(18,18);g.icon:SetPoint('LEFT',2,0);g.icon:SetTexCoord(0.08,0.92,0.08,0.92)
  g.text=U.Label(g,'',24,0,12,'textMedium');g.text:ClearAllPoints();g.text:SetPoint('LEFT',24,0);U.rosterGhost=g
 end
 g:SetBackdropColor(U.Color(classKey(p)));g.icon:SetTexture(U.SpecIcon(p.specId,p.classToken));g.text:SetText(p.name);g.text:SetTextColor(U.Color('ground'))
 U.rosterDrag=p;cell:SetAlpha(0.35);g:Show()
 g:SetScript('OnUpdate',function(self)
  local cx,cy=GetCursorPosition();local s=self:GetEffectiveScale();self:ClearAllPoints();self:SetPoint('CENTER',UIParent,'BOTTOMLEFT',cx/s+10,cy/s-6)
  for _,b in ipairs(U.rosterPool.used) do
   if b.player or b.zone or b.seat then
    local over=b:IsMouseOver() and b.player~=p
    if b.player then b:SetBackdropBorderColor(U.ColorA(over and 'accent' or 'line',over and 1 or 0))
    elseif b.seat then b:SetBackdropBorderColor(U.ColorA(over and 'accent' or 'line',1))
    elseif b.zone then b:SetBackdropBorderColor(U.ColorA('accent',over and 0.8 or 0)) end
   end
  end
 end)
end
local function stopDrag(p)
 if U.rosterDrag~=p then return end
 local g=U.rosterGhost;if g then g:SetScript('OnUpdate',nil);g:Hide() end
 U.rosterDrag=nil;U.rosterDropAt=GetTime and GetTime() or 0
 if not A.Allowed() then U.DrawRoster();return end
 local target,zone
 local seat
 for _,b in ipairs(U.rosterPool.used) do if b:IsMouseOver() then
  if b.player and b.player~=p then target=b.player elseif b.seat and not b.player then seat=b.seat elseif b.zone and not zone then zone=b.zone end
 end end
 if target or seat or zone then drop(p,target,zone,seat) else U.DrawRoster() end
end
local function query() local q=U.rosterSearch and U.rosterSearch:GetText() or '';return q:lower() end
local function matches(p) local q=query();return q=='' or p.name:lower():find(q,1,true)~=nil or ((A.SpecByID[p.specId] or {}).name or ''):lower():find(q,1,true)~=nil end
function U.RosterFirstMatch() if query()=='' then return end;for _,p in ipairs(A.model.plan.roster or {}) do if p.active and matches(p) then return p end end;for _,p in ipairs(A.model.plan.roster or {}) do if matches(p) then return p end end end
local function cell(pool,p,xx,yy)
 local b=pool:get();b:SetPoint('TOPLEFT',xx,-yy);b:SetSize(CELL_W,CELL_H);U.Radius(b,3)
 b:SetBackdropColor(U.Color(classKey(p)));b:SetBackdropBorderColor(0,0,0,0);b.player=p
 b.icon:SetTexture(U.SpecIcon(p.specId,p.classToken));b.icon:ClearAllPoints();b.icon:SetPoint('LEFT',2,0);b.icon:SetSize(18,18);b.icon:Show()
 b.text:ClearAllPoints();b.text:SetPoint('LEFT',24,0);b.text:SetWidth(CELL_W-56);U.Font(b.text,12,'textMedium');b.text:SetTextColor(U.Color('ground'));b.text:SetText(p.name)
 if not b.ilvl then b.ilvl=U.Text(b);U.Line(b.ilvl) end
 b.ilvl:ClearAllPoints();b.ilvl:SetPoint('RIGHT',-5,0);U.Font(b.ilvl,10,'mono');b.ilvl:SetTextColor(U.ColorA('ground',0.7));b.ilvl:SetText(p.itemLevel and tostring(p.itemLevel) or '');b.ilvl:Show()
 b:SetScript('OnClick',function(self,button) if U.rosterDrag or (GetTime and U.rosterDropAt and GetTime()-U.rosterDropAt<0.3) then return end;if button=='RightButton' then U.PlayerMenu(self,p) else U.JumpToPlayer(p) end end)
 b:SetScript('OnDragStart',function(self) startDrag(self,p) end);b:SetScript('OnDragStop',function() stopDrag(p) end)
 b:SetAlpha(matches(p) and 1 or 0.3)
 b:SetScript('OnEnter',function(self) if U.rosterDrag then return end;local spec=A.SpecByID[p.specId];U.Tooltip(self,p.name..'\n'..(spec and spec.name..' '..(spec.className or '') or '')..(p.itemLevel and '\n'..A.T('ro.ilvl')..' '..p.itemLevel or '')) end)
 b:SetScript('OnLeave',function() GameTooltip:Hide() end)
 return b
end
local function chip(pool,p,xx,yy)
 local b=pool:get();U.Radius(b,4);b:SetBackdropColor(U.Color('ground-2'));b:SetBackdropBorderColor(U.Color('line'));b.player=p
 b.icon:SetTexture(U.SpecIcon(p.specId,p.classToken));b.icon:ClearAllPoints();b.icon:SetPoint('LEFT',2,0);b.icon:SetSize(16,16);b.icon:Show()
 b.text:ClearAllPoints();b.text:SetPoint('LEFT',22,0);U.Font(b.text,11,'textMedium');b.text:SetTextColor(U.Color(classKey(p)));b.text:SetText(p.name)
 if b.ilvl then b.ilvl:Hide() end
 local w=math.ceil(b.text:GetUnboundedStringWidth()+30);b:SetSize(w,20);b:SetPoint('TOPLEFT',xx,-yy);b:SetAlpha(matches(p) and 1 or 0.3)
 b:SetScript('OnClick',function(self,button) if U.rosterDrag or (GetTime and U.rosterDropAt and GetTime()-U.rosterDropAt<0.3) then return end;if button=='RightButton' then U.PlayerMenu(self,p) else U.JumpToPlayer(p) end end)
 b:SetScript('OnDragStart',function(self) startDrag(self,p) end);b:SetScript('OnDragStop',function() stopDrag(p) end)
 return b,w
end
local function zone(pool,key,xx,yy,w,h)
 local z=pool:get();z:SetPoint('TOPLEFT',xx,-yy);z:SetSize(w,h);U.Radius(z,6);z:SetBackdropColor(0,0,0,0);z:SetBackdropBorderColor(U.ColorA('accent',0));z.zone=key;z:EnableMouse(true)
 z:SetFrameLevel(U.roster:GetFrameLevel()+1);return z
end
local function heading(pool,text,count,yy,width)
 local h=pool:get();h:SetPoint('TOPLEFT',10,-yy);h:SetSize(width-20,16);h:SetBackdrop(nil);h:EnableMouse(false)
 U.Font(h.text,11,'textMedium');h.text:SetTextColor(U.Color('ink-3'));h.text:SetText(text)
 if not h.count then h.count=U.Text(h) end;h.count:ClearAllPoints();h.count:SetPoint('RIGHT',0,0);U.Font(h.count,11,'mono');h.count:SetTextColor(U.Color('ink-3'));h.count:SetText(count and tostring(count) or '');h.count:Show()
 return h
end
local GW,GH,GG=104,30,4
U.ROSTER_WIDTH=4*GW+3*GG+24
local RAIL_MODES={'custom','role','group','class'}
local function drawRail(pool,width)
 local plan=A.model.plan;local hidden=(A.db.railHidden or {})[A.boss.id] or {}
 local xx=12;local top=94
 for _,m in ipairs(RAIL_MODES) do
  local b=pool:get();b:SetPoint('TOPLEFT',xx,-top);b:SetHeight(24);U.Radius(b,4)
  b.text:ClearAllPoints();b.text:SetPoint('CENTER');b.text:SetJustifyH('CENTER');U.Font(b.text,12,'textMedium');b.text:SetText(A.T('rail.'..m))
  b:SetWidth(b.text:GetUnboundedStringWidth()+18);xx=xx+b:GetWidth()+4;U.Active(b,(plan.railMode or 'role')==m)
  b:SetScript('OnClick',function() A.Edit(function(pl) A.Model.setRailMode(pl,m) end) end)
 end
 local hint=pool:get();hint:SetPoint('TOPLEFT',12,-(top+30));hint:SetSize(width-24,16);hint:SetBackdrop(nil);hint:EnableMouse(false)
 U.Font(hint.text,11);hint.text:SetTextColor(U.Color('ink-3'));hint.text:SetText(A.T('rail.hint'))
 local y=top+52;local rowH=24;local list=A.Model.railOrdered(plan)
 local maxRows=math.max(1,math.floor((U.roster:GetHeight()-y-46)/(rowH+2)));local offset=math.max(0,math.min(U.railOffset or 0,math.max(0,#list-maxRows)));U.railOffset=offset
 for i=offset+1,math.min(#list,offset+maxRows) do
  local p=list[i];local yy=y+(i-offset-1)*(rowH+2)
  local r=pool:get();r:SetPoint('TOPLEFT',8,-yy);r:SetSize(width-16,rowH);U.Radius(r,4);r:SetBackdropColor(U.Color(hidden[p.name] and 'ground' or 'ground-2'));r:SetBackdropBorderColor(U.Color('line'));r.player=p;r.railRow=true
  r:SetAlpha(p.active and 1 or 0.55)
  r.icon:SetTexture(U.SpecIcon(p.specId,p.classToken));r.icon:ClearAllPoints();r.icon:SetPoint('LEFT',22,0);r.icon:SetSize(18,18);r.icon:Show()
  r.text:ClearAllPoints();r.text:SetPoint('LEFT',46,0);r.text:SetWidth(150);U.Font(r.text,12,'textMedium');r.text:SetTextColor(U.Color(p.classToken and 'class-'..p.classToken or 'ink'));r.text:SetText(i..'  '..p.name)
  if not r.ilvl then r.ilvl=U.Text(r);U.Line(r.ilvl) end
  local spec=A.SpecByID[p.specId];r.ilvl:ClearAllPoints();r.ilvl:SetPoint('LEFT',200,0);U.Font(r.ilvl,11);r.ilvl:SetTextColor(U.Color('ink-3'));r.ilvl:SetText((spec and spec.name or '')..(p.active and '' or '  '..A.T('blk.bench')));r.ilvl:Show()
  local g=pool:get();g:SetPoint('LEFT',r,'LEFT',4,0);g:SetSize(14,rowH);g:SetBackdrop(nil);g:EnableMouse(false);g:SetFrameLevel(r:GetFrameLevel()+1)
  g.text:ClearAllPoints();g.text:SetPoint('CENTER');U.Font(g.text,12,'mono');g.text:SetTextColor(U.Color('ink-3'));g.text:SetText('::')
  local eye=pool:get();eye:SetSize(22,20);eye:SetPoint('RIGHT',r,'RIGHT',-4,0);eye:SetFrameLevel(r:GetFrameLevel()+2);U.Radius(eye,4);eye:SetBackdropColor(0,0,0,0);eye:SetBackdropBorderColor(0,0,0,0);U.Eye(eye)
  eye.icon:SetAlpha(hidden[p.name] and 0.35 or 1)
  eye:SetScript('OnClick',function() if IsAltKeyDown() then U.SoloRail(p.name) else U.SetHidden(p.name,not hidden[p.name]) end end)
  eye:SetScript('OnEnter',function(self) U.Tooltip(self,A.T(hidden[p.name] and 'rail.show' or 'rail.hide',{name=p.name})..'\n|cff8a7f8d'..A.T('rail.shared')..'\n'..A.T('keys.soloEyeHint')..'|r') end);eye:SetScript('OnLeave',function() GameTooltip:Hide() end)
  r:SetScript('OnClick',function(_,button) if U.railDrag then return end;if button=='RightButton' then U.PlayerMenu(r,p) else U.JumpToPlayer(p) end end)
  r:SetScript('OnDragStart',function(self)
   if not A.Allowed() then return end
   U.railDrag=p;self:SetAlpha(0.35)
   self:SetScript('OnUpdate',function() for _,b in ipairs(pool.used) do if b.railRow then b:SetBackdropBorderColor(U.ColorA(b:IsMouseOver() and b.player~=p and 'accent' or 'line',1)) end end end)
  end)
  r:SetScript('OnDragStop',function(self)
   self:SetScript('OnUpdate',nil)
   if U.railDrag~=p then return end;U.railDrag=nil
   local target;for _,b in ipairs(pool.used) do if b.railRow and b:IsMouseOver() and b.player~=p then target=b.player end end
   if target and A.Allowed() then A.Edit(function(pl) A.Model.railMove(pl,p.name,target.name) end);A.Message(A.T('addon.railMoved',{name=p.name,before=target.name})) else U.DrawRoster() end
  end)
 end
end
function U.DrawRoster()
 if (A.db.rosterView or 'grid')=='rail' then
  U.rosterPool:release();U.rosterTitle:SetText(A.T('rail.title'));U.rosterCount:SetText('');U.rosterRoles:SetText(A.T('rail.shared'))
  for k,b in pairs(U.rosterViews or {}) do U.Active(b,k=='rail') end
  U.rosterSearch:Hide();drawRail(U.rosterPool,U.roster:GetWidth());return
 end
 U.rosterSearch:Show();for k,b in pairs(U.rosterViews or {}) do U.Active(b,k=='grid') end
 local occupied=A.Model.seat(A.model.plan)
 U.rosterPool:release();local pool=U.rosterPool;local width=U.roster:GetWidth()
 local bench,counts={}, {tank=0,healer=0,melee=0,ranged=0}
 local active=0
 for _,p in ipairs(A.model.plan.roster or {}) do if p.active then active=active+1;counts[p.role or 'ranged']=(counts[p.role or 'ranged'] or 0)+1 else bench[#bench+1]=p end end
 local order={tank=1,healer=2,melee=3,ranged=4}
 table.sort(bench,function(x,y) local rx,ry=order[x.role] or 5,order[y.role] or 5;if rx~=ry then return rx<ry end;return x.name:lower()<y.name:lower() end)
 U.rosterTitle:SetText(A.T('ro.title'));U.rosterCount:SetText(active..'/20');U.rosterHint:SetText(A.T('addon.search'))
 U.rosterRoles:SetText(A.T('addon.roleCounts',{t=counts.tank,h=counts.healer,m=counts.melee,r=counts.ranged}));U.RefreshRosterNote()
 local top=94
 for g=1,4 do
  local gx=12+(g-1)*(GW+GG)
  local n=0;for s2=1,5 do if occupied[(g-1)*5+s2] then n=n+1 end end
  local h=pool:get();h:SetPoint('TOPLEFT',gx,-top);h:SetSize(GW,16);h:SetBackdrop(nil);h:EnableMouse(false)
  U.Font(h.text,11,'textMedium');h.text:SetTextColor(U.Color('ink-3'));h.text:ClearAllPoints();h.text:SetPoint('LEFT',2,0);h.text:SetText(A.T('ro.groupN',{n=g}))
  if not h.count then h.count=U.Text(h) end;h.count:ClearAllPoints();h.count:SetPoint('RIGHT',-2,0);U.Font(h.count,10,'mono');h.count:SetTextColor(U.Color('ink-3'));h.count:SetText(n..'/5');h.count:Show()
  for s2=1,5 do
   local p=occupied[(g-1)*5+s2];local y=top+18+(s2-1)*(GH+GG)
   if p then
    local c=cell(pool,p,gx,y);c:SetSize(GW,GH);c.seat={g=g,s=s2}
    c.text:SetWidth(GW-28);if c.ilvl then c.ilvl:Hide() end
   else
    local e=pool:get();e:SetPoint('TOPLEFT',gx,-y);e:SetSize(GW,GH);U.Radius(e,3);e:SetBackdropColor(U.Color('ground-2'));e:SetBackdropBorderColor(U.Color('line'));e.seat={g=g,s=s2}
    U.Font(e.text,11);e.text:SetTextColor(U.Color('ink-3'));e.text:ClearAllPoints();e.text:SetPoint('CENTER');e.text:SetJustifyH('CENTER');e.text:SetText(A.T('addon.emptySlot'))
   end
  end
 end
 local yy=top+18+5*(GH+GG)+10
 zone(pool,'raid',6,top-4,width-12,yy-top)
 heading(pool,A.T('addon.bench'),#bench,yy,width);yy=yy+20
 local benchTop=yy;local xx=12
 for _,p in ipairs(bench) do
  local c,w=chip(pool,p,xx,yy)
  if xx+w>width-12 and xx>12 then xx=12;yy=yy+24;c:ClearAllPoints();c:SetPoint('TOPLEFT',xx,-yy) end
  xx=xx+w+4
 end
 yy=yy+28
 zone(pool,'bench',6,benchTop-24,width-12,math.max(44,yy-benchTop+20))
end
function U.RaidGrid()
 if not A.Allowed() then return end
 if not U.grid then
  local f=CreateFrame('Frame',nil,U.window);U.Surface(f);f:SetPoint('CENTER');f:SetSize(1000,560);f:SetFrameStrata('DIALOG');f.pool=U.Pool(f);f.focus=1
  f.title=U.Label(f,'',16,-16,18,'display');f.hint=U.Label(f,'',16,-48,12);f.hint:SetWidth(940)
  U.Button(f,'Close',880,-14,100,function() f:Hide() end,{always=true})
  local function drop(g,s,bench)
   local incoming=f.carry;if not incoming then return end
   f.carry=nil
   A.Edit(function(plan)
    if bench then incoming.active=false;return end
    local target
    for _,p in ipairs(plan.roster) do if p.active and p.group==g and p.slot==s then target=p;break end end
    if target==incoming then return end
    if target and not incoming.active then A.Model.swap(plan,target,incoming,A.CD)
    elseif target then incoming.group,target.group=target.group,incoming.group;incoming.slot,target.slot=target.slot,incoming.slot
    else incoming.active=true;incoming.group=g;incoming.slot=s end
    A.Model.seat(plan)
   end)
   U.DrawGrid()
  end
  f.drop=drop
  f:EnableKeyboard(true);U.Propagate(f,true);f:SetScript('OnKeyDown',function(_,key)
   if not A.Allowed() then return end
   if key=='ESCAPE' then f.carry=nil;f:Hide();U.Propagate(f,false);return end
   if key=='Left' or key=='LEFT' then f.focus=math.max(1,f.focus-5)
   elseif key=='Right' or key=='RIGHT' then f.focus=math.min(20,f.focus+5)
   elseif key=='Up' or key=='UP' then f.focus=math.max(1,f.focus-1)
   elseif key=='Down' or key=='DOWN' then f.focus=math.min(20,f.focus+1)
   elseif key=='ENTER' then local g=math.floor((f.focus-1)/5)+1;local s=(f.focus-1)%5+1
    if f.carry then drop(g,s,false) else f.carry=A.Model.seat(A.model.plan)[f.focus] end
   elseif key=='DELETE' or key=='BACKSPACE' then local p=A.Model.seat(A.model.plan)[f.focus];if p then f.carry=p;drop(nil,nil,true) end
   else U.Propagate(f,true);return end
   U.Propagate(f,false);U.DrawGrid()
  end)
  U.grid=f
 end
 U.grid.carry=nil;U.grid:Show();U.DrawGrid();U.RefreshLabels()
end
function U.DrawGrid()
 local f=U.grid;if not f then return end
 f.pool:release();local occupied=A.Model.seat(A.model.plan)
 f.title:SetText(A.T('addon.grid'));f.hint:SetText(A.T('addon.gridHelp'))
 local function cell(p,xx,yy,g,s,bench)
  local b=f.pool:get();b:SetPoint('TOPLEFT',xx,yy);b:SetSize(bench and 250 or 168,52);b.player=p;b.seat=g and {g=g,s=s} or nil;b.bench=bench
  if p then b.icon:SetTexture(U.SpecIcon(p.specId,p.classToken));b.icon:Show();b.text:SetPoint('LEFT',24,0);b.text:SetWidth(bench and 214 or 136);b.text:SetText(p.name..'\n'..(A.SpecByID[p.specId] and A.SpecByID[p.specId].name or '')..(p.itemLevel and ' '..p.itemLevel or ''));b:SetBackdropColor(U.Color(p.classToken and 'class-'..p.classToken or 'panel-2'));b.text:SetTextColor(U.Color(p.classToken and 'ground' or 'ink')) end
  if g and f.focus==(g-1)*5+s then b:SetBackdropBorderColor(U.Color('accent')) end
  b:SetScript('OnClick',function(_,button)
   if not A.Allowed() then return end
   if button=='RightButton' and p then playerMenu(b,p);return end
   if f.carry then f.drop(g,s,bench) elseif p then f.carry=p;if g then f.focus=(g-1)*5+s end;U.DrawGrid() end
  end)
  b:SetScript('OnDragStart',function() if A.Allowed() then f.carry=p end end)
  b:SetScript('OnDragStop',function()
   if not A.Allowed() then f.carry=nil;return end
   for _,target in ipairs(f.pool.used) do if target:IsMouseOver() and (target.seat or target.bench) then local seat=target.seat;f.drop(seat and seat.g,seat and seat.s,target.bench);return end end
   f.carry=nil
  end)
  return b
 end
 for g=1,4 do
  local title=f.pool:get();title:SetPoint('TOPLEFT',16+(g-1)*176,-90);title:SetSize(168,26);title.text:SetText(A.T('ro.groupN',{n=g}))
  for s=1,5 do cell(occupied[(g-1)*5+s],16+(g-1)*176,-122-(s-1)*60,g,s,false) end
 end
 local title=f.pool:get();title:SetPoint('TOPLEFT',728,-90);title:SetSize(250,26);title.text:SetText(A.T('bench'))
 local bench={};for _,p in ipairs(A.model.plan.roster) do if not p.active then bench[#bench+1]=p end end
 local offset=f.benchOffset or 0
 for i=offset+1,math.min(#bench,offset+6) do cell(bench[i],728,-122-(i-offset-1)*60,nil,nil,true) end
 local target=cell(nil,16,-450,nil,nil,true);target:SetWidth(696);target.text:SetText(A.T('ro.benchBtn'))
 f:EnableMouseWheel(true);f:SetScript('OnMouseWheel',function(_,d) if A.Allowed() then f.benchOffset=math.max(0,math.min(math.max(0,#bench-6),offset-d*2));U.DrawGrid() end end)
end
function U.PlayerEditor(player)
 if not U.playerEditor then
  local f=CreateFrame('Frame',nil,U.window);U.Surface(f);f:SetSize(360,180);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG')
  f.nameLabel=U.Label(f,'Name',12,-12);f.ilvlLabel=U.Label(f,'Item level',12,-72)
  f.name=CreateFrame('EditBox',nil,f,'InputBoxTemplate');f.name:SetSize(300,28);f.name:SetPoint('TOPLEFT',20,-36);f.name:SetAutoFocus(false)
  f.ilvl=CreateFrame('EditBox',nil,f,'InputBoxTemplate');f.ilvl:SetSize(100,28);f.ilvl:SetPoint('TOPLEFT',20,-94);f.ilvl:SetAutoFocus(false);f.ilvl:SetNumeric(true)
  U.Button(f,'Save',230,-138,110,function()
   local n=f.name:GetText();if n=='' or n:find('[;%s]') then return end
   for _,p in ipairs(A.model.plan.roster) do if p~=f.player and p.name:lower()==n:lower() then A.Message('Player already exists');return end end
   A.Edit(function(plan)
    local p=f.player
    if p then for _,a in ipairs(plan.lines) do if a.tag==p.name then a.tag=n end end
    else p={active=false};plan.roster[#plan.roster+1]=p end
    p.name=n;p.itemLevel=tonumber(f.ilvl:GetText())
   end);f:Hide()
  end)
  U.Button(f,'Cancel',12,-138,110,function() f:Hide() end);U.playerEditor=f
 end
 local f=U.playerEditor;f.nameLabel:SetText(A.T('ro.name'));f.ilvlLabel:SetText(A.T('ro.ilvl'));f.player=player;f.name:SetText(player and player.name or '');f.ilvl:SetText(player and player.itemLevel or '');f:Show();f.name:SetFocus();U.RefreshLabels()
end
function U.CreateRoster(parent)
 U.roster=CreateFrame('Frame',nil,parent);U.Surface(U.roster,'panel','line',10);U.roster:SetPoint('TOPLEFT',12,-130);U.roster:SetPoint('BOTTOMLEFT',12,36);U.roster:SetWidth(U.ROSTER_WIDTH);U.roster:SetClipsChildren(true)
 U.rosterTitle=U.Label(U.roster,'',12,-14,15,'displayMedium')
 U.rosterCount=U.Label(U.roster,'',0,0,15,'displayMedium');U.rosterCount:ClearAllPoints();U.rosterCount:SetPoint('TOPRIGHT',-12,-14)
 U.rosterRoles=U.Label(U.roster,'',12,-38,11);U.rosterRoles:SetTextColor(U.Color('ink-3'))
 U.rosterSearch=U.Input(U.roster,U.ROSTER_WIDTH-24);U.rosterSearch:SetPoint('TOPLEFT',12,-56);U.rosterSearch:SetHeight(28)
 U.rosterHint=U.Label(U.rosterSearch,'',10,0,12);U.rosterHint:ClearAllPoints();U.rosterHint:SetPoint('LEFT',10,0);U.rosterHint:SetTextColor(U.Color('ink-3'))
 U.rosterSearch:SetScript('OnTextChanged',function(self) U.rosterHint:SetShown(self:GetText()=='');U.DrawRoster() end)
 U.rosterSearch:SetScript('OnEnterPressed',function(self) local p=U.RosterFirstMatch();self:ClearFocus();if p then U.JumpToPlayer(p) end end)
 U.rosterModes={}
 local add=U.Button(U.roster,'+ Player',0,0,0,function() U.PlayerEditor() end,{height=24});add:ClearAllPoints();add:SetPoint('BOTTOMLEFT',12,10)
 local live=U.Button(U.roster,'Read from raid',0,0,0,U.MergeGroup,{height=24,key='addon.live'});live:ClearAllPoints();live:SetPoint('TOPRIGHT',U.rosterCount,'TOPLEFT',-10,6);U.readRaidButton=live
 U.rosterOut=U.Label(U.roster,'',0,0,11);U.rosterOut:ClearAllPoints();U.rosterOut:SetPoint('TOPRIGHT',-12,-38);U.rosterOut:SetTextColor(U.Color('tl-conflict'))
 U.rosterViews={}
 local rail=U.Button(U.roster,'Rail order',0,0,0,function() A.db.rosterView='rail';U.DrawRoster() end,{height=24,key='rail.title'});rail:ClearAllPoints();rail:SetPoint('BOTTOMRIGHT',-12,10)
 local grid=U.Button(U.roster,'Raid frames',0,0,0,function() A.db.rosterView='grid';U.DrawRoster() end,{height=24,key='addon.grid'});grid:ClearAllPoints();grid:SetPoint('RIGHT',rail,'LEFT',-4,0)
 U.rosterViews.rail=rail;U.rosterViews.grid=grid
 U.rosterPool=U.Pool(U.roster)
 U.rosterRoles:SetWidth(U.ROSTER_WIDTH-24);U.Line(U.rosterRoles)
 U.roster:EnableMouseWheel(true);U.roster:SetScript('OnMouseWheel',function(_,d) if A.db.rosterView=='rail' then U.railOffset=math.max(0,(U.railOffset or 0)-d*3);U.DrawRoster() end end)
end
