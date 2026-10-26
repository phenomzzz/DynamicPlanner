local _, A = ...
local U=A.UI
local NOTE_ICON='Interface\\Icons\\INV_Misc_Note_01'
local function hex(key)
 local r,g,b=U.Color(key);return string.format('|cff%02x%02x%02x',math.floor(r*255+0.5),math.floor(g*255+0.5),math.floor(b*255+0.5))
end
local function esc(s) return (tostring(s or ''):gsub('|','||')) end
local SEL={everyone='pv.sel.everyone',tank='pv.sel.tank',healer='pv.sel.healer',damager='pv.sel.dps',dps='pv.sel.dps',melee='pv.sel.melee',ranged='pv.sel.ranged'}
local function selectorLabel(tok)
 local t=tok:lower()
 if SEL[t] then return A.T(SEL[t]) end
 return A.T('ro.groupN',{n=t:match('%d+')})
end
local function spellName(id)
 local s=A.CD[id];if s and s.name then return s.name end
 if C_Spell and C_Spell.GetSpellName then local ok,n=pcall(C_Spell.GetSpellName,id);if ok and n and A.Public(n) then return n end end
 return 'Spell '..id
end
local function rosterColours()
 local out={}
 for _,p in ipairs(A.model.plan.roster or {}) do
  if p.name and p.classToken then local key='class-'..p.classToken;out[p.name:lower()]=key;out[(p.name:match('^[^%-]+') or p.name):lower()]=key end
 end
 return out
end
local function whoText(tag,colours)
 local parts,raid={},true
 for tok in tag:gmatch('%S+') do
  if A.Model.isSelector(tok) then parts[#parts+1]=hex('accent')..esc(selectorLabel(tok))..'|r'
  else raid=false;parts[#parts+1]=hex(colours[tok:lower()] or 'ink-2')..esc(tok)..'|r' end
 end
 return table.concat(parts,', '),raid
end
function U.PreviewModel()
 local out={phases={},unplaced={},kicks={},notes={},count=0,raid=0,left=0}
 local ok,text=A.ExportText()
 if not ok then out.err=tostring(text);out.raw='';return out end
 out.raw=text
 local include=A.ExportInclude()
 for _,a in ipairs(A.model.plan.lines) do if not include(a) then out.left=out.left+1 end end
 local p,err=A.NSRT.parse(text)
 if not p then out.err=tostring(err);return out end
 local byId={}
 for _,ph in ipairs(A.model.phases) do local g={phase=ph,lines={}};out.phases[#out.phases+1]=g;byId[tostring(ph.id)]=g end
 for _,a in ipairs(p.lines) do
  local g=byId[tostring(a.phase)]
  if g then g.lines[#g.lines+1]=a;out.count=out.count+1
   local raid=true;for tok in a.tag:gmatch('%S+') do if not A.Model.isSelector(tok) then raid=false end end
   if raid then out.raid=out.raid+1 end
  else out.unplaced[#out.unplaced+1]={a=a,why=A.T('pv.why.phase',{ph=a.phase})} end
 end
 for _,r in ipairs(p.rejected) do out.unplaced[#out.unplaced+1]={raw=r.raw,line=r.line,why=A.T('imp.why.'..r.reason)} end
 for _,g in ipairs(out.phases) do table.sort(g.lines,function(x,y) if x.time~=y.time then return x.time<y.time end;return x.order<y.order end) end
 for _,block in ipairs(p.kickBlocks) do
  for _,line in ipairs(block) do local l=line:gsub('^%s+',''):gsub('%s+$','');local low=l:lower();if l~='' and low~='intstart' and low~='intend' then out.kicks[#out.kicks+1]=l end end
 end
 for _,line in ipairs(p.notes) do out.notes[#out.notes+1]=line end
 return out
end
local function lineText(a,colours,phaseStart)
 local s={'  ',hex('ink'),U.Time(a.time),'|r  '}
 if phaseStart then s[#s+1]=hex('ink-3')..'('..A.T('pv.fight',{t=U.Time(phaseStart+a.time)})..')|r  ' end
 if a.spellId then
  s[#s+1]='|T'..tostring(U.Icon(a.spellId))..':16:16:0:0|t '..hex('ink')..esc(spellName(a.spellId))..'|r'
 else
  s[#s+1]='|T'..NOTE_ICON..':16:16:0:0|t '..hex('ink')..'"'..esc(a.text)..'"|r'
 end
 s[#s+1]='   '..(whoText(a.tag,colours))
 if a.spellId and a.text and a.text~='' then s[#s+1]='   '..hex('ink-2')..'"'..esc(a.text)..'"|r' end
 if a.extra and #a.extra>0 then
  local t={};for _,kv in ipairs(a.extra) do t[#t+1]=esc(kv[1])..': '..esc(kv[2]) end
  s[#s+1]='   '..hex('ink-3')..table.concat(t,', ')..'|r'
 end
 return table.concat(s)
end
function U.PreviewText(m)
 local out={}
 local function add(s) out[#out+1]=s end
 if m.err then add(hex('tl-conflict')..esc(A.T('pv.failed',{err=m.err}))..'|r');return table.concat(out,'\n') end
 local empty=m.count==0 and #m.unplaced==0 and #m.kicks==0 and #m.notes==0
 if empty then
  add(hex('ink-2')..A.T('pv.empty')..'|r')
  if m.left>0 then add('');add(hex('ink-3')..A.T('pv.left',{n=m.left})..'|r') end
  return table.concat(out,'\n')
 end
 add(hex('ink-2')..A.T(m.raid>0 and 'pv.lead' or 'pv.lead0',{n=m.count,raid=m.raid})..'|r')
 if m.left>0 then add(hex('ink-3')..A.T('pv.left',{n=m.left})..'|r') end
 local colours=rosterColours()
 for _,g in ipairs(m.phases) do
  if #g.lines>0 then
   add('');add(hex('ink')..A.T('pv.phase',{id=g.phase.id})..(g.phase.name and ', '..esc(g.phase.name) or '')..'|r  '..hex('ink-3')..'('..#g.lines..')|r')
   for _,a in ipairs(g.lines) do add(lineText(a,colours,(#m.phases>1 and tonumber(g.phase.id)~=1) and g.phase.start or nil)) end
  end
 end
 if #m.kicks>0 then
  add('');add(hex('ink')..A.T('pv.kicks')..'|r')
  for i,l in ipairs(m.kicks) do add('  '..hex('ink-3')..i..'.|r  '..(whoText(l,colours))) end
 end
 if #m.notes>0 then
  add('');add(hex('ink')..A.T('pv.notes')..'|r')
  for _,l in ipairs(m.notes) do add('  '..hex('ink-2')..esc(l)..'|r') end
 end
 if #m.unplaced>0 then
  add('');add(hex('tl-conflict')..A.T('pv.unplaced',{n=#m.unplaced})..'|r')
  for _,u in ipairs(m.unplaced) do
   local what=u.a and ('ph:'..u.a.phase..'  '..U.Time(u.a.time)..'  '..(u.a.spellId and spellName(u.a.spellId) or '"'..(u.a.text or '')..'"')..'  '..u.a.tag) or (A.T('pv.line',{n=u.line})..'  '..(u.raw or ''):sub(1,80))
   add('  '..hex('ink-2')..esc(what)..'|r  '..hex('ink-3')..esc(u.why)..'|r')
  end
 end
 return table.concat(out,'\n')
end
local function showMode(f,raw)
 f.raw=raw and true or false
 f.readScroll:SetShown(not f.raw);f.rawScroll:SetShown(f.raw)
 U.Active(f.readableTab,not f.raw);U.Active(f.rawTab,f.raw)
end
function U.RefreshPreview()
 local f=U.preview;if not f or not f:IsShown() then return end
 local m=U.PreviewModel();U.previewModel=m
 f.title:SetText(A.T('pv.title',{boss=A.boss.name}))
 f.body:SetText(U.PreviewText(m))
 f.body:SetHeight(math.max(20,(f.body:GetStringHeight() or 0)+8));f.readChild:SetHeight(f.body:GetHeight()+8)
 f.rawText=m.raw or '';f.edit:SetText(f.rawText);f.edit:SetCursorPosition(0)
 f.hint:SetText('')
end
function U.PreviewNote(raw)
 if not A.Allowed() or not U.window then return end
 local f=U.preview
 if not f then
  f=CreateFrame('Frame',nil,U.window);U.preview=f;U.Surface(f);f:SetSize(760,500);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:EnableMouse(true);f:Hide()
  f.title=U.Label(f,'',16,-16,16)
  f.rawTab=U.Button(f,A.T('pv.raw'),0,0,0,function() showMode(f,true) end,{key='pv.raw',height=26});f.rawTab:ClearAllPoints();f.rawTab:SetPoint('TOPRIGHT',-16,-12)
  f.readableTab=U.Button(f,A.T('pv.readable'),0,0,0,function() showMode(f,false) end,{key='pv.readable',height=26});f.readableTab:ClearAllPoints();f.readableTab:SetPoint('TOPRIGHT',f.rawTab,'TOPLEFT',-2,0)
  local rs=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate');rs:SetPoint('TOPLEFT',16,-54);rs:SetPoint('BOTTOMRIGHT',-36,56)
  local child=CreateFrame('Frame',nil,rs);child:SetSize(700,20);rs:SetScrollChild(child)
  local body=U.Text(child);U.Font(body,13);body:SetPoint('TOPLEFT',4,-4);body:SetWidth(692);body:SetJustifyH('LEFT');body:SetJustifyV('TOP');body:SetWordWrap(true)
  f.readScroll,f.readChild,f.body=rs,child,body
  local ws=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate');ws:SetPoint('TOPLEFT',16,-54);ws:SetPoint('BOTTOMRIGHT',-36,56)
  local edit=CreateFrame('EditBox',nil,ws);edit:SetMultiLine(true);U.Font(edit,12,'mono');edit:SetAutoFocus(false);edit:SetWidth(700);edit:SetHeight(360);edit:SetTextInsets(4,4,4,4);ws:SetScrollChild(edit)
  edit:SetScript('OnTextChanged',function(self,user) if user and self:GetText()~=f.rawText then self:SetText(f.rawText or '') end end)
  edit:SetScript('OnEscapePressed',function(self) self:ClearFocus();f:Hide() end)
  f.rawScroll,f.edit=ws,edit
  f.close=U.Button(f,A.T('addon.close'),16,-454,100,function() f:Hide() end,{key='addon.close',always=true})
  f.copy=U.Button(f,A.T('pv.copy'),0,0,0,function() showMode(f,true);f.edit:SetFocus();f.edit:HighlightText();f.hint:SetText(A.T('pv.copied')) end,{key='pv.copy'})
  f.copy:ClearAllPoints();f.copy:SetPoint('BOTTOMRIGHT',-16,16)
  f.hint=U.Label(f,'',0,0,11);f.hint:ClearAllPoints();f.hint:SetPoint('RIGHT',f.copy,'LEFT',-12,0);f.hint:SetTextColor(U.Color('ink-3'))
  f:EnableKeyboard(true);U.Propagate(f,true)
  f:SetScript('OnKeyDown',function(self,key) if key=='ESCAPE' then U.Propagate(self,false);self:Hide() else U.Propagate(self,true) end end)
  f:SetScript('OnHide',function() if f.edit then f.edit:ClearFocus() end end)
 end
 f:Show();showMode(f,raw);U.RefreshPreview()
end
function U.TogglePreview()
 if U.preview and U.preview:IsShown() then U.preview:Hide() else U.PreviewNote() end
end
