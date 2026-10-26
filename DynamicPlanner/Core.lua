local name, A = ...
_G.DynamicPlanner=A
A.name=name; A.locale='en'; A.UI={}; A.CD={}; A.SpecByID={}
function A.T(key,vars)
 local aliases={['note.import']='pb.import',['note.copyRaid']='pb.copy',['rc.title']='sec.players',bossTimeline='sec.boss',spells='blk.spells',all='ph.all',['preset.all']='pb.all',['preset.clear']='pb.clear'}
 key=aliases[key] or key
 local dict=A.Locales[A.locale] or A.Locales.en
 local s=dict[key] or A.Locales.en[key] or key
 return (s:gsub('{([%w]+)}',function(k) return tostring(vars and vars[k] or '') end))
end
function A.Allowed() return not InCombatLockdown() end
function A.Public(v) return not issecretvalue or not issecretvalue(v) end
function A.Message(s) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('Dynamic Planner: '..s) end end
function A.Save()
 if not A.model then return end
 local b=A.db.bosses[A.boss.id] or {};A.db.bosses[A.boss.id]=b
 b.plan=A.Model.copy(A.model.plan);b.view=A.Model.copy(A.view)
end
local savePending=false
function A.SaveSoon()
 if savePending then return end;savePending=true
 C_Timer.After(0.5,function() savePending=false;A.Save() end)
end
function A.SelectBoss(id)
 if not A.Allowed() or not A.Bosses[id] then return end
 A.Save(); A.boss=A.Bosses[id]
 local saved=A.db.bosses[id]
 A.view=saved and saved.view or {start=-5,span=A.boss.duration+10,offset=0,mode='ability',preset='essential',showAll=false,category='all'}
 A.LoadPlan(saved and saved.plan)
end
function A.BlankPlan() return {encounterId=A.boss.id,name=A.boss.name,difficulty='Mythic',lines={},roster={}} end
function A.LoadPlan(plan)
 local id=A.boss.id
 plan=plan or A.BlankPlan()
 A.Model.seedRoster(plan,A.Roster);A.Model.mergeRoster(plan,A.Roster)
 A.Upgrade(plan,A.PhaseMaps[id].phases)
 A.model=A.Model.new(plan,A.PhaseMaps[id].phases)
 A.view.offset=A.view.offset or 0;A.view.scrollY=A.view.scrollY or 0;A.UI.scrollTarget=nil
 if A.UI.ClearSelection then A.UI.ClearSelection() end
 if A.UI.window then A.UI.Render() end
end
local function bossDB() local b=A.db.bosses[A.boss.id] or {};A.db.bosses[A.boss.id]=b;b.saved=b.saved or {};return b end
function A.PlanName() local b=A.db.bosses[A.boss.id];return b and b.planName or A.T('pl.default') end
function A.PlanNames()
 local b=bossDB();local cur=A.PlanName();local out={}
 for n in pairs(b.saved) do if n~=cur then out[#out+1]=n end end
 table.sort(out,function(x,y) return x:lower()<y:lower() end);table.insert(out,1,cur);return out
end
local function cleanName(n) n=tostring(n or ''):gsub('[\r\n|]',''):gsub('^%s+',''):gsub('%s+$','');return n:sub(1,40) end
function A.UniquePlanName(n)
 n=cleanName(n);if n=='' then n=A.T('pl.default') end
 local names={};for _,x in ipairs(A.PlanNames()) do names[x:lower()]=true end
 if not names[n:lower()] then return n end
 local i=2;while names[(n..' '..i):lower()] do i=i+1 end;return n..' '..i
end
function A.OpenPlan(name)
 if not A.Allowed() then return false end
 local b=bossDB();local cur=A.PlanName()
 if name==cur or not b.saved[name] then return false end
 A.Save();b.saved[cur]=A.Model.copy(A.model.plan)
 local plan=b.saved[name];b.saved[name]=nil;b.planName=name;b.plan=plan
 A.LoadPlan(A.Model.copy(plan));A.Save();A.Message(A.T('pl.opened',{name=name}));return true
end
function A.NewPlan(name,copy)
 if not A.Allowed() then return false end
 local b=bossDB();local cur=A.PlanName();name=A.UniquePlanName(name)
 A.Save();b.saved[cur]=A.Model.copy(A.model.plan)
 local plan=copy and A.Model.copy(A.model.plan) or A.BlankPlan()
 if not copy then plan.roster=A.Model.copy(A.model.plan.roster or {});for _,p in ipairs(plan.roster) do p.spells=nil end end
 plan.kicks=copy and plan.kicks or nil
 b.planName=name;A.LoadPlan(plan);A.Save();A.Message(A.T('pl.opened',{name=name}));return true
end
function A.RenamePlan(old,new)
 if not A.Allowed() then return false end
 local b=bossDB();new=cleanName(new)
 if new=='' or new==old then return false end
 for _,x in ipairs(A.PlanNames()) do if x:lower()==new:lower() and x~=old then return false end end
 if old==A.PlanName() then b.planName=new elseif b.saved[old] then b.saved[new]=b.saved[old];b.saved[old]=nil else return false end
 A.Save();return true
end
function A.DeletePlan(name)
 if not A.Allowed() then return false end
 local b=bossDB()
 if name~=A.PlanName() then if not b.saved[name] then return false end;b.saved[name]=nil;return true end
 local nextName=A.PlanNames()[2]
 if nextName then local plan=b.saved[nextName];b.saved[nextName]=nil;b.planName=nextName;A.LoadPlan(A.Model.copy(plan))
 else b.planName=nil;A.LoadPlan(nil) end
 A.Save();return true
end
function A.Edit(fn)
 if not A.Allowed() then return end
 A.Model.transaction(A.model,function(plan) fn(plan);plan.terminalNewline=false end); A.Save(); A.UI.Render()
end
function A.Upgrade(plan,phases)
 plan.lines=plan.lines or {}
 A.Model.canonAll(plan);A.Model.everyoneMigrate(plan,phases);A.Model.kicksFromBlocks(plan)
 plan.railMode=plan.railMode or 'role';plan.notes=plan.notes or {}
end
function A.ParseImport(text)
 if not A.Allowed() or not A.Public(text) then return nil end
 if not text:find('%S') then A.Message(A.T('addon.empty'));return nil end
 local p,err=A.NSRT.parse(text)
 if not p and err=='Missing EncounterID header' then
  p,err=A.NSRT.parse('EncounterID:'..A.boss.id..';Difficulty:Mythic;Name:'..A.boss.name..';\n'..text)
  if p then p.headerless=true end
 end
 if not p then A.Message(err);return nil end
 if p.headerless and #p.lines==0 and #p.rejected==0 and #(p.kickBlocks or {})==0 then A.Message(A.T('addon.noReminders'));return nil end
 if not A.Bosses[p.encounterId] then A.Message('Unsupported encounter: '..p.encounterId);return nil end
 return p
end
function A.MatchTag(tag,roster)
 local f=tag:lower()
 for _,r in ipairs(roster) do if r.name:lower()==f then return r,'exact' end end
 for _,r in ipairs(roster) do if r.nick and r.nick:lower()==f then return r,'nick' end end
 local first=f:match('^(%S+)')
 for _,r in ipairs(roster) do if r.name:lower()==first then return r,'first' end end
 return nil,'miss'
end
function A.ApplyImport(p,mode,map)
 if not A.Allowed() then return false end
 if A.boss.id~=p.encounterId then A.SelectBoss(p.encounterId) end
 local added,dup=0,0
 A.Edit(function(plan)
  local lines={}
  for _,a in ipairs(p.lines) do
   if A.Model.isSelector(a.tag) or a.tag:find('%s') then lines[#lines+1]=a
   else
    local to=map[a.tag]
    if to=='+' then
     local exists;for _,r in ipairs(plan.roster) do if r.name:lower()==a.tag:lower() then exists=r end end
     if not exists then plan.roster[#plan.roster+1]={name=a.tag,active=false} end
     lines[#lines+1]=a
    elseif to and to~='' then
     local r;for _,x in ipairs(plan.roster) do if x.name==to then r=x end end
     if r and a.tag:lower()~=r.name:lower() then r.nick=a.tag end
     a.tag=to;lines[#lines+1]=a
    end
   end
  end
  A.Upgrade({lines=lines},A.model.phases)
  local who={};for _,a in ipairs(lines) do who[a.tag:lower()]=true end
  if mode=='replace' then
   who.everyone=true
   local keep={};for _,a in ipairs(plan.lines) do if not who[a.tag:lower()] then keep[#keep+1]=a end end;plan.lines=keep
   plan.notes={}
  end
  local function key(a) return a.tag:lower()..'|'..tostring(a.spellId or '')..'|'..tostring(a.text or '')..'|'..tostring(a.phase)..'|'..string.format('%.1f',a.time) end
  local have={};for _,a in ipairs(plan.lines) do have[key(a)]=true end
  for _,a in ipairs(lines) do if have[key(a)] then dup=dup+1 else have[key(a)]=true;plan.lines[#plan.lines+1]=a;added=added+1 end end
  if p.kickBlocks and #p.kickBlocks>0 then local tmp={kickBlocks=p.kickBlocks,roster=plan.roster};A.Model.kicksFromBlocks(tmp);plan.kicks=tmp.kicks end
  plan.notes=plan.notes or {};for _,n in ipairs(p.notes or {}) do local seen;for _,x in ipairs(plan.notes) do if x==n then seen=true end end;if not seen then plan.notes[#plan.notes+1]=n end end
  A.Model.activateTagged(plan);A.Model.mergeRoster(plan,A.Roster);A.Model.seat(plan)
  plan.difficulty=p.difficulty or plan.difficulty
 end)
 if mode=='replace' then A.model.plan.terminalNewline=p.terminalNewline;A.Save() end
 A.Message(A.T('addon.imported',{n=added,d=dup}));return true
end
function A.Import(text)
 local p=A.ParseImport(text);if not p then return false end
 if #p.rejected>0 then
  A.Message('Import stopped: '..#p.rejected..' invalid lines; first line '..p.rejected[1].line..' ('..p.rejected[1].reason..'). Original note is unchanged.');return false
 end
 local map={};for _,a in ipairs(p.lines) do if not A.Model.isSelector(a.tag) and not a.tag:find('%s') then local r=A.MatchTag(a.tag,A.model.plan.roster);map[a.tag]=r and r.name or '+' end end
 return A.ApplyImport(p,'replace',map)
end
function A.ReadNSRT()
 if not A.Allowed() then return end
 if not NSAPI or type(NSAPI.GetReminderString)~='function' then A.Message('NSRT read API unavailable. Paste a note instead.');return end
 local ok,personal,shared=pcall(NSAPI.GetReminderString,NSAPI,A.boss.id)
 if not ok then A.Message('NSRT read failed');return end
 if not A.Public(shared) or not A.Public(personal) then A.Message('NSRT returned restricted text');return end
 local text=type(shared)=='string' and shared~='' and shared or personal
 if type(text)~='string' or text=='' then A.Message('NSRT has no note for this encounter');return end
 local section=A.NSRT.forEncounter(text,A.boss.id)
 if not section and type(personal)=='string' then section=A.NSRT.forEncounter(personal,A.boss.id) end
 if not section then A.Message('NSRT has no section for this encounter');return end
 A.UI.Note(section,false)
end
function A.ExportInclude()
 local active={}; for _,p in ipairs(A.model.plan.roster or {}) do if p.active then active[p.name]=true end end
 return function(a)
  if active[a.tag] then return true end
  local raid=true;for tok in a.tag:gmatch('%S+') do if not A.Model.isSelector(tok) then raid=false end end
  if raid then return true end
  for target in a.tag:gmatch('%S+') do if active[target] then return true end end
  return false
 end
end
function A.ExportText()
 return pcall(A.NSRT.serialize,A.model.plan,A.ExportInclude())
end
function A.Export()
 local ok,text=A.ExportText()
 if not ok then A.Message(text);return end
 A.UI.Note(text,true)
end
function A.NSRTWritable()
 local N=_G.NorthernSkyRaidTools
 return type(N)=='table' and type(N.ImportReminder)=='function' and NSAPI and type(NSAPI.GetReminderString)=='function'
end
function A.SendNSRT()
 if not A.Allowed() then return end
 local ok,text=A.ExportText()
 if not ok then A.Message(text);return end
 if not A.NSRTWritable() then A.Message(A.T('addon.nsrtMissing'));A.UI.Note(text,true);return end
 local name='Dynamic Planner: '..A.boss.name
 local exists=type(NSRT)=='table' and type(NSRT.Reminders)=='table' and NSRT.Reminders[name]~=nil
 local done,err=pcall(_G.NorthernSkyRaidTools.ImportReminder,_G.NorthernSkyRaidTools,name,text,true,false,exists)
 local _,shared
 if done then done,_,shared=pcall(NSAPI.GetReminderString,NSAPI,A.boss.id) end
 if done and A.Public(shared) and shared==text then
  local n=0;for _ in text:gmatch('\n') do n=n+1 end
  A.Message(A.T('addon.nsrtSent',{n=n,name=name}))
 else
  A.Message(A.T('addon.nsrtFailed',{err=tostring(err or 'note did not match after import')}));A.UI.Note(text,true)
 end
end
function A.Toggle()
 if not A.Allowed() then A.Message('The planner is available out of combat.');return end
 if not A.UI.window then A.UI.CreateWindow() end
 A.UI.window:SetShown(not A.UI.window:IsShown());if A.UI.window:IsShown() then A.UI.Render() end
end
function A.OpenAnalyzer()
 if not A.Allowed() then A.Message('The planner is available out of combat.');return end
 if not A.UI.window then A.UI.CreateWindow() end
 A.UI.window:Show();if A.UI.Mode()~='analyzer' then A.UI.SetMode('analyzer') else A.UI.Render() end
end
local events=CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED');events:RegisterEvent('PLAYER_LOGIN');events:RegisterEvent('PLAYER_REGEN_DISABLED');events:RegisterEvent('PLAYER_LOGOUT')
events:SetScript('OnEvent',function(_,event,addon)
 if event=='ADDON_LOADED' and addon==name then
  DynamicPlannerDB=DynamicPlannerDB or {version=1,bosses={},locale='en'}
  A.db=DynamicPlannerDB;A.db.bosses=A.db.bosses or {};A.locale=(GetLocale and GetLocale()=='ptBR') and 'pt-BR' or 'en'
  for _,s in ipairs(A.Cooldowns) do A.CD[s.id]=s end
  for _,s in ipairs(A.Specs) do A.SpecByID[s.id]=s end
  A.SelectBoss(A.db.lastBoss or 3429)
 elseif event=='PLAYER_LOGIN' then
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
   AddonCompartmentFrame:RegisterAddon({text='Dynamic Planner',icon='Interface\\Icons\\INV_Misc_PocketWatch_01',func=A.Toggle})
  end
 elseif event=='PLAYER_LOGOUT' then
  A.Save()
 elseif event=='PLAYER_REGEN_DISABLED' then
  if A.UI.window then A.UI.window:StopMovingOrSizing();A.UI.window:Hide() end
  if A.UI.CancelDrag then A.UI.CancelDrag() end
  if A.UI.note then A.UI.note:Hide() end
 end
end)
local Perf={on=false,stats={},orig={}};A.Perf=Perf
local TARGETS={
 {'UI','Render'},{'UI','DrawTimeline'},{'UI','DrawPlayers'},{'UI','DrawRoster'},{'UI','RefreshProblems'},{'UI','LayoutHeader'},
 {'UI','SpellTip'},{'UI','ShowInspector'},{'UI','DrawFilters'},{'UI','DrawCoverage'},{'UI','DrawShortcuts'},
 {'UI','RenderAnalyzer'},{'UI','DrawAnalyzer'},{'Analyzer','Snapshot'},
 {'UI','ToggleFilters'},{'UI','ToggleCoverage'},{'UI','Shortcuts'},{'UI','Kicks'},{'UI','RaidGrid'},{'UI','Menu'},
 {'Model','conflicts'},{'Model','coverage'},{'Model','problems'},{'Model','preStart'},{'Model','railOrdered'},
 {'root','Save'},{'root','Import'},{'root','Edit'},
}
local function owner(where) if where=='UI' then return A.UI elseif where=='Model' then return A.Model elseif where=='Analyzer' then return A.Analyzer else return A end end
local function clock() return debugprofilestop and debugprofilestop() or (GetTime() or 0)*1000 end
function Perf.Start()
 if Perf.on then return end
 Perf.on=true;Perf.stats={};Perf.started=clock();Perf.kb0=collectgarbage('count')
 for _,t in ipairs(TARGETS) do
  local tbl,name=owner(t[1]),t[2];local fn=tbl and tbl[name]
  if type(fn)=='function' then
   local label=(t[1]=='root' and 'A' or t[1]=='UI' and 'U' or t[1]=='Analyzer' and 'AN' or 'M')..'.'..name
   Perf.orig[#Perf.orig+1]={tbl,name,fn}
   tbl[name]=function(...)
    local st=Perf.stats[label];if not st then st={n=0,ms=0,max=0,kb=0};Perf.stats[label]=st end
    local k0=collectgarbage('count');local t0=clock()
    local a,b,c,d=fn(...)
    local dt=clock()-t0;local dk=collectgarbage('count')-k0
    st.n=st.n+1;st.ms=st.ms+dt;if dt>st.max then st.max=dt end;if dk>0 then st.kb=st.kb+dk end
    return a,b,c,d
   end
  end
 end
 A.Message(A.T('perf.on'))
end
function Perf.Report()
 local rows={};for label,st in pairs(Perf.stats) do rows[#rows+1]={label,st} end
 table.sort(rows,function(x,y) return x[2].ms>y[2].ms end)
 local secs=(clock()-(Perf.started or clock()))/1000
 A.Message(A.T('perf.head',{s=string.format('%.0f',secs),kb=string.format('%.0f',collectgarbage('count')-(Perf.kb0 or 0))}))
 if #rows==0 then A.Message(A.T('perf.none'));return end
 for i=1,math.min(#rows,14) do local l,st=rows[i][1],rows[i][2]
  A.Message(string.format('  %-18s %5d x  %8.1f ms  avg %6.2f  max %6.2f  %7.0f KB',l,st.n,st.ms,st.ms/st.n,st.max,st.kb))
 end
end
function Perf.Stop()
 if not Perf.on then return end
 Perf.Report()
 for i=#Perf.orig,1,-1 do local o=Perf.orig[i];o[1][o[2]]=o[3] end
 Perf.orig={};Perf.on=false;A.Message(A.T('perf.off'))
end
function Perf.Command(arg)
 if arg=='report' then if Perf.on then Perf.Report() else A.Message(A.T('perf.idle')) end
 elseif Perf.on then Perf.Stop() else Perf.Start() end
end
SLASH_DYNAMICPLANNER1='/dynplan'
SlashCmdList.DYNAMICPLANNER=function(msg)
 local cmd,arg=(msg or ''):lower():match('^%s*(%S*)%s*(%S*)')
 if cmd=='perf' then Perf.Command(arg)
 elseif cmd=='analyzer' or cmd=='analisador' or cmd=='ana' then A.OpenAnalyzer()
 else A.Toggle() end
end
