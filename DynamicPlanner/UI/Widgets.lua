local _, A = ...
local U=A.UI
function U.Crisp(r) if r and r.SetRoundLayoutToNearestPixel then r:SetRoundLayoutToNearestPixel(true) end;return r end
function U.Propagate(f,v) if InCombatLockdown() then return end;f:SetPropagateKeyboardInput(v) end
function U.Color(key) return unpack(A.Theme.colors[key] or A.Theme.colors.ink) end
function U.ColorA(key,alpha) local r,g,b=U.Color(key);return r,g,b,alpha end
local fontObjects={}
function U.FontObject(kind,size)
 kind=kind or 'text';size=size or A.Theme.size.text
 local byKind=fontObjects[kind];if not byKind then byKind={};fontObjects[kind]=byKind end
 local obj=byKind[size]
 if not obj then
  obj=CreateFont('DynamicPlannerFont_'..kind..'_'..size)
  local ok=obj:SetFont(A.Theme.fonts[kind] or A.Theme.fonts.text,size,'')
  if ok==false or not obj:GetFont() then obj:SetFont(STANDARD_TEXT_FONT,size,'') end
  obj:SetShadowOffset(0,0);obj:SetTextColor(U.Color('ink'));byKind[size]=obj
 end
 return obj
end
function U.Font(f,size,kind)
 local obj=U.FontObject(kind,size)
 if f.dpFont~=obj then f:SetFontObject(obj);f.dpFont=obj end
 f:SetTextColor(U.Color('ink'))
end
function U.Text(parent,layer)
 return parent:CreateFontString(nil,layer or 'OVERLAY','GameFontHighlight')
end
local TEX='Interface\\AddOns\\DynamicPlanner\\Media\\Textures\\'
local RADII={[3]=true,[4]=true,[6]=true,[10]=true}
function U.Radius(f,r)
 if f.dpRadius==r then return end
 f.dpRadius=r
 if r and RADII[r] then
  f.dpBg:SetTexture(TEX..'round'..r);f.dpRing:SetTexture(TEX..'ring'..r)
  for _,t in ipairs({f.dpBg,f.dpRing}) do if t.SetTextureSliceMargins then t:SetTextureSliceMargins(r,r,r,r);t:SetTextureSliceMode(0) end end
 else
  f.dpBg:SetColorTexture(1,1,1,1);f.dpRing:SetColorTexture(1,1,1,0)
 end
end
local function setFill(self,r,g,b,a) self.dpBg:SetVertexColor(r,g,b,a or 1) end
local function setRing(self,r,g,b,a) self.dpRing:SetVertexColor(r,g,b,a or 1) end
local function setShown(self,info) self.dpBg:SetShown(info~=nil and info~=false);self.dpRing:SetShown(info~=nil and info~=false) end
function U.Surface(f,color,border,radius)
 if not f.dpBg then
  f.dpBg=f:CreateTexture(nil,'BACKGROUND',nil,-8);f.dpBg:SetAllPoints()
  f.dpRing=f:CreateTexture(nil,'BACKGROUND',nil,-7);f.dpRing:SetAllPoints()
  U.Crisp(f.dpBg);U.Crisp(f.dpRing)
  f.SetBackdropColor=setFill;f.SetBackdropBorderColor=setRing;f.SetBackdrop=setShown
 end
 U.Radius(f,radius or 6);f.dpBg:Show();f.dpRing:Show()
 f:SetBackdropColor(U.Color(color or 'panel'));f:SetBackdropBorderColor(U.Color(border or 'line'))
end
function U.Hatch(f,key,alpha)
 if not f.dpHatch then
  f.dpHatch=f:CreateTexture(nil,'BACKGROUND',nil,-6);f.dpHatch:SetAllPoints()
  f.dpHatch:SetTexture(TEX..'hatch','REPEAT','REPEAT');f.dpHatch:SetHorizTile(true);f.dpHatch:SetVertTile(true)
 end
 f.dpHatch:SetVertexColor(U.ColorA(key,alpha or 0.55));f.dpHatch:Show()
end
function U.Line(f) f:SetWordWrap(false);if f.SetMaxLines then f:SetMaxLines(1) end;f:SetJustifyV('MIDDLE') end
function U.Label(parent,text,x,y,size,kind)
 local f=U.Text(parent);U.Font(f,size,kind)
 f:SetPoint('TOPLEFT',x or 0,y or 0);f:SetJustifyH('LEFT');f:SetText(text or '');return f
end
local function localeKey(text)
 for key,value in pairs(A.Locales.en) do if value==text then return key end end
end
function U.Button(parent,text,x,y,w,fn,opts)
 opts=opts or {}
 local b=CreateFrame('Button',nil,parent);b:SetPoint('TOPLEFT',x,y);b:SetHeight(opts.height or A.Theme.size.control)
 U.Surface(b,'panel-2','line',6);b.quiet=opts.quiet
 b.text=U.Text(b);U.Font(b.text,opts.size or A.Theme.size.text,'textMedium');U.Line(b.text)
 b.text:SetPoint('LEFT',10,0);b.text:SetPoint('RIGHT',-10,0);b.text:SetJustifyH('CENTER')
 b.minWidth=w or 0;b.fixed=opts.fixed
 function b:SetLabel(s)
  self.text:SetText(s or '')
  local w=self.text:GetUnboundedStringWidth();if not w or w<=0 then w=#(s or '')*7 end
  if not self.fixed then self:SetWidth(math.max(self.minWidth,math.ceil(w+20))) else self:SetWidth(self.minWidth) end
 end
 b:SetLabel((opts.key and (text==nil or text=='')) and A.T(opts.key) or text)
 b.localeKey=opts.key or localeKey(text)
 U.localizedButtons=U.localizedButtons or {};U.localizedButtons[#U.localizedButtons+1]=b
 b:SetScript('OnClick',function(self,button) if opts.always or A.Allowed() then fn(self,button) end end)
 b:SetScript('OnEnter',function(self) if not self.active then self:SetBackdropColor(U.Color('ground-3'));self:SetBackdropBorderColor(U.ColorA('ink',0.32)) end;if self.tip then U.Tooltip(self,self.tip()) end end)
 b:SetScript('OnLeave',function(self) if not self.active then U.Rest(self) end;if self.tip then GameTooltip:Hide() end end)
 U.Rest(b)
 return b
end
local function glyph(b,kind)
 local parts={}
 local function bar(w,h,x,y,rot) local t=b:CreateTexture(nil,'ARTWORK');t:SetColorTexture(1,1,1,1);t:SetSize(w,h);t:SetPoint('CENTER',x or 0,y or 0);if rot then t:SetRotation(rot) end;parts[#parts+1]=t end
 if kind=='minus' then bar(10,2)
 elseif kind=='plus' then bar(10,2);bar(2,10)
 elseif kind=='left' then bar(7,2,-1,2,0.785);bar(7,2,-1,-2,-0.785)
 elseif kind=='right' then bar(7,2,1,2,-0.785);bar(7,2,1,-2,0.785)
 elseif kind=='grip' then bar(14,1,0,3);bar(14,1,0,0);bar(14,1,0,-3)
 elseif kind=='undo' then bar(6,2,-4,3,0.785);bar(6,2,-4,-1,-0.785);bar(10,2,1,1);bar(2,6,5,-1)
 elseif kind=='redo' then bar(6,2,4,3,-0.785);bar(6,2,4,-1,0.785);bar(10,2,-1,1);bar(2,6,-5,-1) end
 local proxy={}
 function proxy:SetVertexColor(r,g,bb,a) for _,t in ipairs(parts) do t:SetVertexColor(r,g,bb,a) end end
 return proxy
end
function U.IconButton(parent,texture,size,fn,tip)
 local b=CreateFrame('Button',nil,parent);b:SetSize(size or A.Theme.size.control,size or A.Theme.size.control);U.Surface(b,'panel-2','line',6)
 if type(tip)=='string' and A.Locales and A.Locales.en[tip] then local key=tip;tip=function() return A.T(key) end end
 if texture:match('^glyph:') then b.icon=glyph(b,texture:sub(7))
 else b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('CENTER');b.icon:SetSize(16,16);b.icon:SetTexture(texture) end
 b.icon:SetVertexColor(U.Color('ink-2'))
 b.text=U.Text(b);b.text:SetText('');b.minWidth=size or A.Theme.size.control;function b:SetLabel() end
 b:SetScript('OnClick',function(self,button) if A.Allowed() and fn then fn(self,button) end end)
 b:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3'));self.icon:SetVertexColor(U.Color('ink'));if tip then U.Tooltip(self,type(tip)=='function' and tip() or tip) end end)
 b:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('panel-2'));self.icon:SetVertexColor(U.Color('ink-2'));GameTooltip:Hide() end)
 return b
end
function U.RefreshLabels()
 for _,b in ipairs(U.localizedButtons or {}) do if b.localeKey then b:SetLabel(A.T(b.localeKey)) end end
end
function U.Rest(b)
 if b.quiet then b:SetBackdropColor(U.ColorA('panel-2',0));b:SetBackdropBorderColor(U.ColorA('line',0));if b.text then b.text:SetTextColor(U.Color('ink-2')) end
 else b:SetBackdropColor(U.Color('panel-2'));b:SetBackdropBorderColor(U.Color('line')) end
end
function U.Active(b,active)
 b.active=active
 if active then b:SetBackdropColor(U.Color('ink'));b:SetBackdropBorderColor(U.Color('ink'));b.text:SetTextColor(U.Color('ground'))
 else U.Rest(b);if not b.quiet then b.text:SetTextColor(U.Color('ink')) end end
end
function U.FlowWrap(buttons,x0,y,gap,maxX,rowH)
 gap=gap or 6;local x=x0;local rowStart=true
 for _,b in ipairs(buttons) do
  if b==false then if not rowStart then x=x+gap*2 end
  elseif b.IsShown and not b:IsShown() then
  else
   local w=b:GetWidth()
   if not rowStart and x+w>maxX then x=x0;y=y-rowH;rowStart=true end
   b:ClearAllPoints();b:SetPoint('TOPLEFT',b:GetParent(),'TOPLEFT',x,y);x=x+w+gap;rowStart=false
  end
 end
 return y-rowH
end
function U.Flow(buttons,x,y,gap)
 for _,b in ipairs(buttons) do
  if b==false then x=x+(gap or 6)*2 elseif b.IsShown and not b:IsShown() then else b:ClearAllPoints();b:SetPoint('TOPLEFT',b:GetParent(),'TOPLEFT',x,y);x=x+b:GetWidth()+(gap or 6) end
 end
 return x
end
local POOL_SCRIPTS={'OnClick','OnDoubleClick','OnMouseDown','OnMouseUp','OnEnter','OnLeave','OnDragStart','OnDragStop'}
function U.Pool(parent)
 local pool={free={},used={}}
 function pool:release()
  for i=#self.used,1,-1 do local b=self.used[i];b:Hide();b:SetScript('OnUpdate',nil);b.data=nil;self.free[#self.free+1]=b end
  self.used={}
 end
 function pool:get()
  local b=table.remove(self.free)
  if not b then
   b=CreateFrame('Button',nil,parent);U.Surface(b,'panel','line',4)
   b.text=U.Text(b);U.Font(b.text,12);U.Line(b.text)
   b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(18,18);b.icon:SetTexCoord(0.08,0.92,0.08,0.92)
   U.Hatch(b,'ink',0);b.dpHatch:Hide()
  end
  b:ClearAllPoints();b.text:ClearAllPoints();b.text:SetPoint('LEFT',6,0);b.text:SetText('');b.text:SetTextColor(U.Color('ink'));b.text:SetWidth(0);b.text:SetJustifyH('LEFT')
  U.Font(b.text,12)
  b.icon:Hide();b.icon:ClearAllPoints();b.icon:SetPoint('LEFT',2,0);b.icon:SetSize(18,18);b.icon:SetDesaturated(false);b.icon:SetTexCoord(0.08,0.92,0.08,0.92);b.icon:SetVertexColor(1,1,1,1)
  b.box=nil;b.row=nil;b.text:Show()
  for i=1,#POOL_SCRIPTS do b:SetScript(POOL_SCRIPTS[i],nil) end
  b.castTime=nil;b.player=nil;b.seat=nil;b.bench=nil;b.zone=nil;b.dpList=nil;b.dpTo=nil;if b.ilvl then b.ilvl:Hide() end;if b.count then b.count:Hide() end
  b:EnableMouse(true);b:RegisterForClicks('LeftButtonUp','RightButtonUp');b:RegisterForDrag('LeftButton');b:SetAlpha(1);b:SetFrameLevel(parent:GetFrameLevel()+2)
  b.dpBg:Show();b.dpRing:Show();U.Radius(b,4);b:SetBackdropColor(U.Color('panel'));b:SetBackdropBorderColor(U.Color('line'));if b.dpHatch then b.dpHatch:Hide() end
  b:Show();self.used[#self.used+1]=b;return b
 end
 return pool
end
local QUESTION='Interface\\Icons\\INV_Misc_QuestionMark'
function U.Icon(id)
 if not id then return QUESTION end
 local ok,texture=pcall(C_Spell.GetSpellTexture,id)
 if ok and A.Public(texture) and texture then return texture end
 return QUESTION
end
function U.SpecIcon(id,classToken)
 if id then local ok,_,_,_,icon=pcall(GetSpecializationInfoByID,id);if ok and A.Public(icon) and icon then return icon end end
 if classToken then return 'Interface\\Icons\\ClassIcon_'..classToken end
 return QUESTION
end
function U.Time(t)
 local s=math.floor(math.abs(t)+0.5);return (t<0 and '-' or '')..string.format('%d:%02d',math.floor(s/60),s%60)
end
function U.TimeFine(t)
 local a=math.abs(t);return (t<0 and '-' or '')..string.format('%d:%04.1f',math.floor(a/60),a%60)
end
function U.Tooltip(b,text)
 GameTooltip:SetOwner(b,'ANCHOR_RIGHT');GameTooltip:SetText(text);GameTooltip:Show()
end
function U.EffectLine(spellId)
 local e=A.Effects and A.Effects[spellId];if not e then return nil end
 local s=A.T('addon.fx.'..e.k,{p=e.p or ''})
 if e.scope then s=s..', '..A.T('addon.scope.'..e.scope) end
 if e.note and A.locale=='en' then s=s..' ('..e.note..')' end
 return s
end
function U.SpellFacts(spellId)
 local sp=A.CD and A.CD[spellId];if not sp then return nil end
 local parts={}
 local function dur(t) return t>=60 and A.T('tt.min',{n=math.floor(t/60*10+0.5)/10}) or (t..' s') end
 if (sp.cooldown or 0)>0 then parts[#parts+1]=A.T('tt.cd',{t=dur(sp.cooldown)})..(sp.charges and sp.charges>1 and ' x'..sp.charges or '') end
 if (sp.duration or 0)>0 then parts[#parts+1]=A.T('tt.dur',{t=dur(sp.duration)}) end
 return #parts>0 and table.concat(parts,', ') or nil
end
function U.SpellTip(b,spellId,head,hint)
 GameTooltip:SetOwner(b,'ANCHOR_RIGHT')
 local ok=spellId and GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID,GameTooltip,spellId)
 if not ok then
  local tip=spellId and A.Tooltips and A.Tooltips[spellId]
  GameTooltip:SetText(head or (A.CD and A.CD[spellId] and A.CD[spellId].name) or ('Spell '..tostring(spellId)))
  if tip then local d=(A.locale=='pt-BR' and tip.pt and tip.pt.d) or tip.d;if d and d~='' and GameTooltip.AddLine then GameTooltip:AddLine(d,1,1,1,true) end end
 elseif head then GameTooltip:AddLine(head,1,0.69,0.23) end
 local facts,fx=U.SpellFacts(spellId),U.EffectLine(spellId)
 if facts and GameTooltip.AddLine then GameTooltip:AddLine(facts,0.85,0.8,0.86) end
 if fx and GameTooltip.AddLine then GameTooltip:AddLine(fx,0.35,0.77,0.54) end
 if hint and GameTooltip.AddLine then GameTooltip:AddLine(hint,0.54,0.5,0.55) end
 GameTooltip:Show()
end
function U.Eye(b)
 local ok=C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo('socialqueuing-icon-eye')
 if ok then b.icon:SetAtlas('socialqueuing-icon-eye',false);b.icon:SetTexCoord(0,1,0,1) else b.icon:SetTexture('Interface\AddOns\DynamicPlanner\Media\Textures\ring6');b.icon:SetTexCoord(0,1,0,1) end
 b.icon:ClearAllPoints();b.icon:SetPoint('CENTER');b.icon:SetSize(14,ok and 14 or 10);b.icon:SetVertexColor(U.Color('ink-3'));b.icon:Show()
end
function U.Menu(parent,items)
 if MenuUtil and MenuUtil.CreateContextMenu then
  MenuUtil.CreateContextMenu(parent,function(_,root)
   if #items>18 and root.SetScrollMode then root:SetScrollMode(18*22) end
   for _,it in ipairs(items) do
    local run=function() if A.Allowed() and it[2] then it[2]() end end
    if it.title then root:CreateTitle(it[1])
    elseif it.divider then root:CreateDivider()
    elseif it.multi then root:CreateCheckbox(it[1],it.isChecked or function() return it.checked end,run)
    elseif it.checked~=nil then root:CreateRadio(it[1],function() return it.checked end,run)
    else root:CreateButton(it[1],run) end
   end
  end)
  return
 end
 local f=U.menu
 if not f then f=CreateFrame('Frame',nil,U.window);U.Surface(f,'panel','border');f:SetFrameStrata('DIALOG');f:EnableMouse(true);f.pool=U.Pool(f);U.menu=f
  f:SetScript('OnShow',function(self) self:RegisterEvent('GLOBAL_MOUSE_DOWN') end)
  f:SetScript('OnHide',function(self) self:UnregisterEvent('GLOBAL_MOUSE_DOWN');self.anchor=nil end)
  f:SetScript('OnEvent',function(self) if not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then self:Hide() end end)
  f:EnableKeyboard(true);U.Propagate(f,true)
  f:SetScript('OnKeyDown',function(self,key) if key=='ESCAPE' then U.Propagate(self,false);self:Hide() else U.Propagate(self,true) end end)
 end
 if f:IsShown() and f.anchor==parent then f:Hide();return end
 f.anchor=parent
 f:ClearAllPoints();f:SetSize(280,math.min(#items,16)*28+8);f:SetPoint('TOPLEFT',parent,'BOTTOMLEFT',0,-4);f:Show()
 local offset=0;local pool=f.pool
 local function draw()
  pool:release()
  for i=offset+1,math.min(#items,offset+16) do
   local item=items[i];if item.divider then item={'-',function() end} end;local b=pool:get();b:SetPoint('TOPLEFT',4,-4-(i-offset-1)*28);b:SetSize(272,26);b.text:SetWidth(258);b.text:SetText(item[1]);b:SetBackdropColor(U.Color('panel'));b:SetBackdropBorderColor(0,0,0,0)
   b:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3')) end);b:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('panel')) end)
   b:SetScript('OnClick',function() if A.Allowed() and item[2] and not item.title then f:Hide();item[2]() end end)
  end
 end
 f:EnableMouseWheel(true);f:SetScript('OnMouseWheel',function(_,delta) offset=math.max(0,math.min(math.max(0,#items-16),offset-delta*3));draw() end)
 draw();U.menu=f
end
