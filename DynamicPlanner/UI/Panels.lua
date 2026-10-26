local _, A = ...
local U=A.UI
local SPV_CATS={'heal','raiddr','raidmob','raidutil','externals','throughput','mobility','utility','defensives','cc','items'}
U.SPV_CATS=SPV_CATS
local function popover(parent,w,h)
 local f=CreateFrame('Frame',nil,parent);U.Surface(f,'panel','border',10);f:SetSize(w,h);f:SetFrameStrata('DIALOG');f:EnableMouse(true);f:Hide()
 f:SetScript('OnShow',function(self) self:RegisterEvent('GLOBAL_MOUSE_DOWN') end)
 f:SetScript('OnHide',function(self) self:UnregisterEvent('GLOBAL_MOUSE_DOWN') end)
 f:SetScript('OnEvent',function(self)
  if self:IsMouseOver() or (self.anchor and self.anchor:IsMouseOver()) then return end
  if self.keepOpen and self.keepOpen() then return end
  self:Hide()
 end)
 f:EnableKeyboard(true);U.Propagate(f,true)
 f:SetScript('OnKeyDown',function(self,key) if key=='ESCAPE' then U.Propagate(self,false);self:Hide() else U.Propagate(self,true) end end)
 f.pool=U.Pool(f)
 return f
end
local function caption(pool,text,x,y)
 local c=pool:get();c:SetBackdrop(nil);c:EnableMouse(false);c:SetPoint('TOPLEFT',x,-y);c:SetSize(300,16)
 c.text:ClearAllPoints();c.text:SetPoint('LEFT',0,0);U.Font(c.text,11,'textMedium');c.text:SetTextColor(U.Color('ink-3'));c.text:SetText(text)
 return c
end
local function switchRow(pool,label,on,x,y,w,fn,sub)
 local r=pool:get();r:SetPoint('TOPLEFT',x,-y);r:SetSize(w,sub and 40 or 32);U.Radius(r,6);r:SetBackdropColor(0,0,0,0);r:SetBackdropBorderColor(0,0,0,0)
 r.text:ClearAllPoints();r.text:SetPoint('TOPLEFT',8,sub and -6 or -9);r.text:SetPoint('RIGHT',-52,0);U.Font(r.text,13);r.text:SetText(label)
 if sub then if not r.count then r.count=U.Text(r);U.Line(r.count) end;r.count:ClearAllPoints();r.count:SetPoint('TOPLEFT',8,-23);r.count:SetPoint('RIGHT',-52,0);U.Font(r.count,11);r.count:SetTextColor(U.Color('ink-3'));r.count:SetText(sub);r.count:Show() end
 local track=pool:get();track:SetSize(32,18);track:SetPoint('RIGHT',r,'RIGHT',-8,0);track:EnableMouse(false);track:SetFrameLevel(r:GetFrameLevel()+1);U.Radius(track,4)
 track:SetBackdropColor(U.Color(on and 'ink' or 'panel-2'));track:SetBackdropBorderColor(U.Color(on and 'ink' or 'line'))
 local knob=pool:get();knob:SetSize(12,12);knob:SetPoint('LEFT',track,'LEFT',on and 17 or 3,0);knob:EnableMouse(false);knob:SetFrameLevel(r:GetFrameLevel()+2);U.Radius(knob,3)
 knob:SetBackdropColor(U.Color(on and 'ground' or 'ink-3'));knob:SetBackdropBorderColor(0,0,0,0)
 r:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3')) end);r:SetScript('OnLeave',function(self) self:SetBackdropColor(0,0,0,0) end)
 r:SetScript('OnClick',function() if A.Allowed() then fn(not on) end end)
 return r
end
local function catsOff() A.view.catsOff=A.view.catsOff or {};return A.view.catsOff end
local function migrateCategory()
 if A.view.category and A.view.category~='all' then
  local keep=A.view.category;local off={};for _,c in ipairs(SPV_CATS) do if c~=keep then off[c]=true end end;A.view.catsOff=off
 end
 A.view.category='all'
end
function U.FiltersDirty()
 local v=A.view;if (v.preset or 'essential')~='essential' or v.showAll or v.cvMarks==false or v.cvPersonals then return true end
 for _ in pairs(v.catsOff or {}) do return true end
 return false
end
function U.ResetFilters()
 A.view.catsOff=nil;A.view.category='all';A.view.preset='essential';A.view.showAll=false;A.view.cvMarks=nil;A.view.cvPersonals=nil
 U.rowsDirty=true;U.Render()
end
local function applyFilters() U.rowsDirty=true;U.Render() end
function U.CreateFilters(win)
 local f=popover(win,404,300);U.filters=f;f.tab='spells'
 f.title=U.Label(f,'',16,-16,14,'textMedium')
 f.reset=U.Button(f,'',0,0,0,function() U.ResetFilters() end,{key='fl.reset',height=24});f.reset:ClearAllPoints();f.reset:SetPoint('TOPRIGHT',-14,-12)
 f.tabs={}
 for _,t in ipairs({{'spells','fl.tSpells'},{'boss','fl.tBoss'},{'phases','fl.tPhases'}}) do
  local key=t[1];f.tabs[key]=U.Button(f,'',0,-46,0,function() f.tab=key;U.DrawFilters() end,{key=t[2],height=26})
 end
 U.presetButtons={}
 for _,key in ipairs({'essential','all','clear'}) do U.presetButtons[key]=U.Button(f,'',0,0,0,function() A.view.preset=key;applyFilters() end,{key='pb.'..key,height=26}) end
 f.all=U.Button(f,'',0,0,0,function() A.view.catsOff={};applyFilters() end,{key='keys.all',height=24})
 f.none=U.Button(f,'',0,0,0,function() local off={};for _,c in ipairs(SPV_CATS) do off[c]=true end;A.view.catsOff=off;applyFilters() end,{key='fl.none',height=24})
end
function U.ToggleFilters(anchor)
 local f=U.filters;if f:IsShown() then f:Hide();return end
 migrateCategory();f.anchor=anchor;f:ClearAllPoints();f:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-6);f:Show();U.DrawFilters()
end
local function catCounts()
 local shown,all={},{}
 for _,row in ipairs(U.RowsFor and U.RowsFor() or {}) do local s=row.spell and row.spell.id and A.CD[row.spell.id];if s and not row.everyone then shown[s.cat]=shown[s.cat] or {};shown[s.cat][s.id]=true end end
 for _,s in ipairs(A.Cooldowns) do if not s.hidden and not s.memberOnly then
  for _,p in ipairs(A.model.plan.roster or {}) do if p.active and A.Model.canCast(p,s) then all[s.cat]=all[s.cat] or {};all[s.cat][s.id]=true;break end end
 end end
 local function n(t) local k=0;for _ in pairs(t or {}) do k=k+1 end;return k end
 return function(cat) return n(shown[cat]),n(all[cat]) end
end
function U.DrawFilters()
 local f=U.filters;if not f or not f:IsShown() then return end
 local pool=f.pool;pool:release()
 f.title:SetText(A.T('fl.btn'))
 f.reset:SetEnabled(U.FiltersDirty());f.reset.text:SetTextColor(U.Color(U.FiltersDirty() and 'ink' or 'ink-3'))
 local x=16;for _,key in ipairs({'spells','boss','phases'}) do local b=f.tabs[key];b:ClearAllPoints();b:SetPoint('TOPLEFT',x,-46);x=x+b:GetWidth()+4;U.Active(b,f.tab==key) end
 local W=f:GetWidth()-32;local y=86
 for _,b in pairs(U.presetButtons) do b:Hide() end;f.all:Hide();f.none:Hide()
 if f.tab=='spells' then
  caption(pool,A.T('pb.title'),16,y);y=y+20
  U.Flow({U.presetButtons.essential,U.presetButtons.all,U.presetButtons.clear},16,-y,4)
  for key,b in pairs(U.presetButtons) do b:Show();U.Active(b,(A.view.preset or 'essential')==key) end
  y=y+38
  caption(pool,A.T('fl.spells'),16,y)
  f.none:Show();f.all:Show();f.none:ClearAllPoints();f.none:SetPoint('TOPRIGHT',-16,-(y-4));f.all:ClearAllPoints();f.all:SetPoint('RIGHT',f.none,'LEFT',-4,0)
  y=y+28
  local count=catCounts();local off=catsOff();local tw=(W-8)/2
  for i,cat in ipairs(SPV_CATS) do
   local col=(i-1)%2;local on=not off[cat];local n,all=count(cat)
   local t=pool:get();t:SetPoint('TOPLEFT',16+col*(tw+8),-y);t:SetSize(tw,40);U.Radius(t,6)
   t:SetBackdropColor(U.Color(on and 'panel-2' or 'ground'));t:SetBackdropBorderColor(U.ColorA(on and 'ink' or 'line',on and 0.45 or 1))
   t.text:ClearAllPoints();t.text:SetPoint('TOPLEFT',10,-6);t.text:SetPoint('RIGHT',-8,0);U.Font(t.text,12,'textMedium');t.text:SetTextColor(U.Color(on and 'ink' or 'ink-3'));t.text:SetText(A.T('cat.'..cat))
   if not t.count then t.count=U.Text(t);U.Line(t.count) end
   t.count:ClearAllPoints();t.count:SetPoint('TOPLEFT',10,-22);U.Font(t.count,11);t.count:SetTextColor(U.Color('ink-3'));t.count:SetText(on and A.T('fl.catN',{n=n,all=all}) or A.T('fl.none'));t.count:Show()
   t:SetScript('OnClick',function() local o=catsOff();o[cat]=on or nil;applyFilters() end)
   t:SetScript('OnEnter',function(self) self:SetBackdropBorderColor(U.ColorA('ink',0.7)) end)
   t:SetScript('OnLeave',function(self) self:SetBackdropBorderColor(U.ColorA(on and 'ink' or 'line',on and 0.45 or 1)) end)
   if col==1 or i==#SPV_CATS then y=y+48 end
  end
 elseif f.tab=='boss' then
  caption(pool,A.T('bm.title'),16,y);y=y+22
  switchRow(pool,A.T('bm.all'),A.view.showAll and true or false,8,y,W+16,function(v) A.view.showAll=v;applyFilters() end);y=y+34
  switchRow(pool,A.T('cv.marks'),A.view.cvMarks~=false,8,y,W+16,function(v) A.view.cvMarks=v and nil or false;applyFilters() end);y=y+34
  switchRow(pool,A.T('cv.personalsToggle'),A.view.cvPersonals and true or false,8,y,W+16,function(v) A.view.cvPersonals=v or nil;applyFilters() end);y=y+40
 else
  caption(pool,A.T('fl.phases'),16,y);y=y+22
  for _,p in ipairs(A.model.phases) do
   local r=pool:get();r:SetPoint('TOPLEFT',16,-y);r:SetSize(W,30);U.Radius(r,6);r:SetBackdropColor(U.Color(p.intermission and 'ground-2' or 'panel-2'));r:SetBackdropBorderColor(U.Color('line'))
   local chip=pool:get();chip:SetSize(34,20);chip:SetPoint('LEFT',r,'LEFT',6,0);chip:EnableMouse(false);chip:SetFrameLevel(r:GetFrameLevel()+1);U.Radius(chip,4)
   chip:SetBackdropColor(U.ColorA(p.intermission and 'tl-intermission' or 'tl-phase',0.9));chip:SetBackdropBorderColor(0,0,0,0)
   chip.text:ClearAllPoints();chip.text:SetPoint('CENTER');chip.text:SetJustifyH('CENTER');U.Font(chip.text,11,'mono');chip.text:SetTextColor(U.Color('ground'));chip.text:SetText(tostring(p.id))
   r.text:ClearAllPoints();r.text:SetPoint('LEFT',48,0);r.text:SetPoint('RIGHT',-110,0);U.Font(r.text,12);r.text:SetText((p.name or '')..(p.intermission and '  ('..A.T('addon.intermission')..')' or ''))
   if not r.count then r.count=U.Text(r);U.Line(r.count) end
   r.count:ClearAllPoints();r.count:SetPoint('RIGHT',-10,0);U.Font(r.count,11,'mono');r.count:SetTextColor(U.Color('ink-2'));r.count:SetText(U.Time(p.start)..' - '..U.Time(p['end']));r.count:Show()
   r:SetScript('OnClick',function() A.view.phase=p.id;U.ZoomTo(p.start-2,p['end']-p.start+4);U.Render() end)
   r:SetScript('OnEnter',function(self) self:SetBackdropBorderColor(U.ColorA('ink',0.5)) end);r:SetScript('OnLeave',function(self) self:SetBackdropBorderColor(U.Color('line')) end)
   y=y+34
  end
  if not (A.PhaseMaps[A.boss.id] or {}).confirmed then
   local n=caption(pool,A.T('addon.phasesUnconfirmed'),16,y+4);n:SetSize(W,30);n.text:SetWidth(W);n.text:SetWordWrap(true);if n.text.SetMaxLines then n.text:SetMaxLines(2) end;y=y+36
  end
 end
 f:SetHeight(y+12)
end
local function M_(k) return A.T('keys.m.'..k) end
local function T_(k) return A.T('keys.t.'..k) end
local SHORTCUTS={
 {'top','keys.place','keys.placeHint',function() return M_('click')..' '..T_('spellRow') end,'keys.kw.place'},
 {'top','keys.move','keys.moveHint',function() return M_('drag')..' '..T_('cast') end,'keys.kw.move'},
 {'top','keys.del',nil,function() return M_('rclick')..' '..T_('cast')..'  '..A.T('keys.or')..'  Delete' end,'keys.kw.del'},
 {'top','keys.undo',nil,function() return 'Ctrl+Z' end,'keys.kw.undo'},
 {'top','keys.redo',nil,function() return 'Ctrl+Y' end,'keys.kw.redo'},
 {'top','keys.zoom',nil,function() return 'Ctrl+'..M_('wheel')..'  '..A.T('keys.or')..'  + / -' end,'keys.kw.zoom'},
 {'top','keys.help',nil,function() return '?' end,'keys.kw.help'},
 {'top','pv.menu',nil,function() return 'N' end,'pv.kw'},
 {'top','ana.keys','ana.keysHint',function() return '/dynplan analyzer' end,'ana.keysKw'},
 {'view','keys.pan','keys.panHint',function() return 'Shift+'..M_('wheel')..'  '..A.T('keys.or')..'  '..A.T('keys.k.Arrows') end,'keys.kw.pan'},
 {'view','keys.pan',nil,function() return M_('drag')..' '..T_('bossTrack')..'  '..A.T('keys.or')..'  '..M_('mdrag') end,'keys.kw.pan'},
 {'view','keys.zoom',nil,function() return 'Ctrl+'..M_('wheel')..'  '..A.T('keys.or')..'  + / -' end,'keys.kw.zoom'},
 {'view','keys.fit',nil,function() return '0  '..A.T('keys.or')..'  '..T_('fitBtn') end},
 {'view','keys.phase','keys.phaseHint',function() return M_('click')..' '..T_('phaseChip') end},
 {'cds','keys.place','keys.placeHint',function() return M_('click')..' '..T_('spellRow') end,'keys.kw.place'},
 {'cds','keys.picker',nil,function() return M_('click')..' '..T_('otherRow') end},
 {'cds','keys.move','keys.moveHint',function() return M_('drag')..' '..T_('cast') end,'keys.kw.move'},
 {'cds','keys.settings',nil,function() return 'Alt+'..M_('rclick')..' '..T_('cast') end,'keys.kw.settings'},
 {'cds','ctx.dup',nil,function() return 'Shift+'..M_('rclick')..' '..T_('cast') end},
 {'cdsSel','keys.marquee',nil,function() return M_('drag')..' '..T_('empty') end,'keys.kw.marquee'},
 {'cdsSel','keys.addSel',nil,function() return 'Ctrl+'..M_('drag') end},
 {'cdsSel','keys.allSpell',nil,function() return 'Ctrl+Shift+'..M_('click')..' '..T_('cast') end},
 {'cdsSel','keys.bulk','keys.bulkHint',function() return M_('drag')..' '..T_('cast') end},
 {'cdsSel','keys.nudge',nil,function() return 'Alt+'..A.T('keys.k.Arrows') end},
 {'cdsSel','keys.nudge5',nil,function() return 'Shift+Alt+'..A.T('keys.k.Arrows') end},
 {'cdsSel','keys.del',nil,function() return 'Delete' end,'keys.kw.del'},
 {'cdsSel','keys.ctx',nil,function() return 'Shift+'..M_('rclick')..' '..T_('cast') end},
 {'boss','keys.hover',nil,function() return M_('hover')..' '..T_('bossCast') end,'keys.kw.hit'},
 {'boss','addon.keysBossAlert',nil,function() return M_('rclick')..' '..T_('bossTrack') end},
 {'roster','keys.frames',nil,function() return M_('click')..' '..T_('gridBtn') end,'keys.kw.frames'},
 {'roster','keys.framesPick',nil,function() return M_('drag')..' '..T_('card') end},
 {'roster','keys.rows',nil,function() return M_('click')..' '..T_('player') end},
 {'roster','keys.fold',nil,function() return M_('click')..' '..T_('chevron') end},
 {'roster','keys.foldAll','keys.foldAllHint',function() return 'Alt+'..M_('click')..' '..T_('chevron') end},
 {'roster','keys.soloEye','keys.soloEyeHint',function() return 'Alt+'..M_('click')..' '..T_('eye') end},
 {'notes','keys.import',nil,function() return M_('click')..' '..T_('importBtn') end,'keys.kw.import'},
 {'notes','keys.copy',nil,function() return M_('click')..' '..T_('copyBtn') end,'keys.kw.copy'},
 {'notes','addon.sendNsrt',nil,function() return M_('click')..' '..A.T('addon.sendNsrt') end,'keys.kw.copy'},
 {'notes','pl.aria',nil,function() return M_('click')..' '..A.T('pl.aria') end},
 {'notes','addon.share','addon.shareTip',function() return M_('click')..' '..A.T('addon.share') end},
 {'boss','fl.coverage','addon.cvTip',function() return M_('click')..' '..A.T('fl.coverage') end,'keys.kw.hit'},
}
local GROUPS={'top','view','cds','cdsSel','boss','roster','notes'}
U.SHORTCUTS=SHORTCUTS
local function matches(s,q)
 if q=='' then return true end
 local hay=(A.T(s[2])..' '..(s[3] and A.T(s[3]) or '')..' '..s[4]()..' '..(s[5] and A.T(s[5]) or '')):lower()
 for word in q:lower():gmatch('%S+') do if not hay:find(word,1,true) then return false end end
 return true
end
function U.ShortcutsFor(group,q)
 local out,seen={}, {}
 for _,s in ipairs(SHORTCUTS) do
  if (q~='' or s[1]==group) and matches(s,q) then
   local key=s[2]..s[4]();if not seen[key] then seen[key]=true;out[#out+1]=s end
  end
 end
 return out
end
function U.Shortcuts()
 if not A.Allowed() then return end
 local f=U.keys
 if not f then
  f=popover(U.window,700,470);U.keys=f;f:SetPoint('CENTER');f.group='top'
  f.title=U.Label(f,'',18,-18,16,'display')
  f.lead=U.Label(f,'',18,-46,12);f.lead:SetTextColor(U.Color('ink-3'))
  local close=U.Button(f,'',0,0,0,function() f:Hide() end,{key='addon.close',always=true,height=26});close:ClearAllPoints();close:SetPoint('TOPRIGHT',-14,-14)
  local box=CreateFrame('EditBox',nil,f);U.Surface(box,'ground-2','line',6);box:SetPoint('TOPLEFT',18,-72);box:SetSize(664,30);U.Font(box,13);box:SetAutoFocus(false);box:SetTextInsets(10,10,0,0)
  box:SetScript('OnTextChanged',function() U.DrawShortcuts() end);box:SetScript('OnEscapePressed',function() if box:GetText()~='' then box:SetText('') else box:ClearFocus();f:Hide() end end)
  box:SetScript('OnEnterPressed',function() box:ClearFocus() end)
  f.box=box;f.groups={}
  for i,g in ipairs(GROUPS) do f.groups[g]=U.Button(f,'',18,-114-(i-1)*34,170,function() f.group=g;f.box:SetText('');U.DrawShortcuts() end,{key='keys.g.'..g,fixed=true,height=30});f.groups[g].text:SetJustifyH('LEFT') end
  f.count=U.Label(f,'',18,0,11);f.count:ClearAllPoints();f.count:SetPoint('BOTTOMLEFT',18,16);f.count:SetTextColor(U.Color('ink-3'))
 end
 if f:IsShown() then f:Hide();return end
 f.box:SetText('');f:Show();U.DrawShortcuts()
end
function U.DrawShortcuts()
 local f=U.keys;if not f or not f:IsShown() then return end
 local pool=f.pool;pool:release()
 f.title:SetText(A.T('keys.title'));f.lead:SetText(A.T('addon.keysLead'))
 local q=f.box:GetText() or ''
 for g,b in pairs(f.groups) do U.Active(b,q=='' and f.group==g) end
 local list=U.ShortcutsFor(f.group,q)
 local x,y,w=204,114,478
 caption(pool,q~='' and A.T('keys.allResults') or A.T('keys.g.'..f.group),x,y);y=y+22
 if #list==0 then local c=caption(pool,A.T('keys.none',{q=q}),x,y);c:SetSize(w,20);c.text:SetTextColor(U.Color('ink-2')) end
 for i,s in ipairs(list) do
  if y>440 then break end
  local r=pool:get();r:SetPoint('TOPLEFT',x,-y);r:SetSize(w,s[3] and 40 or 30);U.Radius(r,6);r:SetBackdropColor(U.Color(i%2==1 and 'panel-2' or 'panel'));r:SetBackdropBorderColor(0,0,0,0);r:EnableMouse(false)
  r.text:ClearAllPoints();r.text:SetPoint('TOPLEFT',10,s[3] and -6 or -8);r.text:SetPoint('RIGHT',-210,0);U.Font(r.text,13);r.text:SetText(A.T(s[2]))
  if s[3] then if not r.count then r.count=U.Text(r);U.Line(r.count) end;r.count:ClearAllPoints();r.count:SetPoint('TOPLEFT',10,-23);r.count:SetPoint('RIGHT',-210,0);U.Font(r.count,11);r.count:SetTextColor(U.Color('ink-3'));r.count:SetText(A.T(s[3]));r.count:Show() end
  if not r.ilvl then r.ilvl=U.Text(r);U.Line(r.ilvl) end
  r.ilvl:ClearAllPoints();r.ilvl:SetPoint('RIGHT',-10,0);r.ilvl:SetWidth(196);r.ilvl:SetJustifyH('RIGHT');U.Font(r.ilvl,12,'mono');r.ilvl:SetTextColor(U.Color('ink-2'));r.ilvl:SetText(s[4]());r.ilvl:Show()
  y=y+(s[3] and 44 or 34)
 end
 f.count:SetText(A.T('keys.count',{n=#list,total=#SHORTCUTS}))
end
function U.CoverColor(hit)
 local cv=hit.cv
 if cv.state=='covered' then
  for _,l in ipairs({cv.mitigate,cv.move}) do for _,e in ipairs(l) do if A.Model.cvCounts(e.x) and e.x.who and e.x.who.classToken and A.Theme.colors['class-'..e.x.who.classToken] then return 'class-'..e.x.who.classToken end end end
  return 'tl-cv-ok'
 end
 return cv.state=='healed' and 'tl-cv-heal' or 'tl-conflict'
end
local function who(e) return e.x.who and e.x.who.name or e.x.a.tag end
local function entry(e)
 local s=e.x.c.name..' ('..who(e)..')'
 if e.x.recharging then s=s..', '..A.T('rs.badge.recharging') elseif e.x.bench then s=s..', '..A.T('rs.badge.bench') end
 return s
end
function U.CoverText(hit)
 local cv=hit.cv;local out={}
 if cv.state=='covered' then out[#out+1]='|cff59c48a'..(hit.win and A.T('cv.coveredFor',{a=math.floor(cv.covered+0.5),b=math.floor(cv.len+0.5),p=math.floor(cv.share*100+0.5)}) or A.T('cv.covered'))..'|r'
 elseif cv.state=='healed' then out[#out+1]='|cffe6b450'..A.T('cv.healOnly')..'|r'
 elseif cv.state=='quiet' then out[#out+1]=A.T('cv.noneMinor')
 else out[#out+1]='|cfff34455'..A.T(hit.win and 'cv.uncoveredWin' or 'cv.uncovered')..'|r' end
 for _,g in ipairs({{'mitigate','cv.mitigation'},{'move','cv.movement'},{'recover','cv.healing'},{'personal','cv.personal'}}) do
  local l=cv[g[1]];if #l>0 then local names={};for i,e in ipairs(l) do if i<=4 then names[#names+1]=entry(e) end end
   local more=#l>4 and ', '..A.T('cv.more',{n=#l-4}) or '';out[#out+1]=A.T(g[2])..': '..table.concat(names,', ')..more end
 end
 if hit.low then out[#out+1]='|cff8a7f8d'..A.T('cv.lowConf')..'|r' end
 return table.concat(out,'\n')
end
local RANK={none=1,healed=2,covered=3}
function U.CoverageInView()
 local hits=U.cvHits or A.Model.coverage(A.boss,A.model.plan,A.model.phases,A.CD,{personals=A.view.cvPersonals})
 local a,b=A.view.start,A.view.start+A.view.span;local out={};local none,heal=0,0
 for _,h in ipairs(hits) do if h.cv.state~='quiet' and (h.e or h.t)>=a and h.t<=b then out[#out+1]=h;if h.cv.state=='none' then none=none+1 elseif h.cv.state=='healed' then heal=heal+1 end end end
 table.sort(out,function(p,q) if RANK[p.cv.state]~=RANK[q.cv.state] then return RANK[p.cv.state]<RANK[q.cv.state] end;return p.t<q.t end)
 return out,none,heal
end
local suggestCache={}
local function suggestion(hit)
 local ver=tostring(A.model.plan)..'|'..#A.model.undo..'|'..#A.model.redo
 if suggestCache.ver~=ver then suggestCache={ver=ver} end
 local key=hit.cast or hit.win
 if suggestCache[key]==nil then suggestCache[key]=A.Model.suggestCover(A.model.plan,A.model.phases,A.CD,hit) or false end
 return suggestCache[key] or nil
end
function U.PlaceCover(s)
 if not A.Allowed() or not s then return end
 A.Edit(function(plan) local a={tag=s.player.name,spellId=s.spell.id,extra={}};A.Model.move(a,s.t,A.model.phases);plan.lines[#plan.lines+1]=a end)
 A.Message(A.T('cv.placed',{spell=s.spell.name,name=s.player.name,t=U.Time(s.t)}))
end
function U.CreateCoverage(win)
 local f=popover(win,560,200);U.coverage=f;f.offset=0
 f.title=U.Label(f,'',16,-16,14,'textMedium')
 f.sub=U.Label(f,'',16,-38,11);f.sub:SetTextColor(U.Color('ink-3'))
 f:EnableMouseWheel(true);f:SetScript('OnMouseWheel',function(_,d) f.offset=math.max(0,f.offset-d*3);U.DrawCoverage() end)
end
function U.ToggleCoverage(anchor)
 local f=U.coverage;if f:IsShown() then f:Hide();return end
 f.anchor=anchor;f.offset=0;f:ClearAllPoints();f:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-6);f:Show();U.DrawCoverage()
end
function U.DrawCoverage()
 local f=U.coverage;if not f or not f:IsShown() then return end
 local pool=f.pool;pool:release()
 local list,none,heal=U.CoverageInView()
 f.title:SetText(A.T('fl.coverage')..'  '..U.Time(A.view.start)..' - '..U.Time(A.view.start+A.view.span))
 f.sub:SetText(A.T('addon.cvSummary',{n=#list,none=none,heal=heal}))
 local MAX=10;f.offset=math.max(0,math.min(f.offset,math.max(0,#list-MAX)));local y=60;local W=f:GetWidth()-32
 if #list==0 then local c=caption(pool,A.T('rs.noHits'),16,y);c.text:SetTextColor(U.Color('ink-2'));y=y+28 end
 for i=f.offset+1,math.min(#list,f.offset+MAX) do
  local hit=list[i];local cv=hit.cv
  local r=pool:get();r:SetPoint('TOPLEFT',16,-y);r:SetSize(W,34);U.Radius(r,6);r:SetBackdropColor(U.Color(i%2==1 and 'panel-2' or 'panel'));r:SetBackdropBorderColor(0,0,0,0)
  local bar=pool:get();bar:SetSize(3,24);bar:SetPoint('LEFT',r,'LEFT',4,0);bar:EnableMouse(false);bar:SetFrameLevel(r:GetFrameLevel()+1);U.Radius(bar,0);bar:SetBackdropColor(U.Color(U.CoverColor(hit)));bar:SetBackdropBorderColor(0,0,0,0)
  r.text:ClearAllPoints();r.text:SetPoint('LEFT',14,0);r.text:SetWidth(46);U.Font(r.text,12,'mono');r.text:SetTextColor(U.Color('ink-2'));r.text:SetText(U.Time(hit.t))
  if not r.count then r.count=U.Text(r);U.Line(r.count) end
  local state=cv.state=='covered' and A.T('rs.state.covered') or cv.state=='healed' and A.T('rs.state.healed') or A.T('rs.state.none')
  local by={};for _,l in ipairs({cv.mitigate,cv.move,cv.recover}) do for _,e in ipairs(l) do if A.Model.cvCounts(e.x) then by[#by+1]=e.x.c.name end end end
  r.count:ClearAllPoints();r.count:SetPoint('LEFT',64,0);r.count:SetPoint('RIGHT',-150,0);U.Font(r.count,12);r.count:SetTextColor(U.Color('ink'))
  r.count:SetText(hit.ab.name..'  |cff8a7f8d'..state..(#by>0 and ': '..table.concat(by,', ') or '')..'|r');r.count:Show()
  r:SetScript('OnEnter',function(self) self:SetBackdropBorderColor(U.ColorA('ink',0.4));U.Tooltip(self,hit.ab.name..'  '..U.Time(hit.t)..'\n'..U.CoverText(hit)) end)
  r:SetScript('OnLeave',function(self) self:SetBackdropBorderColor(0,0,0,0);GameTooltip:Hide() end)
  r:SetScript('OnClick',function() A.view.start=hit.t-A.view.span/2;U.Render() end)
  if cv.state~='covered' then
   local s=suggestion(hit)
   if s then
    local b=pool:get();b:SetHeight(24);b:SetPoint('RIGHT',r,'RIGHT',-5,0);b:SetFrameLevel(r:GetFrameLevel()+2);U.Radius(b,6);b:SetBackdropColor(U.Color('panel-2'));b:SetBackdropBorderColor(U.Color('line'))
    b.icon:SetTexture(U.Icon(s.spell.id));b.icon:ClearAllPoints();b.icon:SetPoint('LEFT',4,0);b.icon:SetSize(16,16);b.icon:Show()
    b.text:ClearAllPoints();b.text:SetPoint('LEFT',24,0);U.Font(b.text,11,'textMedium');b.text:SetText(A.T('cv.place',{t=U.Time(s.t)}));b:SetWidth(b.text:GetUnboundedStringWidth()+32)
    b:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));U.Tooltip(self,s.spell.name..' ('..s.player.name..')  '..U.Time(s.t)) end)
    b:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('panel-2'));GameTooltip:Hide() end)
    b:SetScript('OnClick',function() U.PlaceCover(s) end)
   else
    local n=pool:get();n:SetBackdrop(nil);n:EnableMouse(false);n:SetSize(140,24);n:SetPoint('RIGHT',r,'RIGHT',-6,0);n:SetFrameLevel(r:GetFrameLevel()+2)
    n.text:ClearAllPoints();n.text:SetPoint('RIGHT',0,0);n.text:SetJustifyH('RIGHT');U.Font(n.text,11);n.text:SetTextColor(U.Color('ink-3'));n.text:SetText(A.T('addon.cvNoneFree'))
   end
  end
  y=y+38
 end
 if #list>MAX then local c=caption(pool,A.T('addon.cvMore',{a=f.offset+1,b=math.min(#list,f.offset+MAX),n=#list}),16,y+2);y=y+22 end
 f:SetHeight(y+14)
end
local AN=A.Analyzer
local function anaKey()
 local n=UnitName and UnitName('player');local r=GetRealmName and GetRealmName()
 if type(n)=='string' and type(r)=='string' then return n..'-'..r end;return 'default'
end
function U.AnaFilter()
 A.db.anaFilter=A.db.anaFilter or {}
 local k=anaKey();local f=A.db.anaFilter[k];if not f then f={spells={},players={}};A.db.anaFilter[k]=f end
 f.spells=f.spells or {};f.players=f.players or {};return f
end
local function canonId(id) return (A.Aliases and A.Aliases[id]) or id end
function U.AnaSpellOn(id) if not id then return true end;local s=U.AnaFilter().spells;return not (s[id] or s[canonId(id)]) end
function U.AnaPlayerOn(n) if not n then return true end;return not U.AnaFilter().players[AN.Short(n):lower()] end
function U.AnaHidden() local f=U.AnaFilter();local n=0;for _ in pairs(f.spells) do n=n+1 end;for _ in pairs(f.players) do n=n+1 end;return n end
local function anaApply() if U.anaFilterBox and U.anaFilterBox:IsShown() then U.DrawAnaFilter() end;U.RenderAnalyzer() end
function U.AnaFilterReset() local f=U.AnaFilter();f.spells={};f.players={};anaApply() end
local function anaEntries(p,tab)
 local out={}
 if not p then return out end
 if tab=='spells' then
  local seen={};local order={raid=1,external=2,personal=3}
  local function add(id,cast,plan)
   local ty,cd=AN.CastType(id);if not cd then return end
   local e=seen[cd.id];if not e then e={id=cd.id,label=cd.name,cast=0,plan=0,ty=ty,key=cd.id,kind='spell'};seen[cd.id]=e;out[#out+1]=e end
   e.cast=e.cast+cast;e.plan=e.plan+plan
  end
  for _,c in ipairs(p.casts or {}) do add(c.id,1,0) end
  for _,x in ipairs(AN.Planned(p)) do add(x.spellId,0,1) end
  table.sort(out,function(a,b) if order[a.ty]~=order[b.ty] then return (order[a.ty] or 9)<(order[b.ty] or 9) end;return a.label<b.label end)
  for _,e in ipairs(out) do e.sub=A.T('ana.flt.counts',{c=e.cast,p=e.plan,t=A.T('ana.flt.ty.'..(e.ty or 'raid'))}) end
 elseif tab=='damage' then
  for _,e in ipairs(p.spells or {}) do out[#out+1]={id=e.id,label=AN.SpellName(e.id,e.name),sub=A.UI.Num(e.total),key=e.id,kind='spell'} end
 else
  for _,pl in ipairs(p.players or {}) do local r,g,b=U.Color('class-'..tostring(pl.c or ''));if not A.Theme.colors['class-'..tostring(pl.c or '')] then r,g,b=U.Color('ink') end
   out[#out+1]={label=AN.Short(pl.n),rgb={r,g,b},key=AN.Short(pl.n):lower(),kind='player',sub=A.UI.Num(pl.taken or 0)} end
  table.sort(out,function(a,b) return a.label<b.label end)
 end
 return out
end
local ANA_ROWS=12
function U.CreateAnaFilter(win)
 local f=popover(win,440,300);U.anaFilterBox=f;f.tab='spells';f.offset=0
 f.title=U.Label(f,'',16,-16,14,'textMedium')
 f.reset=U.Button(f,'',0,0,0,function() U.AnaFilterReset() end,{key='fl.reset',height=24});f.reset:ClearAllPoints();f.reset:SetPoint('TOPRIGHT',-14,-12)
 f.tabs={}
 for _,t in ipairs({{'spells','ana.flt.tSpells'},{'damage','ana.flt.tDamage'},{'players','ana.flt.tPlayers'}}) do
  local key=t[1];f.tabs[key]=U.Button(f,'',0,-46,0,function() f.tab=key;f.offset=0;U.DrawAnaFilter() end,{key=t[2],height=26})
 end
 f.all=U.Button(f,'',0,0,0,function() local fl=U.AnaFilter();for _,e in ipairs(anaEntries(AN.Selected(),f.tab)) do if e.kind=='spell' then fl.spells[e.key]=nil else fl.players[e.key]=nil end end;anaApply() end,{key='keys.all',height=24})
 f.none=U.Button(f,'',0,0,0,function() local fl=U.AnaFilter();for _,e in ipairs(anaEntries(AN.Selected(),f.tab)) do if e.kind=='spell' then fl.spells[e.key]=true else fl.players[e.key]=true end end;anaApply() end,{key='fl.none',height=24})
 f:EnableMouseWheel(true);f:SetScript('OnMouseWheel',function(_,d) f.offset=math.max(0,f.offset-d*2);U.DrawAnaFilter() end)
end
function U.ToggleAnaFilter(anchor)
 local f=U.anaFilterBox;if f:IsShown() then f:Hide();return end
 f.anchor=anchor;f:ClearAllPoints();f:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-6);f.offset=0;f:Show();U.DrawAnaFilter()
end
function U.DrawAnaFilter()
 local f=U.anaFilterBox;if not f or not f:IsShown() then return end
 local pool=f.pool;pool:release()
 f.title:SetText(A.T('ana.flt.title'))
 local dirty=U.AnaHidden()>0;f.reset:SetEnabled(dirty);f.reset.text:SetTextColor(U.Color(dirty and 'ink' or 'ink-3'))
 local x=16;for _,key in ipairs({'spells','damage','players'}) do local b=f.tabs[key];b:ClearAllPoints();b:SetPoint('TOPLEFT',x,-46);x=x+b:GetWidth()+4;U.Active(b,f.tab==key) end
 local W=f:GetWidth()-32;local y=86
 local list=anaEntries(AN.Selected(),f.tab);local fl=U.AnaFilter()
 caption(pool,A.T('ana.flt.cap.'..f.tab),16,y)
 f.none:ClearAllPoints();f.none:SetPoint('TOPRIGHT',-16,-(y-4));f.all:ClearAllPoints();f.all:SetPoint('RIGHT',f.none,'LEFT',-4,0)
 f.all:SetShown(#list>0);f.none:SetShown(#list>0)
 y=y+28
 if #list==0 then caption(pool,A.T('ana.flt.empty'),16,y);y=y+24 end
 local rows=math.ceil(#list/2);local maxOff=math.max(0,rows-ANA_ROWS);if f.offset>maxOff then f.offset=maxOff end
 local tw=(W-8)/2
 for i=f.offset*2+1,math.min(#list,(f.offset+ANA_ROWS)*2) do
  local e=list[i];local col=(i-1)%2;local on=(e.kind=='spell' and not fl.spells[e.key]) or (e.kind=='player' and not fl.players[e.key])
  local t=pool:get();t:SetPoint('TOPLEFT',16+col*(tw+8),-y);t:SetSize(tw,30);U.Radius(t,6);t.anaKey=e.key
  t:SetBackdropColor(U.Color(on and 'panel-2' or 'ground'));t:SetBackdropBorderColor(U.ColorA(on and 'ink' or 'line',on and 0.45 or 1))
  local tx=8;if e.id then t.icon:SetTexture(U.Icon(e.id));t.icon:SetSize(18,18);t.icon:ClearAllPoints();t.icon:SetPoint('LEFT',6,0);t.icon:SetDesaturated(not on);t.icon:Show();tx=30 end
  t.text:ClearAllPoints();t.text:SetPoint('LEFT',tx,0);t.text:SetWidth(tw-tx-78);U.Font(t.text,12,'textMedium');t.text:SetText(e.label or '')
  if e.rgb and on then t.text:SetTextColor(e.rgb[1],e.rgb[2],e.rgb[3]) else t.text:SetTextColor(U.Color(on and 'ink' or 'ink-3')) end
  if not t.count then t.count=U.Text(t);U.Line(t.count) end
  t.count:ClearAllPoints();t.count:SetPoint('RIGHT',-8,0);t.count:SetWidth(74);t.count:SetJustifyH('RIGHT');U.Font(t.count,10);t.count:SetTextColor(U.Color('ink-3'));t.count:SetText(on and (e.sub or '') or A.T('ana.flt.hidden'));t.count:Show()
  t:SetScript('OnClick',function() if e.kind=='spell' then fl.spells[e.key]=on or nil else fl.players[e.key]=on or nil end;anaApply() end)
  t:SetScript('OnEnter',function(self) self:SetBackdropBorderColor(U.ColorA('ink',0.7)) end)
  t:SetScript('OnLeave',function(self) self:SetBackdropBorderColor(U.ColorA(on and 'ink' or 'line',on and 0.45 or 1)) end)
  if col==1 or i==#list then y=y+34 end
 end
 if maxOff>0 then caption(pool,A.T('ana.flt.scroll',{a=f.offset*2+1,b=math.min(#list,(f.offset+ANA_ROWS)*2),n=#list}),16,y);y=y+20 end
 f:SetHeight(y+12)
end
