local _, A = ...
local U=A.UI
local labelWidth=210
local GetCursorPosition,IsMouseButtonDown=GetCursorPosition,IsMouseButtonDown
local function x(t) return labelWidth+(t-A.view.start)/A.view.span*(U.canvas:GetWidth()-labelWidth) end
local function perSecond() return (U.canvas:GetWidth()-labelWidth)/A.view.span end
local function timeAt()
 local cx=GetCursorPosition(); return A.view.start+(cx/U.canvas:GetEffectiveScale()-U.canvas:GetLeft()-labelWidth)/(U.canvas:GetWidth()-labelWidth)*A.view.span
end
local function cursorLocal()
 local cx,cy=GetCursorPosition();local s=U.playerCanvas:GetEffectiveScale()
 return cx/s-U.playerCanvas:GetLeft(),U.playerCanvas:GetTop()-cy/s
end
local function visible(s,e) return e>=A.view.start and s<=A.view.start+A.view.span end
local function rect(pool,s,e,y,h,color,label)
 if not visible(s,e) then return end
 local b=pool:get(); local l=math.max(labelWidth,x(s));local r=math.min(U.canvas:GetWidth(),x(e))
 local w=math.max(3,r-l);b:SetPoint('TOPLEFT',l,-y);b:SetSize(w,h);b:SetBackdropColor(U.Color(color));b:SetBackdropBorderColor(0,0,0,0)
 b.text:SetText(label or '');if label then b.text:SetWidth(math.max(0,w-10)) end;return b
end
local M=A.Model
local function absT(a) return U.over and U.over[a] or M.absolute(a,A.model.phases) end
U.rev=U.rev or 0
local memo
local function memoNow()
 if not memo or memo.rev~=U.rev then memo={rev=U.rev,lines={},data={},pre={},count={}} end
 return memo
end
U.Memo=memoNow
local function raidTag(tag) for tok in tag:gmatch('%S+') do if not M.isSelector(tok) then return false end end;return true end
U.RaidTag=raidTag
local function hasName(tag,name) return (' '..tag:lower()..' '):find(' '..name:lower()..' ',1,true)~=nil end
local function hiddenSet()
 A.db.railHidden=A.db.railHidden or {};local h=A.db.railHidden[A.boss.id] or {};A.db.railHidden[A.boss.id]=h;return h
end
function U.SetHidden(name,hide) local h=hiddenSet();h[name]=hide or nil;U.Render() end
function U.HiddenCount() local n=0;local h=hiddenSet();for _,p in ipairs(A.model.plan.roster or {}) do if h[p.name] then n=n+1 end end;return n end
function U.ShowAllHidden() A.db.railHidden[A.boss.id]={};U.Render() end
function U.SoloRail(name)
 local h=hiddenSet();local alone=not h[name]
 for _,p in ipairs(A.model.plan.roster or {}) do if p.name~=name and not h[p.name] then alone=false end end
 if alone then U.ShowAllHidden();return end
 local nh={};for _,p in ipairs(A.model.plan.roster or {}) do if p.name~=name then nh[p.name]=true end end
 A.db.railHidden[A.boss.id]=nh;U.Render()
end
function U.FoldAll(fold)
 local c={};if fold then c['@everyone']=true;for _,p in ipairs(A.model.plan.roster or {}) do c[p.name]=true end end
 A.view.collapsed=c;U.rowsDirty=true;U.DrawTimeline();A.Save()
end
local SPV_CATS={'heal','raiddr','raidmob','raidutil','externals','throughput','mobility','utility','defensives','cc','items'}
local CAT_RANK={};for i,c in ipairs(SPV_CATS) do CAT_RANK[c]=i end
local ESSENTIAL={heal=true,raiddr=true,raidmob=true,raidutil=true,externals=true}
local function isEssential(s) if s.essential~=nil then return s.essential and true or false end;return ESSENTIAL[s.cat]==true end
local function catShown(cat) local off=A.view.catsOff;if off and off[cat] then return false end;return A.view.category==nil or A.view.category=='all' or A.view.category==cat end
U.CatShown=catShown
local castable={}
local function castableFor(p)
 local key=tostring(p.classId)..':'..tostring(p.specId)..':'..tostring(p.classToken)
 local list=castable[key]
 if not list then list={};for i,s in ipairs(A.Cooldowns) do if M.canCast(p,s) and not s.memberOnly then list[#list+1]=i end end;castable[key]=list end
 return list
end
local function spellsFor(p,used)
 local ids,seen={}, {}
 for _,i in ipairs(castableFor(p)) do local s=A.Cooldowns[i];do
  local own=p.spells and p.spells[s.id]
  local shown=catShown(s.cat) and (A.view.preset=='all' or (A.view.preset=='essential' and isEssential(s)) or (A.view.preset=='clear' and used[s.id]))
  if own==true or (own==nil and shown) then ids[#ids+1]={id=s.id,rank=CAT_RANK[s.cat] or 99,i=i};seen[s.id]=true end
 end end
 for id in pairs(used) do if not seen[id] then ids[#ids+1]={id=id,rank=A.CD[id] and CAT_RANK[A.CD[id].cat] or 100,i=1000+id%1000} end end
 table.sort(ids,function(a,b) if a.rank~=b.rank then return a.rank<b.rank end;return a.i<b.i end)
 local out={};for _,x in ipairs(ids) do out[#out+1]=x.id end;return out
end
local function spellOf(id) return A.CD[id] or {id=id,name='Spell '..tostring(id),cat='unknown',cooldown=0,duration=0} end
local PERS_ICON=871
local function rows()
 local out={};local lines=A.model.plan.lines;local collapsed=A.view.collapsed or {};A.view.collapsed=collapsed
 out[#out+1]={header=true,everyone=true}
 if not collapsed['@everyone'] then
  local ids,seen={}, {};for _,id in ipairs(M.EV_ITEMS) do ids[#ids+1]=id;seen[id]=true end
  for _,a in ipairs(lines) do if a.spellId and raidTag(a.tag) and not seen[a.spellId] then ids[#ids+1]=a.spellId;seen[a.spellId]=true end end
  for _,id in ipairs(ids) do out[#out+1]={everyone=true,spell=spellOf(id)} end
  out[#out+1]={everyone=true,personals=true,spell={name=A.T('ev.personals'),icon=PERS_ICON,cooldown=0,duration=0}}
  out[#out+1]={everyone=true,other=true,spell={name=A.T('ev.text'),cooldown=0,duration=0}}
 end
 local has={};for _,a in ipairs(lines) do for tok in a.tag:gmatch('%S+') do has[tok:lower()]=true end end
 local hidden=hiddenSet()
 for _,p in ipairs(M.railOrdered(A.model.plan)) do if (p.active or has[p.name:lower()]) and not hidden[p.name] then
  out[#out+1]={gap=true}
  out[#out+1]={player=p,header=true}
  if not collapsed[p.name] then
   local used={};for _,a in ipairs(lines) do if a.spellId and hasName(a.tag,p.name) then used[a.spellId]=true end end
   for _,id in ipairs(spellsFor(p,used)) do out[#out+1]={player=p,spell=spellOf(id),off=A.CD[id]==nil or not M.canCast(p,A.CD[id])} end
   out[#out+1]={player=p,other=true,spell={name=A.T('row.other'),duration=0,cooldown=0}}
  end
 end end
 return out
end
U.RowsFor=rows
function U.Spells(button,player)
 local items={{A.T('preset.all'),function() A.Edit(function() player.spells={};for _,s in ipairs(A.Cooldowns) do if M.canCast(player,s) and not s.memberOnly then player.spells[s.id]=true end end end) end},
 {A.T('preset.clear'),function() A.Edit(function() player.spells={};for _,s in ipairs(A.Cooldowns) do player.spells[s.id]=false end end) end},
 {A.T('addon.spellsDefault'),function() A.Edit(function() player.spells=nil end) end},{'',nil,divider=true}}
 local last
 for _,cat in ipairs(SPV_CATS) do for _,s in ipairs(A.Cooldowns) do if s.cat==cat and M.canCast(player,s) and not s.memberOnly then
  if last~=cat then items[#items+1]={A.T('cat.'..cat),nil,title=true};last=cat end
  local id=s.id
  items[#items+1]={'|T'..U.Icon(id)..':16:16:0:0|t '..s.name,function() A.Edit(function() player.spells=player.spells or {};local cur=player.spells[id];if cur==nil then cur=false end;player.spells[id]=not cur end) end,multi=true,
   isChecked=function() return player.spells and player.spells[id]==true end}
 end end end
 U.Menu(button,items)
end
U.multi={}
function U.ClearSelection() U.multi={};U.selLine=nil;if U.selbar then U.SyncSelbar() end end
function U.Selected()
 local out={};for a in pairs(U.multi) do out[#out+1]=a end
 if #out==0 and U.selLine then out[1]=U.selLine end
 return out
end
local function multiCount() local n=0;for _ in pairs(U.multi) do n=n+1 end;return n end
function U.SetMulti(list)
 U.multi={};for _,a in ipairs(list) do U.multi[a]=true end;U.selLine=nil;U.SyncSelbar();U.RequestPlayers()
end
local function live(a) for _,b in ipairs(A.model.plan.lines) do if b==a then return true end end end
function U.RemoveLines(list,quiet)
 if #list==0 then return end
 local set={};for _,a in ipairs(list) do set[a]=true end
 A.Edit(function(plan) local keep={};for _,a in ipairs(plan.lines) do if not set[a] then keep[#keep+1]=a end end;plan.lines=keep end)
 U.ClearSelection();if not quiet then A.Message(A.T('addon.removedN',{n=#list})) end
end
function U.DuplicateLines(list)
 local src={};for _,a in ipairs(list) do if a.spellId and M.absolute(a,A.model.phases) then src[#src+1]=a end end
 if #src==0 then A.Message(A.T('ctx.noSpell'));return end
 local made={}
 A.Edit(function(plan)
  for _,a in ipairs(src) do
   local sp=A.CD[a.spellId];local cd=sp and sp.cooldown or 0;if cd<=0 then cd=5 end
   local n={tag=a.tag,spellId=a.spellId,text=a.text,extra=M.copy(a.extra or {})};M.move(n,math.min((A.boss.duration or 600),M.absolute(a,A.model.phases)+cd),A.model.phases)
   plan.lines[#plan.lines+1]=n;made[#made+1]=n
  end
 end)
 U.SetMulti(made)
end
function U.MoveLines(list,delta)
 if #list==0 or delta==0 then return end
 local over,minT,maxT={},1e9,-1e9
 for _,a in ipairs(list) do local t=M.absolute(a,A.model.phases);if t then minT=math.min(minT,t);maxT=math.max(maxT,t) end end
 delta=math.min(math.max(delta,-minT),math.max(0,(A.boss.duration or 600)-maxT));if delta==0 then return end
 for _,a in ipairs(list) do local t=M.absolute(a,A.model.phases);if t then over[a]=A.NSRT.round1(t+delta) end end
 if M.movesBad(A.model.plan,A.model.phases,A.CD,over) then A.Message(#list>1 and A.T('drag.backN',{n=#list}) or A.T('drag.back',{t=U.Time(over[list[1]])}));return end
 A.Edit(function() for a,t in pairs(over) do M.move(a,t,A.model.phases) end end)
end
local ALERT_KEYS={DisplayType=true,dur=true,countdown=true,TTS=true,TTSTimer=true,sound=true,glowunit=true,colors=true,text=true}
local function hasAlert(a) for _,kv in ipairs(a.extra or {}) do if ALERT_KEYS[kv[1]] then return true end end end
local function alertText(a) for _,kv in ipairs(a.extra or {}) do if kv[1]=='text' then return kv[2] end end;return a.text end
local function carriesNote(a) return hasAlert(a) or (a.spellId~=nil and a.text~=nil and a.text~='') end
local ALERT_FIELDS={{'DisplayType','addon.display'},{'dur','addon.duration'},{'countdown','addon.countdown'},{'TTS','addon.tts'},{'TTSTimer','addon.ttsTimer'},{'sound','addon.sound'},{'glowunit','addon.glow'},{'colors','addon.color'}}
local function alertFields(a)
 local parts
 for _,fd in ipairs(ALERT_FIELDS) do for _,kv in ipairs(a.extra or {}) do if kv[1]==fd[1] and kv[2]~='' then parts=parts or {};parts[#parts+1]=A.T(fd[2])..' '..kv[2] end end end
 return parts and table.concat(parts,', ')
end
U.CarriesNote=carriesNote
local LANE_W,WINDOW,LANE_X,MARK,CHIP,CARD_W=300,15,72,18,20,420
local NOTE_W,NOTE_MIN=160,28
local LANES={'insp.boss','insp.player','insp.allies'}
local ALLY_CATS={heal=1,raiddr=1,raidmob=1,externals=1,raidutil=1}
local function anchorText(t)
 local best
 for _,ab in ipairs(A.boss.abilities) do if ab.importance=='core' or A.view.showAll then for n,c in ipairs(ab.casts) do if c.start<=t+0.05 and (not best or c.start>best.start) then best={start=c.start,name=ab.name,n=n} end end end end
 if not best then return A.T('anchor.none') end
 local d=string.format('%.1f',math.max(0,t-best.start));if d=='-0.0' then d='0.0' end
 return A.T('anchor',{d=d,spell=best.name,n=best.n})
end
local function inspector(a,t,snappedTo,nowX)
 local f=U.inspector
 if not f then
  f=CreateFrame('Frame',nil,U.window);U.Surface(f,'panel','border',10);f:SetSize(CARD_W,214);f:SetFrameStrata('TOOLTIP');f:EnableMouse(false)
  f.icon=f:CreateTexture(nil,'ARTWORK');f.icon:SetSize(30,30);f.icon:SetPoint('TOPLEFT',12,-12);f.icon:SetTexCoord(0.08,0.92,0.08,0.92)
  f.name=U.Label(f,'',50,-12,14,'textMedium');f.who=U.Label(f,'',50,-30,12,'textMedium')
  f.prev=U.Label(f,'',12,-58,11,'mono');f.prev:SetTextColor(U.Color('ink-2'))
  f.time=U.Label(f,'',0,-52,20,'displayMedium');f.time:ClearAllPoints();f.time:SetPoint('TOP',0,-50)
  f.rel=U.Label(f,'',0,-78,11,'mono');f.rel:ClearAllPoints();f.rel:SetPoint('TOP',0,-76);f.rel:SetTextColor(U.Color('ink-3'))
  f.next=U.Label(f,'',0,-58,11,'mono');f.next:ClearAllPoints();f.next:SetPoint('TOPRIGHT',-12,-58);f.next:SetJustifyH('RIGHT');f.next:SetTextColor(U.Color('ink-2'))
  f.anchor=U.Label(f,'',12,-98,11);f.anchor:SetWidth(396);U.Line(f.anchor);f.anchor:SetTextColor(U.Color('ink-3'))
  f.note=U.Label(f,'',12,-116,12,'textMedium');f.note:SetWidth(396);U.Line(f.note);f.note:SetTextColor(U.Color('ink'))
  f.fields=U.Label(f,'',12,-134,11);f.fields:SetWidth(396);U.Line(f.fields);f.fields:SetTextColor(U.Color('ink-2'))
  f.badge=CreateFrame('Frame',nil,f);U.Surface(f.badge,'ground-3');f.badge:SetHeight(22);f.badge:SetPoint('TOPRIGHT',-12,-14)
  f.badge.text=U.Label(f.badge,'',8,-4,11,'textMedium');f.badge.text:ClearAllPoints();f.badge.text:SetPoint('CENTER')
  f.warn=CreateFrame('Frame',nil,f);U.Surface(f.warn,'ground-3');f.warn:SetHeight(22);f.warn:SetPoint('TOPRIGHT',f.badge,'TOPLEFT',-6,0)
  f.warn.text=U.Label(f.warn,'',8,-4,11,'textMedium');f.warn.text:ClearAllPoints();f.warn.text:SetPoint('CENTER')
  f.pool=U.Pool(f);f.marks={};U.inspector=f
 end
 f.pool:release()
 local cd=A.CD[a.spellId] or {};local ph,offset=M.at(t,A.model.phases)
 local same,prev,nextT={},nil,nil
 for _,b in ipairs(A.model.plan.lines) do if b.tag==a.tag and a.spellId and b.spellId==a.spellId then
  if b~=a then same[#same+1]=b;local bt=absT(b);if bt then if bt<=t then prev=math.max(prev or bt,bt) else nextT=math.min(nextT or bt,bt) end end end
 end end
 local early=0
 if cd.id then local over={[a]=t};for k,v in pairs(U.over or {}) do over[k]=v end;local all={a};for _,b in ipairs(same) do all[#all+1]=b end
  local sim=M.recharge(all,cd,A.model.phases,over);early=sim[a] and sim[a].early or 0 end
 f.icon:SetTexture(a.spellId and U.Icon(a.spellId) or 'Interface\\Icons\\INV_Misc_Note_01')
 f.name:SetText(cd.name or a.text or ('Spell '..tostring(a.spellId)))
 local player;for _,p in ipairs(A.model.plan.roster or {}) do if p.name==a.tag then player=p end end
 f.who:SetText(a.tag);f.who:SetTextColor(U.Color(player and player.classToken and 'class-'..player.classToken or 'ink-2'))
 f.time:SetText(U.Time(t));f.rel:SetText(A.T('inPhase',{t=U.Time(offset),ph=A.T('phaseShort',{id=tostring(ph.id)})}))
 f.prev:SetText(A.T('insp.prev')..'\n'..(prev and U.Time(prev)..'  (-'..U.Time(t-prev)..')' or '-'))
 f.next:SetText(A.T('insp.next')..'\n'..(nextT and U.Time(nextT)..'  (+'..U.Time(nextT-t)..')' or '-'))
 f.anchor:SetText(anchorText(t)..(snappedTo and ', '..A.T('snap.to',{what=snappedTo}) or ''))
 local note=a.spellId and alertText(a) or (alertText(a)~=a.text and alertText(a)) or nil
 local fields=alertFields(a)
 local laneTop=122
 f.note:SetShown(note~=nil and note~='');f.fields:SetShown(fields~=nil)
 if note and note~='' then f.note:ClearAllPoints();f.note:SetPoint('TOPLEFT',12,-(laneTop-6));f.note:SetText('"'..note..'"');laneTop=laneTop+18 end
 if fields then f.fields:ClearAllPoints();f.fields:SetPoint('TOPLEFT',12,-(laneTop-6));f.fields:SetText(fields);laneTop=laneTop+18 end
 f:SetHeight(laneTop+92)
 if early>0.05 then U.Surface(f.badge,'tl-conflict','tl-conflict');f.badge.text:SetTextColor(U.Color('ground'));f.badge.text:SetText(A.T('addon.early',{n=math.max(1,math.floor(early+0.5))}))
 elseif cd.id and (cd.cooldown or 0)>0 then U.Surface(f.badge,'kill','kill');f.badge.text:SetTextColor(U.Color('ground'));f.badge.text:SetText(A.T('addon.ready'))
 else f.badge.text:SetText('') end
 f.badge:SetShown(f.badge.text:GetText()~='');f.badge:SetWidth(f.badge.text:GetUnboundedStringWidth()+18)
 local warn
 if nextT and cd.cooldown and cd.cooldown>0 and nextT-t<cd.cooldown then warn=A.T('insp.toNext',{n=math.max(1,math.floor(nextT-t+0.5))})
 elseif cd.cooldown and cd.cooldown>0 then local others={};for _,b in ipairs(same) do local bt=absT(b);if bt then others[#others+1]={t=bt} end end
  local ps=M.preStart(cd,t,others);if ps then warn=A.T('pre.note',{n=math.max(1,math.floor(t-ps+0.5))}) end end
 f.warn:SetShown(warn~=nil);if warn then f.warn.text:SetText(warn);f.warn:SetWidth(f.warn.text:GetUnboundedStringWidth()+18) end
 nowX=nowX or (LANE_X+LANE_W/2)
 local laneL,laneR=LANE_X,math.min(CARD_W-12,math.max(LANE_X+LANE_W,nowX+8))
 local function px(bt) return nowX+(bt-t)/(WINDOW*2)*LANE_W end
 local function inLanes(bt) local v=px(bt);return v>=laneL and v<=laneR end
 local marks=f.marks;local n=0
 local function add(bt,icon,color)
  n=n+1;local m=marks[n];if not m then m={};marks[n]=m end;m.t=bt;m.icon=icon;m.color=color
 end
 for i,key in ipairs(LANES) do
  local y=laneTop+(i-1)*28;local cy=y+11;n=0
  local rail=f.pool:get();rail:SetPoint('TOPLEFT',laneL,-cy);rail:SetSize(laneR-laneL,1);U.Radius(rail,0);rail:SetBackdropColor(U.Color('line'));rail:SetBackdropBorderColor(0,0,0,0);rail:EnableMouse(false)
  local label=f.pool:get();label:SetPoint('TOPLEFT',12,-y);label:SetSize(LANE_X-16,22);label:SetBackdrop(nil);label:EnableMouse(false)
  label.text:ClearAllPoints();label.text:SetPoint('LEFT',0,0);label.text:SetJustifyH('LEFT');label.text:SetText(A.T(key));label.text:SetTextColor(U.Color('ink-3'));U.Font(label.text,11,'textMedium')
  if i==1 then
   for _,ab in ipairs(A.boss.abilities) do if ab.importance=='core' or A.view.showAll then for _,c in ipairs(ab.casts) do if inLanes(c.start) then add(c.start,U.Icon(c.spell),'tl-cat-'..(ab.category or 'event')) end end end end
  else
   for _,b in ipairs(A.model.plan.lines) do if b~=a then local bt=absT(b)
    if bt and inLanes(bt) then
     if i==2 and b.tag==a.tag then add(bt,U.Icon(b.spellId),'ink-2')
     elseif i==3 and b.tag~=a.tag and b.spellId and A.CD[b.spellId] and ALLY_CATS[A.CD[b.spellId].cat] then
      local q;for _,p in ipairs(A.model.plan.roster or {}) do if p.name==b.tag then q=p end end;add(bt,U.Icon(b.spellId),q and q.classToken and 'class-'..q.classToken or 'info') end
    end
   end end
  end
  for k=2,n do local m=marks[k];local j=k-1;while j>=1 and marks[j].t>m.t do marks[j+1]=marks[j];j=j-1 end;marks[j+1]=m end
  local k=1
  while k<=n do
   local m=marks[k];local x0=px(m.t);local last=k
   while last<n and px(marks[last+1].t)<x0+MARK+(last>k and CHIP+2 or 0)+2 do last=last+1 end
   local ic=f.pool:get();ic:EnableMouse(false);ic:SetFrameLevel(f:GetFrameLevel()+4);ic:SetSize(MARK,MARK);ic:SetPoint('TOPLEFT',x0-MARK/2,-(cy-MARK/2))
   ic:SetBackdropColor(U.Color('panel'));ic:SetBackdropBorderColor(U.ColorA(m.color,0.9));ic.icon:SetTexture(m.icon);ic.icon:ClearAllPoints();ic.icon:SetPoint('CENTER');ic.icon:SetSize(MARK-2,MARK-2);ic.icon:Show()
   if last>k then
    for j=k+1,last do local tk=f.pool:get();tk:EnableMouse(false);tk:SetFrameLevel(f:GetFrameLevel()+3);U.Radius(tk,0);tk:SetSize(2,6);tk:SetPoint('TOPLEFT',px(marks[j].t)-1,-(cy+MARK/2-1));tk:SetBackdropColor(U.ColorA(marks[j].color,0.9));tk:SetBackdropBorderColor(0,0,0,0) end
    local chip=f.pool:get();chip:EnableMouse(false);chip:SetFrameLevel(f:GetFrameLevel()+5);U.Radius(chip,3);chip:SetSize(CHIP,14);chip:SetPoint('LEFT',ic,'RIGHT',1,0)
    chip:SetBackdropColor(U.Color('ground-3'));chip:SetBackdropBorderColor(U.Color('line'))
    chip.text:ClearAllPoints();chip.text:SetPoint('CENTER',0,0);chip.text:SetJustifyH('CENTER');U.Font(chip.text,10,'mono');chip.text:SetTextColor(U.Color('ink-2'));chip.text:SetText('+'..(last-k))
   end
   k=last+1
  end
 end
 f.nowX=nowX
 local center=f.pool:get();center:SetPoint('TOPLEFT',nowX-1,-(laneTop-4));center:SetSize(2,86);center:SetBackdropColor(U.Color('tl-scrub'));center:SetBackdropBorderColor(0,0,0,0);center:EnableMouse(false);center:SetFrameLevel(f:GetFrameLevel()+6)
 f:Show()
end
function U.CancelDrag()
 U.drag=nil;U.box=nil;U.over=nil;U.overKeys=nil;U.press=nil
 if U.driver then U.driver:SetScript('OnUpdate',nil);U.driver:Hide() end
 if U.inspector then U.inspector:Hide() end
 if U.marquee then U.marquee:Hide() end
 if U.bulkChip then U.bulkChip:Hide() end
end
local HEAD,AXIS,LANE,KICK_H,GAP=20,18,22,34,6
local function ROW() return A.db.compact and 20 or 26 end
local function PHEAD() return A.db.compact and 22 or 30 end
local function classKey(p) return p and p.classToken and 'class-'..p.classToken or 'info' end
local function rowHeight(row) return row.gap and GAP or row.header and PHEAD() or ROW() end
local function layoutRows(all)
 local y=0;for _,row in ipairs(all) do row.y=y;y=y+rowHeight(row) end;return y
end
local function maxScroll(total) return math.max(0,total-U.playerCanvas:GetHeight()+8) end
local EMPTY={}
local function hideTip() GameTooltip:Hide() end
local function gutterEnter(self) U.SpellTip(self,self.dpSpell) end
local function trackDown(self,button) local boss=self.dpBoss;if button~='LeftButton' or boss then U.BeginPan(button,boss) end end
local function gutter(pool,y,h,label,icon,dot,color,font,spellId)
 local g=pool:get();g:SetPoint('TOPLEFT',0,-y);g:SetSize(labelWidth-6,h);g:SetBackdrop(nil);g:EnableMouse(spellId~=nil)
 local tx=10
 if icon then g.icon:SetTexture(icon);g.icon:ClearAllPoints();g.icon:SetPoint('LEFT',10,0);g.icon:SetSize(16,16);g.icon:Show();tx=32 end
 if dot then g.icon:SetColorTexture(U.Color(dot));g.icon:ClearAllPoints();g.icon:SetPoint('LEFT',12,0);g.icon:SetSize(7,7);g.icon:Show();tx=26 end
 g.text:ClearAllPoints();g.text:SetPoint('LEFT',tx,0);g.text:SetWidth(labelWidth-tx-14);U.Font(g.text,12,font or 'textMedium');g.text:SetTextColor(U.Color(color or 'ink'));g.text:SetText(label)
 if spellId then g.dpSpell=spellId;g:SetScript('OnEnter',gutterEnter);g:SetScript('OnLeave',hideTip) end
 return g
end
local function track(pool,y,h,index,level)
 local t=pool:get();t.dpBoss=(pool==U.bossPool);t:SetScript('OnMouseDown',trackDown);t:SetPoint('TOPLEFT',0,-y);t:SetSize(U.canvas:GetWidth(),h);U.Radius(t,0);t:SetBackdropBorderColor(0,0,0,0)
 t:SetBackdropColor(U.ColorA('ink',index%2==0 and 0.025 or 0));if level then t:SetFrameLevel(level) end;return t
end
local function tile(b,icon,ring,size)
 U.Radius(b,3);b:SetBackdropColor(U.Color('ground'));b:SetBackdropBorderColor(U.Color(ring))
 b.icon:SetTexture(icon);b.icon:ClearAllPoints();b.icon:SetPoint('TOPLEFT',1,-1);b.icon:SetSize(size-2,size-2);b.icon:Show()
end
local function rowLinesRaw(row)
 local out={}
 for _,a in ipairs(A.model.plan.lines) do
  if row.everyone then
   if raidTag(a.tag) then
    if row.personals then if not a.spellId and a.text=='Personals' then out[#out+1]=a end
    elseif row.other then if not a.spellId and a.text~='Personals' then out[#out+1]=a end
    elseif a.spellId==row.spell.id then out[#out+1]=a end
   end
  elseif hasName(a.tag,row.player.name) then
   if row.other then if not a.spellId then out[#out+1]=a end
   elseif a.spellId==row.spell.id then out[#out+1]=a end
  end
 end
 return out
end
local function rowLines(row)
 local m=memoNow();local v=m.lines[row]
 if not v then v=rowLinesRaw(row);m.lines[row]=v end
 return v
end
U.RowLines=rowLines
local NOTE='Interface\\Icons\\INV_Misc_Note_01'
local function place(row,t)
 local ph,offset=M.at(t,A.model.phases);offset=A.NSRT.round1(offset)
 if row.everyone then
  if row.other then U.AssignmentEditor({phase=tostring(ph.id),time=offset,tag='everyone',extra={}},true);return end
  A.Edit(function(plan) plan.lines[#plan.lines+1]={phase=tostring(ph.id),time=offset,tag='everyone',spellId=not row.personals and row.spell.id or nil,text=row.personals and 'Personals' or nil,extra={}} end);return
 end
 if row.other then U.AssignmentEditor({phase=tostring(ph.id),time=offset,tag=row.player.name,extra={}},true);return end
 A.Edit(function(plan) local a={phase=tostring(ph.id),time=offset,tag=row.player.name,spellId=row.spell.id,extra={}};plan.lines[#plan.lines+1]=a;U.selLine=a end)
end
local function snapped(raw,moves)
 if not IsShiftKeyDown() then return math.max(0,math.floor(raw+0.5)) end
 local tol=40/math.max(0.01,perSecond());local best,bd,what=nil,tol,nil
 local function ok(t) return not moves or not M.movesBad(A.model.plan,A.model.phases,A.CD,moves(t)) end
 for _,ab in ipairs(A.boss.abilities) do if ab.importance=='core' or A.view.showAll then for n,c in ipairs(ab.casts) do local d=math.abs(c.start-raw);if d<bd and ok(c.start) then bd=d;best=c.start;what=ab.name..' #'..n end end end end
 for _,p in ipairs(A.model.phases) do local d=math.abs(p.start-raw);if d<bd and ok(p.start) then bd=d;best=p.start;what=A.T('snap.phase',{id=tostring(p.id)}) end end
 for _,e in ipairs(U.drag and U.drag.edges or {}) do local d=math.abs(e-raw);if e>=0 and d<bd and ok(e) then bd=d;best=e;what=A.T('snap.ready') end end
 if best then return A.NSRT.round1(best),what end
 return math.max(0,math.floor(raw+0.5))
end
local function startDrag(a,t,dt)
 if not A.Allowed() or U.drag then return end
 local group
 if U.multi[a] and multiCount()>1 then group={};for b in pairs(U.multi) do group[#group+1]=b end
 else if not U.multi[a] then U.multi={} end;U.selLine=a end
 local base={};for _,b in ipairs(group or {a}) do base[b]=M.absolute(b,A.model.phases) end
 local skip=group and base or nil
 U.drag={a=a,group=group,base=base,t0=t,t=t,dt=dt or timeAt()-t,edges=M.readyEdges(A.model.plan,A.model.phases,a,A.CD,skip)}
 if U.tipOwner then GameTooltip:Hide() end
 local function moves(nt)
  local o={};local d=nt-U.drag.t0;for b,bt in pairs(U.drag.base) do o[b]=math.max(0,A.NSRT.round1(bt+d)) end;return o
 end
 local function step()
  local d=U.drag
  if not A.Allowed() or not d then U.CancelDrag();U.RequestDraw();return end
  if not IsMouseButtonDown('LeftButton') then
   local over=U.over;U.CancelDrag();U.justDragged=true;C_Timer.After(0.1,function() U.justDragged=nil end)
   if d.moved and over then
    if M.movesBad(A.model.plan,A.model.phases,A.CD,over) then
     A.Message(d.group and A.T('drag.backN',{n=#d.group}) or A.T('drag.back',{t=U.Time(over[d.a])}));U.Render()
    else A.Edit(function() for b,bt in pairs(over) do M.move(b,bt,A.model.phases) end end);if d.group then U.SetMulti(d.group) end end
   else U.RequestDraw() end
   return
  end
  local raw=timeAt()-d.dt;local px,shift=math.floor(x(raw)),IsShiftKeyDown() and true or false
  local nt,what
  if d.px==px and d.shift==shift and d.moved then nt,what=d.snapT,d.what else nt,what=snapped(raw,moves);d.px,d.shift,d.snapT=px,shift,nt end
  if d.group then
   local lo,hi=1e9,-1e9;for _,bt in pairs(d.base) do lo=math.min(lo,bt);hi=math.max(hi,bt) end
   local delta=math.min(math.max(nt-d.t0,-lo),math.max(0,(A.boss.duration or 600)-hi));nt=A.NSRT.round1(d.t0+delta)
  end
  if nt==d.t and d.moved then return end
  d.t=nt;d.moved=true;U.over=moves(nt);U.overKeys=M.overrideKeys(U.over)
  U.MoveScrub(x(nt),nt);U.DrawPlayers()
  if d.group then
   local chip=U.bulkChip;if not chip then chip=CreateFrame('Frame',nil,U.window);U.Surface(chip,'ink','ink',4);chip:SetHeight(22);chip:SetFrameStrata('TOOLTIP');chip.text=U.Label(chip,'',8,-4,12,'textMedium');chip.text:SetTextColor(U.Color('ground'));U.bulkChip=chip end
   local delta=nt-d.t0;chip.text:SetText(A.T('addon.bulkDelta',{n=#d.group,d=(delta>=0 and '+' or '-')..string.format('%.1f',math.abs(delta)):gsub('%.0$','')}))
   chip:SetWidth(chip.text:GetUnboundedStringWidth()+16);local cx,cy=GetCursorPosition();local s=chip:GetEffectiveScale();chip:ClearAllPoints();chip:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',cx/s+14,cy/s+10);chip:Show()
  else d.what=what end
 end
 U.driver:SetScript('OnUpdate',step)
 U.driver:Show()
 if dt then step() end
end
local PRESS_PX=3
local function pressWatch()
 local p=U.press
 if not p or U.drag or not A.Allowed() or not IsMouseButtonDown('LeftButton') then U.press=nil;if not U.drag then U.driver:SetScript('OnUpdate',nil);U.driver:Hide() end;return end
 local cx,cy=GetCursorPosition();local s=U.playerCanvas:GetEffectiveScale()
 if math.abs(cx-p.x)/s>=PRESS_PX or math.abs(cy-p.y)/s>=PRESS_PX then U.press=nil;startDrag(p.a,p.t,p.dt) end
end
U.PressWatch=pressWatch
local function startBox(row)
 if not A.Allowed() then return end
 local x0,y0=cursorLocal();local add=IsControlKeyDown();local base={};if add then for a in pairs(U.multi) do base[#base+1]=a end end
 U.box={x0=x0,y0=y0,moved=false}
 local m=U.marquee;if not m then m=CreateFrame('Frame',nil,U.playerCanvas);U.Surface(m,'tl-sel','tl-sel',3);m:SetBackdropColor(U.ColorA('tl-sel',0.08));m:SetFrameLevel(U.playerCanvas:GetFrameLevel()+20);m:EnableMouse(false);U.marquee=m end
 U.driver:SetScript('OnUpdate',function()
  local b=U.box;if not b or not A.Allowed() then U.CancelDrag();return end
  local cx,cy=cursorLocal()
  if not IsMouseButtonDown('LeftButton') then
   U.CancelDrag()
   if not b.moved and row and not U.justDragged then
    local t=A.NSRT.round1(timeAt());if IsShiftKeyDown() then t=snapped(t) end
    if t>=0 and x(t)>=labelWidth then U.ClearSelection();place(row,t) end
   end
   U.SyncSelbar();U.RequestPlayers();return
  end
  if math.abs(cx-b.x0)>3 or math.abs(cy-b.y0)>3 then b.moved=true end
  if not b.moved then return end
  local l,r,t,bt=math.min(b.x0,cx),math.max(b.x0,cx),math.min(b.y0,cy),math.max(b.y0,cy)
  m:ClearAllPoints();m:SetPoint('TOPLEFT',l,-t);m:SetSize(math.max(1,r-l),math.max(1,bt-t));m:Show()
  local set={};for _,a in ipairs(base) do set[a]=true end
  for _,f in ipairs(U.playerPool.used) do if f.data and f.box then local fx,fy,fs=f.box[1],f.box[2],f.box[3];if fx<=r and fx+fs>=l and fy<=bt and fy+fs>=t then set[f.data]=true end end end
  U.multi=set;U.selLine=nil;U.SyncSelbar();U.RequestPlayers()
 end)
 U.driver:Show()
end
local function castMenu(anchor,a)
 local sel=U.multi[a] and multiCount()>1 and U.Selected() or {a}
 local items={{#sel>1 and A.T('addon.nCasts',{n=#sel}) or ((A.CD[a.spellId] or {}).name or a.text or ''),nil,title=true}}
 if #sel==1 then items[#items+1]={A.T('ctx.alert'),function() U.AssignmentEditor(a,false) end} end
 items[#items+1]={A.T('ctx.sameSpell'),function() local list={};for _,b in ipairs(A.model.plan.lines) do if b.tag==a.tag and (a.spellId and b.spellId==a.spellId or (not a.spellId and not b.spellId and b.text==a.text)) then list[#list+1]=b end end;U.SetMulti(list) end}
 for _,d in ipairs({-5,-1,1,5}) do items[#items+1]={A.T('addon.nudge',{d=(d>0 and '+' or '')..d}),function() U.MoveLines(sel,d) end} end
 items[#items+1]={A.T('ctx.dup'),function() U.DuplicateLines(sel) end}
 items[#items+1]={'',nil,divider=true}
 items[#items+1]={A.T('ctx.del'),function() U.RemoveLines(sel) end}
 U.Menu(anchor,items)
end
local function rowMenu(row,t)
 local items={{U.Time(t),nil,title=true}}
 if row and row.spell then items[#items+1]={A.T('addon.addHere'),function() place(row,t) end} end
 if row then items[#items+1]={A.T('ctx.rowAll'),function() U.SetMulti(rowLines(row)) end} end
 if multiCount()>0 then items[#items+1]={A.T('ctx.clear'),function() U.ClearSelection();U.RequestDraw() end} end
 items[#items+1]={A.T('ctx.keys'),function() U.Shortcuts() end}
 U.Menu(U.playerCanvas,items)
end
local function tileClick(self,button)
 local a=self.data;if not a or not A.Allowed() or U.justDragged or U.drag then return end
 if button=='RightButton' then
  if IsAltKeyDown() then U.AssignmentEditor(a,false)
  elseif IsShiftKeyDown() then castMenu(self,a)
  elseif U.multi[a] and multiCount()>1 then U.RemoveLines(U.Selected())
  else U.RemoveLines({a},true);A.Message(A.T('addon.removedN',{n=1})) end
  return
 end
 if IsControlKeyDown() and IsShiftKeyDown() then
  local set={};for b2 in pairs(U.multi) do set[#set+1]=b2 end;if U.selLine then set[#set+1]=U.selLine end
  for _,o in ipairs(A.model.plan.lines) do if o.tag==a.tag and (a.spellId and o.spellId==a.spellId or (not a.spellId and not o.spellId and o.text==a.text)) then set[#set+1]=o end end
  U.SetMulti(set)
 elseif IsControlKeyDown() then
  if multiCount()==0 and U.selLine then U.multi[U.selLine]=true end
  U.multi[a]=not U.multi[a] or nil;U.selLine=nil;U.SyncSelbar();U.RequestPlayers()
 else U.multi={};U.selLine=a;U.SyncSelbar();U.RequestPlayers() end
end
local function tileDouble(self) if A.Allowed() and self.data then U.AssignmentEditor(self.data,false) end end
local function tileEnter(self) if U.drag or U.box or not self.data then return end;U.hoverTile=self.data;U.ShowInspector(self.data,self.dpT,self) end
local function tileLeave() if U.drag or U.box then return end;U.hoverTile=nil;if U.inspector then U.inspector:Hide() end end
local function tileDown(self,button)
 if button~='LeftButton' or not self.data or U.drag or U.box or not A.Allowed() then return end
 local cx,cy=GetCursorPosition();U.press={a=self.data,t=self.dpT,x=cx,y=cy,dt=timeAt()-self.dpT}
 U.driver:SetScript('OnUpdate',pressWatch);U.driver:Show()
end
local function tileDrag(self) if self.data and not U.drag then local p=U.press;U.press=nil;startDrag(self.data,self.dpT,p and p.a==self.data and p.dt or nil) end end
local function rowDown(self,button)
 local row=self.row
 if not A.Allowed() or U.drag then return end
 if button=='LeftButton' then if select(1,cursorLocal())>=labelWidth then startBox(row) end
 else U.BeginPan(button,false,function() rowMenu(row,A.NSRT.round1(math.max(0,timeAt()))) end) end
end
local function windowEnter(self) local w=self.dpWin;U.Tooltip(self,self.dpName..'  '..U.Time(w.start)..' - '..U.Time(w['end'])..'\n'..U.CoverText(self.dpHit)) end
local function clusterText(self)
 local list,from,to=self.dpList,self.dpFrom,self.dpTo
 if not list or not to or to<=from then return '' end
 local parts={};for j=from+1,to do parts[#parts+1]=U.Time(list[j].start) end
 return A.T('cl.more',{n=to-from,list=table.concat(parts,', ')})..'\n'
end
local function chipEnter(self) local c,hit=self.dpCast,self.dpHit;U.SpellTip(self,c.spell,self.dpName..'  '..U.Time(c.start)..'  #'..self.dpN,clusterText(self)..(hit and U.CoverText(hit)..'\n' or '')..A.T('addon.rightClickAlert')) end
local function chipClick(self,button) if button=='RightButton' and A.Allowed() then U.BossContext(self.dpCast.start,self.dpName) end end
local drawPlayers
function U.DrawPlayers() return drawPlayers() end
drawPlayers=function()
 local pool=U.playerPool;pool:release()
 local all=(not U.rowsDirty and U.rowsCache) or rows();if all~=U.rowsCache then U.rowsTotal=layoutRows(all) end
 U.rowsCache=all;U.rowsDirty=false;U.visibleRows=all
 local height=U.playerCanvas:GetHeight();local top=math.max(0,math.min(A.view.scrollY or 0,maxScroll(U.rowsTotal or 0)));A.view.scrollY=top
 local base=U.playerCanvas:GetFrameLevel();local width=U.canvas:GetWidth();local compact=A.db.compact
 local mm=memoNow()
 if not mm.bad then mm.bad=M.conflicts(A.model.plan,A.model.phases,A.CD) end
 if U.over then
  local keys=U.overKeys or M.overrideKeys(U.over);local bad=M.conflicts(A.model.plan,A.model.phases,A.CD,U.over,keys)
  for a2,v in pairs(mm.bad) do if not (a2.spellId and keys[a2.tag..'|'..a2.spellId]) then bad[a2]=v end end
  U.bad=bad
 else U.bad=mm.bad end
 if not mm.live then mm.live={};for _,b in ipairs(A.model.plan.lines) do mm.live[b]=true end end
 if U.selLine and not mm.live[U.selLine] then U.selLine=nil end
 for a in pairs(U.multi) do if not mm.live[a] then U.multi[a]=nil end end
 local many=multiCount()>1
 local alt=0
 for i,row in ipairs(all) do
  local h=rowHeight(row);local y=row.y-top
  if not row.gap then alt=alt+1 end
  if not row.gap and y+h>=0 and y<=height then
   local p=row.player
   if row.header then
    local key=row.everyone and 'ink-2' or classKey(p)
    local band=track(pool,y,h,0,base+1);band:SetBackdropColor(U.ColorA(key,(row.everyone or p.active) and 0.07 or 0.03))
    if U.flash and p and U.flash.name==p.name then band:SetBackdropColor(U.ColorA('warm-4',0.22)) end
    local name=row.everyone and A.T('ev.name') or p.name
    local pill=pool:get();pill:SetPoint('LEFT',band,'LEFT',8,0);pill:SetHeight(compact and 18 or 20);pill:SetFrameLevel(base+3);U.Radius(pill,4)
    pill:SetBackdropColor(U.ColorA(key,row.everyone and 0.35 or (p.active and 0.9 or 0.45)));pill:SetBackdropBorderColor(0,0,0,0)
    pill.icon:SetTexture(row.everyone and 'Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend' or U.SpecIcon(p.specId,p.classToken));pill.icon:ClearAllPoints();pill.icon:SetPoint('LEFT',2,0);pill.icon:SetSize(16,16);pill.icon:Show()
    pill.text:ClearAllPoints();pill.text:SetPoint('LEFT',22,0);U.Font(pill.text,12,'textMedium');pill.text:SetTextColor(U.Color(row.everyone and 'ink' or 'ground'));pill.text:SetText(name)
    pill:SetWidth(math.min(labelWidth-58,pill.text:GetUnboundedStringWidth()+30))
    if not row.everyone then pill:SetScript('OnClick',function(b,button) if button=='RightButton' and U.PlayerMenu then U.PlayerMenu(b,p) else U.Spells(b,p) end end)
     pill:SetScript('OnEnter',function(self) U.Tooltip(self,p.name..'\n|cff8a7f8d'..A.T('addon.pillTip')..'|r') end);pill:SetScript('OnLeave',function() GameTooltip:Hide() end) end
    local ckey=row.everyone and '@everyone' or p.name
    local caret=pool:get();caret:SetSize(20,20);caret:SetPoint('LEFT',band,'LEFT',labelWidth-30,0);caret:SetFrameLevel(base+3);U.Radius(caret,4);caret:SetBackdropColor(0,0,0,0);caret:SetBackdropBorderColor(0,0,0,0)
    caret.text:ClearAllPoints();caret.text:SetPoint('CENTER');caret.text:SetJustifyH('CENTER');U.Font(caret.text,12,'textMedium');caret.text:SetTextColor(U.Color('ink-3'));caret.text:SetText(A.view.collapsed[ckey] and '+' or '-')
    caret:SetScript('OnClick',function() if IsAltKeyDown() then U.FoldAll(not A.view.collapsed[ckey]) else A.view.collapsed[ckey]=not A.view.collapsed[ckey] or nil;U.rowsDirty=true;U.DrawTimeline();A.Save() end end)
    caret:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));U.Tooltip(self,A.T(A.view.collapsed[ckey] and 'blk.show' or 'blk.hide',{name=name})..'\n|cff8a7f8d'..A.T('alt.all')..'|r') end);caret:SetScript('OnLeave',function(self) self:SetBackdropColor(0,0,0,0);GameTooltip:Hide() end)
    if not row.everyone then
     local eye=pool:get();eye:SetSize(20,20);eye:SetPoint('RIGHT',caret,'LEFT',-2,0);eye:SetFrameLevel(base+3);U.Radius(eye,4);eye:SetBackdropColor(0,0,0,0);eye:SetBackdropBorderColor(0,0,0,0)
     U.Eye(eye)
     eye:SetScript('OnClick',function() if IsAltKeyDown() then U.SoloRail(p.name) else U.SetHidden(p.name,true);A.Message(A.T('addon.hiddenOne',{name=p.name})) end end)
     eye:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));U.Tooltip(self,A.T('rail.hide',{name=p.name})) end);eye:SetScript('OnLeave',function(self) self:SetBackdropColor(0,0,0,0);GameTooltip:Hide() end)
    end
    local count=mm.count[row];if not count then count=0;for _,a in ipairs(A.model.plan.lines) do if row.everyone and raidTag(a.tag) or (p and hasName(a.tag,p.name)) then count=count+1 end end;mm.count[row]=count end
    local spec=p and A.SpecByID[p.specId]
    local info=pool:get();info:SetPoint('LEFT',band,'LEFT',labelWidth+8,0);info:SetSize(420,20);info:SetBackdrop(nil);info:EnableMouse(false);info:SetFrameLevel(base+3)
    U.Font(info.text,11);info.text:SetTextColor(U.Color('ink-3'))
    info.text:SetText(row.everyone and A.T('ev.sub',{n=count}) or ((spec and spec.name..' '..(spec.className or '') or '')..'   '..A.T('addon.cds',{n=count})..(p.active and '' or '   '..A.T('blk.bench'))))
   else
    local spell=row.spell;local assignments=rowLines(row)
    local key=row.everyone and 'ink-2' or classKey(p);local dim=p and not p.active
    local touched=false;if U.over then for k=1,#assignments do if U.over[assignments[k]] then touched=true;break end end end
    local rd=not touched and mm.data[row]
    if not rd then
     local list={};for _,a in ipairs(assignments) do local t=absT(a);if t then list[#list+1]={a=a,t=t} end end
     table.sort(list,function(m,n) return m.t<n.t end)
     rd={list=list,sim=spell.id and A.CD[spell.id] and M.recharge(assignments,spell,A.model.phases,U.over) or {}}
     if not touched then mm.data[row]=rd end
    end
    local list,sim=rd.list,rd.sim
    local rowBad=false;for _,it in ipairs(list) do if U.bad[it.a] then rowBad=true end end
    local bg=track(pool,y,h,alt,base+1);if rowBad then bg:SetBackdropColor(U.ColorA('tl-conflict',0.1)) end
    local hasSel=false;for _,it in ipairs(list) do if U.multi[it.a] or U.selLine==it.a then hasSel=true end end
    local g=gutter(pool,y,h,spell.name,spell.icon and U.Icon(spell.icon) or spell.id and U.Icon(spell.id) or nil,nil,row.other and 'ink-3' or (#list>0 and 'ink' or 'ink-2'),#list>0 and 'textMedium' or 'text',spell.id)
    g:SetFrameLevel(base+2);if hasSel then g:SetBackdrop(true);g:SetBackdropColor(U.ColorA('tl-sel',0.1));g:SetBackdropBorderColor(0,0,0,0) end
    if row.off then g.text:SetTextColor(U.Color('ink-3')) end
    bg:EnableMouse(true);bg.row=row
    bg:SetScript('OnMouseDown',rowDown)
    for idx,it in ipairs(list) do
     local a,t=it.a,it.t
     local bad=U.bad[a];local sel=U.multi[a] or U.selLine==a;local res=sim[a] or EMPTY
     local alpha=(dim and 0.4 or 1)*((many and not sel) and 0.6 or 1)
     local cd=spell.id and A.CD[spell.id]
     if cd and (cd.cooldown or 0)>0 and visible(t-(cd.cooldown or 0)*(cd.charges or 1),t) then
      local ps=not touched and mm.pre[a]
      if ps==nil or touched then
       local others={};for _,o in ipairs(list) do if o.a~=a then others[#others+1]={t=o.t} end end
       ps=M.preStart(cd,t,others) or false;if not touched then mm.pre[a]=ps end
      end
      if ps then local band=rect(pool,ps,t,y+(h-16)/2+3,10,bad and 'tl-conflict' or key);if band then U.Radius(band,3);band:SetBackdropColor(U.ColorA(bad and 'tl-conflict' or key,0.16));band:SetBackdropBorderColor(U.ColorA(sel and 'tl-sel' or (bad and 'tl-conflict' or key),sel and 0.85 or 0.5));band:EnableMouse(false);band:SetFrameLevel(base+2);band:SetAlpha(alpha) end end
     end
     if compact and cd then
      local cdT=(cd.cooldown or 0)>0 and cd.cooldown or (cd.duration or 0);local free=(res.max or 1)>1 and (res.left or 0)>0 and not bad
      local busy=rect(pool,t,t+cdT,y+1,h-2,bad and 'tl-conflict' or key);if busy then U.Radius(busy,0);busy:SetBackdropColor(U.ColorA(bad and 'tl-conflict' or key,free and 0.3 or 0.6));busy:SetBackdropBorderColor(U.ColorA('tl-sel',sel and 1 or 0));busy:EnableMouse(false);busy:SetFrameLevel(base+2);busy:SetAlpha(alpha) end
      if (cd.duration or 0)>0 then local act=rect(pool,t,t+cd.duration,y+1,h-2,key);if act then U.Radius(act,0);act:SetBackdropColor(U.ColorA(bad and 'tl-conflict' or key,0.85));U.Hatch(act,'ground',0.45);act:EnableMouse(false);act:SetFrameLevel(base+3);act:SetAlpha(alpha) end end
     else
      if res.back and not bad and res.back>t then
       local r=rect(pool,t,res.back,y+(h-16)/2+3,10,key)
       if r then U.Radius(r,3);r:SetBackdropColor(U.ColorA(key,0.08));r:SetBackdropBorderColor(0,0,0,0);U.Hatch(r,key,0.5);r:EnableMouse(false);r:SetFrameLevel(base+2);r:SetAlpha(alpha) end
      end
      if (spell.duration or 0)>0 then
       local d=rect(pool,t,t+spell.duration,y+(h-16)/2+2,12,key);if d then U.Radius(d,3);d:SetBackdropColor(U.ColorA(key,0.45));d:SetBackdropBorderColor(U.ColorA('tl-sel',sel and 1 or 0));d:EnableMouse(false);d:SetFrameLevel(base+3);d:SetAlpha(alpha) end
      end
     end
     if visible(t,t+1) then
      local size=compact and h-4 or 18;local b=pool:get();b:SetSize(size,size);b:SetPoint('TOPLEFT',x(t),-(y+(h-size)/2))
      tile(b,a.spellId and U.Icon(a.spellId) or (row.personals and U.Icon(PERS_ICON)) or NOTE,bad and 'tl-conflict' or (sel and 'tl-sel' or key),size)
      b:SetFrameLevel(base+5);b.rowY=y;b.data=a;local bx=b.dpBox or {};bx[1],bx[2],bx[3]=x(t),y+(h-size)/2,size;b.dpBox=bx;b.box=bx;b:SetAlpha(alpha)
      if sel then local ring=pool:get();ring:SetSize(size+6,size+6);ring:SetPoint('CENTER',b,'CENTER');U.Radius(ring,4);ring:SetBackdropColor(0,0,0,0);ring:SetBackdropBorderColor(U.Color('tl-sel'));ring:EnableMouse(false);ring:SetFrameLevel(base+4) end
      if carriesNote(a) then local dot=pool:get();dot:SetSize(8,8);dot:SetPoint('CENTER',b,'TOPLEFT',2,-2);U.Radius(dot,4);dot:SetBackdropColor(U.Color('accent'));dot:SetBackdropBorderColor(U.Color('ground'));dot:EnableMouse(false);dot:SetFrameLevel(base+6);dot:SetAlpha(alpha) end
      local label=alertText(a);if row.everyone and a.tag~='everyone' then label=a.tag..(label and label~='' and ': '..label or '') end
      if label and label~='' and label~='Personals' and not compact then
       local nx=list[idx+1] and x(list[idx+1].t)
       local left=x(t)+size+3;local room=math.min(NOTE_W,(nx or 1e9)-left-3)
       if room>=NOTE_MIN then
        local lbl=pool:get();lbl:SetPoint('LEFT',b,'RIGHT',3,0);lbl:SetSize(room,16);U.Radius(lbl,3);lbl:SetBackdropColor(U.Color('ground-2'));lbl:SetBackdropBorderColor(U.Color('line'));lbl:EnableMouse(false);lbl:SetFrameLevel(base+4)
        U.Font(lbl.text,11,'textMedium');lbl.text:SetTextColor(U.Color('ink'));lbl.text:ClearAllPoints();lbl.text:SetPoint('LEFT',5,0);lbl.text:SetWidth(room-10);lbl.text:SetText(label);lbl:SetAlpha(alpha)
       end
      end
      if (res.max or 1)>1 and not bad and res.left then local c=pool:get();c:SetSize(11,11);c:SetPoint('TOPLEFT',b,'TOPRIGHT',-6,4);U.Radius(c,3);c:SetBackdropColor(U.Color('ground'));c:SetBackdropBorderColor(U.Color(key));c:EnableMouse(false);c:SetFrameLevel(base+6)
       c.text:ClearAllPoints();c.text:SetPoint('CENTER',0,0);c.text:SetJustifyH('CENTER');U.Font(c.text,9,'textMedium');c.text:SetText(tostring(res.left)) end
      b.dpT=t;b.dpRow=row
      b:SetScript('OnClick',tileClick);b:SetScript('OnDoubleClick',tileDouble);b:SetScript('OnEnter',tileEnter);b:SetScript('OnLeave',tileLeave);b:SetScript('OnDragStart',tileDrag);b:SetScript('OnMouseDown',tileDown)
     end
    end
   end
  end
 end
 if U.drag and U.drag.moved then
  for _,f in ipairs(pool.used) do if f.data==U.drag.a then U.ShowInspector(U.drag.a,U.drag.t,f) end end
 end
end
function U.JumpToPlayer(p)
 if not p then return end
 if not p.active then A.Message(A.T('addon.onBench',{n=p.name}));return end
 if hiddenSet()[p.name] then U.SetHidden(p.name,false) end
 if U.rowsDirty or not U.rowsCache then drawPlayers() end
 for _,row in ipairs(U.rowsCache or {}) do if row.header and row.player and row.player.name==p.name then
  U.scrollTarget=math.max(0,math.min(maxScroll(U.rowsTotal or 0),row.y));U.flash={name=p.name,t=GetTime()}
  U.scroller:Start();C_Timer.After(1.6,function() U.flash=nil;if U.window and U.window:IsShown() then drawPlayers() end end);return
 end end
end
local function cardPlacement(xx)
 local w=U.window;local W=w:GetWidth()
 local l1,l0=U.playerCanvas:GetLeft(),w:GetLeft()
 local left=(l1 and l0) and (l1-l0) or 0
 if left<=0 then left=24+(U.ROSTER_WIDTH or 0) end
 local minX,maxX=12-left,W-12-left-CARD_W;if maxX<minX then maxX=minX end
 local cardX=math.floor(math.max(minX,math.min(maxX,xx-(LANE_X+LANE_W/2)))+0.5)
 local nowX=math.max(LANE_X,math.min(CARD_W-12,xx-cardX))
 return cardX,nowX
end
U.CardPlacement=cardPlacement
function U.ShowInspector(a,t,chip)
 local bx=chip and chip.dpBox
 local cardX,nowX
 if bx then cardX,nowX=cardPlacement(x(t)) end
 inspector(a,t,U.drag and U.drag.what,nowX)
 local f=U.inspector;if not f or not chip then return end
 local side=U.drag and U.drag.side
 if not side then
  local top=chip:GetTop() or 0;local wtop=U.canvas:GetBottom() or 0
  side=(top+8+f:GetHeight()<=wtop) and 'above' or 'below';if U.drag then U.drag.side=side end
 end
 f:ClearAllPoints();f.cardX=cardX
 if not bx then if side=='above' then f:SetPoint('BOTTOM',chip,'TOP',0,8) else f:SetPoint('TOP',chip,'BOTTOM',0,-8) end;return end
 if side=='above' then f:SetPoint('BOTTOMLEFT',U.playerCanvas,'TOPLEFT',cardX,-bx[2]+8) else f:SetPoint('TOPLEFT',U.playerCanvas,'TOPLEFT',cardX,-(bx[2]+bx[3])-8) end
end
local function drawKicks(pool,y)
 if U.kickSub then U.kickSub:Hide() end
 local casts=A.boss.kicks or {};if #casts==0 then return 0 end
 track(pool,y,KICK_H,1)
 local g=gutter(pool,y,KICK_H,A.T('kk.row'),nil,'warm-4','ink');g.text:SetPoint('LEFT',26,5)
 local sub=U.kickSub;if not sub then sub=CreateFrame('Frame',nil,U.canvas);sub:SetSize(150,12);sub:EnableMouse(false);sub.text=U.Text(sub);sub.text:SetPoint('LEFT');U.kickSub=sub end
 sub:SetFrameLevel(g:GetFrameLevel()+1);sub:ClearAllPoints();sub:SetPoint('LEFT',g,'LEFT',26,-8);U.Font(sub.text,10);sub.text:SetTextColor(U.Color('ink-3'));sub.text:SetText(A.T('kk.rowSub'));sub:Show()
 g:EnableMouse(true);g:SetScript('OnClick',function() U.Kicks() end);g:SetScript('OnEnter',function(self) U.Tooltip(self,A.T('kk.rowTitle')) end);g:SetScript('OnLeave',function() GameTooltip:Hide() end)
 local mm=memoNow();if not mm.kicks then mm.kicks=M.kickSchedule(A.model.plan,casts,A.model.phases) end;local sched=mm.kicks
 for i,s in ipairs(sched) do
  if visible(s.t-5,s.t+5) then
   local nextX;for j=i+1,#sched do if (sched[j].line%2)==(s.line%2) then nextX=x(sched[j].t);break end end
   local names={};for _,gg in ipairs(s.group or {}) do names[#names+1]=gg.player end
   local nobody=#names==0
   local label=nobody and A.T('kk.tipNobody') or table.concat(names,', ')
   local bad=s.ready==false;if s.group then local none=true;for _,gg in ipairs(s.group) do if gg.it then none=false end end;if none then bad=true end end
   if nobody then bad=false end
   local who;for _,p in ipairs(A.model.plan.roster or {}) do if p.name==s.player then who=p end end
   local c=pool:get();c:SetHeight(14);c:SetPoint('TOPLEFT',x(s.t),-(y+3+(s.line%2)*17));U.Radius(c,3)
   if nobody then c:SetBackdropColor(0,0,0,0);c:SetBackdropBorderColor(U.ColorA('ink-3',0.8))
   else c:SetBackdropColor(U.ColorA(who and classKey(who) or 'ink-3',who and 0.9 or 0.35));c:SetBackdropBorderColor(U.ColorA('tl-conflict',bad and 1 or 0)) end
   c.text:ClearAllPoints();c.text:SetPoint('LEFT',4,0);c.text:SetPoint('RIGHT',-2,0);c.text:SetWordWrap(false);U.Font(c.text,10,'textMedium');c.text:SetTextColor(U.Color(who and 'ground' or 'ink-2'));c.text:SetText((bad and '! ' or '')..label)
   local natural=math.max(30,math.min((#names>1 or nobody) and 150 or 84,c.text:GetUnboundedStringWidth()+10));c:SetWidth(math.max(8,nextX and math.min(natural,nextX-x(s.t)-2) or natural))
   c:SetScript('OnEnter',function(self)
    local lines={A.T('kk.rowSub')..'  '..U.Time(s.t)}
    for _,gg in ipairs(s.group or {}) do lines[#lines+1]=gg.player..': '..(gg.it and (gg.it.name..', '..gg.it.cd..' s'..(gg.ready==false and '  |cfff34455'..A.T('addon.kickLate')..'|r' or '')) or A.T('kk.noKick')) end
    if not s.player then lines[#lines+1]=A.T('kk.tipNoRot') end
    U.Tooltip(self,table.concat(lines,'\n'))
   end);c:SetScript('OnLeave',function() GameTooltip:Hide() end)
   c:SetScript('OnClick',function() U.Kicks() end)
  end
 end
 return KICK_H
end
function U.DrawTimeline()
 if not U.canvas then return end
 U.drawSeq=(U.drawSeq or 0)+1
 local pool=U.bossPool;pool:release();local width=U.canvas:GetWidth();local height=U.canvas:GetHeight();if width<=labelWidth then return end
 local markers={};for _,mk in ipairs(A.boss.markers or {}) do markers[#markers+1]=mk end
 local enr=A.boss.enrage;if enr and enr.start then markers[#markers+1]={t=enr.start,name=A.T('addon.enrage',{name=enr.name or ''})..(enr.status~='confirmed' and ' ('..A.T('addon.unconfirmed')..')' or ''),enrage=true,spellId=enr.spellId} end
 local MARK=#markers>0 and 14 or 0
 for _,p in ipairs(A.model.phases) do
  local e=p['end'] or A.boss.duration
  if tostring(p.id):find('%.') then local tint=rect(pool,p.start,e,0,height,'tl-intermission');if tint then U.Radius(tint,0);tint:SetBackdropColor(U.ColorA('tl-intermission',0.08));tint:EnableMouse(false) end end
 end
 local title=gutter(pool,0,HEAD+MARK+AXIS,A.T('bossTimeline'),nil,nil,'ink','displayMedium');U.Font(title.text,12,'displayMedium')
 for _,p in ipairs(A.model.phases) do
  local e=p['end'] or A.boss.duration
  local band=rect(pool,p.start,e,0,HEAD,'ground-2')
  if band then
   U.Radius(band,0);band:SetBackdropColor(U.ColorA('warm-4',0.06));band:SetBackdropBorderColor(0,0,0,0)
   band.text:ClearAllPoints();band.text:SetPoint('LEFT',8,0);U.Font(band.text,12,'displayMedium');band.text:SetTextColor(U.Color('warm-4'))
   local full=tostring(p.id)..'  '..(p.name or '');band.text:SetText(full);band.text:SetWidth(math.max(0,band:GetWidth()-12))
   if band.text:GetUnboundedStringWidth()>band:GetWidth()-12 then band.text:SetText(tostring(p.id)) end
   band:SetScript('OnClick',function() if A.Allowed() then A.view.phase=p.id;U.ZoomTo(p.start-2,e-p.start+4) end end)
   band:SetScript('OnEnter',function(self) U.Tooltip(self,full..'\n'..U.Time(p.start)..' - '..U.Time(e)) end);band:SetScript('OnLeave',function() GameTooltip:Hide() end)
  end
  local edge=rect(pool,p.start,p.start,0,height,'tl-phase-edge');if edge then U.Radius(edge,0);edge:SetWidth(2);edge:EnableMouse(false);edge:SetFrameLevel(U.canvas:GetFrameLevel()+6) end
 end
 for _,mk in ipairs(markers) do if visible(mk.t,mk.t) then
  local key=mk.enrage and 'tl-conflict' or 'warm-4'
  local m=pool:get();m:SetHeight(MARK-2);m:SetPoint('TOPLEFT',x(mk.t),-(HEAD+1));U.Radius(m,3);m:SetBackdropColor(U.ColorA(key,0.16));m:SetBackdropBorderColor(0,0,0,0)
  m.text:ClearAllPoints();m.text:SetPoint('LEFT',4,0);U.Font(m.text,10,'textMedium');m.text:SetTextColor(U.Color(key));m.text:SetText(mk.name);m:SetWidth(math.min(220,m.text:GetUnboundedStringWidth()+10))
  if mk.enrage then local line=rect(pool,mk.t,mk.t,HEAD,height-HEAD,'tl-conflict');if line then U.Radius(line,0);line:SetWidth(2);line:SetBackdropColor(U.ColorA('tl-conflict',0.6));line:EnableMouse(false) end end
  m:SetScript('OnEnter',function(self) U.Tooltip(self,mk.name..'  '..U.Time(mk.t)) end);m:SetScript('OnLeave',function() GameTooltip:Hide() end)
 end end
 local step=A.view.span>480 and 60 or A.view.span>200 and 30 or A.view.span>80 and 15 or 5
 for t=math.ceil(A.view.start/step)*step,A.view.start+A.view.span,step do
  local grid=rect(pool,t,t,HEAD,height-HEAD,'ink');if grid then U.Radius(grid,0);grid:SetWidth(1);grid:SetBackdropColor(U.ColorA('ink',0.05));grid:EnableMouse(false) end
  if t>=0 and x(t)>labelWidth+16 and x(t)<width-24 then
   local tick=pool:get();tick:SetPoint('TOPLEFT',x(t)-30,-(HEAD+MARK));tick:SetSize(60,AXIS);tick:SetBackdrop(nil);tick:EnableMouse(false)
   tick.text:ClearAllPoints();tick.text:SetPoint('CENTER');tick.text:SetJustifyH('CENTER');U.Font(tick.text,10,'mono');tick.text:SetTextColor(U.Color('ink-3'));tick.text:SetText(U.Time(t))
  end
 end
 local TOP=HEAD+MARK+AXIS+6
 TOP=TOP+drawKicks(pool,TOP)
 local mm=memoNow();local cvKey=A.view.cvPersonals and 'cvP' or 'cv'
 if not mm[cvKey] then local hits=M.coverage(A.boss,A.model.plan,A.model.phases,A.CD,{personals=A.view.cvPersonals});local map={};for _,hit in ipairs(hits) do map[hit.cast or hit.win]=hit end;mm[cvKey]={hits=hits,map=map} end
 U.cvHits=mm[cvKey].hits;local cvMap=mm[cvKey].map;U.cvMap=cvMap
 local marks=A.view.cvMarks~=false
 local abKey=tostring(A.boss.id)..'|'..tostring(A.view.mode)..'|'..tostring(A.view.showAll and true or false)
 local abilities=U.abCache and U.abCache.key==abKey and U.abCache.list
 if not abilities then abilities={}
 if A.view.mode=='category' then
  local categories={};for _,a in ipairs(A.boss.abilities) do if A.view.showAll or a.importance=='core' then
   local key=a.category or 'event';local q=categories[key]
   if not q then q={name=A.T('bcat.'..key),category=key,casts={},windows={}};categories[key]=q;abilities[#abilities+1]=q end
   for _,c in ipairs(a.casts) do q.casts[#q.casts+1]=c end;for _,c in ipairs(a.windows) do q.windows[#q.windows+1]=c end
  end end
 else
  local byName={}
  for _,a in ipairs(A.boss.abilities) do if A.view.showAll or a.importance=='core' then
   local q=byName[a.name]
   if not q then q={name=a.name,category=a.category,spell=a.spellId,src=a.kind~='boss' and a.src or nil,casts={},windows={}};byName[a.name]=q;abilities[#abilities+1]=q end
   for _,c in ipairs(a.casts) do q.casts[#q.casts+1]=c end;for _,c in ipairs(a.windows) do q.windows[#q.windows+1]=c end
  end end
 end
 for _,q in ipairs(abilities) do table.sort(q.casts,function(m,n) return m.start<n.start end) end
 U.abCache={key=abKey,list=abilities}
 end
 local available=math.floor((height-TOP)/LANE);local offset=math.max(0,math.min(A.view.bossOffset or 0,math.max(0,#abilities-available)));A.view.bossOffset=offset
 for i=offset+1,math.min(#abilities,offset+available) do
  local a=abilities[i];local y=TOP+(i-offset-1)*LANE;local color='tl-cat-'..(a.category or 'event')
  track(pool,y,LANE,i)
  local g=gutter(pool,y,LANE,a.name,nil,color,'ink',nil,a.spell)
  if a.src then g.text:SetText(a.name..'  |cff8a7f8d'..a.src..'|r') end
  for _,w in ipairs(a.windows) do local bar=rect(pool,w.start,w['end'],y+4,LANE-8,color);if bar then U.Radius(bar,3);bar:SetBackdropColor(0,0,0,0);bar:SetBackdropBorderColor(U.ColorA(color,0.5));U.Hatch(bar,color,0.45)
   local hit=cvMap[w]
   if hit then
    if marks and hit.cv.state~='quiet' then local m=rect(pool,w.start,w['end'],y+LANE-4,3,'ink');if m then U.Radius(m,0);m:SetBackdropColor(U.ColorA(U.CoverColor(hit),0.9));m:SetBackdropBorderColor(0,0,0,0);m:EnableMouse(false) end end
    bar.dpName=a.name;bar.dpWin=w;bar.dpHit=hit;bar:SetScript('OnEnter',windowEnter);bar:SetScript('OnLeave',hideTip)
   else bar:EnableMouse(false) end
  end end
  local lastRight,lastChip=-1e9,nil
  for n,c in ipairs(a.casts) do
   if c['end'] and c['end']-c.start>0.5 then local zb=rect(pool,c.start,c['end'],y+5,LANE-10,color);if zb then U.Radius(zb,3);zb:SetBackdropColor(U.ColorA(color,0.22));zb:SetBackdropBorderColor(0,0,0,0);zb:EnableMouse(false) end end
   if visible(c.start,c.start+1) then
    local cx=x(c.start);local nextX=a.casts[n+1] and x(a.casts[n+1].start) or 1e9
    local chip=pool:get();chip.castTime=c.start
    chip.dpList=nil;chip.dpTo=nil
    if cx<lastRight+2 then
     chip:SetSize(3,LANE-8);chip:SetPoint('TOPLEFT',cx,-(y+4));U.Radius(chip,0);chip:SetBackdropColor(U.ColorA(color,0.85));chip:SetBackdropBorderColor(0,0,0,0)
     if lastChip then lastChip.dpTo=n end
    else
     local size=LANE-4;chip:SetSize(size,size);chip:SetPoint('TOPLEFT',cx,-(y+2));tile(chip,U.Icon(c.spell),color,size);lastRight=cx+size
     chip.dpList=a.casts;chip.dpFrom=n;chip.dpTo=n;lastChip=chip
     if nextX-cx>size+40 then
      local lbl=pool:get();lbl:SetPoint('LEFT',chip,'RIGHT',3,0);lbl:SetSize(40,size);lbl:SetBackdrop(nil);lbl:EnableMouse(false)
      U.Font(lbl.text,10,'mono');lbl.text:SetTextColor(U.Color('ink-2'));lbl.text:SetText(U.Time(c.start));lastRight=cx+size+36
     end
    end
    local hit=cvMap[c]
    if hit and marks and hit.cv.state~='quiet' then
     local m=pool:get();m:SetSize(math.max(6,chip:GetWidth()),3);m:SetPoint('TOPLEFT',cx,-(y+LANE-3));U.Radius(m,0);m:SetBackdropColor(U.ColorA(U.CoverColor(hit),0.95));m:SetBackdropBorderColor(0,0,0,0);m:EnableMouse(false);m:SetFrameLevel(chip:GetFrameLevel()+1)
    end
    chip.dpCast=c;chip.dpName=a.name;chip.dpN=n;chip.dpHit=hit;chip:SetScript('OnEnter',chipEnter);chip:SetScript('OnLeave',hideTip);chip:SetScript('OnClick',chipClick)
   end
  end
 end
 drawPlayers()
end
local function clampStart(v) return math.max(-60,math.min((A.boss.duration or 600)+30-A.view.span*0.5,v)) end
function U.PanBy(seconds)
 if U.zoomTarget then U.zoomTarget=nil;U.zoomer:SetScript('OnUpdate',nil);U.zoomer:Hide() end
 A.view.start=clampStart(A.view.start+seconds);U.RequestDraw()
end
function U.BeginPan(button,onBoss,onClick)
 if not A.Allowed() then return end
 local startX=GetCursorPosition();local start=A.view.start;local scale=U.canvas:GetEffectiveScale();local clickT=timeAt();local moved=false
 U.panning=true
 U.driver:SetScript('OnUpdate',function()
  if not U.panning then U.driver:SetScript('OnUpdate',nil);U.driver:Hide();return end
  if not IsMouseButtonDown(button) then
   U.panning=nil;U.driver:SetScript('OnUpdate',nil);U.driver:Hide();A.Save()
   if not moved and button=='RightButton' then if onClick then onClick() elseif onBoss then U.BossContext(clickT) end end
   return
  end
  local dx=(GetCursorPosition()-startX)/scale;if math.abs(dx)>3 then moved=true end;local per=A.view.span/math.max(1,U.canvas:GetWidth()-labelWidth)
  local v=clampStart(start-dx*per);if v~=A.view.start then A.view.start=v;U.DrawTimeline() end
 end)
 U.driver:Show()
end
local TARGETS={{'everyone','addon.tEveryone'},{'tank','addon.roleTank'},{'healer','addon.roleHealer'},{'melee','addon.roleMelee'},{'ranged','addon.roleRanged'}}
function U.BossContext(t,label)
 if not A.Allowed() then return end
 t=A.NSRT.round1(math.max(0,t));local ph,offset=M.at(t,A.model.phases)
 local function open(tag) U.AssignmentEditor({tag=tag,phase=tostring(ph.id),time=A.NSRT.round1(offset),text=label,extra={}},true) end
 local items={{A.T('addon.alertAt',{t=U.TimeFine(t),p=tostring(ph.id)}),nil,title=true}}
 for _,x in ipairs(TARGETS) do items[#items+1]={A.T(x[2]),function() open(x[1]) end} end
 for g=1,4 do items[#items+1]={A.T('ro.groupN',{n=g}),function() open('group'..g) end} end
 items[#items+1]={'',nil,divider=true}
 for _,p in ipairs(A.model.plan.roster or {}) do if p.active then
  local r,g,b=U.Color(p.classToken and 'class-'..p.classToken or 'ink')
  items[#items+1]={string.format('|cff%02x%02x%02x%s|r',r*255,g*255,b*255,p.name),function() open(p.name) end}
 end end
 U.Menu(U.canvas,items)
end
function U.SyncSelbar()
 local f=U.selbar;if not f then return end
 local list=U.Selected();local n=#list
 if n<2 and multiCount()==0 then f:Hide();return end
 f.count:SetText(A.T('addon.selected',{n=n}))
 local xx=f.count:GetUnboundedStringWidth()+24
 for _,b in ipairs(f.buttons) do b:SetLabel(b.label());b:ClearAllPoints();b:SetPoint('LEFT',xx,0);xx=xx+b:GetWidth()+4 end
 f:SetWidth(xx+8);f:Show()
end
local function buildSelbar(parent)
 local f=CreateFrame('Frame',nil,parent);U.Surface(f,'panel','border',6);f:SetHeight(38);f:SetPoint('BOTTOM',U.playerCanvas,'BOTTOM',0,10);f:SetFrameLevel(U.playerCanvas:GetFrameLevel()+30);f:EnableMouse(true);f:Hide()
 f.count=U.Label(f,'',14,0,13,'textMedium');f.count:ClearAllPoints();f.count:SetPoint('LEFT',14,0)
 f.buttons={}
 local function add(label,fn) local b=U.Button(f,'',0,0,0,fn,{key=false,height=26});b.label=label;f.buttons[#f.buttons+1]=b end
 for _,d in ipairs({-5,-1,1,5}) do add(function() return (d>0 and '+' or '')..d..' s' end,function() U.MoveLines(U.Selected(),d) end) end
 add(function() return A.T('ctx.del') end,function() U.RemoveLines(U.Selected()) end)
 add(function() return A.T('ctx.clear') end,function() U.ClearSelection();U.RequestDraw() end)
 U.selbar=f
end
local pending,pendingFull=false,false
local function flush()
 pending=false;local full=pendingFull;pendingFull=false
 if not (U.window and U.window:IsShown()) then return end
 if full then U.DrawTimeline() else U.DrawPlayers() end
end
function U.RequestDraw()
 pendingFull=true
 if pending then return end;pending=true
 C_Timer.After(0,flush)
end
function U.RequestPlayers()
 if pending then return end;pending=true
 C_Timer.After(0,flush)
end
function U.ZoomTo(start,span,anchorT)
 U.zoomTarget={start=start,span=math.max(20,math.min(1800,span)),anchor=anchorT};U.zoomer:Start()
end
function U.CreateTimeline(parent)
 U.canvas=CreateFrame('Frame',nil,parent);U.Surface(U.canvas,'panel','line',10);U.canvas:SetPoint('TOPLEFT',12+U.ROSTER_WIDTH+12,-130);U.canvas:SetPoint('TOPRIGHT',-12,-130);U.canvas:SetHeight(264);U.canvas:SetClipsChildren(true)
 U.playerCanvas=CreateFrame('Frame',nil,parent);U.Surface(U.playerCanvas,'panel','line',10);U.playerCanvas:SetPoint('TOPLEFT',U.canvas,'BOTTOMLEFT',0,-36);U.playerCanvas:SetPoint('BOTTOMRIGHT',parent,'BOTTOMRIGHT',-12,36);U.playerCanvas:SetClipsChildren(true)
 U.bossPool=U.Pool(U.canvas);U.playerPool=U.Pool(U.playerCanvas)
 U.driver=CreateFrame('Frame',nil,parent);U.driver:Hide()
 U.hoverer=CreateFrame('Frame',nil,parent)
 buildSelbar(parent)
 U.scroller=CreateFrame('Frame',nil,parent);U.scroller:Hide()
 local function ease(self,elapsed)
  local cur=A.view.scrollY or 0;local target=U.scrollTarget or cur;local diff=target-cur
  if math.abs(diff)<0.5 then A.view.scrollY=target;self:SetScript('OnUpdate',nil);self:Hide();U.DrawPlayers();A.SaveSoon();return end
  A.view.scrollY=cur+diff*math.min(1,elapsed*14);U.DrawPlayers()
 end
 function U.scroller:Start() self:SetScript('OnUpdate',ease);self:Show() end
 U.zoomer=CreateFrame('Frame',nil,parent);U.zoomer:Hide()
 local function zoomStep(self,elapsed)
  local z=U.zoomTarget;if not z then self:SetScript('OnUpdate',nil);self:Hide();return end
  local k=math.min(1,elapsed*16)
  local frac=z.anchor and (z.anchor-A.view.start)/A.view.span
  A.view.span=A.view.span+(z.span-A.view.span)*k
  if frac then A.view.start=z.anchor-frac*A.view.span else A.view.start=A.view.start+(z.start-A.view.start)*k end
  if math.abs(A.view.span-z.span)<0.05 and (frac or math.abs(A.view.start-z.start)<0.05) then
   A.view.span=z.span;if not frac then A.view.start=z.start end;U.zoomTarget=nil;self:SetScript('OnUpdate',nil);self:Hide();U.Render();A.Save();return
  end
  U.DrawTimeline()
 end
 function U.zoomer:Start() self:SetScript('OnUpdate',zoomStep);self:Show() end
 U.canvas:EnableMouse(true);U.canvas:SetScript('OnMouseDown',function(_,button) U.BeginPan(button,true) end)
 U.playerCanvas:EnableMouse(true);U.playerCanvas:SetScript('OnMouseDown',function(_,button)
  if button=='LeftButton' then if A.Allowed() and select(1,cursorLocal())>=labelWidth then startBox(nil) end
  else U.BeginPan(button,false,function() rowMenu(nil,A.NSRT.round1(math.max(0,timeAt()))) end) end
 end)
 U.canvas:EnableMouseWheel(true);U.canvas:SetScript('OnMouseWheel',function(_,d)
  if not A.Allowed() then return end
  if IsControlKeyDown() then local z=U.zoomTarget;local span=(z and z.span or A.view.span)*(d>0 and 0.8 or 1.25);U.ZoomTo(nil,span,timeAt());return end
  if IsShiftKeyDown() then U.PanBy(-d*A.view.span/10);return end
  A.view.bossOffset=math.max(0,(A.view.bossOffset or 0)-d*2);U.RequestDraw()
 end)
 U.playerCanvas:EnableMouseWheel(true);U.playerCanvas:SetScript('OnMouseWheel',function(_,d)
  if not A.Allowed() then return end
  if IsControlKeyDown() then local z=U.zoomTarget;local span=(z and z.span or A.view.span)*(d>0 and 0.8 or 1.25);U.ZoomTo(nil,span,timeAt());return end
  if IsShiftKeyDown() then U.PanBy(-d*A.view.span/10);return end
  U.scrollTarget=math.max(0,math.min(maxScroll(U.rowsTotal or 0),(U.scrollTarget or A.view.scrollY or 0)-d*ROW()*2.5))
  U.scroller:Start()
 end)
 U.scrub=U.playerCanvas:CreateTexture(nil,'OVERLAY');U.scrub:SetColorTexture(U.Color('tl-scrub'));U.scrub:SetWidth(2);U.scrub:SetHeight(2000);U.scrub:Hide()
 U.bossScrub=U.canvas:CreateTexture(nil,'OVERLAY');U.bossScrub:SetColorTexture(U.Color('tl-scrub'));U.bossScrub:SetSize(2,2000);U.bossScrub:Hide()
 U.Crisp(U.scrub);U.Crisp(U.bossScrub)
 U.ghost=U.playerCanvas:CreateTexture(nil,'OVERLAY');U.ghost:SetColorTexture(1,1,1,1);U.ghost:Hide()
 U.ghostBand=U.playerCanvas:CreateTexture(nil,'OVERLAY');U.ghostBand:SetColorTexture(1,1,1,1);U.ghostBand:Hide()
 U.verdict=U.playerCanvas:CreateFontString(nil,'OVERLAY','GameFontHighlight');U.Font(U.verdict,11,'textMedium');U.verdict:Hide()
 local function hideGhost() U.ghost:Hide();U.ghostBand:Hide();U.verdict:Hide();U.ghostKey=nil end
 function U.MoveScrub(xx,t)
  U.scrub:ClearAllPoints();U.scrub:SetPoint('TOPLEFT',xx-1,0);U.scrub:Show();U.bossScrub:ClearAllPoints();U.bossScrub:SetPoint('TOPLEFT',xx-1,0);U.bossScrub:Show()
  for _,b in ipairs(U.bossPool.used) do if b.castTime then b:SetAlpha(math.abs(b.castTime-t)<=3 and 1 or 0.45) end end
 end
 local function preview(hit,t)
  local key=tostring(hit)..'|'..t;if U.ghostKey==key then return end;U.ghostKey=key
  local top=A.view.scrollY or 0;local h=rowHeight(hit);local y=hit.y-top
  local cd=A.CD[hit.spell.id];if not cd then hideGhost();return end
  local probe={tag=hit.everyone and 'everyone' or hit.player.name,spellId=cd.id,phase='1',time=t}
  local lines={probe};local others={};for _,a in ipairs(rowLines(hit)) do lines[#lines+1]=a;local at=absT(a);if at then others[#others+1]={t=at} end end
  local over={[probe]=t};local sim=M.recharge(lines,cd,A.model.phases,over)
  local bad=sim[probe] and sim[probe].early>0.05
  local col=bad and 'tl-conflict' or 'kill';local size=A.db.compact and h-4 or 18
  U.ghost:ClearAllPoints();U.ghost:SetPoint('TOPLEFT',x(t),-(y+(h-size)/2));U.ghost:SetSize(size,size);U.ghost:SetVertexColor(U.ColorA(col,0.35));U.ghost:Show()
  local ps=M.preStart(cd,t,others)
  if ps and x(ps)<x(t) then U.ghostBand:ClearAllPoints();U.ghostBand:SetPoint('TOPLEFT',math.max(labelWidth,x(ps)),-(y+(h-16)/2+3));U.ghostBand:SetSize(math.max(1,x(t)-math.max(labelWidth,x(ps))),10);U.ghostBand:SetVertexColor(U.ColorA(col,0.16));U.ghostBand:Show() else U.ghostBand:Hide() end
  U.verdict:ClearAllPoints();U.verdict:SetPoint('LEFT',U.playerCanvas,'TOPLEFT',x(t)+size+6,-(y+h/2));U.verdict:SetTextColor(U.Color(col))
  U.verdict:SetText(bad and A.T('addon.previewBad',{n=math.max(1,math.floor(sim[probe].early+0.5))}) or A.T('addon.previewOk',{t=U.Time(t)}));U.verdict:Show()
 end
 local function hover(frame)
  U.hoverFrame=frame
  if U.hoverer:GetScript('OnUpdate') then return end
  local lastX,lastY,lastStart,lastSpan,lastScroll,lastSeq,lastOver
  U.hoverer:SetScript('OnUpdate',function()
   local over=U.canvas:IsMouseOver() and U.canvas or U.playerCanvas:IsMouseOver() and U.playerCanvas
   if not over then lastOver=nil;if U.scrub:IsShown() or U.bossScrub:IsShown() then U.scrub:Hide();U.bossScrub:Hide();hideGhost();for _,b in ipairs(U.bossPool.used) do b:SetAlpha(1) end end;return end
   local cx,cy=GetCursorPosition();local v=A.view
   if cx==lastX and cy==lastY and over==lastOver and v.start==lastStart and v.span==lastSpan and v.scrollY==lastScroll and U.drawSeq==lastSeq and not (U.drag or U.panning or U.box) then return end
   lastX,lastY,lastOver,lastStart,lastSpan,lastScroll,lastSeq=cx,cy,over,v.start,v.span,v.scrollY,U.drawSeq
   frame=over
   if U.drag or U.panning or U.box then hideGhost();return end
   local t=timeAt();local xx=x(t);if xx<labelWidth then U.scrub:Hide();U.bossScrub:Hide();hideGhost();return end
   U.MoveScrub(xx,t)
   if frame==U.playerCanvas and not U.hoverTile then
    local _,yy=cursorLocal();yy=yy+(A.view.scrollY or 0);local hit
    for _,row in ipairs(U.visibleRows or {}) do if not row.gap and yy>=row.y and yy<row.y+rowHeight(row) then hit=row;break end end
    if hit and hit.spell and hit.spell.id and not hit.other and not hit.personals then preview(hit,math.max(0,math.floor(t+0.5))) else hideGhost() end
   else hideGhost() end
  end)
 end
 U.StartHover=hover
 U.canvas:SetScript('OnEnter',hover);U.playerCanvas:SetScript('OnEnter',hover)
 U.canvas:SetScript('OnHide',function(f) f:SetScript('OnUpdate',nil) end);U.playerCanvas:SetScript('OnHide',function(f) f:SetScript('OnUpdate',nil) end)
end
