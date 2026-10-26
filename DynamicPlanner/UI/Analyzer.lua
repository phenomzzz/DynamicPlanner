local _, A = ...
local U=A.UI
local AN=A.Analyzer
local ROW=26
local VIEWS={'overview','deaths','damage','mechanics','compare'}
function U.Num(v)
 v=tonumber(v) or 0;local a=math.abs(v);local s,unit
 if a>=1e9 then s,unit=a/1e9,'B' elseif a>=1e6 then s,unit=a/1e6,'M' elseif a>=1e3 then s,unit=a/1e3,'K' else return tostring(math.floor(v+0.5)) end
 local txt=string.format(s>=100 and '%.0f' or '%.1f',s)..unit
 if A.locale=='pt-BR' then txt=txt:gsub('%.',',') end
 return (v<0 and '-' or '')..txt
end
local function pct(v) local s=string.format('%.0f%%',v or 0);return s end
local function classColor(token) local key='class-'..tostring(token or '');if A.Theme.colors[key] then return U.Color(key) end;return U.Color('ink') end
local function diffName(d) local k='ana.diff.'..tostring(d or 0);local s=A.T(k);if s==k then return A.T('ana.diff.other') end;return s end
local function pullTitle(p)
 return A.T('ana.pullTitle',{boss=p.name or tostring(p.enc),n=p.n or '?'})..(p.src=='log' and (', '..A.T('ana.fromLog')) or '')
end
local function result(p)
 if p.success then return A.T('ana.kill') end
 local hp=AN.BossPct(p);return hp and A.T('ana.wipeAt',{p=pct(hp)}) or A.T('ana.wipe')
end
local function clockAt(at) if type(date)=='function' and at and at>0 then return date('%H:%M',at) end;return '' end
local function rowPool(parent)
 local pool={free={},used={}}
 function pool:release() for i=#self.used,1,-1 do local f=self.used[i];f:Hide();self.free[#self.free+1]=f end;self.used={} end
 function pool:get()
  local f=table.remove(self.free)
  if not f then
   f=CreateFrame('Button',nil,parent);U.Surface(f,'panel','line',4)
   f.bar=f:CreateTexture(nil,'BORDER');f.bar2=f:CreateTexture(nil,'BORDER');f.icon=f:CreateTexture(nil,'ARTWORK');f.icon:SetTexCoord(0.08,0.92,0.08,0.92)
   f.cells={};for i=1,6 do local c=U.Text(f);U.Line(c);f.cells[i]=c end
  end
  f:ClearAllPoints();f:SetScript('OnEnter',nil);f:SetScript('OnLeave',nil);f:SetScript('OnClick',nil);f:EnableMouse(true);f:SetAlpha(1);f.spell=nil;f.player=nil
  f:SetBackdrop(true);U.Radius(f,4);f:SetBackdropColor(U.Color('panel'));f:SetBackdropBorderColor(U.ColorA('line',0))
  f.bar:Hide();f.bar2:Hide();f.icon:Hide();f.icon:ClearAllPoints()
  for i=1,6 do local c=f.cells[i];c:SetText('');c:ClearAllPoints();c:SetWidth(0);c:SetJustifyH('LEFT');U.Font(c,12);c:Hide() end
  f:SetFrameLevel(parent:GetFrameLevel()+2);f:Show();self.used[#self.used+1]=f;return f
 end
 return pool
end
local function texPool(parent)
 local pool={free={},used={}}
 function pool:release() for i=#self.used,1,-1 do local t=self.used[i];t:Hide();self.free[#self.free+1]=t end;self.used={} end
 function pool:get() local t=table.remove(self.free) or parent:CreateTexture(nil,'ARTWORK');t:ClearAllPoints();t:SetAlpha(1);t:Show();self.used[#self.used+1]=t;return t end
 return pool
end
local function cell(f,i,text,x,w,opts)
 opts=opts or {};local c=f.cells[i];U.Font(c,opts.size or 12,opts.kind);c:SetPoint('LEFT',f,'LEFT',x,0);if w then c:SetWidth(math.max(1,w)) end
 c:SetJustifyH(opts.right and 'RIGHT' or 'LEFT');c:SetText(text or '')
 if opts.rgb then c:SetTextColor(opts.rgb[1],opts.rgb[2],opts.rgb[3]) else c:SetTextColor(U.Color(opts.ink or 'ink')) end
 c:Show();return c
end
local function rgb(r,g,b) return {r,g,b} end
function U.CreateAnalyzerChrome(f)
 U.modeSwitch={}
 for _,key in ipairs({'planner','analyzer'}) do
  local b=U.Button(f,'',0,-12,0,function() U.SetMode(key) end,{key='ana.mode.'..key,always=false})
  U.modeSwitch[key]=b
 end
 U.pullButton=U.Button(f,'',0,-52,0,function(b) U.Menu(b,U.PullItems()) end,{key=false,menu=true})
 U.anaImport=U.Button(f,'',0,-52,0,function() U.ImportPull() end,{key='ana.import'})
 U.anaFilterBtn=U.Button(f,'',0,-52,0,function(b) U.ToggleAnaFilter(b) end,{key=false})
 U.anaTabs={}
 for _,key in ipairs(VIEWS) do U.anaTabs[key]=U.Button(f,'',0,-52,0,function() A.db.anaView=key;U.anaScroll=0;U.RenderAnalyzer() end,{key='ana.view.'..key}) end
 for _,b in pairs(U.modeSwitch) do b:Hide() end
 U.pullButton:Hide();U.anaImport:Hide();U.anaFilterBtn:Hide();for _,b in pairs(U.anaTabs) do b:Hide() end
 local body=CreateFrame('Frame',nil,f);U.Surface(body,'panel','line',10);body:SetClipsChildren(true);body:EnableMouse(true);body:EnableMouseWheel(true);body:Hide()
 body:SetScript('OnMouseWheel',function(_,d) U.AnaWheel(d) end)
 body:SetScript('OnMouseDown',function(_,button) U.AnaPress(button) end)
 body:SetScript('OnMouseUp',function() U.anaDrag=nil end)
 U.anaBody=body;U.anaRows=rowPool(body);U.anaTex=texPool(body);U.anaMarks=U.Pool(body)
 U.anaText={}
 for i=1,8 do local t=U.Text(body);t:SetJustifyH('LEFT');t:Hide();U.anaText[i]=t end
 U.anaZoomOut=U.IconButton(body,'glyph:minus',24,function() U.AnaZoom(1.25) end,'ana.zoomOut')
 U.anaZoomFit=U.Button(body,'',0,0,0,function() U.AnaFit() end,{key='ana.fit',height=24})
 U.anaZoomIn=U.IconButton(body,'glyph:plus',24,function() U.AnaZoom(0.8) end,'ana.zoomIn')
 U.anaZoomRead=U.Text(body);U.Font(U.anaZoomRead,11,'mono');U.anaZoomRead:SetJustifyH('RIGHT');U.anaZoomRead:SetTextColor(U.Color('ink-3'))
 for _,w in ipairs({U.anaZoomOut,U.anaZoomFit,U.anaZoomIn}) do w:SetFrameLevel(body:GetFrameLevel()+3) end
 local hv=CreateFrame('Frame',nil,body);hv:EnableMouse(true);hv:EnableMouseWheel(true);hv:SetFrameLevel(body:GetFrameLevel()+1)
 hv.hi=hv:CreateTexture(nil,'OVERLAY');hv.hi:SetColorTexture(U.ColorA('ink',0.12));hv.hi:Hide()
 hv:SetScript('OnMouseWheel',function(_,d) U.AnaWheel(d) end)
 hv:SetScript('OnMouseDown',function(_,button) U.AnaPress(button) end)
 hv:SetScript('OnMouseUp',function() U.anaDrag=nil end)
 hv:SetScript('OnEnter',function(self) self.last=nil;self:SetScript('OnUpdate',U.AnaHoverTick) end)
 hv:SetScript('OnLeave',function(self) self:SetScript('OnUpdate',nil);self.last=nil;self.hi:Hide();U.CardHide(self) end)
 hv:Hide();U.anaHover=hv
 U.anaScratch={vals={},sorted={},top={},hi={}};U.anaHi=texPool(body)
 U.anaLane,U.anaLaneTex,U.anaLaneMarks={},{},{}
 for _,k in ipairs({'phases','deaths','damage','used','planned'}) do
  local lf=CreateFrame('Frame',nil,body);lf:SetAllPoints(body);lf:SetFrameLevel(body:GetFrameLevel()+1);lf:EnableMouse(false);lf.alpha=1;lf.target=1
  U.anaLane[k]=lf;U.anaLaneTex[k]=texPool(lf);U.anaLaneMarks[k]=U.Pool(lf)
 end
 local mk=CreateFrame('Frame',nil,body);mk:SetAllPoints(body);mk:SetFrameLevel(body:GetFrameLevel()+8);mk:EnableMouse(false)
 mk.line=mk:CreateTexture(nil,'OVERLAY');mk.line:SetColorTexture(U.Color('tl-scrub'));mk.line:SetWidth(2);mk.line:Hide()
 mk.tag=CreateFrame('Frame',nil,mk);U.Surface(mk.tag,'tl-scrub','tl-scrub',3);mk.tag:SetSize(52,16);mk.tag:SetFrameLevel(mk:GetFrameLevel()+1);mk.tag:Hide()
 mk.text=U.Text(mk.tag);U.Font(mk.text,11,'mono');mk.text:SetPoint('CENTER',0,0);mk.text:SetTextColor(U.Color('ground'))
 U.anaMarker=mk
 local tr=CreateFrame('Frame',nil,body);tr:Hide();U.anaTrack=tr
 local drv=CreateFrame('Frame',nil,body);drv:Hide();U.anaDriver=drv
end
function U.Mode() return (A.db and A.db.uiMode=='analyzer') and 'analyzer' or 'planner' end
local function plannerOnly()
 return {U.noteButton,U.pasteButton,U.readButton,U.sendButton,U.gridButton,U.assignButton,U.kicksButton,U.plansButton,
  U.bossButton,U.phasesFrame,U.modeButtons.ability,U.modeButtons.category,U.filtersButton,U.coverageButton,U.compactButton,
  U.panRight,U.panLeft,U.zoomIn,U.zoomFit,U.zoomOut,U.redoButton,U.undoButton}
end
local function plannerBody() return {U.roster,U.canvas,U.playerCanvas,U.raidHeader,U.sheetInfo,U.problemsButton,U.status,U.pinGrip} end
function U.SetMode(mode)
 if not A.Allowed() or not U.window then return end
 if mode==U.Mode() then return end
 A.db.uiMode=(mode=='analyzer') and 'analyzer' or nil
 if U.CancelDrag then U.CancelDrag() end
 if U.ClearSelection then U.ClearSelection() end
 for _,k in ipairs({'filters','coverage','preview','kicks','editor','importer','note','grid','menu','prompt','shareOffer','anaImportBox','anaFilterBox'}) do local w=U[k];if w and w.IsShown and w:IsShown() then w:Hide() end end
 U.ApplyMode();U.Render()
end
function U.ApplyMode()
 local ana=U.Mode()=='analyzer'
 for _,b in ipairs(plannerOnly()) do if b then b:SetShown(not ana) end end
 for _,w in ipairs(plannerBody()) do if w then w:SetShown(not ana) end end
 if ana and U.showHidden then U.showHidden:Hide() end
 if not ana and U.AnaTrackStop then U.AnaTrackStop() end
 U.pullButton:SetShown(ana);U.anaImport:SetShown(ana);U.anaFilterBtn:SetShown(ana);if not ana and U.anaFilterBox then U.anaFilterBox:Hide() end;if not ana and U.anaImportBox then U.anaImportBox:Hide() end;for _,b in pairs(U.anaTabs) do b:SetShown(ana) end;U.anaBody:SetShown(ana)
 for _,b in pairs(U.modeSwitch) do b:Show() end
 U.Active(U.modeSwitch.planner,not ana);U.Active(U.modeSwitch.analyzer,ana)
end
function U.LayoutAnalyzerRow(y)
 local f=U.window;local x=12
 local function at(b) b:ClearAllPoints();b:SetPoint('TOPLEFT',f,'TOPLEFT',math.floor(x),y);x=x+b:GetWidth() end
 at(U.pullButton);x=x+U.HEADER_GAP;at(U.anaImport);x=x+U.HEADER_GAP;at(U.anaFilterBtn);x=x+18
 for i,key in ipairs(VIEWS) do at(U.anaTabs[key]);x=x+U.HEADER_GAP end
 return x
end
function U.AnalyzerChanged() if U.window and U.window:IsShown() and U.Mode()=='analyzer' then U.RenderAnalyzer() end end
function U.PullItems()
 local items={{A.T('ana.pulls'),nil,title=true}}
 local sel=AN.Selected()
 for _,p in ipairs(AN.Pulls()) do
  local dur=p.dur and U.Time(p.dur) or '?'
  items[#items+1]={pullTitle(p)..', '..result(p)..', '..dur..(clockAt(p.at)~='' and ', '..clockAt(p.at) or ''),function() AN.selected=p.id;U.anaScroll=0;U.RenderAnalyzer() end,checked=(sel and sel.id==p.id)}
 end
 if #items==1 then items[#items+1]={A.T('ana.none'),nil,title=true} end
 if sel then
  items[#items+1]={'',nil,divider=true}
  items[#items+1]={A.T('ana.delete'),function() AN.Delete(sel.id);U.RenderAnalyzer() end}
  items[#items+1]={A.T('ana.clear'),function() U.Menu(U.pullButton,{{A.T('ana.clearConfirm',{n=#AN.Pulls()}),function() AN.Clear();U.RenderAnalyzer() end},{A.T('addon.cancel'),function() end}}) end}
 end
 return items
end
function U.ImportPull()
 if not A.Allowed() or not U.window then return end
 local f=U.anaImportBox
 if not f then
  f=CreateFrame('Frame',nil,U.window);U.Surface(f,'panel','border',10);f:SetSize(700,420);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:EnableMouse(true);f:SetToplevel(true)
  f.title=U.Label(f,'',18,-16,16,'display')
  f.help=U.Label(f,'',18,-44,12);f.help:SetWidth(664);f.help:SetWordWrap(true);f.help:SetTextColor(U.Color('ink-2'))
  local scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',18,-104);scroll:SetPoint('BOTTOMRIGHT',-38,86)
  local edit=CreateFrame('EditBox',nil,scroll);edit:SetMultiLine(true);U.Font(edit,11,'mono');edit:SetAutoFocus(false);edit:SetWidth(640);edit:SetHeight(220);edit:SetTextInsets(6,6,6,6);scroll:SetScrollChild(edit)
  edit:SetScript('OnEscapePressed',function() edit:ClearFocus();f:Hide() end)
  f.edit=edit;f.scroll=scroll
  f.status=U.Label(f,'',18,0,12);f.status:ClearAllPoints();f.status:SetPoint('BOTTOMLEFT',18,58);f.status:SetWidth(664);f.status:SetWordWrap(true)
  f.go=U.Button(f,'',0,0,0,function() U.ImportPullRun() end,{key='ana.imp.go'});f.go:ClearAllPoints();f.go:SetPoint('BOTTOMRIGHT',-18,16)
  f.cancel=U.Button(f,'',0,0,0,function() f:Hide() end,{key='addon.cancel'});f.cancel:ClearAllPoints();f.cancel:SetPoint('RIGHT',f.go,'LEFT',-6,0)
  f:EnableKeyboard(true);U.Propagate(f,true)
  f:SetScript('OnKeyDown',function(self,key) if key=='ESCAPE' then U.Propagate(self,false);self:Hide() else U.Propagate(self,true) end end)
  U.anaImportBox=f
 end
 f.title:SetText(A.T('ana.imp.title'));f.help:SetText(A.T('ana.imp.help'))
 local part=AN.partial
 U.ImportStatus(part and A.T('ana.imp.part',{got=part.count,of=part.n,next=part.count+1}) or '',part and 'ink-2' or nil)
 f.edit:SetText('');f.scroll:SetVerticalScroll(0);f:Show();U.RefreshLabels();f.edit:SetFocus()
end
function U.ImportStatus(s,ink) local f=U.anaImportBox;if not f then return end;f.status:SetText(s or '');f.status:SetTextColor(U.Color(ink or 'ink-2')) end
function U.ImportPullRun()
 local f=U.anaImportBox;if not f then return end
 if not A.Allowed() then f:Hide();return end
 local r=AN.ImportText(f.edit:GetText())
 if r.err then U.ImportStatus(A.T(r.err,r.vars),'tl-death');return end
 f.edit:SetText('')
 if r.got then U.ImportStatus(A.T('ana.imp.part',{got=r.got,of=r.of,next=r.got+1}),'ink');f.edit:SetFocus();return end
 f:Hide();A.db.anaView='overview';U.anaScroll=0
 A.Message(A.T(r.again and 'ana.imp.again' or 'ana.imp.done',{boss=r.pull.name or tostring(r.pull.enc),n=r.pull.n or '?'}))
 U.RenderAnalyzer()
end
function U.RenderAnalyzer()
 if not U.window then return end
 U.RefreshLabels()
 local p=AN.Selected()
 U.title:SetText(p and (p.name or tostring(p.enc))..', '..diffName(p.diff) or A.T('ana.title'))
 U.pullButton:SetLabel((p and (A.T('ana.pullN',{n=p.n or '?'})..', '..result(p)) or A.T('ana.noPull')))
 local view=A.db.anaView or 'overview';for key,b in pairs(U.anaTabs) do U.Active(b,key==view) end
 local hidden=U.AnaHidden();U.anaFilterBtn:SetLabel(hidden>0 and A.T('ana.flt.btnN',{n=hidden}) or A.T('ana.flt.btn'));U.Active(U.anaFilterBtn,hidden>0)
 U.ApplyMode();U.LayoutHeader();U.DrawAnalyzer()
end
U.ANA_TICKS={5,10,15,30,60,120,300}
local MIN_SPAN=20
local function clampView(z,start,span)
 span=math.max(math.min(MIN_SPAN,z.total),math.min(z.total,span))
 return math.max(0,math.min(z.total-span,start)),span
end
function U.AnaView(p)
 local z=U.anaZoomState;local total=math.max(30,(p.dur or 0)+10)
 if not z or z.pull~=p or z.total~=total then z={pull=p,total=total,start=0,span=total};U.anaZoomState=z end
 return z
end
local function cursorBody()
 local cx,cy=GetCursorPosition();local s=U.anaBody:GetEffectiveScale()
 return cx/s-U.anaBody:GetLeft(),cy/s-U.anaBody:GetTop()
end
local function overAxis()
 local z=U.anaZoomState;local r=z and z.rect;if not r then return nil end
 local x,y=cursorBody();if y>r.top or y<r.bottom or x<16 or x>r.x0+r.aw then return nil end
 return z,math.max(z.start,math.min(z.start+z.span,z.start+(x-r.x0)/r.aw*z.span)),x
end
local function step(_,elapsed) U.AnaStep(elapsed) end
local function request() U.anaDriver:SetScript('OnUpdate',step);U.anaDriver:Show() end
function U.AnaZoom(factor,anchorT)
 local z=U.anaZoomState;if not z or not A.Allowed() then return end
 local to=z.to or {start=z.start,span=z.span}
 anchorT=anchorT or (to.start+to.span/2)
 local frac=(anchorT-to.start)/to.span
 local st,sp=clampView(z,0,to.span*factor);st=select(1,clampView(z,anchorT-frac*sp,sp))
 z.to={start=st,span=sp};request()
end
function U.AnaFit() local z=U.anaZoomState;if not z or not A.Allowed() then return end;z.to={start=0,span=z.total};request() end
function U.AnaPan(dt)
 local z=U.anaZoomState;if not z or not A.Allowed() then return end
 local to=z.to or {start=z.start,span=z.span};z.to={start=select(1,clampView(z,to.start+dt,to.span)),span=to.span};request()
end
function U.AnaWheel(d)
 if not A.Allowed() then return end
 local z,t=overAxis()
 if z and IsControlKeyDown() then U.AnaZoom(d>0 and 0.8 or 1.25,t);return end
 if z and IsShiftKeyDown() then U.AnaPan(-d*(z.to and z.to.span or z.span)/10);return end
 U.anaScroll=math.max(0,(U.anaScroll or 0)-d*ROW*3);U.DrawAnalyzer()
end
function U.AnaPress(button)
 if button~='LeftButton' or not A.Allowed() then return end
 local z,_,x=overAxis();if not z or x<z.rect.x0 then return end
 z.to=nil;U.anaDrag={x=x,start=z.start,span=z.span,aw=z.rect.aw};request()
end
function U.AnaStep(elapsed)
 local z=U.anaZoomState;local dirty=false
 if z and U.anaDrag then
  local d=U.anaDrag
  if not IsMouseButtonDown('LeftButton') then U.anaDrag=nil
  else local x=cursorBody();local st=select(1,clampView(z,d.start-(x-d.x)/d.aw*d.span,d.span));if math.abs(st-z.start)>1e-3 then z.start=st;dirty=true end end
 end
 if z and z.to then
  local k=math.min(1,(elapsed or 0)*16);local to=z.to
  z.span=z.span+(to.span-z.span)*k;z.start=z.start+(to.start-z.start)*k
  if math.abs(z.span-to.span)<0.05 and math.abs(z.start-to.start)<0.05 then z.span,z.start,z.to=to.span,to.start,nil end
  dirty=true
 end
 if dirty then U.DrawAnalyzer() end
 if not (z and (z.to or U.anaDrag)) then U.anaDriver:SetScript('OnUpdate',nil);U.anaDriver:Hide() end
end
U.ANA_DIM=0.4
function U.AnaTrackStop()
 local tr=U.anaTrack;if not tr then return end
 tr:SetScript('OnUpdate',nil);tr:Hide();U.anaMarker.line:Hide();U.anaMarker.tag:Hide();U.anaFocus=nil
 for _,k in ipairs(U.ANA_LANES) do local lf=U.anaLane[k];lf.alpha=1;lf.target=1;lf:SetAlpha(1) end
end
function U.AnaTrackTick(self,elapsed)
 local body=U.anaBody
 local z=U.anaZoomState;local r=z and z.rect
 if not (body:IsShown() and U.window:IsShown()) or not r then U.AnaTrackStop();return end
 local x,y=cursorBody()
 if self.force or x~=self.cx or y~=self.cy then
  self.cx,self.cy,self.force=x,y,false
  local mk=U.anaMarker;local bottom=r.bottom+16
  if x>=r.x0 and x<=r.x0+r.aw and y<=r.top and y>=r.bottom then
   local t=z.start+(x-r.x0)/r.aw*z.span;local px=math.floor(x+0.5)
   mk.line:ClearAllPoints();mk.line:SetPoint('TOPLEFT',body,'TOPLEFT',px-1,r.top);mk.line:SetHeight(math.max(1,r.top-bottom));mk.line:Show()
   mk.tag:ClearAllPoints();mk.tag:SetPoint('TOP',body,'TOPLEFT',math.max(r.x0+26,math.min(r.x0+r.aw-26,px)),bottom+2);mk.text:SetText(U.TimeFine(t));mk.tag:Show()
   mk.t=t
  else mk.line:Hide();mk.tag:Hide();mk.t=nil end
  local focus
  if x>=16 and x<=r.x0+r.aw then for _,l in ipairs(z.lanes or {}) do if y<=l.top and y>=l.bottom then focus=l.key;break end end end
  if focus~=U.anaFocus then U.anaFocus=focus;for _,k in ipairs(U.ANA_LANES) do U.anaLane[k].target=(not focus or k==focus) and 1 or U.ANA_DIM end end
 end
 local k=math.min(1,(elapsed or 0)*12)
 for _,key in ipairs(U.ANA_LANES) do local lf=U.anaLane[key]
  if lf.alpha~=lf.target then local a=lf.alpha+(lf.target-lf.alpha)*k;if math.abs(a-lf.target)<0.02 then a=lf.target end;lf.alpha=a;lf:SetAlpha(a) end
 end
end
function U.AnaHoverTick(self)
 local z=U.anaZoomState;local dm=z and z.dmg;local r=z and z.rect;if not dm or not r or U.anaDrag then return end
 local x=cursorBody();local i=math.floor(((z.start+(x-r.x0)/r.aw*z.span)-dm.b0)/dm.bin)
 if i==self.last then return end;self.last=i
 local s=dm.b0+i*dm.bin;local p=self.pull;local raid=p.raid or {}
 local sum=0;for sec=s+1,s+dm.bin do sum=sum+(raid[sec] or 0) end
 local X=function(t) return r.x0+(t-z.start)/z.span*r.aw end
 local a=math.max(r.x0,X(s));self.hi:ClearAllPoints();self.hi:SetPoint('TOPLEFT',self,'TOPLEFT',a-r.x0,0);self.hi:SetSize(math.max(2,X(s+dm.bin)-a),self:GetHeight());self.hi:Show()
 local top=U.anaScratch.top;for j=#top,1,-1 do top[j]=nil end
 for _,e in ipairs(p.spells or {}) do
  local secs=e.secs;if secs then local v=0;for j=1,#secs,2 do local t=secs[j];if t>=s and t<s+dm.bin then v=v+secs[j+1] end end;if v>0 then top[#top+1]={e,v} end end
 end
 table.sort(top,function(x,y) return x[2]>y[2] end)
 local c=U.Card()
 c.Header(dm.bin>1 and A.T('ana.zoomRange',{a=U.Time(s),b=U.Time(s+dm.bin)}) or U.Time(s),nil,nil,U.Num(sum),sum>0 and 'major' or 'ink-3')
 c.Sub(sum>0 and (A.T('ana.lane.damage')..(dm.bin>1 and (', '..A.T('ana.perSec',{v=U.Num(sum/dm.bin)})) or '')) or A.T('ana.binNone'))
 if #top>0 then
  c.Section(A.T('ana.card.top'))
  for j=1,math.min(3,#top) do local e,v=top[j][1],top[j][2];c.Row({id=e.id,name=AN.SpellName(e.id,e.name),amt=U.Num(v),bar=v/top[1][2],pctText=sum>0 and pct(v/sum*100) or nil}) end
 end
 c.Show(self)
end
local function text(i,s,x,y,w,size,ink,kind)
 local t=U.anaText[i];U.Font(t,size or 12,kind);t:ClearAllPoints();t:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',x,y+(U.anaScroll or 0));t:SetWidth(w or 0);t:SetText(s or '');t:SetTextColor(U.Color(ink or 'ink'));t:Show();return t
end
local function begin()
 if U.CardHideNow then U.CardHideNow() end
 U.anaRows:release();U.anaTex:release();U.anaMarks:release();U.anaHi:release();for _,k in ipairs(U.ANA_LANES) do U.anaLaneTex[k]:release();U.anaLaneMarks[k]:release() end;U.anaRefs=nil;U.anaAxisShown=false;if U.anaZoomState then U.anaZoomState.rect=nil;U.anaZoomState.dmg=nil end
 for _,t in ipairs(U.anaText) do t:Hide() end
end
local function row(y,x,w,h)
 local top=y+(U.anaScroll or 0)
 if top>0 or top<-U.anaBody:GetHeight() then return nil end
 local f=U.anaRows:get();f:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',x,top);f:SetSize(w,h or ROW);return f
end
local function sectionTitle(y,x,s,sub,w)
 local f=row(y,x,w,22);if not f then return end
 f:SetBackdrop(false);f:EnableMouse(false);cell(f,1,s,0,nil,{size=13,kind='textMedium'})
 if sub then cell(f,2,sub,f.cells[1]:GetUnboundedStringWidth()+12,w-(f.cells[1]:GetUnboundedStringWidth()+12),{size=11,ink='ink-3'}) end
end
local function coverText(p,planned,d)
 local c=AN.CoverAt(planned,d.t);if #c==0 then return A.T('ana.noCover') end
 local names={};for _,x in ipairs(c) do names[#names+1]=x.name..' ('..AN.Short(x.who)..')' end;return table.concat(names,', ')
end
local function activeText(p,d)
 local c=AN.ActiveAt(p,d.t);if #c==0 then return A.T('ana.noActive') end
 local names={};for _,x in ipairs(c) do names[#names+1]=x.name..' ('..AN.Short(x.who)..')' end;return table.concat(names,', ')
end
local function usage(p,c)
 local times,present=AN.Used(p,c.who,c.spellId)
 if times then
  if #times>0 then local s={};for i=1,math.min(#times,4) do s[i]=U.Time(times[i]) end;return A.T('ana.usedAt',{t=table.concat(s,', ')}) end
  return A.T(present and 'ana.notUsed' or 'ana.notInPull')
 end
 return A.T(AN.Seen(p,c.who,c.spellId) and 'ana.seen' or 'ana.noTrace')
end
local function hitTimes(secs)
 local out={};local a,b
 for i=1,#secs,2 do local s=secs[i]
  if a and s<=b+2 then b=s else if a then out[#out+1]=(b>a) and (U.Time(a)..'-'..U.Time(b)) or U.Time(a) end;a,b=s,s end
 end
 if a then out[#out+1]=(b>a) and (U.Time(a)..'-'..U.Time(b)) or U.Time(a) end
 local n=#out;if n>8 then for i=n,9,-1 do out[i]=nil end;out[9]=A.T('ana.more',{n=n-8}) end
 return table.concat(out,', ')
end
local realmCache=setmetatable({},{__mode='k'})
local function realmOf(n) local r=tostring(n or ''):match('^[^%-]+%-(.+)$');if r then r=r:gsub('%-%u%u$','') end;return r end
local function homeRealm(p)
 local c=realmCache[p];if c then return c.home,c.set end
 local count,set,best,bn={},{},nil,0
 for _,pl in ipairs(p.players or {}) do set[pl.n]=pl;local r=realmOf(pl.n);if r then count[r]=(count[r] or 0)+1;if count[r]>bn then best,bn=r,count[r] end end end
 realmCache[p]={home=best,set=set};return best,set
end
function U.AnaName(p,n)
 n=tostring(n or '');local home,set=homeRealm(p)
 local isPlayer=set[n] or n:match('^[^%-%s]+%-[^%-%s]+%-%u%u$')
 if not isPlayer then return n,nil end
 local r=realmOf(n);return AN.Short(n),(r and r~=home) and r or nil
end
local function playerOf(p,n) local _,set=homeRealm(p);return set[tostring(n or '')] end
local function nameRGB(p,pl) local r,g,b=classColor(pl and pl.c);return {r,g,b} end
local function withRealm(p,n) local s,r=U.AnaName(p,n);return r and (s..' ('..r..')') or s end
local function cdList(c,list,empty,valueOf)
 local vis,hid={},0;for _,x in ipairs(list) do if U.AnaSpellOn(x.id or x.spellId) and U.AnaPlayerOn(x.who or x.by) then vis[#vis+1]=x else hid=hid+1 end end;list=vis
 if #list==0 then c.Note(hid>0 and A.T('ana.flt.nHidden',{n=hid}) or empty);return end
 if hid>0 then c.Note(A.T('ana.flt.nHidden',{n=hid})) end
 for _,x in ipairs(list) do local who=x.who or x.by;c.Item(x.id or x.spellId,x.name,who and AN.Short(who) or nil,valueOf and valueOf(x) or nil) end
end
local function cardDeath(owner,p,d,planned)
 local c=U.Card();local pl=p.players[d.p];local name,realm=U.AnaName(p,pl and pl.n)
 c.Header(name,nameRGB(p,pl),realm,d.t and U.TimeFine(d.t) or '?')
 local r=d.recap or {};local kb=r[1]
 if kb then
  local detail={};if kb.over and kb.over>0 then detail[#detail+1]=A.T('ana.overkill',{n=U.Num(kb.over)}) end
  if kb.src then detail[#detail+1]=withRealm(p,kb.src) end
  c.Lead(kb.id,kb.melee and A.T('ana.melee') or AN.SpellName(kb.id,kb.name),U.Num(kb.amt or 0),table.concat(detail,', '),'tl-death')
  if kb.src and playerOf(p,kb.src) then c.Note(A.T('ana.card.friendly'),'minor') end
 else c.Note(A.T('ana.noRecap')) end
 if #r>0 then
  c.Section(A.T('ana.card.lastHits'),r.max and A.T('ana.card.hpBefore') or nil)
  local i,shown,used,hidden=1,0,0,0
  while i<=#r and shown<8 do
   if not U.AnaSpellOn(r[i].id) and i>1 then hidden=hidden+1;used=i;i=i+1 else
   local e=r[i];local j=i;local amt=e.amt or 0
   while r[j+1] and r[j+1].id==e.id and r[j+1].src==e.src do j=j+1;amt=amt+(r[j].amt or 0) end
   local oldest=r[j]
   c.Row({time=e.ago and string.format('-%.1f',e.ago) or nil,id=e.id,name=e.melee and A.T('ana.melee') or AN.SpellName(e.id,e.name),count=j-i+1,
    sub=e.src and withRealm(p,e.src) or nil,amt=U.Num(amt),hp=(oldest.hp and r.max and r.max>0) and math.max(0,oldest.hp/r.max) or nil,hl=(i==1)})
   shown=shown+1;used=j;i=j+1
   end
  end
  if used<#r then c.Note(A.T('ana.card.earlier',{n=#r-used})) end
  if hidden>0 then c.Note(A.T('ana.flt.nHidden',{n=hidden})) end
 end
 c.Section(A.T('ana.card.planned'));cdList(c,AN.CoverAt(planned,d.t),A.T('ana.card.nothingPlanned'))
 if p.src=='log' then
  c.Section(A.T('ana.card.active'));cdList(c,AN.ActiveAt(p,d.t),A.T('ana.card.noneActive'),function(x) return string.format('-%.0f s',d.t-x.t) end)
  c.Section(A.T('ana.card.saves'));cdList(c,AN.SavesBefore(p,d,60),A.T('ana.card.noSaves'),function(x) return string.format('-%.0f s',x.ago) end)
 end
 c.Show(owner)
end
local function cardSpell(owner,p,e)
 local c=U.Card();local total=AN.Total(p,'taken');local m=AN.Mechanic(p.enc,e.id)
 c.Lead(e.id,AN.SpellName(e.id,e.name),U.Num(e.total),e.src and withRealm(p,e.src) or nil,e.avoid and 'major' or 'ink')
 local tags={};if e.avoid or (m and (m.kind=='ground' or m.kind=='area')) then tags[#tags+1]=A.T('ana.tag.avoid') end;if e.deadly then tags[#tags+1]=A.T('ana.tag.deadly') end
 if m and m.kind then c.Note(A.T('ana.tip.'..m.kind),#tags>0 and 'major' or 'ink-2',11) end
 c.KV(A.T('ana.card.hits'),tostring(#e.hits)..'  '..A.T('ana.card.playersN',{n=#e.hits}),'ink-2')
 if total>0 then c.KV(A.T('ana.card.share'),pct(e.total/total*100)) end
 if e.over and e.over>0 then c.KV(A.T('ana.card.overkill'),U.Num(e.over),'ink-2') end
 if e.secs and #e.secs>0 then c.Section(A.T('ana.card.hitAt'));c.Note(hitTimes(e.secs),'ink-2') end
 if #e.hits>0 then
  c.Section(A.T('ana.card.players'))
  local top=1;for _,h in ipairs(e.hits) do if (h.a or 0)>top then top=h.a end end
  local shown,hid=0,0
  for _,h in ipairs(e.hits) do local pl=p.players[h.p]
   if not U.AnaPlayerOn(pl and pl.n) then hid=hid+1
   elseif shown<8 then shown=shown+1;local n,rl=U.AnaName(p,pl and pl.n);c.Row({name=n,rgb=nameRGB(p,pl),count=h.c,amt=U.Num(h.a),bar=h.a/top,sub=rl}) end
  end
  if #e.hits-hid>8 then c.Note(A.T('ana.card.more',{n=#e.hits-hid-8})) end
  if hid>0 then c.Note(A.T('ana.flt.nHidden',{n=hid})) end
 end
 c.Show(owner)
end
local function cardChip(owner,p,e,h)
 local c=U.Card();local pl=p.players[h.p];local n,rl=U.AnaName(p,pl and pl.n)
 c.Header(n,nameRGB(p,pl),rl,U.Num(h.a),'major')
 c.Lead(e.id,AN.SpellName(e.id,e.name),nil,e.src and withRealm(p,e.src) or nil)
 c.KV(A.T('ana.card.hits'),tostring(h.c or 1))
 if e.total>0 then c.KV(A.T('ana.card.ofSpell'),pct(h.a/e.total*100)) end
 if (pl and pl.avoid or 0)>0 then c.KV(A.T('ana.card.allAvoid'),U.Num(pl.avoid),'major') end
 c.Show(owner)
end
local function planLine(p,x,c,match)
 if x and c then
  local st,d=AN.PlanDelta(x,c);local vars={p=U.TimeFine(x.t),u=U.TimeFine(c.t),d=string.format('%.1f',math.abs(d)),tol=AN.PLAN_TOL}
  return A.T('ana.plan.'..st,vars),st=='ontime' and 'kill' or 'major'
 end
 if x then
  if not (match and match.log) then return A.T(AN.Seen(p,x.who,x.spellId) and 'ana.plan.seenMeter' or 'ana.plan.noTrace',{p=U.TimeFine(x.t)}),'ink-2' end
  if x.after then return A.T('ana.plan.notReached',{p=U.TimeFine(x.t)}),'ink-3' end
  if not AN.InPull(p,x.who) then return A.T('ana.plan.notInPull',{p=U.TimeFine(x.t)}),'ink-3' end
  return A.T('ana.plan.notUsed',{p=U.TimeFine(x.t),w=AN.PLAN_WINDOW}),'minor'
 end
 return A.T('ana.plan.unplanned',{w=AN.PLAN_WINDOW}),'ink-3'
end
U.AnaPlanLine=planLine
local function cardCast(owner,p,c0,planned,match)
 local c=U.Card();local pl=playerOf(p,c0.who) or AN.InPull(p,c0.who)
 c.Lead(c0.spellId,c0.name,planned and U.TimeFine(c0.t) or U.TimeFine(c0.t),nil,'ink-2')
 local n,rl=U.AnaName(p,pl and pl.n or c0.who);c.Row({name=n,rgb=pl and nameRGB(p,pl) or nil,sub=rl})
 local x,cast
 if planned then x=c0;cast=match and match.byPlan[c0] else cast=c0.src;x=match and cast and match.byCast[cast] end
 c.Section(A.T('ana.card.vsPlan'))
 local line,ink=planLine(p,x,cast,match);c.Note(line,ink,12)
 if planned then
  if c0.dur>0 then c.KV(A.T('ana.card.lasts'),string.format('%d s',c0.dur)) end
 else
  if c0.dur>0 then c.KV(A.T('ana.card.lasts'),string.format('%d s',c0.dur)) end
 end
 c.Show(owner)
end
local function cardPull(owner,p,q)
 local c=U.Card()
 c.Header(A.T('ana.pullN',{n=q.n or '?'}),nil,q.src=='log' and A.T('ana.fromLog') or clockAt(q.at),result(q),q.success and 'kill' or 'ink-2')
 local same=q==p
 local function delta(a,b,fmt,lowerIsBetter)
  if same or not a or not b then return nil end
  local d=a-b;if math.abs(d)<0.05 then return '=' ,'ink-3' end
  local good=(d<0)==lowerIsBetter;return (d>0 and '+' or '-')..fmt(math.abs(d)),good and 'kill' or 'minor'
 end
 local hq,hp=AN.BossPct(q),AN.BossPct(p)
 c.KV(A.T('ana.c.dur'),q.dur and U.Time(q.dur) or '?',nil,delta(q.dur,p.dur,U.Time,false))
 if not q.success then c.KV(A.T('ana.card.bossLeft'),hq and pct(hq) or '?',nil,delta(hq,hp,function(v) return string.format('%.0f%%',v) end,true)) end
 c.KV(A.T('ana.c.deaths'),tostring(#(q.deaths or {})),nil,delta(#(q.deaths or {}),#(p.deaths or {}),function(v) return tostring(math.floor(v+0.5)) end,true))
 c.KV(A.T('ana.c.avoid'),U.Num(AN.Total(q,'avoid')),'major',delta(AN.Total(q,'avoid'),AN.Total(p,'avoid'),U.Num,true))
 local d1=q.deaths and q.deaths[1]
 if d1 then local pl=q.players[d1.p];local n=U.AnaName(q,pl and pl.n);c.Section(A.T('ana.c.first'));c.Row({time=d1.t and U.Time(d1.t) or '?',name=n,rgb=nameRGB(q,pl),id=d1.recap and d1.recap[1] and d1.recap[1].id or nil}) end
 c.Note(same and A.T('ana.card.thisPull') or A.T('ana.card.openPull'),'ink-3')
 c.Show(owner)
end
local function cardPlayer(owner,p,pl)
 local c=U.Card();local n,rl=U.AnaName(p,pl.n);local idx;for i,q in ipairs(p.players) do if q==pl then idx=i end end
 local list,hid,vis={},0,0
 for _,e in ipairs(p.spells or {}) do for _,h in ipairs(e.hits) do if h.p==idx then
  if U.AnaSpellOn(e.id) then local m=AN.Mechanic(p.enc,e.id);list[#list+1]={e=e,a=h.a or 0,c=h.c or 1,av=e.avoid or (m and (m.kind=='ground' or m.kind=='area'))};vis=vis+(h.a or 0) else hid=hid+1 end
 end end end
 table.sort(list,function(a,b) return a.a>b.a end)
 local total=hid>0 and vis or (pl.taken or vis)
 c.Header(n,nameRGB(p,pl),rl,U.Num(total))
 local raid=AN.Total(p,'taken')
 if raid>0 and hid==0 then c.Sub(A.T('ana.card.ofRaid',{p=pct((pl.taken or 0)/raid*100)})) end
 local role=pl.spec and A.SpecRole and A.SpecRole(pl.spec)
 if role and hid==0 then
  local sum,cnt=0,0;for _,q in ipairs(p.players) do if q.spec and A.SpecRole(q.spec)==role then sum=sum+(q.taken or 0);cnt=cnt+1 end end
  if cnt>=2 and sum>0 then local avg=sum/cnt;local d=((pl.taken or 0)-avg)/avg*100
   c.KV(A.T('ana.card.roleAvg',{r=A.T('ana.role.'..role)}),U.Num(avg),'ink-2',string.format('%+.0f%%',d),d>15 and 'minor' or 'ink-3') end
 end
 if (pl.avoid or 0)>0 then c.KV(A.T('ana.card.allAvoid'),U.Num(pl.avoid),'major') end
 if #list>0 then
  c.Section(A.T('ana.card.byAbility'))
  local top=math.max(1,list[1].a)
  for i=1,math.min(5,#list) do local x=list[i];c.Row({id=x.e.id,name=AN.SpellName(x.e.id,x.e.name),count=x.c,amt=U.Num(x.a),amtInk=x.av and 'major' or nil,bar=x.a/top,sub=x.av and A.T('ana.tag.avoid') or nil}) end
  if #list>5 then c.Note(A.T('ana.card.more',{n=#list-5})) end
 end
 if hid>0 then c.Note(A.T('ana.flt.nHidden',{n=hid})) end
 for _,d in ipairs(p.deaths) do if d.p==idx then
  local kb=d.recap and d.recap[1]
  c.Section(A.T('ana.card.died'))
  c.Row({time=d.t and U.TimeFine(d.t) or '?',id=kb and kb.id,name=kb and (kb.melee and A.T('ana.melee') or AN.SpellName(kb.id,kb.name)) or A.T('ana.noRecap'),amt=kb and U.Num(kb.amt or 0) or nil,hl=true,sub=kb and kb.src and withRealm(p,kb.src) or nil})
  break
 end end
 c.Show(owner)
end
U.AnaCards={death=cardDeath,spell=cardSpell,chip=cardChip,cast=cardCast,pull=cardPull,player=cardPlayer}
local function message(lines)
 local y=-24;for i,s in ipairs(lines) do local t=text(i,s,24,y,U.anaBody:GetWidth()-48,i==1 and 15 or 12,i==1 and 'ink' or 'ink-2',i==1 and 'textMedium' or nil);t:SetWordWrap(true);y=y-(i==1 and 30 or 22) end
end
local draw={}
local axisControls
function U.AnaJump(t)
 local z=U.anaZoomState;if not z or not t then return end
 local span=math.min(z.to and z.to.span or z.span,60);local st=math.max(0,math.min(z.total-span,t-span/2))
 z.to={start=st,span=span};U.anaScroll=0;U.anaDriver:SetScript('OnUpdate',function(_,e) U.AnaStep(e) end);U.anaDriver:Show()
end
function U.AnaLink(d,on)
 local r=U.anaRefs;if not r then return end
 local row,mark=r.rows[d],r.marks[d]
 if row then row:SetBackdropColor(U.Color(on and 'ground-3' or 'ground-2')) end
 if mark then local c=on and 'ink' or 'tl-death';mark:SetBackdropColor(U.Color(c));mark:SetBackdropBorderColor(U.Color(c)) end
end
function U.AnaHighlightSpell(e,on)
 U.anaHi:release()
 local z=U.anaZoomState;local dm=z and z.dmg;local r=z and z.rect
 if not on or not dm or not r or not e.secs or #e.secs==0 then return end
 local sums=U.anaScratch.hi;for k in pairs(sums) do sums[k]=nil end
 for j=1,#e.secs,2 do local s=e.secs[j];if s>=z.start-dm.bin and s<=z.start+z.span then local i=math.floor((s-dm.b0)/dm.bin);sums[i]=(sums[i] or 0)+e.secs[j+1] end end
 local room=z.dmgRoom or 82;local base=dm.ly-(room+18)
 for i,v in pairs(sums) do
  local s=dm.b0+i*dm.bin;local x1=r.x0+(math.max(s,z.start)-z.start)/z.span*r.aw;local x2=r.x0+(math.min(s+dm.bin,z.start+z.span)-z.start)/z.span*r.aw
  if x2>x1 and dm.cap>0 then
   local h=math.max(2,math.floor(room*math.min(1,(v/dm.bin)/dm.cap)+0.5))
   local t=U.anaHi:get();t:SetDrawLayer('OVERLAY');t:SetColorTexture(U.ColorA('ink',0.9));t:SetSize(math.max(2,math.floor(x2-x1)-1),h);t:SetPoint('BOTTOMLEFT',U.anaBody,'TOPLEFT',math.floor(x1),base)
  end
 end
end
local function avoidByPlayer(p)
 local by={};local list={}
 for _,it in ipairs(AN.Avoidable(p)) do if U.AnaSpellOn(it.spell.id) then for _,h in ipairs(it.spell.hits) do if U.AnaPlayerOn(p.players[h.p] and p.players[h.p].n) then
  local e=by[h.p];if not e then e={p=h.p,a=0,c=0,spells={}};by[h.p]=e;list[#list+1]=e end
  e.a=e.a+(h.a or 0);e.c=e.c+(h.c or 1);e.spells[#e.spells+1]={e=it.spell,a=h.a or 0,c=h.c or 1}
 end end end end
 table.sort(list,function(a,b) return a.a>b.a end);return list
end
local function cardAvoid(owner,p,x)
 local c=U.Card();local pl=p.players[x.p];local n,rl=U.AnaName(p,pl and pl.n);local r,g,b=classColor(pl and pl.c)
 c.Header(n,{r,g,b},rl,U.Num(x.a),'major');c.Sub(A.T('ana.col.avoidHits',{n=x.c}))
 c.Section(A.T('ana.card.byAbility'))
 table.sort(x.spells,function(a,b) return a.a>b.a end)
 for i=1,math.min(#x.spells,6) do local s=x.spells[i];c.Row({id=s.e.id,name=AN.SpellName(s.e.id,s.e.name),count=s.c,amt=U.Num(s.a),bar=s.a/math.max(1,x.spells[1].a)}) end
 c.Show(owner)
end
local function colHeader(key,x,y,w,title,count,sub,refsKey)
 local f=row(y-6,x+10,w-20,22);if not f then return end
 f:SetBackdrop(false);f:EnableMouse(false);cell(f,1,title,0,nil,{size=13,kind='textMedium'})
 local tw=f.cells[1]:GetUnboundedStringWidth() or 60
 cell(f,2,count or '',tw+8,60,{size=12,kind='mono',ink='ink-3'})
 if sub then cell(f,3,sub,tw+8+((count and #count or 0)*8)+10,w-20-tw-150,{size=11,ink='ink-3'}) end
 local all=U.anaMarks:get();all:SetBackdrop(false);all:SetSize(70,22);all:SetPoint('TOPRIGHT',U.anaBody,'TOPLEFT',x+w-8,y-6+(U.anaScroll or 0));all.text:ClearAllPoints();all.text:SetPoint('RIGHT',-4,0);all.text:SetJustifyH('RIGHT')
 all.text:SetText(A.T('ana.seeAll'));U.Font(all.text,11,'textMedium');all.text:SetTextColor(U.Color('ink-2'))
 all:SetScript('OnEnter',function(self) self.text:SetTextColor(U.Color('ink')) end);all:SetScript('OnLeave',function(self) self.text:SetTextColor(U.Color('ink-2')) end)
 all:SetScript('OnClick',function() A.db.anaView=key;U.anaScroll=0;U.RenderAnalyzer() end)
 all.isSeeAll=key
 return f
end
local function colNote(x,y,w,s,ink) local f=row(y,x+10,w-20,22);if f then f:SetBackdrop(false);f:EnableMouse(false);cell(f,1,s,0,w-20,{size=12,ink=ink or 'ink-3'}) end end
local COLS={}
function COLS.deaths(p,x,y,w,planned,refs)
 local ds={};for _,d in ipairs(p.deaths) do if U.AnaPlayerOn(p.players[d.p] and p.players[d.p].n) then ds[#ds+1]=d end end
 local n=#ds
 colHeader('deaths',x,y,w,A.T('ana.view.deaths'),tostring(n))
 local yy=y-34
 if n==0 then colNote(x,yy,w,A.T('ana.col.noDeaths'));return end
 local cap=n>5 and 4 or 5
 for i=1,math.min(n,cap) do local d=ds[i]
  local f=row(yy,x+6,w-12,24)
  if f then
   f:SetBackdropColor(U.Color('ground-2'))
   local pl=p.players[d.p];local kb=d.recap and d.recap[1];local r,g,b=classColor(pl and pl.c)
   cell(f,1,d.t and U.TimeFine(d.t) or '?',6,50,{size=11,kind='mono',ink=i==1 and 'tl-death' or 'ink-2'})
   cell(f,2,AN.Short(pl and pl.n),60,math.floor((w-12)*0.30),{rgb={r,g,b},kind=i==1 and 'textMedium' or nil})
   local kx=64+math.floor((w-12)*0.30)
   local mk=#planned>0 and 64 or 0
   if kb then f.icon:SetTexture(U.Icon(kb.id));f.icon:SetSize(16,16);f.icon:SetPoint('LEFT',f,'LEFT',kx,0);f.icon:Show()
    cell(f,3,kb.melee and A.T('ana.melee') or AN.SpellName(kb.id,kb.name),kx+20,w-12-kx-20-mk-6,{size=11,ink='ink-2'})
   else cell(f,3,A.T('ana.noRecap'),kx,w-12-kx-mk,{size=11,ink='ink-3'}) end
   if mk>0 then local cov=#AN.CoverAt(planned,d.t)>0;cell(f,4,A.T(cov and 'ana.col.covered' or 'ana.col.uncovered'),w-12-mk-4,mk,{size=10,right=true,ink=cov and 'heal' or 'minor'}) end
   refs.rows[d]=f
   f:SetScript('OnEnter',function(self) U.AnaLink(d,true);U.AnaCards.death(self,p,d,planned) end)
   f:SetScript('OnLeave',function(self) U.AnaLink(d,false);U.CardHide(self) end)
   f:SetScript('OnClick',function() if d.t then U.AnaJump(d.t) end end)
  end
  yy=yy-24
 end
 if n>cap then colNote(x,yy,w,A.T('ana.col.more',{n=n-cap})) end
end
function COLS.damage(p,x,y,w,planned,refs)
 local by=U.anaDmgBy or 'ability'
 local f=colHeader('damage',x,y,w,A.T('ana.view.damage'),nil,p.src~='log' and A.T('ana.col.noTimes') or nil)
 local sx=x+w-8-70-4
 for k=2,1,-1 do local key=k==1 and 'ability' or 'player'
  local b=U.anaMarks:get();local label=A.T(k==1 and 'ana.col.byAbility' or 'ana.col.byPlayer');local bw=math.ceil(#label*6.2)+16
  sx=sx-bw;b:SetSize(bw,20);b:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',sx,y-7+(U.anaScroll or 0));sx=sx-4
  b.text:ClearAllPoints();b.text:SetPoint('CENTER',0,0);b.text:SetJustifyH('CENTER');b.text:SetText(label);U.Font(b.text,11)
  local on=by==key;b:SetBackdropColor(U.Color(on and 'ground-3' or 'ground-2'));b:SetBackdropBorderColor(U.ColorA('line',on and 1 or 0.6));b.text:SetTextColor(U.Color(on and 'ink' or 'ink-3'))
  b.isSwitch=key
  b:SetScript('OnClick',function() U.anaDmgBy=key;U.DrawAnalyzer() end)
 end
 local yy=y-34
 if by=='ability' then
  local sp={};for _,e in ipairs(p.spells) do if U.AnaSpellOn(e.id) then sp[#sp+1]=e end end
  if #sp==0 then colNote(x,yy,w,A.T('ana.col.noDamage'));return end
  local max=math.max(1,sp[1].total or 1)
  for i=1,math.min(5,#sp) do local e=sp[i]
   local g=row(yy,x+6,w-12,24)
   if g then
    local av=e.avoid;local m=AN.Mechanic(p.enc,e.id);if m and (m.kind=='ground' or m.kind=='area') then av=true end
    g:SetBackdropColor(U.Color('ground-2'))
    g.bar:SetColorTexture(U.ColorA(av and 'major' or 'ink',av and 0.24 or 0.08));g.bar:ClearAllPoints();g.bar:SetPoint('LEFT',g,'LEFT',0,0);g.bar:SetSize(math.max(1,(w-12)*e.total/max),24);g.bar:Show()
    g.icon:SetTexture(U.Icon(e.id));g.icon:SetSize(16,16);g.icon:SetPoint('LEFT',g,'LEFT',6,0);g.icon:Show()
    cell(g,1,AN.SpellName(e.id,e.name),28,w-12-28-64,{size=12,ink=av and 'major' or 'ink'})
    cell(g,2,U.Num(e.total),w-12-62,56,{right=true,kind='mono',size=12})
    g.spell=e
    g:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));U.AnaHighlightSpell(e,true);U.AnaCards.spell(self,p,e) end)
    g:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('ground-2'));U.AnaHighlightSpell(e,false);U.CardHide(self) end)
    g:SetScript('OnClick',function() A.db.anaView='damage';U.anaScroll=0;U.RenderAnalyzer() end)
   end
   yy=yy-24
  end
 else
  local list={};for _,pl in ipairs(p.players) do if (pl.taken or 0)>0 and U.AnaPlayerOn(pl.n) then list[#list+1]=pl end end
  table.sort(list,function(a,b) return a.taken>b.taken end)
  if #list==0 then colNote(x,yy,w,A.T('ana.col.noDamage'));return end
  local max=math.max(1,list[1].taken)
  for i=1,math.min(5,#list) do local pl=list[i]
   local g=row(yy,x+6,w-12,24)
   if g then local r,gg,b=classColor(pl.c)
    g:SetBackdropColor(U.Color('ground-2'))
    g.bar:SetColorTexture(U.ColorA('ink',0.08));g.bar:ClearAllPoints();g.bar:SetPoint('LEFT',g,'LEFT',0,0);g.bar:SetSize(math.max(1,(w-12)*pl.taken/max),24);g.bar:Show()
    if (pl.avoid or 0)>0 then g.bar2:SetColorTexture(U.ColorA('major',0.5));g.bar2:ClearAllPoints();g.bar2:SetPoint('BOTTOMLEFT',g,'BOTTOMLEFT',0,0);g.bar2:SetSize(math.max(1,(w-12)*pl.avoid/max),3);g.bar2:Show() end
    cell(g,1,AN.Short(pl.n),8,w-12-8-130,{size=12,rgb={r,gg,b}})
    if (pl.avoid or 0)>0 then cell(g,2,U.Num(pl.avoid),w-12-124,56,{right=true,size=11,ink='major'}) end
    cell(g,3,U.Num(pl.taken),w-12-62,56,{right=true,kind='mono',size=12})
    g.player=pl
    g:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));U.AnaCards.player(self,p,pl) end)
    g:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('ground-2'));U.CardHide(self) end)
    g:SetScript('OnClick',function() U.anaDmgBy='player';A.db.anaView='damage';U.anaScroll=0;U.RenderAnalyzer() end)
   end
   yy=yy-24
  end
 end
end
function COLS.mechanics(p,x,y,w,planned,refs)
 local list=avoidByPlayer(p)
 colHeader('mechanics',x,y,w,A.T('ana.col.avoidTitle'),list[1] and tostring(#list) or nil)
 local yy=y-34
 local kick={};local plan=AN.PlanFor(p.enc)
 local assigned={};for _,k in ipairs(plan and plan.kicks or {}) do for _,n in ipairs(k.players or {}) do assigned[n:lower()]=true end end
 for _,pl in ipairs(p.players) do if (assigned[AN.Short(pl.n):lower()] or assigned[pl.n:lower()]) and (pl.ints or 0)==0 then kick[#kick+1]=pl end end
 local kickRows=#kick>0 and math.min(2,#kick) or 1
 local cap=5-kickRows
 if #list==0 then colNote(x,yy,w,A.T('ana.col.noAvoid'));yy=yy-24 end
 if #list>0 then
  local max=math.max(1,list[1].a)
  for i=1,math.min(cap,#list) do local it=list[i]
   local g=row(yy,x+6,w-12,24)
   if g then local pl=p.players[it.p];local r,gg,b=classColor(pl and pl.c)
    g:SetBackdropColor(U.Color('ground-2'))
    g.bar:SetColorTexture(U.ColorA('major',0.22));g.bar:ClearAllPoints();g.bar:SetPoint('LEFT',g,'LEFT',0,0);g.bar:SetSize(math.max(1,(w-12)*it.a/max),24);g.bar:Show()
    cell(g,1,AN.Short(pl and pl.n),8,w-12-8-120,{size=12,rgb={r,gg,b}})
    cell(g,2,'x'..it.c,w-12-112,44,{right=true,size=11,ink='ink-3',kind='mono'})
    cell(g,3,U.Num(it.a),w-12-62,56,{right=true,kind='mono',size=12})
    g:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));cardAvoid(self,p,it) end)
    g:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('ground-2'));U.CardHide(self) end)
    g:SetScript('OnClick',function() A.db.anaView='mechanics';U.anaScroll=0;U.RenderAnalyzer() end)
   end
   yy=yy-24
  end
  yy=yy-(cap-math.min(cap,#list))*24
 end
 if #kick>0 then
  for i=1,math.min(2,#kick) do local pl=kick[i];local r,gg,b=classColor(pl.c)
   local g=row(yy,x+6,w-12,24);if g then g:SetBackdrop(false);g:EnableMouse(false);cell(g,1,AN.Short(pl.n),8,140,{size=12,rgb={r,gg,b}});cell(g,2,A.T('ana.col.noKick'),152,w-12-160,{size=11,ink='minor'}) end
   yy=yy-24
  end
 else
  colNote(x,yy,w,A.T('ana.col.ints',{n=AN.Total(p,'ints'),d=AN.Total(p,'disp')}))
 end
end
function U.AnaColumn(key,p,x,y,w,h,planned,refs)
 local bg=row(y,x,w,h)
 if bg then bg:EnableMouse(false);U.Radius(bg,6);bg:SetBackdropColor(U.ColorA('ground-2',0.45));bg:SetBackdropBorderColor(U.Color('line'));bg:SetFrameLevel(U.anaBody:GetFrameLevel()+1) end
 COLS[key](p,x,y,w,planned,refs)
end
local LANE_KEY={['ana.lane.phases']='phases',['ana.lane.deaths']='deaths',['ana.lane.damage']='damage',['ana.lane.used']='used',['ana.lane.planned']='planned'}
U.ANA_LANES={'phases','deaths','damage','used','planned'}
local function LT(k) return U.anaLaneTex[k]:get() end
local function LM(k) return U.anaLaneMarks[k]:get() end
function draw.overview(p,W,H)
 local log=p.src=='log';local planned=AN.Planned(p)
 local refs={rows={},marks={}};U.anaRefs=refs
 local ncol=W>=1040 and 3 or (W>=700 and 2 or 1);local COLH=30+5*24+12;local GAP=16
 local colRows=math.ceil(3/ncol);local colBlock=colRows*COLH+(colRows-1)*GAP
 local y=-12
 local leftW=math.max(340,math.floor((W-32)*0.42));local rx=16+leftW+24;local rw=W-16-rx
 if rw<300 then leftW=W-32;rw=0 end
 local ph=AN.PhaseAt(p.enc,p.dur)
 text(1,result(p),16,y,leftW,18,p.success and 'kill' or 'ink','display')
 local meta={A.T('ana.pullN',{n=p.n or '?'})..(log and (' '..A.T('ana.fromLog')) or ''),p.dur and A.T('ana.lasted',{t=U.Time(p.dur)}) or nil,ph and A.T('ana.phaseEst',{p=ph.id}) or nil,diffName(p.diff),clockAt(p.at)~='' and clockAt(p.at) or nil}
 local m={};for i=1,5 do if meta[i] then m[#m+1]=meta[i] end end
 text(2,table.concat(m,', '),16,y-26,leftW,11,'ink-3')
 local tiles={{A.T('ana.t.deaths'),tostring(#p.deaths)},{A.T('ana.t.taken'),U.Num(AN.Total(p,'taken'))},{A.T('ana.t.avoid'),U.Num(AN.Total(p,'avoid')),'major'},{A.T('ana.t.ints'),tostring(AN.Total(p,'ints'))}}
 local tw=math.floor(math.min(leftW,480)/4);local top=y-48+(U.anaScroll or 0)
 for i,t in ipairs(tiles) do
  local l=U.anaMarks:get();l:EnableMouse(false);l:SetBackdrop(false);l:SetSize(tw-8,14);l:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',16+(i-1)*tw,top);l.text:SetPoint('LEFT',0,0);l.text:SetText(t[1]);U.Font(l.text,11);l.text:SetTextColor(U.Color('ink-3'))
  local v=U.anaMarks:get();v:EnableMouse(false);v:SetBackdrop(false);v:SetSize(tw-8,22);v:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',16+(i-1)*tw,top-15);v.text:SetPoint('LEFT',0,0);v.text:SetText(t[2]);U.Font(v.text,18,'display');v.text:SetTextColor(U.Color(t[3] or 'ink'))
 end
 local leftH=48+40
 local fs=AN.Findings(p);local fy=y;local rightH=0
 if rw>0 then
  local f=row(fy,rx,rw,18);if f then f:SetBackdrop(false);f:EnableMouse(false);cell(f,1,A.T('ana.findings'),0,rw,{size=11,ink='ink-3'}) end
  fy=fy-20
  if #fs==0 then local g=row(fy,rx,rw,20);if g then g:SetBackdrop(false);g:EnableMouse(false);cell(g,1,A.T('ana.f.none'),0,rw,{ink='ink-3',size=12}) end;fy=fy-20 end
  for i=1,math.min(#fs,5) do local it=fs[i]
   local g=row(fy,rx,rw,20)
   if g then g:SetBackdrop(false);g.bar:SetColorTexture(U.Color(it.color));g.bar:SetSize(6,6);g.bar:ClearAllPoints();g.bar:SetPoint('LEFT',4,0);g.bar:Show()
    cell(g,1,A.T(it.key,it.vars),16,rw-20,{size=12})
    g:SetScript('OnEnter',function(self) self:SetBackdrop(true);self:SetBackdropColor(U.Color('ground-2')) end);g:SetScript('OnLeave',function(self) self:SetBackdrop(false) end)
    g:SetScript('OnClick',function() if it.t then U.AnaJump(it.t) elseif it.view then A.db.anaView=it.view;U.anaScroll=0;U.RenderAnalyzer() end end)
   end
   fy=fy-20
  end
  rightH=y-fy
 end
 y=y-math.max(leftH,rightH)-10
 local deathMarks=refs.marks
 local z=U.AnaView(p);local total,vs,vspan=z.total,z.start,z.span;local ve=vs+vspan
 local CTRL=24
 sectionTitle(y,16,A.T('ana.axis'),A.T('ana.zoomHelp'),W-32-3*CTRL-130)
 do
  local cy=y+(U.anaScroll or 0)
  local zin,fit,zout,read=U.anaZoomIn,U.anaZoomFit,U.anaZoomOut,U.anaZoomRead
  local xr=W-16-CTRL
  zin:ClearAllPoints();zin:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',xr,cy);zin:Show()
  xr=xr-U.HEADER_GAP-fit:GetWidth();fit:ClearAllPoints();fit:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',xr,cy);fit:Show();U.Active(fit,vspan<total-0.5)
  xr=xr-U.HEADER_GAP-CTRL;zout:ClearAllPoints();zout:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',xr,cy);zout:Show()
  read:ClearAllPoints();read:SetPoint('RIGHT',U.anaBody,'TOPLEFT',xr-8,cy-CTRL/2)
  read:SetText(vspan>=total-0.5 and A.T('ana.zoomAll') or A.T('ana.zoomRange',{a=U.Time(vs),b=U.Time(ve)}));read:Show()
  U.anaAxisShown=true
 end
 y=y-32
 local LABEL=120;local x0=16+LABEL;local aw=math.max(40,W-16-x0)
 local top=y+(U.anaScroll or 0)
 local function X(t) return x0+(t-vs)/vspan*aw end
 local function inView(t) return t>=vs and t<=ve end
 local function span2(t1,t2) local a,b=X(math.max(t1,vs)),X(math.min(t2,ve));if b-a<1 and not (t2>=vs and t1<=ve) then return nil end;return a,math.max(2,b-a) end
 local lanes={{key='ana.lane.phases',h=20},{key='ana.lane.deaths',h=30}}
 local function stack(list,dur)
  local st,ends={},{}
  for _,c in ipairs(list) do
   if c.t+dur(c)>=vs and c.t<=ve then
    local lane;for i,e in ipairs(ends) do if e<=X(c.t) then lane=i;break end end
    if not lane then lane=#ends+1 end;ends[lane]=X(c.t)+22+math.max(0,X(c.t+dur(c))-X(c.t));st[c]=lane
   end
  end
  return st,math.max(1,math.min(#ends,3))
 end
 local used={};local match=AN.MatchPlan(p,planned);U.anaMatch=match
 if log then for _,c in ipairs(p.casts or {}) do local ty,cd=AN.CastType(c.id);local who=p.players[c.p] and p.players[c.p].n
  if ty=='raid' and U.AnaSpellOn(cd.id) and U.AnaPlayerOn(who) then used[#used+1]={t=c.t,dur=cd.duration or 0,spellId=cd.id,name=cd.name,who=who,src=c} end end end
 local plannedV={};for _,c in ipairs(planned) do if U.AnaSpellOn(c.spellId) and U.AnaPlayerOn(c.who) then plannedV[#plannedV+1]=c end end
 local stacks,cdLanes=stack(plannedV,function(c) return c.dur end)
 local ustacks,usedLanes=stack(used,function(c) return c.dur end)
 local fixed=32+20+30+(log and 24*usedLanes or 0)+24*cdLanes+8*(log and 5 or 3)+18+14
 local DH=math.max(64,math.min(110,math.floor(H+y-fixed-colBlock-12)))
 if log then lanes[#lanes+1]={key='ana.lane.damage',h=DH};lanes[#lanes+1]={key='ana.lane.used',h=24*usedLanes} end
 lanes[#lanes+1]={key='ana.lane.planned',h=24*cdLanes}
 local laneY={};local laneAt={};local yy=top
 for i,l in ipairs(lanes) do laneY[i]=yy;laneAt[l.key]=yy;yy=yy-l.h-8 end
 local axisBottom=yy
 z.lanes={};for i,l in ipairs(lanes) do z.lanes[i]={key=LANE_KEY[l.key],top=laneY[i]+4,bottom=laneY[i]-l.h-4} end
 z.rect={x0=x0,aw=aw,top=top,bottom=axisBottom-16}
 do
  for i,l in ipairs(lanes) do
   local lk=LANE_KEY[l.key];local lb=LM(lk);lb:EnableMouse(false);lb:SetBackdrop(false);lb:SetSize(LABEL-8,l.key=='ana.lane.damage' and 18 or l.h);lb:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',16,laneY[i]);lb.text:SetText(A.T(l.key));lb.text:SetTextColor(U.Color('ink-2'));U.Font(lb.text,12);lb.text:SetWidth(LABEL-14)
   local r=LT(lk);r:SetColorTexture(U.Color('line'));r:SetSize(aw,1);r:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',x0,laneY[i]-l.h);U.Crisp(r)
  end
  local pm=A.PhaseMaps[p.enc]
  for i,ph in ipairs(pm and pm.phases or {}) do
   local a,w=span2(ph.start,math.min(ph['end'] or total,total))
   if a and ph.start<total then
    local t=LT('phases');t:SetColorTexture(U.ColorA(i%2==1 and 'tl-phase' or 'tl-intermission',0.35));t:SetSize(math.max(1,w-1),20);t:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',a,laneY[1])
    local lb=LM('phases');lb:EnableMouse(false);lb:SetBackdrop(false);lb:SetSize(math.max(1,w-1),20);lb:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',a,laneY[1]);lb.text:SetText(w>=18 and tostring(ph.id) or '');U.Font(lb.text,11);lb.text:SetTextColor(U.Color('ink-2'))
   end
  end
  local step=600;for _,s in ipairs(U.ANA_TICKS) do if s/vspan*aw>=64 then step=s;break end end
  z.step=step
  for t=math.ceil(vs/step)*step,ve,step do
   local tk=U.anaTex:get();tk:SetColorTexture(U.ColorA('ink',0.08));tk:SetSize(1,top-axisBottom);tk:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',X(t),top);U.Crisp(tk)
   if X(t)+44<=x0+aw then local lb=U.anaMarks:get();lb:EnableMouse(false);lb:SetBackdrop(false);lb:SetSize(44,14);lb:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',X(t)+3,axisBottom+2);lb.text:SetText(U.Time(t));U.Font(lb.text,11,'mono');lb.text:SetTextColor(U.Color('ink-3')) end
  end
  if p.dur and inView(p.dur) then local e=U.anaTex:get();e:SetColorTexture(U.Color(p.success and 'kill' or 'tl-death'));e:SetSize(2,top-axisBottom);e:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',X(p.dur)-1,top) end
  for _,d in ipairs(p.deaths) do
   if d.t and inView(d.t) and U.AnaPlayerOn(p.players[d.p] and p.players[d.p].n) then
    local b=LM('deaths');b:SetSize(6,22);b:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',X(d.t)-3,laneY[2]-4);b:SetBackdropColor(U.Color('tl-death'));b:SetBackdropBorderColor(U.Color('tl-death'))
    deathMarks[d]=b
    b:SetScript('OnEnter',function(self) U.AnaCards.death(self,p,d,planned);U.AnaLink(d,true) end);b:SetScript('OnLeave',function(self) U.CardHide(self);U.AnaLink(d,false) end)
   end
  end
  if log then
   local ly=laneAt['ana.lane.damage'];local base=ly-DH;local room=DH-18;z.dmgRoom=room
   local raid=p.raid or {};local bin=math.max(1,math.ceil(3*vspan/aw));local b0=math.floor(vs/bin)*bin
   local vals,sorted=U.anaScratch.vals,U.anaScratch.sorted;local n,m,peak=0,0,0
   for s=b0,ve,bin do local sum=0;for sec=s+1,s+bin do sum=sum+(raid[sec] or 0) end;n=n+1;vals[n]=sum/bin;if sum>0 then m=m+1;sorted[m]=sum/bin end;if sum/bin>peak then peak=sum/bin end end
   for i=n+1,#vals do vals[i]=nil end;for i=m+1,#sorted do sorted[i]=nil end
   local cap=peak
   if m>=10 then table.sort(sorted);local p95=sorted[math.max(1,math.ceil(m*0.95))];if p95>0 and peak>p95*1.5 then cap=p95 end end
   z.dmg={b0=b0,bin=bin,ly=ly,cap=cap,peak=peak}
   local bl=LT('damage');bl:SetColorTexture(U.Color('line'));bl:SetSize(aw,1);bl:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',x0,base);U.Crisp(bl)
   local tl=LT('damage');tl:SetColorTexture(U.ColorA('ink',0.10));tl:SetSize(aw,1);tl:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',x0,base+room);U.Crisp(tl)
   if cap>0 then
    local sc=LM('damage');sc:EnableMouse(false);sc:SetBackdrop(false);sc:SetSize(LABEL-8,14);sc:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',16,base+room+7);sc.text:SetText(A.T('ana.scaleTop',{v=U.Num(cap)}));U.Font(sc.text,11,'mono');sc.text:SetTextColor(U.Color('ink-3'))
   end
   local tags,lastTag=0,-100
   for i=1,n do local v=vals[i]
    if v>0 and cap>0 then
     local s=b0+(i-1)*bin;local a,w=span2(s,s+bin)
     if a then
      local over=v>cap*1.001;local h=math.max(1,math.floor(room*math.min(1,v/cap)+0.5))
      local t=LT('damage');if over then t:SetColorTexture(U.Color('tl-spike')) else t:SetColorTexture(U.ColorA('major',0.6)) end;t:SetSize(math.max(2,math.floor(w)-1),h);t:SetPoint('BOTTOMLEFT',U.anaBody,'TOPLEFT',math.floor(a),base)
      if over and tags<4 and a-lastTag>=52 then
       tags=tags+1;lastTag=a
       local lb=LM('damage');lb:EnableMouse(false);lb:SetBackdrop(false);lb:SetSize(52,14);lb:SetPoint('BOTTOMLEFT',U.anaBody,'TOPLEFT',math.max(x0,math.floor(a)-2),base+room+1);lb.text:SetText(U.Num(v));U.Font(lb.text,10,'mono');lb.text:SetTextColor(U.Color('tl-spike'))
      end
     end
    end
   end
   local hv=U.anaHover;hv:ClearAllPoints();hv:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',x0,ly);hv:SetSize(aw,DH);hv.pull=p;hv.last=nil;hv:Show()
   for _,c in ipairs(used) do
    local lane=ustacks[c];if lane and lane<=usedLanes then
     local uy=laneAt['ana.lane.used']-(lane-1)*24
     if c.dur>0 then local a,w=span2(c.t,c.t+c.dur);if a then local bar=LT('used');bar:SetColorTexture(U.ColorA('kill',0.3));bar:SetSize(w,6);bar:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',a,uy-16) end end
     if inView(c.t) then
      local b=LM('used');b:SetSize(20,20);b:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',X(c.t)-10,uy-1);b.icon:SetTexture(U.Icon(c.spellId));b.icon:SetAllPoints();b.icon:Show()
      b:SetScript('OnEnter',function(self) U.AnaCards.cast(self,p,c,false,match) end)
      b:SetScript('OnLeave',function(self) U.CardHide(self) end)
     end
    end
   end
  end
  for _,c in ipairs(plannedV) do
   local lane=stacks[c];if lane and lane<=cdLanes then
    local ly=laneAt['ana.lane.planned']-(lane-1)*24
    if c.dur>0 then local a,w=span2(c.t,c.t+c.dur);if a then local bar=LT('planned');bar:SetColorTexture(U.ColorA('heal',c.after and 0.12 or 0.3));bar:SetSize(w,6);bar:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',a,ly-16) end end
    if inView(c.t) then
     local b=LM('planned');b:SetSize(20,20);b:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',X(c.t)-10,ly-1);b.icon:SetTexture(U.Icon(c.spellId));b.icon:SetAllPoints();b.icon:Show();b:SetAlpha(c.after and 0.45 or 1)
     b:SetScript('OnEnter',function(self) U.AnaCards.cast(self,p,c,true,match) end)
     b:SetScript('OnLeave',function(self) U.CardHide(self) end)
    end
   end
  end
 end
 y=y-(top-axisBottom)-14
 local cw=math.floor((W-32-(ncol-1)*GAP)/ncol)
 for i,key in ipairs({'deaths','damage','mechanics'}) do
  local ci=(i-1)%ncol;local ri=math.floor((i-1)/ncol)
  U.AnaColumn(key,p,16+ci*(cw+GAP),y-ri*(COLH+GAP),cw,COLH,planned,refs)
 end
 y=y-colBlock
 return -y+16
end
function draw.deaths(p,W,H)
 local y=-12;local planned=AN.Planned(p)
 sectionTitle(y,16,A.T('ana.view.deaths'),A.T('ana.deathsSub',{n=#p.deaths}),W-32);y=y-30
 if #p.deaths==0 then local f=row(y,16,W-32);if f then f:SetBackdrop(false);cell(f,1,A.T('ana.noDeaths'),12,W-56,{ink='ink-3'}) end;return 80 end
 local cols={{'#',12,24},{A.T('ana.c.time'),40,60},{A.T('ana.c.player'),104,150},{A.T('ana.c.kb'),282,math.floor(W*0.34)},{A.T(p.src=='log' and 'ana.c.active' or 'ana.c.cover'),290+math.floor(W*0.34),W-32-(300+math.floor(W*0.34))}}
 local hf=row(y,16,W-32,20);if hf then hf:SetBackdrop(false);hf:EnableMouse(false);for i,c in ipairs(cols) do cell(hf,i,c[1],c[2],c[3],{size=11,ink='ink-3'}) end end
 y=y-22
 for i,d in ipairs(p.deaths) do
  if U.AnaPlayerOn(p.players[d.p] and p.players[d.p].n) then
  local f=row(y,16,W-32,30)
  if f then
   local pl=p.players[d.p];local kb=d.recap and d.recap[1]
   if i%2==0 then f:SetBackdropColor(U.Color('ground-2')) end
   cell(f,1,tostring(i),12,24,{ink='ink-3',kind='mono'});cell(f,2,d.t and U.TimeFine(d.t) or '?',40,60,{kind='mono'})
   local r,g,b=classColor(pl and pl.c);cell(f,3,AN.Short(pl and pl.n),104,150,{rgb=rgb(r,g,b),kind='textMedium'})
   if kb then
    f.icon:SetTexture(U.Icon(kb.id));f.icon:SetSize(20,20);f.icon:SetPoint('LEFT',f,'LEFT',282,0);f.icon:Show()
    local s=(kb.melee and A.T('ana.melee') or AN.SpellName(kb.id,kb.name))..'  '..U.Num(kb.amt or 0)..((kb.over and kb.over>0) and ('  '..A.T('ana.overkill',{n=U.Num(kb.over)})) or '')..(kb.src and ('  '..withRealm(p,kb.src)) or '')
    cell(f,4,s,308,math.floor(W*0.34)-30)
   else cell(f,4,A.T('ana.noRecap'),282,math.floor(W*0.34),{ink='ink-3'}) end
   if p.src=='log' then
    local act=AN.ActiveAt(p,d.t);cell(f,5,activeText(p,d),cols[5][2],cols[5][3],{ink=#act==0 and 'minor' or 'ink-2',size=11})
   else
    local cv=coverText(p,planned,d);cell(f,5,cv,cols[5][2],cols[5][3],{ink=#AN.CoverAt(planned,d.t)==0 and 'minor' or 'ink-2',size=11})
   end
   f:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));U.AnaCards.death(self,p,d,planned) end)
   f:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color(i%2==0 and 'ground-2' or 'panel'));U.CardHide(self) end)
  end
  y=y-32
  end
 end
 y=y-8;local f=row(y,16,W-32,22);if f then f:SetBackdrop(false);f:EnableMouse(false);cell(f,1,A.T(p.src=='log' and 'ana.deathsNoteLog' or 'ana.deathsNote'),0,W-32,{size=11,ink='ink-3'}) end
 return -y+40
end
function draw.damage(p,W,H)
 local total=AN.Total(p,'taken');local half=math.floor((W-48)/2)
 local y0=-12
 sectionTitle(y0,16,A.T('ana.byAbility'),A.T('ana.byAbilitySub'),half)
 sectionTitle(y0,32+half,A.T('ana.byPlayer'),A.T('ana.byPlayerSub'),half)
 local y=y0-30;local maxS=(p.spells[1] and p.spells[1].total) or 1
 for _,e in ipairs(p.spells) do
  if U.AnaSpellOn(e.id) then
  local f=row(y,16,half,28)
  if f then
   f.bar:SetColorTexture(U.ColorA(e.avoid and 'major' or 'ink',e.avoid and 0.22 or 0.07));f.bar:ClearAllPoints();f.bar:SetPoint('TOPLEFT',f,'TOPLEFT',0,0);f.bar:SetSize(math.max(1,half*e.total/maxS),28);f.bar:Show()
   f.icon:SetTexture(U.Icon(e.id));f.icon:SetSize(20,20);f.icon:SetPoint('LEFT',f,'LEFT',6,0);f.icon:Show()
   local tags={};if e.avoid then tags[#tags+1]=A.T('ana.tag.avoid') end;if e.deadly then tags[#tags+1]=A.T('ana.tag.deadly') end
   cell(f,1,AN.SpellName(e.id,e.name),32,half-260,{kind='textMedium'})
   cell(f,2,table.concat(tags,', '),half-226,90,{size=11,ink=e.avoid and 'major' or 'ink-3'})
   cell(f,3,A.T('ana.hitN',{n=#e.hits}),half-134,56,{size=11,ink='ink-3',right=true})
   cell(f,4,U.Num(e.total),half-74,44,{right=true,kind='mono'})
   cell(f,5,total>0 and pct(e.total/total*100) or '',half-28,24,{size=11,ink='ink-3',right=true})
   f:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));U.AnaCards.spell(self,p,e) end)
   f:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('panel'));U.CardHide(self) end)
  end
  y=y-30
  end
 end
 local yl=y
 local players={};for i,pl in ipairs(p.players) do if U.AnaPlayerOn(pl.n) then players[#players+1]=pl end end
 table.sort(players,function(a,b) return (a.taken or 0)>(b.taken or 0) end)
 local maxP=(players[1] and players[1].taken) or 1;if maxP<=0 then maxP=1 end
 y=y0-30
 for _,pl in ipairs(players) do
  local f=row(y,32+half,half,28)
  if f then
   local r,g,b=classColor(pl.c)
   f.bar:SetColorTexture(U.ColorA('ink',0.07));f.bar:ClearAllPoints();f.bar:SetPoint('TOPLEFT',f,'TOPLEFT',0,0);f.bar:SetSize(math.max(1,half*(pl.taken or 0)/maxP),28);f.bar:Show()
   if (pl.avoid or 0)>0 then f.bar2:SetColorTexture(U.ColorA('major',0.35));f.bar2:ClearAllPoints();f.bar2:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',0,0);f.bar2:SetSize(math.max(1,half*pl.avoid/maxP),4);f.bar2:Show() end
   cell(f,1,AN.Short(pl.n),10,half-200,{rgb=rgb(r,g,b),kind='textMedium'})
   cell(f,2,(pl.avoid or 0)>0 and A.T('ana.avoidN',{n=U.Num(pl.avoid)}) or '',half-186,110,{size=11,ink='major',right=true})
   cell(f,3,U.Num(pl.taken or 0),half-66,56,{right=true,kind='mono'})
   f.player=pl
   f:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));U.AnaCards.player(self,p,pl) end)
   f:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('panel'));U.CardHide(self) end)
  end
  y=y-30
 end
 return -math.min(y,yl)+40
end
function draw.mechanics(p,W,H)
 local y=-12
 sectionTitle(y,16,A.T('ana.view.mechanics'),A.T('ana.mechSub'),W-32);y=y-30
 local av={};for _,it in ipairs(AN.Avoidable(p)) do if U.AnaSpellOn(it.spell.id) then av[#av+1]=it end end
 if #av==0 then local f=row(y,16,W-32);if f then f:SetBackdrop(false);cell(f,1,A.T('ana.noAvoid'),12,W-56,{ink='ink-3'}) end;y=y-ROW end
 for _,it in ipairs(av) do
  local e=it.spell
  local f=row(y,16,W-32,28)
  if f then f:SetBackdropColor(U.Color('ground-2'))
   f.icon:SetTexture(U.Icon(e.id));f.icon:SetSize(20,20);f.icon:SetPoint('LEFT',f,'LEFT',6,0);f.icon:Show()
   cell(f,1,AN.SpellName(e.id,e.name),32,260,{kind='textMedium'})
   cell(f,2,A.T('ana.tip.'..it.kind),300,W-32-300-200,{size=11,ink='ink-2'})
   cell(f,3,A.T('ana.mechTotal',{n=#e.hits,amt=U.Num(e.total)}),W-32-190,180,{size=11,ink='major',right=true})
   f:SetScript('OnEnter',function(self) U.AnaCards.spell(self,p,e) end);f:SetScript('OnLeave',function(self) U.CardHide(self) end)
  end
  y=y-32
  local x=32;local cy=y
  for _,h in ipairs(e.hits) do if U.AnaPlayerOn(p.players[h.p] and p.players[h.p].n) then
   local pl=p.players[h.p];local label=AN.Short(pl and pl.n)..'  '..U.Num(h.a)..(h.c and h.c>1 and (' x'..h.c) or '')
   local w=math.ceil(#label*6.6)+20
   if x+w>W-16 then x=32;cy=cy-26 end
   local top=cy+(U.anaScroll or 0)
   if top<=0 and top-22>-H then
    local b=U.anaMarks:get();b:SetSize(w,22)
    b:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));U.AnaCards.chip(self,p,e,h) end);b:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('panel-2'));U.CardHide(self) end);b:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',x,top);b:SetBackdropColor(U.Color('panel-2'));b.text:SetText(label);U.Font(b.text,11)
    local r,g,bl=classColor(pl and pl.c);b.text:SetTextColor(r,g,bl)
   end
   x=x+w+6
  end end
  y=cy-32
 end
 y=y-8
 sectionTitle(y,16,A.T('ana.intTitle'),A.T(p.src=='log' and 'ana.intSubLog' or 'ana.intSub'),W-32);y=y-28
 local kickers={};local plan=AN.PlanFor(p.enc)
 for _,k in ipairs(plan and plan.kicks or {}) do for _,n in ipairs(k.players or {}) do kickers[n:lower()]=true end end
 local list={};for _,pl in ipairs(p.players) do if U.AnaPlayerOn(pl.n) and ((pl.ints or 0)>0 or (pl.disp or 0)>0 or kickers[AN.Short(pl.n):lower()] or kickers[pl.n:lower()]) then list[#list+1]=pl end end
 table.sort(list,function(a,b) return (a.ints or 0)+(a.disp or 0)>(b.ints or 0)+(b.disp or 0) end)
 if #list==0 then local f=row(y,16,W-32);if f then f:SetBackdrop(false);cell(f,1,A.T('ana.noInts'),12,W-56,{ink='ink-3'}) end;y=y-ROW end
 local hf=row(y,16,W-32,20);if hf then hf:SetBackdrop(false);hf:EnableMouse(false);cell(hf,1,A.T('ana.c.player'),12,200,{size=11,ink='ink-3'});cell(hf,2,A.T('ana.c.ints'),230,90,{size=11,ink='ink-3',right=true});cell(hf,3,A.T('ana.c.disp'),330,90,{size=11,ink='ink-3',right=true}) end
 y=y-22
 for _,pl in ipairs(list) do
  local f=row(y,16,W-32,26)
  if f then f:SetBackdrop(false)
   local r,g,b=classColor(pl.c);cell(f,1,AN.Short(pl.n),12,200,{rgb=rgb(r,g,b)})
   cell(f,2,tostring(pl.ints or 0),230,90,{right=true,kind='mono'});cell(f,3,tostring(pl.disp or 0),330,90,{right=true,kind='mono'})
   if kickers[AN.Short(pl.n):lower()] or kickers[pl.n:lower()] then cell(f,4,A.T('ana.kicker'),440,200,{size=11,ink=(pl.ints or 0)==0 and 'minor' or 'ink-3'}) end
  end
  y=y-26
 end
 if p.src=='log' and #(p.ints or {})>0 then
  y=y-8;sectionTitle(y,16,A.T('ana.intOrder'),A.T('ana.intOrderSub',{n=#p.ints}),W-32);y=y-28
  for _,it in ipairs(p.ints) do if U.AnaPlayerOn(p.players[it.p] and p.players[it.p].n) then
   local f=row(y,16,W-32,24)
   if f then f:SetBackdrop(false);f:EnableMouse(false)
    local pl=p.players[it.p];local r,g,b=classColor(pl and pl.c)
    cell(f,1,U.TimeFine(it.t),12,70,{kind='mono',size=11});cell(f,2,AN.Short(pl and pl.n),90,180,{rgb=rgb(r,g,b)})
    if it.id then f.icon:SetTexture(U.Icon(it.id));f.icon:SetSize(16,16);f.icon:SetPoint('LEFT',f,'LEFT',276,0);f.icon:Show() end
    cell(f,3,it.id and AN.SpellName(it.id,it.name) or '',298,W-32-310,{size=11,ink='ink-2'})
   end
   y=y-24
  end end
 end
 return -y+40
end
function draw.compare(p,W,H)
 local y=-12;local list=AN.Recent(p,14)
 sectionTitle(y,16,A.T('ana.view.compare'),A.T('ana.cmpSub',{n=#list}),W-32);y=y-30
 local cols={{A.T('ana.c.pull'),12,70},{A.T('ana.c.result'),86,110},{A.T('ana.c.dur'),200,60},{A.T('ana.c.phase'),264,50},{A.T('ana.c.deaths'),318,56},{A.T('ana.c.first'),380,180},{A.T('ana.c.avoid'),566,80},{A.T('ana.c.top'),652,W-32-660}}
 local hf=row(y,16,W-32,20);if hf then hf:SetBackdrop(false);hf:EnableMouse(false);for i=1,6 do local c=cols[i];cell(hf,i,c[1],c[2],c[3],{size=11,ink='ink-3'}) end
  hf.bar:Hide() end
 for i=7,8 do local c=cols[i];local top=y+(U.anaScroll or 0);if top<=0 then local b=U.anaMarks:get();b:EnableMouse(false);b:SetBackdrop(false);b:SetSize(c[3],20);b:SetPoint('TOPLEFT',U.anaBody,'TOPLEFT',16+c[2],top);b.text:SetText(c[1]);U.Font(b.text,11);b.text:SetTextColor(U.Color('ink-3')) end end
 y=y-22
 for _,q in ipairs(list) do
  local f=row(y,16,W-32,28)
  if f then
   local sel=q.id==p.id;if sel then f:SetBackdropColor(U.Color('ground-3')) end
   local hp=AN.BossPct(q)
   if hp and not q.success then f.bar:SetColorTexture(U.ColorA('heal',0.18));f.bar:ClearAllPoints();f.bar:SetPoint('BOTTOMLEFT',f,'BOTTOMLEFT',0,0);f.bar:SetSize(math.max(1,(W-32)*(100-hp)/100),3);f.bar:Show() end
   cell(f,1,'#'..tostring(q.n or '?')..(q.src=='log' and (' '..A.T('ana.logShort')) or (clockAt(q.at)~='' and ('  '..clockAt(q.at)) or '')),12,70,{kind='mono',size=11})
   cell(f,2,result(q),86,110,{ink=q.success and 'kill' or 'ink'})
   cell(f,3,q.dur and U.Time(q.dur) or '?',200,60,{kind='mono'})
   local ph=AN.PhaseAt(q.enc,q.dur);cell(f,4,ph and tostring(ph.id) or '',264,50)
   cell(f,5,tostring(#(q.deaths or {})),318,56,{kind='mono'})
   local d1=q.deaths and q.deaths[1];local who=d1 and q.players[d1.p]
   cell(f,6,d1 and (AN.Short(who and who.n)..'  '..(d1.t and U.Time(d1.t) or '?')) or '',380,180,{size=11})
   local av=AN.Avoidable(q);local top=av[1] and av[1].spell
   local extra=U.anaMarks:get();extra:EnableMouse(false);extra:SetBackdrop(false);extra:SetSize(W-32-566,28);extra:SetPoint('TOPLEFT',f,'TOPLEFT',566,0);extra:SetFrameLevel(f:GetFrameLevel()+1)
   extra.text:SetText(U.Num(AN.Total(q,'avoid'))..(top and ('        '..AN.SpellName(top.id,top.name)) or ''));U.Font(extra.text,11);extra.text:SetTextColor(U.Color('ink-2'))
   f:SetScript('OnClick',function() AN.selected=q.id;A.db.anaView='overview';U.anaScroll=0;U.RenderAnalyzer() end)
   f:SetScript('OnEnter',function(self) if not sel then self:SetBackdropColor(U.Color('ground-2')) end;U.AnaCards.pull(self,p,q) end)
   f:SetScript('OnLeave',function(self) if not sel then self:SetBackdropColor(U.Color('panel')) end;U.CardHide(self) end)
  end
  y=y-30
 end
 return -y+40
end
axisControls=function()
 local on=U.anaAxisShown
 if on then local tr=U.anaTrack;tr.force=true;tr:SetScript('OnUpdate',U.AnaTrackTick);tr:Show() else U.AnaTrackStop() end
 for _,w in ipairs({U.anaZoomOut,U.anaZoomFit,U.anaZoomIn,U.anaZoomRead}) do if not on then w:Hide() end end
 if not (U.anaZoomState and U.anaZoomState.dmg) and U.anaHover:IsShown() then U.anaHover:Hide() end
end
function U.DrawAnalyzer()
 if not U.anaBody or not U.anaBody:IsShown() then return end
 begin()
 local W,H=U.anaBody:GetWidth(),U.anaBody:GetHeight()
 if not A.Allowed() then message({A.T('ana.locked'),A.T('ana.lockedSub')});return end
 local p=AN.Selected()
 if not p then
  local ok,why=AN.Available()
  local lines={A.T('ana.emptyTitle'),A.T('ana.emptyHow')}
  if not ok then lines[#lines+1]=A.T(why=='api' and 'ana.why.api' or 'ana.why.off') end
  message(lines);return
 end
 if p.meter==false then
  message({pullTitle(p)..', '..result(p),A.T('ana.why.'..(p.why or 'error')),A.T('ana.emptyHow')});return
 end
 local view=A.db.anaView or 'overview';if not draw[view] then view='overview' end
 local height=draw[view](p,W,H) or H;U.anaHeight=height
 local maxScroll=math.max(0,height-H)
 if (U.anaScroll or 0)>maxScroll then U.anaScroll=maxScroll;begin();draw[view](p,W,H) end
 axisControls()
end
