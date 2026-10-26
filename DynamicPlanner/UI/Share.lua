local _, A = ...
local U=A.UI
local S={};A.Share=S
S.PREFIX='DynPlan';S.CHUNK=230;S.MAX_PARTS=400;S.VERSION=1
local queue,sending,incoming={}, nil,{}
S.pending=nil
local function short(name) return name and (name:match('^([^%-]+)') or name) or '' end
local function escape(s) return (s:gsub('\\','\\\\'):gsub('\n','\\n'):gsub('|','\\p')) end
local function unescape(s) return (s:gsub('\\(.)',function(c) if c=='n' then return '\n' elseif c=='p' then return '|' else return c end end)) end
S.escape,S.unescape=escape,unescape
function S.InGroup() return (IsInRaid and IsInRaid()) or (IsInGroup and IsInGroup()) or false end
local function lead(unit) return (UnitIsGroupLeader and UnitIsGroupLeader(unit)) or (UnitIsGroupAssistant and UnitIsGroupAssistant(unit)) or false end
local function chatRestricted()
 if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then local ok,v=pcall(C_ChatInfo.InChatMessagingLockdown);if ok and v then return true end end
 local R=C_RestrictedActions
 if R and R.IsAddOnRestrictionActive then
  local kind=Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Chat
  if kind~=nil then local ok,v=pcall(R.IsAddOnRestrictionActive,kind);if ok and v then return true end end
 end
 return false
end
S.ChatRestricted=chatRestricted
local function busy() return InCombatLockdown() or (IsEncounterInProgress and IsEncounterInProgress()) or chatRestricted() end
function S.RosterLine(plan)
 local out={}
 for _,p in ipairs(plan.roster or {}) do
  if not p.name:find('[,;]') then out[#out+1]=table.concat({p.name,tostring(p.classId or ''),tostring(p.specId or ''),p.active and '1' or '0',tostring(p.group or ''),tostring(p.slot or '')},',') end
 end
 return table.concat(out,';')
end
function S.ParseRoster(line)
 local out={}
 for item in (line or ''):gmatch('[^;]+') do
  local name,c,s,a,g,sl=item:match('^([^,]+),(%d*),(%d*),([01]),(%d*),(%d*)$')
  if name and #out<60 then
   local r={name=name,classId=tonumber(c),specId=tonumber(s),active=a=='1',group=tonumber(g),slot=tonumber(sl)}
   local spec=r.specId and A.SpecByID[r.specId];if spec then r.classToken=spec.classToken;r.role=spec.role end
   out[#out+1]=r
  end
 end
 return out
end
function S.Payload(plan)
 local ok,text=pcall(A.NSRT.serialize,plan);if not ok then return nil,text end
 return text..'\n#dp-roster:'..S.RosterLine(plan)
end
function S.Messages(payload,bossId,planName)
 local body=escape(payload);local parts={}
 for i=1,#body,S.CHUNK do parts[#parts+1]=body:sub(i,i+S.CHUNK-1) end
 local id=tostring(math.random(100000,999999))
 local msgs={'H|'..id..'|'..bossId..'|'..#parts..'|'..S.VERSION..'|'..escape(planName):gsub('|','')}
 for i,p in ipairs(parts) do msgs[#msgs+1]='D|'..id..'|'..i..'|'..p end
 return msgs,#parts
end
S.BURST=10;S.BURST_GAP=0.3;S.GAP=1.0;S.BACKOFF_MAX=16
local function sendOne(msg)
 local channel=(IsInRaid and IsInRaid()) and 'RAID' or 'PARTY'
 local ok,res=pcall(C_ChatInfo.SendAddonMessage,S.PREFIX,msg,channel)
 if not ok then return 'fail' end
 local E=Enum and Enum.SendAddonMessageResult
 if res==nil or res==true or (E and res==E.Success) or (not E and res==0) then return 'ok' end
 if E and (res==E.AddonMessageThrottle or res==E.ChannelThrottle) then return 'throttle' end
 return 'fail'
end
S.SendOne=sendOne
local ticker=CreateFrame('Frame');ticker:Hide();local wait,sentCount,backoff=0,0,0
local function step(self,elapsed)
 wait=wait-(elapsed or 0.3);if wait>0 then return end
 if busy() then wait=2;return end
 local msg=queue[1]
 if not msg then self:SetScript('OnUpdate',nil);self:Hide();if sending then A.Message(A.T('addon.shareDone',{plan=sending}));sending=nil end;return end
 local r=sendOne(msg)
 if r=='ok' then table.remove(queue,1);sentCount=sentCount+1;backoff=0;wait=sentCount<S.BURST and S.BURST_GAP or S.GAP
 elseif r=='throttle' then backoff=math.min(S.BACKOFF_MAX,backoff>0 and backoff*2 or 2);wait=backoff
 else wait=2 end
end
function S.ResetPacing() wait,sentCount,backoff=0,0,0 end
function S.Wait() return wait end
ticker.step=step
S.ticker=ticker
function S.Send()
 if not A.Allowed() or busy() then A.Message(A.T('addon.shareBusy'));return false end
 if not S.InGroup() then A.Message(A.T('addon.shareNoGroup'));return false end
 if not lead('player') then A.Message(A.T('addon.shareNotLead'));return false end
 if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
 local payload,err=S.Payload(A.model.plan);if not payload then A.Message(tostring(err));return false end
 local msgs,n=S.Messages(payload,A.boss.id,A.PlanName())
 if n>S.MAX_PARTS-1 then A.Message(A.T('addon.shareTooBig'));return false end
 for _,m in ipairs(msgs) do queue[#queue+1]=m end
 sending=A.PlanName();wait,sentCount,backoff=0,0,0;ticker:SetScript('OnUpdate',step);ticker:Show()
 local burst=math.min(#msgs,S.BURST)
 A.Message(A.T('addon.shareSent',{plan=sending,n=n,s=math.ceil(burst*S.BURST_GAP+(#msgs-burst)*S.GAP)}))
 return true
end
local function me()
 local n=UnitName and UnitName('player');return n
end
function S.OnMessage(prefix,text,channel,sender)
 if prefix~=S.PREFIX or type(text)~='string' or not A.Public(text) or not A.Public(sender) then return end
 if channel~='RAID' and channel~='PARTY' then return end
 local who=short(sender);if who==me() then return end
 if not (lead(sender) or lead(who)) then return end
 local kind,id,a,b,c,d=text:match('^(%u)|(%d+)|([^|]*)|([^|]*)|?([^|]*)|?(.*)$')
 if kind=='H' then
  local parts=tonumber(b);if not parts or parts<1 or parts>S.MAX_PARTS or not A.Bosses[tonumber(a)] then return end
  incoming[sender]={id=id,boss=tonumber(a),parts=parts,got={},n=0,name=unescape(d or ''),from=who}
 elseif kind=='D' then
  local cur=incoming[sender];if not cur or cur.id~=id then return end
  local i=tonumber(a);if not i or i<1 or i>cur.parts or cur.got[i] then return end
  local chunk=text:match('^D|%d+|%d+|(.*)$')
  cur.got[i]=chunk;cur.n=cur.n+1
  if cur.n==cur.parts then incoming[sender]=nil;S.Complete(cur) end
 end
end
function S.Complete(cur)
 local body=unescape(table.concat(cur.got))
 local note,roster=body:match('^(.*)\n#dp%-roster:(.*)$')
 if not note then return end
 local p=A.NSRT.parse(note);if not p or p.encounterId~=cur.boss then return end
 local plan={encounterId=p.encounterId,name=p.name or A.Bosses[cur.boss].name,difficulty=p.difficulty,lines=p.lines,roster=S.ParseRoster(roster),kickBlocks=p.kickBlocks,notes=p.notes}
 S.pending={from=cur.from,boss=cur.boss,planName=cur.name~='' and cur.name or A.T('pl.default'),plan=plan,casts=#p.lines,players=#plan.roster}
 A.Message(A.T('addon.shareGot',{name=cur.from,plan=S.pending.planName,boss=A.Bosses[cur.boss].name}))
 if U.window and U.window:IsShown() then U.ShareOffer() end
end
function S.Accept()
 local pend=S.pending;if not pend or not A.Allowed() then return false end
 S.pending=nil
 if A.boss.id~=pend.boss then A.SelectBoss(pend.boss) end
 local name=A.UniquePlanName(A.T('addon.shareFrom',{name=pend.from})..': '..pend.planName)
 A.Save();local b=A.db.bosses[A.boss.id];b.saved=b.saved or {};b.saved[name]=pend.plan
 A.OpenPlan(name);A.Message(A.T('addon.shareSaved',{plan=name}));if U.shareOffer then U.shareOffer:Hide() end
 return true
end
function S.Dismiss() S.pending=nil;if U.shareOffer then U.shareOffer:Hide() end end
function U.ShareOffer()
 local pend=S.pending;if not pend or not U.window then return end
 local f=U.shareOffer
 if not f then
  f=CreateFrame('Frame',nil,U.window);U.Surface(f,'panel','border',10);f:SetSize(440,150);f:SetPoint('TOP',0,-70);f:SetFrameStrata('DIALOG');f:EnableMouse(true)
  f.title=U.Label(f,'',16,-16,14,'textMedium')
  f.body=U.Label(f,'',16,-44,12);f.body:SetWidth(408);f.body:SetWordWrap(true);f.body:SetTextColor(U.Color('ink-2'))
  f.save=U.Button(f,'',0,0,0,function() S.Accept() end,{key='addon.shareSave'});f.save:ClearAllPoints();f.save:SetPoint('BOTTOMRIGHT',-16,16)
  f.dismiss=U.Button(f,'',0,0,0,function() S.Dismiss() end,{key='addon.shareDismiss',always=true});f.dismiss:ClearAllPoints();f.dismiss:SetPoint('RIGHT',f.save,'LEFT',-8,0)
  U.shareOffer=f
 end
 f.title:SetText(A.T('addon.shareTitle',{name=pend.from}))
 f.body:SetText(A.T('addon.shareBody',{plan=pend.planName,boss=A.Bosses[pend.boss].name,n=pend.casts,p=pend.players}))
 f.save:SetLabel(A.T('addon.shareSave'));f.dismiss:SetLabel(A.T('addon.shareDismiss'))
 f.save:ClearAllPoints();f.save:SetPoint('BOTTOMRIGHT',-16,16);f.dismiss:ClearAllPoints();f.dismiss:SetPoint('RIGHT',f.save,'LEFT',-8,0)
 f:Show()
end
local events=CreateFrame('Frame')
events:RegisterEvent('CHAT_MSG_ADDON');events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent',function(_,event,...)
 if event=='PLAYER_LOGIN' then if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(S.PREFIX) end
 else S.OnMessage(...) end
end)
S.events=events
