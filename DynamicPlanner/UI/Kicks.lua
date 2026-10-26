local _, A = ...
local U=A.UI
local M=A.Model
local LABELS_3429={'kk.l.unmarked','kk.l.marked','kk.l.p3unmarked','kk.l.p3marked','kk.l.p3w2unmarked','kk.l.p3w2marked'}
local CARD_W,CARD_H,PAD=300,392,16
local function label(k,i) if k.label and k.label~='' then return k.label end;if A.boss.id==3429 and LABELS_3429[i] then return A.T(LABELS_3429[i]) end;return A.T('kk.group',{n=i}) end
local function byName(n) for _,p in ipairs(A.model.plan.roster or {}) do if p.name==n then return p end end end
local function classHex(p) local r,g,b=U.Color(p and p.classToken and 'class-'..p.classToken or 'ink-2');return string.format('|cff%02x%02x%02x',r*255,g*255,b*255) end
local function edit(fn) A.Edit(function(plan) plan.kicks=plan.kicks or {};fn(plan.kicks) end);U.DrawKicks() end
local function interruptLabel(p)
 local it=M.interruptOf(p)
 if it then return it.name..', '..it.cd..' s' elseif it==false then return A.T('kk.noKick') else return A.T('kk.unknownKick') end
end
local function playerMenu(anchor,fn)
 local items={}
 local list={};for _,p in ipairs(A.model.plan.roster or {}) do list[#list+1]=p end
 table.sort(list,function(a,b) if a.active~=b.active then return a.active end;return a.name:lower()<b.name:lower() end)
 for _,p in ipairs(list) do
  local spec=A.SpecByID[p.specId]
  items[#items+1]={classHex(p)..p.name..'|r  |cff8a7f8d'..(spec and spec.name or '')..', '..interruptLabel(p)..(p.active and '' or ', '..A.T('kk.bench'))..'|r',function() fn(p.name) end}
 end
 U.Menu(anchor,items)
end
function U.Kicks()
 if not A.Allowed() then return end
 if not U.kicks then
  local f=CreateFrame('Frame',nil,U.window);U.Surface(f,'panel','border',10);f:SetSize(PAD*2+CARD_W*3+24,600);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:EnableMouse(true);f:SetToplevel(true)
  f.title=U.Label(f,'',PAD,-PAD,18,'display');f.sub=U.Label(f,'',PAD,-PAD-28,12);f.sub:SetTextColor(U.Color('ink-3'));f.sub:SetWidth(f:GetWidth()-PAD*2)
  f.close=U.Button(f,'',0,0,0,function() f:Hide() end,{key='addon.close'});f.close:ClearAllPoints();f.close:SetPoint('TOPRIGHT',-PAD,-PAD)
  f.copy=U.Button(f,'',0,0,0,function() local lines=M.kickLines(A.model.plan);if lines then U.Note(table.concat(lines,'\n'),true) end end,{key='kk.copy'});f.copy:ClearAllPoints();f.copy:SetPoint('RIGHT',f.close,'LEFT',-6,0)
  f.suggest=U.Button(f,'',0,0,0,function() U.SuggestKicks() end,{key='kk.suggest'});f.suggest:ClearAllPoints();f.suggest:SetPoint('RIGHT',f.copy,'LEFT',-6,0)
  f.add=U.Button(f,'',0,0,0,function() edit(function(ks) ks[#ks+1]={label='',phase='',players={},backups={}} end) end,{key='kk.add'});f.add:ClearAllPoints();f.add:SetPoint('RIGHT',f.suggest,'LEFT',-6,0)
  f.body=CreateFrame('Frame',nil,f);f.body:SetPoint('TOPLEFT',PAD,-86);f.body:SetPoint('BOTTOMRIGHT',-PAD,PAD);f.body:SetClipsChildren(true)
  f.pool=U.Pool(f.body);f.offset=0
  f:EnableMouseWheel(true);f:SetScript('OnMouseWheel',function(_,d) f.offset=math.max(0,f.offset-d*60);U.DrawKicks() end)
  f:EnableKeyboard(true);U.Propagate(f,true)
  f:SetScript('OnKeyDown',function(self,key) if key=='ESCAPE' then U.Propagate(self,false);self:Hide() else U.Propagate(self,true) end end)
  U.kicks=f
 end
 U.kicks:Show();U.RefreshLabels();U.DrawKicks()
end
function U.SuggestKicks()
 local r=M.suggestKicks(A.model.plan,A.boss.kicks or {},A.model.phases)
 if not r then A.Message(A.T('kk.noPool'));return end
 edit(function(ks) for i=#ks,1,-1 do ks[i]=nil end;for _,k in ipairs(r.kicks) do ks[#ks+1]=k end end)
 A.Message(r.late>0 and A.T('kk.suggestedLate',{n=r.late,total=r.total}) or A.T('kk.suggested',{total=r.total}))
end
local function small(f,pool,text,x,y,w,fn,tip)
 local b=pool:get();b:SetPoint('TOPLEFT',x,-y);b:SetSize(w,22);U.Radius(b,4);b:SetBackdropColor(U.Color('panel-2'));b:SetBackdropBorderColor(U.Color('line'))
 b.text:ClearAllPoints();b.text:SetPoint('CENTER');b.text:SetJustifyH('CENTER');U.Font(b.text,11,'textMedium');b.text:SetText(text)
 b:SetScript('OnClick',function(self) if A.Allowed() and fn then fn(self) end end)
 b:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));if tip then U.Tooltip(self,tip) end end);b:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('panel-2'));GameTooltip:Hide() end)
 return b
end
local function text(pool,s,x,y,w,size,color,font)
 local t=pool:get();t:SetPoint('TOPLEFT',x,-y);t:SetSize(w,(size or 12)+6);t:SetBackdrop(nil);t:EnableMouse(false)
 t.text:ClearAllPoints();t.text:SetPoint('LEFT',0,0);t.text:SetWidth(w);U.Font(t.text,size or 12,font or 'text');t.text:SetTextColor(U.Color(color or 'ink'));t.text:SetText(s);return t
end
local function cycle(k)
 if #k.players==0 then return A.T('kk.empty') end
 local uniq={};for _,n in ipairs(k.players) do uniq[n]=true end;local n=0;for _ in pairs(uniq) do n=n+1 end
 if n==1 then return A.T('kk.every',{name=k.players[1]}) end
 local parts={};for i=1,math.min(6,#k.players) do parts[#parts+1]=i..' '..k.players[i] end
 return A.T('kk.cycle',{list=table.concat(parts,', ')})
end
local function playerList(f,pool,k,ki,list,x,y)
 local names=k[list] or {}
 for i,n in ipairs(names) do
  local p=byName(n);local it=M.interruptOf(p);local warn=it==false or not p
  local row=pool:get();row:SetPoint('TOPLEFT',x,-y);row:SetSize(CARD_W-24,24);U.Radius(row,4);row:SetBackdropColor(U.Color('ground-2'));row:SetBackdropBorderColor(U.ColorA('tl-conflict',warn and 0.8 or 0));row:EnableMouse(false)
  row:SetAlpha(p and not p.active and 0.6 or 1)
  row.text:ClearAllPoints();row.text:SetPoint('LEFT',8,0);row.text:SetWidth(CARD_W-110);U.Font(row.text,11,'textMedium')
  row.text:SetText((list=='players' and i or 'B')..'  '..classHex(p)..n..'|r  |cff8a7f8d'..(p and interruptLabel(p) or A.T('kk.notRoster'))..'|r')
  local bx=x+CARD_W-24-74
  small(f,pool,'^',bx,y+1,22,i>1 and function() edit(function(ks) local l=ks[ki][list];l[i],l[i-1]=l[i-1],l[i] end) end or nil,A.T('kk.upTitle'))
  small(f,pool,'v',bx+24,y+1,22,i<#names and function() edit(function(ks) local l=ks[ki][list];l[i],l[i+1]=l[i+1],l[i] end) end or nil,A.T('kk.downTitle'))
  small(f,pool,'x',bx+48,y+1,22,function() edit(function(ks) table.remove(ks[ki][list],i) end) end,A.T('kk.rm',{name=n}))
  y=y+26
 end
 return y
end
function U.DrawKicks()
 local f=U.kicks;if not f or not f:IsShown() then return end
 local pool=f.pool;pool:release()
 local ks=A.model.plan.kicks or {};local casts=A.boss.kicks or {}
 f.title:SetText(A.T('kk.title'))
 if #casts>0 then f.sub:SetText(A.T('kk.emptyCasts',{n=#casts,spell=A.T('kk.rowSub'),range=U.Time(casts[1].start)..' '..A.T('to')..' '..U.Time(casts[#casts].start)}))
 else f.sub:SetText(A.T('kk.none')) end
 local hasPool=#M.kickers(A.model.plan)>0
 f.suggest:SetEnabled(hasPool);f.copy:SetEnabled(#ks>0)
 if #ks==0 then
  local y=4
  text(pool,A.T('kk.emptyH'),0,y,600,15,'ink','displayMedium');y=y+28
  text(pool,A.T('kk.emptySplit'),0,y,f.body:GetWidth(),12,'ink-3');y=y+28
  local who=M.kickers(A.model.plan)
  text(pool,A.T('kk.emptyWho',{n=#who}),0,y,600,12,'ink-2','textMedium');y=y+22
  for _,p in ipairs(who) do local it=M.interruptOf(p);local spec=A.SpecByID[p.specId]
   text(pool,classHex(p)..p.name..'|r  '..(spec and spec.name or '')..'  |cff8a7f8d'..it.name..', '..it.cd..' s|r',12,y,600,12);y=y+20 end
  return
 end
 local sched=M.kickSchedule(A.model.plan,casts,A.model.phases)
 local late={};for _,s in ipairs(sched) do if s.ready==false then late[s.line]=(late[s.line] or 0)+1 end end
 for i,k in ipairs(ks) do
  local col=(i-1)%3;local row=math.floor((i-1)/3)
  local x=col*(CARD_W+12);local y=row*(CARD_H+12)-f.offset
  local card=pool:get();card:SetPoint('TOPLEFT',x,-y);card:SetSize(CARD_W,CARD_H);U.Radius(card,6);card:SetBackdropColor(U.Color('ground-2'));card:SetBackdropBorderColor(U.Color('line'));card:EnableMouse(false)
  local cx,cy=x+12,y+12
  text(pool,A.T('kk.line',{n=i}),cx,cy,80,11,'ink-3','textMedium')
  local name=small(f,pool,label(k,i),cx+70,cy-3,CARD_W-24-70-28,function(self)
   local items={{A.T('kk.labelAria',{n=i}),nil,title=true}}
   for li,key in ipairs(LABELS_3429) do items[#items+1]={A.T(key),function() edit(function(ks2) ks2[i].label=A.T(key) end) end} end
   items[#items+1]={A.T('kk.group',{n=i}),function() edit(function(ks2) ks2[i].label='' end) end}
   U.Menu(self,items)
  end);name.text:SetJustifyH('LEFT');name.text:ClearAllPoints();name.text:SetPoint('LEFT',8,0);U.Font(name.text,12,'textMedium')
  small(f,pool,'x',cx+CARD_W-24-24,cy-3,24,function() edit(function(ks2) table.remove(ks2,i) end);A.Message(A.T('kk.deleted')) end,A.T('kk.del',{name=label(k,i)}))
  cy=cy+30
  text(pool,A.T('kk.phase'),cx,cy,70,11,'ink-3','textMedium')
  local phName=A.T('kk.anyPhase');for _,p in ipairs(A.model.phases) do if tostring(p.id)==k.phase then phName=A.T('phaseShort',{id=tostring(p.id)})..'  '..(p.name or '') end end
  small(f,pool,phName,cx+70,cy-3,CARD_W-24-70,function(self)
   local items={{A.T('kk.anyPhase'),function() edit(function(ks2) ks2[i].phase='' end) end,checked=(k.phase or '')==''}}
   for _,p in ipairs(A.model.phases) do items[#items+1]={A.T('phaseShort',{id=tostring(p.id)})..'  '..(p.name or ''),function() edit(function(ks2) ks2[i].phase=tostring(p.id) end) end,checked=k.phase==tostring(p.id)} end
   U.Menu(self,items)
  end)
  cy=cy+28
  local per=math.max(1,math.floor(tonumber(k.per) or 1))
  text(pool,A.T('kk.per'),cx,cy,150,11,'ink-3','textMedium')
  small(f,pool,'-',cx+160,cy-3,24,per>1 and function() edit(function(ks2) local v=per-1;ks2[i].per=v>1 and v or nil end) end or nil)
  text(pool,tostring(per),cx+190,cy,20,12,'ink','textMedium')
  small(f,pool,'+',cx+206,cy-3,24,per<4 and function() edit(function(ks2) ks2[i].per=per+1 end) end or nil,A.T('kk.perNote'))
  cy=cy+28
  local c=text(pool,cycle(k),cx,cy,CARD_W-24,11,'ink-2');c.text:SetWordWrap(true);c:SetHeight(30);c.text:SetHeight(30);cy=cy+32
  if late[i-1] then local w=text(pool,'! '..A.T('addon.kicksLate',{n=late[i-1]}),cx,cy,CARD_W-24,11,'tl-conflict','textMedium');cy=cy+18 end
  text(pool,A.T('kk.order'),cx,cy,CARD_W-24,11,'ink-3','textMedium');cy=cy+18
  cy=playerList(f,pool,k,i,'players',cx,cy)
  small(f,pool,'+ '..A.T('kk.addPlayer'),cx,cy,CARD_W-24,function(self) playerMenu(self,function(n) edit(function(ks2) ks2[i].players[#ks2[i].players+1]=n end) end) end);cy=cy+28
  text(pool,A.T('kk.backups')..'  |cff8a7f8d'..A.T('kk.backupsNote')..'|r',cx,cy,CARD_W-24,11,'ink-3','textMedium');cy=cy+18
  cy=playerList(f,pool,k,i,'backups',cx,cy)
  small(f,pool,'+ '..A.T('kk.backups'),cx,cy,CARD_W-24,function(self) playerMenu(self,function(n) edit(function(ks2) ks2[i].backups=ks2[i].backups or {};ks2[i].backups[#ks2[i].backups+1]=n end) end) end);cy=cy+28
  local lines=M.kickLines(A.model.plan)
  local code=text(pool,lines and lines[i+1] or '',cx,cy,CARD_W-24,11,'ink-2','mono');code:SetBackdrop(true);code:SetBackdropColor(U.Color('ground'));code:SetBackdropBorderColor(0,0,0,0);code.text:SetPoint('LEFT',6,0);code.text:SetWidth(CARD_W-36)
  card:SetHeight(math.max(CARD_H,cy-y+30))
 end
end
