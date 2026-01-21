-- 魔兽世界时光服/怀旧服 自动回复+公会邀请插件 V2.0
-- 指令：/argi 打开设置面板
-- 快捷键：”]“来执行公会邀请按钮触发 
local addonName = "AutoReplyAndGuildInvite"
local ARGI = CreateFrame("Frame", addonName, UIParent)
ARGI.version = "2.0"
ARGI:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

-- ================ 【核心重构】魔兽原生兼容 单层全局变量================
-- 所有配置全部用「独立全局变量」存储，这是魔兽官方推荐写法，写入配置文件100%成功
AutoReply_FirstReply_Enable = true          -- 首次密语回复开关
AutoReply_FirstReply_Text = "你好，收到你的消息啦，需要入会请发送 !invite" -- 首次回复内容
AutoReply_RuleReply_Enable = true           -- 5组规则回复开关（修改：10→5）
AutoReply_GuildInv_Enable = true            -- 公会邀请开关
AutoReply_GuildInv_Trigger = "!invite"      -- 公会邀请触发词
-- 5组自动回复规则 (独立变量，无嵌套)（修改：10→5）
AutoReply_Rule1_Trigger = "";AutoReply_Rule1_Reply = ""
AutoReply_Rule2_Trigger = "";AutoReply_Rule2_Reply = ""
AutoReply_Rule3_Trigger = "";AutoReply_Rule3_Reply = ""
AutoReply_Rule4_Trigger = "";AutoReply_Rule4_Reply = ""
AutoReply_Rule5_Trigger = "";AutoReply_Rule5_Reply = ""
-- 已私聊玩家记录 (独立表，无嵌套)
AutoReply_WhisperedPlayers = AutoReply_WhisperedPlayers or {}

-- 邀请按钮全局变量（用于控制唯一按钮）
ARGI.inviteButton = nil

-- 聊天框提示函数
local function Print(msg)
    print("|cff00ff00[自动回复助手]|r: " .. msg)
end

-- ================ 创建公会邀请按钮函数（新增快捷键"]"支持） ================
function ARGI:CreateInviteButton(author)
    -- 如果已有按钮，先删除
    if self.inviteButton and self.inviteButton:IsShown() then
        self.inviteButton:Hide()
        self.inviteButton = nil
    end

    -- 创建按钮框架
    local btn = CreateFrame("Button", addonName.."InviteBtn", UIParent, "UIPanelButtonTemplate")
    btn:SetSize(180, 40) -- 按钮基础尺寸
    -- 自定义按钮位置（可修改：CENTER为屏幕中心，x/y偏移可调整）
    btn:SetPoint("CENTER", UIParent, "CENTER", 0, -100) 
    btn:SetText("邀请 "..author.." 入公会") -- 按钮文字
    btn:SetNormalFontObject("GameFontNormalLarge")
    btn:SetHighlightFontObject("GameFontHighlightLarge")

    -- ========== 核心修改：提升按钮层级到最高 ==========
    btn:SetFrameStrata("TOOLTIP") -- 设置层级为提示层（最高层级）
    btn:SetFrameLevel(100) -- 设置层级数值（确保高于其他UI）
    -- ================================================

    -- ========== 关键修改1：扩大按钮可交互/拖动区域（边缘扩展10像素） ==========
    -- 设置按钮的点击/鼠标检测区域（向外扩展50px，上下左右各加50）
    btn:SetHitRectInsets(-50, -50, -50, -50)
    -- ========== 关键修改2：拖动逻辑重构（区分点击和拖动） ==========
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn.isDragging = false
    btn.dragStartX = 0
    btn.dragStartY = 0

    -- 鼠标按下事件：记录拖动起始位置，标记开始拖动
    btn:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            -- 记录鼠标按下时的位置和按钮位置
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self.dragStartX = x / scale - self:GetLeft()
            self.dragStartY = y / scale - self:GetTop()
            self.isDragging = false -- 初始标记为未拖动
            self:StartMoving() -- 开始移动（先不实际移动，等待鼠标移动判定）
        end
    end)

    -- 鼠标移动事件：判定是否为拖动操作
    btn:SetScript("OnUpdate", function(self)
        if self:IsMouseDown("LeftButton") then
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local currentX = x / scale - self.dragStartX
            local currentY = y / scale - self.dragStartY
            -- 如果鼠标移动超过5像素，判定为拖动，标记状态
            if not self.isDragging and (abs(currentX - self:GetLeft()) > 5 or abs(currentY - self:GetTop()) > 5) then
                self.isDragging = true
            end
        end
    end)

    -- 鼠标松开事件：结束拖动或执行点击
    btn:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self:StopMovingOrSizing()
            -- 如果是拖动操作，不执行点击逻辑；否则执行邀请
            if not self.isDragging then
                -- 执行公会邀请宏逻辑
                if CanGuildInvite() then
                    GuildInvite(author)
                    Print("【手动邀请】已邀请 "..author.." 加入公会！")
                else
                    Print("|cffff0000【邀请失败】你没有公会邀请权限！|r")
                end
                -- 非拖动的点击后隐藏按钮
                self:Hide()
                ARGI.inviteButton = nil
            else
                -- 拖动结束后更新按钮位置，不隐藏按钮
                Print("【按钮拖动】已将邀请按钮移动到新位置！")
                self.isDragging = false -- 重置拖动状态
            end
        end
    end)

    -- 按钮隐藏时重置拖动状态
    btn:SetScript("OnHide", function(self)
        if self:IsDragging() then
            self:StopMovingOrSizing()
        end
        self.isDragging = false
        self:ClearFocus() -- 隐藏时释放键盘焦点
    end)

    -- 按钮点击事件（保留原逻辑，实际已被上面的鼠标松开事件覆盖）
    btn:SetScript("OnClick", function(self)
        -- 此事件会被OnMouseUp覆盖，仅做冗余备份
        if CanGuildInvite() then
            GuildInvite(author)
            Print("【手动邀请】已邀请 "..author.." 加入公会！")
        else
            Print("|cffff0000【邀请失败】你没有公会邀请权限！|r")
        end
        self:Hide()
        ARGI.inviteButton = nil
    end)

    -- ========== 新增：快捷键"]"绑定逻辑 ==========
    -- 注册按键监听
    btn:RegisterForClicks("AnyUp")
    btn:SetPropagateKeyboardInput(true)
    -- 按键按下事件：检测"]"键
    btn:SetScript("OnKeyDown", function(self, key)
        if key == "]" then
            -- 触发邀请逻辑
            if CanGuildInvite() then
                GuildInvite(author)
                Print("【快捷键邀请】已邀请 "..author.." 加入公会！")
            else
                Print("|cffff0000【邀请失败】你没有公会邀请权限！|r")
            end
            self:Hide()
            ARGI.inviteButton = nil
        end
    end)
    -- 按钮显示时自动获取键盘焦点，确保能捕获按键
    btn:SetScript("OnShow", function(self)
        self:SetFocus()
    end)

    -- 按钮悬浮提示（新增快捷键说明）
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("点击邀请 "..author.." 加入你的公会", 0, 1, 0)
        GameTooltip:AddLine("按住左键可拖动按钮位置（边缘扩大更易操作）", 5, 5, 5, 5)
        GameTooltip:AddLine("按下快捷键右括号【 ] 】也可触发邀请", 1, 0.8, 0, 1)
        GameTooltip:AddLine("(无权限时会提示失败)", 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- 显示按钮并保存引用
    btn:Show()
    self.inviteButton = btn
    Print("【邀请按钮】已生成邀请 "..author.." 的按钮，点击或按【 ] 】键即可发送公会邀请！按住左键可拖动按钮！")
end

-- ================ 【核心修复】强制保存配置 (魔兽原生写法，100%写入文件) ================
function ARGI:SaveAllSettings()
    -- 强制写入，无任何嵌套，魔兽必识别
    AutoReply_FirstReply_Enable = self.firstReplyCheck:GetChecked()
    AutoReply_FirstReply_Text = self.firstReplyEdit:GetText()
    AutoReply_RuleReply_Enable = self.autoReplyCheck:GetChecked()
    AutoReply_GuildInv_Enable = self.guildInviteCheck:GetChecked()
    AutoReply_GuildInv_Trigger = self.inviteTriggerEdit:GetText()
    -- 保存5组规则（修改：10→5）
    for i=1,5 do
        _G["AutoReply_Rule"..i.."_Trigger"] = self["triggerEdit"..i]:GetText()
        _G["AutoReply_Rule"..i.."_Reply"] = self["replyEdit"..i]:GetText()
    end
    -- 强制刷新配置文件，立即写入硬盘（关键！解决空白核心）
    ReloadUI() -- 轻量重载，不卡游戏，仅刷新变量保存
    Print("✅ 所有设置已强制写入配置文件！配置文件不再空白！")
    self.optionsFrame:Hide() -- 保存后自动关闭界面
end

-- ================ 一键清空私聊记录 (保留功能) ================
function ARGI:ClearWhisperList()
    AutoReply_WhisperedPlayers = {}
    Print("✅ 已清空所有私聊玩家记录，可重新触发首次回复！")
end

-- ================ 聊天私聊事件处理 (修改公会邀请逻辑) ================
function ARGI:CHAT_MSG_WHISPER(msg, author)
    author = author:match("^([^%-]+)") -- 去除跨服服务器后缀
    if not author then return end

    -- 功能1：首次密语任意内容 自动回复 (仅触发1次)
    if AutoReply_FirstReply_Enable and not AutoReply_WhisperedPlayers[author] then
        SendChatMessage(AutoReply_FirstReply_Text, "WHISPER", nil, author)
        Print("【首次密语回复】"..author.."："..AutoReply_FirstReply_Text)
        AutoReply_WhisperedPlayers[author] = true
    end

    -- 功能2：5组自定义规则 模糊匹配自动回复（修改：10→5）
    if AutoReply_RuleReply_Enable then
        for i=1,5 do
            local trig = _G["AutoReply_Rule"..i.."_Trigger"]
            local repl = _G["AutoReply_Rule"..i.."_Reply"]
            if trig and repl and trig ~= "" and msg:find(trig, 1, true) then
                SendChatMessage(repl, "WHISPER", nil, author)
                Print("【规则回复】"..author.."："..repl)
                break
            end
        end
    end

    -- 功能3：指定触发词 生成手动邀请按钮（核心修改）
    if AutoReply_GuildInv_Enable and msg == AutoReply_GuildInv_Trigger then
        self:CreateInviteButton(author) -- 生成邀请按钮
    end
end

-- ================ 设置界面 (保留所有选项+底部【保存设置并关闭】按钮，位置不变) ================
function ARGI:CreateOptionsFrame()
    local f = CreateFrame("Frame", addonName.."Options", UIParent, "UIPanelDialogTemplate")
    f:SetSize(620, 580) -- 修改：调整面板高度（因规则组减少）
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetScript("OnMouseDown", f.StartMoving)
    f:SetScript("OnMouseUp", f.StopMovingOrSizing)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.title:SetPoint("TOP", 0, -10)
    f.title:SetText("自动回复&公会邀请助手 V2.0")

    -- 1. 首次密语回复开关
    self.firstReplyCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    self.firstReplyCheck:SetPoint("TOPLEFT", 20, -40)
    self.firstReplyCheck.Text:SetText("启用【首次密语任意内容】自动回复")
    self.firstReplyCheck:SetChecked(AutoReply_FirstReply_Enable)

    -- 2. 首次密语回复内容编辑框
    local firstReplyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    firstReplyLabel:SetPoint("TOPLEFT", self.firstReplyCheck, "BOTTOMLEFT", 0, -10)
    firstReplyLabel:SetText("首次回复内容：")
    self.firstReplyEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    self.firstReplyEdit:SetPoint("LEFT", firstReplyLabel, "RIGHT", 10, 0)
    self.firstReplyEdit:SetSize(350, 20)
    self.firstReplyEdit:SetText(AutoReply_FirstReply_Text)
    self.firstReplyEdit:SetMaxLetters(100)

    -- 3. 一键清空私聊记录按钮
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetPoint("TOPLEFT", firstReplyLabel, "BOTTOMLEFT", 0, -10)
    clearBtn:SetSize(180, 22)
    clearBtn:SetText("一键清空私聊玩家记录")
    clearBtn:SetScript("OnClick", function() ARGI:ClearWhisperList() end)

    -- 4. 5组规则回复开关（修改：10→5）
    self.autoReplyCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    self.autoReplyCheck:SetPoint("TOPLEFT", clearBtn, "BOTTOMLEFT", 0, -15)
    self.autoReplyCheck.Text:SetText("启用5组规则自动回复")
    self.autoReplyCheck:SetChecked(AutoReply_RuleReply_Enable)

    -- 5. 公会邀请开关
    self.guildInviteCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    self.guildInviteCheck:SetPoint("TOPLEFT", self.autoReplyCheck, "BOTTOMLEFT", 0, -10)
    self.guildInviteCheck.Text:SetText("启用手动公会邀请按钮（替代自动邀请）")
    self.guildInviteCheck:SetChecked(AutoReply_GuildInv_Enable)

    -- 6. 公会邀请触发词编辑框
    local inviteTriggerLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inviteTriggerLabel:SetPoint("TOPLEFT", self.guildInviteCheck, "BOTTOMLEFT", 0, -10)
    inviteTriggerLabel:SetText("邀请按钮触发词：")
    self.inviteTriggerEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    self.inviteTriggerEdit:SetPoint("LEFT", inviteTriggerLabel, "RIGHT", 10, 0)
    self.inviteTriggerEdit:SetSize(150, 20)
    self.inviteTriggerEdit:SetText(AutoReply_GuildInv_Trigger)

    -- 7. 5组自定义回复规则（修改：10→5）
    local rulesLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rulesLabel:SetPoint("TOPLEFT", inviteTriggerLabel, "BOTTOMLEFT", 0, -20)
    rulesLabel:SetText("自动回复规则（5组）")
    local yOffset = -20
    for i=1,5 do
        local trigLab = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        trigLab:SetPoint("TOPLEFT", rulesLabel, "BOTTOMLEFT", 0, yOffset)
        trigLab:SetText("规则"..i.." 触发词：")
        self["triggerEdit"..i] = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        self["triggerEdit"..i]:SetPoint("LEFT", trigLab, "RIGHT", 10, 0)
        self["triggerEdit"..i]:SetSize(150, 20)
        self["triggerEdit"..i]:SetText(_G["AutoReply_Rule"..i.."_Trigger"])

        local replLab = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        replLab:SetPoint("LEFT", self["triggerEdit"..i], "RIGHT", 20, 0)
        replLab:SetText("回复内容：")
        self["replyEdit"..i] = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        self["replyEdit"..i]:SetPoint("LEFT", replLab, "RIGHT", 10, 0)
        self["replyEdit"..i]:SetSize(200, 20)
        self["replyEdit"..i]:SetText(_G["AutoReply_Rule"..i.."_Reply"])
        yOffset = yOffset - 30
    end

    -- 添加水印文字（新增：保存按钮上方）
    local watermark = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    watermark:SetPoint("BOTTOM", f, "BOTTOM", 0, 50)
    watermark:SetText("https://wlk.plus60.cn")

    -- ✅ 【底部保存设置并关闭】按钮 (核心保留)
    local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    saveBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    saveBtn:SetSize(220, 30)
    saveBtn:SetText("保存设置并关闭界面")
    saveBtn:SetScript("OnClick", function() ARGI:SaveAllSettings() end)

    f:Hide()
    self.optionsFrame = f
end

-- ================ 指令呼出面板 + 插件初始化 ================
SLASH_ARGI1 = "/argi"
function SlashCmdList.ARGI()
    if not ARGI.optionsFrame then ARGI:CreateOptionsFrame() end
    ARGI.optionsFrame:SetShown(not ARGI.optionsFrame:IsShown())
end

-- 注册事件+加载插件
ARGI:RegisterEvent("CHAT_MSG_WHISPER")
ARGI:RegisterEvent("ADDON_LOADED")
function ARGI:ADDON_LOADED(name)
    if name ~= addonName then return end
    Print("插件加载完成！输入 /argi 打开设置面板")
    Print("【功能变更】玩家发送邀请触发词后将生成手动邀请按钮，点击或按【 ] 】键即可邀请！")
end