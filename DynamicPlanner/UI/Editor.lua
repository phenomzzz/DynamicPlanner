local _, A = ...
local U=A.UI
local DISPLAY={'','Icon','Bar','Text','Circle'}
local SWATCH={{'ink'},{'warm-4'},{'warm-3'},{'cool-1'},{'kill'},{'c-rup'}}
local SELECTORS={'everyone','tank','healer','melee','ranged','group1','group2','group3','group4'}
local W,PAD=560,18
local function extra(a,key) for _,kv in ipairs(a.extra or {}) do if kv[1]==key then return kv[2] end end end
local function setExtra(a,key,value)
 a.extra=a.extra or {}
 for i,kv in ipairs(a.extra) do if kv[1]==key then if value==nil or value=='' then table.remove(a.extra,i) else kv[2]=value end;return end end
 if value~=nil and value~='' then a.extra[#a.extra+1]={key,value} end
end
local function colorString(key) local r,g,b=U.Color(key);return string.format('%.2f %.2f %.2f 1',r,g,b) end
function U.Input(parent,width,numeric)
 local e=CreateFrame('EditBox',nil,parent);e:SetSize(width,A.Theme.size.control);U.Surface(e,'ground-2')
 e:SetAutoFocus(false);e:SetTextInsets(8,8,0,0);U.Font(e,13);e:SetTextColor(U.Color('ink'))
 if numeric then e:SetJustifyH('RIGHT') end
 e:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
 e:SetScript('OnEnterPressed',function(self) self:ClearFocus() end)
 e:SetScript('OnEditFocusGained',function(self) self:SetBackdropBorderColor(U.Color('accent'));self:HighlightText() end)
 e:SetScript('OnEditFocusLost',function(self) self:SetBackdropBorderColor(U.Color('line'));self:HighlightText(0,0) end)
 return e
end
local function caption(f,text,x,y) local l=U.Label(f,text,x,y,11,'textMedium');l:SetTextColor(U.Color('ink-3'));return l end
local function build()
 local f=CreateFrame('Frame',nil,U.window);U.Surface(f,'panel','border');f:SetSize(W,620);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:EnableMouse(true)
 f:SetToplevel(true);f.labels={}
 f.icon=f:CreateTexture(nil,'ARTWORK');f.icon:SetSize(32,32);f.icon:SetPoint('TOPLEFT',PAD,-PAD);f.icon:SetTexCoord(0.08,0.92,0.08,0.92)
 f.title=U.Label(f,'',PAD+42,-PAD-1,16,'textMedium');f.sub=U.Label(f,'',PAD+42,-PAD-20,11);f.sub:SetTextColor(U.Color('ink-3'))
 local y=-66
 f.labels.who=caption(f,'',PAD,y);f.labels.what=caption(f,'',PAD+262,y);y=y-16
 f.who=U.Button(f,'',PAD,y,252,function(b)
  local items={}
  for _,p in ipairs(A.model.plan.roster or {}) do if p.active then
   local token=p.classToken;local r,g,bb=U.Color(token and 'class-'..token or 'ink')
   items[#items+1]={string.format('|cff%02x%02x%02x%s|r',r*255,g*255,bb*255,p.name),function() f.data.tag=p.name;U.EditorRefresh() end,checked=f.data.tag==p.name}
  end end
  for _,s in ipairs(SELECTORS) do items[#items+1]={s,function() f.data.tag=s;U.EditorRefresh() end,checked=f.data.tag==s} end
  U.Menu(b,items)
 end,{fixed=true})
 f.what=U.Button(f,'',PAD+262,y,W-PAD*2-262,function(b)
  local player;for _,p in ipairs(A.model.plan.roster or {}) do if p.name==f.data.tag then player=p end end
  local items={{A.T('pk.text'),function() f.data.spellId=nil;U.EditorRefresh() end,checked=f.data.spellId==nil}}
  for _,s in ipairs(A.Cooldowns) do if not player or A.Model.canCast(player,s) then
   local icon=U.Icon(s.id);items[#items+1]={'|T'..icon..':16:16:0:0|t '..s.name,function() f.data.spellId=s.id;U.EditorRefresh() end,checked=f.data.spellId==s.id}
  end end
  U.Menu(b,items)
 end,{fixed=true})
 y=y-40
 for _,b in ipairs({f.who,f.what}) do b.text:ClearAllPoints();b.text:SetPoint('LEFT',10,0);b.text:SetPoint('RIGHT',-24,0);b.text:SetJustifyH('LEFT');U.Font(b.text,13);b.chev=U.Label(b,'v',0,0,11,'textMedium');b.chev:ClearAllPoints();b.chev:SetPoint('RIGHT',-10,0);b.chev:SetTextColor(U.Color('ink-3')) end
 f.labels.text=caption(f,'',PAD,y);y=y-16
 f.text=U.Input(f,W-PAD*2);f.text:SetPoint('TOPLEFT',PAD,y);f.text:SetScript('OnTextChanged',function(self,user) if user then f.data.text=self:GetText();U.EditorPreview() end end);y=y-44
 f.labels.when=caption(f,'',PAD,y);y=y-16
 f.phases=CreateFrame('Frame',nil,f);f.phases:SetPoint('TOPLEFT',PAD,y);f.phases:SetSize(260,30);f.phasePool=U.Pool(f.phases)
 f.offset=U.Input(f,72,true);f.offset:SetPoint('TOPLEFT',PAD+270,y);f.whenY=y
 f.offset:SetScript('OnTextChanged',function(self,user) if user then local v=tonumber(self:GetText());if v then f.data.time=A.NSRT.round1(v);U.EditorPreview() end end end)
 local nx=PAD+344
 for _,step in ipairs({-5,-1,1,5}) do
  local b=U.Button(f,(step>0 and '+' or '')..step,nx,y,40,function() f.data.time=A.NSRT.round1((f.data.time or 0)+step);U.EditorRefresh() end,{key=false});nx=nx+44
  f.nudges=f.nudges or {};f.nudges[#f.nudges+1]=b
 end
 y=y-34;f.abs=U.Label(f,'',PAD,y,11,'mono');f.abs:SetTextColor(U.Color('ink-3'));y=y-26
 f.labels.alert=caption(f,'',PAD,y);y=y-16
 f.display={};local dx=PAD;f.displayY=y
 for _,d in ipairs(DISPLAY) do
  local b=U.Button(f,d=='' and 'Default' or d,dx,y,0,function() f.data.DisplayType=d;U.EditorRefresh() end,{key=false});f.display[d]=b;dx=dx+b:GetWidth()+4
 end
 y=y-44
 local function field(key,label,x,w,numeric)
  f.labels[key]=caption(f,label,x,y);local e=U.Input(f,w,numeric);e:SetPoint('TOPLEFT',x,y-16)
  e:SetScript('OnTextChanged',function(self,user) if user then f.data[key]=self:GetText();U.EditorPreview() end end);f[key]=e;return e
 end
 field('dur','',PAD,110,true);field('countdown','',PAD+122,110,true);field('TTSTimer','',PAD+244,110,true);y=y-58
 field('TTS','',PAD,W-PAD*2);y=y-58
 f.labels.sound=caption(f,'',PAD,y);f.labels.glow=caption(f,'',PAD+262,y);y=y-16
 f.sound=U.Button(f,'',PAD,y,252,function(b)
  local items={{A.T('addon.none'),function() f.data.sound=nil;U.EditorRefresh() end,checked=not f.data.sound}}
  local LSM=LibStub and LibStub('LibSharedMedia-3.0',true)
  if LSM then for _,name in ipairs(LSM:List('sound')) do items[#items+1]={name,function() f.data.sound=name;U.EditorRefresh();local path=LSM:Fetch('sound',name);if path then PlaySoundFile(path,'Master') end end,checked=f.data.sound==name} end end
  U.Menu(b,items)
 end,{fixed=true})
 f.glow=U.Button(f,'',PAD+262,y,W-PAD*2-262,function(b)
  local set={};for n in (f.data.glowunit or ''):gmatch('[^%s:]+') do set[n]=true end
  local items={{A.T('addon.none'),function() f.data.glowunit=nil;U.EditorRefresh() end}}
  for _,p in ipairs(A.model.plan.roster or {}) do if p.active then items[#items+1]={p.name,function()
   set[p.name]=not set[p.name] or nil;local list={};for n in pairs(set) do list[#list+1]=n end;table.sort(list);f.data.glowunit=#list>0 and table.concat(list,' ') or nil;U.EditorRefresh()
  end,multi=true,isChecked=function() return set[p.name]==true end} end end
  U.Menu(b,items)
 end,{fixed=true})
 for _,b in ipairs({f.sound,f.glow}) do b.text:ClearAllPoints();b.text:SetPoint('LEFT',10,0);b.text:SetPoint('RIGHT',-24,0);b.text:SetJustifyH('LEFT');U.Font(b.text,13);b.chev=U.Label(b,'v',0,0,11,'textMedium');b.chev:ClearAllPoints();b.chev:SetPoint('RIGHT',-10,0);b.chev:SetTextColor(U.Color('ink-3')) end
 y=y-40
 f.labels.color=caption(f,'',PAD,y);y=y-16
 f.swatches={};local sx=PAD
 local none=U.Button(f,'',sx,y,60,function() f.data.colors=nil;U.EditorRefresh() end,{fixed=true,key=false});f.noColor=none;sx=sx+64
 for _,sw in ipairs(SWATCH) do
  local b=CreateFrame('Button',nil,f);b:SetSize(30,30);b:SetPoint('TOPLEFT',sx,y);U.Surface(b,sw[1]);b.value=colorString(sw[1])
  b:SetScript('OnClick',function() f.data.colors=b.value;U.EditorRefresh() end);f.swatches[#f.swatches+1]=b;sx=sx+36
 end
 y=y-46
 f.labels.preview=caption(f,'NSRT',PAD,y);y=y-16
 f.preview=CreateFrame('Frame',nil,f);U.Surface(f.preview,'ground-2','line',6);f.preview:SetPoint('TOPLEFT',PAD,y);f.preview:SetSize(W-PAD*2,40);y=y-40-18
 f:SetHeight(-y+A.Theme.size.control+PAD)
 f.previewText=U.Label(f.preview,'',10,-6,11,'mono');f.previewText:SetWidth(W-PAD*2-20);f.previewText:SetWordWrap(true);f.previewText:SetTextColor(U.Color('ink-2'))
 f.delete=U.Button(f,'',PAD,-(620-PAD-30),0,function()
  A.Edit(function(plan) for k,v in ipairs(plan.lines) do if v==f.assignment then table.remove(plan.lines,k);break end end end);f:Hide()
 end,{key=false})
 f.cancel=U.Button(f,'',0,0,100,function() f:Hide() end,{key=false})
 f.save=U.Button(f,'',0,0,110,function() U.EditorSave() end,{key=false})
 f.save:ClearAllPoints();f.save:SetPoint('BOTTOMRIGHT',-PAD,PAD);f.cancel:ClearAllPoints();f.cancel:SetPoint('RIGHT',f.save,'LEFT',-6,0)
 f.delete:ClearAllPoints();f.delete:SetPoint('BOTTOMLEFT',PAD,PAD)
 f:EnableKeyboard(true);U.Propagate(f,true)
 f:SetScript('OnKeyDown',function(self,key) if key=='ESCAPE' then U.Propagate(self,false);self:Hide() else U.Propagate(self,true) end end)
 U.editor=f
 return f
end
local function lineOf(d)
 local a={tag=d.tag or '',phase=d.phase,time=d.time or 0,spellId=d.spellId,text=(d.text and d.text~='') and d.text or nil,extra={}}
 for _,kv in ipairs(d.extra or {}) do a.extra[#a.extra+1]={kv[1],kv[2]} end
 for _,k in ipairs({'DisplayType','dur','countdown','TTS','TTSTimer','sound','glowunit','colors'}) do setExtra(a,k,d[k]) end
 return a
end
function U.EditorPreview()
 local f=U.editor;if not f then return end
 local ok,text=pcall(A.NSRT.serialize,{encounterId=A.boss.id,name=A.boss.name,difficulty='Mythic',lines={lineOf(f.data)}})
 f.previewText:SetText(ok and (text:match('\n(.*)$') or '') or ('|cffff6060'..tostring(text)..'|r'))
 local t=A.Model.absolute({phase=f.data.phase,time=f.data.time or 0},A.model.phases)
 f.abs:SetText(t and A.T('addon.fromPull',{t=U.TimeFine(t)}) or '')
end
function U.EditorRefresh()
 local f=U.editor;local d=f.data;local L=A.T
 local cd=A.CD[d.spellId]
 f.icon:SetTexture(d.spellId and U.Icon(d.spellId) or 'Interface\\Icons\\INV_Misc_Note_01')
 f.title:SetText(cd and cd.name or (d.text~='' and d.text) or L('pk.text'))
 f.sub:SetText((d.tag or '')..(cd and cd.cooldown and cd.cooldown>0 and ('   '..L('addon.cooldownN',{n=cd.cooldown})) or ''))
 f.labels.who:SetText(L('ro.name'));f.labels.what:SetText(L('addon.spell'));f.labels.text:SetText(L('addon.customText'))
 f.labels.when:SetText(L('addon.when'));f.labels.alert:SetText(L('addon.display'));f.labels.dur:SetText(L('addon.duration'))
 f.labels.countdown:SetText(L('addon.countdown'));f.labels.TTSTimer:SetText(L('addon.ttsTimer'));f.labels.TTS:SetText(L('addon.tts'))
 f.labels.sound:SetText(L('addon.sound'));f.labels.glow:SetText(L('addon.glow'));f.labels.color:SetText(L('addon.color'))
 f.who:SetLabel(d.tag or '');f.what:SetLabel(cd and cd.name or L('pk.text'))
 f.text:SetText(d.text or '');f.offset:SetText(string.format('%.1f',d.time or 0))
 for _,k in ipairs({'dur','countdown','TTSTimer','TTS'}) do f[k]:SetText(d[k] or '') end
 f.sound:SetLabel(d.sound or L('addon.none'));f.glow:SetLabel(d.glowunit or L('addon.none'));f.noColor:SetLabel(L('addon.none'))
 f.display['']:SetLabel(L('addon.default'))
 do local list={};for _,k in ipairs(DISPLAY) do list[#list+1]=f.display[k] end;U.Flow(list,PAD,f.displayY,4) end
 for key,b in pairs(f.display) do U.Active(b,(d.DisplayType or '')==key) end
 for _,b in ipairs(f.swatches) do b:SetBackdropBorderColor(U.Color(d.colors==b.value and 'accent' or 'line')) end
 U.Active(f.noColor,not d.colors)
 f.phasePool:release();local px=0
 for _,p in ipairs(A.model.phases) do
  local b=f.phasePool:get();b.text:ClearAllPoints();b.text:SetPoint('CENTER');b.text:SetJustifyH('CENTER');U.Font(b.text,13,'textMedium');b.text:SetText(tostring(p.id))
  local w=math.max(34,math.ceil(b.text:GetUnboundedStringWidth()+20));b:SetPoint('TOPLEFT',px,0);b:SetSize(w,A.Theme.size.control);px=px+w+4
  U.Active(b,tostring(d.phase)==tostring(p.id));b:SetScript('OnClick',function() d.phase=tostring(p.id);U.EditorRefresh() end)
 end
 f.phases:SetWidth(math.max(1,px-4));f.offset:ClearAllPoints();f.offset:SetPoint('TOPLEFT',PAD+px+12,f.whenY)
 local list={};for _,b in ipairs(f.nudges) do list[#list+1]=b end;U.Flow(list,PAD+px+12+f.offset:GetWidth()+6,f.whenY,4)
 f.cancel:SetLabel(L('addon.cancel'));f.save:SetLabel(L('addon.save'));f.delete:SetLabel(L('addon.delete'));f.delete:SetShown(not f.isNew)
 U.EditorPreview()
end
function U.EditorSave()
 local f=U.editor;local d=f.data
 local ph=tonumber(d.phase);local t=tonumber(d.time)
 local bad=(not ph) or (not t) or math.abs(t)>86400 or (d.tag or '')=='' or (d.tag or ''):find('[;\r\n]') or ((d.text or ''):find('[;\r\n]')) or (not d.spellId and (d.text or '')=='')
 for _,k in ipairs({'dur','countdown','TTSTimer'}) do if d[k] and d[k]~='' and not tostring(d[k]):match('^%d+$') then bad=true end end
 if (d.TTS or ''):find('[;\r\n]') then bad=true end
 if bad then A.Message(A.T('addon.checkFields'));return end
 A.Edit(function(plan)
  local a=f.assignment;local line=lineOf(d)
  a.tag=line.tag;a.phase=t<0 and '1' or tostring(d.phase);a.time=A.NSRT.round1(t);a.spellId=line.spellId;a.text=line.text;a.extra=line.extra
  if f.isNew then plan.lines[#plan.lines+1]=a;A.Model.rosterFromTags(plan) end
 end)
 f:Hide()
end
function U.AssignmentEditor(assignment,isNew)
 if not A.Allowed() then return end
 local f=U.editor or build()
 f.assignment=assignment;f.isNew=isNew
 local d={tag=assignment.tag,phase=tostring(assignment.phase or (A.model.phases[1] and A.model.phases[1].id) or '1'),time=assignment.time or 0,spellId=assignment.spellId,text=assignment.text,extra={}}
 for _,kv in ipairs(assignment.extra or {}) do
  local k=kv[1]
  if k=='DisplayType' or k=='dur' or k=='countdown' or k=='TTS' or k=='TTSTimer' or k=='sound' or k=='glowunit' or k=='colors' then d[k]=kv[2] else d.extra[#d.extra+1]={kv[1],kv[2]} end
 end
 f.data=d;f:Show();U.EditorRefresh()
end
