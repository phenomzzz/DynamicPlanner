local _, A = ...
local U=A.UI
local M=A.Model
local W,PAD=760,18
local function classHex(p) local r,g,b=U.Color(p and p.classToken and 'class-'..p.classToken or 'ink-2');return string.format('|cff%02x%02x%02x',r*255,g*255,b*255) end
local function build()
 local f=CreateFrame('Frame',nil,U.window);U.Surface(f,'panel','border',10);f:SetSize(W,600);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:EnableMouse(true);f:SetToplevel(true)
 f.title=U.Label(f,'',PAD,-PAD,18,'display');f.summary=U.Label(f,'',PAD,-PAD-30,12);f.summary:SetWidth(W-PAD*2);f.summary:SetWordWrap(true)
 f.body=CreateFrame('Frame',nil,f);f.body:SetPoint('TOPLEFT',PAD,-PAD-74);f.body:SetPoint('BOTTOMRIGHT',-PAD,PAD+44);f.body:SetClipsChildren(true)
 f.pool=U.Pool(f.body);f.offset=0
 f:EnableMouseWheel(true);f:SetScript('OnMouseWheel',function(_,d) f.offset=math.max(0,f.offset-d*48);U.DrawImport() end)
 f.back=U.Button(f,'',0,0,0,function() f:Hide();U.Note(f.raw or '',false) end,{key='imp.back'});f.back:ClearAllPoints();f.back:SetPoint('BOTTOMLEFT',PAD,PAD)
 f.replace=U.Button(f,'',0,0,0,function() f:Hide();A.ApplyImport(f.p,'replace',f.map) end,{key='imp.replace'});f.replace:ClearAllPoints();f.replace:SetPoint('BOTTOMRIGHT',-PAD,PAD)
 f.keep=U.Button(f,'',0,0,0,function() f:Hide();A.ApplyImport(f.p,'keep',f.map) end,{key='imp.merge'});f.keep:ClearAllPoints();f.keep:SetPoint('RIGHT',f.replace,'LEFT',-6,0)
 f:EnableKeyboard(true);U.Propagate(f,true)
 f:SetScript('OnKeyDown',function(self,key) if key=='ESCAPE' then U.Propagate(self,false);self:Hide() else U.Propagate(self,true) end end)
 U.importer=f;return f
end
function U.ImportReview(p,raw)
 if not A.Allowed() then return end
 local f=U.importer or build()
 f.p=p;f.raw=raw or (U.note and U.note.edit:GetText());f.map={};f.offset=0
 for _,a in ipairs(p.lines) do if not U.RaidTag(a.tag) and not a.tag:find('%s') and f.map[a.tag]==nil then
  local r=A.MatchTag(a.tag,A.model.plan.roster);f.map[a.tag]=r and r.name or '+'
 end end
 f:Show();U.RefreshLabels();U.DrawImport()
end
function U.DrawImport()
 local f=U.importer;if not f or not f:IsShown() then return end
 local p=f.p;local pool=f.pool;pool:release()
 local boss=A.Bosses[p.encounterId]
 f.title:SetText(A.T('imp.forRaid'))
 local names,wide,counts={},{},{}
 for _,a in ipairs(p.lines) do counts[a.tag]=(counts[a.tag] or 0)+1;if U.RaidTag(a.tag) or a.tag:find('%s') then if not wide[a.tag] then wide[a.tag]=true;wide[#wide+1]=a.tag end elseif not names[a.tag] then names[a.tag]=true;names[#names+1]=a.tag end end
 local rot=0;if p.kickBlocks and p.kickBlocks[1] then rot=#p.kickBlocks[1]-2 end
 f.summary:SetText('|cffffb13b'..(boss and boss.name or p.name or '')..'|r, '..(p.difficulty or 'Mythic')..': '..A.T('addon.impSummary',{n=#p.lines,pl=#names,wide=#wide,rot=rot,bad=#p.rejected,txt=#(p.notes or {})})..(p.headerless and '\n|cff8a7f8d'..A.T('addon.noHeader',{boss=A.boss.name})..'|r' or ''))
 local y=-f.offset;local w=f.body:GetWidth()
 local function line(s,size,color,font,indent)
  local t=pool:get();t:SetPoint('TOPLEFT',indent or 0,-y);t:SetSize(w-(indent or 0),(size or 12)+6);t:SetBackdrop(nil);t:EnableMouse(false)
  t.text:ClearAllPoints();t.text:SetPoint('LEFT',0,0);t.text:SetWidth(w-(indent or 0));U.Font(t.text,size or 12,font or 'text');t.text:SetTextColor(U.Color(color or 'ink'));t.text:SetText(s);y=y+(size or 12)+10;return t
 end
 local roster=A.model.plan.roster
 local out,odd,exact={}, {}, {}
 for _,n in ipairs(names) do local r,how=A.MatchTag(n,roster);if not r or not r.active then out[#out+1]=n elseif how~='exact' then odd[#odd+1]=n else exact[#exact+1]=n end end
 local function mapRow(n)
  local r,how=A.MatchTag(n,roster);local to=f.map[n]
  local t=pool:get();t:SetPoint('TOPLEFT',0,-y);t:SetSize(w,26);t:SetBackdrop(nil);t:EnableMouse(false)
  t.text:ClearAllPoints();t.text:SetPoint('LEFT',8,0);t.text:SetWidth(300);U.Font(t.text,12,'mono');t.text:SetText(n..'  |cff8a7f8d'..A.T('addon.linesN',{n=counts[n]})..(how=='nick' and ', '..A.T('imp.nickKnown') or how=='first' and ', '..A.T('imp.nickGuess') or '')..'|r')
  local cur=to=='' and A.T('imp.drop') or to=='+' and A.T('addon.newBench') or (function() local q;for _,x in ipairs(roster) do if x.name==to then q=x end end;return classHex(q)..to..'|r' end)()
  local b=pool:get();b:SetPoint('TOPLEFT',320,-y);b:SetSize(w-320,26);U.Radius(b,4);b:SetBackdropColor(U.Color('panel-2'));b:SetBackdropBorderColor(U.Color('line'))
  b.text:ClearAllPoints();b.text:SetPoint('LEFT',10,0);U.Font(b.text,12,'textMedium');b.text:SetText(cur)
  b.icon:SetTexture(U.ChevronTexture);b.icon:SetTexCoord(0,1,0,1);b.icon:SetSize(10,10);b.icon:ClearAllPoints();b.icon:SetPoint('RIGHT',-10,0);b.icon:SetVertexColor(U.Color('ink'));b.icon:Show()
  b:SetScript('OnClick',function(self)
   local items={{A.T('addon.newBench'),function() f.map[n]='+';U.DrawImport() end,checked=to=='+'},{A.T('imp.drop'),function() f.map[n]='';U.DrawImport() end,checked=to==''},{'',nil,divider=true},{A.T('imp.grpRaid'),nil,title=true}}
   local bench={}
   for _,x in ipairs(roster) do if x.active then items[#items+1]={classHex(x)..x.name..'|r',function() f.map[n]=x.name;U.DrawImport() end,checked=to==x.name} else bench[#bench+1]=x end end
   if #bench>0 then items[#items+1]={A.T('imp.grpBench'),nil,title=true};for _,x in ipairs(bench) do items[#items+1]={classHex(x)..x.name..'|r',function() f.map[n]=x.name;U.DrawImport() end,checked=to==x.name} end end
   U.Menu(self,items)
  end)
  b:SetScript('OnEnter',function(self) self:SetBackdropColor(U.Color('ground-3')) end);b:SetScript('OnLeave',function(self) self:SetBackdropColor(U.Color('panel-2')) end)
  y=y+30
 end
 if #out>0 then line(A.T('addon.outH',{n=#out}),13,'warm-4','textMedium');line(A.T('imp.outHint'),11,'ink-3');for _,n in ipairs(out) do mapRow(n) end;y=y+8 end
 if #odd>0 then line(A.T('addon.oddH',{n=#odd}),13,'ink','textMedium');for _,n in ipairs(odd) do mapRow(n) end;y=y+8 end
 if #exact>0 then line(A.T('addon.exactN',{n=#exact}),12,'ink-2','textMedium');local s={};for _,n in ipairs(exact) do local r=A.MatchTag(n,roster);s[#s+1]=classHex(r)..n..'|r' end;local t=line(table.concat(s,'  '),12);t.text:SetWordWrap(true);y=y+8 end
 if #wide>0 then line(A.T('addon.wideH',{n=#wide}),13,'ink','textMedium');line(A.T('imp.wideHint'),11,'ink-3');local s={};for _,tg in ipairs(wide) do s[#s+1]=tg..' ('..counts[tg]..')' end;line(table.concat(s,',  '),12,'ink-2','mono');y=y+8 end
 if rot>0 then line(A.T('addon.kicksH',{n=rot}),13,'ink','textMedium');for i=2,#p.kickBlocks[1]-1 do line(A.T('kk.line',{n=i-1})..':  '..p.kickBlocks[1][i],12,'ink-2','mono',12) end;y=y+8 end
 if p.notes and #p.notes>0 then line(A.T('addon.notesH',{n=#p.notes}),13,'ink','textMedium');line(A.T('imp.notesHint'),11,'ink-3');for i=1,math.min(6,#p.notes) do line(p.notes[i],11,'ink-2','mono',12) end;y=y+8 end
 if #p.rejected>0 then
  line(A.T('addon.probH',{n=#p.rejected}),13,'tl-conflict','textMedium')
  for i=1,math.min(8,#p.rejected) do local r=p.rejected[i];line(A.T('imp.line',{n=r.line})..': '..A.T('imp.why.'..r.reason)..'  |cff8a7f8d'..(r.raw or ''):sub(1,80)..'|r',11,'ink-2',nil,12) end
  if #p.rejected>8 then line(A.T('addon.more',{n=#p.rejected-8}),11,'ink-3',nil,12) end
 end
 local any=#p.lines>0 or rot>0 or #(p.notes or {})>0
 f.keep:SetEnabled(any);f.replace:SetEnabled(any)
end
