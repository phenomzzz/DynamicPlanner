local _, A = ...
local U=A.UI
function U.Note(text,export)
 if not A.Allowed() then return end
 if not U.note then
  local f=CreateFrame('Frame',nil,U.window);U.Surface(f);f:SetSize(740,440);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:EnableMouse(true)
  f.title=U.Label(f,'',16,-14,16)
  local scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',16,-54);scroll:SetPoint('BOTTOMRIGHT',-36,56)
  local edit=CreateFrame('EditBox',nil,scroll);edit:SetMultiLine(true);U.Font(edit,12,'mono');edit:SetAutoFocus(false);edit:SetWidth(680);edit:SetHeight(320);edit:SetTextInsets(4,4,4,4);scroll:SetScrollChild(edit)
  edit:SetScript('OnEscapePressed',function() edit:ClearFocus();f:Hide() end)
  f.edit=edit;f.scroll=scroll
  f.apply=U.Button(f,'',600,-394,120,function()
   if f.export then edit:SetFocus();edit:HighlightText();return end
   local p=A.ParseImport(edit:GetText());if p then f:Hide();U.ImportReview(p) end
  end,{key=false})
  U.Button(f,'Close',16,-394,100,function() f:Hide() end,{always=true});U.note=f
 end
 local f=U.note;f.export=export;f.title:SetText(export and 'NSRT: Ctrl+C' or A.T('note.import'));f.apply:SetLabel(export and A.T('addon.select') or A.T('imp.reviewBtn'));f.apply:ClearAllPoints();f.apply:SetPoint('BOTTOMRIGHT',-16,16);f.edit:SetText(text or '');f.edit:SetCursorPosition(0);f.scroll:SetVerticalScroll(0);f:Show();f.edit:SetFocus();f.edit:HighlightText()
end
local HEAD_Y1,HEAD_Y2,ROW_GAP,GROUP_GAP=-12,-52,40,18
local function sepAt(i,x,y)
 local seps=U.headerSeps;local t=seps[i]
 if not t then t=U.window:CreateTexture(nil,'ARTWORK');t:SetColorTexture(U.Color('line'));t:SetSize(1,18);U.Crisp(t);seps[i]=t end
 t:ClearAllPoints();t:SetPoint('TOPLEFT',U.window,'TOPLEFT',math.floor(x),y-6);t:Show();return t
end
function U.LayoutHeader()
 local f=U.window;if not f or not U.closeButton then return end
 U.headerSeps=U.headerSeps or {};local nsep=0
 local function sep(x,y) nsep=nsep+1;sepAt(nsep,x,y) end
 local function at(b,x,y) b:ClearAllPoints();b:SetPoint('TOPLEFT',f,'TOPLEFT',math.floor(x),y) end
 local W=f:GetWidth()
 local x=W-12
 local function right(list,y,gap)
  for _,b in ipairs(list) do
   if b==false then x=x-GROUP_GAP/2;sep(x,y);x=x-GROUP_GAP/2
   elseif b:IsShown() then x=x-b:GetWidth();at(b,x,y);x=x-(gap or 4) end
  end
 end
 right({U.closeButton,U.helpButton,false,U.noteButton,false,U.gridButton,U.assignButton,U.kicksButton},HEAD_Y1,2)
 local plansW=U.plansButton:GetWidth()
 local titleMax=math.max(80,x-16-12-plansW-16)
 local natural=U.title:GetUnboundedStringWidth() or 0
 local tw=math.min(natural>0 and natural+2 or titleMax,titleMax);U.title:SetWidth(tw)
 U.title:ClearAllPoints();U.title:SetPoint('LEFT',f,'TOPLEFT',16,HEAD_Y1-A.Theme.size.control/2)
 at(U.plansButton,16+tw+12,HEAD_Y1)
 local lx=12
 local function left(list,y,gap)
  for _,b in ipairs(list) do
   if b==false then lx=lx+GROUP_GAP/2;sep(lx,y);lx=lx+GROUP_GAP/2
   elseif b:IsShown() then at(b,lx,y);lx=lx+b:GetWidth()+(gap or 4) end
  end
 end
 left({U.bossButton},HEAD_Y2,8);U.phasesFrame:SetWidth(math.max(1,U.chipsWidth or 0));at(U.phasesFrame,lx,HEAD_Y2);lx=lx+(U.chipsWidth or 0)
 left({false,U.modeButtons.ability,U.modeButtons.category},HEAD_Y2,2);lx=lx+2
 left({false,U.filtersButton,U.coverageButton},HEAD_Y2,4)
 local rightList={U.compactButton,false,U.panRight,U.panLeft,U.zoomIn,U.zoomFit,U.zoomOut,false,U.redoButton,U.undoButton}
 local need=0;for _,b in ipairs(rightList) do if b==false then need=need+GROUP_GAP elseif b:IsShown() then need=need+b:GetWidth()+2 end end
 local y=HEAD_Y2
 if lx+GROUP_GAP+need>W-12 then y=HEAD_Y2-ROW_GAP end
 x=W-12;right(rightList,y,2)
 for i=nsep+1,#U.headerSeps do U.headerSeps[i]:Hide() end
 U.headerRows=(y==HEAD_Y2) and 2 or 3
 U.panelTop=-(y-A.Theme.size.control)+12
 if U.roster then U.roster:ClearAllPoints();U.roster:SetPoint('TOPLEFT',12,-U.panelTop);U.roster:SetPoint('BOTTOMLEFT',12,36) end
 if U.canvas then U.canvas:ClearAllPoints();U.canvas:SetPoint('TOPLEFT',12+U.ROSTER_WIDTH+12,-U.panelTop);U.canvas:SetPoint('TOPRIGHT',-12,-U.panelTop) end
end
U.LayoutToolbar=function(chipsWidth) if chipsWidth then U.chipsWidth=chipsWidth end;U.LayoutHeader() end
function U.NoteItems()
 local items={{A.T('nb.title'),nil,title=true}}
 items[#items+1]={A.T('note.import'),function() U.Note('',false) end}
 items[#items+1]={A.T('addon.read'),function() A.ReadNSRT() end}
 items[#items+1]={A.T('note.copyRaid'),function() A.Export() end}
 items[#items+1]={A.T('pv.menu'),function() U.PreviewNote() end}
 if A.NSRTWritable() then items[#items+1]={A.T('addon.sendNsrt'),function() A.SendNSRT() end} end
 if A.Share and A.Share.InGroup() then items[#items+1]={A.T('addon.share'),function() A.Share.Send() end} end
 items[#items+1]={'',nil,divider=true}
 items[#items+1]={A.T('addon.clearAll'),function() U.ClearAll(U.noteButton) end}
 return items
end
function U.ClearAll(anchor)
 local n=#A.model.plan.lines
 if n==0 then A.Message(A.T('addon.nothingToClear'));return end
 U.Menu(anchor or U.noteButton,{{A.T('addon.clearConfirm',{n=n}),function() A.Edit(function(plan) plan.lines={} end);A.Message(A.T('addon.cleared',{n=n})) end},{A.T('addon.cancel'),function() end}})
end
function U.Render()
 if not U.window or not A.model then return end
 U.rev=(U.rev or 0)+1;U.rowsDirty=true
 U.RefreshLabels()
 U.canvas:SetHeight(A.view.pinHeight or U.window:GetHeight()*0.35)
 U.title:SetText(A.boss.name..', Mythic');U.bossButton:SetLabel(A.boss.name..'  v');U.plansButton:SetLabel(A.PlanName()..'  v')
 U.SheetHeader();U.RefreshProblems();U.status:SetText(A.PhaseMaps[A.boss.id].confirmed and '' or A.T('note.unconfirmed'))
 local unresolved=0;for _,a in ipairs(A.model.plan.lines) do if not A.Model.absolute(a,A.model.phases) then unresolved=unresolved+1 end end
 if unresolved>0 then U.status:SetText(A.T('addon.unknownPhases',{n=unresolved})) end
 for key,b in pairs(U.modeButtons) do b:SetLabel(A.T('bm.'..key)) end
 for key,b in pairs(U.presetButtons) do b:SetLabel(A.T('pb.'..key)) end
 local chipsWidth=0
 if U.phasePool then
  U.phasePool:release();U.phaseChips={};local buttons={{id='all',name='All'}};for _,p in ipairs(A.model.phases) do buttons[#buttons+1]=p end
  for i,p in ipairs(buttons) do
   local b=U.phasePool:get();b.text:SetText(p.id=='all' and A.T('all') or tostring(p.id));b.text:ClearAllPoints();b.text:SetPoint('CENTER');b.text:SetJustifyH('CENTER');U.Font(b.text,13,'textMedium')
   local w=math.max(30,math.ceil(b.text:GetUnboundedStringWidth()+20));b:SetPoint('TOPLEFT',chipsWidth,0);b:SetSize(w,A.Theme.size.control);chipsWidth=chipsWidth+w+2;U.phaseChips[#U.phaseChips+1]=b
   U.Active(b,(A.view.phase or 'all')==p.id)
   b:SetScript('OnClick',function() if not A.Allowed() then return end;A.view.phase=p.id;U.ZoomTo(p.start and p.start-2 or -5,p.start and (p['end']-p.start+4) or A.boss.duration+10);U.Render() end)
  end
 end
 U.chipsWidth=math.max(0,chipsWidth-2);U.noteButton:SetLabel(A.T('nb.btn')..'  v')
 U.undoButton:SetAlpha(#A.model.undo>0 and 1 or 0.4);U.redoButton:SetAlpha(#A.model.redo>0 and 1 or 0.4)
 U.LayoutHeader()
 for key,b in pairs(U.modeButtons) do U.Active(b,A.view.mode==key) end
 for key,b in pairs(U.rosterModes or {}) do U.Active(b,(A.view.rosterMode or 'role')==key) end
 for key,b in pairs(U.presetButtons) do U.Active(b,A.view.preset==key) end
 U.Active(U.compactButton,A.db.compact and true or false)
 U.DrawRoster();U.DrawTimeline();A.db.lastBoss=A.boss.id;A.SaveSoon()
 if U.DrawFilters then U.DrawFilters() end;if U.DrawCoverage then U.DrawCoverage() end;if U.DrawShortcuts then U.DrawShortcuts() end
 if U.RefreshPreview then U.RefreshPreview() end
end
function U.CreateWindow()
 local f=CreateFrame('Frame',nil,UIParent);U.window=f;f:Hide();U.Surface(f,'ground','line',10);f:SetSize(1480,820);f:SetPoint('CENTER');f:SetFrameStrata('HIGH');f:SetClampedToScreen(true);f:EnableMouse(true);f:SetMovable(true);f:SetResizable(true);f:SetResizeBounds(1240,680,2400,1400)
 local saved=A.db.window
 if saved then f:SetSize(saved.width,saved.height);f:ClearAllPoints();f:SetPoint(saved.point,UIParent,saved.relativePoint,saved.x,saved.y) end
 local function geometry()
  local point,_,relativePoint,xx,yy=f:GetPoint();A.db.window={point=point,relativePoint=relativePoint,x=xx,y=yy,width=f:GetWidth(),height=f:GetHeight()}
 end
 local drag=CreateFrame('Frame',nil,f);drag:SetPoint('TOPLEFT');drag:SetPoint('TOPRIGHT');drag:SetHeight(46);drag:EnableMouse(true);drag:RegisterForDrag('LeftButton');drag:SetScript('OnDragStart',function() if A.Allowed() then f:StartMoving() end end);drag:SetScript('OnDragStop',function() f:StopMovingOrSizing();geometry() end)
 U.title=U.Label(f,'Dynamic Planner',16,-18,20,'display');U.Line(U.title)
 U.closeButton=U.Button(f,'Close',0,-16,0,function() f:Hide() end,{always=true,quiet=true})
 U.bossButton=U.Button(f,'Boss',12,-68,220,function(b)
  local items={};for id,boss in pairs(A.Bosses) do items[#items+1]={boss.name,function() A.SelectBoss(id) end} end;table.sort(items,function(a,b)return a[1]<b[1] end);U.Menu(b,items)
 end)
 local phases=CreateFrame('Frame',nil,f);phases:SetPoint('TOPLEFT',240,-68);phases:SetSize(210,30);U.phasesFrame=phases;U.phasePool=U.Pool(phases)
 U.modeButtons={}
 for i,entry in ipairs({{'ability','By ability'},{'category','By category'}}) do local key=entry[1];U.modeButtons[key]=U.Button(f,entry[2],0,-68,0,function() A.view.mode=key;A.view.bossOffset=0;U.Render() end) end
 U.CreateFilters(f)
 U.CreateCoverage(f)
 U.coverageButton=U.Button(f,'',0,-104,0,function(b) U.ToggleCoverage(b) end,{key='fl.coverage'})
 do local cb=U.coverageButton;local oe,ol=cb:GetScript('OnEnter'),cb:GetScript('OnLeave')
  cb:SetScript('OnEnter',function(self) oe(self);U.Tooltip(self,A.T('addon.cvTip')) end);cb:SetScript('OnLeave',function(self) ol(self);GameTooltip:Hide() end) end
 U.filtersButton=U.Button(f,'Filters',0,-104,0,function(b) U.ToggleFilters(b) end,{key='fl.btn'})
 U.noteButton=U.Button(f,'Note',0,-104,0,function(b) U.Menu(b,U.NoteItems()) end,{key=false})
 U.noteButton.tip=function() return A.T('nb.tip') end
 U.undoButton=U.IconButton(f,'glyph:undo',30,function() if A.Model.undo(A.model) then U.ClearSelection();A.Save();U.Render() end end,'h.undoAria')
 U.redoButton=U.IconButton(f,'glyph:redo',30,function() if A.Model.redo(A.model) then U.ClearSelection();A.Save();U.Render() end end,'addon.redoTip')
 U.zoomOut=U.IconButton(f,'glyph:minus',30,function() U.ZoomTo(nil,(U.zoomTarget and U.zoomTarget.span or A.view.span)*1.25,A.view.start+A.view.span/2) end)
 U.zoomFit=U.Button(f,'Fit',0,-104,0,function() A.view.phase='all';U.ZoomTo(-5,A.boss.duration+10) end)
 U.zoomIn=U.IconButton(f,'glyph:plus',30,function() U.ZoomTo(nil,(U.zoomTarget and U.zoomTarget.span or A.view.span)*0.8,A.view.start+A.view.span/2) end)
 U.panLeft=U.IconButton(f,'glyph:left',30,function() A.view.start=math.max(-60,A.view.start-A.view.span/4);U.Render() end)
 U.panRight=U.IconButton(f,'glyph:right',30,function() A.view.start=A.view.start+A.view.span/4;U.Render() end)
 U.assignButton=U.Button(f,'Assignments',0,-104,0,function(b)
  local items={};for _,a in ipairs(A.model.plan.lines) do items[#items+1]={a.tag..' P'..a.phase..' +'..a.time..' '..(A.CD[a.spellId] and A.CD[a.spellId].name or a.spellId or a.text),function() U.AssignmentEditor(a,false) end} end
  U.Menu(b,items)
 end,{quiet=true})
 U.gridButton=U.Button(f,'Raid frames',0,-104,0,function() U.RaidGrid() end,{quiet=true})
 U.compactButton=U.Button(f,'Compact',0,-104,0,function() A.db.compact=not A.db.compact or nil;U.rowsDirty=true;U.Render() end,{key='addon.compact'})
 U.kicksButton=U.Button(f,'Kicks',0,-104,0,function() U.Kicks() end,{key='kk.row',quiet=true})
 U.helpButton=U.Button(f,'?',0,-104,30,function() U.Shortcuts() end,{key=false,quiet=true})
 do local hb=U.helpButton;local oe,ol=hb:GetScript('OnEnter'),hb:GetScript('OnLeave')
  hb:SetScript('OnEnter',function(self) oe(self);U.Tooltip(self,A.T('keys.btnTitle')) end);hb:SetScript('OnLeave',function(self) ol(self);GameTooltip:Hide() end) end
 U.plansButton=U.Button(f,'Main',0,-68,0,function(b) U.Menu(b,U.PlanItems()) end,{key=false})
 do local pb=U.plansButton;local oe,ol=pb:GetScript('OnEnter'),pb:GetScript('OnLeave')
  pb:SetScript('OnEnter',function(self) oe(self);U.Tooltip(self,A.T('pl.btnTitle')) end);pb:SetScript('OnLeave',function(self) ol(self);GameTooltip:Hide() end) end
 drag:SetFrameLevel(f:GetFrameLevel()+1)
 for _,b in ipairs({U.closeButton,U.helpButton,U.noteButton,U.gridButton,U.assignButton,U.kicksButton,U.plansButton}) do b:SetFrameLevel(drag:GetFrameLevel()+3) end
 U.CreateRoster(f);U.CreateTimeline(f)
 local pinGrip=U.IconButton(f,'glyph:grip',28,function(b)
  if U.pinDragged then U.pinDragged=false;return end
  U.Menu(b,U.HamburgerItems())
 end);pinGrip:ClearAllPoints();pinGrip:SetPoint('TOPRIGHT',U.canvas,'BOTTOMRIGHT',-4,-4);pinGrip:RegisterForDrag('LeftButton')
 pinGrip:SetScript('OnDragStart',function(self)
  if not A.Allowed() then return end
  U.pinDragged=true
  local _,startY=GetCursorPosition();local height=U.canvas:GetHeight()
  self:SetScript('OnUpdate',function()
   if not A.Allowed() then self:SetScript('OnUpdate',nil);return end
   local _,cy=GetCursorPosition();local h=math.floor(math.max(120,math.min(f:GetHeight()-320,height+(startY-cy)/f:GetEffectiveScale())))
   if h~=A.view.pinHeight then A.view.pinHeight=h;U.canvas:SetHeight(h);U.DrawTimeline() end
  end)
 end)
 pinGrip:SetScript('OnDragStop',function(self) self:SetScript('OnUpdate',nil);A.Save() end)
 pinGrip:SetScript('OnHide',function(self) self:SetScript('OnUpdate',nil) end)
 U.roster:SetPoint('TOPLEFT',12,-96);U.canvas:SetPoint('TOPLEFT',12+U.ROSTER_WIDTH+12,-96);U.canvas:SetPoint('TOPRIGHT',-12,-96)
 U.raidHeader=U.Label(f,'Raid cooldowns',294,-422,14);U.raidHeader:ClearAllPoints();U.raidHeader:SetPoint('TOPLEFT',U.canvas,'BOTTOMLEFT',10,-10)
 U.sheetInfo=U.Label(f,'',0,0,11);U.sheetInfo:ClearAllPoints();U.sheetInfo:SetPoint('LEFT',U.raidHeader,'RIGHT',12,0);U.sheetInfo:SetTextColor(U.Color('ink-3'))
 U.showHidden=U.Button(f,'',0,0,0,function() U.ShowAllHidden() end,{key='rail.showAll',height=22});U.showHidden:ClearAllPoints();U.showHidden:SetPoint('LEFT',U.sheetInfo,'RIGHT',8,0)
 U.problemsButton=U.Button(f,'',0,0,0,function() U.NextProblem() end,{key=false,height=22});U.problemsButton:ClearAllPoints();U.problemsButton:SetPoint('BOTTOMRIGHT',-30,8)
 do local pb=U.problemsButton;local oe,ol=pb:GetScript('OnEnter'),pb:GetScript('OnLeave')
  pb:SetScript('OnEnter',function(self) oe(self);U.Tooltip(self,A.T('pr.tip')) end);pb:SetScript('OnLeave',function(self) ol(self);GameTooltip:Hide() end) end
 U.status=U.Label(f,'',12,28,11);U.status:ClearAllPoints();U.status:SetPoint('BOTTOMLEFT',12,12);U.status:SetPoint('RIGHT',U.problemsButton,'LEFT',-10,0)
 local resize=U.IconButton(f,'Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up',20,nil);resize:ClearAllPoints();resize:SetPoint('BOTTOMRIGHT',-2,2);resize:SetBackdropColor(0,0,0,0);resize:SetBackdropBorderColor(0,0,0,0);resize.icon:SetVertexColor(1,1,1,0.6);resize:SetScript('OnEnter',function(self) self.icon:SetVertexColor(1,1,1,1) end);resize:SetScript('OnLeave',function(self) self.icon:SetVertexColor(1,1,1,0.6) end);resize:SetScript('OnMouseDown',function() if A.Allowed() then f:StartSizing('BOTTOMRIGHT') end end);resize:SetScript('OnMouseUp',function() f:StopMovingOrSizing();geometry();U.Render() end)
 local sizePending=false
 f:SetScript('OnSizeChanged',function()
  if sizePending or not U.canvas then return end;sizePending=true
  C_Timer.After(0,function() sizePending=false;if not U.canvas or not f:IsShown() then return end;U.canvas:SetHeight(A.view.pinHeight or f:GetHeight()*0.35);if U.LayoutHeader then U.LayoutHeader() end;U.DrawTimeline();U.DrawRoster() end)
 end)
 f:SetScript('OnShow',function() if U.StartHover then U.StartHover(U.canvas) end;if A.Share and A.Share.pending then U.ShareOffer() end end)
 f:SetScript('OnHide',function() U.CancelDrag();if U.hoverer then U.hoverer:SetScript('OnUpdate',nil) end;if U.scroller then U.scroller:SetScript('OnUpdate',nil);U.scroller:Hide() end;if U.zoomer then U.zoomTarget=nil;U.zoomer:SetScript('OnUpdate',nil);U.zoomer:Hide() end;if U.menu then U.menu:Hide() end;A.Save() end)
 f:EnableKeyboard(true);U.Propagate(f,true);f:SetScript('OnKeyDown',function(_,key)
  if not A.Allowed() then return end
  if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then U.Propagate(f,true);return end
  if key=='ESCAPE' and #U.Selected()>0 then U.Propagate(f,false);U.ClearSelection();U.RequestDraw()
  elseif key=='ESCAPE' then U.Propagate(f,false);f:Hide()
  elseif (key=='DELETE' or key=='BACKSPACE') and #U.Selected()>0 then U.Propagate(f,false);U.RemoveLines(U.Selected())
  elseif IsAltKeyDown() and (key=='LEFT' or key=='RIGHT') and #U.Selected()>0 then U.Propagate(f,false);U.MoveLines(U.Selected(),(key=='LEFT' and -1 or 1)*(IsShiftKeyDown() and 5 or 1))
  elseif IsControlKeyDown() and key=='Z' then U.Propagate(f,false);A.Model.undo(A.model);U.ClearSelection();A.Save();U.Render()
  elseif IsControlKeyDown() and key=='Y' then U.Propagate(f,false);A.Model.redo(A.model);U.ClearSelection();A.Save();U.Render()
  elseif key=='LEFT' or key=='RIGHT' then U.Propagate(f,false);U.PanBy((key=='LEFT' and -1 or 1)*A.view.span*(IsShiftKeyDown() and 0.5 or 0.15))
  elseif key=='=' or key=='+' or key=='NUMPADPLUS' then U.Propagate(f,false);U.ZoomTo(nil,(U.zoomTarget and U.zoomTarget.span or A.view.span)*0.8,A.view.start+A.view.span/2)
  elseif key=='-' or key=='NUMPADMINUS' then U.Propagate(f,false);U.ZoomTo(nil,(U.zoomTarget and U.zoomTarget.span or A.view.span)*1.25,A.view.start+A.view.span/2)
  elseif key=='/' and IsShiftKeyDown() then U.Propagate(f,false);U.Shortcuts()
  elseif key=='N' and not IsControlKeyDown() and not IsAltKeyDown() then U.Propagate(f,false);U.TogglePreview()
  elseif key=='0' or key=='NUMPAD0' then U.Propagate(f,false);A.view.phase='all';U.ZoomTo(-5,A.boss.duration+10)
  else U.Propagate(f,true) end
 end)
 U.Render()
end
function U.RefreshProblems()
 if not U.problemsButton then return end
 local r=A.Model.problems(A.model.plan,A.model.phases,A.CD,A.boss.kicks);U.problems=r
 if U.problemIndex and U.problemIndex>#r.list then U.problemIndex=nil end
 local parts={}
 if r.conflicts>0 then parts[#parts+1]=A.T(r.conflicts==1 and 'pr.conf1' or 'pr.conf',{n=r.conflicts}) end
 if r.uncovered>0 then parts[#parts+1]=A.T(r.uncovered==1 and 'pr.unc1' or 'pr.unc',{n=r.uncovered}) end
 local bad=#parts>0
 U.problemsButton:SetLabel(bad and table.concat(parts,', ') or A.T('pr.none'))
 U.problemsButton.text:SetTextColor(U.Color(bad and 'tl-conflict' or 'ink-3'))
end
function U.NextProblem()
 U.RefreshProblems();local list=U.problems and U.problems.list or {}
 if #list==0 then return end
 U.problemIndex=((U.problemIndex or 0) % #list)+1
 local pr=list[U.problemIndex];A.view.phase='all'
 A.view.start=pr.t-A.view.span/2
 if pr.line then
  for _,p in ipairs(A.model.plan.roster or {}) do for tok in pr.line.tag:gmatch('%S+') do if p.name:lower()==tok:lower() then U.JumpToPlayer(p) end end end
  U.selected=nil
 end
 U.Render()
end
function U.HamburgerItems()
 local items={}
 local function add(label,fn) items[#items+1]={label,fn} end
 add(A.T('menu.expand'),function() A.view.pinHeight=math.min(U.window:GetHeight()-320,(A.view.pinHeight or U.canvas:GetHeight())+80);U.canvas:SetHeight(A.view.pinHeight);U.DrawTimeline();A.Save() end)
 add(A.T('menu.shrink'),function() A.view.pinHeight=math.max(120,(A.view.pinHeight or U.canvas:GetHeight())-80);U.canvas:SetHeight(A.view.pinHeight);U.DrawTimeline();A.Save() end)
 add(A.T('menu.reset'),function() A.view.pinHeight=nil;U.canvas:SetHeight(U.window:GetHeight()*0.35);U.DrawTimeline();A.Save() end)
 add(A.T('addon.compact'),function() A.db.compact=not A.db.compact or nil;U.rowsDirty=true;U.Render() end)
 add(A.T('rail.showAll'),function() U.ShowAllHidden() end)
 add(A.T('kk.row'),function() U.Kicks() end)
 return items
end
function U.SheetHeader()
 local inRaid,out,has=0,0,{}
 for _,a in ipairs(A.model.plan.lines) do for tok in a.tag:gmatch('%S+') do has[tok:lower()]=true end end
 for _,p in ipairs(A.model.plan.roster or {}) do if p.active then inRaid=inRaid+1 elseif has[p.name:lower()] then out=out+1 end end
 local hidden=U.HiddenCount and U.HiddenCount() or 0
 U.raidHeader:SetText(A.T('rc.title'))
 local parts={A.T('addon.inRaid',{n=inRaid})};if out>0 then parts[#parts+1]=A.T('addon.notInRaid',{n=out}) end;if hidden>0 then parts[#parts+1]=A.T('rail.hidden',{n=hidden}) end
 parts[#parts+1]=A.T('rail.orderBtn',{mode=A.T('rail.'..(A.model.plan.railMode or 'role'))})
 U.sheetInfo:SetText(table.concat(parts,', '))
 U.showHidden:SetShown(hidden>0)
end
function U.PlanItems()
 local cur=A.PlanName();local items={{A.T('pl.aria'),nil,title=true}}
 for _,n in ipairs(A.PlanNames()) do items[#items+1]={n,function() A.OpenPlan(n) end,checked=(n==cur)} end
 items[#items+1]={'',nil,divider=true}
 items[#items+1]={A.T('pl.add'),function() U.Prompt(A.T('pl.newName'),A.UniquePlanName(A.T('pl.default')),function(v) A.NewPlan(v,false) end) end}
 items[#items+1]={A.T('pl.dup'),function() U.Prompt(A.T('pl.newName'),A.UniquePlanName(A.T('pl.copyOf',{name=cur})),function(v) A.NewPlan(v,true) end) end}
 items[#items+1]={A.T('pl.rename'),function() U.Prompt(A.T('pl.renameAria',{name=cur}),cur,function(v) if not A.RenamePlan(cur,v) then A.Message(A.T('addon.planNameTaken')) end;U.Render() end) end}
 items[#items+1]={A.T('pl.delete'),function() U.Menu(U.plansButton,{{A.T('addon.planDelete',{name=cur}),nil,title=true},{A.T('pl.confirmYes'),function() A.DeletePlan(cur);U.Render() end},{A.T('pl.cancel'),function() end}}) end}
 return items
end
function U.Prompt(title,default,onOk)
 if not A.Allowed() then return end
 local f=U.prompt
 if not f then
  f=CreateFrame('Frame',nil,U.window);U.Surface(f,'panel','border',10);f:SetSize(380,136);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:EnableMouse(true)
  f.title=U.Label(f,'',16,-16,14,'textMedium')
  local box=CreateFrame('EditBox',nil,f);U.Surface(box,'ground-2','line',6);box:SetPoint('TOPLEFT',16,-46);box:SetSize(348,30);U.Font(box,13);box:SetAutoFocus(false);box:SetTextInsets(10,10,0,0)
  f.box=box
  local function ok() local v=box:GetText();box:ClearFocus();f:Hide();if f.onOk and A.Allowed() then f.onOk(v) end end
  f.ok=U.Button(f,A.T('pl.save'),0,0,90,ok,{key='pl.save'});f.ok:ClearAllPoints();f.ok:SetPoint('BOTTOMRIGHT',-16,16)
  f.cancel=U.Button(f,A.T('pl.cancel'),0,0,90,function() box:ClearFocus();f:Hide() end,{key='pl.cancel',always=true});f.cancel:ClearAllPoints();f.cancel:SetPoint('RIGHT',f.ok,'LEFT',-8,0)
  box:SetScript('OnEnterPressed',ok);box:SetScript('OnEscapePressed',function() box:ClearFocus();f:Hide() end)
  f.submit=ok;U.prompt=f
 end
 f.onOk=onOk;f.title:SetText(title or '');f.box:SetText(default or '');f:Show();f.box:SetFocus();f.box:HighlightText()
end
