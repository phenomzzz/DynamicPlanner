local _, A = ...
local U=A.UI
local W,PAD=360,14
local IN=W-2*PAD
local C_TIME,C_ICON,C_NAME,C_AMT,C_BAR,C_PCT=40,46,66,232,240,IN
local card
local function texts()
 local pool={free={},used={}}
 function pool:get(size,kind,ink)
  local t=table.remove(self.free) or card:CreateFontString(nil,'OVERLAY','GameFontHighlight')
  U.Font(t,size or 12,kind);t:SetTextColor(U.Color(ink or 'ink'));t:ClearAllPoints();t:SetWidth(0);t:SetJustifyH('LEFT')
  if t.SetWordWrap then t:SetWordWrap(false) end;t:Show();self.used[#self.used+1]=t;return t
 end
 function pool:release() for i=#self.used,1,-1 do local t=self.used[i];t:Hide();t:SetText('');self.free[#self.free+1]=t end;self.used={} end
 return pool
end
local function textures()
 local pool={free={},used={}}
 function pool:get(layer)
  local t=table.remove(self.free) or card:CreateTexture(nil,'ARTWORK')
  t:ClearAllPoints();t:SetTexCoord(0,1,0,1);t:SetVertexColor(1,1,1,1);t:SetAlpha(1);t:SetDrawLayer(layer or 'ARTWORK');t:Show();self.used[#self.used+1]=t;return t
 end
 function pool:release() for i=#self.used,1,-1 do local t=self.used[i];t:Hide();self.free[#self.free+1]=t end;self.used={} end
 return pool
end
local function build()
 card=CreateFrame('Frame',nil,UIParent);card:SetFrameStrata('TOOLTIP');card:SetWidth(W);card:SetHeight(40);card:EnableMouse(false)
 if card.SetClampedToScreen then card:SetClampedToScreen(true) end
 U.Surface(card,'ground-2','line',6);card:Hide()
 card.text=texts();card.tex=textures();card.y=0
 U.anaCard=card
end
local function at(r,x,y) r:SetPoint('TOPLEFT',card,'TOPLEFT',PAD+x,-(PAD+y)) end
local function right(t,xRight,y,w) t:SetWidth(w);t:SetJustifyH('RIGHT');at(t,xRight-w,y) end
local function icon(id,x,y,size)
 local t=card.tex:get('ARTWORK');t:SetTexture(U.Icon(id));t:SetTexCoord(0.08,0.92,0.08,0.92);t:SetSize(size,size);at(t,x,y);return t
end
local function fill(color,alpha,x,y,w,h,layer)
 local t=card.tex:get(layer or 'BORDER');t:SetColorTexture(U.ColorA(color,alpha or 1));t:SetSize(math.max(1,w),math.max(1,h));at(t,x,y);return t
end
local B={}
function B.Begin()
 if not card then build() end
 card.text:release();card.tex:release();card.y=0;card.rows=0;return B
end
function B.Header(title,rgb,suffix,value,valueInk)
 local t=card.text:get(14,'textMedium');t:SetText(title or '');at(t,0,card.y)
 if rgb then t:SetTextColor(rgb[1],rgb[2],rgb[3]) end
 local tw=math.min(t:GetUnboundedStringWidth() or 0,IN-90);t:SetWidth(tw+2)
 if suffix and suffix~='' then local s=card.text:get(11,nil,'ink-3');s:SetText(suffix);at(s,tw+8,card.y+3) end
 if value then local v=card.text:get(13,'mono',valueInk or 'ink-2');v:SetText(value);right(v,IN,card.y+1,90) end
 card.y=card.y+22
end
function B.Sub(s,ink) if not s or s=='' then return end;local t=card.text:get(11,nil,ink or 'ink-3');t:SetText(s);t:SetWidth(IN);at(t,0,card.y);card.y=card.y+16 end
function B.Lead(id,name,value,detail,valueInk)
 card.y=card.y+4
 if id then icon(id,0,card.y,20) end
 local n=card.text:get(13,'textMedium');n:SetText(name or '');n:SetWidth(IN-28-96);at(n,28,card.y+2)
 if value then local v=card.text:get(13,'mono',valueInk or 'ink');v:SetText(value);right(v,IN,card.y+2,96) end
 if detail and detail~='' then local d=card.text:get(11,nil,'ink-3');d:SetText(detail);d:SetWidth(IN-28);at(d,28,card.y+20) ;card.y=card.y+38 else card.y=card.y+26 end
end
function B.Section(label,rightLabel)
 card.y=card.y+10
 local r=fill('line',1,0,card.y,IN,1,'BORDER');U.Crisp(r)
 card.y=card.y+8
 local t=card.text:get(11,nil,'ink-3');t:SetText(label);t:SetWidth(IN-110);at(t,0,card.y)
 if rightLabel then local s=card.text:get(10,nil,'ink-3');s:SetText(rightLabel);right(s,IN,card.y+1,110) end
 card.y=card.y+18
end
function B.Row(r)
 local h=r.sub and 30 or 20
 if r.hl then fill('tl-death',0.16,-6,card.y-3,IN+12,h+2,'BACKGROUND') end
 if r.time then local t=card.text:get(11,'mono','ink-3');t:SetText(r.time);right(t,C_TIME,card.y+2,C_TIME) end
 local x0=r.time and C_ICON or 0
 if r.id then icon(r.id,x0,card.y+1,16) end
 local nx=r.id and (x0+20) or x0
 local nameW=(r.hp or r.pctText) and (C_AMT-56-nx) or (IN-62-nx)
 local n=card.text:get(12,r.nameKind,r.nameInk);n:SetText((r.name or '')..(r.count and r.count>1 and ('  x'..r.count) or ''));n:SetWidth(nameW);at(n,nx,card.y+2)
 if r.rgb then n:SetTextColor(r.rgb[1],r.rgb[2],r.rgb[3]) end
 if r.sub then local s=card.text:get(10,nil,'ink-3');s:SetText(r.sub);s:SetWidth(IN-nx);at(s,nx,card.y+17) end
 local amtRight=(r.hp or r.pctText) and C_AMT or IN
 if r.amt then local a=card.text:get(12,'mono',r.amtInk or (r.hl and 'tl-death' or 'ink'));a:SetText(r.amt);right(a,amtRight,card.y+2,56) end
 if r.hp then
  fill('ink',0.10,C_BAR,card.y+8,40,4)
  fill(r.hp<0.35 and 'tl-death' or (r.hp<0.7 and 'major' or 'heal'),0.9,C_BAR,card.y+8,math.max(1,40*math.min(1,r.hp)),4,'ARTWORK')
  local p=card.text:get(10,'mono','ink-3');p:SetText(string.format('%d%%',math.floor(r.hp*100+0.5)));right(p,C_PCT,card.y+3,34)
 elseif r.pctText then local p=card.text:get(10,'mono','ink-3');p:SetText(r.pctText);right(p,C_PCT,card.y+3,40) end
 if r.bar then fill('ink',0.07,nx,card.y+16,math.max(1,(amtRight-56-nx)*math.min(1,r.bar)),2,'BORDER') end
 card.y=card.y+h+2;card.rows=card.rows+1
end
function B.Item(id,name,who,value,ink)
 if id then icon(id,0,card.y+1,16) end
 local n=card.text:get(12,nil,ink);n:SetText(name or '');local nw=math.min(n:GetUnboundedStringWidth() or 0,IN-130);n:SetWidth(nw+2);at(n,20,card.y+2)
 if who and who~='' then local w=card.text:get(11,nil,'ink-3');w:SetText(who);w:SetWidth(IN-60-nw-28);at(w,20+nw+8,card.y+3) end
 if value then local v=card.text:get(11,'mono','ink-2');v:SetText(value);right(v,IN,card.y+3,56) end
 card.y=card.y+20
end
function B.KV(label,value,valueInk,delta,deltaInk)
 local l=card.text:get(12,nil,'ink-2');l:SetText(label);l:SetWidth(IN-150);at(l,0,card.y+1)
 local v=card.text:get(13,'mono',valueInk or 'ink');v:SetText(value or '');right(v,delta and IN-64 or IN,card.y,90)
 if delta then local d=card.text:get(11,'mono',deltaInk or 'ink-3');d:SetText(delta);right(d,IN,card.y+2,60) end
 card.y=card.y+20
end
function B.Note(s,ink,size)
 if not s or s=='' then return end
 local t=card.text:get(size or 11,nil,ink or 'ink-3');if t.SetWordWrap then t:SetWordWrap(true) end;t:SetWidth(IN);t:SetText(s);at(t,0,card.y+1)
 local h=t.GetStringHeight and t:GetStringHeight() or 14;if not h or h<=0 then h=14 end
 card.y=card.y+math.ceil(h)+4
end
local HIDE_GRACE,FADE=0.06,0.12
local function tick(self,elapsed)
 local now=GetTime()
 if self.hideAt and now>=self.hideAt then self.hideAt=nil;self.owner=nil;self.hiddenAt=now;self:Hide();self:SetScript('OnUpdate',nil);return end
 if self.fade then self.fade=self.fade+elapsed;local a=math.min(1,self.fade/FADE);self:SetAlpha(a);if a>=1 then self.fade=nil end end
 if not self.fade and not self.hideAt then self:SetScript('OnUpdate',nil) end
end
local function place(owner)
 local s=card:GetEffectiveScale();local os=owner:GetEffectiveScale()/s
 local l,r,t=(owner:GetLeft() or 0)*os,(owner:GetRight() or 0)*os,(owner:GetTop() or 0)*os
 local sw,sh=UIParent:GetWidth() or 1920,UIParent:GetHeight() or 1080;if sw<=0 then sw=1920 end;if sh<=0 then sh=1080 end
 local h=card:GetHeight()
 local x
 if r-l>240 then local cx=GetCursorPosition()/s;x=cx+20;if x+W>sw-8 then x=cx-20-W end
 else x=r+8;if x+W>sw-8 then x=l-8-W end end
 x=math.max(8,math.min(sw-8-W,x))
 local y=math.min(sh-8,math.max(h+8,t+4))
 card:ClearAllPoints();card:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',math.floor(x+0.5),math.floor(y+0.5))
 card.placed={x=x,y=y}
end
function B.Show(owner)
 card:SetHeight(math.ceil(card.y+2*PAD-4))
 place(owner)
 local now=GetTime()
 local quick=card:IsShown() or (card.hiddenAt and now-card.hiddenAt<0.25)
 card.owner=owner;card.hideAt=nil
 if quick then card.fade=nil;card:SetAlpha(1) else card.fade=0;card:SetAlpha(0) end
 card:Show()
 if card.fade then card:SetScript('OnUpdate',tick) elseif not card.hideAt then card:SetScript('OnUpdate',nil) end
end
function U.CardHide(owner)
 if not card or not card:IsShown() then return end
 if owner and card.owner~=owner then return end
 card.hideAt=GetTime()+HIDE_GRACE;card:SetScript('OnUpdate',tick)
end
function U.CardHideNow() if card then card.hideAt=nil;card.fade=nil;card.owner=nil;card:SetScript('OnUpdate',nil);card:Hide() end end
function U.Card() return B.Begin() end
U.CARD_W=W
